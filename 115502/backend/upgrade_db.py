import sqlite3
import os

# 1. 自動抓取 upgrade.py 所在的絕對路徑 (也就是 backend 資料夾的位置)
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
# 小組押金紀錄
add_column("group_member", "deposit_amount INTEGER DEFAULT 0")

print("✅ group_member 欄位確認完畢")

# ==========================================
# 2. 升級 user
# ==========================================
add_column("user", "username VARCHAR(30)")
add_column("user", "last_free_group_week VARCHAR(10)") # 押金對賭機制，紀錄上一次免費參加是哪一週

# 訂閱與 AI 相關欄位
add_column("user", "is_premium BOOLEAN DEFAULT 0")
add_column("user", "subscription_end_date DATETIME")
add_column("user", "auto_renew BOOLEAN DEFAULT 0")

add_column("user", "photo_count_today INTEGER DEFAULT 0")
add_column("user", "photo_extra_count INTEGER DEFAULT 0")
add_column("user", "ai_count_today INTEGER DEFAULT 0")
add_column("user", "ai_extra_count INTEGER DEFAULT 0")
add_column("user", "last_reset_date DATE")
add_column("user", "vocab_slot INTEGER DEFAULT 50")
add_column("user", "group_free_used_this_week INTEGER DEFAULT 0")

try:
    cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_username ON user(username);")
    print("✅ user 及其索引、訂閱、對賭額度欄位確認完畢")
except sqlite3.OperationalError as e:
    print(f"⚠️ username 索引建立警告：{e}")

# ==========================================
# 3. 升級 study_group (學習小組獎勵機制與到期日)
# ==========================================
add_column("study_group", "current_progress INTEGER DEFAULT 0")
print("✅ study_group 進度欄位確認完畢")

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
# 4b. 升級 scene：新增欄位
# ==========================================
add_column("scene", "icon_codepoint INTEGER")
add_column("scene", "show_in_quick_select BOOLEAN DEFAULT 0")
print("✅ scene icon_codepoint / show_in_quick_select 欄位確認完畢")
# 注意：場景種入資料已移至 app.py 的 db.create_all() 後管理

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

# ==========================================
# 12. 升級 point_transaction (交易紀錄)
# ==========================================
try:
    # 確保表格存在 (因為有時候舊使用者連這個表都沒有)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS point_transaction (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        points INTEGER NOT NULL,
        price INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES user(id)
    );
    """)
    # 補充欄位
    add_column("point_transaction", "transaction_type VARCHAR(20) DEFAULT 'purchase'")
    add_column("point_transaction", "related_feature VARCHAR(100)")
    print("✅ point_transaction 交易紀錄表欄位確認完畢")
except Exception as e:
    print(f"⚠️ point_transaction 建立或升級警告：{e}")

# ==========================================
# 13. 升級 subscription_plan
# ==========================================
add_column("subscription_plan", "points_grant_monthly INTEGER DEFAULT 50")
add_column("subscription_plan", "points_grant_yearly INTEGER DEFAULT 600")

# ==========================================
# 14. 升級 user（訂閱相關新欄位）
# ==========================================
add_column("user", "trial_used BOOLEAN DEFAULT 0")
add_column("user", "trial_notice_sent BOOLEAN DEFAULT 0")
add_column("user", "group_week_reset_date DATE")
print("✅ user 表訂閱相關欄位確認完畢")

# ==========================================
# 15. 建立 notification 通知表
# ==========================================
try:
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS notification (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title VARCHAR(100) NOT NULL,
        content TEXT NOT NULL,
        is_read BOOLEAN DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES user(id)
    );
    """)
    print("✅ notification 通知表確認完畢")
except sqlite3.OperationalError as e:
    print(f"⚠️ notification 建立警告：{e}")

