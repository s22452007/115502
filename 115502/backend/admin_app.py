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
import unicodedata
import base64
import binascii
from datetime import datetime, timedelta
from flask import Flask, render_template, request, redirect, url_for
import os
from flask import session, flash, redirect, url_for, render_template, request, jsonify
from functools import wraps
from utils.db import db, ensure_model_columns
from models import Admin, Vocab, SystemLog, Article, Achievement, User, AccountType, School
from school_seed import DEFAULT_STUDENT_ID_PATTERN, OLD_DEFAULT_STUDENT_ID_PATTERN
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
# TEACHER_GOOGLE_ALLOWED_EMAILS：例外名單（逗號分隔），列在這裡的 Email 即使 @ 前是學號也能登入老師後台
TEACHER_GOOGLE_ALLOWED_EMAILS = {e.strip().lower() for e in (os.getenv('TEACHER_GOOGLE_ALLOWED_EMAILS') or '').split(',') if e.strip()}

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

# jlens.db 不進 git、每位組員電腦上都是自己的資料庫；模型新增欄位後（例如 admin.last_login_at）
# 舊資料庫一查就 no such column 而 500。啟動時自動建缺少的表、補缺少的欄位，pull 完直接能跑。
with app.app_context():
    try:
        db.create_all()
        for _table, _column in ensure_model_columns(db):
            print(f'[DB] 自動補上缺少的欄位 {_table}.{_column}')
    except Exception as _e:
        print(f'[DB] 自動補欄位失敗（請手動執行 upgrade_db.py 或聯繫負責人）：{_e}')


@app.context_processor
def _inject_sidebar_badges():
    """側欄的紅色數字：還沒回覆的回饋筆數、等待審核的老師人數（管理者登入時才查）"""
    if 'admin_user' not in session or session.get('role') == 'teacher':
        return {'sidebar_feedback_pending': 0, 'sidebar_teacher_pending': 0}
    n = pending_teachers = 0
    try:
        conn = get_db_connection()
        try:
            n = conn.execute('SELECT COUNT(*) FROM feedback WHERE reply IS NULL OR reply = ""').fetchone()[0]
            pending_teachers = conn.execute(
                "SELECT COUNT(*) FROM user WHERE account_type = 'teacher' AND teacher_status = 'pending'"
            ).fetchone()[0]
        finally:
            conn.close()
    except sqlite3.Error:
        pass
    return {'sidebar_feedback_pending': n, 'sidebar_teacher_pending': pending_teachers}


@app.context_processor
def _inject_google_login_settings():
    """登入頁用：有設定 client ID 才顯示「用學校 Google 帳號登入」按鈕"""
    return {'google_client_id': GOOGLE_WEB_CLIENT_ID,
            'teacher_domains': TEACHER_GOOGLE_DOMAINS,
            'teacher_domain_labels': _teacher_domain_labels()}


@app.context_processor
def _inject_teacher_account_card():
    """老師端側欄點頭像跳出的帳號小卡（像 Google 的帳號選單）要用的資料"""
    if session.get('role') != 'teacher' or not session.get('teacher_user_id'):
        return {}
    teacher = User.query.get(session['teacher_user_id'])
    if not teacher:
        return {}
    # 判斷 Google 帳號要算一次密碼雜湊（scrypt，有點慢），每個 session 只算一次；改密碼時會更新
    if 'teacher_google_only' not in session:
        session['teacher_google_only'] = _teacher_google_only(teacher)
    # 名字還是 Email 前段（App 建的帳號預設值，例如學號），學生看到「老師：11156047」認不出是誰：
    # 每次登入後第一個頁面自動打開小卡請老師改名，可以按取消跳過，不會擋住其他功能。
    # 還在強制改密碼或待審核時先不提醒，等能正常使用再說。
    prompt_name = False
    if (session.get('teacher_name_prompt') and not session.get('teacher_must_change_password')
            and request.endpoint != 'teacher_change_password'   # 剛改完密碼那頁先讓老師看完成訊息
            and (teacher.teacher_status or 'approved') == 'approved'):
        session.pop('teacher_name_prompt')
        prompt_name = (teacher.username or '') in ('', teacher.email.split('@')[0])
    return {'account_card': {
        'name': teacher.username or teacher.email,
        'email': teacher.email,
        'avatar': teacher.avatar if (teacher.avatar or '').startswith('http') else None,
        'google_only': session['teacher_google_only'],
        'domain': teacher.email.split('@')[-1],
        'prompt_name': prompt_name,
    }}


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
def _refresh_admin_session():
    """每次請求重新從資料庫確認管理員狀態，讓停用、改權限、重設密碼立即生效，不用等對方重新登入。
    回傳需要轉址的 response，正常則回 None。"""
    admin = Admin.query.get(session.get('admin_id') or 0)
    if not admin or admin.is_active is False:
        session.clear()
        return redirect(url_for('admin_login'))
    session['role'] = admin.role
    session['must_change_password'] = bool(admin.must_change_password)
    if session['must_change_password'] and request.endpoint not in ('change_password', 'admin_logout', 'static'):
        return redirect(url_for('change_password'))
    return None


def admin_login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'admin_user' not in session:
            return redirect(url_for('admin_login'))
        # 老師的 session 也有 admin_user（側欄顯示名稱用），但不能進管理者的頁面
        if session.get('role') == 'teacher':
            return redirect(url_for('teacher_classrooms'))
        blocked = _refresh_admin_session()
        if blocked:
            return blocked
        return f(*args, **kwargs)
    return decorated_function

def super_admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'admin_user' not in session:
            return redirect(url_for('admin_login'))
        if session.get('role') == 'teacher':
            return redirect(url_for('teacher_classrooms'))
        blocked = _refresh_admin_session()
        if blocked:
            return blocked
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
            # 用管理者給的密碼登入：改掉之前只能待在個人資料頁
            if session.get('teacher_must_change_password'):
                if not teacher.must_change_password:
                    session.pop('teacher_must_change_password')
                elif request.endpoint not in ('teacher_profile', 'teacher_change_password'):
                    return redirect(url_for('teacher_profile'))
            return f(*args, **kwargs)
        if session.get('role') == 'super_admin':
            # 和管理者頁面一樣每次重查：被停用或降成 admin 之後要立刻進不來
            blocked = _refresh_admin_session()
            if blocked:
                return blocked
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

        # 帳號是手動輸入的學號（例如 "11156001"）：去掉前後空白，並把中文輸入法打出的全形數字轉成半形
        # 密碼不做任何轉換，必須一字不差
        username = unicodedata.normalize('NFKC', request.form.get('username') or '').strip()
        password = request.form.get('password') or ''
        
        # 增加終端機的登入紀錄 (方便您增加 Commit 內容)
        print(f"[{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')}] 登入嘗試: 管理員 {username}")
        
        admin = Admin.query.filter_by(username=username).first()
        
        if admin and admin.check_password(password):
            if not (admin.is_active if admin.is_active is not None else True):
                print(f"[FAIL] 登入失敗: {username} (帳號已停用)")
                return render_template('admin_login.html', error="此管理員帳號已被停用，請聯繫 super_admin")
            # 登入成功，記錄時間並將重要資訊寫入 Session
            admin.last_login_at = datetime.utcnow()
            db.session.commit()
            session.clear()
            session['admin_user'] = admin.username
            session['admin_id'] = admin.id
            session['role'] = admin.role # 確保這行有加上，這樣才能分辨 super_admin
            session['must_change_password'] = bool(admin.must_change_password)
            session.permanent = True
            if session['must_change_password']:
                return redirect(url_for('change_password'))
            
            print(f"[OK] 登入成功: {username} (權限: {admin.role})")
            return redirect(url_for('admin_dashboard')) # 密碼正確去儀表板
        else:
            # 終端機分開記錄原因方便除錯；畫面上不說明是哪一個錯，避免被拿來試出有哪些帳號
            print(f"[FAIL] 登入失敗: {username!r} ({'密碼錯誤' if admin else '沒有這個帳號'})")
            return render_template('admin_login.html', error="帳號或密碼錯誤，請重新輸入")
            
    return render_template('admin_login.html')


def _teacher_login():
    """校園教育版老師登入：帳號是 user 表裡 account_type='teacher' 的使用者（由 super_admin 建立）"""
    email = (request.form.get('email') or '').strip()
    password = request.form.get('password') or ''
    user = User.query.filter_by(email=email).first()

    from utils import password_policy
    if (not user or not check_password_hash(user.password_hash, password)
            or password_policy.is_google_placeholder_input(password, user.email)):
        print(f"[FAIL] 老師登入失敗: {email} (帳號或密碼錯誤)")
        return render_template('admin_login.html', login_as='teacher', error="Email 或密碼錯誤，請重新輸入")
    if getattr(user, 'account_type', AccountType.GENERAL) != AccountType.TEACHER:
        return render_template('admin_login.html', login_as='teacher',
                               error="這不是老師帳號。老師帳號需由學校系統管理員在後台建立")
    if getattr(user, 'is_suspended', False):
        return render_template('admin_login.html', login_as='teacher', error="此老師帳號已被停用，請聯繫系統管理員")

    print(f"[OK] 老師登入成功: {email} (user_id={user.id})")
    response = _start_teacher_session(user)
    # 只有用密碼登入才要求改密碼；用 Google 登入的人不靠這組密碼，不用擋
    if getattr(user, 'must_change_password', False):
        session['teacher_must_change_password'] = True
        return redirect(url_for('teacher_profile'))
    return response


def _start_teacher_session(user):
    session.clear()
    session['admin_user'] = user.username or user.email   # 側欄顯示名稱
    session['admin_id'] = None                            # 老師不是 admin 表的帳號
    session['role'] = 'teacher'
    session['teacher_user_id'] = user.id
    session['teacher_name_prompt'] = True   # 這次登入還沒提醒過改名（見 _inject_teacher_account_card）
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
    """一般使用者的暱稱可以重複，但老師之間名稱要能分辨（後台名單、學生看到的老師名稱）；
    Google 顯示名稱跟其他老師撞名時改用 Email 帳號部分，再撞就加流水號"""
    base = (preferred or '').strip() or email.split('@')[0]
    candidates = [base, email.split('@')[0]] + [f'{base}{i}' for i in range(2, 100)]
    for name in candidates:
        if not User.query.filter_by(username=name, account_type=AccountType.TEACHER).first():
            return name
    return email


@app.route('/login/google', methods=['GET', 'POST'])
def teacher_google_login():
    """老師用學校 Google 帳號登入：第一次登入自動建立老師帳號，之後直接登入"""
    if request.method == 'GET':
        # 直接打開這個網址（例如網址列自動完成）時導回登入頁，不要顯示 405
        return redirect(url_for('admin_login'))

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
    if _is_student_like_email(email):
        # 有些學校的教職員帳號也是數字，這種老師請走申請表，由管理者人工確認
        return fail(f'「{email}」看起來是學生帳號（帳號為學號），無法直接用 Google 登入老師後台；'
                    f'如果你是老師，請點下方「申請老師帳號」，由管理者確認後開通')

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


def _is_student_like_email(email):
    """學校信箱帳號是學號的（例如 11156047@ntub.edu.tw）視為學生，不能當老師帳號；白名單裡的例外"""
    return bool(TEACHER_GOOGLE_STUDENT_PATTERN and email.lower() not in TEACHER_GOOGLE_ALLOWED_EMAILS
                and re.fullmatch(TEACHER_GOOGLE_STUDENT_PATTERN, email.split('@')[0]))


# ==========================================
# 老師帳號申請（Google 無法登入時）
#   填申請表 → 寄驗證連結到學校信箱 → 點連結設定密碼，建立「待審核」帳號 → 管理者對照教職員名錄核准 → 寄信通知
#   驗證連結是用 secret_key 簽章的 token（裡面是申請表內容），點了才建帳號，所以沒驗證的申請不會留在資料庫
# ==========================================
TEACHER_APPLY_LINK_MINUTES = 30
TEACHER_APPLY_RESEND_SECONDS = 60


