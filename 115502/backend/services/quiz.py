from flask import Blueprint, request, jsonify
from utils.db import db
from models import User, QuizQuestion

quiz_bp = Blueprint('quiz', __name__)

# ========================================
# 🆕 1. 隨機抽取 10 題測驗卷 API (智能防呆版)
# ========================================
@quiz_bp.route('/questions', methods=['GET'])
def get_quiz_questions():
    try:
        # 撈取所有題目並照 ID 排序 (也就是當初寫入的難易度順序)
        all_questions = QuizQuestion.query.order_by(QuizQuestion.id).all()
        final_questions = []

        # 智能判斷：題庫如果超過 10 題，才啟用「分級隨機抽題」
        if len(all_questions) > 10:
            # 配合你 seed.py 的實際難度標籤
            levels = ['超級新手', 'N5', 'N4', 'N3', 'N2', 'N1']
            for level in levels:
                # 使用 db.func.random() 安全隨機排序，每個難度抽 2 題
                sampled = QuizQuestion.query.filter_by(level_tag=level).order_by(db.func.random()).limit(2).all()
                final_questions.extend(sampled)
        else:
            # 如果題庫剛好只有 10 題，就直接全部照順序拿出來，確保「由簡入深」
            final_questions = all_questions

        # 轉換成前端看得懂的 JSON 格式
        result_list = []
        for q in final_questions:
            # 轉換正確答案字串為數字索引 (A->0, B->1, C->2, D->3)
            ans_map = {'A': 0, 'B': 1, 'C': 2, 'D': 3}
            correct_idx = ans_map.get(q.correct_answer.upper(), 0)
            
            result_list.append({
                "id": q.id,
                "context": f"{q.stage} ({q.level_tag})",
                "question": q.question,
                "options": [q.option_a, q.option_b, q.option_c, q.option_d],
                "correctIndex": correct_idx
            })

        # 回傳最終的 10 題
        return jsonify({"questions": result_list[:10]}), 200

    except Exception as e:
        print(f"題庫撈取發生錯誤: {e}")
        return jsonify({"error": str(e)}), 500


# ========================================
# 🚀 2. 階梯式程度判定演算法 (Fail-Stop)
# ========================================
@quiz_bp.route('/submit', methods=['POST'])
def submit_quiz():
    data = request.get_json()
    user_id = data.get('user_id')
    results = data.get('results', []) 

    if user_id is None:
        return jsonify({"error": "缺少使用者 ID"}), 400

    final_level = 'N5'  # 預設起點

    # 確保有完整 10 題結果再進行 Fail-Stop 判定
    if len(results) >= 10:
        if results[2] or results[3]:   # N4 條件
            final_level = 'N4'
            if results[4] or results[5]: # N3 條件
                final_level = 'N3'
                if results[6] or results[7]: # N2 條件
                    final_level = 'N2'
                    if results[8] or results[9]: # N1 條件
                        final_level = 'N1'

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404
    
    # 【資料庫寫入標準】：只存乾淨的代碼 ('N5', 'N4', 'N3', 'N2', 'N1')
    user.japanese_level = final_level
    db.session.commit()

    return jsonify({
        "message": "測驗結果已儲存",
        "level": final_level 
    }), 200