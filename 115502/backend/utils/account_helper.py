"""帳號類型的共用判斷。

教育版是學校採購、老師帶班使用，學生端不該出現任何付費或次數限制。
這裡把判斷集中成一個函式，避免 account_type == 'student' 這種字串
散落在各個 service 裡 —— 之後若要新增帳號類型（例如試用班級），
只要改這裡就好。
"""

from models import AccountType


def is_edu_student(user):
    """是不是校園教育版的學生帳號。"""
    if user is None:
        return False
    return getattr(user, 'account_type', AccountType.GENERAL) == AccountType.STUDENT


def has_unlimited_usage(user):
    """這個帳號是否不受每日次數限制。

    目前等同於「是不是教育版學生」，但特意分成兩個函式：
    呼叫端關心的是「能不能無限使用」，而不是帳號類型本身。
    """
    return is_edu_student(user)


# 造句批改、文章朗讀評分的每日次數（免費版 / Premium）。教育版學生不受限（has_unlimited_usage）。
# 拍照與 AI 對話的次數另外寫在 services/user.py（photo 2/10、AI 3/10）。
SENTENCE_DAILY_LIMIT = {'free': 3, 'premium': 10}
READING_DAILY_LIMIT = {'free': 1, 'premium': 5}


def _tier(user):
    return 'premium' if getattr(user, 'is_premium', False) else 'free'


def sentence_daily_limit(user):
    """每天可以免費 AI 批改造句幾次（超過可以花點數）"""
    return SENTENCE_DAILY_LIMIT[_tier(user)]


def reading_daily_limit(user):
    """每天可以做幾次文章朗讀評分"""
    return READING_DAILY_LIMIT[_tier(user)]


def today_start_utc():
    """台灣時間今天 00:00 換算成 UTC（資料庫的 created_at 存 UTC），算「今天用了幾次」用。"""
    from datetime import datetime, timedelta, timezone
    tw = timezone(timedelta(hours=8))
    today_tw = datetime.now(tw).date()
    return datetime.combine(today_tw, datetime.min.time()) - timedelta(hours=8)


def is_payment_free(user):
    """這個帳號是否完全不需要付費／扣點。

    教育版學生的解鎖文章、造句超額、小組押金全部免費。
    """
    return is_edu_student(user)
