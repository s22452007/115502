import sqlite3
import os

# 確保對準 instance 資料夾裡的 jlens.db
db_path = os.path.join('instance', 'jlens.db')

# 連接到你的資料庫
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    # 請資料庫幫我們在 study_group 表加上這兩個新欄位，並設定預設值
    cursor.execute("ALTER TABLE study_group ADD COLUMN goal_type VARCHAR(50) NOT NULL DEFAULT 'scans';")
    cursor.execute("ALTER TABLE study_group ADD COLUMN goal_target INTEGER NOT NULL DEFAULT 30;")
    print("✅ 太棒了！資料庫升級成功！小組目標的兩個新欄位已經加入囉！")
except sqlite3.OperationalError as e:
    print(f"⚠️ 欄位可能已經存在，或是發生小錯誤：{e}")

conn.commit()
conn.close()