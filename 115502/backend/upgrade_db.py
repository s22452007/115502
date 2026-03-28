import sqlite3
import os

# 確保對準 instance 資料夾裡的 jlens.db
db_path = os.path.join('instance', 'jlens.db')

# 連接到你的資料庫
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_scans INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_points INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_logins INTEGER DEFAULT 0;")
    print("✅ group_member 欄位升級成功")
except sqlite3.OperationalError as e:
    print(f"⚠️ group_member 欄位可能已存在：{e}")

try:
    cursor.execute("ALTER TABLE user ADD COLUMN username VARCHAR(30);")
    print("✅ user.username 欄位加入成功")
except sqlite3.OperationalError as e:
    print(f"⚠️ user.username 欄位可能已存在：{e}")

try:
    cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_username ON user(username);")
    print("✅ username 唯一索引建立成功")
except sqlite3.OperationalError as e:
    print(f"⚠️ username 索引：{e}")

conn.commit()
conn.close()