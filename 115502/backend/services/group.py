from flask import Blueprint, request, jsonify
from utils.db import db
from models import User, StudyGroup, GroupMember, GroupInvite, Friendship

group_bp = Blueprint('group', __name__)

# ==========================================
# 取得我的小組資料 (GET /my_group/<user_id>)
# ==========================================
@group_bp.route('/my_group/<int:user_id>', methods=['GET'])
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
            # 把每個人的資料打包，回傳給前端顯示
            member_data.append({
                "user_id": u.id,
                "nickname": u.username or u.email.split('@')[0], # 優先顯示真實暱稱
                "avatar": u.avatar,
                "daily_scans": m.group_scans, 
                "j_pts": m.group_points,             
                "streak_days": m.group_logins, 
                "is_host": u.id == group.host_id
            })
            
    return jsonify({
        "has_group": True,
        "group_id": group.id,
        "group_name": group.name,
        "goal_type": group.goal_type,     # 把設定的目標類型傳給前端
        "goal_target": group.goal_target, # 把設定的目標次數傳給前端
        "current_progress": group.current_progress, 
        "reward_points": group.reward_points,       
        "is_reward_claimed": group.is_reward_claimed,
        "members": member_data
    }), 200


# ==========================================
# 創建小組 (POST /create)
# ==========================================
@group_bp.route('/create', methods=['POST'])
def create_group():
    data = request.get_json()
    host_id = data.get('host_id')
    group_name = data.get('name', '日語學習小隊')
    friend_ids = data.get('friend_ids', []) 
    goal_type = data.get('goal_type', 'scans')
    goal_target = data.get('goal_target', 30)

    if not host_id:
        return jsonify({"error": "缺少房主 ID"}), 400

    if GroupMember.query.filter_by(user_id=host_id).first():
        return jsonify({"error": "你已經加入過小組囉！"}), 400
        
    try:
        # 1. 建立小組主檔
        new_group = StudyGroup(name=group_name, host_id=host_id, goal_type=goal_type, goal_target=goal_target)
        db.session.add(new_group)
        db.session.flush() 
        
        # 2. 把房主自己加入成員名單
        # 建立小組的當下，進度直接算 1 天！
        # 根據目標類型給予對應的初始進度
        initial_logins = 1 if goal_type == 'logins' else 0
        
        host_member = GroupMember(
            group_id=new_group.id, 
            user_id=host_id,
            group_logins=initial_logins # 給予 1 天的登入進度
        )
        db.session.add(host_member)
        
        # 同步更新小組的總進度 (這樣首頁進度條才不會是 0)
        new_group.current_progress += initial_logins

        # 3. 發送邀請給好友
        for f_id in friend_ids:
            friend_user = User.query.filter_by(friend_id=f_id).first()
            if friend_user:
                existing_invite = GroupInvite.query.filter_by(group_id=new_group.id, receiver_id=friend_user.id, status='pending').first()
                if not existing_invite:
                    new_invite = GroupInvite(group_id=new_group.id, sender_id=host_id, receiver_id=friend_user.id)
                    db.session.add(new_invite)
                
        db.session.commit()
        return jsonify({"message": "小組建立成功，已發送邀請給好友！", "group_id": new_group.id}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"建立小組失敗: {str(e)}"}), 500


# ==========================================
# 取得小組邀請 (GET /invites/<user_id>)
# ==========================================
@group_bp.route('/invites/<int:user_id>', methods=['GET'])
def get_group_invites(user_id):
    # 找出所有寄給我，且狀態是 pending 的邀請
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
                "inviter_name": sender.username or sender.email.split('@')[0] # 優先顯示真實暱稱
            })
            
    return jsonify({"invites": result}), 200


# ==========================================
# 回覆小組邀請 (POST /respond_invite)
# ==========================================
@group_bp.route('/respond_invite', methods=['POST'])
def respond_group_invite():
    data = request.get_json()
    invite_id = data.get('invite_id')
    action = data.get('action') # 傳入 'accept' 或 'reject'
    user_id = data.get('user_id')

    invite = GroupInvite.query.get(invite_id)
    if not invite or invite.receiver_id != user_id:
        return jsonify({"error": "找不到此邀請"}), 404

    try:
        # 更改邀請狀態
        invite.status = action
        
        if action == 'accept':
            # 檢查小組是不是已經滿 5 人了
            current_members = GroupMember.query.filter_by(group_id=invite.group_id).count()
            if current_members >= 5:
                return jsonify({"error": "這個小組已經客滿了！"}), 400
                
            # 檢查自己是不是已經在別的小組了
            if GroupMember.query.filter_by(user_id=user_id).first():
                return jsonify({"error": "你已經在其他小組中，無法重複加入！"}), 400

            group = StudyGroup.query.get(invite.group_id)
            if not group:
                return jsonify({"error": "找不到該小組"}), 404

            # 加入小組的當下，進度算 1 天！
            initial_logins = 1 if group.goal_type == 'logins' else 0

            # 正式寫入小組成員名單
            new_member = GroupMember(
                group_id=invite.group_id, 
                user_id=user_id,
                group_logins=initial_logins # 給予 1 天的登入進度
            )
            db.session.add(new_member)
            
            # 同步更新小組的總進度
            group.current_progress += initial_logins

        db.session.commit()
        msg = "已成功加入小組！" if action == 'accept' else "已拒絕邀請"
        return jsonify({"message": msg}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"處理邀請失敗: {str(e)}"}), 500


