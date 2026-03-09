from flask import Blueprint, request, jsonify
from utils.db import db
from models import User # 改由 models 匯入資料表

quiz_bp = Blueprint('quiz', __name__)

@quiz_bp.route('/submit', methods=['POST'])
def submit_quiz():
    data = request.get_json()
    score = data.get('score')
    user_id = data.get('user_id') 

    if score is None or user_id is None:
        return jsonify({"error": "缺少分數或使用者 ID"}), 400

    if score >= 80:
        level_name = '中級對話(N3以上)'
    elif score >= 60:
        level_name = '初級應用(N5、N4)'
    elif score >= 40:
        level_name = '入門新手'
    else:
        level_name = '超級新手'

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者，請先登入或註冊"}), 404
    
    # 更新該使用者的日語程度
    user.japanese_level = level_name
    db.session.commit()

    return jsonify({
        "message": "測驗結果已成功儲存至資料庫",
        "score": score,
        "level": level_name
    }), 200