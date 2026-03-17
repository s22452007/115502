from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from utils.db import db
from models import User, UserAbility, UserAchievement, Achievement, UserVocab, UserFolder, FriendRequest, Friendship
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
        db.session.commit()
        # ----- 連續登入計算邏輯結束 -----

        return jsonify({
            "message": "登入成功！",
            "user_id": user.id,
            "email": user.email,
            "japanese_level": user.japanese_level,
            "avatar": user.avatar,
            "streak_days": user.streak_days, # 把最新的天數傳給前端
            "j_pts": user.j_pts,             # 順便把點數也傳回去
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