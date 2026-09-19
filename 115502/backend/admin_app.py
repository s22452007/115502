import sys
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

import sqlite3
import os
import json
import re
import base64
import binascii
from datetime import datetime, timedelta
from flask import Flask, render_template, request, redirect, url_for
import os
from flask import session, flash, redirect, url_for, render_template, request, jsonify
from functools import wraps
from utils.db import db
from models import Admin, Vocab, SystemLog, Article, Achievement, User, AccountType
from werkzeug.security import generate_password_hash, check_password_hash
from sqlalchemy import func
from dotenv import load_dotenv


def utc_to_tw(utc_str):
    """把資料庫的 UTC 時間字串轉成台灣時間 (+8)"""
    if not utc_str:
        return ''
    try:
        # 支援帶微秒和不帶微秒的格式
        for fmt in ('%Y-%m-%d %H:%M:%S.%f', '%Y-%m-%d %H:%M:%S'):
            try:
                dt = datetime.strptime(utc_str, fmt)
                return (dt + timedelta(hours=8)).strftime('%Y-%m-%d %H:%M')
            except ValueError:
                continue
        return utc_str
    except Exception:
        return utc_str

app = Flask(__name__)

app.secret_key = 'jlens_admin_secure_key_2024'

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(BASE_DIR, '.env'))  # GOOGLE_WEB_CLIENT_ID、TEACHER_GOOGLE_DOMAINS 等設定

# ---- 老師用學校 Google 帳號登入 ----
# GOOGLE_WEB_CLIENT_ID：Firebase 專案裡「Web client」的 OAuth client ID（與 App 的 serverClientId 同一個）。
#   沒設定時登入頁不顯示 Google 按鈕，老師仍可用管理者建立的帳號密碼登入。
# TEACHER_GOOGLE_DOMAINS：允許的學校網域，逗號分隔。以「.」開頭代表結尾比對，
#   例如 .edu.tw 涵蓋全台學校（ntub.edu.tw、xxjh.tp.edu.tw…）；ntub.edu.tw 則只允許該校。留空表示不限制網域。
GOOGLE_WEB_CLIENT_ID = (os.getenv('GOOGLE_WEB_CLIENT_ID') or '').strip()
TEACHER_GOOGLE_DOMAINS = [d.strip().lower().lstrip('@') for d in (os.getenv('TEACHER_GOOGLE_DOMAINS') or '').split(',') if d.strip()]
# TEACHER_GOOGLE_STUDENT_PATTERN：Email @ 前面符合這個正規式的視為學生帳號、不能登入老師後台。
#   預設 ^\d+$（帳號全是數字＝學號，例如 11156047@ntub.edu.tw）。設成空字串則不過濾。
TEACHER_GOOGLE_STUDENT_PATTERN = os.getenv('TEACHER_GOOGLE_STUDENT_PATTERN', r'^\d+$').strip()

path1 = os.path.join(BASE_DIR, 'instance', 'jlens.db')
path2 = os.path.join(BASE_DIR, 'jlens.db')
DB_FILE_PATH = path1 if os.path.exists(path1) else path2


from sqlalchemy.pool import NullPool
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + DB_FILE_PATH
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'poolclass': NullPool,
    'connect_args': {'timeout': 15},
}
db.init_app(app)


@app.context_processor
def _inject_google_login_settings():
    """登入頁用：有設定 client ID 才顯示「用學校 Google 帳號登入」按鈕"""
    return {'google_client_id': GOOGLE_WEB_CLIENT_ID,
            'teacher_domains': TEACHER_GOOGLE_DOMAINS,
            'teacher_domain_labels': _teacher_domain_labels()}


def _teacher_domain_allowed(domain):
    """'.edu.tw' 這種以「.」開頭的設定用結尾比對，其餘要完全相同"""
    domain = (domain or '').lower()
    for allowed in TEACHER_GOOGLE_DOMAINS:
        if allowed.startswith('.'):
            if domain.endswith(allowed) or domain == allowed[1:]:
                return True
        elif domain == allowed:
            return True
    return False


def _teacher_domain_labels():
    """顯示給老師看的網域說明，例如 ['@*.edu.tw', '@ntub.edu.tw']"""
    return ['@*' + d if d.startswith('.') else '@' + d for d in TEACHER_GOOGLE_DOMAINS]
# ==========================================
# 🚀 自動路徑偵測
# ==========================================
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
# 優先嘗試 instance 下的路徑
DB_FILE_PATH = os.path.join(BASE_DIR, 'instance', 'jlens.db')

def get_db_connection():
    conn = sqlite3.connect(DB_FILE_PATH, check_same_thread=False, timeout=15)
    conn.execute('PRAGMA journal_mode=WAL')
    conn.execute('PRAGMA busy_timeout=15000')
    conn.row_factory = sqlite3.Row
    return conn

# ==========================================
# 🔐 1. 守門員：檢查是否登入
# ==========================================
def admin_login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'admin_user' not in session:
            return redirect(url_for('admin_login'))
        # 老師的 session 也有 admin_user（側欄顯示名稱用），但不能進管理者的頁面
        if session.get('role') == 'teacher':
            return redirect(url_for('teacher_classrooms'))
        return f(*args, **kwargs)
    return decorated_function

def super_admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'admin_user' not in session:
            return redirect(url_for('admin_login'))
        if session.get('role') == 'teacher':
            return redirect(url_for('teacher_classrooms'))
        if session.get('role') != 'super_admin':
            return redirect(url_for('admin_dashboard'))
        return f(*args, **kwargs)
    return decorated_function

