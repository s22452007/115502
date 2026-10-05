from utils.db import db
from datetime import datetime, timezone, timedelta
from werkzeug.security import generate_password_hash, check_password_hash

TW = timezone(timedelta(hours=8))
created_at = db.Column(db.DateTime, default=lambda: datetime.now(TW))

class TransactionType:
    PURCHASE = 'purchase'                      # 購買點數
    SPEND = 'spend'                            # 消費點數
    REWARD = 'reward'                          # 獎勵點數
    SUBSCRIPTION_GRANT = 'subscription_grant'  # 訂閱贈點
    DEPOSIT = 'deposit'                        # 押金扣除
    DEPOSIT_REFUND = 'deposit_refund'          # 押金退還
    GROUP_REWARD = 'group_reward'              # 小組達成獎勵

# ==========================================
# 👤 1. 核心系統層
# ==========================================

# T01: 使用者資料表
class User(db.Model):
    __tablename__ = 'user'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    username = db.Column(db.String(30), nullable=True)  # 暱稱，可以跟別人重複（辨識靠 friend_id）
    friend_id = db.Column(db.String(20), unique=True, nullable=True)
    japanese_level = db.Column(db.String(50), nullable=True)
    avatar = db.Column(db.Text, nullable=True)
    ai_cheat_sheet = db.Column(db.Text, nullable=True)
    # 點數與活躍度
    j_pts = db.Column(db.Integer, default=0)
    streak_days = db.Column(db.Integer, default=1)
    last_login_date = db.Column(db.Date, nullable=True)
    last_seen_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    # 拍照紀錄與限制
    daily_scans = db.Column(db.Integer, default=0)
    last_scan_date = db.Column(db.Date, nullable=True)
    photo_count_today = db.Column(db.Integer, default=0)
    photo_extra_count = db.Column(db.Integer, default=0)
    # AI 服務限制
    ai_count_today = db.Column(db.Integer, default=0)
    ai_extra_count = db.Column(db.Integer, default=0)
    last_reset_date = db.Column(db.Date, nullable=True)
    # 已扣次數、還沒用掉的拍照辨識／AI 回覆憑證：increment_scan、use_ai 成功各 +1，
    # /api/scenario/analyze、/api/chat 每次呼叫 AI 前各用掉 1。沒有憑證就不呼叫 AI，
    # 避免跳過扣次 API 直接打辨識／對話，無限使用。
    scan_credits = db.Column(db.Integer, default=0)
    ai_credits = db.Column(db.Integer, default=0)
    # 登入通行證版本：改密碼、重設密碼時 +1，之前發出的通行證全部失效（utils/auth_token.py）
    token_version = db.Column(db.Integer, default=0)
    # 徽章與成就
    total_active_days = db.Column(db.Integer, default=0)
    total_scans = db.Column(db.Integer, default=0)
    notified_levels = db.Column(db.JSON, default={})
    # 帳號類型：登入分流與免費判斷的根據，合法值見 AccountType。
    # 舊資料一律是 'general'，行為完全不變。
    account_type = db.Column(db.String(20), default='general', nullable=False)
    # 手機推播（Firebase Cloud Messaging）的裝置 token。學生登入 App 時登記、登出時清掉；
    # 同一支手機換人登入會從前一個帳號移走。一個帳號只記最後登入的那支手機
    push_token = db.Column(db.String(255), nullable=True, index=True)
    # 訂閱與小組狀態
    is_premium = db.Column(db.Boolean, default=False)
    subscription_end_date = db.Column(db.DateTime, nullable=True)
    auto_renew = db.Column(db.Boolean, default=False)
    trial_used = db.Column(db.Boolean, default=False)
    trial_notice_sent = db.Column(db.Boolean, default=False)
    last_free_group_week = db.Column(db.String(10), nullable=True)
    group_free_used_this_week = db.Column(db.Integer, default=0)
    vocab_slot = db.Column(db.Integer, default=50)
    is_suspended = db.Column(db.Boolean, default=False)
    # 老師帳號審核狀態：'pending'（用學校 Google 帳號自行登入，等管理者確認是老師）／'approved'。
    # 管理者建立的老師帳號直接 approved；一般使用者與學生用不到這個欄位。
    teacher_status = db.Column(db.String(20), default='approved')
    # Google 無法登入的老師自己填申請表時留下的資料，給管理者審核時對照教職員名錄；其他帳號都是空的
    teacher_department = db.Column(db.String(50), nullable=True)    # 系所／單位
    teacher_apply_note = db.Column(db.String(200), nullable=True)   # 申請備註
    # 下次登入是否要強制改密碼：老師建立學生帳號、或幫學生重設密碼時設為 True
    # （初始密碼是系統產生給老師的臨時密碼，老師也知道，所以一定要學生自己換掉），改完即清除。
    must_change_password = db.Column(db.Boolean, default=False)
    # 校園教育版學生用學校 Google 帳號登入時選的學校（School.id）。
    # 有值＝Google 學生帳號（沒有密碼）；老師貼名單建立的學號帳號是空的
    school_id = db.Column(db.Integer, db.ForeignKey('school.id'), nullable=True)
    # 每日任務
    daily_task_date = db.Column(db.Date, nullable=True)
    daily_task_photo = db.Column(db.Boolean, default=False)
    daily_task_ai = db.Column(db.Boolean, default=False)
    daily_reward_claimed = db.Column(db.Boolean, default=False)

    user_vocabs = db.relationship('UserVocab', backref='user', lazy=True)
    achievements = db.relationship('UserAchievement', backref='user', lazy=True)