def _teacher_apply_serializer():
    from itsdangerous import URLSafeTimedSerializer
    return URLSafeTimedSerializer(app.secret_key, salt='teacher-apply')


def _teacher_apply_problem(form):
    """檢查申請表；有問題回傳錯誤訊息。點驗證連結時會再檢查一次（這段時間內 Email 或名字可能已被用掉）"""
    name, email = form.get('username') or '', form.get('email') or ''
    if not name:
        return '請輸入姓名'
    if len(name) > 30:
        return '姓名最多 30 個字'
    if '@' not in email or len(email) > 120:
        return '請輸入正確的學校 Email'
    if not form.get('department'):
        return '請輸入系所或單位，管理者審核時會對照學校教職員名錄'
    if len(form['department']) > 50:
        return '系所／單位最多 50 個字'
    if len(form.get('note') or '') > 200:
        return '備註最多 200 個字'
    if TEACHER_GOOGLE_DOMAINS and not _teacher_domain_allowed(email.split('@')[-1]):
        return f'請使用學校 Email（{"、".join(_teacher_domain_labels())}）申請，一般 Gmail 無法作為老師帳號'
    # 不擋「帳號是數字」：其他學校的教職員帳號也可能是編號。申請一定要管理者人工審核，
    # 學生拿學號信箱來申請會在對名錄時被拒絕；老師帳號管理的名單上會標「帳號像學號」提醒管理者
    user = User.query.filter(func.lower(User.email) == email.lower()).first()
    if user:
        if user.account_type != AccountType.TEACHER:
            return f'「{email}」已是 App 的一般使用者帳號，無法作為老師帳號，請聯繫系統管理員'
        if (user.teacher_status or 'approved') == 'pending':
            return '這個 Email 已經送出申請，正在等待管理者審核'
        return '這個 Email 已經有老師帳號，請直接登入；忘記密碼請聯繫系統管理員重設'
    if User.query.filter_by(username=name).first():
        # username 全系統唯一，跟老師自己改名、管理者建老師帳號同一個規則
        return f'「{name}」已經有人使用，請加上科目或系所（例如「{name}（日文）」）'
    return None


@app.route('/teacher/apply', methods=['GET', 'POST'])
def teacher_apply():
    """申請表：通過檢查就寄驗證連結到學校信箱"""
    from utils import mailer
    form = {k: (request.form.get(k) or '').strip() for k in ('username', 'email', 'department', 'note')}
    form['email'] = form['email'].lower()   # Google 登入拿到的 Email 都是小寫，統一才不會變成兩個帳號
    if request.method == 'GET':
        return render_template('teacher/apply.html', step='form', form=form)

    def fail(msg):
        return render_template('teacher/apply.html', step='form', form=form, error=msg)

    problem = _teacher_apply_problem(form)
    if problem:
        return fail(problem)
    if not mailer.is_configured():
        return fail('寄信服務尚未設定，暫時無法申請，請直接聯繫學校系統管理員')
    waited = datetime.utcnow().timestamp() - (session.get('teacher_apply_sent_at') or 0)
    if waited < TEACHER_APPLY_RESEND_SECONDS:
        return fail(f'驗證信剛寄出，請 {int(TEACHER_APPLY_RESEND_SECONDS - waited) + 1} 秒後再試')

    link = url_for('teacher_apply_verify', token=_teacher_apply_serializer().dumps(form), _external=True)
    try:
        mailer.send_mail(
            form['email'], 'Snap to Learn 老師帳號申請：請驗證你的 Email',
            f'{form["username"]} 老師您好：\n\n'
            f'我們收到你的 Snap to Learn 校園教育版老師帳號申請。請在 {TEACHER_APPLY_LINK_MINUTES} 分鐘內點下面的連結，'
            f'設定登入密碼並完成申請：\n\n{link}\n\n'
            f'送出後會由學校系統管理員確認老師身分，核准後會再寄信通知你。\n'
            f'如果不是你本人申請，請忽略這封信。\n\nSnap to Learn 校園教育版',
        )
    except Exception as e:
        print(f"⚠️ 寄送老師申請驗證信失敗：{e}")
        return fail('驗證信寄送失敗，請確認 Email 是否正確，或稍後再試')
    session['teacher_apply_sent_at'] = datetime.utcnow().timestamp()
    print(f"[APPLY] 已寄出老師申請驗證信: {form['email']}")
    return render_template('teacher/apply.html', step='sent', form=form, minutes=TEACHER_APPLY_LINK_MINUTES)


@app.route('/teacher/apply/verify', methods=['GET', 'POST'])
def teacher_apply_verify():
    """點驗證信裡的連結：證明信箱是本人的，設定密碼後建立「待審核」老師帳號"""
    from itsdangerous import BadSignature, SignatureExpired
    token = request.values.get('token') or ''
    try:
        form = _teacher_apply_serializer().loads(token, max_age=TEACHER_APPLY_LINK_MINUTES * 60)
    except SignatureExpired:
        return render_template('teacher/apply.html', step='invalid',
                               error=f'驗證連結已超過 {TEACHER_APPLY_LINK_MINUTES} 分鐘，請重新填寫申請表')
    except BadSignature:
        return render_template('teacher/apply.html', step='invalid', error='驗證連結不正確，請確認是否完整複製信裡的連結')
    problem = _teacher_apply_problem(form)
    if problem:
        return render_template('teacher/apply.html', step='invalid', error=problem)
    if request.method == 'GET':
        return render_template('teacher/apply.html', step='password', form=form, token=token)

    password = request.form.get('password') or ''
    error = ('兩次輸入的密碼不一致' if password != (request.form.get('confirm_password') or '')
             else _validate_password(password, account=form['email']))
    if error:
        return render_template('teacher/apply.html', step='password', form=form, token=token, error=error)

    teacher = User(
        email=form['email'],
        username=form['username'],
        password_hash=generate_password_hash(password),
        account_type=AccountType.TEACHER,
        teacher_status='pending',   # 信箱證明了是本人，但是不是老師要等管理者對照名錄
        teacher_department=form['department'],
        teacher_apply_note=form.get('note') or None,
    )
    db.session.add(teacher)
    db.session.flush()
    db.session.add(SystemLog(
        admin_id=None, user_id=teacher.id,
        action='CREATE', target_table='user', target_id=teacher.id,
        new_value={'email': teacher.email, 'username': teacher.username, 'account_type': AccountType.TEACHER,
                   'department': teacher.teacher_department, 'via': 'apply', 'teacher_status': 'pending'}
    ))
    db.session.commit()
    print(f"[NEW] 老師申請表建立待審核帳號: {teacher.email}")
    return render_template('teacher/apply.html', step='done', form=form)


# ==========================================
# 老師忘記密碼：管理者在「教師帳號管理」按重設 → 寄連結到老師信箱 → 老師點連結自己設定新密碼
#   連結是用 secret_key 簽章的 token，裡面有老師 id 和「目前密碼雜湊的指紋」：
#   密碼一換（用掉連結、自己改密碼、管理者改發臨時密碼），指紋就對不上，舊連結全部失效，不用另外存資料表
# ==========================================
TEACHER_RESET_LINK_MINUTES = 30


def _teacher_reset_serializer():
    from itsdangerous import URLSafeTimedSerializer
    return URLSafeTimedSerializer(app.secret_key, salt='teacher-reset')


def _teacher_reset_fingerprint(teacher):
    import hashlib
    return hashlib.sha256((teacher.password_hash or '').encode()).hexdigest()[:16]


def _teacher_reset_token(teacher):
    return _teacher_reset_serializer().dumps({'uid': teacher.id, 'fp': _teacher_reset_fingerprint(teacher)})


@app.route('/teacher/reset_password', methods=['GET', 'POST'])
def teacher_reset_password():
    """點重設信裡的連結：設定新密碼。不用登入，憑連結裡的 token 認人"""
    from itsdangerous import BadSignature, SignatureExpired

    def invalid(msg):
        return render_template('teacher/reset_password.html', step='invalid', error=msg)

    token = request.values.get('token') or ''
    try:
        data = _teacher_reset_serializer().loads(token, max_age=TEACHER_RESET_LINK_MINUTES * 60)
    except SignatureExpired:
        return invalid(f'重設連結已超過 {TEACHER_RESET_LINK_MINUTES} 分鐘，請聯絡管理者重新寄送')
    except BadSignature:
        return invalid('重設連結不正確，請確認是否完整複製信裡的連結')
    teacher = User.query.filter_by(id=data.get('uid'), account_type=AccountType.TEACHER).first()
    if not teacher or data.get('fp') != _teacher_reset_fingerprint(teacher):
        return invalid('這個重設連結已經使用過或已失效，需要的話請聯絡管理者重新寄送')
    if request.method == 'GET':
        return render_template('teacher/reset_password.html', step='password', teacher=teacher, token=token)

    password = request.form.get('password') or ''
    error = ('兩次輸入的密碼不一致' if password != (request.form.get('confirm_password') or '')
             else _validate_password(password, account=teacher.email))
    if error:
        return render_template('teacher/reset_password.html', step='password', teacher=teacher, token=token, error=error)
    teacher.password_hash = generate_password_hash(password)
    teacher.must_change_password = False
    db.session.add(SystemLog(
        admin_id=None, user_id=teacher.id,
        action='UPDATE', target_table='user', target_id=teacher.id,
        new_value={'password': 'reset_by_link'}
    ))
    db.session.commit()
    print(f"[OK] 老師用重設連結設定了新密碼: {teacher.email}")
    return render_template('teacher/reset_password.html', step='done', teacher=teacher)


# ==========================================
# 老師「聯絡管理者」：登不進去、等審核太久、忘記密碼時用。存進意見回饋表（T18），
# 管理者在「意見回饋」看到並回覆，回覆會寄信給老師。不用登入也能送
# ==========================================
TEACHER_CONTACT_PREFIX = '老師聯絡'
TEACHER_CONTACT_TOPICS = ['無法登入', '帳號申請／審核', '忘記密碼', '其他']
TEACHER_CONTACT_RESEND_SECONDS = 60


@app.route('/teacher/contact', methods=['GET', 'POST'])
def teacher_contact():
    teacher = None
    if session.get('role') == 'teacher' and session.get('teacher_user_id'):
        teacher = User.query.get(session['teacher_user_id'])
    form = {k: (request.form.get(k) or '').strip() for k in ('email', 'topic', 'content')}
    if request.method == 'GET':
        form['email'] = teacher.email if teacher else ''
        form['topic'] = request.args.get('topic') if request.args.get('topic') in TEACHER_CONTACT_TOPICS else ''
        return render_template('teacher/contact.html', form=form, topics=TEACHER_CONTACT_TOPICS)

    def fail(msg):
        return render_template('teacher/contact.html', form=form, topics=TEACHER_CONTACT_TOPICS, error=msg)

    if '@' not in form['email'] or len(form['email']) > 120:
        return fail('請輸入正確的 Email，管理者會回信到這裡')
    if form['topic'] not in TEACHER_CONTACT_TOPICS:
        return fail('請選擇問題類型')
    if not form['content']:
        return fail('請說明遇到的問題')
    if len(form['content']) > 1000:
        return fail('內容最多 1000 個字')
    waited = datetime.utcnow().timestamp() - (session.get('teacher_contact_sent_at') or 0)
    if waited < TEACHER_CONTACT_RESEND_SECONDS:
        return fail(f'剛剛已經送出，請 {int(TEACHER_CONTACT_RESEND_SECONDS - waited) + 1} 秒後再送')

    from models import Feedback
    db.session.add(Feedback(
        user_id=teacher.id if teacher else None,
        email=form['email'],
        feedback_type=f"{TEACHER_CONTACT_PREFIX}：{form['topic']}",
        content=form['content'],
    ))
    db.session.commit()
    session['teacher_contact_sent_at'] = datetime.utcnow().timestamp()
    print(f"[CONTACT] 老師聯絡管理者: {form['email']} ({form['topic']})")
    return render_template('teacher/contact.html', form=form, topics=TEACHER_CONTACT_TOPICS, sent=True)


