import random

from flask import Blueprint, request, jsonify
from utils.db import db
from models import User, QuizQuestion

quiz_bp = Blueprint('quiz', __name__)

# 等級階梯：由低到高。程度測驗每級抽 2 題，升級測驗抽「高一級」的題目。
LEVEL_LADDER = ['N5', 'N4', 'N3', 'N2', 'N1']
PLACEMENT_PER_LEVEL = 2
UPGRADE_QUESTION_COUNT = 10   # 升級測驗題數（題庫不足時抽該等級全部）
UPGRADE_PASS_RATE = 0.7       # 答對率達 70% 即通過

# ----------------------------------------------------------------------
# 改考卷由後端負責：
#   原本題目連同正確答案一起送到 App，App 自己對答案後只回傳「對/錯」清單，
#   後端照單全收——自己送一個 [true] 就能 100% 通過升級，看網路請求也能直接看到答案。
#   現在出題時不附正確答案、選項順序每次打亂，App 只回傳「哪一題選了哪個選項」，
#   由後端對答案、檢查是不是完整的一份考卷。
# ----------------------------------------------------------------------


def _options(q):
    return [q.option_a, q.option_b, q.option_c, q.option_d]


def _correct_text(q):
    idx = 'ABCD'.find((q.correct_answer or 'A').strip().upper()[:1])
    return _options(q)[idx if idx >= 0 else 0]


def _serialize(q):
    opts = _options(q)
    random.shuffle(opts)  # 題庫裡正確答案大多是 A，不打亂的話一直選第一個就會過
    return {
        "id": q.id,
        # 只顯示階段名稱（如「第二階段：初級」），不帶 N5/N1：那只是參考分級，不代表真正的檢定程度
        "context": q.stage,
        "level_tag": q.level_tag,   # 內部分級，給程式判斷用，畫面不顯示
        "question": q.question,
        "options": opts,
    }


def _grade(answers):
    """把 App 送來的作答對答案。

    answers 格式：[{"id": 題目ID, "answer": 選的選項文字（選「我還沒學過這個」就是 null）}, ...]
    回傳 (題目清單, 每題對錯清單, 錯誤訊息)；同一題重複作答或題目不存在都算不合法的考卷。
    """
    if not isinstance(answers, list) or not answers:
        return None, None, "沒有作答結果"
    ids = []
    for a in answers:
        if not isinstance(a, dict):
            return None, None, "作答格式不正確"
        try:
            ids.append(int(a.get('id')))
        except (TypeError, ValueError):
            return None, None, "作答格式不正確"
    if len(set(ids)) != len(ids):
        return None, None, "同一題不能作答兩次"

    found = {q.id: q for q in QuizQuestion.query.filter(QuizQuestion.id.in_(ids)).all()}
    if len(found) != len(ids):
        return None, None, "作答裡有不存在的題目"

    questions = [found[i] for i in ids]
    results = [a.get('answer') is not None and str(a.get('answer')) == _correct_text(q)
               for a, q in zip(answers, questions)]
    return questions, results, None


def _next_level(current):
    """回傳比 current 高一級的等級；已是最高級則回傳 None"""
    if current not in LEVEL_LADDER:
        current = 'N5'  # 未設定程度者視為 N5
    idx = LEVEL_LADDER.index(current)
    if idx + 1 >= len(LEVEL_LADDER):
        return None  # 已達 N1，無法再升
    return LEVEL_LADDER[idx + 1]


