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


# ========================================
# 🎓 3. 升級測驗（使用者自主挑戰更高一級）
# ========================================

# 等級階梯：由低到高
LEVEL_LADDER = ['N5', 'N4', 'N3', 'N2', 'N1']
UPGRADE_QUESTION_COUNT = 10   # 目標題數（題庫不足時會抽該等級全部）
UPGRADE_PASS_RATE = 0.7       # 答對率達 70% 即通過


def _next_level(current):
    """回傳比 current 高一級的等級；已是最高級或無法辨識則回傳 None"""
    if current not in LEVEL_LADDER:
        current = 'N5'  # 未設定程度者視為 N5
    idx = LEVEL_LADDER.index(current)
    if idx + 1 >= len(LEVEL_LADDER):
        return None  # 已達 N1，無法再升
    return LEVEL_LADDER[idx + 1]


@quiz_bp.route('/upgrade_questions', methods=['GET'])
def get_upgrade_questions():
    """
    取得升級測驗題目：隨機抽出「比使用者目前程度高一級」的題目。
    題庫不足 10 題時，抽出該等級全部題目。
    """
    user_id = request.args.get('user_id', type=int)
    if not user_id:
        return jsonify({"error": "缺少 user_id"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    current_level = user.japanese_level or 'N5'
    target_level = _next_level(current_level)

    if target_level is None:
        return jsonify({
            "error": "你已經是「日語大師」，沒有更高的挑戰囉！",
            "current_level": current_level,
            "is_max_level": True,
        }), 400

    questions = (QuizQuestion.query
                 .filter_by(level_tag=target_level)
                 .order_by(db.func.random())
                 .limit(UPGRADE_QUESTION_COUNT)
                 .all())

    if not questions:
        return jsonify({
            "error": "這個等級的題庫還在準備中，請稍後再來挑戰！",
            "current_level": current_level,
            "target_level": target_level,
        }), 404

    ans_map = {'A': 0, 'B': 1, 'C': 2, 'D': 3}
    # context 不帶 level_tag：對使用者一律用稱號呈現程度，不顯示 N5/N1 代碼
    result_list = [{
        "id": q.id,
        "context": q.stage,
        "question": q.question,
        "options": [q.option_a, q.option_b, q.option_c, q.option_d],
        "correctIndex": ans_map.get(q.correct_answer.upper(), 0),
    } for q in questions]

    # 通過門檻：答對率 70%（無條件進位，至少 1 題）
    pass_count = max(1, -(-len(result_list) * 7 // 10))

    return jsonify({
        "current_level": current_level,
        "target_level": target_level,
        "total": len(result_list),
        "pass_count": pass_count,
        "questions": result_list,
    }), 200


@quiz_bp.route('/upgrade_submit', methods=['POST'])
def submit_upgrade_quiz():
    """
    送出升級測驗結果：答對率達門檻就升一級，否則維持原等級。
    """
    data = request.get_json() or {}
    user_id = data.get('user_id')
    results = data.get('results', [])

    if user_id is None:
        return jsonify({"error": "缺少使用者 ID"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    current_level = user.japanese_level or 'N5'
    target_level = _next_level(current_level)

    if target_level is None:
        return jsonify({"error": "已達最高等級，無法再升級"}), 400

    total = len(results)
    if total == 0:
        return jsonify({"error": "沒有作答結果"}), 400

    correct = sum(1 for r in results if r)
    pass_count = max(1, -(-total * 7 // 10))
    passed = correct >= pass_count

    if passed:
        user.japanese_level = target_level
        db.session.commit()

    return jsonify({
        "passed": passed,
        "correct": correct,
        "total": total,
        "pass_count": pass_count,
        "level": user.japanese_level,       # 升級後（或維持）的等級
        "previous_level": current_level,
        "target_level": target_level,
    }), 200