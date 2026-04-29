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

# ==========================================
# 🏠 2. 首頁導航 (解決無限迴圈的關鍵)
# ==========================================
@app.route('/')
def admin_root():
    
    return redirect(url_for('admin_login'))         # 沒登入就去登入頁

# ==========================================
# 🚪 3. 登入與登出系統
# ==========================================
@app.route('/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        admin = Admin.query.filter_by(username=username).first()
        if admin and admin.check_password(password):
            session['admin_user'] = admin.username
            session.permanent = True
            return redirect(url_for('admin_dashboard')) # 密碼正確去儀表板
        else:
            return render_template('admin_login.html', error="帳號或密碼錯誤")
            
    return render_template('admin_login.html')

@app.route('/logout')
def admin_logout():
    session.clear()
    return redirect(url_for('admin_login'))

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

@app.route('/customer/delete/<int:user_id>', methods=['POST'])
@admin_login_required
def delete_user(user_id):
    conn = get_db_connection()
    # user_photo_vocab 依賴 user_photo，要先刪
    conn.execute('''
        DELETE FROM user_photo_vocab WHERE photo_id IN
        (SELECT id FROM user_photo WHERE user_id = ?)
    ''', (user_id,))
    conn.execute('DELETE FROM user_photo WHERE user_id = ?', (user_id,))
    conn.execute('DELETE FROM user_vocab WHERE user_id = ?', (user_id,))
    conn.execute('DELETE FROM user_folder WHERE user_id = ?', (user_id,))
    conn.execute('DELETE FROM user_ability WHERE user_id = ?', (user_id,))
    conn.execute('DELETE FROM user_achievement WHERE user_id = ?', (user_id,))
    conn.execute('DELETE FROM point_transaction WHERE user_id = ?', (user_id,))
    conn.execute('DELETE FROM friendship WHERE user_id = ? OR friend_id = ?', (user_id, user_id))
    conn.execute('DELETE FROM friend_request WHERE sender_id = ? OR receiver_id = ?', (user_id, user_id))
    conn.execute('DELETE FROM group_member WHERE user_id = ?', (user_id,))
    conn.execute('DELETE FROM feedback WHERE user_id = ?', (user_id,))
    conn.execute('DELETE FROM user WHERE id = ?', (user_id,))
    conn.commit()
    conn.close()
    return redirect(url_for('customer_list'))


@app.route('/purchase/list')
# 如果您有登入驗證，請記得加上您的裝飾器，例如 @admin_login_required
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
    query = '''
        SELECT p.id, u.username, s.name as scene_name, p.custom_title, p.created_at 
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

    # 檢查 last_seen_at 欄位是否存在
    cols = [row[1] for row in conn.execute("PRAGMA table_info(user)").fetchall()]
    has_last_seen = 'last_seen_at' in cols
    last_seen_col = 'u.last_seen_at' if has_last_seen else 'NULL as last_seen_at'

    base_query = f'''
        SELECT u.id, u.email, u.username, u.friend_id, u.japanese_level,
               u.j_pts,
               CASE WHEN u.last_login_date >= DATE('now', '-1 day') THEN u.streak_days ELSE 0 END as streak_days,
               u.total_active_days,
               u.avatar,
               DATE(u.created_at) as created_at,
               {last_seen_col},
               (SELECT COUNT(*) FROM user_vocab WHERE user_id = u.id AND collected_at IS NOT NULL) as vocab_count,
               (SELECT COUNT(*) FROM user_folder WHERE user_id = u.id) as folder_count,
               (SELECT COUNT(*) FROM friendship WHERE user_id = u.id) as friend_count
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