# ==========================================
# 16. 建立 user_subscription 使用者訂閱紀錄表
# ==========================================
try:
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_subscription (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        plan_id INTEGER NOT NULL,
        billing_cycle VARCHAR(20) NOT NULL,
        start_date DATETIME NOT NULL,
        end_date DATETIME NOT NULL,
        status VARCHAR(20) DEFAULT 'active',
        auto_renew BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES user(id),
        FOREIGN KEY(plan_id) REFERENCES subscription_plan(id)
    );
    """)
    print("✅ user_subscription 使用者訂閱紀錄表確認完畢")
except sqlite3.OperationalError as e:
    print(f"⚠️ user_subscription 建立警告：{e}")

# ==========================================
# 17. 升級 subscription_plan
# ==========================================
add_column("subscription_plan", "billing_cycle VARCHAR(20)")
add_column("subscription_plan", "price_monthly INTEGER")
add_column("subscription_plan", "price_yearly INTEGER")
add_column("subscription_plan", "is_active BOOLEAN DEFAULT 1")
add_column("subscription_plan", "features TEXT")
print("✅ subscription_plan 欄位確認完畢")

# ==========================================
# 18. 修正 subscription_plan：移除 price_monthly / price_yearly 的 NOT NULL 限制
#     SQLite 不支援 ALTER COLUMN，需要整張表重建
# ==========================================
try:
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS subscription_plan_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR(100) NOT NULL,
        billing_cycle VARCHAR(20),
        price_monthly INTEGER,
        price_yearly INTEGER,
        features_json TEXT,
        points_grant INTEGER DEFAULT 0,
        points_grant_monthly INTEGER DEFAULT 50,
        points_grant_yearly INTEGER DEFAULT 600,
        is_active BOOLEAN DEFAULT 1
    );
    """)

    cursor.execute("""
    INSERT INTO subscription_plan_new
        (id, name, billing_cycle, price_monthly, price_yearly,
         features_json, points_grant, points_grant_monthly,
         points_grant_yearly, is_active)
    SELECT id, name, billing_cycle, price_monthly, price_yearly,
           features_json, points_grant, points_grant_monthly,
           points_grant_yearly, is_active
    FROM subscription_plan;
    """)

    cursor.execute("DROP TABLE subscription_plan;")
    cursor.execute("ALTER TABLE subscription_plan_new RENAME TO subscription_plan;")
    print("✅ subscription_plan price 欄位 NOT NULL 限制已移除")
except Exception as e:
    print(f"⚠️ subscription_plan 重建警告（可能已完成）：{e}")

# ==========================================
# 19. 升級 user_subscription：補充 payment_method 與 payment_status 欄位
# ==========================================
add_column("user_subscription", "payment_method VARCHAR(50)")
add_column("user_subscription", "payment_status VARCHAR(20) DEFAULT 'paid'")
print("✅ user_subscription payment_method / payment_status 欄位確認完畢")

# ==========================================
# 20. 刪除已廢棄的資料表與欄位
# ==========================================
try:
    cursor.execute("DROP TABLE IF EXISTS user_boost;")
    print("✅ user_boost 資料表已成功移除！")
except sqlite3.OperationalError as e:
    print(f"⚠️ user_boost 移除警告：{e}")

# 重建 study_group：移除 host_id 與 expire_at 欄位
try:
    cursor.execute("PRAGMA table_info(study_group);")
    sg_cols = [row[1] for row in cursor.fetchall()]

    if 'host_id' not in sg_cols and 'expire_at' not in sg_cols:
        print("✅ study_group 已不含廢棄欄位，跳過重建。")
    else:
        cursor.execute("ALTER TABLE study_group RENAME TO study_group_old;")

        cursor.execute("""
        CREATE TABLE study_group (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) DEFAULT '日語學習小隊',
            created_at DATETIME,
            goal_type VARCHAR(50) NOT NULL DEFAULT 'scans',
            goal_target INTEGER NOT NULL DEFAULT 30,
            current_progress INTEGER DEFAULT 0
        );
        """)

        new_sg_cols = ['id', 'name', 'created_at', 'goal_type', 'goal_target',
                       'current_progress']
        copy_sg_cols = [c for c in new_sg_cols if c in sg_cols]
        cols_str = ', '.join(copy_sg_cols)
        cursor.execute(f"INSERT INTO study_group ({cols_str}) SELECT {cols_str} FROM study_group_old;")
        cursor.execute("DROP TABLE study_group_old;")

        print("✅ study_group host_id / expire_at / reward_points / is_reward_claimed 廢棄欄位已移除！")