def _pass_count(total):
    """通過門檻：答對率 70%（無條件進位，至少 1 題）"""
    return max(1, -(-total * 7 // 10))


# ========================================
# 🆕 1. 程度測驗出題：N5～N1 每級隨機抽 2 題，由淺入深
# ========================================
@quiz_bp.route('/questions', methods=['GET'])
def get_quiz_questions():
    final_questions = []
    for level in LEVEL_LADDER:
        sampled = (QuizQuestion.query.filter_by(level_tag=level)
                   .order_by(db.func.random()).limit(PLACEMENT_PER_LEVEL).all())
        if len(sampled) < PLACEMENT_PER_LEVEL:
            return jsonify({"error": "程度測驗題庫不足，請聯繫系統管理員"}), 503
        final_questions.extend(sampled)

    return jsonify({"questions": [_serialize(q) for q in final_questions]}), 200


# ========================================
# 🚀 2. 程度測驗判定（Fail-Stop）
# ========================================
@quiz_bp.route('/submit', methods=['POST'])
def submit_quiz():
    data = request.get_json() or {}
    user_id = data.get('user_id')
    if user_id is None:
        return jsonify({"error": "缺少使用者 ID"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    # 程度測驗只在剛註冊、還沒有程度時做一次；之後要往上升只能靠升級測驗，
    # 否則重做一次程度測驗就能跳過升級測驗。
    if user.japanese_level:
        return jsonify({"error": "你已經完成程度測驗了，想提升稱號請到「個人檔案」挑戰升級測驗"}), 409

    questions, results, err = _grade(data.get('answers'))
    if err:
        return jsonify({"error": err}), 400

    # 必須是完整的一份考卷：N5～N1 每級剛好 2 題
    per_level = {lv: [] for lv in LEVEL_LADDER}
    for q, ok in zip(questions, results):
        if q.level_tag not in per_level:
            return jsonify({"error": "作答題目不屬於程度測驗"}), 400
        per_level[q.level_tag].append(ok)
    if any(len(v) != PLACEMENT_PER_LEVEL for v in per_level.values()):
        return jsonify({"error": "請完成整份測驗再送出"}), 400

    # 一關一關往上爬：
    #   - N5 兩題至少要對 1 題，才開始往上判定（最簡單的都不會就從新手開始）
    #   - N4 以上每一關「兩題都答對」才算通過，有一關沒過就停在前一級
    # 原本每關只要對 1 題就過關，4 個選項亂猜每關也有快一半機率過，
    # 結果每關各對 1 題、總共只對 3 題就被判成 N2（商務菁英）。
    final_level = 'N5'
    if any(per_level['N5']):
        for level in LEVEL_LADDER[1:]:
            if not all(per_level[level]):
                break
            final_level = level

    # 【資料庫寫入標準】：只存乾淨的代碼 ('N5', 'N4', 'N3', 'N2', 'N1')
    user.japanese_level = final_level
    db.session.commit()

    return jsonify({
        "message": "測驗結果已儲存",
        "level": final_level,
        "correct": sum(results),
        "total": len(results),
    }), 200


# ========================================
# 🎓 3. 升級測驗（使用者自主挑戰更高一級）
# ========================================
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

    return jsonify({
        "current_level": current_level,
        "target_level": target_level,
        "total": len(questions),
        "pass_count": _pass_count(len(questions)),
        "questions": [_serialize(q) for q in questions],
    }), 200


@quiz_bp.route('/upgrade_submit', methods=['POST'])
def submit_upgrade_quiz():
    """
    送出升級測驗：後端對答案，答對率達門檻就升一級，否則維持原等級（不會降級）。
    """
    data = request.get_json() or {}
    user_id = data.get('user_id')

    if user_id is None:
        return jsonify({"error": "缺少使用者 ID"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    current_level = user.japanese_level or 'N5'
    target_level = _next_level(current_level)

    if target_level is None:
        return jsonify({"error": "已達最高等級，無法再升級"}), 400

    questions, results, err = _grade(data.get('answers'))
    if err:
        return jsonify({"error": err}), 400

    # 必須是一份完整的升級考卷：全部都是高一級的題目，題數跟出題時一樣
    # （避免只挑一兩題會的送出來就通過）
    if any(q.level_tag != target_level for q in questions):
        return jsonify({"error": "作答題目不是這次升級測驗的題目"}), 400
    expected = min(UPGRADE_QUESTION_COUNT, QuizQuestion.query.filter_by(level_tag=target_level).count())
    if len(questions) != expected:
        return jsonify({"error": "請完成整份測驗再送出"}), 400

    total = len(results)
    correct = sum(results)
    pass_count = _pass_count(total)
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
