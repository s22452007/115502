from flask import Blueprint, request, jsonify
from utils.db import db
from models import User, StudyGroup, GroupMember, GroupInvite, Friendship, PointTransaction, TransactionType
from datetime import datetime, timezone

group_bp = Blueprint('group', __name__)

# ==========================================
# 🛠️ 輔助工具：時間與週次計算
# ==========================================
def get_current_year_week():
    """取得現在是哪一年的第幾週 (例如：'2026-16')"""
    now = datetime.now(timezone.utc)
    year, week, _ = now.isocalendar()
    return f"{year}-{week}"


def handle_deposit_and_free_quota(user):
    """
    處理每週免費次數與押金邏輯，回傳 (success, msg, deposit_amount)。
    - 免費用戶：每週 1 次免押金，超過後押 20 點
    - 訂閱用戶：每週 3 次免押金，超過後押 10 點
    加入成功後無論免費或付押金都會計入本週次數。
    """
    current_week = get_current_year_week()

    # 若是新的一週，重置計數器
    if getattr(user, 'last_free_group_week', None) != current_week:
        user.last_free_group_week = current_week
        user.group_free_used_this_week = 0

    free_quota = 3 if user.is_premium else 1
    free_used = getattr(user, 'group_free_used_this_week', 0) or 0

    if free_used < free_quota:
        # 本週免費額度內：免押金
        user.group_free_used_this_week = free_used + 1
        return True, "OK", 0
    else:
        # 本週免費額度已用完：需要押金
        deposit = 10 if user.is_premium else 20
        if user.j_pts < deposit:
            quota_label = '3 次' if user.is_premium else '1 次'
            return False, f"本週免費額度（{quota_label}）已用完，且點數不足 {deposit} 點押金！", 0
        user.j_pts -= deposit
        user.group_free_used_this_week = free_used + 1
        feature_key = 'group_deposit_premium' if user.is_premium else 'group_deposit_free'
        db.session.add(PointTransaction(
            user_id=user.id,
            points=-deposit,
            price=0,
            payment_method='points',
            transaction_type=TransactionType.SPEND,
            related_feature=feature_key,
        ))
        return True, "OK", deposit


