import re
from datetime import date, datetime
from unittest import result

from flask import Blueprint, request, jsonify

from sqlalchemy import func
from sqlalchemy.orm.attributes import flag_modified

from utils.db import db
from utils.group_helper import add_group_progress_and_check_reward
from models import (
    User, UserAbility, UserAchievement, UserVocab, UserFolder, UserVocab,
    Achievement, FriendRequest, Friendship, GroupMember, GroupInvite, StudyGroup,
    Feedback, PointTransaction, Vocab
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

# 補發初始程度徽章
@user_bp.route('/grant_initial_badges', methods=['POST'])
def grant_initial_badges():
    data = request.get_json()
    user_id = data.get('user_id')
    level = data.get('level') # 例如: 'N3'

    if not user_id or not level:
        return jsonify({"error": "缺少必要資料"}), 400

    # 1. 定義每個等級對應「應該擁有的徽章名稱」
    level_badges = {
        'N5': ['新手上路'], 
        'N4': ['新手上路', '生活達人'],
        'N3': ['新手上路', '生活達人', '交流無礙'],
        'N2': ['新手上路', '生活達人', '交流無礙', '商務菁英'],
        'N1': ['新手上路', '生活達人', '交流無礙', '商務菁英', '日語大師']
    }

    badges_to_grant = level_badges.get(level, [])
    if not badges_to_grant:
        return jsonify({"message": "沒有需要補發的徽章", "granted": []}), 200

    granted_badge_names = []

    # 2. 找出這些徽章的 ID 並發放給使用者
    for badge_name in badges_to_grant:
        ach = Achievement.query.filter_by(name=badge_name).first()
        if ach:
            # 檢查是否已經擁有，避免重複發放
            exists = UserAchievement.query.filter_by(user_id=user_id, achievement_id=ach.id).first()
            if not exists:
                new_ua = UserAchievement(user_id=user_id, achievement_id=ach.id)
                db.session.add(new_ua)
                granted_badge_names.append(badge_name)

    db.session.commit()

    return jsonify({
        "message": "初始徽章結算完成",
        "granted": granted_badge_names 
    }), 200

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
    
# 更新個人資料（包含 AI 小抄）
@user_bp.route('/update_profile', methods=['POST'])
def update_profile():
    # 假設你有傳 user_id 過來 (實戰中可能是從 Token 抓)
    user_id = request.form.get('user_id') 
    new_cheat_sheet = request.form.get('cheat_sheet', '')

    if not user_id:
        return jsonify({'error': '缺少 user_id'}), 400

    # 從資料庫找出這個人
    user = User.query.get(user_id)
    if user:
        # 把 Flutter 傳來的小抄存進資料庫
        user.ai_cheat_sheet = new_cheat_sheet
        db.session.commit()
        return jsonify({'message': 'AI 小抄更新成功！'})
    else:
        return jsonify({'error': '找不到該使用者'}), 404    

# 抓取雷達圖與徽章
@user_bp.route('/profile_data/<int:user_id>', methods=['GET'])
def get_profile_data(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到使用者"}), 404

    # 動態計算能力值
    vocab_count = UserVocab.query.filter_by(user_id=user_id).count()
    scene_count = db.session.query(func.count(func.distinct(Vocab.scene_id))).select_from(UserVocab).join(Vocab, UserVocab.vocab_id == Vocab.id).filter(UserVocab.user_id == user_id).scalar()
    folder_count = UserFolder.query.filter_by(user_id=user_id).count()
    streak = user.streak_days if user else 0
    pts = user.j_pts if user else 0

    ability_data = {
        "reading": min(vocab_count / 50, 1.0),
        "culture": min(scene_count / 5, 1.0),
        "speaking": min(streak / 30, 1.0),
        "listening": min(pts / 500, 1.0),
        "writing": min(folder_count / 10, 1.0),
    }

    # 確保最低值為 0.05（讓雷達圖不會完全空白）
    for key in ability_data:
        if ability_data[key] < 0.05:
            ability_data[key] = 0.05

    # 2. 算 5 大核心徽章的進度數字
    # 日語檢定轉換為 1~5 的數字
    level_map = {'N5': 1, 'N4': 2, 'N3': 3, 'N2': 4, 'N1': 5}
    current_n_level = level_map.get(user.japanese_level, 0)

    badge_progress = {
        "level_01": current_n_level,             # 程度認證
        "vocab_01": vocab_count,                 # 單字大富翁
        "streak_01": user.streak_days or 0,      # 學習火種
        "marathon_01": user.total_active_days or 0, # 學習馬拉松
        "camera_01": user.total_scans or 0       # 快門獵人
    }

    return jsonify({
        "ability": ability_data,
        "badge_progress": badge_progress,
        "notified_levels": user.notified_levels or {}
    }), 200

# 標記徽章彈窗已讀 API
@user_bp.route('/mark_badge_seen', methods=['POST'])
def mark_badge_seen():
    try:
        data = request.json
        user_id = data.get('user_id')
        badge_id = data.get('badge_id') # 例如 'streak_01'
        level = data.get('level')       # 例如 2
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({"error": "找不到使用者"}), 404
            
        # 1. 拿出舊的紀錄 (如果沒有就生一個空字典)
        levels = user.notified_levels or {}
        
        # 2. 更新這顆徽章的已讀等級
        levels[badge_id] = level
        
        # 3. 存回資料庫
        user.notified_levels = levels
        
        # 🌟 關鍵小技巧：因為改的是 JSON 裡面的值，要手動搖醒 SQLAlchemy
        flag_modified(user, "notified_levels")
        
        db.session.commit()
        return jsonify({"message": "徽章彈窗已標記為看過"}), 200
        
    except Exception as e:
        print(f"標記已讀失敗: {e}")
        return jsonify({"error": "伺服器發生錯誤"}), 500
    
# 增加點數
@user_bp.route('/add_points', methods=['POST'])
def add_points():
    data = request.get_json()
    user_id = data.get('user_id')
    points_to_add = data.get('points', 0)
    price = data.get('price', 0)
    payment_method = data.get('payment_method', 'unknown')

    if not user_id or points_to_add <= 0:
        return jsonify({"error": "缺少使用者 ID 或點數數量錯誤"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    user.j_pts += points_to_add

    # 存交易紀錄
    transaction = PointTransaction(
        user_id=user_id,
        points=points_to_add,
        price=price,
        payment_method=payment_method,
    )
    db.session.add(transaction)
    db.session.commit()

    member_record = GroupMember.query.filter_by(user_id=user_id).first()
    if member_record:
        member_record.group_points += points_to_add

    add_group_progress_and_check_reward(user_id=user_id, action_type="points", amount=points_to_add)

    return jsonify({
        "message": f"成功儲值 {points_to_add} 點！",
        "total_points": user.j_pts
    }), 200


# 查詢交易紀錄
@user_bp.route('/transactions/<int:user_id>', methods=['GET'])
def get_transactions(user_id):
    txns = PointTransaction.query.filter_by(user_id=user_id).order_by(PointTransaction.created_at.desc()).all()
    result = []
    for t in txns:
        result.append({
            "points": t.points,
            "price": t.price,
            "payment_method": t.payment_method,
            "created_at": t.created_at.strftime('%Y-%m-%d %H:%M'),
        })
    return jsonify({"transactions": result}), 200

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

    # 把找到的用戶資料回傳給手機
    return jsonify({
        "user_id": user.id,
        "email": user.email,
        "username": user.username,
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
        nickname = (sender.username or sender.email.split('@')[0]) if sender else "Unknown"
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
            original_name = friend_user.username or friend_user.email.split('@')[0]
            result.append({
                "user_id": friend_user.id,
                "friend_id": friend_user.friend_id,
                "avatar": friend_user.avatar,
                "username": original_name,
                "nickname": f.nickname,
                "japanese_level": friend_user.japanese_level
            })
            
    return jsonify({"friends": result}), 200

# 刪除好友 API
@user_bp.route('/friend/delete', methods=['POST'])
def delete_friend():
    data = request.get_json()
    user_id = data.get('user_id')
    target_friend_code = data.get('friend_id') # 👈 這是前端傳來的字串 ID (如 QZHPAREI)

    if not user_id or not target_friend_code:
        return jsonify({"error": "缺少必要參數"}), 400

    try:
        # 先用字串 ID 找出對方真正的資料庫「整數 ID」
        target_user = User.query.filter_by(friend_id=target_friend_code).first()
        if not target_user:
            return jsonify({"error": "找不到該用戶"}), 404

        target_user_id = target_user.id

        # 用真正的整數 ID 去查 Friendship 表並刪除雙向關係
        rel1 = Friendship.query.filter_by(user_id=user_id, friend_id=target_user_id).first()
        rel2 = Friendship.query.filter_by(user_id=target_user_id, friend_id=user_id).first()

        if not rel1 and not rel2:
            return jsonify({"error": "找不到好友紀錄"}), 404

        if rel1:
            db.session.delete(rel1)
        if rel2:
            db.session.delete(rel2)

        db.session.commit()
        return jsonify({"message": "好友已成功刪除"}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"刪除失敗: {str(e)}"}), 500


# 修改好友暱稱 (備註) API
@user_bp.route('/friend/update_nickname', methods=['POST'])
def update_friend_nickname():
    data = request.get_json()
    user_id = data.get('user_id')
    target_friend_code = data.get('friend_id') # 👈 這是前端傳來的字串 ID
    new_nickname = data.get('nickname')

    if not user_id or not target_friend_code or not new_nickname:
        return jsonify({"error": "缺少必要參數"}), 400

    try:
        # 先找出對方的整數 ID
        target_user = User.query.filter_by(friend_id=target_friend_code).first()
        if not target_user:
            return jsonify({"error": "找不到該用戶"}), 404

        # 用整數 ID 找出「你加他」的那條好友關係
        friendship = Friendship.query.filter_by(user_id=user_id, friend_id=target_user.id).first()
        
        if not friendship:
            return jsonify({"error": "找不到好友關係"}), 404
            
        # 將新的暱稱存入資料庫
        friendship.nickname = new_nickname 
        
        db.session.commit()
        return jsonify({"message": "暱稱已更新"}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"更新失敗: {str(e)}"}), 500
    
# ==========================================
# 意見回饋
# ==========================================
@user_bp.route('/feedback', methods=['POST'])
def submit_feedback():
    data = request.get_json()
    user_id = data.get('user_id')
    email = data.get('email', '')
    feedback_type = data.get('feedback_type', '')
    content = data.get('content', '').strip()

    if not content:
        return jsonify({"error": "請輸入回饋內容"}), 400
    if not feedback_type:
        return jsonify({"error": "請選擇回饋類型"}), 400

    new_feedback = Feedback(
        user_id=user_id,
        email=email,
        feedback_type=feedback_type,
        content=content,
    )
    db.session.add(new_feedback)
    db.session.commit()

    return jsonify({"message": "感謝你的回饋！我們會盡快處理"}), 200


# 查詢使用者的歷史回饋
@user_bp.route('/feedback/<int:user_id>', methods=['GET'])
def get_feedbacks(user_id):
    from datetime import timedelta
    feedbacks = Feedback.query.filter_by(user_id=user_id).order_by(Feedback.created_at.desc()).all()
    result = []
    for fb in feedbacks:
        # UTC 轉台灣時間 (+8)
        created_tw = (fb.created_at + timedelta(hours=8)) if fb.created_at else None
        replied_tw = (fb.replied_at + timedelta(hours=8)) if fb.replied_at else None
        result.append({
            "id": fb.id,
            "feedback_type": fb.feedback_type,
            "content": fb.content,
            "reply": fb.reply,
            "replied_at": replied_tw.strftime('%Y-%m-%d %H:%M') if replied_tw else None,
            "created_at": created_tw.strftime('%Y-%m-%d %H:%M') if created_tw else None,
        })
    return jsonify({"feedbacks": result}), 200


# 管理員回覆回饋
@user_bp.route('/feedback/reply', methods=['POST'])
def reply_feedback():
    data = request.get_json()
    feedback_id = data.get('feedback_id')
    reply = (data.get('reply') or '').strip()

    if not feedback_id or not reply:
        return jsonify({"error": "缺少必要資訊"}), 400

    fb = Feedback.query.get(feedback_id)
    if not fb:
        return jsonify({"error": "找不到該回饋"}), 404

    fb.reply = reply
    fb.replied_at = datetime.utcnow()
    db.session.commit()
    return jsonify({"message": "回覆成功"}), 200
