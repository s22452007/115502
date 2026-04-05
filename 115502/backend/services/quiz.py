# backend/services/quiz.py
from flask import Blueprint, request, jsonify
from utils.db import db
from models import User

quiz_bp = Blueprint('quiz', __name__)

@quiz_bp.route('/submit', methods=['POST'])
def submit_quiz():
    data = request.get_json()
    user_id = data.get('user_id')
    # 預期收到長度 10 的布林值陣列，例如: [True, True, False, True, False...]
    results = data.get('results', []) 

    if user_id is None:
        return jsonify({"error": "缺少使用者 ID"}), 400

    # ========================================
    # 🚀 核心：階梯式程度判定演算法 (Fail-Stop)
    # ========================================
    final_level = 'N5'  # 預設起點：所有人進來都是 N5

    # 確保前端有傳入完整的 10 題結果再進行判定
    if len(results) >= 10:
        # 晉級 N4 條件：答對 Q3 或 Q4 至少一題 (索引 2 或 3)
        if results[2] or results[3]:
            final_level = 'N4'
            
            # 晉級 N3 條件：在 N4 成立下，答對 Q5 或 Q6 至少一題 (索引 4 或 5)
            if results[4] or results[5]:
                final_level = 'N3'
                
                # 晉級 N2 條件：在 N3 成立下，答對 Q7 或 Q8 至少一題 (索引 6 或 7)
                if results[6] or results[7]:
                    final_level = 'N2'
                    
                    # 晉級 N1 條件：在 N2 成立下，答對 Q9 或 Q10 至少一題 (索引 8 或 9)
                    if results[8] or results[9]:
                        final_level = 'N1'

    # 尋找使用者並寫入資料庫
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者，請先登入或註冊"}), 404
    
    # 【資料庫寫入標準】：只存乾淨的代碼 ('N5', 'N4', 'N3', 'N2', 'N1')
    user.japanese_level = final_level
    db.session.commit()

    return jsonify({
        "message": "測驗結果已成功儲存至資料庫",
        "level": final_level  # 回傳給前端，讓前端轉換 UI 文字
    }), 200