# # 使用者能力值表 (UserAbility) - 雷達圖專用
# class UserAbility(db.Model):
#     id = db.Column(db.Integer, primary_key=True)
#     user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
#     listening = db.Column(db.Float, default=0.2)  # 預設 0.2 (滿分 1.0)
#     reading = db.Column(db.Float, default=0.2)
#     writing = db.Column(db.Float, default=0.2)
#     culture = db.Column(db.Float, default=0.2)
#     speaking = db.Column(db.Float, default=0.2)

# T02: 系統管理者資料表
class Admin(db.Model):
    __tablename__ = 'admin'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    role = db.Column(db.String(20), default='super_admin', nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)              # 停用後無法登入後台
    must_change_password = db.Column(db.Boolean, default=False)  # 新建／重設密碼後，第一次登入強制改密碼
    last_login_at = db.Column(db.DateTime)                       # 上次成功登入後台的時間（UTC）

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

# ==========================================
# 📖 2. 系統教材內容
# ==========================================

# T03: 場景資料表
class Scene(db.Model):
    __tablename__ = 'scene'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False) # 例如：咖啡廳
    icon_name = db.Column(db.String(50), nullable=True)
    icon_codepoint = db.Column(db.Integer, nullable=True) # Flutter Icon 代碼
    show_in_quick_select = db.Column(db.Boolean, default=False)
    vocabs = db.relationship('Vocab', backref='scene', lazy=True)
    updated_by = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True)
    updated_at = db.Column(db.DateTime, nullable=True, onupdate=lambda: datetime.now(timezone.utc))

# T04: 單字字典表
class Vocab(db.Model):
    __tablename__ = 'vocab'
    id = db.Column(db.Integer, primary_key=True)
    audio_word = db.Column(db.String(100), nullable=True)     # 單字本身的發音檔
    audio_basic = db.Column(db.String(100), nullable=True)    # 初級例句發音檔
    audio_inter = db.Column(db.String(100), nullable=True)    # 中級例句發音檔
    audio_upper = db.Column(db.String(100), nullable=True)    # 中高級例句發音檔
    audio_adv = db.Column(db.String(100), nullable=True)      # 高級例句發音檔
    scene_id = db.Column(db.Integer, db.ForeignKey('scene.id'), nullable=False) # 所屬場景
    word = db.Column(db.String(100), nullable=False) # 日文原型/漢字
    kana = db.Column(db.String(100), nullable=False) # 假名拼音
    meaning = db.Column(db.String(200), nullable=False) # 中文解釋
    # 例句分級
    sentence_basic = db.Column(db.String(255), nullable=True) # N5-N4
    sentence_inter = db.Column(db.String(255), nullable=True) # N3
    sentence_upper_inter = db.Column(db.String(255), nullable=True) # N2
    sentence_advanced = db.Column(db.String(255), nullable=True) # N1
    # 分級例句的中文翻譯
    sentence_basic_zh = db.Column(db.String(255), nullable=True)
    sentence_inter_zh = db.Column(db.String(255), nullable=True)
    sentence_upper_inter_zh = db.Column(db.String(255), nullable=True)
    sentence_advanced_zh = db.Column(db.String(255), nullable=True)
    # 語音路徑
    # 來源與編輯紀錄
    source = db.Column(db.String(10), nullable=False, default='ai') # 'ai'（Gemini生成）| 'admin'（管理者手動新增）
    updated_by = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True)
    updated_at = db.Column(db.DateTime, nullable=True, onupdate=lambda: datetime.now(timezone.utc))

