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

    # 2. 如果他做的動作，剛好是隊長設定的目標，累加進度
    if group.goal_type == action_type:
        group.current_progress += amount
        db.session.commit()