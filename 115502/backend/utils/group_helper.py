from utils.db import db
from models import User, StudyGroup, GroupMember

def add_group_progress_and_check_reward(user_id, action_type, amount=1):
    """
    小組進度與獎勵派發中心 (大鍋飯機制：達標全體有獎)
    action_type: 動作類型 (對應前端的 goal_type)
      支援：'scans' | 'logins' | 'sentences' | 'articles'
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

        # 同步更新個人貢獻欄位（用於排行榜顯示）
        if action_type == 'sentences':
            membership.group_sentences = (membership.group_sentences or 0) + amount
        elif action_type == 'articles':
            membership.group_articles = (membership.group_articles or 0) + amount

        db.session.commit()