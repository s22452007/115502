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
    username = db.Column(db.String(30), unique=True, nullable=True)
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
    # 徽章與成就
    total_active_days = db.Column(db.Integer, default=0)
    total_scans = db.Column(db.Integer, default=0)
    notified_levels = db.Column(db.JSON, default={})
    # 訂閱與小組狀態
    is_premium = db.Column(db.Boolean, default=False)
    subscription_end_date = db.Column(db.DateTime, nullable=True)
    auto_renew = db.Column(db.Boolean, default=False)
    trial_used = db.Column(db.Boolean, default=False)
    trial_notice_sent = db.Column(db.Boolean, default=False)
    last_free_group_week = db.Column(db.String(10), nullable=True)
    group_free_used_this_week = db.Column(db.Integer, default=0)
    vocab_slot = db.Column(db.Integer, default=50)

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

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

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
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    photo_vocabs = db.relationship('UserPhotoVocab', backref='photo', lazy=True, cascade="all, delete-orphan")

# T07: 照片辨識單字明細表
class UserPhotoVocab(db.Model):
    __tablename__ = 'user_photo_vocab'
    id = db.Column(db.Integer, primary_key=True)
    photo_id = db.Column(db.Integer, db.ForeignKey('user_photo.id'), nullable=False)
    vocab_id = db.Column(db.Integer, db.ForeignKey('vocab.id'), nullable=False)

# T08: 使用者單字收藏表
class UserVocab(db.Model):
    __tablename__ = 'user_vocab'
    __table_args__ = (db.UniqueConstraint('user_id', 'vocab_id', name='uq_user_vocab_user_vocab'),)
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    vocab_id = db.Column(db.Integer, db.ForeignKey('vocab.id'), nullable=False)
    folder_id = db.Column(db.Integer, db.ForeignKey('user_folder.id'), nullable=True)
    collected_at = db.Column(db.DateTime, nullable=True)

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