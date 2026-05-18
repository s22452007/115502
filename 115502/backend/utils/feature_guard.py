from datetime import datetime
from models import User


def check_feature_access(user_id, required_points=0):
    """
    DFD 5.12 功能使用權限驗證。
    回傳 dict: { 'allowed': bool, 'reason': str, 'is_premium': bool, 'points': int }

    邏輯：
      1. is_premium 且訂閱未到期 → 允許（無需扣點）
      2. j_pts >= required_points → 允許（需呼叫方自行呼叫 spend_points 扣除）
      3. 否則 → 拒絕
    """
    user = User.query.get(user_id)
    if not user:
        return {'allowed': False, 'reason': '使用者不存在', 'is_premium': False, 'points': 0}

    now = datetime.utcnow()

    # 若本地標記是 premium 但已過期且未自動續訂，更新狀態
    if user.is_premium and user.subscription_end_date and user.subscription_end_date < now:
        if not user.auto_renew:
            from utils.db import db
            user.is_premium = False
            db.session.commit()

    if user.is_premium:
        return {
            'allowed': True,
            'reason': 'premium',
            'is_premium': True,
            'points': user.j_pts,
        }

    if required_points > 0 and user.j_pts >= required_points:
        return {
            'allowed': True,
            'reason': 'points',
            'is_premium': False,
            'points': user.j_pts,
        }

    return {
        'allowed': False,
        'reason': '需要 Premium 訂閱或足夠點數',
        'is_premium': False,
        'points': user.j_pts,
    }
