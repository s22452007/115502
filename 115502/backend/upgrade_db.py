import sqlite3
import os

# 找到你的資料庫位置
db_path = os.path.join('instance', 'jlens.db')

try:
    # 連線到資料庫
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 使用 SQL 語法，強行在 user 表格加上 friend_id 欄位
    cursor.execute("ALTER TABLE user ADD COLUMN friend_id VARCHAR(20);")
    conn.commit()
    print("✅ 太棒了！成功為現有的 User 表格加入 friend_id 欄位！你的測試資料都還在！")
    
except Exception as e:
    print(f"⚠️ 執行結果: {e} (如果你看到寫著 duplicate column name，代表已經加成功過了)")
finally:
    conn.close()