def teacher_required(f):
    """校園教育版老師頁面：老師本人（已審核）或 super_admin 才能進。

    - 老師：每次請求重新查一次帳號，被停用就登出；待審核只會看到「等待審核」頁
    - super_admin：可以檢視、管理所有班級，但不綁定任何老師帳號（不能代替老師建班級）
    - 一般管理者：進不了，導回管理者首頁
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if session.get('role') == 'teacher' and session.get('teacher_user_id'):
            teacher = User.query.get(session['teacher_user_id'])
            if not teacher or getattr(teacher, 'is_suspended', False) or teacher.account_type != AccountType.TEACHER:
                session.clear()
                return redirect(url_for('admin_login'))
            if (getattr(teacher, 'teacher_status', None) or 'approved') != 'approved' and request.endpoint != 'teacher_pending':
                return redirect(url_for('teacher_pending'))
            return f(*args, **kwargs)
        if session.get('role') == 'super_admin':
            return f(*args, **kwargs)
        if 'admin_user' in session:
            return redirect(url_for('admin_dashboard'))
        return redirect(url_for('admin_login'))
    return decorated_function

# ==========================================
# 🏠 2. 首頁導航 (解決無限迴圈的關鍵)
# ==========================================
@app.route('/')
def admin_root():
    
    return redirect(url_for('admin_login'))         # 沒登入就去登入頁

# ==========================================
# 🚪 3. 登入與登出系統
# ==========================================
# ==========================================
# 🚪 3. 登入與登出系統
# ==========================================
@app.route('/login-preview')
def login_preview():
    return render_template('admin_login_preview.html')

@app.route('/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        # 登入頁分成「管理者」與「老師」兩個分頁，用 login_as 區分
        if request.form.get('login_as') == 'teacher':
            return _teacher_login()

        # 現在 username 會接收到我們下拉選單選到的學號 (例如 "11156001")
        username = request.form.get('username')
        password = request.form.get('password')
        
        # 增加終端機的登入紀錄 (方便您增加 Commit 內容)
        print(f"[{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')}] 登入嘗試: 管理員 {username}")
        
        admin = Admin.query.filter_by(username=username).first()
        
        if admin and admin.check_password(password):
            # 登入成功，將重要資訊寫入 Session
            session['admin_user'] = admin.username
            session['admin_id'] = admin.id
            session['role'] = admin.role # 確保這行有加上，這樣才能分辨 super_admin
            session.permanent = True
            
            print(f"[OK] 登入成功: {username} (權限: {admin.role})")
            return redirect(url_for('admin_dashboard')) # 密碼正確去儀表板
        else:
            print(f"[FAIL] 登入失敗: {username} (密碼錯誤)")
            return render_template('admin_login.html', error="密碼錯誤，請重新輸入")
            
    return render_template('admin_login.html')


def _teacher_login():
    """校園教育版老師登入：帳號是 user 表裡 account_type='teacher' 的使用者（由 super_admin 建立）"""
    email = (request.form.get('email') or '').strip()
    password = request.form.get('password') or ''
    user = User.query.filter_by(email=email).first()

    if not user or not check_password_hash(user.password_hash, password):
        print(f"[FAIL] 老師登入失敗: {email} (帳號或密碼錯誤)")
        return render_template('admin_login.html', login_as='teacher', error="Email 或密碼錯誤，請重新輸入")
    if getattr(user, 'account_type', AccountType.GENERAL) != AccountType.TEACHER:
        return render_template('admin_login.html', login_as='teacher',
                               error="這不是老師帳號。老師帳號需由學校系統管理員在後台建立")
    if getattr(user, 'is_suspended', False):
        return render_template('admin_login.html', login_as='teacher', error="此老師帳號已被停用，請聯繫系統管理員")

    print(f"[OK] 老師登入成功: {email} (user_id={user.id})")
    return _start_teacher_session(user)


def _start_teacher_session(user):
    session.clear()
    session['admin_user'] = user.username or user.email   # 側欄顯示名稱
    session['admin_id'] = None                            # 老師不是 admin 表的帳號
    session['role'] = 'teacher'
    session['teacher_user_id'] = user.id
    session.permanent = True
    return redirect(url_for('teacher_classrooms'))


def _verify_google_id_token(credential):
    """向 Google 驗證登入頁送來的 ID token，回傳 claims（email、name、picture…）；驗證失敗丟 ValueError。

    這裡一定要在伺服器端驗，不能像 App 的 /google_login 那樣直接相信前端送來的 Email。
    """
    from google.oauth2 import id_token as google_id_token
    from google.auth.transport import requests as google_requests
    return google_id_token.verify_oauth2_token(credential, google_requests.Request(), GOOGLE_WEB_CLIENT_ID)


def _unique_teacher_username(preferred, email):
    """user.username 有唯一限制；Google 顯示名稱撞名時改用 Email 帳號部分，再撞就加流水號"""
    base = (preferred or '').strip() or email.split('@')[0]
    candidates = [base, email.split('@')[0]] + [f'{base}{i}' for i in range(2, 100)]
    for name in candidates:
        if not User.query.filter_by(username=name).first():
            return name
    return email


@app.route('/login/google', methods=['POST'])
def teacher_google_login():
    """老師用學校 Google 帳號登入：第一次登入自動建立老師帳號，之後直接登入"""
    def fail(msg):
        print(f"[FAIL] 老師 Google 登入失敗: {msg}")
        return render_template('admin_login.html', login_as='teacher', error=msg)

    if not GOOGLE_WEB_CLIENT_ID:
        return fail('尚未設定 Google 登入，請聯繫系統管理員')
    credential = request.form.get('credential') or ''
    if not credential:
        return fail('沒有收到 Google 登入資料，請再試一次')

    try:
        claims = _verify_google_id_token(credential)
    except ValueError as e:
        return fail('Google 登入驗證失敗，請再試一次')

    email = (claims.get('email') or '').strip()
    if not email or not claims.get('email_verified', False):
        return fail('這個 Google 帳號的 Email 尚未驗證')
    domain = email.split('@')[-1].lower()
    if TEACHER_GOOGLE_DOMAINS and not _teacher_domain_allowed(domain):
        allowed = '、'.join(_teacher_domain_labels())
        return fail(f'請使用學校配發的 Google 帳號（{allowed}）登入，一般 Gmail 無法作為老師帳號')
    if TEACHER_GOOGLE_STUDENT_PATTERN and re.fullmatch(TEACHER_GOOGLE_STUDENT_PATTERN, email.split('@')[0]):
        return fail(f'「{email}」是學生帳號（帳號為學號），無法登入老師後台；老師請改用學校配發的教職員帳號')

    user = User.query.filter_by(email=email).first()
    if user is None:
        # 學校網域驗證通過的第一次登入：自動建立老師帳號，不需要管理者手動建
        user = User(
            email=email,
            username=_unique_teacher_username(claims.get('name'), email),
            password_hash=generate_password_hash('GOOGLE_OAUTH_' + os.urandom(16).hex()),
            account_type=AccountType.TEACHER,
            avatar=claims.get('picture') or None,
            teacher_status='pending',   # 學校帳號證明不了是老師，要等管理者核准
        )
        db.session.add(user)
        db.session.flush()
        db.session.add(SystemLog(
            admin_id=None, user_id=user.id,
            action='CREATE', target_table='user', target_id=user.id,
            new_value={'email': email, 'username': user.username, 'account_type': AccountType.TEACHER,
                       'via': 'google', 'teacher_status': 'pending'}
        ))
        db.session.commit()
        print(f"[NEW] 以學校 Google 帳號建立老師: {email}")
    elif getattr(user, 'account_type', AccountType.GENERAL) != AccountType.TEACHER:
        return fail(f'「{email}」已是 App 的一般使用者帳號，無法作為老師帳號；請改用其他學校帳號，或請管理者處理')
    elif getattr(user, 'is_suspended', False):
        return fail('此老師帳號已被停用，請聯繫系統管理員')

    print(f"[OK] 老師 Google 登入成功: {email} (user_id={user.id})")
    return _start_teacher_session(user)

@app.route('/logout')
def admin_logout():
    session.clear()
    return redirect(url_for('admin_login'))

@app.route('/admin/change_password', methods=['GET', 'POST'])
@admin_login_required
def change_password():
    error = None
    success = None
    if request.method == 'POST':
        current = request.form.get('current_password', '')
        new_pw = request.form.get('new_password', '')
        confirm = request.form.get('confirm_password', '')
        admin = Admin.query.filter_by(username=session['admin_user']).first()
        if not admin.check_password(current):
            error = '目前密碼錯誤'
        elif new_pw != confirm:
            error = '新密碼與確認密碼不一致'
        elif len(new_pw) < 6:
            error = '密碼至少需要 6 個字元'
        else:
            admin.set_password(new_pw)
            db.session.commit()
            success = '密碼已成功更新'
    return render_template('admin/change_password.html', error=error, success=success,
                           admin_user=session.get('admin_user'))

# ==========================================
# 📊 4. 儀表板 (讀取您的 index.html)
# ==========================================
@app.route('/dashboard')
@admin_login_required
def admin_dashboard():
    from datetime import date
    conn = get_db_connection()
    try:
        user_count = conn.execute('SELECT COUNT(*) FROM user').fetchone()[0]
    except: user_count = 0
    try:
        photo_count = conn.execute('SELECT COUNT(*) FROM user_photo').fetchone()[0]
    except: photo_count = 0
    try:
        vocab_exists = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='vocab'").fetchone()
        vocab_count = conn.execute('SELECT COUNT(*) FROM vocab').fetchone()[0] if vocab_exists else 0
    except: vocab_count = 0
    try:
        today_str = date.today().strftime('%Y-%m-%d')
        today_active = conn.execute(
            "SELECT COUNT(*) FROM user WHERE DATE(last_login_date) = ?", (today_str,)
        ).fetchone()[0]
    except: today_active = 0
    try:
        feedback_total = conn.execute('SELECT COUNT(*) FROM feedback').fetchone()[0]
    except: feedback_total = 0
    try:
        feedback_pending = conn.execute(
            'SELECT COUNT(*) FROM feedback WHERE reply IS NULL OR reply = ""'
        ).fetchone()[0]
    except: feedback_pending = 0
    try:
        new_users_today = conn.execute(
            "SELECT COUNT(*) FROM user WHERE DATE(created_at) = ?", (today_str,)
        ).fetchone()[0]
    except: new_users_today = 0
    try:
        recent_users = conn.execute(
            "SELECT username, email, avatar, last_seen_at FROM user ORDER BY last_seen_at IS NULL, last_seen_at DESC LIMIT 5"
        ).fetchall()
        recent_users = [
            {**dict(u), 'last_seen_at': utc_to_tw(u['last_seen_at']) if u['last_seen_at'] else '從未登入'}
            for u in recent_users
        ]
    except: recent_users = []
    try:
        pending_feedbacks = conn.execute(
            '''SELECT f.id, f.feedback_type, f.content, f.created_at, u.username, u.email
               FROM feedback f
               LEFT JOIN user u ON f.user_id = u.id
               WHERE f.reply IS NULL OR f.reply = ""
               ORDER BY f.created_at DESC LIMIT 5'''
        ).fetchall()
        pending_feedbacks = [
            {**dict(f), 'created_at': utc_to_tw(f['created_at'])}
            for f in pending_feedbacks
        ]
    except: pending_feedbacks = []
    conn.close()

    return render_template('index.html',
                           user_count=user_count,
                           photo_count=photo_count,
                           vocab_count=vocab_count,
                           today_active=today_active,
                           feedback_total=feedback_total,
                           feedback_pending=feedback_pending,
                           recent_users=recent_users,
                           pending_feedbacks=pending_feedbacks,
                           new_users_today=new_users_today)
# ==========================================
# [使用者管理] 包含點數 (j_pts)
# ==========================================
@app.route('/customer/list')
@admin_login_required
def customer_list():
    conn = get_db_connection()
    users = conn.execute('SELECT id, username, email, j_pts, created_at FROM user').fetchall()
    conn.close()
    return render_template('customer/list.html', customers=users)

@app.route('/customer/adjust_pts/<int:user_id>', methods=['POST'])
@admin_login_required
def adjust_pts(user_id):
    try:
        amount = int(request.form.get('amount', 0))
    except (ValueError, TypeError):
        return redirect(url_for('customer_list'))
    conn = get_db_connection()
    conn.execute('UPDATE user SET j_pts = j_pts + ? WHERE id = ?', (amount, user_id))
    conn.commit()
    conn.close()
    return redirect(url_for('customer_list'))

@app.route('/user/suspend/<int:user_id>', methods=['POST'])
@admin_login_required
def toggle_suspend_user(user_id):
    conn = get_db_connection()
    row = conn.execute('SELECT is_suspended FROM user WHERE id = ?', (user_id,)).fetchone()
    if row:
        new_val = 0 if row['is_suspended'] else 1
        conn.execute('UPDATE user SET is_suspended = ? WHERE id = ?', (new_val, user_id))
        conn.commit()
    conn.close()
    return redirect(request.referrer or url_for('user_list'))


@app.route('/plan/list')
@super_admin_required
def plan_list():
    conn = get_db_connection()
    plans = conn.execute('SELECT * FROM subscription_plan ORDER BY id ASC').fetchall()
    plans = [dict(p) for p in plans]
    for p in plans:
        count = conn.execute(
            """SELECT COUNT(*) as cnt FROM user_subscription
               WHERE plan_id=? AND end_date >= datetime('now')
                 AND billing_cycle != 'trial' AND auto_renew != 0""",
            (p['id'],)
        ).fetchone()
        p['active_users'] = count['cnt'] if count else 0
    free_users = conn.execute(
        "SELECT COUNT(*) FROM user WHERE is_premium = 0 OR is_premium IS NULL"
    ).fetchone()[0]
    conn.close()
    return render_template('plan/list.html', plans=plans, free_users=free_users)

@app.route('/plan/add', methods=['POST'])
@super_admin_required
def plan_add():
    name = request.form.get('name', '').strip()
    billing_cycle = request.form.get('billing_cycle', 'monthly')
    price_monthly = request.form.get('price_monthly')
    price_yearly = request.form.get('price_yearly')
    pts_monthly = request.form.get('points_grant_monthly')
    pts_yearly = request.form.get('points_grant_yearly')
    if name and billing_cycle:
        admin_id = session.get('admin_id')
        now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
        conn = get_db_connection()
        cur = conn.execute('''INSERT INTO subscription_plan
                        (name, billing_cycle, price_monthly, price_yearly, points_grant_monthly, points_grant_yearly, is_active, updated_by, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)''',
                     (name, billing_cycle,
                      int(price_monthly) if price_monthly else None,
                      int(price_yearly)  if price_yearly  else None,
                      int(pts_monthly)   if pts_monthly   else None,
                      int(pts_yearly)    if pts_yearly    else None,
                      admin_id, now))
        conn.execute(
            'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
            (admin_id, 'INSERT', 'subscription_plan', cur.lastrowid, now))
        conn.commit()
        conn.close()
    return redirect(url_for('plan_list'))

@app.route('/plan/edit/<int:plan_id>', methods=['POST'])
@super_admin_required
def plan_edit(plan_id):
    name = request.form.get('name', '').strip()
    price_monthly = request.form.get('price_monthly') or None
    price_yearly  = request.form.get('price_yearly') or None
    pts_monthly   = request.form.get('points_grant_monthly') or None
    pts_yearly    = request.form.get('points_grant_yearly') or None
    if name:
        admin_id = session.get('admin_id')
        now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
        conn = get_db_connection()
        conn.execute('''UPDATE subscription_plan SET name=?, price_monthly=?, price_yearly=?,
                        points_grant_monthly=?, points_grant_yearly=?, updated_by=?, updated_at=? WHERE id=?''',
                     (name,
                      int(price_monthly) if price_monthly else None,
                      int(price_yearly)  if price_yearly  else None,
                      int(pts_monthly)   if pts_monthly   else None,
                      int(pts_yearly)    if pts_yearly    else None,
                      admin_id, now, plan_id))
        conn.execute(
            'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
            (admin_id, 'UPDATE', 'subscription_plan', plan_id, now))
        conn.commit()
        conn.close()
    return redirect(url_for('plan_list'))

@app.route('/plan/toggle/<int:plan_id>', methods=['POST'])
@super_admin_required
def plan_toggle(plan_id):
    conn = get_db_connection()
    row = conn.execute('SELECT is_active FROM subscription_plan WHERE id=?', (plan_id,)).fetchone()
    if row:
        conn.execute('UPDATE subscription_plan SET is_active=? WHERE id=?',
                     (0 if row['is_active'] else 1, plan_id))
        conn.commit()
    conn.close()
    return redirect(url_for('plan_list'))

@app.route('/package/list')
@super_admin_required
def package_list():
    conn = get_db_connection()
    packages = conn.execute('SELECT * FROM point_package ORDER BY price ASC').fetchall()
    packages = [dict(p) for p in packages]

    # 計算每個方案的購買次數與累計營收
    for p in packages:
        row = conn.execute(
            "SELECT COUNT(*) as cnt, COALESCE(SUM(price),0) as revenue FROM point_transaction WHERE points=? AND price=? AND transaction_type='purchase'",
            (p['points'], p['price'])
        ).fetchone()
        p['buy_count'] = row['cnt'] if row else 0
        p['revenue']   = row['revenue'] if row else 0

    # 整體統計
    total_revenue  = sum(p['revenue'] for p in packages)
    total_purchases = sum(p['buy_count'] for p in packages)
    active_count   = sum(1 for p in packages if p['is_active'])

    conn.close()
    return render_template('package/list.html', packages=packages,
                           total_revenue=total_revenue, total_purchases=total_purchases,
                           active_count=active_count)

@app.route('/package/add', methods=['POST'])
@super_admin_required
def package_add():
    name  = request.form.get('name', '').strip()
    points = request.form.get('points', 0)
    price  = request.form.get('price', 0)
    tag    = request.form.get('tag', '').strip()
    desc   = request.form.get('description', '').strip()
    if name and points and price:
        admin_id = session.get('admin_id')
        now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
        conn = get_db_connection()
        cur = conn.execute(
            'INSERT INTO point_package (name, points, price, tag, description, is_active, updated_by, updated_at) VALUES (?,?,?,?,?,1,?,?)',
            (name, int(points), int(price), tag or None, desc or None, admin_id, now))
        conn.execute(
            'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
            (admin_id, 'INSERT', 'point_package', cur.lastrowid, now))
        conn.commit()
        conn.close()
    return redirect(url_for('package_list'))

@app.route('/package/edit/<int:pkg_id>', methods=['POST'])
@super_admin_required
def package_edit(pkg_id):
    name   = request.form.get('name', '').strip()
    points = request.form.get('points', 0)
    price  = request.form.get('price', 0)
    tag    = request.form.get('tag', '').strip()
    desc   = request.form.get('description', '').strip()
    if name and points and price:
        admin_id = session.get('admin_id')
        now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
        conn = get_db_connection()
        conn.execute(
            'UPDATE point_package SET name=?, points=?, price=?, tag=?, description=?, updated_by=?, updated_at=? WHERE id=?',
            (name, int(points), int(price), tag or None, desc or None, admin_id, now, pkg_id))
        conn.execute(
            'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
            (admin_id, 'UPDATE', 'point_package', pkg_id, now))
        conn.commit()
        conn.close()
    return redirect(url_for('package_list'))

@app.route('/package/toggle/<int:pkg_id>', methods=['POST'])
@super_admin_required
def package_toggle(pkg_id):
    conn = get_db_connection()
    row = conn.execute('SELECT is_active FROM point_package WHERE id=?', (pkg_id,)).fetchone()
    if row:
        conn.execute('UPDATE point_package SET is_active=? WHERE id=?', (0 if row['is_active'] else 1, pkg_id))
        conn.commit()
    conn.close()
    return redirect(url_for('package_list'))

@app.route('/purchase/list')
@admin_login_required
def purchase_list():
    conn = get_db_connection()
    
    # 這裡直接去抓您資料庫裡原有的 point_transaction 表格
    # 只抓真正的付費購買紀錄，排除獎勵領取、消費點數、訂閱贈點等非購買事件
    query = '''
        SELECT p.id, p.points, p.price, p.payment_method, p.created_at,
               u.username, u.email
        FROM point_transaction p
        LEFT JOIN user u ON p.user_id = u.id
        WHERE p.transaction_type = 'purchase' OR p.transaction_type IS NULL
        ORDER BY p.created_at DESC
    '''
    
    try:
        records = conn.execute(query).fetchall()
        purchases = [{**dict(r), 'created_at': utc_to_tw(r['created_at'])} for r in records]
    except Exception as e:
        print(f"查詢購買紀錄失敗：{e}")
        purchases = []
        
    conn.close()
    
    # 將資料送到我們剛剛建立的 templates/purchase/list.html
    return render_template('purchase/list.html', purchases=purchases)
# ==========================================
# [照片管控]
# ==========================================
@app.route('/photo/list')
@admin_login_required
def photo_list():
    conn = get_db_connection()
    # 修正點：將 p.filename 改為 p.image_path
    query = '''
        SELECT p.id, p.image_path, u.username, s.name as scene_name, p.custom_title, p.created_at 
        FROM user_photo p
        LEFT JOIN user u ON p.user_id = u.id
        LEFT JOIN scene s ON p.scene_id = s.id
    '''
    photos = conn.execute(query).fetchall()
    conn.close()
    return render_template('photo/list.html', photos=photos)

@app.route('/photo/delete/<int:photo_id>', methods=['POST'])
@admin_login_required
def delete_photo(photo_id):
    conn = get_db_connection()
    conn.execute('DELETE FROM user_photo_vocab WHERE photo_id = ?', (photo_id,))
    conn.execute('DELETE FROM user_photo WHERE id = ?', (photo_id,))
    conn.commit()
    conn.close()
    return redirect(url_for('photo_list'))

# ==========================================
# [教材單字管理] 
# ==========================================


# ==========================================
# [意見回饋管理]
# ==========================================
@app.route('/feedback/list')
@admin_login_required
def feedback_list():
    status = request.args.get('status', 'all')
    conn = get_db_connection()
    base = '''
        SELECT f.id, f.feedback_type, f.content, f.reply, f.replied_at, f.created_at,
               u.username, u.email
        FROM feedback f
        LEFT JOIN user u ON f.user_id = u.id
    '''
    if status == 'pending':
        query = base + 'WHERE (f.reply IS NULL OR f.reply = "") ORDER BY f.created_at DESC'
    elif status == 'replied':
        query = base + 'WHERE f.reply IS NOT NULL AND f.reply != "" ORDER BY f.created_at DESC'
    else:
        query = base + 'ORDER BY f.created_at DESC'
    feedbacks = conn.execute(query).fetchall()
    pending_count = conn.execute(
        'SELECT COUNT(*) FROM feedback WHERE reply IS NULL OR reply = ""'
    ).fetchone()[0]
    conn.close()
    feedbacks = [
        {**dict(f),
         'created_at': utc_to_tw(f['created_at']),
         'replied_at': utc_to_tw(f['replied_at']) if f['replied_at'] else None}
        for f in feedbacks
    ]
    return render_template('feedback/list.html', feedbacks=feedbacks, status=status, pending_count=pending_count)

@app.route('/feedback/reply/<int:feedback_id>', methods=['POST'])
@admin_login_required
def feedback_reply(feedback_id):
    reply = request.form.get('reply', '').strip()
    if not reply:
        return redirect(url_for('feedback_list'))
    admin_id = session.get('admin_id')
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    conn = get_db_connection()
    conn.execute('UPDATE feedback SET reply = ?, replied_at = ?, replied_by = ? WHERE id = ?',
                 (reply, now, admin_id, feedback_id))
    conn.execute(
        'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
        (admin_id, 'UPDATE', 'feedback', feedback_id, now))
    conn.commit()
    conn.close()
    return redirect(url_for('feedback_list'))

@app.route('/feedback/delete/<int:feedback_id>', methods=['POST'])
@admin_login_required
def feedback_delete(feedback_id):
    admin_id = session.get('admin_id')
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    conn = get_db_connection()
    conn.execute('DELETE FROM feedback WHERE id = ?', (feedback_id,))
    conn.execute(
        'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
        (admin_id, 'DELETE', 'feedback', feedback_id, now))
    conn.commit()
    conn.close()
    return redirect(url_for('feedback_list'))


# ==========================================
# [使用者資料] 新版：詳細資料 + 卡片式
# ==========================================
@app.route('/user/list')
@admin_login_required
def user_list():
    keyword = request.args.get('q', '').strip()
    conn = get_db_connection()

    # 檢查欄位是否存在
    cols = [row[1] for row in conn.execute("PRAGMA table_info(user)").fetchall()]
    has_last_seen    = 'last_seen_at'          in cols
    has_is_premium   = 'is_premium'            in cols
    has_trial_used   = 'trial_used'            in cols
    has_sub_end      = 'subscription_end_date' in cols
    has_is_suspended = 'is_suspended'          in cols
    has_account_type = 'account_type'          in cols

    last_seen_col    = 'u.last_seen_at'          if has_last_seen    else 'NULL as last_seen_at'
    is_premium_col   = 'u.is_premium'            if has_is_premium   else '0 as is_premium'
    trial_used_col   = 'u.trial_used'            if has_trial_used   else '0 as trial_used'
    sub_end_col      = 'u.subscription_end_date' if has_sub_end      else 'NULL as subscription_end_date'
    is_suspended_col = 'u.is_suspended'          if has_is_suspended else '0 as is_suspended'
    account_type_col = 'u.account_type'          if has_account_type else "'general' as account_type"

    base_query = f'''
        SELECT u.id, u.email, u.username, u.friend_id, u.japanese_level,
               u.j_pts,
               CASE WHEN u.last_login_date >= DATE('now', '-1 day') THEN u.streak_days ELSE 0 END as streak_days,
               u.total_active_days,
               u.avatar,
               DATE(u.created_at) as created_at,
               {last_seen_col},
               {is_premium_col},
               {trial_used_col},
               {sub_end_col},
               {is_suspended_col},
               {account_type_col},
               (SELECT COUNT(*) FROM user_vocab WHERE user_id = u.id AND collected_at IS NOT NULL) as vocab_count,
               (SELECT COUNT(*) FROM user_folder WHERE user_id = u.id) as folder_count,
               (SELECT COUNT(*) FROM friendship WHERE user_id = u.id) as friend_count,
               (SELECT CASE WHEN sub.end_date < datetime('now') THEN 'expired'
                            WHEN sub.billing_cycle = 'trial' THEN 'trial'
                            WHEN sub.auto_renew = 0 THEN 'cancelled'
                            ELSE 'active' END
                FROM user_subscription sub WHERE sub.user_id = u.id ORDER BY sub.created_at DESC LIMIT 1) as sub_status,
               (SELECT sub.billing_cycle FROM user_subscription sub WHERE sub.user_id = u.id ORDER BY sub.created_at DESC LIMIT 1) as sub_billing_cycle,
               (SELECT sp.name FROM user_subscription sub JOIN subscription_plan sp ON sp.id = sub.plan_id WHERE sub.user_id = u.id ORDER BY sub.created_at DESC LIMIT 1) as sub_plan_name
        FROM user u
    '''
    if keyword:
        query = base_query + '''
            WHERE u.email LIKE ? OR u.username LIKE ? OR u.friend_id LIKE ?
            ORDER BY u.created_at DESC
        '''
        pattern = f'%{keyword}%'
        users = conn.execute(query, (pattern, pattern, pattern)).fetchall()
    else:
        users = conn.execute(base_query + 'ORDER BY u.created_at DESC').fetchall()
    conn.close()
    users = [
        {**dict(u), 'last_seen_at': utc_to_tw(u['last_seen_at']) if u['last_seen_at'] else None}
        for u in users
    ]
    return render_template('user/list.html', users=users, keyword=keyword)


@app.route('/user/<int:user_id>')
@admin_login_required
def user_detail(user_id):
    conn = get_db_connection()

    user = conn.execute('SELECT * FROM user WHERE id = ?', (user_id,)).fetchone()
    if not user:
        conn.close()
        return redirect(url_for('user_list'))
    user = dict(user)
    user['last_seen_at'] = utc_to_tw(user.get('last_seen_at') or '')
    user['created_at']   = utc_to_tw(user.get('created_at') or '')

    try:
        subscriptions = conn.execute('''
            SELECT us.id,
                   CASE WHEN us.end_date < datetime('now') THEN 'expired'
                        WHEN us.billing_cycle = 'trial' THEN 'trial'
                        WHEN us.auto_renew = 0 THEN 'cancelled'
                        ELSE 'active' END as status,
                   us.billing_cycle, us.start_date, us.end_date,
                   us.auto_renew, us.created_at, sp.name as plan_name
            FROM user_subscription us
            LEFT JOIN subscription_plan sp ON sp.id = us.plan_id
            WHERE us.user_id = ?
            ORDER BY us.created_at DESC
        ''', (user_id,)).fetchall()
        subscriptions = [{**dict(s),
            'created_at': utc_to_tw(s['created_at']),
            'start_date': utc_to_tw(s['start_date'] or ''),
            'end_date':   utc_to_tw(s['end_date'] or '')} for s in subscriptions]
    except: subscriptions = []

    try:
        transactions = conn.execute('''
            SELECT id, transaction_type, points, price, payment_method, created_at
            FROM point_transaction WHERE user_id = ?
            ORDER BY created_at DESC LIMIT 30
        ''', (user_id,)).fetchall()
        transactions = [{**dict(t), 'created_at': utc_to_tw(t['created_at'])} for t in transactions]
    except: transactions = []

    try:
        photo_count = conn.execute('SELECT COUNT(*) FROM user_photo WHERE user_id = ?', (user_id,)).fetchone()[0]
        photos = conn.execute('''
            SELECT p.id, p.image_path, p.custom_title, p.created_at, s.name as scene_name
            FROM user_photo p LEFT JOIN scene s ON s.id = p.scene_id
            WHERE p.user_id = ? ORDER BY p.created_at DESC LIMIT 6
        ''', (user_id,)).fetchall()
        photos = [{**dict(p), 'created_at': utc_to_tw(p['created_at'])} for p in photos]
    except: photo_count = 0; photos = []

    try:
        vocab_count = conn.execute(
            'SELECT COUNT(*) FROM user_vocab WHERE user_id = ?', (user_id,)
        ).fetchone()[0]
    except: vocab_count = 0

    try:
        friends = conn.execute('''
            SELECT u.id, u.username, u.email, u.friend_id, u.japanese_level
            FROM friendship f JOIN user u ON u.id = f.friend_id
            WHERE f.user_id = ?
        ''', (user_id,)).fetchall()
        friends = [dict(f) for f in friends]
    except: friends = []

    try:
        feedbacks = conn.execute('''
            SELECT id, feedback_type, content, reply, replied_at, created_at
            FROM feedback WHERE user_id = ? ORDER BY created_at DESC
        ''', (user_id,)).fetchall()
        feedbacks = [{**dict(f),
            'created_at': utc_to_tw(f['created_at']),
            'replied_at': utc_to_tw(f['replied_at'] or '')} for f in feedbacks]
    except: feedbacks = []

    try:
        # study_group 沒有 description、group_member 也沒有 role 欄位，
        # 原本的查詢會直接丟例外被 except 吃掉，導致這區永遠顯示「未加入任何小組」
        groups = conn.execute('''
            SELECT sg.id, sg.name, sg.goal_type, sg.goal_target, sg.current_progress,
                   gm.joined_at, gm.group_scans, gm.group_points, gm.group_logins,
                   gm.group_sentences, gm.group_articles, gm.has_claimed
            FROM group_member gm JOIN study_group sg ON sg.id = gm.group_id
            WHERE gm.user_id = ?
            ORDER BY gm.joined_at DESC
        ''', (user_id,)).fetchall()
        groups = [dict(g) for g in groups]
        for g in groups:
            label, contrib_col = GROUP_GOAL_MAP.get(g['goal_type'], (g['goal_type'] or '—', None))
            g['goal_label'] = label
            g['my_contribution'] = (g.get(contrib_col) or 0) if contrib_col else None
            g['joined_at'] = utc_to_tw(g['joined_at'] or '')
    except: groups = []

    conn.close()
    return render_template('user/detail.html',
        user=user, subscriptions=subscriptions, transactions=transactions,
        photos=photos, photo_count=photo_count, vocab_count=vocab_count,
        friends=friends, feedbacks=feedbacks, groups=groups)


# ==========================================
# [測驗題目管理]
# ==========================================
@app.route('/quiz/list')
@admin_login_required
def quiz_list():
    keyword = request.args.get('q', '').strip()
    level = request.args.get('level', '').strip()

    conn = get_db_connection()
    sql = 'SELECT * FROM quiz_question WHERE 1=1'
    params = []
    if keyword:
        sql += ' AND (question LIKE ? OR option_a LIKE ? OR option_b LIKE ? OR option_c LIKE ? OR option_d LIKE ?)'
        kw = f'%{keyword}%'
        params.extend([kw, kw, kw, kw, kw])
    if level:
        sql += ' AND level_tag = ?'
        params.append(level)
    sql += ' ORDER BY id DESC'

    questions = conn.execute(sql, params).fetchall()
    # 所有難度標籤（供篩選下拉）
    levels = conn.execute('SELECT DISTINCT level_tag FROM quiz_question ORDER BY level_tag').fetchall()
    conn.close()
    return render_template('quiz/list.html',
                           questions=questions,
                           levels=[l['level_tag'] for l in levels],
                           keyword=keyword,
                           current_level=level)


@app.route('/quiz/delete/<int:quiz_id>', methods=['POST'])
@admin_login_required
def quiz_delete(quiz_id):
    admin_id = session.get('admin_id')
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    conn = get_db_connection()
    conn.execute('DELETE FROM quiz_question WHERE id = ?', (quiz_id,))
    conn.execute(
        'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
        (admin_id, 'DELETE', 'quiz_question', quiz_id, now))
    conn.commit()
    conn.close()
    return redirect(url_for('quiz_list'))


@app.route('/quiz/edit/<int:quiz_id>', methods=['POST'])
@admin_login_required
def quiz_edit(quiz_id):
    stage = request.form.get('stage', '').strip()
    level_tag = request.form.get('level_tag', '').strip()
    question = request.form.get('question', '').strip()
    option_a = request.form.get('option_a', '').strip()
    option_b = request.form.get('option_b', '').strip()
    option_c = request.form.get('option_c', '').strip()
    option_d = request.form.get('option_d', '').strip()
    correct = request.form.get('correct_answer', '').strip().upper()

    if not all([stage, level_tag, question, option_a, option_b, option_c, option_d, correct]):
        return redirect(url_for('quiz_list'))
    if correct not in ('A', 'B', 'C', 'D'):
        return redirect(url_for('quiz_list'))

    admin_id = session.get('admin_id')
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    conn = get_db_connection()
    conn.execute('''
        UPDATE quiz_question
        SET stage=?, level_tag=?, question=?, option_a=?, option_b=?, option_c=?, option_d=?, correct_answer=?, updated_by=?, updated_at=?
        WHERE id=?
    ''', (stage, level_tag, question, option_a, option_b, option_c, option_d, correct, admin_id, now, quiz_id))
    conn.execute(
        'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
        (admin_id, 'UPDATE', 'quiz_question', quiz_id, now))
    conn.commit()
    conn.close()
    return redirect(url_for('quiz_list'))


@app.route('/quiz/add', methods=['POST'])
@admin_login_required
def quiz_add():
    stage = request.form.get('stage', '').strip()
    level_tag = request.form.get('level_tag', '').strip()
    question = request.form.get('question', '').strip()
    option_a = request.form.get('option_a', '').strip()
    option_b = request.form.get('option_b', '').strip()
    option_c = request.form.get('option_c', '').strip()
    option_d = request.form.get('option_d', '').strip()
    correct = request.form.get('correct_answer', '').strip().upper()

    if not all([stage, level_tag, question, option_a, option_b, option_c, option_d, correct]):
        return redirect(url_for('quiz_list'))
    if correct not in ('A', 'B', 'C', 'D'):
        return redirect(url_for('quiz_list'))

    admin_id = session.get('admin_id')
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    conn = get_db_connection()
    cur = conn.execute('''
        INSERT INTO quiz_question (stage, level_tag, question, option_a, option_b, option_c, option_d, correct_answer, updated_by, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (stage, level_tag, question, option_a, option_b, option_c, option_d, correct, admin_id, now))
    conn.execute(
        'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, created_at) VALUES (?, NULL, ?, ?, ?, ?)',
        (admin_id, 'INSERT', 'quiz_question', cur.lastrowid, now))
    conn.commit()
    conn.close()
    return redirect(url_for('quiz_list'))

# ==========================================
# 📖 模組：單字庫管理 (CRUD)
# ==========================================

# 1. 查 (Read) - 顯示單字列表
@app.route('/vocab/list')
@admin_login_required
def vocab_list():
    vocabs = Vocab.query.all()
    return render_template('vocab/list.html', vocabs=vocabs)

# 2. 增 (Create) - 新增單字
@app.route('/vocab/add', methods=['POST'])
@admin_login_required
def vocab_add():
    word = request.form.get('word')
    kana = request.form.get('kana')
    meaning = request.form.get('meaning')
    
    # 💡 關鍵修正：因為您的模型規定 scene_id 不能是空的 (nullable=False)
    # 這裡我們先預設給 1 (代表預設場景)，未來您可以再把「選擇場景」的功能加進前端！
    scene_id = 1
    admin_id = session.get('admin_id')

    new_vocab = Vocab(
        scene_id=scene_id,
        word=word,
        kana=kana,
        meaning=meaning,
        source='admin',
        updated_by=admin_id,
        updated_at=datetime.utcnow()
    )
    db.session.add(new_vocab)
    db.session.flush()
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=None,
        action='INSERT', target_table='vocab', target_id=new_vocab.id
    ))
    db.session.commit()
    return redirect(url_for('vocab_list'))

# 3. 改 (Update) - 編輯單字
@app.route('/vocab/edit/<int:id>', methods=['POST'])
@admin_login_required
def vocab_edit(id):
    admin_id = session.get('admin_id')
    vocab = Vocab.query.get_or_404(id)
    vocab.word = request.form.get('word')
    vocab.kana = request.form.get('kana')
    vocab.meaning = request.form.get('meaning')
    vocab.updated_by = admin_id
    vocab.updated_at = datetime.utcnow()
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=None,
        action='UPDATE', target_table='vocab', target_id=id
    ))
    db.session.commit()
    return redirect(url_for('vocab_list'))
# 4. 刪 (Delete) - 刪除單字
@app.route('/vocab/delete/<int:id>', methods=['POST'])
@admin_login_required
def vocab_delete(id):
    admin_id = session.get('admin_id')
    vocab = Vocab.query.get_or_404(id)
    db.session.delete(vocab)
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=None,
        action='DELETE', target_table='vocab', target_id=id
    ))
    db.session.commit()
    return redirect(url_for('vocab_list'))



# ==========================================
# 📖 閱讀文章管理 (依等級上架、預設付費解鎖)
# ==========================================
ARTICLE_LEVELS = ['N5', 'N4', 'N3', 'N2', 'N1']
ARTICLE_THEMES = ['日常生活', '日本文化', '旅遊觀光', '職場應用', '流行動漫',
                  '日本美食', '台灣文化', '日本傳說']
DEFAULT_ARTICLE_COST = 50


def _parse_grammar_points(raw_json, grammars_text, vocabs_text):
    """把後台表單的文法／單字欄位整理成 Article.grammar_points 的 JSON 結構。

    優先採用「進階模式」直接貼上的 JSON；否則用一行一筆的簡易格式：
      文法：表現形式 | 中文說明 | 例句
      單字：單字 | 讀音 | 中文意思
    """
    raw_json = (raw_json or '').strip()
    if raw_json:
        try:
            parsed = json.loads(raw_json)
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            raise ValueError('文法解析 JSON 格式錯誤，請確認括號與引號是否正確')

    def split_lines(text):
        return [line.strip() for line in (text or '').splitlines() if line.strip()]

    grammars = []
    for line in split_lines(grammars_text):
        parts = [p.strip() for p in line.split('|')]
        grammars.append({
            'expression': parts[0],
            'meaning': parts[1] if len(parts) > 1 else '',
            'example': parts[2] if len(parts) > 2 else '',
        })

    vocabularies = []
    for line in split_lines(vocabs_text):
        parts = [p.strip() for p in line.split('|')]
        vocabularies.append({
            'word': parts[0],
            'reading': parts[1] if len(parts) > 1 else '',
            'meaning': parts[2] if len(parts) > 2 else '',
        })

    if not grammars and not vocabularies:
        return None
    return {'grammars': grammars, 'vocabularies': vocabularies}


def _grammar_points_to_text(grammar_points):
    """把 JSON 還原成編輯畫面用的一行一筆文字"""
    data = grammar_points if isinstance(grammar_points, dict) else {}
    grammars = '\n'.join(
        ' | '.join([g.get('expression', ''), g.get('meaning', ''), g.get('example', '')]).rstrip(' |')
        for g in data.get('grammars', []) if isinstance(g, dict)
    )
    vocabs = '\n'.join(
        ' | '.join([v.get('word', ''), v.get('reading', ''), v.get('meaning', '')]).rstrip(' |')
        for v in data.get('vocabularies', []) if isinstance(v, dict)
    )
    return {'grammars': grammars, 'vocabs': vocabs}


def _read_article_form(form):
    """讀取並驗證新增／編輯文章的共用欄位，回傳 dict 或丟出 ValueError"""
    title = (form.get('title') or '').strip()
    level = (form.get('level') or '').strip()
    theme = (form.get('theme') or '').strip()
    content = (form.get('content') or '').strip()
    translation = (form.get('translation') or '').strip()

    if not title or not content:
        raise ValueError('標題與日文內容為必填欄位')
    if level not in ARTICLE_LEVELS:
        raise ValueError('請選擇正確的等級 (N5~N1)')
    if not theme:
        raise ValueError('請選擇或輸入文章主題')

    try:
        unlock_cost = int(form.get('unlock_cost') or DEFAULT_ARTICLE_COST)
    except ValueError:
        raise ValueError('解鎖點數必須是數字')
    if unlock_cost <= 0:
        raise ValueError('解鎖點數必須大於 0（新文章一律付費解鎖）')

    grammar_points = _parse_grammar_points(
        form.get('grammar_json'), form.get('grammars_text'), form.get('vocabs_text')
    )

    return {
        'title': title,
        'level': level,
        'theme': theme,
        'content': content,
        'translation': translation or None,
        'unlock_cost': unlock_cost,
        'is_published': form.get('is_published') == 'on',
        'grammar_points': grammar_points,
    }


@app.route('/article/list')
@admin_login_required
def article_list():
    level = request.args.get('level', '')
    keyword = (request.args.get('keyword') or '').strip()

    query = Article.query
    if level in ARTICLE_LEVELS:
        query = query.filter_by(level=level)
    if keyword:
        query = query.filter(Article.title.like('%' + keyword + '%'))
    articles = query.order_by(Article.id.desc()).all()

    # 每篇文章被付費解鎖的次數，讓管理者看得出成效
    unlock_counts = {}
    try:
        conn = get_db_connection()
        rows = conn.execute(
            'SELECT article_id, COUNT(*) AS c FROM unlocked_articles GROUP BY article_id'
        ).fetchall()
        conn.close()
        unlock_counts = {r['article_id']: r['c'] for r in rows}
    except sqlite3.Error:
        unlock_counts = {}

    # 依等級統計，方便確認每個級別各上架了幾篇
    level_stats = []
    for lv in ARTICLE_LEVELS:
        lv_articles = Article.query.filter_by(level=lv).all()
        level_stats.append({
            'level': lv,
            'total': len(lv_articles),
            'published': sum(1 for a in lv_articles if a.is_published is not False),
            'paid': sum(1 for a in lv_articles if not a.is_free),
        })

    return render_template('article/list.html',
                           articles=articles,
                           levels=ARTICLE_LEVELS,
                           themes=ARTICLE_THEMES,
                           level_stats=level_stats,
                           unlock_counts=unlock_counts,
                           default_cost=DEFAULT_ARTICLE_COST,
                           grammar_texts={a.id: _grammar_points_to_text(a.grammar_points) for a in articles},
                           current_level=level,
                           keyword=keyword)


@app.route('/article/add', methods=['POST'])
@admin_login_required
def article_add():
    admin_id = session.get('admin_id')
    try:
        data = _read_article_form(request.form)
    except ValueError as e:
        flash(str(e), 'error')
        return redirect(url_for('article_list'))

    article = Article(
        theme=data['theme'],
        level=data['level'],
        title=data['title'],
        content=data['content'],
        translation=data['translation'],
        grammar_points=data['grammar_points'],
        is_free=False,          # 後台新增的文章一律付費解鎖
        unlock_cost=data['unlock_cost'],
        is_published=data['is_published'],
        created_by=admin_id,
    )
    db.session.add(article)
    db.session.flush()  # 先取得 id 才能寫入操作紀錄
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=None,
        action='CREATE', target_table='articles', target_id=article.id,
        new_value={'title': article.title, 'level': article.level,
                   'unlock_cost': article.unlock_cost, 'is_published': article.is_published}
    ))
    db.session.commit()
    flash('已新增 %s 文章「%s」，需 %d J-pts 解鎖' % (article.level, article.title, article.unlock_cost), 'success')
    return redirect(url_for('article_list', level=article.level))


@app.route('/article/edit/<int:article_id>', methods=['POST'])
@admin_login_required
def article_edit(article_id):
    admin_id = session.get('admin_id')
    article = Article.query.get_or_404(article_id)
    try:
        data = _read_article_form(request.form)
    except ValueError as e:
        flash(str(e), 'error')
        return redirect(url_for('article_list'))

    old_value = {'title': article.title, 'level': article.level,
                 'unlock_cost': article.unlock_cost, 'is_published': article.is_published}

    article.theme = data['theme']
    article.level = data['level']
    article.title = data['title']
    article.content = data['content']
    article.translation = data['translation']
    article.grammar_points = data['grammar_points']
    article.unlock_cost = data['unlock_cost']
    article.is_published = data['is_published']
    article.updated_at = datetime.utcnow()

    db.session.add(SystemLog(
        admin_id=admin_id, user_id=None,
        action='UPDATE', target_table='articles', target_id=article_id,
        old_value=old_value,
        new_value={'title': article.title, 'level': article.level,
                   'unlock_cost': article.unlock_cost, 'is_published': article.is_published}
    ))
    db.session.commit()
    flash('已更新文章「%s」' % article.title, 'success')
    return redirect(url_for('article_list', level=article.level))


@app.route('/article/toggle/<int:article_id>', methods=['POST'])
@admin_login_required
def article_toggle(article_id):
    """上架 / 下架切換：下架後 App 端的文章列表就看不到這篇"""
    admin_id = session.get('admin_id')
    article = Article.query.get_or_404(article_id)
    article.is_published = not (article.is_published is not False)
    article.updated_at = datetime.utcnow()
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=None,
        action='UPDATE', target_table='articles', target_id=article_id,
        new_value={'is_published': article.is_published}
    ))
    db.session.commit()
    flash(('已上架「%s」' if article.is_published else '已下架「%s」') % article.title, 'success')
    return redirect(url_for('article_list', level=request.args.get('level', '')))


@app.route('/article/delete/<int:article_id>', methods=['POST'])
@admin_login_required
def article_delete(article_id):
    admin_id = session.get('admin_id')
    article = Article.query.get_or_404(article_id)
    title = article.title

    # 先清掉關聯資料，避免留下指向已刪除文章的孤兒紀錄
    conn = get_db_connection()
    try:
        conn.execute('DELETE FROM unlocked_articles WHERE article_id = ?', (article_id,))
        conn.execute('DELETE FROM article_progress WHERE article_id = ?', (article_id,))
        conn.execute('DELETE FROM score_record WHERE article_id = ?', (article_id,))
        conn.commit()
    finally:
        conn.close()

    db.session.delete(article)
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=None,
        action='DELETE', target_table='articles', target_id=article_id,
        old_value={'title': title}
    ))
    db.session.commit()
    flash('已刪除文章「%s」' % title, 'success')
    return redirect(url_for('article_list'))


# ==========================================
# 👥 學習成果與社群：學習小組總覽
# ==========================================
# 小組目標類型 -> (顯示名稱, group_member 上對應的個人貢獻欄位)
GROUP_GOAL_MAP = {
    'scans':     ('拍照', 'group_scans'),
    'points':    ('點數', 'group_points'),
    'logins':    ('登入', 'group_logins'),
    'sentences': ('造句', 'group_sentences'),
    'articles':  ('閱讀', 'group_articles'),
}
GROUP_STATUS_LABELS = {'active': '進行中', 'achieved': '已達標', 'expired': '已過週待結算'}


def _parse_db_datetime(value):
    """把 SQLite 取出的時間字串轉成 datetime（資料庫存的是 UTC），失敗回傳 None"""
    if not value:
        return None
    for fmt in ('%Y-%m-%d %H:%M:%S.%f', '%Y-%m-%d %H:%M:%S'):
        try:
            return datetime.strptime(str(value), fmt)
        except ValueError:
            continue
    return None


def _group_status(group, now):
    """與 services/group.py 的 get_my_group 採用同一套規則：
    - 建立時的 ISO 週次已經過去 → 待結算（要等成員下次打開小組頁才會真正結算並解散）
    - 進度達標 → 已達標
    - 其餘 → 進行中
    """
    created = _parse_db_datetime(group['created_at'])
    if created and now.isocalendar()[:2] > created.isocalendar()[:2]:
        return 'expired'
    if (group['current_progress'] or 0) >= (group['goal_target'] or 0):
        return 'achieved'
    return 'active'


@app.route('/group/list')
@admin_login_required
def group_list():
    status_filter = request.args.get('status', '')

    conn = get_db_connection()
    try:
        groups = [dict(g) for g in conn.execute(
            'SELECT id, name, goal_type, goal_target, current_progress, created_at '
            'FROM study_group ORDER BY created_at DESC'
        ).fetchall()]
        members = conn.execute('''
            SELECT gm.group_id, gm.user_id, gm.joined_at,
                   gm.group_scans, gm.group_points, gm.group_logins,
                   gm.group_sentences, gm.group_articles,
                   gm.has_claimed, gm.paid_deposit, gm.deposit_amount,
                   u.username, u.email, u.japanese_level
            FROM group_member gm LEFT JOIN user u ON u.id = gm.user_id
        ''').fetchall()
        pending_rows = conn.execute(
            "SELECT group_id, COUNT(*) AS c FROM group_invite WHERE status = 'pending' GROUP BY group_id"
        ).fetchall()
    except sqlite3.Error:
        groups, members, pending_rows = [], [], []
    finally:
        conn.close()

    members_by_group = {}
    for m in members:
        members_by_group.setdefault(m['group_id'], []).append(dict(m))
    pending_by_group = {r['group_id']: r['c'] for r in pending_rows}

    now = datetime.utcnow()
    counts = {'active': 0, 'achieved': 0, 'expired': 0}
    for g in groups:
        label, contrib_col = GROUP_GOAL_MAP.get(g['goal_type'], (g['goal_type'] or '—', None))
        g['goal_label'] = label
        g['status'] = _group_status(g, now)
        counts[g['status']] += 1

        created = _parse_db_datetime(g['created_at'])
        # 挑戰在建立當週的週日結束（UTC），之後才會被結算
        g['week_end'] = (created + timedelta(days=7 - created.isoweekday())).strftime('%Y-%m-%d') if created else '—'
        g['created_at'] = utc_to_tw(g['created_at'])

        target = g['goal_target'] or 0
        g['percent'] = min(100, round((g['current_progress'] or 0) * 100 / target)) if target else 0
        g['pending_invites'] = pending_by_group.get(g['id'], 0)

        g['members'] = members_by_group.get(g['id'], [])
        g['deposit_total'] = 0
        for m in g['members']:
            m['contribution'] = (m.get(contrib_col) or 0) if contrib_col else None
            # 與 _give_group_reward 相同：舊資料 deposit_amount 為 0 但有付押金時視為 20 點
            m['deposit'] = m['deposit_amount'] or (20 if m['paid_deposit'] else 0)
            m['joined_at'] = utc_to_tw(m['joined_at'])
            g['deposit_total'] += m['deposit']
        g['members'].sort(key=lambda m: m['contribution'] or 0, reverse=True)

    if status_filter in counts:
        shown = [g for g in groups if g['status'] == status_filter]
    else:
        status_filter = ''
        shown = groups

    return render_template('group/list.html',
                           groups=shown,
                           counts=counts,
                           total=len(groups),
                           status_filter=status_filter,
                           status_labels=GROUP_STATUS_LABELS)


# ==========================================
# 📝 學習成果與社群：造句與朗讀紀錄
# ==========================================
RECORD_PAGE_SIZE = 30
# 同一人同一篇文章測驗達到這個次數就特別標示（每次送出都會重新發點數）
REPEAT_THRESHOLD = 3


@app.route('/record/list')
@admin_login_required
def record_list():
    tab = request.args.get('tab', 'sentence')
    if tab not in ('sentence', 'reading'):
        tab = 'sentence'
    keyword = (request.args.get('q') or '').strip()
    page = max(1, request.args.get('page', 1, type=int) or 1)
    offset = (page - 1) * RECORD_PAGE_SIZE
    pattern = '%' + keyword + '%'

    records, summary, total = [], [], 0
    tab_counts = {}
    conn = get_db_connection()
    try:
        for key, table in (('sentence', 'sentence_practice_record'), ('reading', 'score_record')):
            try:
                tab_counts[key] = conn.execute('SELECT COUNT(*) FROM ' + table).fetchone()[0]
            except sqlite3.Error:
                tab_counts[key] = 0

        if tab == 'sentence':
            where = 'WHERE (u.email LIKE ? OR u.username LIKE ? OR r.grammar_point LIKE ?)' if keyword else ''
            params = (pattern, pattern, pattern) if keyword else ()
            total = conn.execute(
                'SELECT COUNT(*) FROM sentence_practice_record r LEFT JOIN user u ON u.id = r.user_id ' + where,
                params
            ).fetchone()[0]
            rows = conn.execute('''
                SELECT r.id, r.user_id, r.grammar_point, r.selected_vocabs, r.user_sentence,
                       r.corrected_sentence, r.ai_feedback, r.score, r.points_earned,
                       r.is_claimed, r.created_at, u.username, u.email
                FROM sentence_practice_record r LEFT JOIN user u ON u.id = r.user_id
                ''' + where + '''
                ORDER BY r.created_at DESC LIMIT ? OFFSET ?
            ''', params + (RECORD_PAGE_SIZE, offset)).fetchall()
            for row in rows:
                r = dict(row)
                try:
                    vocabs = json.loads(r['selected_vocabs']) if r['selected_vocabs'] else []
                except (TypeError, ValueError):
                    vocabs = []
                r['vocabs'] = vocabs if isinstance(vocabs, list) else []
                r['created_at'] = utc_to_tw(r['created_at'])
                records.append(r)

            # 各文法的練習次數與表現，找出學生普遍卡關的文法
            summary = [dict(s) for s in conn.execute('''
                SELECT grammar_point,
                       COUNT(*) AS times,
                       ROUND(AVG(score), 1) AS avg_score,
                       ROUND(100.0 * SUM(CASE WHEN score >= 60 THEN 1 ELSE 0 END) / COUNT(*)) AS pass_rate
                FROM sentence_practice_record
                GROUP BY grammar_point
                ORDER BY times DESC
                LIMIT 8
            ''').fetchall()]
        else:
            where = 'WHERE (u.email LIKE ? OR u.username LIKE ? OR a.title LIKE ?)' if keyword else ''
            params = (pattern, pattern, pattern) if keyword else ()
            total = conn.execute(
                'SELECT COUNT(*) FROM score_record s '
                'LEFT JOIN user u ON u.id = s.user_id LEFT JOIN articles a ON a.id = s.article_id ' + where,
                params
            ).fetchone()[0]
            rows = conn.execute('''
                SELECT s.id, s.user_id, s.article_id, s.score, s.points_earned, s.created_at,
                       u.username, u.email, a.title, a.level,
                       (SELECT COUNT(*) FROM score_record s2
                        WHERE s2.user_id = s.user_id AND s2.article_id = s.article_id
                          AND s2.id <= s.id) AS attempt_no
                FROM score_record s
                LEFT JOIN user u ON u.id = s.user_id
                LEFT JOIN articles a ON a.id = s.article_id
                ''' + where + '''
                ORDER BY s.created_at DESC LIMIT ? OFFSET ?
            ''', params + (RECORD_PAGE_SIZE, offset)).fetchall()
            records = [{**dict(r), 'created_at': utc_to_tw(r['created_at'])} for r in rows]

            # 同一人同一篇文章重複測驗很多次的組合
            summary = [dict(s) for s in conn.execute('''
                SELECT s.user_id, s.article_id, COUNT(*) AS times,
                       SUM(s.points_earned) AS total_points, MAX(s.score) AS best_score,
                       u.username, u.email, a.title
                FROM score_record s
                LEFT JOIN user u ON u.id = s.user_id
                LEFT JOIN articles a ON a.id = s.article_id
                GROUP BY s.user_id, s.article_id
                HAVING COUNT(*) >= ?
                ORDER BY times DESC
                LIMIT 8
            ''', (REPEAT_THRESHOLD,)).fetchall()]
    except sqlite3.Error:
        records, summary, total = [], [], 0
    finally:
        conn.close()

    pages = max(1, -(-total // RECORD_PAGE_SIZE))
    return render_template('record/list.html',
                           tab=tab,
                           keyword=keyword,
                           records=records,
                           summary=summary,
                           total=total,
                           page=page,
                           pages=pages,
                           tab_counts=tab_counts,
                           repeat_threshold=REPEAT_THRESHOLD)


# ==========================================
# 🏅 學習成果與社群：成就徽章
# ==========================================
def _theme_badge_names():
    """主題收集冊徽章 [(徽章名稱, 主題名稱)]。

    直接引用 services/scenario.py 的定義，避免後台與使用者端的主題清單不同步。
    徽章是用「名稱」比對發放的，所以名稱不能在後台修改。
    """
    try:
        from services.scenario import THEME_DEFS, theme_badge_name
        return [(theme_badge_name(t['name']), t['name']) for t in THEME_DEFS if t['name'] != '其他']
    except Exception:
        return []


@app.route('/achievement/list')
@admin_login_required
def achievement_list():
    conn = get_db_connection()
    try:
        user_total = conn.execute('SELECT COUNT(*) FROM user').fetchone()[0]
        achievements = [dict(a) for a in conn.execute('''
            SELECT a.id, a.name, a.description,
                   (SELECT COUNT(*) FROM user_achievement ua WHERE ua.achievement_id = a.id) AS unlock_count
            FROM achievement a ORDER BY a.id
        ''').fetchall()]
        holder_rows = conn.execute('''
            SELECT ua.achievement_id, ua.unlocked_at, u.id AS user_id, u.username, u.email
            FROM user_achievement ua JOIN user u ON u.id = ua.user_id
            ORDER BY ua.unlocked_at DESC
        ''').fetchall()
    except sqlite3.Error:
        user_total, achievements, holder_rows = 0, [], []
    finally:
        conn.close()

    holders = {}
    for h in holder_rows:
        bucket = holders.setdefault(h['achievement_id'], [])
        if len(bucket) < 50:
            bucket.append({**dict(h), 'unlocked_at': utc_to_tw(h['unlocked_at'])})

    theme_badges = dict(_theme_badge_names())  # 徽章名稱 -> 主題名稱
    existing = {a['name'] for a in achievements}
    for a in achievements:
        a['theme_name'] = theme_badges.get(a['name'])
        a['holders'] = holders.get(a['id'], [])
        a['unlock_rate'] = round(a['unlock_count'] * 100 / user_total) if user_total else 0
    missing = [(badge, theme) for badge, theme in theme_badges.items() if badge not in existing]

    return render_template('achievement/list.html',
                           achievements=achievements,
                           missing=missing,
                           user_total=user_total)


@app.route('/achievement/sync_theme', methods=['POST'])
@admin_login_required
def achievement_sync_theme():
    """補建缺少的主題徽章：資料庫少了某個徽章時，使用者集滿該主題也拿不到徽章"""
    admin_id = session.get('admin_id')
    existing = {a.name for a in Achievement.query.all()}
    created = []
    for badge, theme in _theme_badge_names():
        if badge in existing:
            continue
        ach = Achievement(
            name=badge,
            description='集滿「%s」主題收集冊的所有官方單字' % theme,
            updated_by=admin_id,
        )
        db.session.add(ach)
        db.session.flush()
        db.session.add(SystemLog(
            admin_id=admin_id, user_id=None,
            action='CREATE', target_table='achievement', target_id=ach.id,
            new_value={'name': badge}
        ))
        created.append(badge)
    db.session.commit()

    if created:
        flash('已補建 %d 個主題徽章：%s' % (len(created), '、'.join(created)), 'success')
    else:
        flash('主題徽章都已存在，不需要補建', 'success')
    return redirect(url_for('achievement_list'))


# ==========================================
# 🖼️ 大頭貼與照片的顯示規則（首頁、使用者、照片管控共用）
# ==========================================
# App 內建的表情符號頭像與背景色，對應 jpn_learning_app/lib/widgets/common/user_avatar.dart 的 kAvatarPresets
AVATAR_PRESET_COLORS = {
    '🐱': '#FFAB91', '🐶': '#FFCC80', '🐼': '#CFD8DC', '🐨': '#80DEEA',
    '🐸': '#A5D6A7', '🦊': '#FFB74D', '🐰': '#F48FB1', '🐻': '#BCAAA4',
    '🐯': '#FFD54F', '🐮': '#DCE775', '🦁': '#FFE082', '🐧': '#80CBC4',
    '🐙': '#CE93D8', '🦋': '#B39DDB', '🐢': '#80CBC4', '🦄': '#F8BBD9',
}
PHOTO_DIR = os.path.join(BASE_DIR, 'static', 'photos')


@app.template_global()
def avatar_info(avatar):
    """判斷 user.avatar 要怎麼顯示，規則與 App 的 UserAvatar 相同：
    - App 內建的表情符號 → {'type': 'emoji', 'emoji', 'bg'}
    - http 網址、data: URL、合法 base64 → {'type': 'image', 'src'}
    - 空值或解不開的內容（例如舊版存進去的 '__gallery__'）→ None，頁面改顯示名字首字
    """
    if not avatar:
        return None
    if avatar in AVATAR_PRESET_COLORS:
        return {'type': 'emoji', 'emoji': avatar, 'bg': AVATAR_PRESET_COLORS[avatar]}
    if avatar.startswith('http') or avatar.startswith('data:'):
        return {'type': 'image', 'src': avatar}
    try:
        base64.b64decode(avatar, validate=True)
    except (binascii.Error, ValueError):
        return None
    return {'type': 'image', 'src': 'data:image/jpeg;base64,' + avatar}


@app.template_global()
def photo_src(image_path):
    """把 user_photo.image_path 轉成網址，照片檔不存在時回傳 None。

    API 存的是 '/static/photos/<檔名>'，較早的種子資料只存檔名，兩種實際上都放在 static/photos。
    """
    if not image_path:
        return None
    if image_path.startswith('http'):
        return image_path
    filename = os.path.basename(image_path)
    if not filename or not os.path.isfile(os.path.join(PHOTO_DIR, filename)):
        return None
    return url_for('static', filename='photos/' + filename)


# ==========================================
# 🎓 校園教育版：教師端核心功能
# ==========================================
# 老師用自己的 User 帳號（account_type='teacher'）從登入頁的「老師」分頁登入，
# 登入後 session['role'] = 'teacher'、session['teacher_user_id'] = User.id。
# 老師只看得到自己建立的班級；管理者不會進到這些頁面。
# 老師帳號由 super_admin 在「教師帳號管理」建立，老師不能自己註冊。
from services.teacher_service import (
    create_classroom, regenerate_join_code,
    toggle_classroom_open, get_classroom_list, get_classroom_student_stats,
    get_student_detail, create_sentence_assignment, create_article_assignment,
    get_assignment_submissions_list, grade_submission
)
from models import Classroom, ClassroomMember, Assignment, AssignmentSubmission


def _own_classroom(classroom_id):
    """回傳目前登入老師自己的班級；若是 super_admin 則可管理所有班級"""
    if session.get('role') == 'super_admin':
        return Classroom.query.get(classroom_id)
    return Classroom.query.filter_by(id=classroom_id, teacher_id=session.get('teacher_user_id')).first()


def _own_assignment(assignment_id):
    assignment = Assignment.query.get(assignment_id)
    if not assignment or not _own_classroom(assignment.classroom_id):
        return None
    return assignment


@app.route('/teacher/classrooms')
@teacher_required
def teacher_classrooms():
    """班級列表與隨機碼管理首頁（老師只看自己，super_admin 看全部）"""
    show_archived = request.args.get('show') == 'archived'
    teacher_id = None if session.get('role') == 'super_admin' else session['teacher_user_id']
    classrooms = get_classroom_list(teacher_id=teacher_id, archived=show_archived)
    return render_template('teacher/classroom_list.html', classrooms=classrooms, show_archived=show_archived)


@app.route('/teacher/pending')
@teacher_required
def teacher_pending():
    """待審核的老師登入後只會看到這一頁"""
    teacher = User.query.get(session.get('teacher_user_id') or 0)
    if not teacher or (getattr(teacher, 'teacher_status', None) or 'approved') == 'approved':
        return redirect(url_for('teacher_classrooms'))
    return render_template('teacher/pending.html', teacher=teacher)


@app.route('/teacher/classroom/create', methods=['POST'])
@teacher_required
def teacher_classroom_create():
    """教師建立新班級"""
    name = request.form.get('name', '').strip()
    description = request.form.get('description', '').strip()
    if not name:
        flash("請填寫班級名稱", "danger")
        return redirect(url_for('teacher_classrooms'))
    if session.get('role') != 'teacher' or not session.get('teacher_user_id'):
        flash("管理者無法代替老師建立班級，請以老師身分登入", "danger")
        return redirect(url_for('teacher_classrooms'))

    c = create_classroom(session['teacher_user_id'], name, description)
    flash(f"班級「{c.name}」建立成功！學生加入隨機碼為：{c.join_code}", "success")
    return redirect(url_for('teacher_classrooms'))


@app.route('/teacher/classroom/<int:classroom_id>/regenerate_code', methods=['POST'])
@teacher_required
def teacher_classroom_regenerate_code(classroom_id):
    """重新生成班級隨機碼"""
    if not _own_classroom(classroom_id):
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    new_code = regenerate_join_code(classroom_id)
    flash(f"班級隨機碼已更新為：{new_code}", "success")
    return redirect(url_for('teacher_classrooms'))


@app.route('/teacher/classroom/<int:classroom_id>/toggle_open', methods=['POST'])
@teacher_required
def teacher_classroom_toggle_open(classroom_id):
    """切換班級開放或關閉加入"""
    if not _own_classroom(classroom_id):
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    is_open = toggle_classroom_open(classroom_id)
    status_text = "開放" if is_open else "關閉"
    flash(f"已將班級狀態切換為【{status_text}加入】", "info")
    return redirect(url_for('teacher_classrooms'))


@app.route('/teacher/classroom/<int:classroom_id>/students')
@teacher_required
def teacher_classroom_students(classroom_id):
    """依班級檢視學生學習狀況與名冊"""
    data = get_classroom_student_stats(classroom_id) if _own_classroom(classroom_id) else None
    if not data:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    return render_template('teacher/student_progress.html', data=data)


@app.route('/teacher/student/<int:student_id>/detail')
@teacher_required
def teacher_student_detail(student_id):
    """取得單一學生的詳細學習紀錄 (AJAX)"""
    classroom_id = request.args.get('classroom_id', type=int)
    if not classroom_id:
        return jsonify({"error": "缺少 classroom_id"}), 400
    if not _own_classroom(classroom_id):
        return jsonify({"error": "找不到該班級"}), 404
    detail = get_student_detail(student_id, classroom_id)
    if not detail:
        return jsonify({"error": "找不到學生資料"}), 404
    return jsonify(detail)


@app.route('/teacher/classroom/<int:classroom_id>/assignments')
@teacher_required
def teacher_classroom_assignments(classroom_id):
    """班級作業總覽清單"""
    classroom = _own_classroom(classroom_id)
    if not classroom:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))

    assignments = Assignment.query.filter_by(classroom_id=classroom_id).order_by(Assignment.created_at.desc()).all()
    member_count = ClassroomMember.query.filter_by(classroom_id=classroom_id).count()

    for a in assignments:
        a.total_students = member_count
        a.submitted_count = AssignmentSubmission.query.filter_by(assignment_id=a.id).filter(
            AssignmentSubmission.status.in_(['submitted', 'graded'])
        ).count()

    return render_template('teacher/assignment_list.html', classroom=classroom, assignments=assignments)


@app.route('/teacher/classroom/<int:classroom_id>/assignment/create', methods=['GET', 'POST'])
@teacher_required
def teacher_assignment_create(classroom_id):
    """出題新作業：造句挑戰 vs 文章閱讀（支援上傳文章、選擇題、是非題）"""
    classroom = _own_classroom(classroom_id)
    if not classroom:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))

    if request.method == 'POST':
        task_type = request.form.get('task_type', 'sentence')
        title = request.form.get('title', '').strip()
        instructions = request.form.get('instructions', '').strip()
        due_at_str = request.form.get('due_at')
        due_at = None
        if due_at_str:
            try:
                due_at = datetime.fromisoformat(due_at_str)
            except Exception:
                pass

        if not title:
            flash("請填寫作業標題", "danger")
            return redirect(url_for('teacher_assignment_create', classroom_id=classroom_id))

        if task_type == 'sentence':
            grammar = request.form.get('grammar_point', '').strip()
            vocabs_raw = request.form.get('required_vocabs', '')
            vocabs = [v.strip() for v in vocabs_raw.replace('，', ',').split(',') if v.strip()]
            pass_score = request.form.get('pass_score', 60)
            create_sentence_assignment(classroom_id, title, instructions, grammar, vocabs, pass_score, due_at)
            flash(f"造句挑戰作業「{title}」發布成功！", "success")

        elif task_type == 'article':
            source = request.form.get('article_source', 'existing')
            new_art = None
            art_id = None
            if source == 'new':
                new_title = request.form.get('new_art_title', '').strip()
                new_content = request.form.get('new_art_content', '').strip()
                if not new_title or not new_content:
                    flash("上傳新文章時，標題與日文內文為必填！", "danger")
                    return redirect(url_for('teacher_assignment_create', classroom_id=classroom_id))
                new_art = {
                    'title': new_title,
                    'level': request.form.get('new_art_level', 'N3'),
                    'content': new_content,
                    'translation': request.form.get('new_art_translation', '').strip()
                }
            else:
                art_id = request.form.get('article_id', type=int)

            has_quiz = bool(request.form.get('has_quiz'))
            questions_json = request.form.get('questions_json', '[]')
            try:
                questions = json.loads(questions_json) if has_quiz else []
            except Exception:
                questions = []

            create_article_assignment(
                classroom_id, title, instructions,
                article_id=art_id, new_article=new_art,
                has_quiz=has_quiz, questions=questions, due_at=due_at
            )
            flash(f"文章閱讀作業「{title}」發布成功！", "success")

        return redirect(url_for('teacher_classroom_assignments', classroom_id=classroom_id))

    existing_articles = Article.query.filter(Article.is_published.isnot(False)).order_by(Article.level, Article.id).all()
    return render_template('teacher/assignment_create.html', classroom=classroom, existing_articles=existing_articles)


@app.route('/teacher/assignment/<int:assignment_id>/submissions')
@teacher_required
def teacher_assignment_submissions(assignment_id):
    """作業繳交名單與批閱給分"""
    data = get_assignment_submissions_list(assignment_id) if _own_assignment(assignment_id) else None
    if not data:
        flash("找不到該作業", "danger")
        return redirect(url_for('teacher_classrooms'))
    return render_template('teacher/assignment_submissions.html', data=data)


@app.route('/teacher/submission/<int:submission_id>/grade', methods=['POST'])
@teacher_required
def teacher_submission_grade(submission_id):
    """批閱儲存成績與評語"""
    score = request.form.get('score')
    teacher_comment = request.form.get('teacher_comment', '')
    sub = AssignmentSubmission.query.get(submission_id)
    if not sub or not _own_assignment(sub.assignment_id):
        flash("找不到該繳交紀錄", "danger")
        return redirect(url_for('teacher_classrooms'))

    grade_submission(submission_id, score, teacher_comment)
    flash("批閱成績與教師評語已成功儲存！", "success")
    return redirect(url_for('teacher_assignment_submissions', assignment_id=sub.assignment_id))


# ---- 班級：改名、封存 ----
@app.route('/teacher/classroom/<int:classroom_id>/edit', methods=['POST'])
@teacher_required
def teacher_classroom_edit(classroom_id):
    classroom = _own_classroom(classroom_id)
    if not classroom:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    name = request.form.get('name', '').strip()
    if not name:
        flash("請填寫班級名稱", "danger")
        return redirect(url_for('teacher_classrooms'))
    classroom.name = name
    classroom.description = request.form.get('description', '').strip()
    db.session.commit()
    flash(f"班級「{name}」已更新", "success")
    return redirect(url_for('teacher_classrooms'))


@app.route('/teacher/classroom/<int:classroom_id>/archive', methods=['POST'])
@teacher_required
def teacher_classroom_archive(classroom_id):
    """封存／取消封存。封存後學生在 App 看不到這個班級與作業，資料全部保留"""
    classroom = _own_classroom(classroom_id)
    if not classroom:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    classroom.is_archived = not bool(classroom.is_archived)
    if classroom.is_archived:
        classroom.is_open = False   # 封存的班級不該再有人加入
    db.session.commit()
    if classroom.is_archived:
        flash(f"班級「{classroom.name}」已封存，可在「已封存的班級」中取消封存", "info")
        return redirect(url_for('teacher_classrooms'))
    flash(f"班級「{classroom.name}」已取消封存", "success")
    return redirect(url_for('teacher_classrooms'))


# ---- 學生名冊：改顯示名稱、移出班級 ----
def _own_member(classroom_id, student_id):
    if not _own_classroom(classroom_id):
        return None
    return ClassroomMember.query.filter_by(classroom_id=classroom_id, student_id=student_id).first()


@app.route('/teacher/classroom/<int:classroom_id>/student/<int:student_id>/rename', methods=['POST'])
@teacher_required
def teacher_student_rename(classroom_id, student_id):
    member = _own_member(classroom_id, student_id)
    if not member:
        flash("找不到該學生", "danger")
        return redirect(url_for('teacher_classrooms'))
    member.display_name = (request.form.get('display_name') or '').strip() or None
    db.session.commit()
    flash("學生顯示名稱已更新", "success")
    return redirect(url_for('teacher_classroom_students', classroom_id=classroom_id))


@app.route('/teacher/classroom/<int:classroom_id>/student/<int:student_id>/remove', methods=['POST'])
@teacher_required
def teacher_student_remove(classroom_id, student_id):
    """把學生移出班級：只刪成員關係，已繳交的作業紀錄保留，學生之後可用隨機碼重新加入"""
    member = _own_member(classroom_id, student_id)
    if not member:
        flash("找不到該學生", "danger")
        return redirect(url_for('teacher_classrooms'))
    name = member.display_name or (member_user.username if (member_user := User.query.get(student_id)) else '學生')
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=student_id,
        action='DELETE', target_table='classroom_member', target_id=member.id,
        old_value={'classroom_id': classroom_id, 'display_name': member.display_name}
    ))
    db.session.delete(member)
    db.session.commit()
    flash(f"已將「{name}」移出班級", "success")
    return redirect(url_for('teacher_classroom_students', classroom_id=classroom_id))


# ---- 作業：編輯、發布／下架、刪除 ----
@app.route('/teacher/assignment/<int:assignment_id>/edit', methods=['POST'])
@teacher_required
def teacher_assignment_edit(assignment_id):
    """只改標題、說明、截止日與發布狀態；題目內容要改請刪除重出，避免學生已作答的內容被改掉"""
    assignment = _own_assignment(assignment_id)
    if not assignment:
        flash("找不到該作業", "danger")
        return redirect(url_for('teacher_classrooms'))
    title = request.form.get('title', '').strip()
    if not title:
        flash("請填寫作業標題", "danger")
        return redirect(url_for('teacher_classroom_assignments', classroom_id=assignment.classroom_id))
    assignment.title = title
    assignment.instructions = request.form.get('instructions', '').strip()
    due_at_str = request.form.get('due_at')
    assignment.due_at = None
    if due_at_str:
        try:
            assignment.due_at = datetime.fromisoformat(due_at_str)
        except ValueError:
            pass
    assignment.is_published = request.form.get('is_published') == 'on'
    db.session.commit()
    flash(f"作業「{title}」已更新", "success")
    return redirect(url_for('teacher_classroom_assignments', classroom_id=assignment.classroom_id))


@app.route('/teacher/assignment/<int:assignment_id>/toggle_publish', methods=['POST'])
@teacher_required
def teacher_assignment_toggle_publish(assignment_id):
    """下架後學生在 App 看不到這份作業，已繳交的紀錄保留"""
    assignment = _own_assignment(assignment_id)
    if not assignment:
        flash("找不到該作業", "danger")
        return redirect(url_for('teacher_classrooms'))
    assignment.is_published = not bool(assignment.is_published)
    db.session.commit()
    flash(("作業「%s」已發布，學生現在看得到" if assignment.is_published else "作業「%s」已下架，學生看不到了") % assignment.title, "info")
    return redirect(url_for('teacher_classroom_assignments', classroom_id=assignment.classroom_id))


@app.route('/teacher/assignment/<int:assignment_id>/delete', methods=['POST'])
@teacher_required
def teacher_assignment_delete(assignment_id):
    """刪除作業，學生的繳交與批閱紀錄一併刪除（模型有 cascade）"""
    assignment = _own_assignment(assignment_id)
    if not assignment:
        flash("找不到該作業", "danger")
        return redirect(url_for('teacher_classrooms'))
    classroom_id, title = assignment.classroom_id, assignment.title
    submission_count = AssignmentSubmission.query.filter_by(assignment_id=assignment_id).count()
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=session.get('teacher_user_id'),
        action='DELETE', target_table='assignment', target_id=assignment_id,
        old_value={'title': title, 'classroom_id': classroom_id, 'submissions': submission_count}
    ))
    db.session.delete(assignment)
    db.session.commit()
    flash(f"作業「{title}」已刪除（含 {submission_count} 份繳交紀錄）", "success")
    return redirect(url_for('teacher_classroom_assignments', classroom_id=classroom_id))


# ==========================================
# 🎓 校園教育版：教師帳號管理（super_admin）
# ==========================================
# 老師帳號存在 user 表（account_type='teacher'），不能自己註冊，只能由這裡建立。
# 這種帳號只能從後台登入頁的「老師」分頁登入，App 的兩個入口都會擋下來。
@app.route('/teacher_account/list')
@super_admin_required
def teacher_account_list():
    teachers = User.query.filter_by(account_type=AccountType.TEACHER).order_by(User.created_at.desc()).all()
    classroom_counts = dict(
        db.session.query(Classroom.teacher_id, func.count(Classroom.id)).group_by(Classroom.teacher_id).all()
    )
    rows = [{
        'id': t.id,
        'username': t.username,
        'email': t.email,
        'is_suspended': bool(t.is_suspended),
        'status': t.teacher_status or 'approved',
        'classroom_count': classroom_counts.get(t.id, 0),
        'created_at': utc_to_tw(t.created_at.strftime('%Y-%m-%d %H:%M:%S')) if t.created_at else '',
    } for t in teachers]
    rows.sort(key=lambda r: 0 if r['status'] == 'pending' else 1)  # 待審核排最前面
    pending_count = sum(1 for r in rows if r['status'] == 'pending')
    return render_template('teacher_account/list.html', teachers=rows, pending_count=pending_count)


@app.route('/teacher_account/approve/<int:user_id>', methods=['POST'])
@super_admin_required
def teacher_account_approve(user_id):
    """確認這個學校帳號真的是老師：核准後才能建班級"""
    admin_id = session.get('admin_id')
    teacher = User.query.filter_by(id=user_id, account_type=AccountType.TEACHER).first_or_404()
    teacher.teacher_status = 'approved'
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=teacher.id,
        action='UPDATE', target_table='user', target_id=teacher.id,
        new_value={'teacher_status': 'approved'}
    ))
    db.session.commit()
    flash(f'已核准「{teacher.username}」的老師身分，老師重新整理頁面即可建立班級', 'success')
    return redirect(url_for('teacher_account_list'))


@app.route('/teacher_account/reject/<int:user_id>', methods=['POST'])
@super_admin_required
def teacher_account_reject(user_id):
    """拒絕待審核的申請：直接移除帳號，之後同一個帳號再登入會重新進入待審核"""
    admin_id = session.get('admin_id')
    teacher = User.query.filter_by(id=user_id, account_type=AccountType.TEACHER).first_or_404()
    if (teacher.teacher_status or 'approved') != 'pending':
        flash('只能拒絕「待審核」的帳號；已核准的老師請改用「停用」', 'error')
        return redirect(url_for('teacher_account_list'))
    if Classroom.query.filter_by(teacher_id=teacher.id).count():
        flash('這個帳號已有班級資料，無法移除，請改用「停用」', 'error')
        return redirect(url_for('teacher_account_list'))
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=None,
        action='DELETE', target_table='user', target_id=teacher.id,
        old_value={'email': teacher.email, 'username': teacher.username, 'teacher_status': 'pending'}
    ))
    db.session.delete(teacher)
    db.session.commit()
    flash(f'已拒絕並移除「{teacher.username}」（{teacher.email}）的申請', 'success')
    return redirect(url_for('teacher_account_list'))


def _validate_password(pw):
    if len(pw or '') < 6:
        return '密碼至少需要 6 個字元'
    return None


@app.route('/teacher_account/add', methods=['POST'])
@super_admin_required
def teacher_account_add():
    admin_id = session.get('admin_id')
    email = (request.form.get('email') or '').strip()
    username = (request.form.get('username') or '').strip()
    password = request.form.get('password') or ''

    error = None
    if not email or '@' not in email:
        error = '請輸入正確的 Email'
    elif not username:
        error = '請輸入老師姓名'
    elif _validate_password(password):
        error = _validate_password(password)
    elif User.query.filter_by(email=email).first():
        error = f'Email「{email}」已經被使用'
    elif User.query.filter_by(username=username).first():
        error = f'名稱「{username}」已經被使用，請換一個（例如加上科目或班級）'
    if error:
        flash(error, 'error')
        return redirect(url_for('teacher_account_list'))

    teacher = User(
        email=email,
        username=username,
        password_hash=generate_password_hash(password),
        account_type=AccountType.TEACHER,
    )
    db.session.add(teacher)
    db.session.flush()
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=teacher.id,
        action='CREATE', target_table='user', target_id=teacher.id,
        new_value={'email': email, 'username': username, 'account_type': AccountType.TEACHER}
    ))
    db.session.commit()
    flash(f'已建立老師帳號「{username}」，請將 Email 與密碼交給老師，從登入頁的「老師」分頁登入', 'success')
    return redirect(url_for('teacher_account_list'))


@app.route('/teacher_account/reset_password/<int:user_id>', methods=['POST'])
@super_admin_required
def teacher_account_reset_password(user_id):
    admin_id = session.get('admin_id')
    teacher = User.query.filter_by(id=user_id, account_type=AccountType.TEACHER).first_or_404()
    password = request.form.get('password') or ''
    error = _validate_password(password)
    if error:
        flash(error, 'error')
        return redirect(url_for('teacher_account_list'))
    teacher.password_hash = generate_password_hash(password)
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=teacher.id,
        action='UPDATE', target_table='user', target_id=teacher.id,
        new_value={'password': 'reset'}
    ))
    db.session.commit()
    flash(f'已重設「{teacher.username}」的密碼', 'success')
    return redirect(url_for('teacher_account_list'))


@app.route('/teacher_account/toggle/<int:user_id>', methods=['POST'])
@super_admin_required
def teacher_account_toggle(user_id):
    """停用／啟用老師帳號：停用後無法登入後台，已建立的班級與隨機碼保留"""
    admin_id = session.get('admin_id')
    teacher = User.query.filter_by(id=user_id, account_type=AccountType.TEACHER).first_or_404()
    teacher.is_suspended = not bool(teacher.is_suspended)
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=teacher.id,
        action='UPDATE', target_table='user', target_id=teacher.id,
        new_value={'is_suspended': teacher.is_suspended}
    ))
    db.session.commit()
    flash(('已停用「%s」' if teacher.is_suspended else '已啟用「%s」') % teacher.username, 'success')
    return redirect(url_for('teacher_account_list'))


if __name__ == '__main__':
    # host='0.0.0.0'：容器內要綁全介面，外面才連得到（本機直接跑也不影響）
    app.run(host='0.0.0.0', debug=True, port=5001)



