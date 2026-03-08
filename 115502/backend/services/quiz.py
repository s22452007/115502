from flask import Blueprint, request, jsonify
from utils.db import db

# 建立 Blueprint，方便管理路由
quiz_bp = Blueprint('quiz', __name__)

# 定義資料表模型 (未來這段也可以獨立移到 models/user.py 裡)
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    japanese_level = db.Column(db.String(50), nullable=True) # 儲存日語程度

@quiz_bp.route('/submit', methods=['POST'])
def submit_quiz():
    data = request.get_json()
    score = data.get('score')
    user_id = data.get('user_id') # 假設前端有傳送目前登入的使用者 ID

    if score is None or user_id is None:
        return jsonify({"error": "缺少分數或使用者 ID"}), 400

    # 1. 後端判斷邏輯 (把原本 Flutter 裡的邏輯搬過來了！)
    if score >= 80:
        level_name = '中級對話(N3以上)'
    elif score >= 60:
        level_name = '初級應用(N5、N4)'
    elif score >= 40:
        level_name = '入門新手'
    else:
        level_name = '超級新手'

    # 2. 儲存進資料庫
    user = User.query.get(user_id)
    if not user:
        # 為了測試方便，如果資料庫找不到這個使用者，我們就自動建一個假的
        user = User(id=user_id, username=f"test_user_{user_id}")
        db.session.add(user)
    
    # 更新該使用者的日語程度
    user.japanese_level = level_name
    db.session.commit()

    # 3. 回傳 JSON 結果給前端 Flutter
    return jsonify({
        "message": "測驗結果已成功儲存至資料庫",
        "score": score,
        "level": level_name
    }), 200