from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from utils.db import db
from models import User, UserAbility, UserAchievement, Achievement, UserVocab, UserFolder, FriendRequest, Friendship, StudyGroup, GroupMember, GroupInvite
from datetime import date, timedelta
import random
import string

# 建立 auth 的 Blueprint
auth_bp = Blueprint('auth', __name__)

# 新增一個小工具：用來產生 8 碼不重複的隨機交友 ID
def generate_friend_id():
    characters = string.ascii_uppercase + string.digits # 大寫英文字母 + 數字
    while True:
        # 隨機湊出 8 個字
        new_id = ''.join(random.choice(characters) for _ in range(8))
        # 檢查資料庫有沒有人已經用過這個 ID，沒有的話才回傳
        if not User.query.filter_by(friend_id=new_id).first():
            return new_id

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({"error": "請填寫 Email 與密碼"}), 400

    # 檢查是否已經被註冊過
    if User.query.filter_by(email=email).first():
        return jsonify({"error": "這個 Email 已經註冊過囉！"}), 400

    # 將密碼加密後，存入資料庫
    hashed_pw = generate_password_hash(password)
    
    # 在建立新使用者時，給他一組隨機交友 ID
    new_friend_id = generate_friend_id()
    new_user = User(email=email, password_hash=hashed_pw, friend_id=new_friend_id)
    
    db.session.add(new_user)
    db.session.commit()

    return jsonify({
        "message": "註冊成功！", 
        "user_id": new_user.id,
        "friend_id": new_friend_id  
    }), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    user = User.query.filter_by(email=email).first()

    # 如果帳號密碼正確
    if user and check_password_hash(user.password_hash, password):
        
        # 防呆：如果舊玩家沒有 friend_id，就在登入時幫他補發一個
        if not user.friend_id:
            user.friend_id = generate_friend_id()
            db.session.commit()

        # ----- 連續登入計算邏輯開始 -----
        today = date.today()
        
        if user.last_login_date == today:
            # 狀況 A：今天已經登入過了，天數不變
            pass 
        elif user.last_login_date == today - timedelta(days=1):
            # 狀況 B：昨天有登入，天數 +1
            user.streak_days += 1
        else:
            # 狀況 C：斷掉了，或是第一次登入，重置為 1
            user.streak_days = 1
            
        # 把最後登入日期更新為今天
        user.last_login_date = today
        
        # 檢查並重置今日拍照次數 (如果是新的一天，就把次數歸零)
        if user.last_scan_date != today:
            user.daily_scans = 0
            user.last_scan_date = today

        db.session.commit()

        return jsonify({
            "message": "登入成功！",
            "user_id": user.id,
            "email": user.email,
            "japanese_level": user.japanese_level,
            "avatar": user.avatar,
            "streak_days": user.streak_days, # 把最新的天數傳給前端
            "j_pts": user.j_pts,             # 順便把點數也傳回去
            "daily_scans": user.daily_scans,
            "friend_id": user.friend_id      # 把交友 ID 傳回給前端
        }), 200
    else:
        return jsonify({"error": "Email 或密碼錯誤"}), 401
    
@auth_bp.route('/reset_password', methods=['POST'])
def reset_password():
    data = request.get_json()
    email = data.get('email')
    new_password = data.get('new_password')

    if not email or not new_password:
        return jsonify({"error": "請填寫 Email 與新密碼"}), 400

    # 去資料庫找看看這個 Email 存不存在
    user = User.query.filter_by(email=email).first()
    
    if not user:
        return jsonify({"error": "找不到此 Email，請確認是否輸入正確"}), 404

    # 將新密碼加密後，覆蓋掉舊密碼
    user.password_hash = generate_password_hash(new_password)
    db.session.commit()

    return jsonify({"message": "密碼重設成功！請使用新密碼登入"}), 200

@auth_bp.route('/update_level', methods=['POST'])
def update_level():
    data = request.get_json()
    user_id = data.get('user_id')
    level = data.get('level')

    if not user_id or not level:
        return jsonify({"error": "缺少使用者 ID 或程度資訊"}), 400

    # 尋找使用者
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    # 直接更新日語程度
    user.japanese_level = level
    db.session.commit()

    return jsonify({"message": "程度更新成功！", "level": level}), 200

