from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from utils.db import db
from models import User, UserAbility, UserAchievement, Achievement, UserVocab, UserVocab, UserFolder
from datetime import date, timedelta

# 建立 auth 的 Blueprint
auth_bp = Blueprint('auth', __name__)

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
    new_user = User(email=email, password_hash=hashed_pw)
    
    db.session.add(new_user)
    db.session.commit()

    return jsonify({"message": "註冊成功！", "user_id": new_user.id}), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    user = User.query.filter_by(email=email).first()

    # 如果帳號密碼正確
    if user and check_password_hash(user.password_hash, password):
        
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
            "j_pts": user.j_pts              # 順便把點數也傳回去
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

    # 2. 🌟 去資料庫抓取使用者「自訂」的資料夾 (就算裡面是 0 個單字也會顯示)
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