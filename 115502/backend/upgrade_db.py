import sqlite3
import os

# 確保對準 instance 資料夾裡的 jlens.db
db_path = os.path.join('instance', 'jlens.db')

# 連接到你的資料庫
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    # 🌟 請資料庫幫我們在 group_member 表加上這三個新欄位，並設定預設值為 0
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_scans INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_points INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_logins INTEGER DEFAULT 0;")
    print("✅ 太棒了！資料庫升級成功！小組成員的三個專屬貢獻欄位已經加入囉！")
except sqlite3.OperationalError as e:
    print(f"⚠️ 欄位可能已經存在，或是發生小錯誤：{e}")

conn.commit()
conn.close()