# T05: 測驗題目表
class QuizQuestion(db.Model):
    __tablename__ = 'quiz_question'
    id = db.Column(db.Integer, primary_key=True)
    stage = db.Column(db.String(50), nullable=False) # 階段名稱
    level_tag = db.Column(db.String(20), nullable=False) # 難度 (N5-N1)
    question = db.Column(db.Text, nullable=False) # 題目內容
    option_a = db.Column(db.String(100), nullable=False)
    option_b = db.Column(db.String(100), nullable=False)
    option_c = db.Column(db.String(100), nullable=False)
    option_d = db.Column(db.String(100), nullable=False)
    correct_answer = db.Column(db.String(1), nullable=False) # 正確答案 (A/B/C/D)
    updated_by = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# T_dialect: 腔調設定資料表
class Dialect(db.Model):
    __tablename__ = 'dialect'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(20), nullable=False)         # 關西腔
    jp_name = db.Column(db.String(20), nullable=False)      # 関西弁
    region = db.Column(db.String(50))                       # 大阪、京都、神戶
    description = db.Column(db.String(100))                 # 最有名，ACG常出現
    prompt_instruction = db.Column(db.Text, nullable=False) # 給Gemini的指令
    is_active = db.Column(db.Boolean, default=True)

# ==========================================
# 🗂️ 3. 使用者學習紀錄
# ==========================================

# T06: 使用者照片事件表
class UserPhoto(db.Model):
    __tablename__ = 'user_photo'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    scene_id = db.Column(db.Integer, db.ForeignKey('scene.id'), nullable=True) # AI 辨識出的場景
    image_path = db.Column(db.String(255), nullable=False)
    custom_title = db.Column(db.String(100), nullable=True) # 使用者自訂名稱
    context_description = db.Column(db.Text, nullable=True) # 拍照當下使用者描述的情境（原文）
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    scene = db.relationship('Scene', foreign_keys=[scene_id])
    photo_vocabs = db.relationship('UserPhotoVocab', backref='photo', lazy=True, cascade="all, delete-orphan")

# T07: 照片辨識單字明細表
class UserPhotoVocab(db.Model):
    __tablename__ = 'user_photo_vocab'
    id = db.Column(db.Integer, primary_key=True)
    photo_id = db.Column(db.Integer, db.ForeignKey('user_photo.id'), nullable=False)
    vocab_id = db.Column(db.Integer, db.ForeignKey('vocab.id'), nullable=False)
    context_sentence = db.Column(db.Text, nullable=True)  # 依使用者拍照當下情境生成的專屬例句
    vocab = db.relationship('Vocab', backref='photo_vocabs', lazy=True)

# T08: 使用者單字收藏表
class UserVocab(db.Model):
    __tablename__ = 'user_vocab'
    __table_args__ = (db.UniqueConstraint('user_id', 'vocab_id', name='uq_user_vocab_user_vocab'),)
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    vocab_id = db.Column(db.Integer, db.ForeignKey('vocab.id'), nullable=False)
    folder_id = db.Column(db.Integer, db.ForeignKey('user_folder.id'), nullable=True)
    collected_at = db.Column(db.DateTime, nullable=True)
    vocab = db.relationship('Vocab', backref='user_vocabs', lazy=True)

# T09: 使用者自訂資料夾表
class UserFolder(db.Model):
    __tablename__ = 'user_folder'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==========================================
# 🤝 4. 社交與學習小組系統
# ==========================================

# T10: 好友邀請表
class FriendRequest(db.Model):
    __tablename__ = 'friend_request'
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    receiver_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    status = db.Column(db.String(20), default='pending') # pending, accepted, rejected
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# T11: 好友關係表
class Friendship(db.Model):
    __tablename__ = 'friendship'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    friend_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    nickname = db.Column(db.String(50), nullable=True) # 好友備註

# T12: 學習小組表
class StudyGroup(db.Model):
    __tablename__ = 'study_group'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), default="日語學習小隊")
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    goal_type = db.Column(db.String(50), nullable=False, default='scans')
    goal_target = db.Column(db.Integer, nullable=False, default=30)
    current_progress = db.Column(db.Integer, default=0)
    members = db.relationship('GroupMember', backref='group', lazy=True, cascade="all, delete-orphan")
    invites = db.relationship('GroupInvite', backref='group', lazy=True, cascade="all, delete-orphan")