def _give_group_reward(user, member, group):
    """按本週加入次數（是否付押金）與訂閱狀態給予獎勵，回傳描述字串。"""
    # 目標難度分級
    if group.goal_target <= 15:
        tier = 0  # 輕鬆
    elif group.goal_target <= 30:
        tier = 1  # 標準
    else:
        tier = 2  # 爆肝

    # 退還押金
    deposit_refund = getattr(member, 'deposit_amount', 0) or (20 if member.paid_deposit else 0)
    if deposit_refund > 0:
        user.j_pts += deposit_refund
        db.session.add(PointTransaction(
            user_id=user.id,
            points=deposit_refund,
            price=0,
            payment_method='refund',
            transaction_type=TransactionType.REWARD,
            related_feature='group_deposit_refund',
        ))

    # 依「是否付押金」判斷獎勵等級
    if not member.paid_deposit:
        # 本週第一次加入（免押金）：較多獎勵 5/10/20
        pts = [5, 10, 20][tier]
        related_feature = 'group_first_completion'
    elif user.is_premium:
        # 本週第二次起 + 訂閱用戶：5/8/12
        pts = [5, 8, 12][tier]
        related_feature = 'group_completion'
    else:
        # 本週第二次起 + 免費用戶：3/5/8
        pts = [3, 5, 8][tier]
        related_feature = 'group_completion'

    user.j_pts += pts
    db.session.add(PointTransaction(
        user_id=user.id,
        points=pts,
        price=0,
        payment_method='reward',
        transaction_type=TransactionType.REWARD,
        related_feature=related_feature,
    ))

    msg_parts = [f'獲得 {pts} 點']
    if deposit_refund > 0:
        msg_parts.append(f'退還押金 {deposit_refund} 點')

    return '、'.join(msg_parts)


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
    # 以 ISO 週次比對：建立週 < 當前週 → 該小組已過期
    # -----------------------------------------------------
    now = datetime.now(timezone.utc)
    created = group.created_at.replace(tzinfo=timezone.utc) if group.created_at.tzinfo is None else group.created_at
    if now.isocalendar()[:2] > created.isocalendar()[:2]:
        # 結算時間到！判斷是否達標
        is_success = group.current_progress >= group.goal_target
        
        # 抓出所有成員
        members = GroupMember.query.filter_by(group_id=group.id).all()
        for m in members:
            u = User.query.get(m.user_id)
            if u and is_success and not m.has_claimed:
                _give_group_reward(u, m, group)
                m.has_claimed = True
                
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
    user_id = data.get('user_id')
    group_name = data.get('name', '日語學習小隊')
    friend_ids = data.get('friend_ids', [])
    goal_type = data.get('goal_type', 'logins')
    goal_target = data.get('goal_target', 35)

    if not user_id:
        return jsonify({"error": "缺少使用者 ID"}), 400

    if GroupMember.query.filter_by(user_id=user_id).first():
        return jsonify({"error": "系統偵測到您已在其他小組中，無法重複建立！"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到用戶"}), 404

    # 檢查押金與額度
    success, msg, deposit_amount = handle_deposit_and_free_quota(user)
    if not success:
        return jsonify({"error": msg}), 400
    paid_deposit = deposit_amount > 0

    try:
        # 建立小組
        new_group = StudyGroup(
            name=group_name,
            goal_type=goal_type,
            goal_target=goal_target,
        )
        db.session.add(new_group)
        db.session.flush()

        initial_logins = 1 if goal_type == 'logins' else 0
        host_member = GroupMember(
            group_id=new_group.id,
            user_id=user_id,
            group_logins=initial_logins,
            paid_deposit=paid_deposit,
            deposit_amount=deposit_amount,
        )
        db.session.add(host_member)
        new_group.current_progress += initial_logins

        # 發送邀請
        for f_id in friend_ids:
            friend_user = User.query.filter_by(friend_id=f_id).first()
            if friend_user:
                existing_invite = GroupInvite.query.filter_by(group_id=new_group.id, receiver_id=friend_user.id, status='pending').first()
                if not existing_invite:
                    new_invite = GroupInvite(group_id=new_group.id, sender_id=user_id, receiver_id=friend_user.id)
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
            success, msg, deposit_amount = handle_deposit_and_free_quota(user)
            if not success:
                return jsonify({"error": msg}), 400
            paid_deposit = deposit_amount > 0

            initial_logins = 1 if group.goal_type == 'logins' else 0
            new_member = GroupMember(
                group_id=invite.group_id,
                user_id=user_id,
                group_logins=initial_logins,
                paid_deposit=paid_deposit,
                deposit_amount=deposit_amount,
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
        return jsonify({"error": "獎勵已領取或你已不在此小組中"}), 404

    if group.current_progress < group.goal_target:
        return jsonify({"error": "任務尚未達成，還不能領獎喔！"}), 400

    try:
        user = User.query.get(user_id)
        reward_desc = _give_group_reward(user, member, group)

        db.session.delete(member)
        db.session.commit()

        remaining_members = GroupMember.query.filter_by(group_id=group_id).count()
        if remaining_members == 0:
            db.session.delete(group)
            db.session.commit()

        return jsonify({"message": f"太棒了！{reward_desc}！你已順利結業！", "new_j_pts": user.j_pts}), 200

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
    if getattr(user, 'last_free_group_week', None) != current_week:
        free_used = 0
    else:
        free_used = getattr(user, 'group_free_used_this_week', 0) or 0

    free_quota = 3 if user.is_premium else 1
    remaining = max(0, free_quota - free_used)

    return jsonify({
        "is_free": remaining > 0,
        "free_used": free_used,
        "free_quota": free_quota,
        "remaining_free": remaining,
    }), 200