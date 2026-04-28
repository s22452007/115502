from flask import Blueprint, request, jsonify
from utils.db import db
from models import User, StudyGroup, GroupMember, GroupInvite, Friendship
from datetime import datetime, timedelta, timezone

group_bp = Blueprint('group', __name__)

# ==========================================
# 🛠️ 輔助工具：時間與週次計算
# ==========================================
def get_current_year_week():
    """取得現在是哪一年的第幾週 (例如：'2026-16')"""
    now = datetime.now(timezone.utc)
    year, week, _ = now.isocalendar()
    return f"{year}-{week}"

def get_next_sunday_end():
    """取得這個星期日 23:59:59 的 UTC 時間"""
    now = datetime.now(timezone.utc)
    # weekday(): 禮拜一是 0，禮拜日是 6
    days_until_sunday = 6 - now.weekday()
    next_sunday = now + timedelta(days=days_until_sunday)
    return next_sunday.replace(hour=23, minute=59, second=59, microsecond=0)

def handle_deposit_and_free_quota(user):
    """處理玩家的押金與免費額度"""
    current_week = get_current_year_week()
    is_free = (user.last_free_group_week != current_week)
    
    if not is_free:
        # 第二團起，檢查餘額並扣除 20 點押金
        if user.j_pts < 20:
            return False, "點數不足 20 點，無法開啟額外小組對賭！", False
        user.j_pts -= 20
        return True, "OK", True  # 付了押金
    else:
        # 免費團，更新他的免費額度使用紀錄
        user.last_free_group_week = current_week
        return True, "OK", False # 使用免費額度


# ==========================================
# 1. 取得我的小組資料 (含自動結算清道夫)
# ==========================================
@group_bp.route('/my_group/<int:user_id>', methods=['GET'])
def get_my_group(user_id):
    member_record = GroupMember.query.filter_by(user_id=user_id).first()
    if not member_record:
        return jsonify({"has_group": False}), 200 
        
    group = StudyGroup.query.get(member_record.group_id)
    
    # -----------------------------------------------------
    # 終極清道夫 (Lazy Evaluation)：時間到了嗎？
    # -----------------------------------------------------
    now = datetime.now(timezone.utc)
    # SQLite 拿出來的時間沒有時區，要手動幫它掛上 UTC 以便比較
    expire_time = group.expire_at.replace(tzinfo=timezone.utc) if group.expire_at.tzinfo is None else group.expire_at
    
    if now > expire_time:
        # 結算時間到！判斷是否達標
        is_success = group.current_progress >= group.goal_target
        
        # 抓出所有成員
        members = GroupMember.query.filter_by(group_id=group.id).all()
        for m in members:
            u = User.query.get(m.user_id)
            if u and is_success and not m.has_claimed:
                # 達標發放獎勵！加回押金
                total_reward = group.reward_points + (20 if m.paid_deposit else 0)
                u.j_pts += total_reward 
                
        # 結算完畢後，抓取「當前打開畫面的這個人」的最新點數
        current_user = User.query.get(user_id)
        latest_pts = current_user.j_pts if current_user else 0

        # 解散小組 (Cascade 設定會一併刪除 GroupMember)
        db.session.delete(group)
        db.session.commit()
        
        msg = f"📜 上週結算：挑戰成功！獎勵已自動匯入錢包！" if is_success else "💀 結算：上週挑戰失敗，押金已被沒收！"
        return jsonify({
            "has_group": False, 
            "message": msg, 
            "just_expired": True,
            "new_j_pts": latest_pts
        }), 200
    # -----------------------------------------------------

    # 1️⃣ 先抓取這個小組的「正式成員」
    members = GroupMember.query.filter_by(group_id=group.id).all()
    member_data = []
    for m in members:
        u = User.query.get(m.user_id)
        if u:
            # 取得原名
            original_name = u.username or u.email.split('@')[0]
            member_data.append({
                "user_id": u.id,
                "friend_id": u.friend_id, # 傳送 ID 用來算顏色
                "username": original_name, # 傳送原名
                "nickname": original_name, # 注意：排行榜通常不顯示備註，直接顯示原名即可
                "avatar": u.avatar,
                "japanese_level": u.japanese_level, # 打包日語程度
                "is_host": u.id == group.host_id,
                "group_scans": m.group_scans, 
                "group_points": m.group_points,              
                "group_logins": m.group_logins 
            })

    # 2️⃣ 接著抓取這個小組「邀請中 (pending)」的名單
    pending_invites = GroupInvite.query.filter_by(group_id=group.id, status='pending').all()
    pending_data = []
    for inv in pending_invites:
        u = User.query.get(inv.receiver_id)
        if u:
            original_name = u.username or u.email.split('@')[0]
            pending_data.append({
                "friend_id": u.friend_id,
                "username": original_name,
                "avatar": u.avatar
            })
            
    # 3️⃣ 兩邊都抓完之後，最後統一打包回傳！
    return jsonify({
        "has_group": True,
        "group_id": group.id,
        "group_name": group.name,
        "goal_type": group.goal_type,     
        "goal_target": group.goal_target, 
        "current_progress": group.current_progress, 
        "reward_points": group.reward_points,       
        "members": member_data,              # 正式成員
        "pending_invites": pending_data,     # 把邀請中的名單也一起交給前端！
        "has_claimed": member_record.has_claimed # 傳遞此用戶是否已領獎！
    }), 200