# T13: 小組成員表
class GroupMember(db.Model):
    __tablename__ = 'group_member'
    id = db.Column(db.Integer, primary_key=True)
    group_id = db.Column(db.Integer, db.ForeignKey('study_group.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    # 貢獻紀錄
    group_scans = db.Column(db.Integer, default=0)
    group_points = db.Column(db.Integer, default=0)
    group_logins = db.Column(db.Integer, default=0)
    group_sentences = db.Column(db.Integer, default=0)   # 個人本週完成造句句數
    group_articles = db.Column(db.Integer, default=0)    # 個人本週完成閱讀篇數
    # 獎勵與押金
    has_claimed = db.Column(db.Boolean, default=False)
    paid_deposit = db.Column(db.Boolean, default=False)
    deposit_amount = db.Column(db.Integer, default=0)

# T14: 小組邀請表
class GroupInvite(db.Model):
    __tablename__ = 'group_invite'
    id = db.Column(db.Integer, primary_key=True)
    group_id = db.Column(db.Integer, db.ForeignKey('study_group.id'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    receiver_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    status = db.Column(db.String(20), default='pending')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==========================================
# 🏆 5. 成就、通知與回饋
# ==========================================

# T15: 系統成就表
class Achievement(db.Model):
    __tablename__ = 'achievement'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False) 
    description = db.Column(db.String(255), nullable=True)
    icon_codepoint = db.Column(db.Integer, nullable=True)
    updated_by = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# T16: 使用者成就解鎖紀錄表
class UserAchievement(db.Model):
    __tablename__ = 'user_achievement'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    achievement_id = db.Column(db.Integer, db.ForeignKey('achievement.id'), nullable=False)
    unlocked_at = db.Column(db.DateTime, default=datetime.utcnow)

# T17: 系統通知紀錄表
class Notification(db.Model):
    __tablename__ = 'notification'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    title = db.Column(db.String(100), nullable=False)
    body = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# 忘記密碼的 Email 驗證碼：寄出時新增一筆，驗證成功或過期就作廢
class PasswordResetCode(db.Model):
    __tablename__ = 'password_reset_code'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, index=True)
    code_hash = db.Column(db.String(256), nullable=False)   # 只存雜湊，不存驗證碼本身
    expires_at = db.Column(db.DateTime, nullable=False)
    attempts = db.Column(db.Integer, default=0)             # 輸錯次數，達上限就作廢
    used_at = db.Column(db.DateTime, nullable=True)         # 有值代表已用過或已作廢
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# T18: 系統回饋表
class Feedback(db.Model):
    __tablename__ = 'feedback'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    email = db.Column(db.String(120), nullable=True)
    feedback_type = db.Column(db.String(50), nullable=False)
    content = db.Column(db.Text, nullable=False)
    reply = db.Column(db.Text, nullable=True)
    replied_by = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True)
    replied_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==========================================
# 💳 6. 商業邏輯 (購點與訂閱)
# ==========================================

# T19: 購點方案表
class PointPackage(db.Model):
    __tablename__ = 'point_package'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), nullable=False)
    points = db.Column(db.Integer, nullable=False)
    price = db.Column(db.Integer, nullable=False)
    tag = db.Column(db.String(20), nullable=True)
    description = db.Column(db.String(200), nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    updated_by = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# T20: 訂閱方案資料表
class SubscriptionPlan(db.Model):
    __tablename__ = 'subscription_plan'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    billing_cycle = db.Column(db.String(10), nullable=True) # monthly/yearly
    price_monthly = db.Column(db.Integer, nullable=True)
    price_yearly = db.Column(db.Integer, nullable=True)
    features_json = db.Column(db.JSON, nullable=True) # 訂閱功能清單
    points_grant_monthly = db.Column(db.Integer, default=50) # 月訂贈點
    points_grant_yearly = db.Column(db.Integer, default=600) # 年訂贈點
    is_active = db.Column(db.Boolean, default=True)
    updated_by = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# T21: 使用者訂閱紀錄表
class UserSubscription(db.Model):
    __tablename__ = 'user_subscription'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    plan_id = db.Column(db.Integer, db.ForeignKey('subscription_plan.id'), nullable=False)
    billing_cycle = db.Column(db.String(10), nullable=False)
    start_date = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    end_date = db.Column(db.DateTime, nullable=False)
    auto_renew = db.Column(db.Boolean, default=True)
    payment_method = db.Column(db.String(50), nullable=True)
    payment_status = db.Column(db.String(20), nullable=False, default='paid')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    plan = db.relationship('SubscriptionPlan', backref='subscriptions', lazy=True)

# T22: 點數交易紀錄表
class PointTransaction(db.Model):
    __tablename__ = 'point_transaction'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    points = db.Column(db.Integer, nullable=False) # 正/負數
    price = db.Column(db.Integer, nullable=False)
    payment_method = db.Column(db.String(50), nullable=True)
    transaction_type = db.Column(db.String(20), nullable=False) # purchase/spend/reward...
    related_feature = db.Column(db.String(100), nullable=True) # 功能來源
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==========================================
# 🛡️ 7. 系統日誌
# ==========================================

# T23: 系統操作異動日誌表
class SystemLog(db.Model):
    __tablename__ = 'system_log'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True) # 操作者(使用者)
    admin_id = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True) # 操作者(管理員)
    action = db.Column(db.String(20), nullable=False) # INSERT, UPDATE, DELETE
    target_table = db.Column(db.String(50), nullable=False) # 操作目標資料表
    target_id = db.Column(db.Integer, nullable=False) # 目標紀錄 ID
    old_value = db.Column(db.JSON, nullable=True) # 變更前資料 (JSON)
    new_value = db.Column(db.JSON, nullable=True) # 變更後資料 (JSON)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # === 新增文章系統相關的資料表 ===

