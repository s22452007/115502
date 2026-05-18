import sqlite3
import os
from werkzeug.security import generate_password_hash

# 自動對準你的資料庫位置
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DB_PATH = os.path.join(BASE_DIR, 'instance', 'jlens.db')
if not os.path.exists(DB_PATH):
    DB_PATH = os.path.join(BASE_DIR, 'jlens.db')

admin_ids = ['11156001', '11156006', '11156015', '11156039', '11156047']

def init_default_admins():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    print("🛠️ 開始檢查並升級資料庫欄位...")
    # 自動幫舊的 admin 資料表補上 role 欄位
    try:
        cursor.execute("ALTER TABLE admin ADD COLUMN role VARCHAR(20) DEFAULT 'admin'")
        print("✅ 成功為 admin 資料表加入 'role' 權限欄位！")
    except sqlite3.OperationalError:
        print("⚡ 'role' 欄位已存在，無需新增。")
        
    # 自動幫舊的 admin 資料表補上 created_at 欄位
    try:
        cursor.execute("ALTER TABLE admin ADD COLUMN created_at DATETIME")
        print("✅ 成功為 admin 資料表加入 'created_at' 時間欄位！")
    except sqlite3.OperationalError:
        pass

    print("\n👤 開始初始化管理員帳號...")
    
    for uid in admin_ids:
        hashed_pw = generate_password_hash(uid)
        try:
            # 統一給予 super_admin 權限
            cursor.execute(
                "INSERT INTO admin (username, password_hash, role) VALUES (?, ?, ?)",
                (uid, hashed_pw, 'super_admin')
            )
            print(f"✅ 帳號 {uid} 建立成功！(預設密碼: {uid})")
        except sqlite3.IntegrityError:
            print(f"⚠️ 帳號 {uid} 已經存在，跳過。")
            
    conn.commit()
    conn.close()
    print("🎉 資料庫升級與初始化大功告成！")

if __name__ == '__main__':
    init_default_admins()