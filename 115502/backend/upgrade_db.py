import sqlite3
import os

# 1. 自動抓取 upgrade_db.py 所在的絕對路徑 (也就是 backend 資料夾的位置)
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

# 2. 精準對準 backend/instance/jlens.db
db_path = os.path.join(BASE_DIR, 'instance', 'jlens.db')

# 連接到你的資料庫
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

def add_column(table, column_def):
    """安全新增欄位的小工具，避免因為欄位已存在而中斷程式"""
    try:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column_def};")
    except sqlite3.OperationalError:
        pass # 欄位已存在就安靜跳過

print("開始執行資料庫升級...")

# ==========================================
# 1. 升級 group_member
# ==========================================
add_column("group_member", "group_scans INTEGER DEFAULT 0")
add_column("group_member", "group_points INTEGER DEFAULT 0")
add_column("group_member", "group_logins INTEGER DEFAULT 0")
print("✅ group_member 欄位確認完畢")

# ==========================================
# 2. 升級 user
# ==========================================
add_column("user", "username VARCHAR(30)")
try:
    cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_username ON user(username);")
    print("✅ user.username 及其索引確認完畢")
except sqlite3.OperationalError as e:
    print(f"⚠️ username 索引建立警告：{e}")

# ==========================================
# 3. 升級 study_group (學習小組獎勵機制)
# ==========================================
add_column("study_group", "current_progress INTEGER DEFAULT 0")
add_column("study_group", "reward_points INTEGER DEFAULT 50")
add_column("study_group", "is_reward_claimed BOOLEAN DEFAULT 0")
print("✅ study_group 獎勵機制欄位確認完畢")

# ==========================================
# 🌟 4. 升級 Scene (確保單字目錄的 icon 欄位存在)
# ==========================================
try:
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS scene (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(100) NOT NULL,
        icon_name VARCHAR(50)
    );
    """)
    add_column("scene", "icon_name VARCHAR(50)")
    print("✅ scene 場景表確認完畢")
except Exception as e:
    print(f"⚠️ scene 建立或升級警告：{e}")

# ==========================================
# 🌟 5. 建立與升級 user_vocab (玩家的單字圖鑑！)
# ==========================================
try:
    # 如果是舊專案沒有這張表，先建起來
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_vocab (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        vocab_id INTEGER NOT NULL,
        unlocked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        image_path VARCHAR(255),
        folder_id INTEGER,
        FOREIGN KEY(user_id) REFERENCES user(id),
        FOREIGN KEY(vocab_id) REFERENCES vocab(id)
    );
    """)
    # 針對已經存在的表，確保這兩個重要欄位有加上去
    add_column("user_vocab", "image_path VARCHAR(255)")
    add_column("user_vocab", "folder_id INTEGER")
    print("✅ user_vocab 單字圖鑑擴充成功 (加入照片路徑與資料夾功能)！")
except sqlite3.OperationalError as e:
    print(f"⚠️ user_vocab 升級警告：{e}")

# ==========================================
# 🌟 6. 升級 vocab (單字詳細內容：適性化分級例句與 5 種音檔)
# ==========================================
# 分級例句
add_column("vocab", "sentence_basic VARCHAR(255)")
add_column("vocab", "sentence_inter VARCHAR(255)")
add_column("vocab", "sentence_upper_inter VARCHAR(255)")
add_column("vocab", "sentence_advanced VARCHAR(255)")
# 獨立發音檔
add_column("vocab", "audio_word VARCHAR(100)")
add_column("vocab", "audio_basic VARCHAR(100)")
add_column("vocab", "audio_inter VARCHAR(100)")
add_column("vocab", "audio_upper VARCHAR(100)")
add_column("vocab", "audio_adv VARCHAR(100)")

print("✅ vocab 單字表擴充成功 (已支援分級例句與獨立語音檔)！")

# ==========================================
# 📖 7. 新增 quiz_question (測驗題庫表)
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
    print("✅ quiz_question 測驗題目表確認完畢")
except sqlite3.OperationalError as e:
    print(f"⚠️ quiz_question 建立警告：{e}")

# ==========================================
# 🏆 8. 升級 User 表 (新版 5 大徽章計數器)
# ==========================================
add_column("user", "total_active_days INTEGER DEFAULT 0")
add_column("user", "total_scans INTEGER DEFAULT 0")
print("✅ user 表徽章計數器擴充成功！")

# ==========================================
# 🎁 9. 升級 User 表 (新增 notified_levels 徽章彈窗記憶)
# ==========================================
add_column("user", "notified_levels TEXT DEFAULT '{}'")
print("✅ user 表徽章彈窗記憶擴充成功！")

# 儲存並關閉
conn.commit()
conn.close()

print("🎉 資料庫全面升級完成！你的『拍立翻單字圖鑑』底層架構已準備就緒！")