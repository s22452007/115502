import sqlite3
import os

# 確保對準 instance 資料夾裡的 jlens.db
db_path = os.path.join('instance', 'jlens.db')

# 連接到你的資料庫
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    # 請資料庫幫我們加上這兩個新欄位
    cursor.execute("ALTER TABLE user ADD COLUMN daily_scans INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE user ADD COLUMN last_scan_date DATE;")
    print("✅ 太棒了！資料庫升級成功！新欄位已經加入囉！")
except sqlite3.OperationalError as e:
    print(f"⚠️ 欄位可能已經存在，或是發生小錯誤：{e}")

conn.commit()
conn.close()