@auth_bp.route('/upload_avatar', methods=['POST'])
def upload_avatar():
    data = request.get_json()
    user_id = data.get('user_id')
    avatar_base64 = data.get('avatar')

    if not user_id or not avatar_base64:
        return jsonify({"error": "缺少使用者 ID 或圖片"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    user.avatar = avatar_base64 # 更新大頭貼
    db.session.commit()

    return jsonify({"message": "大頭貼更新成功！", "avatar": avatar_base64}), 200

@auth_bp.route('/profile_data/<int:user_id>', methods=['GET'])
def get_profile_data(user_id):
    # 1. 抓取能力值 (雷達圖)
    ability = UserAbility.query.filter_by(user_id=user_id).first()
    
    # 如果這個人還沒有能力值記錄，我們就給他一個預設值 (0.2)
    ability_data = {
        "listening": ability.listening if ability else 0.2,
        "reading": ability.reading if ability else 0.2,
        "writing": ability.writing if ability else 0.2,
        "culture": ability.culture if ability else 0.2,
        "speaking": ability.speaking if ability else 0.2,
    }

    # 2. 抓取成就徽章
    # 先抓出系統裡所有的徽章總表
    all_achievements = Achievement.query.all()
    # 再抓出這個使用者「已經解鎖」的徽章
    unlocked_records = UserAchievement.query.filter_by(user_id=user_id).all()
    unlocked_ids = [record.achievement_id for record in unlocked_records]

    achievements_data = []
    for ach in all_achievements:
        achievements_data.append({
            "id": ach.id,
            "name": ach.name,
            "description": ach.description,
            "is_unlocked": ach.id in unlocked_ids # 判斷是否有解鎖
        })

    return jsonify({
        "ability": ability_data,
        "achievements": achievements_data
    }), 200

@auth_bp.route('/favorites/<int:user_id>', methods=['GET'])
def get_user_favorites(user_id):
    user_vocabs = UserVocab.query.filter_by(user_id=user_id).all()
    folders = {}

    # 1. 抓取系統單字自動生成的資料夾
    for uv in user_vocabs:
        scene_name = uv.vocab.scene.name if uv.vocab.scene else "未分類單字"
        if scene_name not in folders:
            folders[scene_name] = {"name": scene_name, "count": 0}
        folders[scene_name]["count"] += 1

    # 2. 去資料庫抓取使用者「自訂」的資料夾
    custom_folders = UserFolder.query.filter_by(user_id=user_id).all()
    for cf in custom_folders:
        if cf.name not in folders:
            folders[cf.name] = {"name": cf.name, "count": 0}

    result = list(folders.values())
    return jsonify({"favorites": result}), 200

@auth_bp.route('/folders', methods=['POST'])
def create_folder():
    data = request.get_json()
    user_id = data.get('user_id')
    name = data.get('name')

    if not user_id or not name:
        return jsonify({"error": "缺少必要資料"}), 400

    # 把自訂資料夾存進資料庫
    new_folder = UserFolder(user_id=user_id, name=name)
    db.session.add(new_folder)
    db.session.commit()

    return jsonify({"message": "資料夾建立成功！"}), 201

@auth_bp.route('/search_friend', methods=['POST'])
def search_friend():
    data = request.get_json()
    friend_id = data.get('friend_id')

    if not friend_id:
        return jsonify({"error": "請輸入對方的專屬 ID"}), 400

    # 去資料庫尋找有沒有這個 ID 的人
    # (因為我們有設定 friend_id 是唯一的，所以用 filter_by 找第一個就好)
    user = User.query.filter_by(friend_id=friend_id).first()

    if not user:
        return jsonify({"error": "找不到此 ID 的用戶 🥲"}), 404

    # 把找到的用戶資料回傳給手機 (因為資料庫目前沒有暱稱，我們先用 email 當作名字)
    return jsonify({
        "user_id": user.id,
        "email": user.email,
        "friend_id": user.friend_id,
        "avatar": user.avatar
    }), 200

@auth_bp.route('/friend_request/send', methods=['POST'])
def send_friend_request():
    data = request.get_json()
    sender_id = data.get('sender_id')
    receiver_id = data.get('receiver_id')

    # 檢查是否已經是好友
    if Friendship.query.filter_by(user_id=sender_id, friend_id=receiver_id).first():
         return jsonify({"error": "你們已經是好友了！"}), 400

    # 檢查是否已經發過邀請 (正在等對方同意)
    if FriendRequest.query.filter_by(sender_id=sender_id, receiver_id=receiver_id, status='pending').first():
        return jsonify({"error": "已經發送過邀請，請靜候對方同意喔！"}), 400

    new_req = FriendRequest(sender_id=sender_id, receiver_id=receiver_id)
    db.session.add(new_req)
    db.session.commit()
    return jsonify({"message": "邀請已順利送出！"}), 201

@auth_bp.route('/friend_request/pending/<int:user_id>', methods=['GET'])
def get_pending_requests(user_id):
    # 抓出「寄給我」且「還沒處理」的邀請
    requests = FriendRequest.query.filter_by(receiver_id=user_id, status='pending').all()
    result = []
    for req in requests:
        sender = User.query.get(req.sender_id)
        nickname = sender.email.split('@')[0] if sender else "Unknown"
        result.append({
            "request_id": req.id,
            "sender_id": req.sender_id,
            "nickname": nickname,
            "friend_id": sender.friend_id,
            "avatar": sender.avatar
        })
    return jsonify({"pending_requests": result}), 200

@auth_bp.route('/friend_request/respond', methods=['POST'])
def respond_friend_request():
    data = request.get_json()
    request_id = data.get('request_id')
    action = data.get('action') # 'accept' (接受) 或 'reject' (拒絕)

    req = FriendRequest.query.get(request_id)
    if not req:
        return jsonify({"error": "找不到此邀請"}), 404

    req.status = action # 更新狀態
    
    if action == 'accept':
        # 如果接受，就互相加為好友 (建立兩筆紀錄，方便雙向查詢)
        f1 = Friendship(user_id=req.sender_id, friend_id=req.receiver_id)
        f2 = Friendship(user_id=req.receiver_id, friend_id=req.sender_id)
        db.session.add_all([f1, f2])

    db.session.commit()
    return jsonify({"message": f"已{'接受' if action == 'accept' else '拒絕'}邀請！"}), 200

@auth_bp.route('/friends/<int:user_id>', methods=['GET'])
def get_friends_list(user_id):
    # 從 Friendship 表單抓取所有這個 user 的好友紀錄
    friendships = Friendship.query.filter_by(user_id=user_id).all()
    
    result = []
    for f in friendships:
        # 找出好友的詳細資料
        friend_user = User.query.get(f.friend_id)
        if friend_user:
            nickname = friend_user.email.split('@')[0]
            result.append({
                "user_id": friend_user.id,
                "nickname": nickname,
                "friend_id": friend_user.friend_id,
                "avatar": friend_user.avatar
            })
            
    return jsonify({"friends": result}), 200

@auth_bp.route('/add_points', methods=['POST'])
def add_points():
    data = request.get_json()
    user_id = data.get('user_id')
    points_to_add = data.get('points', 0) # 前端告訴我要加多少點

    if not user_id or points_to_add <= 0:
        return jsonify({"error": "缺少使用者 ID 或點數數量錯誤"}), 400

    # 去資料庫找這個人
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    # 把他的點數加上去！
    user.j_pts += points_to_add
    db.session.commit()

    return jsonify({
        "message": f"成功儲值 {points_to_add} 點！", 
        "total_points": user.j_pts # 回傳最新的總餘額給前端
    }), 200

@auth_bp.route('/increment_scan', methods=['POST'])
def increment_scan():
    data = request.get_json()
    user_id = data.get('user_id')

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    today = date.today()
    # 防呆：如果是新的一天，先歸零
    if user.last_scan_date != today:
        user.daily_scans = 0
        user.last_scan_date = today

    # 增加次數 (假設每日目標是 3 次)
    if user.daily_scans < 3:
        user.daily_scans += 1
    
    # 🎁 (選擇性) 如果你想讓使用者達成目標時獲得獎勵，可以解開下面這兩行：
    # if user.daily_scans == 3:
    #     user.j_pts += 10 # 達成目標送 10 點！

    db.session.commit()

    return jsonify({
        "message": "進度更新成功！",
        "daily_scans": user.daily_scans
    }), 200

# ==========================================
# 學習小組 API
# ==========================================

@auth_bp.route('/group/my_group/<int:user_id>', methods=['GET'])
def get_my_group(user_id):
    # 找自己在哪個小組
    member_record = GroupMember.query.filter_by(user_id=user_id).first()
    if not member_record:
        return jsonify({"has_group": False}), 200 # 還沒加入任何小組
        
    group = StudyGroup.query.get(member_record.group_id)
    # 抓取這個小組的所有成員
    members = GroupMember.query.filter_by(group_id=group.id).all()
    
    member_data = []
    for m in members:
        u = User.query.get(m.user_id)
        if u:
            # 把每個人的資料打包，這樣前端就可以顯示大家今天的進度了！
            member_data.append({
                "user_id": u.id,
                "nickname": u.email.split('@')[0],
                "avatar": u.avatar,
                "daily_scans": u.daily_scans, # 🌟 核心功能：讓大家互相看到對方的今日進度！
                "is_host": u.id == group.host_id
            })
            
    return jsonify({
        "has_group": True,
        "group_id": group.id,
        "group_name": group.name,
        "members": member_data
    }), 200

# 建立學習小組 API (發送邀請給好友)
@auth_bp.route('/group/create', methods=['POST'])
def create_group():
    data = request.get_json()
    host_id = data.get('host_id')
    group_name = data.get('name', '日語學習小隊')
    friend_ids = data.get('friend_ids', []) 
    
    if not host_id:
        return jsonify({"error": "缺少房主 ID"}), 400

    if GroupMember.query.filter_by(user_id=host_id).first():
        return jsonify({"error": "你已經加入過小組囉！"}), 400
        
    # 建立小組
    new_group = StudyGroup(name=group_name, host_id=host_id)
    db.session.add(new_group)
    db.session.flush() 
    
    # 把房主自己加入成員名單
    host_member = GroupMember(group_id=new_group.id, user_id=host_id)
    db.session.add(host_member)
    
    # 發送邀請給好友
    for f_id in friend_ids:
        friend_user = User.query.filter_by(friend_id=f_id).first()
        if friend_user:
            # 確認沒邀請過才發送
            existing_invite = GroupInvite.query.filter_by(group_id=new_group.id, receiver_id=friend_user.id, status='pending').first()
            if not existing_invite:
                new_invite = GroupInvite(group_id=new_group.id, sender_id=host_id, receiver_id=friend_user.id)
                db.session.add(new_invite)
            
    db.session.commit()
    return jsonify({"message": "小組建立成功，已發送邀請給好友！", "group_id": new_group.id}), 201

# 真實的「讀取收到的邀請」 API
@auth_bp.route('/group/invites/<int:user_id>', methods=['GET'])
def get_group_invites(user_id):
    # 找出所有寄給這個人，且狀態是 pending 的邀請
    invites = GroupInvite.query.filter_by(receiver_id=user_id, status='pending').all()
    
    result = []
    for inv in invites:
        group = StudyGroup.query.get(inv.group_id)
        sender = User.query.get(inv.sender_id)
        if group and sender:
            result.append({
                "invite_id": inv.id,
                "group_id": group.id,
                "group_name": group.name,
                "inviter_name": sender.email.split('@')[0] # 取 Email 前半段當暱稱
            })
            
    return jsonify({"invites": result}), 200

# 處理邀請 (同意或拒絕) API
@auth_bp.route('/group/respond_invite', methods=['POST'])
def respond_group_invite():
    data = request.get_json()
    invite_id = data.get('invite_id')
    action = data.get('action') # 傳入 'accept' 或 'reject'
    user_id = data.get('user_id')

    invite = GroupInvite.query.get(invite_id)
    if not invite or invite.receiver_id != user_id:
        return jsonify({"error": "找不到此邀請"}), 404

    # 更改狀態
    invite.status = action
    
    if action == 'accept':
        # 檢查小組是不是已經滿 5 人了
        current_members = GroupMember.query.filter_by(group_id=invite.group_id).count()
        if current_members >= 5:
            return jsonify({"error": "這個小組已經客滿了！"}), 400
            
        # 檢查自己是不是已經在別的小組了
        if GroupMember.query.filter_by(user_id=user_id).first():
            return jsonify({"error": "你已經在其他小組中，無法重複加入！"}), 400

        # 都沒問題，正式寫入小組成員名單！
        new_member = GroupMember(group_id=invite.group_id, user_id=user_id)
        db.session.add(new_member)

    db.session.commit()
    msg = "已成功加入小組！" if action == 'accept' else "已拒絕邀請"
    return jsonify({"message": msg}), 200

# ==========================================
# 第三方登入整合 API (Google Login)
# ==========================================
@auth_bp.route('/google_login', methods=['POST'])
def google_login():
    data = request.get_json()
    email = data.get('email')
    
    # Google 登入通常可以順便拿到大頭貼網址，可以選擇性傳入
    avatar = data.get('avatar', '')

    if not email:
        return jsonify({"error": "缺少 Email"}), 400

    user = User.query.filter_by(email=email).first()

    if not user:
        # 狀況 A：這是一個全新的使用者，自動幫他在資料庫建檔！
        new_friend_id = generate_friend_id()
        # 因為是用 Google 登入，不需要輸入密碼，所以隨機塞一個極高強度的假密碼給他
        dummy_pwd = generate_password_hash("GOOGLE_OAUTH_" + email) 
        
        user = User(email=email, password_hash=dummy_pwd, friend_id=new_friend_id, avatar=avatar)
        db.session.add(user)
        db.session.commit() # 先 commit 讓 user 產生 id
    else:
        # 狀況 B：老用戶，防呆檢查有沒有交友 ID
        if not user.friend_id:
            user.friend_id = generate_friend_id()
        # 如果老用戶沒頭像，但這次 Google 有傳過來，就順便更新
        if avatar and not user.avatar:
            user.avatar = avatar

    # ----- 登入天數與任務重置邏輯 (跟一般登入完全一樣) -----
    today = date.today()
    
    if user.last_login_date == today:
        pass 
    elif user.last_login_date == today - timedelta(days=1):
        user.streak_days += 1
    else:
        user.streak_days = 1
        
    user.last_login_date = today
    
    if user.last_scan_date != today:
        user.daily_scans = 0
        user.last_scan_date = today

    db.session.commit()

    # 把所有的資料回傳給前端，讓前端的 UserProvider 能夠順利運作！
    return jsonify({
        "message": "Google 登入成功！",
        "user_id": user.id,
        "email": user.email,
        "japanese_level": user.japanese_level,
        "avatar": user.avatar,
        "streak_days": user.streak_days,
        "j_pts": user.j_pts,
        "daily_scans": user.daily_scans,
        "friend_id": user.friend_id
    }), 200

# 🛡️ 邀請好友加入「現有」小組 API
@auth_bp.route('/group/invite_friends', methods=['POST'])
def invite_friends_to_group():
    data = request.get_json()
    group_id = data.get('group_id')
    sender_id = data.get('sender_id')
    friend_ids = data.get('friend_ids', [])

    if not group_id or not sender_id:
        return jsonify({"error": "缺少必要資訊"}), 400

    group = StudyGroup.query.get(group_id)
    if not group:
        return jsonify({"error": "找不到該小組"}), 404

    invited_count = 0
    for f_id in friend_ids:
        friend_user = User.query.filter_by(friend_id=f_id).first()
        if friend_user:
            # 1. 檢查是否已經在小組內
            is_member = GroupMember.query.filter_by(group_id=group_id, user_id=friend_user.id).first()
            # 2. 檢查是否已經發過邀請 (且對方還沒按同意或拒絕)
            is_invited = GroupInvite.query.filter_by(group_id=group_id, receiver_id=friend_user.id, status='pending').first()

            # 如果他不在小組內，且還沒被邀請過，才發送邀請！
            if not is_member and not is_invited:
                new_invite = GroupInvite(group_id=group_id, sender_id=sender_id, receiver_id=friend_user.id)
                db.session.add(new_invite)
                invited_count += 1

    db.session.commit()
    return jsonify({"message": f"成功發送 {invited_count} 個邀請！"}), 200

# 🛡️ 抓取包含邀請狀態的詳細好友名單 API
@auth_bp.route('/group/friends_detailed_status', methods=['POST'])
def get_friends_detailed_status():
    data = request.get_json()
    group_id = data.get('group_id')
    user_id = data.get('user_id')

    if not group_id or not user_id:
        return jsonify({"error": "缺少必要資訊"}), 400

    try:
        # 1. 抓取好友關係：尋找 Friendship 表中，user_id 是目前登入者的紀錄
        friendships = Friendship.query.filter_by(user_id=user_id).all()
        
        detailed_friends = []

        for fs in friendships:
            # 透過 fs.friend_id (整數PK) 去 User 表找好友的詳細資料
            f_user = User.query.get(fs.friend_id)
            if not f_user:
                continue
                
            # 2. 檢查狀態防呆
            # a. 檢查對方是否已經是小組成員
            is_member = GroupMember.query.filter_by(group_id=group_id, user_id=f_user.id).first() is not None
            
            # b. 檢查是否已經發過邀請 (且狀態為 'pending')
            is_invited = GroupInvite.query.filter_by(group_id=group_id, receiver_id=f_user.id, status='pending').first() is not None
            
            # 整理回傳資料
            # 因為你的 models.py 裡面的 User 沒有 nickname 欄位
            # 所以這裡的顯示名稱 (nickname) 我們先用他的學號/公開ID (friend_id) 來代替，拿 Email @ 前面的字串當作名字
            display_name = f_user.email.split('@')[0] if f_user.email else "未知好友"
            detailed_friends.append({
                'nickname': display_name, 
                'friend_id': f_user.friend_id,
                'avatar': f_user.avatar,
                'is_member': is_member,  
                'is_invited': is_invited, 
            })

        return jsonify({"friends": detailed_friends}), 200

    except Exception as e:
        print("API 發生錯誤:", str(e)) # 錯誤印在終端機方便 Debug
        return jsonify({"error": f"後端錯誤: {str(e)}"}), 500