class Article(db.Model):
    __tablename__ = 'articles'
    
    id = db.Column(db.Integer, primary_key=True)
    theme = db.Column(db.String(50), nullable=False) # 主題，例如: 'daily', 'travel', 'business', 'culture', 'news'
    level = db.Column(db.String(10), nullable=False) # 難度等級，例如: 'N5', 'N4', 'N3' 等
    title = db.Column(db.String(255), nullable=False) # 文章標題
    content = db.Column(db.Text, nullable=False) # 文章內容 (日文)
    translation = db.Column(db.Text, nullable=True) # 中文翻譯
    grammar_points = db.Column(db.JSON, nullable=True) # 重點文法解析 (存成 JSON 格式)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # === 後台上架用欄位 ===
    is_free = db.Column(db.Boolean, default=False)      # 是否免費閱讀；後台新增的文章一律付費 (False)
    unlock_cost = db.Column(db.Integer, default=50)     # 解鎖所需的 J-pts
    is_published = db.Column(db.Boolean, default=True)  # 是否已上架，下架後 App 端看不到
    created_by = db.Column(db.Integer, db.ForeignKey('admin.id'), nullable=True) # 由哪位管理者新增
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ArticleProgress(db.Model):
    __tablename__ = 'article_progress'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    article_id = db.Column(db.Integer, db.ForeignKey('articles.id'), nullable=False)
    score = db.Column(db.Integer, default=0) # 朗讀評分 (0-100)
    ai_feedback = db.Column(db.Text, nullable=True) # AI 針對朗讀給的糾音建議
    is_completed = db.Column(db.Boolean, default=False) # 是否完成閱讀/測驗
    completed_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 建立關聯 (選用，方便查詢)
    article = db.relationship('Article', backref=db.backref('user_progress', lazy=True))

# ==========================================
# 🌟 新增：文章解鎖紀錄資料表 (已修正外鍵名稱)
# ==========================================
class UnlockedArticle(db.Model):
    __tablename__ = 'unlocked_articles'
    
    id = db.Column(db.Integer, primary_key=True)
    # 🌟 這裡把 'users.id' 改成了 'user.id' (單數)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    article_id = db.Column(db.Integer, db.ForeignKey('articles.id'), nullable=False)
    unlocked_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "article_id": self.article_id,
            "unlocked_at": self.unlocked_at.strftime('%Y-%m-%d %H:%M:%S')
        }

# ==========================================
# 🌟 新增：文章測驗歷史紀錄表 (每次測驗都會存一筆)
# ==========================================
class ScoreRecord(db.Model):
    __tablename__ = 'score_record'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    article_id = db.Column(db.Integer, db.ForeignKey('articles.id'), nullable=False)
    score = db.Column(db.Integer, nullable=False)
    points_earned = db.Column(db.Integer, default=0) # 這次測驗賺到的點數
    created_at = db.Column(db.DateTime, default=datetime.utcnow) # 測驗時間


