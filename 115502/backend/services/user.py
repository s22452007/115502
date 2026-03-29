import re
from datetime import date

from flask import Blueprint, request, jsonify

from utils.db import db
from utils.group_helper import add_group_progress_and_check_reward
from models import (
    User, UserAbility, UserAchievement, UserVocab, UserFolder, 
    Achievement, FriendRequest, Friendship, GroupMember, GroupInvite, StudyGroup
)

user_bp = Blueprint('user', __name__)

# ==========================================
# [個人設定與數據]
# ==========================================
# 更新日語等級
@user_bp.route('/update_level', methods=['POST'])
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

# 上傳大頭貼
@user_bp.route('/upload_avatar', methods=['POST'])
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

# 檢查暱稱
@user_bp.route('/check_username', methods=['POST'])
def check_username():
    data = request.get_json()
    username = (data.get('username') or '').strip()
    current_user_id = data.get('user_id')

    if not username:
        return jsonify({"error": "請輸入暱稱"}), 400
    if len(username) < 2 or len(username) > 20:
        return jsonify({"error": "暱稱需為 2～20 個字元"}), 400
    if not re.match(r'^[\u4e00-\u9fffA-Za-z0-9_]+$', username):
        return jsonify({"error": "暱稱只能包含中文、英文、數字或底線"}), 400

    query = User.query.filter(db.func.lower(User.username) == username.lower())
    if current_user_id:
        query = query.filter(User.id != current_user_id)
    taken = query.first()
    if taken:
        return jsonify({"available": False, "error": "此暱稱已被使用"}), 200

    return jsonify({"available": True}), 200

# 更新暱稱
@user_bp.route('/update_username', methods=['POST'])
def update_username():
    data = request.get_json()
    user_id = data.get('user_id')
    username = (data.get('username') or '').strip()

    if not user_id or not username:
        return jsonify({"error": "缺少必要資訊"}), 400
    if len(username) < 2 or len(username) > 20:
        return jsonify({"error": "暱稱需為 2～20 個字元"}), 400
    if not re.match(r'^[\u4e00-\u9fffA-Za-z0-9_]+$', username):
        return jsonify({"error": "暱稱只能包含中文、英文、數字或底線"}), 400

    taken = User.query.filter(
        db.func.lower(User.username) == username.lower(),
        User.id != user_id
    ).first()
    if taken:
        return jsonify({"error": "此暱稱已被使用"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到使用者"}), 404

    user.username = username
    db.session.commit()
    return jsonify({"message": "暱稱更新成功", "username": username}), 200

# 刪除帳號
@user_bp.route('/delete_account', methods=['POST'])
def delete_account():
    data = request.get_json()
    user_id = data.get('user_id')

    if not user_id:
        return jsonify({"error": "缺少 user_id"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到使用者"}), 404

    try:
        # 刪除相關資料
        UserAbility.query.filter_by(user_id=user_id).delete()
        UserAchievement.query.filter_by(user_id=user_id).delete()
        UserVocab.query.filter_by(user_id=user_id).delete()
        UserFolder.query.filter_by(user_id=user_id).delete()
        FriendRequest.query.filter(
            (FriendRequest.sender_id == user_id) | (FriendRequest.receiver_id == user_id)
        ).delete(synchronize_session=False)
        Friendship.query.filter(
            (Friendship.user_id == user_id) | (Friendship.friend_id == user_id)
        ).delete(synchronize_session=False)

        # 處理小組：如果是組長就解散，否則退出
        hosted_groups = StudyGroup.query.filter_by(host_id=user_id).all()
        for group in hosted_groups:
            GroupInvite.query.filter_by(group_id=group.id).delete()
            GroupMember.query.filter_by(group_id=group.id).delete()
            db.session.delete(group)

        GroupMember.query.filter_by(user_id=user_id).delete()
        GroupInvite.query.filter_by(receiver_id=user_id).delete()
        GroupInvite.query.filter_by(sender_id=user_id).delete()

        db.session.delete(user)
        db.session.commit()

        return jsonify({"message": "帳號已刪除"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"刪除失敗：{str(e)}"}), 500
    
# 抓取雷達圖與徽章
@user_bp.route('/profile_data/<int:user_id>', methods=['GET'])
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

# 增加點數
@user_bp.route('/add_points', methods=['POST'])
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

    # 增加小組的點數貢獻
    member_record = GroupMember.query.filter_by(user_id=user_id).first()
    if member_record:
        member_record.group_points += points_to_add

    # 幫小組的點數任務進度加上他剛賺到的點數 (points_to_add)
    add_group_progress_and_check_reward(user_id=user_id, action_type="points", amount=points_to_add)

    return jsonify({
        "message": f"成功儲值 {points_to_add} 點！", 
        "total_points": user.j_pts # 回傳最新的總餘額給前端
    }), 200

# 增加拍照次數
@user_bp.route('/increment_scan', methods=['POST'])
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
    
    # 增加小組的拍照貢獻
    member_record = GroupMember.query.filter_by(user_id=user_id).first()
    if member_record:
        member_record.group_scans += 1
    
    db.session.commit()

    # 把這次拍照的進度算給小組，並檢查要不要發獎勵！
    add_group_progress_and_check_reward(user_id=user_id, action_type="scans", amount=1)

    return jsonify({
        "message": "進度更新成功！",
        "daily_scans": user.daily_scans
    }), 200

# ==========================================
# [好友系統]
# ==========================================
# 搜尋好友
@user_bp.route('/search_friend', methods=['POST'])
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

# 發送交友邀請
@user_bp.route('/friend_request/send', methods=['POST'])
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

# 查看收到的邀請
@user_bp.route('/friend_request/pending/<int:user_id>', methods=['GET'])
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

# 接受/拒絕邀請
@user_bp.route('/friend_request/respond', methods=['POST'])
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

# 好友列表
@user_bp.route('/friends/<int:user_id>', methods=['GET'])
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
