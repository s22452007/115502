# Python 內建標準庫
import random
import re
import string

# 本地端模組 (Local)
from models import User

# 用來產生 8 碼不重複的隨機交友 ID
def generate_friend_id():
    characters = string.ascii_uppercase + string.digits # 大寫英文字母 + 數字
    while True:
        # 隨機湊出 8 個字
        new_id = ''.join(random.choice(characters) for _ in range(8))
        # 檢查資料庫有沒有人已經用過這個 ID，沒有的話才回傳
        if not User.query.filter_by(friend_id=new_id).first():
            return new_id


# Email 至少要像 名稱@網域.後綴，避免打錯成「11」這種沒有 @ 的帳號
EMAIL_PATTERN = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')


def is_valid_email(email):
    return bool(email and EMAIL_PATTERN.match(email))


# 新帳號的預設暱稱：取 Email @ 前面那段，規則跟「修改暱稱」一樣（2～20 字、中英數底線）。
# 暱稱可以跟別人重複，所以不用再加 _2、_3。
def default_username(email):
    base = re.sub(r'[^一-鿿A-Za-z0-9_]', '', (email or '').split('@')[0])[:20]
    if len(base) < 2:
        base = (base + '_user')[:20]
    return base