# T_reading_evaluation: 朗讀評分結果，只由後端寫入。
# 原本 /evaluate 把 AI 分數交給前端、/submit_score 再照單全收前端送回來的分數，
# 等於學生可以自己決定分數。現在 AI 評完分就存在這裡，結算時只認 evaluation_id，
# 而且每筆只能結算一次，避免同一次好成績被重複送出刷點數。
class ReadingEvaluation(db.Model):
    __tablename__ = 'reading_evaluation'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    article_id = db.Column(db.Integer, db.ForeignKey('articles.id'), nullable=False)
    score = db.Column(db.Integer, nullable=False)
    settled_at = db.Column(db.DateTime, nullable=True)   # 已結算的時間，有值就不能再結算
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==========================================
# 🌟 新增：造句練習歷史紀錄表
# ==========================================
class SentencePracticeRecord(db.Model):
    __tablename__ = 'sentence_practice_record'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    grammar_point = db.Column(db.String(100), nullable=False)
    selected_vocabs = db.Column(db.JSON, nullable=True) # 記錄使用者勾選了哪些收藏單字
    user_sentence = db.Column(db.Text, nullable=False)
    corrected_sentence = db.Column(db.Text, nullable=True)
    ai_feedback = db.Column(db.Text, nullable=True) 
    score = db.Column(db.Integer, default=0)
    points_earned = db.Column(db.Integer, default=0)
    is_claimed = db.Column(db.Boolean, default=False) 
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    


 
# ==========================================
# 💬 AI 對話歷史紀錄
# ==========================================

# T_chat_session: AI 對話場次（一次進入對話畫面 = 一個場次）
class ChatSession(db.Model):
    __tablename__ = 'chat_session'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    topic = db.Column(db.String(100), nullable=False)          # 情境主題，例如「一蘭拉麵」
    character_name = db.Column(db.String(50), nullable=True)   # 對話角色，例如「預設老師」
    dialect_id = db.Column(db.Integer, db.ForeignKey('dialect.id'), nullable=True)
    message_count = db.Column(db.Integer, default=0)           # 訊息則數（清單顯示用）
    started_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_message_at = db.Column(db.DateTime, default=datetime.utcnow)
    messages = db.relationship('ChatMessage', backref='session', lazy=True,
                               cascade="all, delete-orphan")

# T_chat_message: 對話訊息明細
class ChatMessage(db.Model):
    __tablename__ = 'chat_message'
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey('chat_session.id'), nullable=False)
    role = db.Column(db.String(10), nullable=False)   # 'user' = 使用者、'ai' = AI 回覆
    content = db.Column(db.Text, nullable=False)      # 保留原始內容（含 [漢字|假名] 標音）
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# T_custom_character: 使用者自訂的 AI 對話角色（花點數新增，人設會放進 AI 的指令）
class CustomCharacter(db.Model):
    __tablename__ = 'custom_character'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    name = db.Column(db.String(50), nullable=False)        # 同一位使用者不可重名
    origin = db.Column(db.String(50))                      # 出身地
    age = db.Column(db.String(10))
    gender = db.Column(db.String(10))
    personality = db.Column(db.String(100))                # 個性
    special_traits = db.Column(db.String(200))             # 特殊設定
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ==========================================
# 🎓 校園教育版：教室與作業
# ==========================================
#
# 這幾張表是「學生端」與「老師端」共用的介面，兩邊都要照這個欄位定義寫。
# 設計原則：作業本身只負責「指派」與「收件」，學生實際作答的內容仍然寫進
# 原本各功能的表（造句 → sentence_practice_record、拍照 → user_photo …），
# 由 AssignmentSubmission.result_ref_id 指過去。這樣教育版不必把既有功能
# 重寫一遍，學生的作業成果也會同時出現在他自己的學習紀錄裡。


class AccountType:
    """User.account_type 的合法值。登入分流與免費判斷都看這個欄位。"""
    GENERAL = 'general'   # 一般自主學習版（維持原本的付費／次數機制）
    STUDENT = 'student'   # 校園教育版學生（不限次數、沒有任何付費入口）
    TEACHER = 'teacher'   # 校園教育版老師（由老師端負責，這裡只先定義值）


class TaskType:
    """Assignment.task_type 的合法值，對應四種既有功能。"""
    SENTENCE = 'sentence'   # 造句挑戰
    PHOTO = 'photo'         # 拍照學習
    CHAT = 'chat'           # AI 情境對話
    ARTICLE = 'article'     # 文章閱讀

    ALL = (SENTENCE, PHOTO, CHAT, ARTICLE)


class SubmissionStatus:
    """AssignmentSubmission.status 的合法值。"""
    PENDING = 'pending'       # 已指派，學生還沒做
    SUBMITTED = 'submitted'   # 學生已完成，等老師看
    GRADED = 'graded'         # 老師已批閱（AI 自動給分的也算）


