from utils.db import db

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False) # 儲存「加密後」的密碼
    japanese_level = db.Column(db.String(50), nullable=True)  # 儲存日語程度