def _mail_teacher_contact_reply(email, question, reply):
    """管理者回覆老師的聯絡單時寄信通知；沒設定寄信或寄失敗都不影響回覆本身"""
    from utils import mailer
    if not mailer.is_configured():
        return
    try:
        mailer.send_mail(
            email, 'Snap to Learn 管理者回覆了你的問題',
            f'老師您好：\n\n管理者回覆了你在 Snap to Learn 校園教育版留下的問題。\n\n'
            f'【你的問題】\n{question}\n\n【管理者回覆】\n{reply}\n\nSnap to Learn 校園教育版',
        )
    except Exception as e:
        print(f"⚠️ 寄送聯絡單回覆失敗：{e}")


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
        elif _validate_password(new_pw, account=admin.username, old_hash=admin.password_hash):
            error = _validate_password(new_pw, account=admin.username, old_hash=admin.password_hash)
        else:
            admin.set_password(new_pw)
            admin.must_change_password = False
            db.session.commit()
            session['must_change_password'] = False
            success = '密碼已成功更新'
    return render_template('admin/change_password.html', error=error, success=success,
                           admin_user=session.get('admin_user'),
                           force=bool(session.get('must_change_password')))

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
            "SELECT username, email, avatar, last_seen_at FROM user ORDER BY last_seen_at IS NULL, last_seen_at DESC LIMIT 4"
        ).fetchall()
        recent_users = [
            {**dict(u), 'last_seen_at': utc_to_tw(u['last_seen_at']) if u['last_seen_at'] else '從未登入'}
            for u in recent_users
        ]
    except: recent_users = []
    # ---- 待處理事項、本週活動、內容與校園版（每個查詢各自 try，缺表就顯示 0）----
    def q1(sql, params=()):
        try:
            return conn.execute(sql, params).fetchone()[0] or 0
        except sqlite3.Error:
            return 0

    # 與小組總覽頁的 _group_status 用同一套 ISO 週規則
    try:
        _now = datetime.utcnow()
        expired_groups = sum(
            1 for (created_raw,) in conn.execute('SELECT created_at FROM study_group').fetchall()
            if (lambda d: d and _now.isocalendar()[:2] > d.isocalendar()[:2])(_parse_db_datetime(created_raw))
        )
    except sqlite3.Error:
        expired_groups = 0
    todo = {
        'pending_teachers': q1("SELECT COUNT(*) FROM user WHERE account_type = 'teacher' AND teacher_status = 'pending'"),
        'feedback_pending': feedback_pending,
        # 建立當週已過、但成員還沒打開小組頁觸發結算的小組
        'expired_groups': expired_groups,
        'default_password_admins': q1("SELECT COUNT(*) FROM admin WHERE must_change_password = 1") if session.get('role') == 'super_admin' else None,
    }
    weekly = {
        'photos': q1("SELECT COUNT(*) FROM user_photo WHERE created_at >= datetime('now', '-7 days')"),
        'sentences': q1("SELECT COUNT(*) FROM sentence_practice_record WHERE created_at >= datetime('now', '-7 days')"),
        'readings': q1("SELECT COUNT(*) FROM score_record WHERE created_at >= datetime('now', '-7 days')"),
        'unlocks': q1("SELECT COUNT(*) FROM unlocked_articles WHERE unlocked_at >= datetime('now', '-7 days')"),
        'chats': q1("SELECT COUNT(*) FROM chat_session WHERE started_at >= datetime('now', '-7 days')"),
        'groups': q1("SELECT COUNT(*) FROM study_group WHERE created_at >= datetime('now', '-7 days')"),
        'new_users': q1("SELECT COUNT(*) FROM user WHERE created_at >= datetime('now', '-7 days')"),
    }
    content = {
        'articles_published': q1("SELECT COUNT(*) FROM articles WHERE is_published IS NOT 0"),
        'articles_total': q1("SELECT COUNT(*) FROM articles"),
        'premium_users': q1("SELECT COUNT(*) FROM user WHERE is_premium = 1"),
    }
    edu = {
        'classrooms': q1("SELECT COUNT(*) FROM classroom WHERE is_archived IS NOT 1"),
    }
    tw_now = datetime.utcnow() + timedelta(hours=8)

    # 最近 14 天每日活躍人數：當天做過任一種學習活動（拍照、AI 對話、造句、朗讀）的不同使用者數，
    # 依台灣時間分日（資料庫存 UTC）
    days = [(tw_now - timedelta(days=i)).date() for i in range(13, -1, -1)]
    active_users = {d.isoformat(): set() for d in days}
    all_active = set()
    for table, col in (('user_photo', 'created_at'), ('chat_session', 'started_at'),
                       ('sentence_practice_record', 'created_at'), ('score_record', 'created_at')):
        try:
            rows = conn.execute(
                f"SELECT DISTINCT date({col}, '+8 hours') AS d, user_id FROM {table} "
                f"WHERE {col} >= datetime('now', '-14 days')").fetchall()
        except sqlite3.Error:
            continue
        for d, uid in rows:
            if d in active_users and uid is not None:
                active_users[d].add(uid)
                all_active.add(uid)
    daily = {d: len(u) for d, u in active_users.items()}
    conn.close()

    W, H, TOP, BOTTOM = 600, 100, 16, 4
    values = [daily[d.isoformat()] for d in days]
    vmax = max(values + [1])
    step = W / (len(days) - 1)
    pts = []
    for i, v in enumerate(values):
        x = round(i * step, 1)
        y = round(H - BOTTOM - (v / vmax) * (H - TOP - BOTTOM), 1)
        pts.append({'x': x, 'y': y, 'v': v, 'label': f'{days[i].month}/{days[i].day}', 'date': days[i].isoformat()})
    daily_chart = {
        'w': W, 'h': H, 'base': H - BOTTOM, 'step': round(step, 1),
        'points': pts,
        'polyline': ' '.join(f"{p['x']},{p['y']}" for p in pts),
        'area': f"M{pts[0]['x']},{H - BOTTOM} " + ' '.join(f"L{p['x']},{p['y']}" for p in pts) + f" L{pts[-1]['x']},{H - BOTTOM} Z",
        'total': len(all_active), 'max': vmax,
    }

    todo_count = sum(1 for v in todo.values() if v)
    weekly_max = max(list(weekly.values()) + [1])

    return render_template('index.html',
                           dashboard_todo=todo, weekly=weekly, content=content, edu=edu,
                           todo_count=todo_count, weekly_max=weekly_max,
                           daily_chart=daily_chart,
                           user_count=user_count,
                           photo_count=photo_count,
                           vocab_count=vocab_count,
                           today_active=today_active,
                           feedback_total=feedback_total,
                           feedback_pending=feedback_pending,
                           recent_users=recent_users,
                           new_users_today=new_users_today)
# ==========================================
# [使用者管理] 包含點數 (j_pts)
# ==========================================
@app.route('/customer/list')
@admin_login_required
def customer_list():
    """點數管理已併入使用者資料：舊連結導到使用者列表，點數在各使用者的詳情頁調整"""
    return redirect(url_for('user_list'))

@app.route('/customer/adjust_pts/<int:user_id>', methods=['POST'])
@admin_login_required
def adjust_pts(user_id):
    """管理者手動加減點數：寫進點數交易明細（讓使用者在 App 也看得到）與 SystemLog"""
    from models import PointTransaction
    user = User.query.get_or_404(user_id)
    try:
        amount = int(request.form.get('amount', ''))
    except (ValueError, TypeError):
        flash('請輸入要調整的點數（正數加點、負數扣點）', 'error')
        return redirect(url_for('user_detail', user_id=user_id))
    if amount == 0:
        flash('調整點數不可為 0', 'error')
        return redirect(url_for('user_detail', user_id=user_id))
    reason = (request.form.get('reason') or '').strip()

    before = user.j_pts or 0
    after = before + amount
    if after < 0:
        amount = -before   # 最多扣到 0，不讓餘額變負
        after = 0
    user.j_pts = after
    db.session.add(PointTransaction(
        user_id=user.id, points=amount, price=0, payment_method='admin',   # 資料表此欄 NOT NULL
        transaction_type='admin_adjust', related_feature=reason or '管理者調整',
    ))
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=user.id,
        action='UPDATE', target_table='user', target_id=user.id,
        old_value={'j_pts': before}, new_value={'j_pts': after, 'reason': reason},
    ))
    db.session.commit()
    flash(f'已{"加" if amount > 0 else "扣"} {abs(amount)} 點，餘額 {before} → {after}' + ('（已扣到 0 為止）' if after == 0 and before + int(request.form.get('amount')) < 0 else ''), 'success')
    return redirect(url_for('user_detail', user_id=user_id))

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
    plans = conn.execute('SELECT * FROM subscription_plan ORDER BY is_active DESC, id ASC').fetchall()
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

    # 點數方案（原本獨立的「點數方案管理」頁已併進來）
    packages = [dict(p) for p in conn.execute('SELECT * FROM point_package ORDER BY is_active DESC, price ASC').fetchall()]
    for p in packages:
        row = conn.execute(
            "SELECT COUNT(*) as cnt, COALESCE(SUM(price),0) as revenue FROM point_transaction WHERE points=? AND price=? AND transaction_type='purchase'",
            (p['points'], p['price'])
        ).fetchone()
        p['buy_count'] = row['cnt'] if row else 0
        p['revenue']   = row['revenue'] if row else 0
    conn.close()
    return render_template('plan/list.html', plans=plans, free_users=free_users, packages=packages,
                           total_revenue=sum(p['revenue'] for p in packages),
                           total_purchases=sum(p['buy_count'] for p in packages),
                           active_count=sum(1 for p in packages if p['is_active']))

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
    return redirect(url_for('plan_list', tab='subscription'))

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
    return redirect(url_for('plan_list', tab='subscription'))

