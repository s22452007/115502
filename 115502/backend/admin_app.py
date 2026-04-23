import sqlite3
import os
from datetime import datetime, timedelta
from flask import Flask, render_template, request, redirect, url_for


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
# [首頁] 儀表板
# ==========================================
@app.route('/')
def index():
    conn = get_db_connection()
    user_count = conn.execute('SELECT COUNT(*) FROM user').fetchone()[0]
    photo_count = conn.execute('SELECT COUNT(*) FROM user_photo').fetchone()[0]
    # 安全檢查 vocab 表
    vocab_exists = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='vocab'").fetchone()
    vocab_count = conn.execute('SELECT COUNT(*) FROM vocab').fetchone()[0] if vocab_exists else 0

    # 今日活躍人數 (今天有登入過的)
    from datetime import date
    today_str = date.today().strftime('%Y-%m-%d')
    today_active = conn.execute(
        "SELECT COUNT(*) FROM user WHERE DATE(last_login_date) = ?", (today_str,)
    ).fetchone()[0]

    # 總回饋數 / 待回覆
    feedback_total = conn.execute('SELECT COUNT(*) FROM feedback').fetchone()[0]
    feedback_pending = conn.execute(
        'SELECT COUNT(*) FROM feedback WHERE reply IS NULL OR reply = ""'
    ).fetchone()[0]

    conn.close()
    return render_template('index.html',
                           user_count=user_count,
                           photo_count=photo_count,
                           vocab_count=vocab_count,
                           today_active=today_active,
                           feedback_total=feedback_total,
                           feedback_pending=feedback_pending)

# ==========================================
# [使用者管理] 包含點數 (j_pts)
# ==========================================
@app.route('/customer/list')
def customer_list():
    conn = get_db_connection()
    users = conn.execute('SELECT id, username, email, j_pts, created_at FROM user').fetchall()
    conn.close()
    return render_template('customer/list.html', customers=users)

@app.route('/customer/adjust_pts/<int:user_id>', methods=['POST'])
def adjust_pts(user_id):
    amount = int(request.form.get('amount', 0))
    conn = get_db_connection()
    conn.execute('UPDATE user SET j_pts = j_pts + ? WHERE id = ?', (amount, user_id))
    conn.commit()
    conn.close()
    return redirect(url_for('customer_list'))

@app.route('/customer/delete/<int:user_id>', methods=['POST'])
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

# ==========================================
# [照片管控]
# ==========================================
@app.route('/photo/list')
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
@app.route('/vocab/list')
def vocab_list():
    conn = get_db_connection()
    # 關聯查詢單字表與場景表，取得場景名稱 
    query = '''
        SELECT v.id, v.word, v.kana, v.meaning, s.name as scene_name, v.sentence_basic
        FROM vocab v
        LEFT JOIN scene s ON v.scene_id = s.id
        ORDER BY v.id DESC
    '''
    vocabs = conn.execute(query).fetchall()
    conn.close()
    return render_template('vocab/list.html', vocabs=vocabs)

@app.route('/vocab/delete/<int:vocab_id>', methods=['POST'])
def delete_vocab(vocab_id):
    conn = get_db_connection()
    # 執行刪除單字 
    conn.execute('DELETE FROM vocab WHERE id = ?', (vocab_id,))
    conn.commit()
    conn.close()
    return redirect(url_for('vocab_list'))


# ==========================================
# [意見回饋管理]
# ==========================================
@app.route('/feedback/list')
def feedback_list():
    conn = get_db_connection()
    query = '''
        SELECT f.id, f.feedback_type, f.content, f.reply, f.replied_at, f.created_at,
               u.username, u.email
        FROM feedback f
        LEFT JOIN user u ON f.user_id = u.id
        ORDER BY f.created_at DESC
    '''
    feedbacks = conn.execute(query).fetchall()
    conn.close()
    # 把時間都轉成台灣時間
    feedbacks = [
        {**dict(f),
         'created_at': utc_to_tw(f['created_at']),
         'replied_at': utc_to_tw(f['replied_at']) if f['replied_at'] else None}
        for f in feedbacks
    ]
    return render_template('feedback/list.html', feedbacks=feedbacks)

@app.route('/feedback/reply/<int:feedback_id>', methods=['POST'])
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
def user_list():
    keyword = request.args.get('q', '').strip()
    conn = get_db_connection()
    base_query = '''
        SELECT u.id, u.email, u.username, u.friend_id, u.japanese_level,
               u.j_pts, u.streak_days, u.total_active_days,
               DATE(u.created_at) as created_at,
               u.last_seen_at,
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
def quiz_delete(quiz_id):
    conn = get_db_connection()
    conn.execute('DELETE FROM quiz_question WHERE id = ?', (quiz_id,))
    conn.commit()
    conn.close()
    return redirect(url_for('quiz_list'))


@app.route('/quiz/edit/<int:quiz_id>', methods=['POST'])
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


if __name__ == '__main__':
    app.run(debug=True, port=5001)


