import sqlite3
import os
from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)

# ==========================================
# 🚀 自動偵測資料庫路徑 (最保險的做法)
# ==========================================
# 取得目前這個 admin_app.py 所在的資料夾路徑
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

# 這裡會嘗試兩個最可能的路徑，哪個有檔案就用哪個
path_option1 = os.path.join(BASE_DIR, 'instance', 'jlens.db')
path_option2 = os.path.join(BASE_DIR, '..', 'instance', 'jlens.db')

if os.path.exists(path_option1):
    DB_FILE_PATH = path_option1
elif os.path.exists(path_option2):
    DB_FILE_PATH = path_option2
else:
    # 如果都找不到，就維持你指定的那個絕對路徑
    DB_FILE_PATH = r'C:\Users\aaasa\115502\backend\instance\jlens.db'

print("-" * 30)
print(f"🕵️ 系統目前鎖定的資料庫位置：\n{DB_FILE_PATH}")
if not os.path.exists(DB_FILE_PATH):
    print("❌ 警告：路徑依據不存在，請確認 jlens.db 檔案位置！")
print("-" * 30)

def get_db_connection():
    # 這裡加入 check_same_thread=False 防止 Flask 在多執行緒下報錯
    conn = sqlite3.connect(DB_FILE_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row 
    return conn

# ==========================================
# [首頁] 莫蘭迪數據儀表板
# ==========================================
@app.route('/')
def index():
    try:
        conn = get_db_connection()
        user_count = conn.execute('SELECT COUNT(*) FROM user').fetchone()[0]
        photo_count = conn.execute('SELECT COUNT(*) FROM user_photo').fetchone()[0]
        # 檢查是否有 vocab 表，避免新環境報錯
        vocab_count = conn.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='vocab'").fetchone()[0]
        if vocab_count > 0:
            vocab_count = conn.execute('SELECT COUNT(*) FROM vocab').fetchone()[0]
        else:
            vocab_count = 0
        conn.close()
    except Exception as e:
        print(f"首頁資料讀取失敗: {e}")
        user_count, photo_count, vocab_count = 0, 0, 0
        
    return render_template('index.html', user_count=user_count, photo_count=photo_count, vocab_count=vocab_count)

# ==========================================
# [使用者管理]
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

if __name__ == '__main__':
    app.run(debug=True, port=5001)