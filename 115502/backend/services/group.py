from flask import Blueprint, request, jsonify

from utils.db import db
from models import User, StudyGroup, GroupMember, GroupInvite

group_bp = Blueprint('group', __name__)

# 取得我的小組資料
@group_bp.route('/group/my_group/<int:user_id>', methods=['GET'])
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
                # 我們不再抓 u.daily_scans，而是抓 m.group_scans (小組專屬紀錄)
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
        "members": member_data
    }), 200

# 創建小組
@group_bp.route('/group/create', methods=['POST'])
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
        
    # 建立小組
    new_group = StudyGroup(name=group_name, host_id=host_id, goal_type=goal_type, goal_target=goal_target)
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

# 取得小組邀請
@group_bp.route('/group/invites/<int:user_id>', methods=['GET'])
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

# 回覆小組邀請
@group_bp.route('/group/respond_invite', methods=['POST'])
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

# 邀請好友進現有小組
@group_bp.route('/group/invite_friends', methods=['POST'])
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

# 取得好友是否已加入小組的狀態
@group_bp.route('/group/friends_detailed_status', methods=['POST'])
def get_friends_detailed_status():
    data = request.get_json()
    group_id = data.get('group_id') # 可能是真實 ID，也可能是我們前端傳來的 -1
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
                
            # 只要他在 GroupMember 表裡有紀錄，就代表他「已經有小組了」
            has_group = GroupMember.query.filter_by(user_id=f_user.id).first() is not None
            
            # 只有在有傳入真實 group_id 的情況下，才需要檢查是否被當前小組邀請中
            is_invited = False
            if group_id and group_id != -1:
                is_invited = GroupInvite.query.filter_by(group_id=group_id, receiver_id=f_user.id, status='pending').first() is not None
            
            display_name = f_user.email.split('@')[0] if f_user.email else "未知好友"

            detailed_friends.append({
                'nickname': display_name, 
                'friend_id': f_user.friend_id,
                'avatar': f_user.avatar,
                'has_group': has_group,  # 回傳 has_group 給前端
                'is_invited': is_invited, 
            })

        return jsonify({"friends": detailed_friends}), 200

    except Exception as e:
        print("API 發生錯誤:", str(e)) 
        return jsonify({"error": f"後端錯誤: {str(e)}"}), 500

# 退出/解散小組
@group_bp.route('/group/leave', methods=['POST'])
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
        # 判斷是否為組長
        if group.host_id == user_id:
            # 是組長：解散整個小組 (因為你有設定 cascade="all, delete-orphan"，這會連帶刪除成員名單)
            db.session.delete(group)
            db.session.commit()
            return jsonify({"message": "身為組長的你退出了，小組已解散！"}), 200
        else:
            # 是一般成員：單純刪除他的成員紀錄
            member = GroupMember.query.filter_by(group_id=group_id, user_id=user_id).first()
            if member:
                db.session.delete(member)
                db.session.commit()
            return jsonify({"message": "已成功退出小組！"}), 200
            
    except Exception as e:
        print("退出小組發生錯誤:", str(e))
        return jsonify({"error": f"後端錯誤: {str(e)}"}), 500
