# 1. Python 內建標準庫
import re
from datetime import date, datetime, timedelta

# 2. 第三方套件 (Third-Party)
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash

# 3. 本地端模組 (Local)
from utils.db import db
from utils.auth_helper import generate_friend_id
from models import (
    User, UserAchievement, Achievement, 
    UserVocab, UserFolder, FriendRequest, Friendship, 
    StudyGroup, GroupMember, GroupInvite
)

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

    if not user:
        return jsonify({"error": "not_registered"}), 401

    # 如果帳號密碼正確
    if check_password_hash(user.password_hash, password):

        # 防呆：如果舊玩家沒有 friend_id，就在登入時幫他補發一個
        if not user.friend_id:
            user.friend_id = generate_friend_id()
            db.session.commit()

        # ----- 登入天數與任務重置邏輯 -----
        today = date.today()
        
        # 先用一個變數記錄「這是不是他今天第一次登入？」
        is_first_login_today = (user.last_login_date != today)
        
        if is_first_login_today:
            # 1. 算個人的馬拉松與連勝天數
            user.total_active_days = (user.total_active_days or 0) + 1

            if user.last_login_date == today - timedelta(days=1):
                user.streak_days = (user.streak_days or 0) + 1
            else:
                user.streak_days = 1

            # 2. 算小組的貢獻 (確保一天只能加一次！)
            member_record = GroupMember.query.filter_by(user_id=user.id).first()
            if member_record:
                member_record.group_logins += 1 # 個人對小組的貢獻 +1
                
                # 順便找出他們小組的資料
                # 3. 如果小組這週的任務剛好是「登入 (logins)」，才幫小組總進度 +1
                group = StudyGroup.query.get(member_record.group_id)
                if group and group.goal_type == 'logins':
                    group.current_progress += 1
                    
        # 不管是不是第一次登入，都要更新最後上線時間
        user.last_login_date = today
        user.last_seen_at = datetime.utcnow()

        # 檢查並重置今日拍照次數
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
            "friend_id": user.friend_id,
            "username": user.username
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

    # ----- 登入天數與任務重置邏輯 -----
    today = date.today()

    # 只要今天還沒登入過，馬拉松總天數就 +1
    if user.last_login_date != today:
        user.total_active_days = (user.total_active_days or 0) + 1

        # 接著算連續登入 (學習火種)
        if user.last_login_date == today - timedelta(days=1):
            # 狀況 B：昨天有登入，連勝 +1
            user.streak_days += 1
        else:
            # 狀況 C：斷掉了，或是第一次登入，重置為 1
            user.streak_days = 1

    # 把最後登入日期更新為今天
    user.last_login_date = today
    user.last_seen_at = datetime.utcnow()

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
        "friend_id": user.friend_id,
        "username": user.username
    }), 200