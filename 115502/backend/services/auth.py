from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from utils.db import db
from models import User

# 建立 auth 的 Blueprint
auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({"error": "請填寫 Email 與密碼"}), 400

    # 檢查是否已經被註冊過
    if User.query.filter_by(email=email).first():
        return jsonify({"error": "這個 Email 已經註冊過囉！"}), 400

    # 將密碼加密後，存入資料庫
    hashed_pw = generate_password_hash(password)
    new_user = User(email=email, password_hash=hashed_pw)
    
    db.session.add(new_user)
    db.session.commit()

    return jsonify({"message": "註冊成功！", "user_id": new_user.id}), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    # 去資料庫找這個 Email 的使用者
    user = User.query.filter_by(email=email).first()

    # 檢查帳號是否存在，且「解密後的密碼」是否與輸入的相符
    if user and check_password_hash(user.password_hash, password):
        return jsonify({
            "message": "登入成功！",
            "user_id": user.id,
            "email": user.email,
            "japanese_level": user.japanese_level
        }), 200
    else:
        return jsonify({"error": "Email 或密碼錯誤"}), 401