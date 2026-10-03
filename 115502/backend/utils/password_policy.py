"""密碼強度規則（App 與後台共用）。

規則：
  - 少於 8 個字元：一律不能使用
  - 一般使用者自行設定的密碼：8 個字元以上即可，強度只是參考
  - 老師、管理者帳號，以及老師建立的學生帳號：至少要「中」

強度等級：
  too_short  少於 8 個字元
  weak       8 字元以上，但只有一種字元、是常見密碼、是連號／重複字元，或包含帳號名稱
  medium     8 字元以上、至少兩種字元，且沒有上述問題
  strong     12 字元以上、至少三種字元，且沒有上述問題

前端 lib/utils/password_policy.dart 是同一套規則，改這裡時兩邊要一起改。
"""
from werkzeug.security import check_password_hash

MIN_LENGTH = 8
STRONG_LENGTH = 12

LEVEL_LABELS = {
    'too_short': '太短',
    'weak': '弱',
    'medium': '中',
    'strong': '強',
}

# 最常被使用、最容易被猜中的密碼（全部轉小寫比對）
COMMON_PASSWORDS = {
    '12345678', '123456789', '1234567890', '87654321', '11111111', '00000000',
    '88888888', '66666666', '12341234', '11223344', '123123123', '147258369',
    'password', 'password1', 'password123', 'passw0rd', 'p@ssw0rd', 'p@ssword',
    'qwertyui', 'qwerty123', 'qwertyuiop', '1qaz2wsx', 'qazwsxedc', '1q2w3e4r',
    'asdfghjk', 'zxcvbnm1', 'iloveyou', 'abcd1234', 'abc12345', 'aa123456',
    'admin123', 'administrator', 'welcome1', 'letmein1', 'sunshine', 'princess',
    'football', 'baseball', 'superman', 'trustno1', 'whatever', 'dragon12',
    'snaptolearn', 'jlens123', 'teacher123', 'student123', 'guest123',
}

# 連號判斷用的序列（含鍵盤排列）
_SEQUENCES = (
    '01234567890123456789',
    'abcdefghijklmnopqrstuvwxyz',
    'qwertyuiopasdfghjklzxcvbnm',
    'qwertyuiop', 'asdfghjkl', 'zxcvbnm',
    '1qaz2wsx3edc4rfv5tgb', 'qazwsxedcrfvtgb',
)


def _char_classes(pw):
    """回傳用了幾種字元：小寫、大寫、數字、符號"""
    kinds = 0
    kinds += any(c.islower() for c in pw)
    kinds += any(c.isupper() for c in pw)
    kinds += any(c.isdigit() for c in pw)
    kinds += any(not c.isalnum() for c in pw)
    return kinds


def _is_sequence_or_repeat(pw):
    """整組密碼是連號、鍵盤順序，或幾乎只有同一個字元"""
    s = pw.lower()
    if len(set(s)) <= 2:
        return True
    for seq in _SEQUENCES:
        if s in seq or s in seq[::-1]:
            return True
    return False


def _account_key(account):
    """取出帳號中可以拿來比對的部分：Email 取 @ 前面，學號或帳號直接用"""
    if not account:
        return ''
    key = str(account).split('@')[0].strip().lower()
    return key if len(key) >= 3 else ''


def evaluate(pw, account=None):
    """評估密碼強度。回傳 {level, label, checks}，checks 給畫面顯示檢查清單用。"""
    pw = pw or ''
    key = _account_key(account)
    lowered = pw.lower()

    common = lowered in COMMON_PASSWORDS
    sequence = len(pw) >= 1 and _is_sequence_or_repeat(pw)
    has_account = bool(key) and key in lowered
    kinds = _char_classes(pw)

    if len(pw) < MIN_LENGTH:
        level = 'too_short'
    elif common or sequence or has_account or kinds < 2:
        level = 'weak'
    elif len(pw) >= STRONG_LENGTH and kinds >= 3:
        level = 'strong'
    else:
        level = 'medium'

    checks = [
        {'key': 'length', 'label': '至少 %d 個字元' % MIN_LENGTH, 'ok': len(pw) >= MIN_LENGTH},
        {'key': 'variety', 'label': '包含兩種以上字元（大寫、小寫、數字、符號）', 'ok': kinds >= 2},
        {'key': 'not_common', 'label': '不是常見密碼或連續字元', 'ok': bool(pw) and not (common or sequence)},
        {'key': 'not_account', 'label': '不包含帳號名稱', 'ok': not has_account},
        {'key': 'long', 'label': '%d 個字元以上更安全' % STRONG_LENGTH, 'ok': len(pw) >= STRONG_LENGTH},
    ]
    return {'level': level, 'label': LEVEL_LABELS[level], 'checks': checks}


def validate(pw, account=None, require_medium=False, old_hash=None):
    """檢查密碼能不能用。可以用回傳 None，不行回傳要顯示給使用者的錯誤訊息。

    require_medium：老師、管理者與老師建立的學生帳號要至少「中」
    old_hash：改密碼時帶入目前密碼的雜湊，新密碼不能跟舊的一樣
    """
    pw = pw or ''
    result = evaluate(pw, account)
    level = result['level']

    if level == 'too_short':
        return '密碼至少需要 %d 個字元' % MIN_LENGTH

    if require_medium and level == 'weak':
        failed = {c['key'] for c in result['checks'] if not c['ok']}
        if 'not_account' in failed:
            return '密碼不能包含帳號名稱'
        if 'not_common' in failed:
            return '密碼太容易被猜到（常見密碼或連續字元），請換一組'
        return '密碼強度不足，請混合使用英文、數字或符號等兩種以上字元'

    if old_hash and check_password_hash(old_hash, pw):
        return '新密碼不可與目前密碼相同'

    return None
