import sqlite3
import os
from flask import Flask, render_template

app = Flask(__name__)


BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DB_FILE_PATH = os.path.join(BASE_DIR, 'instance', 'jlens.db')


print("-" * 30)
print(f"🕵️ 管理後台正在讀取的資料庫路徑是：\n{DB_FILE_PATH}")
print("-" * 30)

def get_db_connection():
    if not os.path.exists(DB_FILE_PATH):
        print("❌ 警告：找不到資料庫檔案，現在讀取的是自動生成的空檔案！")
    
    conn = sqlite3.connect(DB_FILE_PATH)
    conn.row_factory = sqlite3.Row 
    return conn

# ==========================================
# 網頁路由區塊
# ==========================================
@app.route('/', methods=['GET'])
def index():
    conn = get_db_connection()
    # 計算總使用者數
    user_count = conn.execute('SELECT COUNT(*) FROM user').fetchone()[0]
    # 計算總照片數
    photo_count = conn.execute('SELECT COUNT(*) FROM user_photo').fetchone()[0]
    # 計算總學習小組數
    group_count = conn.execute('SELECT COUNT(*) FROM study_group').fetchone()[0]
    conn.close()
    
    # 把這些數字傳遞給前端網頁
    return render_template('index.html', 
                           user_count=user_count, 
                           photo_count=photo_count, 
                           group_count=group_count)

# ==========================================
# 客戶清單：從資料庫撈取真實資料
# ==========================================
@app.route('/customer/list', methods=['GET'])
def customer_list():
    conn = get_db_connection()
    # 撈取使用者資料
    users = conn.execute('SELECT id, username, email, created_at, j_pts FROM user').fetchall()
    conn.close()
    
    return render_template('customer/list.html', customers=users)


# ==========================================
# 照片與相簿管理模組
# ==========================================
@app.route('/photo/list', methods=['GET'])
def photo_list():
    conn = get_db_connection()
    # 使用 JOIN 語法，把照片關聯的「使用者名稱」和「場景名稱」一起撈出來
    query = '''
        SELECT 
            p.id, 
            u.username, 
            s.name as scene_name, 
            p.custom_title, 
            p.image_path, 
            p.created_at 
        FROM user_photo p
        LEFT JOIN user u ON p.user_id = u.id
        LEFT JOIN scene s ON p.scene_id = s.id
        ORDER BY p.created_at DESC
    '''
    photos = conn.execute(query).fetchall()
    conn.close()
    
    return render_template('photo/list.html', photos=photos)
# ==========================================
# 🚀 啟動伺服器的馬達 (就是這裡剛剛可能不見了！)
# ==========================================
if __name__ == '__main__':
    app.run(debug=True, port=5001)