@app.route('/plan/toggle/<int:plan_id>', methods=['POST'])
@super_admin_required
def plan_toggle(plan_id):
    conn = get_db_connection()
    row = conn.execute('SELECT is_active FROM subscription_plan WHERE id=?', (plan_id,)).fetchone()
    if row:
        new_active = 0 if row['is_active'] else 1
        conn.execute('UPDATE subscription_plan SET is_active=? WHERE id=?', (new_active, plan_id))
        # 下架／上架也記一筆操作紀錄（跟新增、修改方案一樣寫入 system_log）
        conn.execute(
            'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, old_value, new_value, created_at) VALUES (?, NULL, ?, ?, ?, ?, ?, ?)',
            (session.get('admin_id'), 'UPDATE', 'subscription_plan', plan_id,
             json.dumps({'is_active': row['is_active']}), json.dumps({'is_active': new_active}),
             datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')))
        conn.commit()
    conn.close()
    return redirect(url_for('plan_list', tab='subscription'))

@app.route('/package/list')
@super_admin_required
def package_list():
    """點數方案已併入「方案管理」：舊網址導到合併頁"""
    return redirect(url_for('plan_list'))

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
    return redirect(url_for('plan_list', tab='package'))

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
    return redirect(url_for('plan_list', tab='package'))

@app.route('/package/toggle/<int:pkg_id>', methods=['POST'])
@super_admin_required
def package_toggle(pkg_id):
    conn = get_db_connection()
    row = conn.execute('SELECT is_active FROM point_package WHERE id=?', (pkg_id,)).fetchone()
    if row:
        new_active = 0 if row['is_active'] else 1
        conn.execute('UPDATE point_package SET is_active=? WHERE id=?', (new_active, pkg_id))
        # 下架／上架也記一筆操作紀錄（跟新增、修改方案一樣寫入 system_log）
        conn.execute(
            'INSERT INTO system_log (admin_id, user_id, action, target_table, target_id, old_value, new_value, created_at) VALUES (?, NULL, ?, ?, ?, ?, ?, ?)',
            (session.get('admin_id'), 'UPDATE', 'point_package', pkg_id,
             json.dumps({'is_active': row['is_active']}), json.dumps({'is_active': new_active}),
             datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')))
        conn.commit()
    conn.close()
    return redirect(url_for('plan_list', tab='package'))

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
PHOTO_PAGE_SIZE = 30


@app.route('/photo/list')
@admin_login_required
def photo_list():
    keyword = (request.args.get('q') or '').strip()
    page = max(1, request.args.get('page', 1, type=int) or 1)
    offset = (page - 1) * PHOTO_PAGE_SIZE
    pattern = '%' + keyword + '%'
    where = ('WHERE (u.email LIKE ? OR u.username LIKE ? OR p.custom_title LIKE ? OR s.name LIKE ?)'
             if keyword else '')
    params = (pattern,) * 4 if keyword else ()
    joins = '''
        FROM user_photo p
        LEFT JOIN user u ON p.user_id = u.id
        LEFT JOIN scene s ON p.scene_id = s.id
    '''

    photos, total = [], 0
    conn = get_db_connection()
    try:
        total = conn.execute('SELECT COUNT(*) ' + joins + where, params).fetchone()[0]
        rows = conn.execute('''
            SELECT p.id, p.user_id, p.image_path, u.username, u.email, s.name as scene_name,
                   p.custom_title, p.created_at
            ''' + joins + where + '''
            ORDER BY p.created_at DESC, p.id DESC LIMIT ? OFFSET ?
        ''', params + (PHOTO_PAGE_SIZE, offset)).fetchall()
        photos = [{**dict(r), 'created_at': utc_to_tw(r['created_at'] or ''), 'is_submission': False}
                  for r in rows]

        # 被拍照作業當成繳交內容的照片要標出來，刪掉後老師那邊會看不到這份作業的照片
        ids = [p['id'] for p in photos]
        if ids:
            try:
                used = {r[0] for r in conn.execute('''
                    SELECT sub.result_ref_id
                    FROM assignment_submission sub JOIN assignment a ON a.id = sub.assignment_id
                    WHERE a.task_type = 'photo' AND sub.result_ref_id IN (%s)
                ''' % ','.join('?' * len(ids)), ids).fetchall()}
            except sqlite3.Error:
                used = set()
            for p in photos:
                p['is_submission'] = p['id'] in used
    except sqlite3.Error:
        photos, total = [], 0
    finally:
        conn.close()

    pages = max(1, -(-total // PHOTO_PAGE_SIZE))
    return render_template('photo/list.html', photos=photos, keyword=keyword,
                           total=total, page=page, pages=pages)

@app.route('/photo/delete/<int:photo_id>', methods=['POST'])
@admin_login_required
def delete_photo(photo_id):
    back = url_for('photo_list', q=request.form.get('q') or None,
                   page=request.form.get('page', type=int) or None)
    conn = get_db_connection()
    try:
        row = conn.execute('SELECT image_path FROM user_photo WHERE id = ?', (photo_id,)).fetchone()
        if not row:
            flash('找不到這張照片，可能已經被刪除', 'error')
            return redirect(back)
        image_path = row['image_path']
        conn.execute('DELETE FROM user_photo_vocab WHERE photo_id = ?', (photo_id,))
        conn.execute('DELETE FROM user_photo WHERE id = ?', (photo_id,))
        conn.commit()
        # 照片檔案：其他紀錄沒有用到同一個檔案才刪（種子資料可能多人共用同一張示範圖）
        still_used = image_path and conn.execute(
            'SELECT 1 FROM user_photo WHERE image_path = ? LIMIT 1', (image_path,)).fetchone()
    finally:
        conn.close()

    file_error = False
    filename = os.path.basename(image_path or '')
    if filename and not still_used and not image_path.startswith('http'):
        file_path = os.path.join(PHOTO_DIR, filename)
        try:
            if os.path.isfile(file_path):
                os.remove(file_path)
        except OSError:
            file_error = True

    if file_error:
        flash('照片紀錄已刪除，但照片檔案刪除失敗：%s' % filename, 'error')
    else:
        flash('已刪除照片 #%d' % photo_id, 'success')
    return redirect(back)

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
    # 老師從「聯絡管理者」送來的可能還沒有帳號（user_id 是空的），Email 改看回饋本身留的
    base = '''
        SELECT f.id, f.feedback_type, f.content, f.reply, f.replied_at, f.created_at,
               u.username, COALESCE(u.email, f.email) AS email
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
    fb = conn.execute('''SELECT f.feedback_type, f.content, COALESCE(u.email, f.email) AS email
                         FROM feedback f LEFT JOIN user u ON f.user_id = u.id WHERE f.id = ?''', (feedback_id,)).fetchone()
    conn.commit()
    conn.close()
    # 老師的聯絡單：老師多半登不進後台、也不用 App，回覆要寄信才看得到（App 的回饋在 App 裡看）
    if fb and (fb['feedback_type'] or '').startswith(TEACHER_CONTACT_PREFIX) and fb['email']:
        _mail_teacher_contact_reply(fb['email'], fb['content'], reply)
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
    account_type = user.get('account_type') or 'general'

    # 老師帳號：看班級與帳號狀態；學生帳號：看所屬班級與作業。這兩種都用不到 App 的付費功能
    teacher_info, student_info = None, None
    if account_type == 'teacher':
        try:
            classrooms = [dict(r) for r in conn.execute('''
                SELECT c.id, c.name, c.join_code, c.is_open, c.is_archived, c.created_at,
                       (SELECT COUNT(*) FROM classroom_member m WHERE m.classroom_id = c.id) AS members,
                       (SELECT COUNT(*) FROM assignment a WHERE a.classroom_id = c.id AND a.is_published = 1) AS assignments
                FROM classroom c WHERE c.teacher_id = ? ORDER BY c.is_archived, c.created_at DESC
            ''', (user_id,)).fetchall()]
            for c in classrooms:
                c['created_at'] = utc_to_tw(c['created_at'] or '')
            via_google = conn.execute(
                "SELECT COUNT(*) FROM system_log WHERE target_table = 'user' AND target_id = ? AND action = 'CREATE' "
                "AND new_value LIKE '%\"via\": \"google\"%'", (user_id,)).fetchone()[0] > 0
        except sqlite3.Error:
            classrooms, via_google = [], False
        teacher_info = {
            'classrooms': classrooms,
            'active_count': sum(1 for c in classrooms if not c['is_archived']),
            'student_total': sum(c['members'] for c in classrooms if not c['is_archived']),
            'assignment_total': sum(c['assignments'] for c in classrooms if not c['is_archived']),
            'status': user.get('teacher_status') or 'approved',
            'via': 'Google 學校帳號登入自動建立' if via_google else '管理者建立',
        }
    elif account_type == 'student':
        try:
            memberships = [dict(r) for r in conn.execute('''
                SELECT c.id, c.name, c.join_code, c.is_archived, t.username AS teacher_name, m.joined_at, m.display_name,
                       (SELECT COUNT(*) FROM assignment a WHERE a.classroom_id = c.id AND a.is_published = 1) AS total,
                       (SELECT COUNT(*) FROM assignment_submission s JOIN assignment a ON a.id = s.assignment_id
                        WHERE a.classroom_id = c.id AND s.student_id = m.student_id AND s.status IN ('submitted', 'graded')) AS done,
                       (SELECT ROUND(AVG(s.score), 1) FROM assignment_submission s JOIN assignment a ON a.id = s.assignment_id
                        WHERE a.classroom_id = c.id AND s.student_id = m.student_id AND s.score IS NOT NULL) AS avg_score
                FROM classroom_member m JOIN classroom c ON c.id = m.classroom_id
                LEFT JOIN user t ON t.id = c.teacher_id
                WHERE m.student_id = ? ORDER BY m.joined_at DESC
            ''', (user_id,)).fetchall()]
            for m in memberships:
                m['joined_at'] = utc_to_tw(m['joined_at'] or '')
        except sqlite3.Error:
            memberships = []
        student_info = {'memberships': memberships}

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
            SELECT id, transaction_type, points, price, payment_method, related_feature, created_at
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
        friends=friends, feedbacks=feedbacks, groups=groups,
        account_type=account_type, teacher_info=teacher_info, student_info=student_info)


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


@app.route('/article/auto_ruby', methods=['POST'])
@admin_login_required
def article_auto_ruby():
    """新增／編輯文章時的「自動標註讀音」：請 AI 幫漢字加上 <ruby> 讀音標記，回傳給表單填回去（不會直接存檔）"""
    from utils.ruby_helper import add_ruby, RubyError
    text = (request.get_json(silent=True) or {}).get('text', '')
    try:
        content, count = add_ruby(text)
    except RubyError as e:
        return jsonify({'error': str(e)}), 400
    return jsonify({'content': content, 'count': count})


@app.route('/article/auto_translate', methods=['POST'])
@admin_login_required
def article_auto_translate():
    """新增／編輯文章時的「自動產生中文翻譯」：回傳翻譯給表單填回去（不會直接存檔）"""
    from utils.ruby_helper import translate_to_zh, RubyError
    text = (request.get_json(silent=True) or {}).get('text', '')
    try:
        translation = translate_to_zh(text)
    except RubyError as e:
        return jsonify({'error': str(e)}), 400
    return jsonify({'translation': translation})


@app.route('/article/auto_points', methods=['POST'])
@admin_login_required
def article_auto_points():
    """新增／編輯文章時的「自動產生重點文法與單字」：回傳表單用的「a | b | c」一行一筆格式（不會直接存檔）"""
    from utils.ruby_helper import extract_points, RubyError
    data = request.get_json(silent=True) or {}
    level = data.get('level') if data.get('level') in ARTICLE_LEVELS else 'N5'
    try:
        points = extract_points(data.get('text', ''), level)
    except RubyError as e:
        return jsonify({'error': str(e)}), 400
    grammars_text = '\n'.join(' | '.join([g['expression'], g['meaning'], g['example']]) for g in points['grammars'])
    vocabs_text = '\n'.join(' | '.join([v['word'], v['reading'], v['meaning']]) for v in points['vocabularies'])
    return jsonify({'grammars_text': grammars_text, 'vocabs_text': vocabs_text,
                    'grammar_count': len(points['grammars']), 'vocab_count': len(points['vocabularies'])})


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
    create_sentence_assignment, create_article_assignment,
    create_photo_assignment, create_chat_assignment,
    get_assignment_submissions_list, grade_submission,
    get_gradebook, save_grade_config, set_assignment_score, gradebook_csv,
    get_classroom_report, get_student_report, student_report_csv, tw_fmt,
    set_late_policy, late_policy_text, post_announcement, announce_assignment, get_announcements,
    copy_assignment, LATE_POLICY_LABELS, push_announcement, push_new_assignment, push_graded
)
from models import (Classroom, ClassroomMember, Assignment, AssignmentSubmission, Dialect, Scene,
                    ClassroomAnnouncement)

# 模板裡直接拿 ORM 物件的時間（UTC）顯示時用：{{ a.created_at|tw }}
app.add_template_filter(tw_fmt, 'tw')


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


def _teacher_google_only(teacher):
    """用 Google 建立、本人沒有密碼的老師帳號，個人資料頁就不顯示改密碼。有兩種來源：
    - 舊版 App Google 登入建的帳號後來轉成老師：密碼還是固定的假密碼（沒有建立紀錄，只能從雜湊認）
    - 後台 Google 登入第一次自動建立：密碼是隨機的，看建立紀錄
    之後管理者幫他重設過密碼（或自己改過）就算有密碼，照樣可以改。"""
    from utils import password_policy
    if password_policy.has_google_placeholder_hash(teacher.password_hash, teacher.email):
        return True
    created_via_google = password_set = False
    for log in SystemLog.query.filter_by(target_table='user', target_id=teacher.id).all():
        value = log.new_value if isinstance(log.new_value, dict) else {}
        if log.action == 'CREATE' and value.get('via') == 'google':
            created_via_google = True
        elif log.action == 'UPDATE' and 'password' in value:
            password_set = True
    return created_via_google and not password_set


def _render_teacher_profile(teacher, name_value=None, **messages):
    """個人資料頁：顯示名稱和密碼放在同一頁。error/success 是名稱的訊息，pw_error/pw_success 是密碼的"""
    joined = (teacher.created_at + timedelta(hours=8)).strftime('%Y/%m/%d') if teacher.created_at else ''
    avatar = teacher.avatar if (teacher.avatar or '').startswith('http') else None   # Google 大頭貼
    return render_template('teacher/profile.html', teacher=teacher, active_menu='profile',
                           name_value=(teacher.username or '') if name_value is None else name_value,
                           google_only=_teacher_google_only(teacher), joined=joined, avatar=avatar,
                           force_pw=bool(session.get('teacher_must_change_password')), **messages)


@app.route('/teacher/change_password', methods=['GET', 'POST'])
@teacher_required
def teacher_change_password():
    """老師改自己的密碼（表單在個人資料頁）。管理者的 /admin/change_password 只認 admin 表，老師進不去"""
    if session.get('role') != 'teacher':
        return redirect(url_for('change_password'))
    if request.method == 'GET':
        return redirect(url_for('teacher_profile'))
    teacher = User.query.get(session['teacher_user_id'])
    if _teacher_google_only(teacher):
        return _render_teacher_profile(teacher, pw_error='你的帳號用學校 Google 帳號登入，沒有另外的密碼可以修改')
    current = request.form.get('current_password', '')
    new_pw = request.form.get('new_password', '')
    confirm = request.form.get('confirm_password', '')
    if not check_password_hash(teacher.password_hash, current):
        return _render_teacher_profile(teacher, pw_error='目前密碼錯誤')
    if new_pw != confirm:
        return _render_teacher_profile(teacher, pw_error='新密碼與確認密碼不一致')
    policy_error = _validate_password(new_pw, account=teacher.email, old_hash=teacher.password_hash)
    if policy_error:
        return _render_teacher_profile(teacher, pw_error=policy_error)
    teacher.password_hash = generate_password_hash(new_pw)
    teacher.must_change_password = False
    db.session.add(SystemLog(
        admin_id=None, user_id=teacher.id,
        action='UPDATE', target_table='user', target_id=teacher.id,
        new_value={'password': 'changed_by_self'}
    ))
    db.session.commit()
    session['teacher_google_only'] = False
    was_forced = session.pop('teacher_must_change_password', False)
    return _render_teacher_profile(teacher, pw_success='密碼已更新，下次登入請使用新密碼', just_unlocked=was_forced)


@app.route('/teacher/profile', methods=['GET', 'POST'])
@teacher_required
def teacher_profile():
    """老師改自己的顯示名稱（user.username），學生在 App 教室頁看到的「老師：XXX」就是這個。

    Google 登入的老師名稱是第一次登入時抓 Google 顯示名稱，管理者建的帳號是建立時填的姓名，
    之前建好就改不了。登入用 Email、系統認人用 user.id，所以改名不影響登入和班級。
    """
    if session.get('role') != 'teacher':
        return redirect(url_for('teacher_classrooms'))
    teacher = User.query.get(session['teacher_user_id'])
    error = success = None
    if request.method == 'POST':
        name = (request.form.get('username') or '').strip()
        if not name:
            error = '請輸入顯示名稱'
        elif len(name) > 30:
            error = '顯示名稱最多 30 個字'
        elif name == teacher.username:
            success = '名稱沒有變更'
        elif User.query.filter(User.username == name, User.id != teacher.id).first():
            # username 全系統唯一（含 App 一般會員的暱稱），跟管理者新增老師帳號同一個規則
            error = f'「{name}」已經有人使用，請換一個（例如加上全名或科目）'
        else:
            old = teacher.username
            teacher.username = name
            db.session.add(SystemLog(
                admin_id=None, user_id=teacher.id,
                action='UPDATE', target_table='user', target_id=teacher.id,
                old_value={'username': old}, new_value={'username': name, 'via': 'teacher_profile'}
            ))
            db.session.commit()
            session['admin_user'] = name   # 側欄上的名字跟著換
            success = '已更新，學生在 App 重新整理教室頁就會看到新名稱'
        if request.headers.get('X-Requested-With') == 'fetch':
            # 側欄帳號小卡直接改名，不換頁
            return jsonify({'ok': not error, 'name': teacher.username, 'message': error or success})
    # 存失敗時保留老師剛剛打的字，不要被換回舊名稱
    name_value = (request.form.get('username') or '') if error else None
    return _render_teacher_profile(teacher, name_value=name_value, error=error, success=success)


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
    flash(f"班級「{c.name}」建立成功！班級代碼為：{c.join_code}", "success")
    return redirect(url_for('teacher_classrooms'))


@app.route('/teacher/classroom/<int:classroom_id>/regenerate_code', methods=['POST'])
@teacher_required
def teacher_classroom_regenerate_code(classroom_id):
    """重新生成班級隨機碼"""
    if not _own_classroom(classroom_id):
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    new_code = regenerate_join_code(classroom_id)
    flash(f"班級代碼已更新為：{new_code}", "success")
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
        a.late_text = late_policy_text(a)

    # 「複製到其他班」能選的班級：同一位老師、使用中的其他班（super_admin 不能代替老師出題）
    other_classrooms = []
    if session.get('role') == 'teacher':
        other_classrooms = Classroom.query.filter(
            Classroom.teacher_id == session['teacher_user_id'], Classroom.id != classroom_id,
            Classroom.is_archived.isnot(True)).order_by(Classroom.created_at.desc()).all()

    return render_template('teacher/assignment_list.html', classroom=classroom, assignments=assignments,
                           other_classrooms=other_classrooms, late_policy_labels=LATE_POLICY_LABELS)


@app.route('/teacher/classroom/<int:classroom_id>/assignment/create', methods=['GET', 'POST'])
@teacher_required
def teacher_assignment_create(classroom_id):
    """出題新作業：造句挑戰、文章閱讀（支援上傳文章、選擇題、是非題）、拍照學習、AI 情境對話"""
    classroom = _own_classroom(classroom_id)
    if not classroom:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))

    if request.method == 'POST':
        # 出題是老師的教學行為；super_admin 可以檢視、下架、刪除，但不能代替老師出題（與建班級、加學生一致）
        if session.get('role') != 'teacher' or not session.get('teacher_user_id'):
            flash("管理者無法代替老師出題，請由班級老師登入後新增作業", "danger")
            return redirect(url_for('teacher_classroom_assignments', classroom_id=classroom_id))

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
            assignment = create_sentence_assignment(classroom_id, title, instructions, grammar, vocabs, pass_score, due_at)
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

            assignment = create_article_assignment(
                classroom_id, title, instructions,
                article_id=art_id, new_article=new_art,
                has_quiz=has_quiz, questions=questions, due_at=due_at
            )
            flash(f"文章閱讀作業「{title}」發布成功！", "success")

        elif task_type == 'photo':
            theme = request.form.get('photo_theme', '').strip()
            min_vocab_count = request.form.get('min_vocab_count', 3)
            assignment = create_photo_assignment(classroom_id, title, instructions, theme, min_vocab_count, due_at)
            flash(f"拍照學習作業「{title}」發布成功！", "success")

        elif task_type == 'chat':
            topic = request.form.get('chat_topic', '').strip()
            if not topic:
                flash("對話作業必須填寫情境主題！", "danger")
                return redirect(url_for('teacher_assignment_create', classroom_id=classroom_id))
            dialect_id = request.form.get('dialect_id', type=int)
            min_turns = request.form.get('min_turns', 6)
            assignment = create_chat_assignment(classroom_id, title, instructions, topic, dialect_id, min_turns, due_at)
            flash(f"情境對話作業「{title}」發布成功！", "success")

        else:
            flash("未知的作業題型", "danger")
            return redirect(url_for('teacher_assignment_create', classroom_id=classroom_id))

        # 遲交規則填錯不擋發布（出題表單很長，退回去會整份重填），先用預設的允許遲交並提醒老師
        late_error = set_late_policy(assignment, request.form.get('late_policy'), request.form.get('late_penalty'))
        if late_error:
            flash(f"{late_error}；這份作業先設為「允許遲交」，可在作業列表按「編輯」修改", "warning")
        announce = request.form.get('announce') == '1'
        if announce:
            announce_assignment(assignment)
        db.session.commit()
        if announce:
            pushed = push_new_assignment(assignment)
            if pushed:
                flash(f"已推播通知到 {pushed} 位學生的手機", "info")
        return redirect(url_for('teacher_classroom_assignments', classroom_id=classroom_id))

    existing_articles = Article.query.filter(Article.is_published.isnot(False)).order_by(Article.level, Article.id).all()
    # 對話作業可選腔調；拍照作業的主題提示用現有場景名稱當建議選項（老師仍可自由輸入）
    dialects = Dialect.query.filter_by(is_active=True).order_by(Dialect.id).all()
    scene_names = [sc.name for sc in Scene.query.order_by(Scene.id).all()]
    return render_template('teacher/assignment_create.html', classroom=classroom,
                           existing_articles=existing_articles, dialects=dialects, scene_names=scene_names)


@app.route('/teacher/assignment/<int:assignment_id>/submissions')
@teacher_required
def teacher_assignment_submissions(assignment_id):
    """作業繳交名單與批閱給分"""
    data = get_assignment_submissions_list(assignment_id) if _own_assignment(assignment_id) else None
    if not data:
        flash("找不到該作業", "danger")
        return redirect(url_for('teacher_classrooms'))
    # saved：剛批完的學生 id，那一列會標「已儲存」
    return render_template('teacher/assignment_submissions.html', data=data,
                           saved_id=request.args.get('saved', type=int))


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

    ok, error = grade_submission(submission_id, score, teacher_comment)
    if not ok:
        flash(error, "danger")
        return redirect(url_for('teacher_assignment_submissions', assignment_id=sub.assignment_id))
    push_graded(sub)
    # 存完回到剛剛那一列（不用每批一個人就捲回最上面），那一列會標「已儲存」
    return redirect(url_for('teacher_assignment_submissions', assignment_id=sub.assignment_id,
                            saved=sub.student_id, _anchor=f'stu-{sub.student_id}'))


# ---- 班級成績總表 / 學期成績 ----
@app.route('/teacher/classroom/<int:classroom_id>/gradebook')
@teacher_required
def teacher_gradebook(classroom_id):
    """學生 × 作業的成績矩陣，加上依權重算出的學期成績"""
    data = get_gradebook(classroom_id) if _own_classroom(classroom_id) else None
    if not data:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    return render_template('teacher/gradebook.html', data=data)


@app.route('/teacher/classroom/<int:classroom_id>/gradebook/config', methods=['POST'])
@teacher_required
def teacher_gradebook_config(classroom_id):
    """儲存作業權重、缺交處理、自主練習占比"""
    if not _own_classroom(classroom_id):
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    error = save_grade_config(classroom_id, request.form)
    if error:
        flash(error, "danger")
    else:
        flash("計分方式已儲存，學期成績已重新計算", "success")
    return redirect(url_for('teacher_gradebook', classroom_id=classroom_id))


@app.route('/teacher/classroom/<int:classroom_id>/gradebook/score', methods=['POST'])
@teacher_required
def teacher_gradebook_score(classroom_id):
    """在總表上直接改一格分數（AJAX）。回傳該學生重算後的整列與該作業的班平均。"""
    if not _own_classroom(classroom_id):
        return jsonify({'error': '找不到該班級'}), 404
    payload = request.get_json(silent=True) or {}
    assignment_id = payload.get('assignment_id')
    student_id = payload.get('student_id')
    assignment = Assignment.query.get(assignment_id or 0)
    if not assignment or assignment.classroom_id != classroom_id:
        return jsonify({'error': '找不到該作業'}), 404

    ok, error = set_assignment_score(assignment_id, student_id, str(payload.get('score', '')))
    if not ok:
        return jsonify({'error': error}), 400

    data = get_gradebook(classroom_id)
    student = next((s for s in data['students'] if s['student_id'] == student_id), None)
    assignment_row = next((a for a in data['assignments'] if a['id'] == assignment_id), None)
    return jsonify({
        'student': student,
        'assignment': assignment_row,
        'summary': data['summary'],
    })


@app.route('/teacher/classroom/<int:classroom_id>/gradebook/export.csv')
@teacher_required
def teacher_gradebook_export(classroom_id):
    """成績總表下載成 CSV，老師拿去貼學校成績系統"""
    classroom = _own_classroom(classroom_id)
    if not classroom:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    return _csv_response(gradebook_csv(classroom_id), f"{classroom.name}_成績總表")


def _csv_response(csv_text, name):
    from flask import Response
    from urllib.parse import quote
    filename = f"{name}_{datetime.now().strftime('%Y%m%d')}.csv"
    return Response(
        csv_text,
        mimetype='text/csv; charset=utf-8',
        headers={'Content-Disposition': f"attachment; filename*=UTF-8''{quote(filename)}"},
    )


# ---- 班級報表 / 學生詳細成果 ----
@app.route('/teacher/classroom/<int:classroom_id>/report')
@teacher_required
def teacher_classroom_report(classroom_id):
    """成績分布、各作業比較、文法弱點、測驗錯題、學習活躍度"""
    data = get_classroom_report(classroom_id) if _own_classroom(classroom_id) else None
    if not data:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    return render_template('teacher/classroom_report.html', data=data)


@app.route('/teacher/classroom/<int:classroom_id>/student/<int:student_id>/report')
@teacher_required
def teacher_student_report(classroom_id, student_id):
    """單一學生的詳細成果頁"""
    data = get_student_report(classroom_id, student_id) if _own_classroom(classroom_id) else None
    if not data:
        flash("找不到該學生或班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    return render_template('teacher/student_report.html', data=data)


@app.route('/teacher/classroom/<int:classroom_id>/student/<int:student_id>/report.csv')
@teacher_required
def teacher_student_report_export(classroom_id, student_id):
    """個人成績單 CSV"""
    csv_text = student_report_csv(classroom_id, student_id) if _own_classroom(classroom_id) else None
    if not csv_text:
        flash("找不到該學生或班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    data = get_student_report(classroom_id, student_id)
    return _csv_response(csv_text, f"{data['classroom']['name']}_{data['student']['display_name']}_成績單")


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


@app.route('/teacher/classroom/<int:classroom_id>/student/<int:student_id>/reset_password', methods=['POST'])
@teacher_required
def teacher_student_reset_password(classroom_id, student_id):
    """學生忘記密碼：重設成隨機的臨時密碼，只在這次顯示給老師。App 的忘記密碼不開放學生帳號用"""
    member = _own_member(classroom_id, student_id)
    student = User.query.get(student_id) if member else None
    if not student:
        flash("找不到該學生", "danger")
        return redirect(url_for('teacher_classrooms'))
    if (student.account_type or AccountType.GENERAL) != AccountType.STUDENT:
        flash("這不是校園教育版的學生帳號，無法在這裡重設密碼", "danger")
        return redirect(url_for('teacher_classroom_students', classroom_id=classroom_id))
    if student.school_id:
        flash("這位學生用學校 Google 帳號登入，沒有密碼可以重設；登不進去請學生確認選對學校、用學校帳號登入", "danger")
        return redirect(url_for('teacher_classroom_students', classroom_id=classroom_id))
    temp_password = _student_temp_password()
    student.password_hash = generate_password_hash(temp_password)
    student.must_change_password = True   # 臨時密碼老師也知道，學生下次登入要自己換掉
    student.token_version = (student.token_version or 0) + 1   # 已登入的裝置一併登出
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=student.id,
        action='UPDATE', target_table='user', target_id=student.id,
        new_value={'password': 'reset_to_temp', 'classroom_id': classroom_id}
    ))
    db.session.commit()
    flash(f"已重設「{member.display_name or student.username or student.email}」的密碼，學生用下面的臨時密碼登入後會被要求設定新密碼", "success")
    return _render_roster_with_passwords(classroom_id, [
        {'account': student.email, 'name': member.display_name or student.username, 'password': temp_password}])


# ---- 學生名冊：老師貼上名單建立學生帳號 ----
# 備用的登入方式（主要是學生在 App 選學校、用學校 Google 帳號登入）：老師在班級名冊加入，
# 帳號是學號，初始密碼由系統隨機產生、只顯示給老師一次。以前初始密碼＝學號，
# 知道學號的人搶先登入就能改掉密碼、佔走帳號，所以改成隨機。

# 臨時密碼的字元：去掉容易看錯的 0/O/o、1/l/I，學生照著紙條打才不會打錯
_TEMP_PASSWORD_CHARS = 'abcdefghjkmnpqrstuvwxyz23456789'


def _student_temp_password():
    import secrets
    return ''.join(secrets.choice(_TEMP_PASSWORD_CHARS) for _ in range(8))


def _render_roster_with_passwords(classroom_id, new_passwords):
    """直接回傳名冊頁並列出新密碼，不轉址：密碼不能放進 session（cookie 會被看到、一班太多也放不下），
    只在這次回應出現，重新整理就消失"""
    data = get_classroom_student_stats(classroom_id)
    return render_template('teacher/student_progress.html', data=data, new_passwords=new_passwords)
STUDENT_ID_RE = re.compile(r'^[A-Za-z0-9_.\-]{2,30}$')
ROSTER_MAX_LINES = 200


def _parse_roster(text):
    """把貼上的名單拆成 [(學號, 姓名或 None)]；每行「學號 姓名」，空白、Tab、逗號都可以分隔，姓名可省略"""
    rows, bad = [], []
    for line in (text or '').splitlines():
        line = line.strip()
        if not line:
            continue
        parts = re.split(r'[\s,，、]+', line, maxsplit=1)
        student_no = parts[0].strip()
        name = parts[1].strip() if len(parts) > 1 and parts[1].strip() else None
        if not STUDENT_ID_RE.match(student_no):
            bad.append(line)
            continue
        rows.append((student_no, name[:50] if name else None))
    return rows, bad


@app.route('/teacher/classroom/<int:classroom_id>/students/add', methods=['POST'])
@teacher_required
def teacher_students_add(classroom_id):
    """貼上名單批次加入學生：沒有帳號的建立學生帳號（帳號是學號、隨機初始密碼），已有學生帳號的直接加入班級"""
    from utils.auth_helper import generate_friend_id
    classroom = _own_classroom(classroom_id)
    if not classroom:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    # 名冊由班級老師負責；super_admin 可以檢視所有班級，但和建立班級一樣不能代替老師加學生
    if session.get('role') != 'teacher' or not session.get('teacher_user_id'):
        flash("管理者無法代替老師新增學生，請由班級老師登入後加入", "danger")
        return redirect(url_for('teacher_classroom_students', classroom_id=classroom_id))

    rows, bad = _parse_roster(request.form.get('roster'))
    if not rows and not bad:
        flash("請貼上學生名單，每行一位：學號 姓名", "danger")
        return redirect(url_for('teacher_classroom_students', classroom_id=classroom_id))
    if len(rows) > ROSTER_MAX_LINES:
        flash(f"一次最多加入 {ROSTER_MAX_LINES} 位學生，請分批貼上", "danger")
        return redirect(url_for('teacher_classroom_students', classroom_id=classroom_id))

    created, joined, already, conflicts = [], [], [], []
    new_passwords = []   # 只顯示這一次的初始密碼
    seen = set()
    for student_no, name in rows:
        if student_no in seen:
            continue
        seen.add(student_no)
        user = User.query.filter_by(email=student_no).first()
        if user is None:
            temp_password = _student_temp_password()
            user = User(
                email=student_no,
                password_hash=generate_password_hash(temp_password),
                friend_id=generate_friend_id(),
                account_type=AccountType.STUDENT,
                must_change_password=True,   # 初始密碼老師也知道，第一次登入要自己換掉
            )
            new_passwords.append({'account': student_no, 'name': name, 'password': temp_password})
            db.session.add(user)
            db.session.flush()
            db.session.add(SystemLog(
                admin_id=session.get('admin_id'), user_id=user.id,
                action='CREATE', target_table='user', target_id=user.id,
                new_value={'email': student_no, 'account_type': AccountType.STUDENT,
                           'via': 'teacher_roster', 'classroom_id': classroom_id}
            ))
            created.append(student_no)
        elif (user.account_type or AccountType.GENERAL) != AccountType.STUDENT:
            conflicts.append(student_no)   # 已是一般版或老師帳號，不能拿來當學生帳號
            continue

        if ClassroomMember.query.filter_by(classroom_id=classroom_id, student_id=user.id).first():
            if student_no not in created:
                already.append(student_no)
            continue
        db.session.add(ClassroomMember(classroom_id=classroom_id, student_id=user.id, display_name=name))
        if student_no not in created:
            joined.append(student_no)
    db.session.commit()

    parts = []
    if created:
        parts.append(f"新建立 {len(created)} 個學生帳號")
    if joined:
        parts.append(f"{len(joined)} 位已有帳號的學生加入班級")
    if already:
        parts.append(f"{len(already)} 位原本就在班上")
    if parts:
        flash("、".join(parts) + "。", "success")
    if conflicts:
        flash("以下帳號已是一般版或老師帳號，無法加入：" + "、".join(conflicts), "danger")
    if bad:
        flash("以下幾行的學號格式不正確（只能是英數字，2～30 字），已略過：" + "、".join(bad[:10])
              + (" …" if len(bad) > 10 else ""), "danger")
    if new_passwords:
        return _render_roster_with_passwords(classroom_id, new_passwords)
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
    if session.get('role') != 'teacher' or not session.get('teacher_user_id'):
        flash("管理者無法代替老師編輯作業，請由班級老師登入後修改", "danger")
        return redirect(url_for('teacher_classroom_assignments', classroom_id=assignment.classroom_id))
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
    late_error = set_late_policy(assignment, request.form.get('late_policy'), request.form.get('late_penalty'))
    db.session.commit()
    if late_error:
        flash(f"作業「{title}」已更新，但{late_error}，遲交規則維持原本的設定", "warning")
    else:
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
    flash(("作業「%s」已發布，學生看得到，也計入學期成績" if assignment.is_published
           else "作業「%s」已下架：學生看不到，也不計入學期成績；已繳交的紀錄保留，重新發布就恢復") % assignment.title, "info")
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
    ClassroomAnnouncement.query.filter_by(assignment_id=assignment_id).delete()
    db.session.delete(assignment)
    db.session.commit()
    note = f"，學生的 {submission_count} 份繳交紀錄一併移除" if submission_count else ""
    flash(f"作業「{title}」已刪除{note}", "success")
    return redirect(url_for('teacher_classroom_assignments', classroom_id=classroom_id))


@app.route('/teacher/assignment/<int:assignment_id>/copy', methods=['POST'])
@teacher_required
def teacher_assignment_copy(assignment_id):
    """把作業複製到老師自己的其他班：同一門課開兩班、或新學期沿用舊班的作業"""
    assignment = _own_assignment(assignment_id)
    if not assignment:
        flash("找不到該作業", "danger")
        return redirect(url_for('teacher_classrooms'))
    back = url_for('teacher_classroom_assignments', classroom_id=assignment.classroom_id)
    if session.get('role') != 'teacher' or not session.get('teacher_user_id'):
        flash("管理者無法代替老師出題，請由班級老師登入後複製", "danger")
        return redirect(back)

    targets = Classroom.query.filter(
        Classroom.id.in_(request.form.getlist('target_classroom_ids', type=int) or [0]),
        Classroom.teacher_id == session['teacher_user_id'],
        Classroom.id != assignment.classroom_id,
        Classroom.is_archived.isnot(True),
    ).all()
    if not targets:
        flash("請勾選要複製到哪個班級", "danger")
        return redirect(back)

    due_at = None
    if request.form.get('due_at'):
        try:
            due_at = datetime.fromisoformat(request.form['due_at'])
        except ValueError:
            flash("截止時間格式不正確", "danger")
            return redirect(back)
    publish = request.form.get('publish') == 'on'
    announce = publish and request.form.get('announce') == 'on'
    copies = []
    for c in targets:
        new = copy_assignment(assignment, c.id, due_at=due_at, publish=publish)
        if announce:
            announce_assignment(new)
        copies.append(new)
    db.session.commit()
    if announce:
        for new in copies:
            push_new_assignment(new)
    names = '、'.join(f"「{c.name}」" for c in targets)
    flash(f"已將「{assignment.title}」複製到 {names}"
          + ("" if publish else "（尚未發布，到該班的作業列表按「發布」學生才看得到）"), "success")
    return redirect(back)


# ---- 班級公告 ----
def _own_announcement(announcement_id):
    a = ClassroomAnnouncement.query.get(announcement_id)
    return a if a and _own_classroom(a.classroom_id) else None


@app.route('/teacher/classroom/<int:classroom_id>/announcements', methods=['GET', 'POST'])
@teacher_required
def teacher_announcements(classroom_id):
    """班級公告：老師發布、學生在 App 教室頁看到（有未讀會顯示紅點）"""
    classroom = _own_classroom(classroom_id)
    if not classroom:
        flash("找不到該班級", "danger")
        return redirect(url_for('teacher_classrooms'))
    if request.method == 'POST':
        # 和出題一樣：super_admin 可以檢視、刪除，但不能代替老師發公告
        if session.get('role') != 'teacher' or not session.get('teacher_user_id'):
            flash("管理者無法代替老師發公告，請由班級老師登入後發布", "danger")
            return redirect(url_for('teacher_announcements', classroom_id=classroom_id))
        title = (request.form.get('title') or '').strip()
        if not title:
            flash("請填寫公告標題", "danger")
            return redirect(url_for('teacher_announcements', classroom_id=classroom_id))
        ann = post_announcement(classroom_id, title, request.form.get('content'))
        db.session.commit()
        pushed = push_announcement(ann)
        flash("公告已發布，學生打開 App 的教室就會看到"
              + (f"，並已推播到 {pushed} 位學生的手機" if pushed else ""), "success")
        return redirect(url_for('teacher_announcements', classroom_id=classroom_id))
    return render_template('teacher/announcements.html', classroom=classroom,
                           announcements=get_announcements(classroom_id))


@app.route('/teacher/announcement/<int:announcement_id>/edit', methods=['POST'])
@teacher_required
def teacher_announcement_edit(announcement_id):
    """修改公告內容。不會重新變成未讀，要提醒學生請另發一則"""
    a = _own_announcement(announcement_id)
    if not a:
        flash("找不到該公告", "danger")
        return redirect(url_for('teacher_classrooms'))
    back = url_for('teacher_announcements', classroom_id=a.classroom_id)
    if session.get('role') != 'teacher':
        flash("管理者無法代替老師修改公告", "danger")
        return redirect(back)
    title = (request.form.get('title') or '').strip()
    if not title:
        flash("請填寫公告標題", "danger")
        return redirect(back)
    a.title = title[:100]
    a.content = (request.form.get('content') or '').strip()
    a.updated_at = datetime.utcnow()
    db.session.commit()
    flash("公告已更新", "success")
    return redirect(back)


@app.route('/teacher/announcement/<int:announcement_id>/delete', methods=['POST'])
@teacher_required
def teacher_announcement_delete(announcement_id):
    a = _own_announcement(announcement_id)
    if not a:
        flash("找不到該公告", "danger")
        return redirect(url_for('teacher_classrooms'))
    classroom_id = a.classroom_id
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=session.get('teacher_user_id'),
        action='DELETE', target_table='classroom_announcement', target_id=a.id,
        old_value={'classroom_id': classroom_id, 'title': a.title}
    ))
    db.session.delete(a)
    db.session.commit()
    flash("公告已刪除", "success")
    return redirect(url_for('teacher_announcements', classroom_id=classroom_id))


# ==========================================
# 🎓 校園教育版：教師帳號管理（super_admin）
# ==========================================
# 老師帳號存在 user 表（account_type='teacher'），不能自己註冊，只能由這裡建立。
# 這種帳號只能從後台登入頁的「老師」分頁登入，App 的兩個入口都會擋下來。
@app.route('/teacher_account/list')
@super_admin_required
def teacher_account_list():
    return _render_teacher_account_list()


def _render_teacher_account_list(temp_password=None):
    """temp_password：剛產生的臨時密碼（{'username', 'email', 'password'}），只在這次回應顯示"""
    from utils import mailer
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
        'department': t.teacher_department,   # 只有填申請表的老師才有
        'apply_note': t.teacher_apply_note,
        'student_like': _is_student_like_email(t.email),   # 審核時提醒管理者特別確認
        'classroom_count': classroom_counts.get(t.id, 0),
        'created_at': utc_to_tw(t.created_at.strftime('%Y-%m-%d %H:%M:%S')) if t.created_at else '',
    } for t in teachers]
    rows.sort(key=lambda r: 0 if r['status'] == 'pending' else 1)  # 待審核排最前面
    pending_count = sum(1 for r in rows if r['status'] == 'pending')
    return render_template('teacher_account/list.html', teachers=rows, pending_count=pending_count,
                           mail_ready=mailer.is_configured(), temp_password=temp_password,
                           reset_minutes=TEACHER_RESET_LINK_MINUTES)


@app.route('/school/list')
@super_admin_required
def school_list():
    """學校管理：學生在 App 選的學校清單（網域、學號格式、停用）"""
    student_counts = dict(
        db.session.query(User.school_id, func.count(User.id)).filter(User.school_id.isnot(None)).group_by(User.school_id).all()
    )
    schools = [{
        'id': s.id,
        'name': s.name,
        'domains': s.domain_list(),
        'student_domains': s.student_domains,
        'pattern': s.student_id_pattern,
        'pattern_custom': s.student_id_pattern not in (DEFAULT_STUDENT_ID_PATTERN, OLD_DEFAULT_STUDENT_ID_PATTERN),
        'is_active': s.is_active is not False,
        'student_count': student_counts.get(s.id, 0),
        # 學生在 App 新增的學校：顯示是誰新增的，名稱打錯時管理者知道要改
        'created_by': getattr(User.query.get(s.created_by_user_id), 'email', None) if s.created_by_user_id else None,
    } for s in School.query.order_by(School.name).all()]
    # 預設學校有一百多間、大部分沒人用：有學生、App 新增、停用或改過學號格式的才直接列出來，其餘收合
    for s in schools:
        s['featured'] = bool(s['student_count'] or s['created_by'] or not s['is_active'] or s['pattern_custom'])
    schools.sort(key=lambda s: -s['student_count'])  # 穩定排序，同人數維持校名順序
    return render_template('school/list.html', schools=schools, default_pattern=DEFAULT_STUDENT_ID_PATTERN)


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
    mailed = _notify_teacher_approved(teacher)
    flash(f'已核准「{teacher.username}」的老師身分，老師重新整理頁面即可建立班級'
          + ('，已寄信通知老師' if mailed else ''), 'success')
    return redirect(url_for('teacher_account_list'))


def _notify_teacher_approved(teacher):
    """核准後寄信通知老師（申請表送出後老師不會一直盯著畫面）；沒設定寄信或寄失敗都不影響核准，回傳是否寄出"""
    from utils import mailer
    if not mailer.is_configured():
        return False
    how = '學校 Google 帳號' if _teacher_google_only(teacher) else 'Email 與申請時設定的密碼'
    try:
        mailer.send_mail(
            teacher.email, 'Snap to Learn 老師帳號已核准',
            f'{teacher.username} 老師您好：\n\n你的 Snap to Learn 校園教育版老師帳號已通過審核。\n'
            f'請到 {url_for("admin_login", _external=True)} 的「老師」分頁，用{how}登入，就可以建立班級。\n\n'
            f'Snap to Learn 校園教育版',
        )
        return True
    except Exception as e:
        print(f"⚠️ 寄送老師核准通知失敗：{e}")
        return False


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


def _validate_password(pw, account=None, old_hash=None):
    """老師、管理者帳號的密碼：8 個字元以上且強度至少「中」（規則見 utils/password_policy.py）"""
    from utils import password_policy
    return password_policy.validate(pw, account=account, require_medium=True, old_hash=old_hash)


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
    elif _validate_password(password, account=email):
        error = _validate_password(password, account=email)
    elif User.query.filter_by(email=email).first():
        error = f'Email「{email}」已經被使用'
    elif User.query.filter_by(username=username, account_type=AccountType.TEACHER).first():
        error = f'已經有老師叫「{username}」，請換一個（例如加上科目或班級）'
    if error:
        flash(error, 'error')
        return redirect(url_for('teacher_account_list'))

    teacher = User(
        email=email,
        username=username,
        password_hash=generate_password_hash(password),
        account_type=AccountType.TEACHER,
        must_change_password=True,   # 密碼是管理者設的，老師第一次用密碼登入要自己換掉
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
    """老師忘記密碼。管理者不能自己指定密碼，只有兩種做法：
    - mode=link（預設）：寄重設連結到老師信箱，老師自己設定新密碼，管理者完全碰不到密碼
    - mode=temp：老師收不到信（信箱是假的、寄信服務沒設定）時，由系統產生隨機臨時密碼，
      只在這次顯示，老師下次登入要先換掉
    """
    from utils import mailer
    admin_id = session.get('admin_id')
    teacher = User.query.filter_by(id=user_id, account_type=AccountType.TEACHER).first_or_404()

    if request.form.get('mode') == 'temp':
        temp_password = _student_temp_password()
        teacher.password_hash = generate_password_hash(temp_password)
        teacher.must_change_password = True   # 臨時密碼管理者也知道，老師下次用密碼登入要先換掉
        db.session.add(SystemLog(
            admin_id=admin_id, user_id=teacher.id,
            action='UPDATE', target_table='user', target_id=teacher.id,
            new_value={'password': 'reset_to_temp'}
        ))
        db.session.commit()
        return _render_teacher_account_list(temp_password={
            'username': teacher.username, 'email': teacher.email, 'password': temp_password})

    if not mailer.is_configured():
        flash('寄信服務尚未設定，無法寄重設連結，請改用「產生臨時密碼」', 'error')
        return redirect(url_for('teacher_account_list'))
    link = url_for('teacher_reset_password', token=_teacher_reset_token(teacher), _external=True)
    try:
        mailer.send_mail(
            teacher.email, 'Snap to Learn 老師帳號：重設密碼',
            f'{teacher.username} 老師您好：\n\n'
            f'學校系統管理員為你的 Snap to Learn 校園教育版老師帳號寄出了重設密碼連結。'
            f'請在 {TEACHER_RESET_LINK_MINUTES} 分鐘內點下面的連結，設定新的登入密碼：\n\n{link}\n\n'
            f'連結只能使用一次。如果你沒有要求重設密碼，請忽略這封信，原本的密碼不會改變。\n\n'
            f'Snap to Learn 校園教育版',
        )
    except Exception as e:
        print(f"⚠️ 寄送老師重設密碼連結失敗：{e}")
        flash(f'重設連結寄送失敗（{teacher.email}），請稍後再試，或改用「產生臨時密碼」', 'error')
        return redirect(url_for('teacher_account_list'))
    # 只是寄出連結、密碼還沒變，所以不用 'password' 這個 key（_teacher_google_only 靠它判斷帳號有沒有密碼）
    db.session.add(SystemLog(
        admin_id=admin_id, user_id=teacher.id,
        action='UPDATE', target_table='user', target_id=teacher.id,
        new_value={'password_reset': 'link_sent'}
    ))
    db.session.commit()
    flash(f'已寄出重設連結到 {teacher.email}，{TEACHER_RESET_LINK_MINUTES} 分鐘內有效', 'success')
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


# ---- 學校：學生在 App 先選學校，再用學校 Google 帳號登入 ----
SCHOOL_DOMAIN_RE = re.compile(r'^\.?[a-z0-9-]+(\.[a-z0-9-]+)+$')


def _school_form():
    """讀取並檢查學校表單，回傳 (資料, 錯誤訊息)"""
    name = (request.form.get('name') or '').strip()[:50]
    domains = [d.strip().lower().lstrip('@') for d in re.split(r'[,，\s]+', request.form.get('student_domains') or '') if d.strip()]
    pattern = (request.form.get('student_id_pattern') or '').strip() or DEFAULT_STUDENT_ID_PATTERN
    if not name:
        return None, '請輸入學校名稱'
    if not domains:
        return None, '請輸入學生 Google 帳號的網域，例如 gm.xxx.edu.tw'
    bad = [d for d in domains if not SCHOOL_DOMAIN_RE.match(d)]
    if bad:
        return None, '網域格式不正確：' + '、'.join(bad)
    try:
        re.compile(pattern)
    except re.error:
        return None, '學號格式（正規式）寫錯了，請檢查括號與符號'
    return {'name': name, 'student_domains': ','.join(domains), 'student_id_pattern': pattern[:100]}, None


@app.route('/school/add', methods=['POST'])
@super_admin_required
def school_add():
    form, error = _school_form()
    if not error and School.query.filter_by(name=form['name']).first():
        error = f'已經有「{form["name"]}」了'
    if error:
        flash(error, 'error')
        return redirect(url_for('school_list'))
    school = School(**form)
    db.session.add(school)
    db.session.flush()
    db.session.add(SystemLog(admin_id=session.get('admin_id'), action='CREATE',
                             target_table='school', target_id=school.id, new_value=form))
    db.session.commit()
    flash(f'已新增「{school.name}」，學生在 App 校園教育版選這間學校後，就能用學校 Google 帳號登入', 'success')
    return redirect(url_for('school_list'))


@app.route('/school/edit/<int:school_id>', methods=['POST'])
@super_admin_required
def school_edit(school_id):
    school = School.query.get_or_404(school_id)
    form, error = _school_form()
    if not error and School.query.filter(School.name == form['name'], School.id != school.id).first():
        error = f'已經有「{form["name"]}」了'
    if error:
        flash(error, 'error')
        return redirect(url_for('school_list'))
    old = {'name': school.name, 'student_domains': school.student_domains, 'student_id_pattern': school.student_id_pattern}
    for key, value in form.items():
        setattr(school, key, value)
    db.session.add(SystemLog(admin_id=session.get('admin_id'), action='UPDATE',
                             target_table='school', target_id=school.id, old_value=old, new_value=form))
    db.session.commit()
    flash(f'已更新「{school.name}」', 'success')
    return redirect(url_for('school_list'))


@app.route('/school/toggle/<int:school_id>', methods=['POST'])
@super_admin_required
def school_toggle(school_id):
    """停用後 App 的學校清單不再顯示、也不能用這間學校登入；已建立的學生帳號與班級資料保留"""
    school = School.query.get_or_404(school_id)
    school.is_active = not bool(school.is_active)
    db.session.add(SystemLog(admin_id=session.get('admin_id'), action='UPDATE',
                             target_table='school', target_id=school.id, new_value={'is_active': school.is_active}))
    db.session.commit()
    flash(('已啟用「%s」' if school.is_active else '已停用「%s」，學生無法再選這間學校登入') % school.name, 'success')
    return redirect(url_for('school_list'))


# ==========================================
# 🔐 管理員帳號管理（super_admin）
# ==========================================
# 取代原本不驗證身分的「忘記密碼」：帳號建立、權限、停用、重設密碼都由 super_admin 在這裡處理。
ADMIN_ROLES = ('admin', 'super_admin')


def _active_super_admin_count():
    return Admin.query.filter(Admin.role == 'super_admin', Admin.is_active.isnot(False)).count()


@app.route('/admin_account/list')
@super_admin_required
def admin_account_list():
    admins = Admin.query.order_by(Admin.id).all()
    rows = [{
        'id': a.id, 'username': a.username, 'role': a.role,
        'is_active': a.is_active is not False,
        'must_change_password': bool(a.must_change_password),
        'is_me': a.id == session.get('admin_id'),
        'last_login_at': utc_to_tw(a.last_login_at.strftime('%Y-%m-%d %H:%M:%S')) if a.last_login_at else '',
    } for a in admins]
    return render_template('admin_account/list.html', admins=rows)


@app.route('/admin_account/add', methods=['POST'])
@super_admin_required
def admin_account_add():
    username = (request.form.get('username') or '').strip()
    role = request.form.get('role') or 'admin'
    password = request.form.get('password') or ''
    error = None
    if not username:
        error = '請輸入帳號'
    elif role not in ADMIN_ROLES:
        error = '權限不正確'
    elif _validate_password(password, account=username):
        error = _validate_password(password, account=username)
    elif Admin.query.filter_by(username=username).first():
        error = f'帳號「{username}」已存在'
    if error:
        flash(error, 'error')
        return redirect(url_for('admin_account_list'))
    admin = Admin(username=username, role=role, is_active=True, must_change_password=True)
    admin.set_password(password)
    db.session.add(admin)
    db.session.flush()
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=None,
        action='CREATE', target_table='admin', target_id=admin.id,
        new_value={'username': username, 'role': role}
    ))
    db.session.commit()
    flash(f'已建立管理員「{username}」（{role}），對方第一次登入需先修改密碼', 'success')
    return redirect(url_for('admin_account_list'))


@app.route('/admin_account/reset_password/<int:admin_id>', methods=['POST'])
@super_admin_required
def admin_account_reset_password(admin_id):
    admin = Admin.query.get_or_404(admin_id)
    password = request.form.get('password') or ''
    pw_error = _validate_password(password, account=admin.username)
    if pw_error:
        flash(pw_error, 'error')
        return redirect(url_for('admin_account_list'))
    admin.set_password(password)
    admin.must_change_password = True
    if admin.id == session.get('admin_id'):
        session['must_change_password'] = True
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=None,
        action='UPDATE', target_table='admin', target_id=admin.id,
        new_value={'password': 'reset'}
    ))
    db.session.commit()
    flash(f'已重設「{admin.username}」的密碼，對方登入後需立刻修改', 'success')
    return redirect(url_for('admin_account_list'))


@app.route('/admin_account/toggle_active/<int:admin_id>', methods=['POST'])
@super_admin_required
def admin_account_toggle_active(admin_id):
    admin = Admin.query.get_or_404(admin_id)
    if admin.id == session.get('admin_id'):
        flash('不能停用自己的帳號', 'error')
        return redirect(url_for('admin_account_list'))
    currently_active = admin.is_active is not False
    if currently_active and admin.role == 'super_admin' and _active_super_admin_count() <= 1:
        flash('至少要保留一位可用的 super_admin', 'error')
        return redirect(url_for('admin_account_list'))
    admin.is_active = not currently_active
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=None,
        action='UPDATE', target_table='admin', target_id=admin.id,
        new_value={'is_active': admin.is_active}
    ))
    db.session.commit()
    flash(('已停用「%s」' if not admin.is_active else '已啟用「%s」') % admin.username, 'success')
    return redirect(url_for('admin_account_list'))


@app.route('/admin_account/toggle_role/<int:admin_id>', methods=['POST'])
@super_admin_required
def admin_account_toggle_role(admin_id):
    admin = Admin.query.get_or_404(admin_id)
    if admin.id == session.get('admin_id'):
        flash('不能修改自己的權限', 'error')
        return redirect(url_for('admin_account_list'))
    if admin.role == 'super_admin' and (admin.is_active is not False) and _active_super_admin_count() <= 1:
        flash('至少要保留一位可用的 super_admin', 'error')
        return redirect(url_for('admin_account_list'))
    old_role = admin.role
    admin.role = 'admin' if admin.role == 'super_admin' else 'super_admin'
    db.session.add(SystemLog(
        admin_id=session.get('admin_id'), user_id=None,
        action='UPDATE', target_table='admin', target_id=admin.id,
        old_value={'role': old_role}, new_value={'role': admin.role}
    ))
    db.session.commit()
    flash(f'「{admin.username}」的權限已改為 {admin.role}', 'success')
    return redirect(url_for('admin_account_list'))


_lan_ip_cache = {'ip': None, 'at': 0.0}


def _lan_ip():
    """這台電腦目前在區網（Wi-Fi）的 IP；換網路就會變，所以快取 60 秒後重查。
    在 Docker 容器裡查到的是容器內部 IP，組員連不到，回傳 None。"""
    import time as _time
    if os.path.exists('/.dockerenv'):
        return None
    if _time.time() - _lan_ip_cache['at'] < 60:
        return _lan_ip_cache['ip']
    import socket
    ip = None
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))      # UDP 的 connect 不會真的送出封包，只是讓系統選出對外用的網卡
        ip = s.getsockname()[0]
        s.close()
        if ip.startswith('127.'):
            ip = None
    except OSError:
        ip = None
    _lan_ip_cache.update(ip=ip, at=_time.time())
    return ip


@app.before_request
def _prefer_localhost():
    """在後台所在的同一台電腦上，不管開 127.0.0.1 還是自己的區網 IP，都轉到 localhost：
    瀏覽器記住的密碼、登入狀態都綁在網址上，統一用 localhost 才不會「換個網址就登不進去」，
    Google 登入也只接受 localhost。從別台電腦連進來的組員維持原本的 IP，不會被轉走。"""
    if request.method != 'GET':
        return None
    host, _, port = request.host.partition(':')
    lan = _lan_ip()
    same_machine = host == '127.0.0.1' or (lan and host == lan and request.remote_addr in ('127.0.0.1', lan))
    if not same_machine:
        return None
    target = request.url.replace(f'//{request.host}', f'//localhost{":" + port if port else ""}', 1)
    return redirect(target)


def _lan_url(host=None):
    """給同一個 Wi-Fi 的組員用的後台登入網址，例如 http://192.168.0.111:5001/login"""
    ip = _lan_ip()
    if not ip:
        return None
    port = (host or '').rsplit(':', 1)[-1] if host and ':' in host else '5001'
    return f'http://{ip}:{port}/login'


def _print_login_hint():
    url = _lan_url()
    print('\n' + '=' * 60)
    print('  ↑ 上面兩個網址都能用，在這台電腦開會自動轉到 localhost')
    print('  自己登入請開：http://localhost:5001/login')
    if url:
        print(f'  同一個 Wi-Fi 的組員（用別台電腦）請開：{url}')
    print('=' * 60 + '\n', flush=True)


if __name__ == '__main__':
    # debug 模式會啟動兩次（監看程式＋真正的伺服器）；在真正的伺服器裡、Flask 印完
    # 「Running on ...」之後再印提示，讓終端機最後看到的是這段說明
    if os.environ.get('WERKZEUG_RUN_MAIN') == 'true':
        import threading
        threading.Timer(1.5, _print_login_hint).start()
    # host='0.0.0.0'：容器內要綁全介面，外面才連得到（本機直接跑也不影響）
    app.run(host='0.0.0.0', debug=True, port=5001)