# ==========================================
# 2. 創建小組 (POST /create)
# ==========================================
@group_bp.route('/create', methods=['POST'])
def create_group():
    data = request.get_json()
    host_id = data.get('host_id')
    group_name = data.get('name', '日語學習小隊')
    friend_ids = data.get('friend_ids', []) 
    goal_type = data.get('goal_type', 'logins') # 預設改為登入
    goal_target = data.get('goal_target', 35)

    if not host_id:
        return jsonify({"error": "缺少房主 ID"}), 400

    if GroupMember.query.filter_by(user_id=host_id).first():
        return jsonify({"error": "系統偵測到您已在其他小組中，無法重複建立！"}), 400
        
    user = User.query.get(host_id)
    if not user:
        return jsonify({"error": "找不到用戶"}), 404

    # 檢查押金與額度
    success, msg, paid_deposit = handle_deposit_and_free_quota(user)
    if not success:
        return jsonify({"error": msg}), 400

    try:
        # 根據「目標類型」與「目標數值」，動態決定獎勵點數！
        calculated_reward = 30 # 預設防呆值
        
        if goal_type == 'scans':
            # 📸 拍照任務 (輕鬆15次 / 標準30次 / 爆肝50次)
            if goal_target <= 15:
                calculated_reward = 20
            elif goal_target <= 30:
                calculated_reward = 40
            else:
                calculated_reward = 80
                
        elif goal_type == 'logins':
            # 📅 登入任務 (輕鬆15天 / 標準25天 / 爆肝35天)
            if goal_target <= 15:
                calculated_reward = 20
            elif goal_target <= 25:
                calculated_reward = 40
            else:
                calculated_reward = 80

        # 建立小組，並計算結算日
        new_group = StudyGroup(
            name=group_name, 
            host_id=host_id, 
            goal_type=goal_type, 
            goal_target=goal_target,
            reward_points=calculated_reward, # 動態計算的獎勵
            expire_at=get_next_sunday_end() 
        )
        db.session.add(new_group)
        db.session.flush() 
        
        initial_logins = 1 if goal_type == 'logins' else 0
        host_member = GroupMember(
            group_id=new_group.id, 
            user_id=host_id,
            group_logins=initial_logins,
            paid_deposit=paid_deposit # 紀錄是否付了押金！
        )
        db.session.add(host_member)
        new_group.current_progress += initial_logins

        # 發送邀請
        for f_id in friend_ids:
            friend_user = User.query.filter_by(friend_id=f_id).first()
            if friend_user:
                existing_invite = GroupInvite.query.filter_by(group_id=new_group.id, receiver_id=friend_user.id, status='pending').first()
                if not existing_invite:
                    new_invite = GroupInvite(group_id=new_group.id, sender_id=host_id, receiver_id=friend_user.id)
                    db.session.add(new_invite)
                
        db.session.commit()
        return jsonify({
            "message": "小組建立成功，已發送邀請給好友！", 
            "group_id": new_group.id,
            "new_j_pts": user.j_pts # 把最新的餘額回傳給前端
        }), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"建立小組失敗: {str(e)}"}), 500


