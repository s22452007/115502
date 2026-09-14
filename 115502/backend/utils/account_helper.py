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


def is_payment_free(user):
    """這個帳號是否完全不需要付費／扣點。

    教育版學生的解鎖文章、造句超額、小組押金全部免費。
    """
    return is_edu_student(user)
