import sqlite3
import os
from datetime import datetime, timedelta
from flask import Flask, render_template, request, redirect, url_for
import os
from flask import session, flash, redirect, url_for, render_template, request
from functools import wraps
from utils.db import db
from models import Admin
from models import Admin, Vocab  # <--- 加上 Vocab


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
path1 = os.path.join(BASE_DIR, 'instance', 'jlens.db')
path2 = os.path.join(BASE_DIR, 'jlens.db')
DB_FILE_PATH = path1 if os.path.exists(path1) else path2


app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + DB_FILE_PATH
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)
# ==========================================
# 🚀 自動路徑偵測
# ==========================================
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
# 優先嘗試 instance 下的路徑
DB_FILE_PATH = os.path.join(BASE_DIR, 'instance', 'jlens.db')

def get_db_connection():
    conn = sqlite3.connect(DB_FILE_PATH, check_same_thread=False)
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
        return f(*args, **kwargs)
    return decorated_function

def super_admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'admin_user' not in session:
            return redirect(url_for('admin_login'))
        if session.get('role') != 'super_admin':
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
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
            
            print(f"✅ 登入成功: {username} (權限: {admin.role})")
            return redirect(url_for('admin_dashboard')) # 密碼正確去儀表板
        else:
            print(f"❌ 登入失敗: {username} (密碼錯誤)")
            return render_template('admin_login.html', error="密碼錯誤，請重新輸入")
            
    return render_template('admin_login.html')

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
            "SELECT COUNT(*) as cnt FROM user_subscription WHERE plan_id=? AND status='active'",
            (p['id'],)
        ).fetchone()
        p['active_users'] = count['cnt'] if count else 0
    conn.close()
    return render_template('plan/list.html', plans=plans)

@app.route('/plan/edit/<int:plan_id>', methods=['POST'])
@super_admin_required
def plan_edit(plan_id):
    name = request.form.get('name', '').strip()
    price_monthly = request.form.get('price_monthly') or None
    price_yearly  = request.form.get('price_yearly') or None
    pts_monthly   = request.form.get('points_grant_monthly') or None
    pts_yearly    = request.form.get('points_grant_yearly') or None
    if name:
        conn = get_db_connection()
        conn.execute('''UPDATE subscription_plan SET name=?, price_monthly=?, price_yearly=?,
                        points_grant_monthly=?, points_grant_yearly=? WHERE id=?''',
                     (name,
                      int(price_monthly) if price_monthly else None,
                      int(price_yearly)  if price_yearly  else None,
                      int(pts_monthly)   if pts_monthly   else None,
                      int(pts_yearly)    if pts_yearly    else None,
                      plan_id))
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
        conn = get_db_connection()
        conn.execute('INSERT INTO point_package (name, points, price, tag, description, is_active) VALUES (?,?,?,?,?,1)',
                     (name, int(points), int(price), tag or None, desc or None))
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
        conn = get_db_connection()
        conn.execute('UPDATE point_package SET name=?, points=?, price=?, tag=?, description=? WHERE id=?',
                     (name, int(points), int(price), tag or None, desc or None, pkg_id))
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
    query = '''
        SELECT p.id, p.points, p.price, p.payment_method, p.created_at,
               u.username, u.email
        FROM point_transaction p
        LEFT JOIN user u ON p.user_id = u.id
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
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    conn = get_db_connection()
    conn.execute('UPDATE feedback SET reply = ?, replied_at = ? WHERE id = ?',
                 (reply, now, feedback_id))
    conn.commit()
    conn.close()
    return redirect(url_for('feedback_list'))

@app.route('/feedback/delete/<int:feedback_id>', methods=['POST'])
@admin_login_required
def feedback_delete(feedback_id):
    conn = get_db_connection()
    conn.execute('DELETE FROM feedback WHERE id = ?', (feedback_id,))
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

    last_seen_col    = 'u.last_seen_at'          if has_last_seen    else 'NULL as last_seen_at'
    is_premium_col   = 'u.is_premium'            if has_is_premium   else '0 as is_premium'
    trial_used_col   = 'u.trial_used'            if has_trial_used   else '0 as trial_used'
    sub_end_col      = 'u.subscription_end_date' if has_sub_end      else 'NULL as subscription_end_date'
    is_suspended_col = 'u.is_suspended'          if has_is_suspended else '0 as is_suspended'

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
        groups = conn.execute('''
            SELECT sg.id, sg.name, sg.description, gm.role, gm.joined_at
            FROM group_member gm JOIN study_group sg ON sg.id = gm.group_id
            WHERE gm.user_id = ?
        ''', (user_id,)).fetchall()
        groups = [{**dict(g), 'joined_at': utc_to_tw(g['joined_at'] or '')} for g in groups]
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
    conn = get_db_connection()
    conn.execute('DELETE FROM quiz_question WHERE id = ?', (quiz_id,))
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

    conn = get_db_connection()
    conn.execute('''
        UPDATE quiz_question
        SET stage=?, level_tag=?, question=?, option_a=?, option_b=?, option_c=?, option_d=?, correct_answer=?
        WHERE id=?
    ''', (stage, level_tag, question, option_a, option_b, option_c, option_d, correct, quiz_id))
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

    conn = get_db_connection()
    conn.execute('''
        INSERT INTO quiz_question (stage, level_tag, question, option_a, option_b, option_c, option_d, correct_answer)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', (stage, level_tag, question, option_a, option_b, option_c, option_d, correct))
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

    new_vocab = Vocab(
        scene_id=scene_id, 
        word=word, 
        kana=kana, 
        meaning=meaning
    )
    db.session.add(new_vocab)
    db.session.commit()
    return redirect(url_for('vocab_list'))

# 3. 改 (Update) - 編輯單字
@app.route('/vocab/edit/<int:id>', methods=['POST'])
@admin_login_required
def vocab_edit(id):
    vocab = Vocab.query.get_or_404(id)
    vocab.word = request.form.get('word')
    vocab.kana = request.form.get('kana')
    vocab.meaning = request.form.get('meaning')
    
    # 移除了原本會報錯的 vocab.level = ...
    
    db.session.commit()
    return redirect(url_for('vocab_list'))
# 4. 刪 (Delete) - 刪除單字
@app.route('/vocab/delete/<int:id>', methods=['POST'])
@admin_login_required
def vocab_delete(id):
    vocab = Vocab.query.get_or_404(id)
    db.session.delete(vocab)
    db.session.commit()
    return redirect(url_for('vocab_list'))



if __name__ == '__main__':
    app.run(debug=True, port=5001)



