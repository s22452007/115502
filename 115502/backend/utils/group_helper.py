from utils.db import db
from models import User, StudyGroup, GroupMember

def add_group_progress_and_check_reward(user_id, action_type, amount=1):
    """
    小組進度與獎勵派發中心 (大鍋飯機制：達標全體有獎)
    action_type: 動作類型 (對應前端的 goal_type)
    amount: 這次要增加的進度量
    """
    # 1. 找看看這個人有沒有小組
    membership = GroupMember.query.filter_by(user_id=user_id).first()
    if not membership:
        return 
        
    group = StudyGroup.query.get(membership.group_id)
    if not group:
        return

    # 2. 如果他做的動作，剛好是隊長設定的目標，且還沒發過獎勵
    if group.goal_type == action_type and not group.is_reward_claimed:
        
        # 直接把進度灌給小組！
        group.current_progress += amount
        
        # 3. 判斷是否達標
        if group.current_progress >= group.goal_target:
            # 把領獎開關鎖起來，避免未來重複發錢
            group.is_reward_claimed = True 
            
            # 撈出名單，人人有獎！
            all_members = GroupMember.query.filter_by(group_id=group.id).all()
            for m in all_members:
                user_to_reward = User.query.get(m.user_id)
                if user_to_reward:
                    user_to_reward.j_pts += group.reward_points

        # 統一存檔
        db.session.commit()