# ==========================================
# 3. 取得小組邀請 (GET /invites/<user_id>)
# ==========================================
@group_bp.route('/invites/<int:user_id>', methods=['GET'])
def get_group_invites(user_id):
    invites = GroupInvite.query.filter_by(receiver_id=user_id, status='pending').all()
    result = []
    for inv in invites:
        group = StudyGroup.query.get(inv.group_id)
        sender = User.query.get(inv.sender_id)
        if group and sender:
            # 取得原名
            original_name = sender.username or sender.email.split('@')[0]
            
            # 去 Friendship 表格查查看，接收者(你)有沒有幫發送者取過暱稱(備註)？
            fs = Friendship.query.filter_by(user_id=user_id, friend_id=sender.id).first()
            custom_nickname = fs.nickname if fs else None

            result.append({
                "invite_id": inv.id,
                "group_id": group.id,
                "group_name": group.name,
                "inviter_name": original_name,       # 原名
                "inviter_nickname": custom_nickname, # 打包專屬備註
                "inviter_friend_id": sender.friend_id, 
                "inviter_avatar": sender.avatar,       
                "inviter_level": sender.japanese_level 
            })
    return jsonify({"invites": result}), 200

# ==========================================
# 撤銷小組邀請 (POST /cancel_invite)
# ==========================================
@group_bp.route('/cancel_invite', methods=['POST'])
def cancel_invite():
    data = request.get_json()
    group_id = data.get('group_id')
    friend_id_str = data.get('receiver_id') # 前端傳來的是字串 ID (例如 97WBADI1)

    if not group_id or not friend_id_str:
        return jsonify({"error": "缺少必要資訊"}), 400

    try:
        # 先用字串 ID 找出這位使用者的真實資料庫 ID
        target_user = User.query.filter_by(friend_id=friend_id_str).first()
        
        if not target_user:
            return jsonify({"error": "找不到該使用者資料"}), 404

        # 用真實的整數 target_user.id 去尋找邀請紀錄
        invite = GroupInvite.query.filter_by(
            group_id=group_id, 
            receiver_id=target_user.id, # 這裡換成整數 ID 啦！
            status='pending'
        ).first()

        if invite:
            db.session.delete(invite)
            db.session.commit()
            return jsonify({"message": "已成功取消邀請"}), 200
        else:
            return jsonify({"error": "找不到該邀請紀錄，可能已被對方處理或刪除"}), 404

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"取消邀請失敗: {str(e)}"}), 500
    
# ==========================================
# 4. 回覆小組邀請 (POST /respond_invite)
# ==========================================
@group_bp.route('/respond_invite', methods=['POST'])
def respond_group_invite():
    data = request.get_json()
    invite_id = data.get('invite_id')
    action = data.get('action') 
    user_id = data.get('user_id')

    invite = GroupInvite.query.get(invite_id)
    if not invite or invite.receiver_id != user_id:
        return jsonify({"error": "找不到此邀請"}), 404

    user = User.query.get(user_id)
    
    try:
        invite.status = action
        if action == 'accept':
            # 防呆：小組滿 5 人不准進！
            current_members = GroupMember.query.filter_by(group_id=invite.group_id).count()
            if current_members >= 5:
                return jsonify({"error": "這個小組已經客滿了！"}), 400
                
            if GroupMember.query.filter_by(user_id=user_id).first():
                return jsonify({"error": "你已經在其他小組中，無法重複加入！"}), 400

            group = StudyGroup.query.get(invite.group_id)
            if not group:
                return jsonify({"error": "找不到該小組"}), 404

            # 防白嫖：如果小組已經達標，鎖定車門！
            if group.current_progress >= group.goal_target:
                return jsonify({"error": "該小組已達成目標，目前鎖定加入喔！"}), 400

            # 加入也需要檢查押金與額度
            success, msg, paid_deposit = handle_deposit_and_free_quota(user)
            if not success:
                return jsonify({"error": msg}), 400

            initial_logins = 1 if group.goal_type == 'logins' else 0
            new_member = GroupMember(
                group_id=invite.group_id, 
                user_id=user_id,
                group_logins=initial_logins,
                paid_deposit=paid_deposit # 紀錄是否付了押金！
            )
            db.session.add(new_member)
            group.current_progress += initial_logins

        db.session.commit()
        msg = "已成功加入小組！" if action == 'accept' else "已拒絕邀請"
        return jsonify({
            "message": msg,
            "new_j_pts": user.j_pts # 把最新的餘額回傳給前端
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"處理邀請失敗: {str(e)}"}), 500


