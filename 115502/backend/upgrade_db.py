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

# 各自領獎與押金機制欄位
add_column("group_member", "has_claimed BOOLEAN DEFAULT 0")
add_column("group_member", "paid_deposit BOOLEAN DEFAULT 0")

print("✅ group_member 欄位確認完畢")

# ==========================================
# 2. 升級 user
# ==========================================
add_column("user", "username VARCHAR(30)")
# 🌟 新增：押金對賭機制，紀錄上一次免費參加是哪一週
add_column("user", "last_free_group_week VARCHAR(10)")

try:
    cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_username ON user(username);")
    print("✅ user 及其索引、對賭額度欄位確認完畢")
except sqlite3.OperationalError as e:
    print(f"⚠️ username 索引建立警告：{e}")

# ==========================================
# 3. 升級 study_group (學習小組獎勵機制與到期日)
# ==========================================
add_column("study_group", "current_progress INTEGER DEFAULT 0")
add_column("study_group", "reward_points INTEGER DEFAULT 50")
add_column("study_group", "is_reward_claimed BOOLEAN DEFAULT 0")
# 🌟 新增：自動結算系統，紀錄小組到期時間
add_column("study_group", "expire_at DATETIME")
print("✅ study_group 獎勵機制與到期日欄位確認完畢")

# ==========================================
# 4. 升級 Scene (確保單字目錄的 icon 欄位存在)
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
# 5. 🚀 建立新版相簿與圖鑑系統 (UserPhoto, UserPhotoVocab, UserVocab)
# ==========================================
try:
    # A. 建立 UserPhoto (照片事件主檔)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_photo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        scene_id INTEGER,
        image_path VARCHAR(255) NOT NULL,
        custom_title VARCHAR(100),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES user(id),
        FOREIGN KEY(scene_id) REFERENCES scene(id)
    );
    """)
    print("✅ user_photo (照片事件主檔) 建立成功！")

    # B. 建立 UserPhotoVocab (照片單字明細檔)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_photo_vocab (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER NOT NULL,
        vocab_id INTEGER NOT NULL,
        FOREIGN KEY(photo_id) REFERENCES user_photo(id),
        FOREIGN KEY(vocab_id) REFERENCES vocab(id)
    );
    """)
    print("✅ user_photo_vocab (照片單字明細檔) 建立成功！")

    # C. 建立/修改 UserVocab (全域單字圖鑑/收藏)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_vocab (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        vocab_id INTEGER NOT NULL,
        folder_id INTEGER,
        collected_at DATETIME,
        FOREIGN KEY(user_id) REFERENCES user(id),
        FOREIGN KEY(vocab_id) REFERENCES vocab(id),
        FOREIGN KEY(folder_id) REFERENCES user_folder(id)
    );
    """)
    # 確保必要的圖鑑欄位存在
    add_column("user_vocab", "folder_id INTEGER")
    add_column("user_vocab", "collected_at DATETIME")
    
    # 確保圖鑑系統的 Unique Constraint 存在 (防止同一個單字重複收藏)
    cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_user_vocab_user_vocab ON user_vocab(user_id, vocab_id);")
    
    print("✅ user_vocab (單字收藏狀態檔) 確認完畢！")

except sqlite3.OperationalError as e:
    print(f"⚠️ 相簿與圖鑑系統升級警告：{e}")

# ==========================================
# 6. 升級 vocab (單字詳細內容：適性化分級例句與 5 種音檔)
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
add_column("user", "last_seen_at DATETIME")
print("✅ user 表徽章計數器擴充成功！")

# ==========================================
# 🎁 9. 升級 User 表 (新增 notified_levels 徽章彈窗記憶)
# ==========================================
add_column("user", "notified_levels TEXT DEFAULT '{}'")
print("✅ user 表徽章彈窗記憶擴充成功！")

# ==========================================
# 🤝 10. 升級 friendship (好友系統：新增暱稱/備註)
# ==========================================
try:
    # 先確保 friendship 表存在 (萬一它還沒被建出來)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS friendship (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        friend_id INTEGER NOT NULL,
        status VARCHAR(20) DEFAULT 'accepted',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES user(id),
        FOREIGN KEY(friend_id) REFERENCES user(id)
    );
    """)
    
    # 幫 friendship 加上可以自訂的 nickname 欄位
    add_column("friendship", "nickname VARCHAR(50)")
    
    print("✅ friendship 好友關係表 (含暱稱備註) 確認完畢！")
except Exception as e:
    print(f"⚠️ friendship 建立或升級警告：{e}")

# ==========================================
# 🗑️ 11. 清除舊版能力值系統 (UserAbility)
# ==========================================
try:
    # 執行 DROP TABLE 語法，如果表格存在就直接刪除
    cursor.execute("DROP TABLE IF EXISTS user_ability;")
    print("✅ user_ability 資料表已成功移除！")
except sqlite3.OperationalError as e:
    print(f"⚠️ user_ability 移除警告：{e}")

# 儲存並關閉 (這兩行原本就有，加在它們上面就好)
conn.commit()
conn.close()

print("🎉 資料庫全面升級完成！你的『拍立翻單字圖鑑』底層架構已準備就緒！")