class LatePolicy:
    """Assignment.late_policy 的合法值：截止之後還交不交得進來、怎麼算分。"""
    ALLOW = 'allow'     # 允許遲交，只標示「遲交」（預設，也是舊作業的行為）
    REJECT = 'reject'   # 截止後不收，學生端擋下繳交
    DEDUCT = 'deduct'   # 允許遲交，但算成績時扣 late_penalty 分（原始分數保留，老師改分也照扣）
    ALL = (ALLOW, REJECT, DEDUCT)


# T_school: 學校。學生在 App 先選學校，再用學校 Google 帳號登入（像 TronClass 選學校）。
# 由 super_admin 在後台「學校管理」頁設定網域與學號格式。
from school_seed import DEFAULT_STUDENT_ID_PATTERN


class School(db.Model):
    __tablename__ = 'school'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    # 學生 Google 帳號的網域，逗號分隔；以「.」開頭代表結尾比對（.xxx.edu.tw 包含 gm.xxx.edu.tw）
    student_domains = db.Column(db.String(200), nullable=False)
    # Email @ 前面要符合這個正規式才算學號；有括號群組時取第一組當學號（例如 ^s(\d{8})$）
    student_id_pattern = db.Column(db.String(100), default=DEFAULT_STUDENT_ID_PATTERN, nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    # 學生在 App 自己新增的學校記下是誰（管理者在後台新增的是空的）
    created_by_user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def domain_list(self):
        return [d.strip().lower().lstrip('@') for d in (self.student_domains or '').split(',') if d.strip()]

    def domain_match_len(self, domain):
        """這個網域符合的設定有多長，不符合回傳 0。附中的網域在大學底下（hs.ntnu.edu.tw），
        同時符合好幾間學校時用這個挑最貼近的那一間"""
        domain = (domain or '').lower()
        best = 0
        for allowed in self.domain_list():
            if domain == allowed.lstrip('.') or (allowed.startswith('.') and domain.endswith(allowed)):
                best = max(best, len(allowed.lstrip('.')))
        return best

    def domain_allowed(self, domain):
        return self.domain_match_len(domain) > 0

    def student_no(self, local_part):
        """Email @ 前面那段是學號就回傳學號，不是回傳 None"""
        import re
        try:
            m = re.fullmatch(self.student_id_pattern or DEFAULT_STUDENT_ID_PATTERN, local_part or '')
        except re.error:
            return None
        if not m:
            return None
        return m.group(1) if m.groups() else m.group(0)


# T_classroom: 學習教室。老師建立，學生用 join_code 加入。
class Classroom(db.Model):
    __tablename__ = 'classroom'
    id = db.Column(db.Integer, primary_key=True)
    teacher_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)
    # 學生加入用的隨機碼。全大寫英數、去掉容易看錯的 0/O/1/I/L。
    join_code = db.Column(db.String(10), unique=True, nullable=False, index=True)
    # 老師可以關閉加入（例如開學一週後就不再收人），關閉後既有成員不受影響
    is_open = db.Column(db.Boolean, default=True)
    is_archived = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # 學期成績設定（老師在「班級成績總表」調整），用 JSON 存一份就好，不另外開表。欄位約定：
    #   {"assignment_weights": {"<assignment_id>": 1.0},   # 各作業相對權重，沒設的作業視為 1
    #    "missing_as_zero": true,                          # 缺交算 0 分；false 則不列入平均
    #    "sentence_pct": 0, "quiz_pct": 0}                 # 自主練習（造句／文章測驗）占學期成績的百分比，其餘歸作業
    # None 代表老師還沒調過，全部用預設值（作業等權重、缺交算 0、自主練習不計）
    grade_config = db.Column(db.JSON, nullable=True)

    @staticmethod
    def generate_code():
        import secrets, string
        safe_chars = ''.join(c for c in string.ascii_uppercase + string.digits if c not in '01OIL')
        while True:
            code = ''.join(secrets.choice(safe_chars) for _ in range(6))
            if not Classroom.query.filter_by(join_code=code).first():
                return code

    members = db.relationship('ClassroomMember', backref='classroom', lazy=True,
                              cascade="all, delete-orphan")
    assignments = db.relationship('Assignment', backref='classroom', lazy=True,
                                  cascade="all, delete-orphan")