# ==========================================
# 5. 邀請好友進現有小組 (POST /invite_friends)
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

    # 防白嫖：如果小組已經達標，不准再發邀請拉人！
    if group.current_progress >= group.goal_target:
        return jsonify({"error": "小組已達標，無法再發送邀請！"}), 400

    try:
        invited_count = 0
        for f_id in friend_ids:
            friend_user = User.query.filter_by(friend_id=f_id).first()
            if friend_user:
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
# 6. 取得好友詳細狀態 (POST /friends_detailed_status)
# ==========================================
@group_bp.route('/friends_detailed_status', methods=['POST'])
def get_friends_detailed_status():
    data = request.get_json()
    group_id = data.get('group_id') 
    user_id = data.get('user_id')

    if not user_id:
        return jsonify({"error": "缺少必要資訊"}), 400

    try:
        friendships = Friendship.query.filter_by(user_id=user_id).all()
        detailed_friends = []
        
        # 建立一個「已見過的好友 ID」集合，用來過濾髒資料！
        seen_ids = set()

        for fs in friendships:
            # 如果這個朋友已經處理過了，就直接跳過（去重複）
            if fs.friend_id in seen_ids:
                continue
                
            f_user = User.query.get(fs.friend_id)
            if not f_user:
                continue
            
            # 把處理過的朋友 ID 加進名單中
            seen_ids.add(fs.friend_id)
                
            has_group = GroupMember.query.filter_by(user_id=f_user.id).first() is not None
            is_invited = False
            if group_id and group_id != -1:
                is_invited = GroupInvite.query.filter_by(group_id=group_id, receiver_id=f_user.id, status='pending').first() is not None
            
            # 取得原名
            original_name = f_user.username or f_user.email.split('@')[0] 

            detailed_friends.append({
                'username': original_name,
                'nickname': fs.nickname, 
                'friend_id': f_user.friend_id,
                'avatar': f_user.avatar,
                'has_group': has_group,  
                'is_invited': is_invited, 
                'japanese_level': f_user.japanese_level
            })

        return jsonify({"friends": detailed_friends}), 200

    except Exception as e:
        return jsonify({"error": f"獲取好友狀態失敗: {str(e)}"}), 500

# ==========================================
# 7. 退出 / 解散小組 (POST /leave) -> 被焊死了！
# ==========================================
@group_bp.route('/leave', methods=['POST'])
def leave_group():
    # 為了防止舊版 App 呼叫，直接擋下來
    return jsonify({"error": "一週鎖定模式，挑戰結算前無法退出喔！"}), 400

# ==========================================
# 8. 手動各自領取獎勵 (POST /claim_reward)
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
        return jsonify({"error": "任務尚未達成，還不能領獎喔！"}), 400

    try:
        # 計算總獎勵 = 預設獎勵 + (若有付押金則退還 20 點)
        total_reward = group.reward_points + (20 if member.paid_deposit else 0)

        user = User.query.get(user_id)
        user.j_pts += total_reward

        # 領完獎後，直接把這個人從小組刪除 (順利畢業)
        # 注意：我們「絕對不」扣除 group.current_progress，讓留下來的隊友依然能領獎！
        db.session.delete(member)
        db.session.commit()

        # 檢查是不是所有人都領完結業了？
        # 如果小組空了，代表大家都領完了，這組才真正解散清除！
        remaining_members = GroupMember.query.filter_by(group_id=group_id).count()
        if remaining_members == 0:
            db.session.delete(group) # 清除這個空蕩蕩的小組
            db.session.commit()

        msg = f"太棒了！成功領取 {group.reward_points} 點"
        if member.paid_deposit:
            msg += " (含退還 20 點押金)"
        msg += "！你已順利結業！"

        return jsonify({"message": msg, "new_j_pts": user.j_pts}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"領獎失敗: {str(e)}"}), 500
    
# ==========================================
# 9. 檢查本週是否還有免費額度 (GET /check_quota/<user_id>)
# ==========================================
@group_bp.route('/check_quota/<int:user_id>', methods=['GET'])
def check_quota(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到用戶"}), 404
        
    current_week = get_current_year_week()
    is_free = (user.last_free_group_week != current_week)
    
    return jsonify({"is_free": is_free}), 200