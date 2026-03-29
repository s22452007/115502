# Python 內建標準庫
import random
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
