import sqlite3
import os

# 1. 自動抓取 upgrade_db.py 所在的絕對路徑 (也就是 backend 資料夾的位置)
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

# 2. 精準對準 backend/instance/jlens.db
db_path = os.path.join(BASE_DIR, 'instance', 'jlens.db')

# 連接到你的資料庫
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# ==========================================
# 1. 升級 group_member
# ==========================================
try:
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_scans INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_points INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE group_member ADD COLUMN group_logins INTEGER DEFAULT 0;")
    print("✅ group_member 欄位升級成功")
except sqlite3.OperationalError as e:
    print(f"⚠️ group_member 欄位可能已存在：{e}")

# ==========================================
# 2. 升級 user
# ==========================================
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

# ==========================================
# 🚀 3. 新增：升級 study_group (學習小組獎勵機制)
# ==========================================
try:
    cursor.execute("ALTER TABLE study_group ADD COLUMN current_progress INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE study_group ADD COLUMN reward_points INTEGER DEFAULT 50;")
    cursor.execute("ALTER TABLE study_group ADD COLUMN is_reward_claimed BOOLEAN DEFAULT 0;")
    print("✅ study_group 獎勵機制欄位升級成功！")
except sqlite3.OperationalError as e:
    print(f"⚠️ study_group 欄位可能已存在：{e}")

# 儲存並關閉
conn.commit()
conn.close()

print("🎉 資料庫全面升級完成！")