# ==========================================
# 邀請好友進現有小組 (POST /invite_friends)
# ==========================================
@group_bp.route('/invite_friends', methods=['POST'])
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

    try:
        invited_count = 0
        for f_id in friend_ids:
            friend_user = User.query.filter_by(friend_id=f_id).first()
            if friend_user:
                # 檢查是否已在小組內或已被邀請
                is_member = GroupMember.query.filter_by(group_id=group_id, user_id=friend_user.id).first()
                is_invited = GroupInvite.query.filter_by(group_id=group_id, receiver_id=friend_user.id, status='pending').first()

                if not is_member and not is_invited:
                    new_invite = GroupInvite(group_id=group_id, sender_id=sender_id, receiver_id=friend_user.id)
                    db.session.add(new_invite)
                    invited_count += 1

        db.session.commit()
        return jsonify({"message": f"成功發送 {invited_count} 個邀請！"}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"發送邀請失敗: {str(e)}"}), 500


# ==========================================
# 取得好友詳細狀態 (供拉人清單使用) (POST /friends_detailed_status)
# ==========================================
@group_bp.route('/friends_detailed_status', methods=['POST'])
def get_friends_detailed_status():
    data = request.get_json()
    group_id = data.get('group_id') # 可能是真實 ID，也可能是新建小組傳來的 -1
    user_id = data.get('user_id')

    if not user_id:
        return jsonify({"error": "缺少必要資訊"}), 400

    try:
        friendships = Friendship.query.filter_by(user_id=user_id).all()
        detailed_friends = []

        for fs in friendships:
            f_user = User.query.get(fs.friend_id)
            if not f_user:
                continue
                
            # 判斷他是否已經有小組了
            has_group = GroupMember.query.filter_by(user_id=f_user.id).first() is not None
            
            # 判斷是否被當前小組邀請中
            is_invited = False
            if group_id and group_id != -1:
                is_invited = GroupInvite.query.filter_by(group_id=group_id, receiver_id=f_user.id, status='pending').first() is not None
            
            display_name = f_user.username or f_user.email.split('@')[0] # 優先顯示真實暱稱

            detailed_friends.append({
                'nickname': display_name, 
                'friend_id': f_user.friend_id,
                'avatar': f_user.avatar,
                'has_group': has_group,  
                'is_invited': is_invited, 
            })

        return jsonify({"friends": detailed_friends}), 200

    except Exception as e:
        return jsonify({"error": f"獲取好友狀態失敗: {str(e)}"}), 500


# ==========================================
# 退出 / 解散小組 (POST /leave)
# ==========================================
@group_bp.route('/leave', methods=['POST'])
def leave_group():
    data = request.get_json()
    group_id = data.get('group_id')
    user_id = data.get('user_id')

    if not group_id or not user_id:
        return jsonify({"error": "缺少必要資訊"}), 400

    group = StudyGroup.query.get(group_id)
    if not group:
        return jsonify({"error": "找不到該小組"}), 404

    try:
        if group.host_id == user_id:
            # 是組長：解散整個小組
            db.session.delete(group)
            db.session.commit()
            return jsonify({"message": "身為組長的你退出了，小組已解散！"}), 200
        else:
            # 是一般成員：退出小組
            member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
            if member:
                # 退出時，可以選擇把他的貢獻從總進度扣除 (根據你的遊戲規則決定)
                group.current_progress -= (member.group_logins if group.goal_type == 'logins' else member.group_scans)
                db.session.delete(member)
                db.session.commit()
            return jsonify({"message": "已成功退出小組！"}), 200
            
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"退出小組失敗: {str(e)}"}), 500


# ==========================================
# 領取小組獎勵 (POST /claim_reward)
# ==========================================
@group_bp.route('/claim_reward', methods=['POST'])
def claim_reward():
    data = request.get_json()
    group_id = data.get('group_id')
    user_id = data.get('user_id')

    group = StudyGroup.query.get(group_id)
    member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()

    if not group or not member:
        return jsonify({"error": "找不到小組或你已不在小組中"}), 404

    if group.current_progress < group.goal_target:
        return jsonify({"error": "任務尚未達成，無法領獎"}), 400

    try:
        # 發放點數
        user = User.query.get(user_id)
        user.j_pts += group.reward_points

        # 領完獎後安全移除
        db.session.delete(member)
        db.session.commit()

        # 檢查小組是否空了，空了才徹底刪除
        remaining_members = GroupMember.query.filter_by(group_id=group_id).count()
        if remaining_members == 0:
            db.session.delete(group)
            db.session.commit()

        return jsonify({"message": f"成功領取 {group.reward_points} 點！"}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"領獎失敗: {str(e)}"}), 500