except Exception as e:
    print(f"⚠️ study_group 重建警告（可能已完成）：{e}")

# 重建 user 資料表以移除 group_completions 欄位
# （SQLite 不支援 DROP COLUMN，需重建資料表）
try:
    cursor.execute("PRAGMA table_info(user);")
    existing_cols = [row[1] for row in cursor.fetchall()]

    if 'group_completions' not in existing_cols:
        print("✅ group_completions 欄位已不存在，跳過重建。")
    else:
        cursor.execute("ALTER TABLE user RENAME TO user_old;")

        cursor.execute("""
        CREATE TABLE user (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email VARCHAR(120) NOT NULL,
            password_hash VARCHAR(256) NOT NULL,
            username VARCHAR(30),
            friend_id VARCHAR(20),
            japanese_level VARCHAR(50),
            avatar TEXT,
            ai_cheat_sheet TEXT,
            j_pts INTEGER DEFAULT 0,
            streak_days INTEGER DEFAULT 1,
            last_login_date DATE,
            last_seen_at DATETIME,
            created_at DATETIME,
            last_free_group_week VARCHAR(10),
            daily_scans INTEGER DEFAULT 0,
            last_scan_date DATE,
            total_active_days INTEGER DEFAULT 0,
            total_scans INTEGER DEFAULT 0,
            notified_levels TEXT DEFAULT '{}',
            is_premium BOOLEAN DEFAULT 0,
            subscription_end_date DATETIME,
            auto_renew BOOLEAN DEFAULT 0,
            trial_used BOOLEAN DEFAULT 0,
            trial_notice_sent BOOLEAN DEFAULT 0,
            group_free_used_this_week INTEGER DEFAULT 0,
            photo_count_today INTEGER DEFAULT 0,
            ai_count_today INTEGER DEFAULT 0,
            last_reset_date DATE,
            photo_extra_count INTEGER DEFAULT 0,
            ai_extra_count INTEGER DEFAULT 0,
            vocab_slot INTEGER DEFAULT 50
        );
        """)

        # 只複製新表有且舊表也有的欄位（相容舊版 DB）
        new_cols = [
            'id', 'email', 'password_hash', 'username', 'friend_id',
            'japanese_level', 'avatar', 'ai_cheat_sheet', 'j_pts', 'streak_days',
            'last_login_date', 'last_seen_at', 'created_at', 'last_free_group_week',
            'daily_scans', 'last_scan_date', 'total_active_days', 'total_scans',
            'notified_levels', 'is_premium', 'subscription_end_date', 'auto_renew',
            'trial_used', 'trial_notice_sent', 'group_free_used_this_week',
            'photo_count_today', 'ai_count_today', 'last_reset_date',
            'photo_extra_count', 'ai_extra_count', 'vocab_slot',
        ]
        copy_cols = [c for c in new_cols if c in existing_cols]
        cols_str = ', '.join(copy_cols)
        cursor.execute(f"INSERT INTO user ({cols_str}) SELECT {cols_str} FROM user_old;")
        cursor.execute("DROP TABLE user_old;")

        # 重建唯一索引
        cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_user_email ON user(email);")
        cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_user_username ON user(username);")
        cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS uq_user_friend_id ON user(friend_id);")

        print("✅ group_completions 欄位已從 user 資料表移除！")
except Exception as e:
    print(f"⚠️ group_completions 移除警告（可能已完成）：{e}")

# 儲存並關閉
conn.commit()
conn.close()

print("🎉 資料庫全面升級完成！你的『拍立翻單字圖鑑』底層架構已準備就緒！")