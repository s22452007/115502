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

# ==========================================
# 4. 升級 user_vocab (收藏夾資料夾功能)
# ==========================================
try:
    cursor.execute("ALTER TABLE user_vocab ADD COLUMN folder_id INTEGER;")
    print("✅ user_vocab.folder_id 欄位加入成功")
except sqlite3.OperationalError as e:
    print(f"⚠️ user_vocab.folder_id 可能已存在：{e}")

# ==========================================
# 5. 升級 vocab (單字詳細內容：適性化分級例句與音檔)
# ==========================================
try:
    cursor.execute("ALTER TABLE vocab ADD COLUMN example_sentence VARCHAR(255);")
except sqlite3.OperationalError:
    pass

try:
    cursor.execute("ALTER TABLE vocab ADD COLUMN sentence_basic VARCHAR(255);")
    cursor.execute("ALTER TABLE vocab ADD COLUMN sentence_inter VARCHAR(255);")
    cursor.execute("ALTER TABLE vocab ADD COLUMN sentence_advanced VARCHAR(255);")
    cursor.execute("ALTER TABLE vocab ADD COLUMN audio_filename VARCHAR(100);")
    print("✅ vocab 單字表擴充成功 (加入初、中、高級分級例句與音檔)！")
except sqlite3.OperationalError as e:
    print(f"⚠️ vocab 分級例句欄位可能已存在：{e}")

# ==========================================
# 📖 6. 新增 quiz_question (測驗題庫表)
# ==========================================
try:
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS quiz_question (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage VARCHAR(50) NOT NULL,
        level_tag VARCHAR(20) NOT NULL,
        question TEXT NOT NULL,
        option_a VARCHAR(100) NOT NULL,
        option_b VARCHAR(100) NOT NULL,
        option_c VARCHAR(100) NOT NULL,
        option_d VARCHAR(100) NOT NULL,
        correct_answer VARCHAR(1) NOT NULL
    );
    """)
    print("✅ quiz_question 測驗題目表確認/建立成功！")
except sqlite3.OperationalError as e:
    print(f"⚠️ quiz_question 建立失敗：{e}")

# ==========================================
# 📸 7. 升級 user_scene & Vocab 中高級
# ==========================================
try:
    cursor.execute("ALTER TABLE user_scene ADD COLUMN image_path VARCHAR(255);")
    print("✅ user_scene 擴充成功 (加入照片路徑欄位)！")
except sqlite3.OperationalError:
    pass

try:
    cursor.execute("ALTER TABLE vocab ADD COLUMN sentence_upper_inter VARCHAR(255);")
    print("✅ vocab 成功新增『中高級』例句欄位！")
except sqlite3.OperationalError:
    pass

# ==========================================
# 🏆 8. 升級 User 表 (新版 5 大徽章計數器)
# ==========================================
try:
    cursor.execute("ALTER TABLE user ADD COLUMN total_active_days INTEGER DEFAULT 0;")
    cursor.execute("ALTER TABLE user ADD COLUMN total_scans INTEGER DEFAULT 0;")
    print("✅ user 表升級成功 (加入 total_active_days, total_scans 徽章計數器)！")
except sqlite3.OperationalError as e:
    print(f"⚠️ user 徽章計數欄位可能已存在：{e}")

# ==========================================
# 🎁 9. 升級 User 表 (新增 notified_levels 徽章彈窗記憶)
# ==========================================
try:
    # 注意：SQLite 沒有專門的 JSON 格式，所以我們用 TEXT 來存，預設給一個空的 JSON 字串 '{}'
    cursor.execute("ALTER TABLE user ADD COLUMN notified_levels TEXT DEFAULT '{}';")
    print("✅ user 表升級成功 (加入 notified_levels 徽章彈窗記憶)！")
except sqlite3.OperationalError as e:
    print(f"⚠️ user.notified_levels 欄位可能已存在：{e}")

# ==========================================
# 📸 10. 升級 user_vocab (新增相片、解鎖時間與去重索引)
# ==========================================
try:
    cursor.execute("ALTER TABLE user_vocab ADD COLUMN image_path VARCHAR(255);")
    print("✅ user_vocab 擴充成功 (加入相片路徑欄位)！")
except sqlite3.OperationalError:
    pass

try:
    cursor.execute("ALTER TABLE user_vocab ADD COLUMN unlocked_at DATETIME;")
    print("✅ user_vocab 擴充成功 (加入解鎖時間欄位)！")
except sqlite3.OperationalError:
    pass

try:
    cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_user_vocab_user_vocab ON user_vocab(user_id, vocab_id);")
    print("✅ user_vocab 去重複索引建立成功！")
except sqlite3.OperationalError as e:
    print(f"⚠️ user_vocab 索引建立失敗：{e}")

# 儲存並關閉
conn.commit()
conn.close()

print("🎉 資料庫全面升級完成！")