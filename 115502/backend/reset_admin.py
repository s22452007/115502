from app import app
from utils.db import db
from models import Admin

with app.app_context():
    new_password = input("請輸入新密碼：").strip()
    if len(new_password) < 6:
        print("密碼至少需要 6 個字元")
    else:
        admin = Admin.query.filter_by(username='admin').first()
        if admin:
            admin.set_password(new_password)
            db.session.commit()
            print("✅ 密碼已重設")
        else:
            print("找不到 admin 帳號")