# T_classroom_member: 學生與教室的關聯。一個學生可以同時加入多間教室。
class ClassroomMember(db.Model):
    __tablename__ = 'classroom_member'
    id = db.Column(db.Integer, primary_key=True)
    classroom_id = db.Column(db.Integer, db.ForeignKey('classroom.id'), nullable=False)
    student_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    # 老師看到的顯示名稱，預設抄 User.username，但老師可以改成座號或真名
    display_name = db.Column(db.String(50), nullable=True)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)
    # 學生上次打開這班公告的時間；比它新的公告算未讀（App 教室卡片上的紅點）。
    # None 代表還沒打開過，這班所有公告都算未讀
    notice_seen_at = db.Column(db.DateTime, nullable=True)

    # 同一個學生在同一間教室只會有一筆
    __table_args__ = (
        db.UniqueConstraint('classroom_id', 'student_id', name='uq_classroom_student'),
    )


# T_assignment: 老師出的題目
class Assignment(db.Model):
    __tablename__ = 'assignment'
    id = db.Column(db.Integer, primary_key=True)
    classroom_id = db.Column(db.Integer, db.ForeignKey('classroom.id'), nullable=False)
    title = db.Column(db.String(200), nullable=False)
    instructions = db.Column(db.Text, nullable=True)      # 老師給學生的說明
    task_type = db.Column(db.String(20), nullable=False)  # TaskType 其中之一

    # 各題型的參數，用 JSON 存，避免四種題型要開四張表。欄位約定：
    #   sentence: {"grammar_point": "～はいけません", "required_vocabs": ["犬"], "pass_score": 60}
    #   photo:    {"theme": "廚房裡的東西", "min_vocab_count": 3}
    #   chat:     {"topic": "在餐廳點餐", "dialect_id": 1, "min_turns": 6}
    #   article:  {"article_id": 101}
    config = db.Column(db.JSON, nullable=True)

    due_at = db.Column(db.DateTime, nullable=True)        # 不設就是沒有截止日
    # 遲交規則（LatePolicy）：None 視為 allow，舊作業行為不變。沒有截止日的作業不會遲交
    late_policy = db.Column(db.String(10), nullable=True, default='allow')
    late_penalty = db.Column(db.Integer, nullable=True, default=0)  # deduct 時每份遲交扣幾分
    is_published = db.Column(db.Boolean, default=True)    # 老師可以先存草稿
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    submissions = db.relationship('AssignmentSubmission', backref='assignment',
                                  lazy=True, cascade="all, delete-orphan")


# T_assignment_submission: 學生的作業繳交紀錄
class AssignmentSubmission(db.Model):
    __tablename__ = 'assignment_submission'
    id = db.Column(db.Integer, primary_key=True)
    assignment_id = db.Column(db.Integer, db.ForeignKey('assignment.id'), nullable=False)
    student_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    status = db.Column(db.String(20), default=SubmissionStatus.PENDING)

    # 指向學生實際作答的那筆紀錄，對應的表由 assignment.task_type 決定：
    #   sentence → sentence_practice_record.id
    #   photo    → user_photo.id
    #   chat     → chat_session.id
    #   article  → article_progress.id
    # 不用 ForeignKey 是因為要指向四張不同的表。
    result_ref_id = db.Column(db.Integer, nullable=True)

    score = db.Column(db.Integer, nullable=True)          # AI 或老師給的分數
    teacher_comment = db.Column(db.Text, nullable=True)
    # 文章測驗的逐題作答（班級報表算每題答對率、學生成果列錯題用）。格式：
    #   [{"question_index": 0, "type": "single_choice", "question": "...",
    #     "your_answer": "B", "correct_answer": "A", "is_correct": false, "explanation": "..."}]
    # 只有 submit_quiz 會寫；其他題型和舊資料為 None
    answer_detail = db.Column(db.JSON, nullable=True)
    attempt_count = db.Column(db.Integer, default=0)      # 重做次數，允許學生再挑戰
    submitted_at = db.Column(db.DateTime, nullable=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 一個學生對一份作業只有一筆繳交紀錄，重做就更新同一筆並累加 attempt_count
    __table_args__ = (
        db.UniqueConstraint('assignment_id', 'student_id', name='uq_assignment_student'),
    )


# T_classroom_announcement: 班級公告。老師在後台「公告」分頁發布，學生在 App 教室頁看到。
# 出新作業時可以勾選同時發一則，那種公告會記下 assignment_id，App 可以直接點進作業
class ClassroomAnnouncement(db.Model):
    __tablename__ = 'classroom_announcement'
    id = db.Column(db.Integer, primary_key=True)
    classroom_id = db.Column(db.Integer, db.ForeignKey('classroom.id'), nullable=False, index=True)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=True)
    # 出作業時自動發的公告指向那份作業；作業被刪除時這則公告一併刪除。一般公告為 None
    assignment_id = db.Column(db.Integer, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=True)   # 老師編輯過才有
