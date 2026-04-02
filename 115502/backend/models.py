from utils.db import db
from datetime import datetime, date

# ==========================================
# 👤 1. 核心使用者系統
# ==========================================

# 使用者表 (User)
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False) # 儲存「加密後」的密碼
    username = db.Column(db.String(30), unique=True, nullable=True)
    friend_id = db.Column(db.String(20), unique=True, nullable=True)
    japanese_level = db.Column(db.String(50), nullable=True)  # 儲存日語程度
    avatar = db.Column(db.Text, nullable=True)  # 用來存圖片的 Base64 字串
    
    j_pts = db.Column(db.Integer, default=0)         
    streak_days = db.Column(db.Integer, default=1)   
    last_login_date = db.Column(db.Date, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # 今日拍照次數與最後拍照日期
    daily_scans = db.Column(db.Integer, default=0)
    last_scan_date = db.Column(db.Date, nullable=True)

    # 關聯
    collected_vocabs = db.relationship('UserVocab', backref='user', lazy=True)
    achievements = db.relationship('UserAchievement', backref='user', lazy=True)
    abilities = db.relationship('UserAbility', backref='user', uselist=False, lazy=True) # 一對一關聯
    unlocked_scenes = db.relationship('UserScene', backref='user', lazy=True)

# 使用者能力值表 (UserAbility) - 雷達圖專用
class UserAbility(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    listening = db.Column(db.Float, default=0.2)  # 預設 0.2 (滿分 1.0)
    reading = db.Column(db.Float, default=0.2)
    writing = db.Column(db.Float, default=0.2)
    culture = db.Column(db.Float, default=0.2)
    speaking = db.Column(db.Float, default=0.2)


# ==========================================
# 📖 2. 系統教材內容 (場景、單字、測驗題庫)
# ==========================================

# 場景表 (Scene)
class Scene(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    icon_name = db.Column(db.String(50), nullable=True) 
    vocabs = db.relationship('Vocab', backref='scene', lazy=True)

# 單字字典 (Vocab)
class Vocab(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    scene_id = db.Column(db.Integer, db.ForeignKey('scene.id'), nullable=False) # 紀錄這個單字屬於哪個場景
    word = db.Column(db.String(100), nullable=False) # 單字的日文原型或漢字
    kana = db.Column(db.String(100), nullable=False) # 單字的假名拼音
    meaning = db.Column(db.String(200), nullable=False)  # 單字的中文解釋
    example_sentence = db.Column(db.String(255), nullable=True) # 儲存例句
    audio_filename = db.Column(db.String(100), nullable=True)   # 儲存音檔檔名或路徑

# 測驗題目表 (QuizQuestion) - 用於新手程度判定
class QuizQuestion(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    stage = db.Column(db.String(50), nullable=False)       # 階段名稱 (例：第一階段：超級新手)
    level_tag = db.Column(db.String(20), nullable=False)   # 難度標籤 (例：N5, N4, N3...)
    question = db.Column(db.Text, nullable=False)          # 題目內容
    option_a = db.Column(db.String(100), nullable=False)   # 選項 A
    option_b = db.Column(db.String(100), nullable=False)   # 選項 B
    option_c = db.Column(db.String(100), nullable=False)   # 選項 C
    option_d = db.Column(db.String(100), nullable=False)   # 選項 D
    correct_answer = db.Column(db.String(1), nullable=False) # 正確答案 ('A', 'B', 'C', 'D')


# ==========================================
# 🗂️ 3. 使用者學習紀錄 (場景解鎖、單字收藏)
# ==========================================

# 使用者解鎖場景表 (UserScene) - 首頁進度專用
class UserScene(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    scene_id = db.Column(db.Integer, db.ForeignKey('scene.id'), nullable=False)
    unlocked_at = db.Column(db.DateTime, default=datetime.utcnow)
    scene = db.relationship('Scene')

# 使用者的「單字收藏夾」 (UserVocab)
class UserVocab(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    vocab_id = db.Column(db.Integer, db.ForeignKey('vocab.id'), nullable=False)
    folder_id = db.Column(db.Integer, db.ForeignKey('user_folder.id'), nullable=True)
    collected_at = db.Column(db.DateTime, default=datetime.utcnow)
    vocab = db.relationship('Vocab')
    folder = db.relationship('UserFolder')

# 使用者自訂資料夾表 (UserFolder)
class UserFolder(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ==========================================
# 🏆 4. 成就、任務與交易系統
# ==========================================

# 系統徽章/成就 (Achievement)
class Achievement(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False) 
    description = db.Column(db.String(255), nullable=True)

# 使用者已解鎖的徽章 (UserAchievement)
class UserAchievement(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    achievement_id = db.Column(db.Integer, db.ForeignKey('achievement.id'), nullable=False)
    unlocked_at = db.Column(db.DateTime, default=datetime.utcnow)
    achievement = db.relationship('Achievement')

# 點數交易紀錄表 (PointTransaction)
class PointTransaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    points = db.Column(db.Integer, nullable=False)
    price = db.Column(db.Integer, nullable=False)
    payment_method = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ==========================================
# 🤝 5. 社交與好友系統
# ==========================================

# 好友邀請表 (FriendRequest)
class FriendRequest(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    receiver_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    status = db.Column(db.String(20), default='pending') # pending, accepted, rejected
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# 確立好友關係表 (Friendship)
class Friendship(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    friend_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ==========================================
# 🛡️ 6. 學習小組 (公會) 系統
# ==========================================

# 學習小組本體 (StudyGroup)
class StudyGroup(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), default="日語學習小隊") # 小組名稱
    host_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False) # 紀錄誰是「房主/創建者」
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    goal_type = db.Column(db.String(50), nullable=False, default='scans') 
    goal_target = db.Column(db.Integer, nullable=False, default=30)       
    
    # === 獎勵機制專用 ===
    current_progress = db.Column(db.Integer, default=0) # 小組當前總進度
    reward_points = db.Column(db.Integer, default=50)   # 達標後，有貢獻的成員每人可獲得的點數 (j_pts)
    is_reward_claimed = db.Column(db.Boolean, default=False) # 本次目標是否已經發放過獎勵 (防重複發放)

    # 關聯：一個小組可以有多個成員
    members = db.relationship('GroupMember', backref='group', lazy=True, cascade="all, delete-orphan")
    invites = db.relationship('GroupInvite', backref='group', lazy=True, cascade="all, delete-orphan")

# 小組成員名單 (GroupMember)
class GroupMember(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    group_id = db.Column(db.Integer, db.ForeignKey('study_group.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    joined_at = db.Column(db.DateTime, default=datetime.utcnow)

    # 專屬這個小組的貢獻紀錄
    group_scans = db.Column(db.Integer, default=0)  # 加入小組後的拍照次數
    group_points = db.Column(db.Integer, default=0) # 加入小組後的獲得點數
    group_logins = db.Column(db.Integer, default=0) # 加入小組後的登入天數

# 小組邀請表 (GroupInvite)
class GroupInvite(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    group_id = db.Column(db.Integer, db.ForeignKey('study_group.id'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False) # 邀請人 (組長)
    receiver_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False) # 被邀請人 (朋友)
    status = db.Column(db.String(20), default='pending') # 狀態：pending(待處理), accepted(已接受), rejected(已拒絕)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


# ==========================================
# 💬 7. 系統回饋與其他
# ==========================================

# 意見回饋表 (Feedback)
class Feedback(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    email = db.Column(db.String(120), nullable=True)
    feedback_type = db.Column(db.String(50), nullable=False)
    content = db.Column(db.Text, nullable=False)
    reply = db.Column(db.Text, nullable=True)
    replied_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)