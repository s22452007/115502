from datetime import datetime
from models import User
from utils.subscription_helper import check_and_expire_subscription


def check_feature_access(user_id, required_points=0):
    """
    DFD 5.12 功能使用權限驗證。
    回傳 dict: { 'allowed': bool, 'reason': str, 'is_premium': bool, 'points': int }

    邏輯：
      1. 先呼叫 check_and_expire_subscription 確保訂閱狀態同步
      2. is_premium == True 且 subscription_end_date > 現在 → 允許（無需扣點）
      3. j_pts >= required_points → 允許（需呼叫方自行呼叫 spend_points 扣除）
      4. 否則 → 拒絕
    """
    user = User.query.get(user_id)
    if not user:
        return {'allowed': False, 'reason': '使用者不存在', 'is_premium': False, 'points': 0}

    # 同步訂閱過期狀態（修正5）
    check_and_expire_subscription(user)

    now = datetime.utcnow()
    end_date = user.subscription_end_date

    is_premium_valid = (
        user.is_premium is True
        and end_date is not None
        and end_date > now
    )

    if is_premium_valid:
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
