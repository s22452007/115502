"""校園教育版 —— 學生端的作業 API。

老師端（出題、批閱）由另一位同學負責，這個檔案只處理學生這一側：
看作業列表、看作業詳情、繳交。

繳交的設計：學生是在原本的功能裡作答（造句頁、拍照頁、AI 對話頁、閱讀頁），
作答結果照常寫進那些功能自己的表。繳交只是把那筆紀錄的 id 掛到作業上，
所以這裡要驗證三件事：
    1. 那筆紀錄真的屬於這個學生（不能交別人的）
    2. 紀錄類型對得上作業題型（不能用拍照紀錄交造句作業）
    3. 有照老師的要求做（對的文法、對的文章、夠多輪對話…）

核心邏輯寫在 submit_assignment()，而不是塞在 route 裡，
這樣各功能在作答完成時可以直接呼叫它自動繳交。
"""

from datetime import datetime

from flask import Blueprint, request, jsonify

from utils.db import db
from models import (
    User, Classroom, ClassroomMember, Assignment, AssignmentSubmission,
    TaskType, SubmissionStatus,
    SentencePracticeRecord, UserPhoto, ChatSession, ChatMessage, ArticleProgress,
)

student_assignment_bp = Blueprint('student_assignment', __name__)


# 各題型對應的作答紀錄表
RECORD_MODELS = {
    TaskType.SENTENCE: SentencePracticeRecord,
    TaskType.PHOTO: UserPhoto,
    TaskType.CHAT: ChatSession,
    TaskType.ARTICLE: ArticleProgress,
}

# 有 AI 自動給分的題型，繳交後直接算「已批閱」；其餘要等老師看
AUTO_GRADED_TYPES = (TaskType.SENTENCE, TaskType.ARTICLE)


# ==========================================
# 內部工具
# ==========================================

def _is_member(student_id, classroom_id):
    return ClassroomMember.query.filter_by(
        classroom_id=classroom_id, student_id=student_id
    ).first() is not None


def _visible_assignment(assignment_id, student_id):
    """取得學生看得到的作業；看不到就回傳 (None, 錯誤訊息, HTTP 狀態碼)。

    看不到的情況：作業不存在、還是草稿、教室已封存、學生不在這間教室。
    草稿和「不存在」回同一個訊息，不讓學生從錯誤訊息推測老師準備了什麼。
    """
    assignment = Assignment.query.get(assignment_id)
    if not assignment or not assignment.is_published:
        return None, "找不到這份作業", 404

    classroom = Classroom.query.get(assignment.classroom_id)
    if not classroom or classroom.is_archived:
        return None, "找不到這份作業", 404

    if not _is_member(student_id, assignment.classroom_id):
        return None, "你不在這份作業所屬的教室裡", 403

    return assignment, None, None


def _is_late(assignment, when=None):
    if not assignment.due_at:
        return False
    return (when or datetime.utcnow()) > assignment.due_at


def _check_requirements(assignment, record):
    """檢查作答紀錄有沒有照老師的要求做。回傳 (是否通過, 不通過的原因)。

    只擋「做錯題目」的情況（文法不對、文章不對、對話輪數不夠…）。
    分數低不擋 —— 認真做了但只拿 40 分仍然算有交，老師需要看到這些嘗試。
    """
    config = assignment.config or {}
    task_type = assignment.task_type

    if task_type == TaskType.SENTENCE:
        required_grammar = config.get('grammar_point')
        if required_grammar and record.grammar_point != required_grammar:
            return False, f"這份作業指定的文法是「{required_grammar}」"

        required_vocabs = config.get('required_vocabs') or []
        used = set(record.selected_vocabs or [])
        missing = [v for v in required_vocabs if v not in used]
        if missing:
            return False, f"還沒用到指定單字：{'、'.join(missing)}"

    elif task_type == TaskType.PHOTO:
        need = int(config.get('min_vocab_count') or 0)
        got = len(record.photo_vocabs or [])
        if got < need:
            return False, f"這份作業需要辨識出至少 {need} 個單字，這張照片只有 {got} 個"

    elif task_type == TaskType.CHAT:
        required_topic = config.get('topic')
        if required_topic and record.topic != required_topic:
            return False, f"這份作業指定的對話情境是「{required_topic}」"

        need = int(config.get('min_turns') or 0)
        # 只算學生自己說的話，AI 回覆不算輪數
        got = ChatMessage.query.filter_by(session_id=record.id, role='user').count()
        if got < need:
            return False, f"這份作業需要至少對話 {need} 輪，目前只有 {got} 輪"

    elif task_type == TaskType.ARTICLE:
        required_article = config.get('article_id')
        if required_article and record.article_id != int(required_article):
            return False, "這不是作業指定的文章"
        if not record.is_completed:
            return False, "文章還沒讀完"

    return True, None


def _record_score(task_type, record):
    """有 AI 分數的題型取出分數，其餘回傳 None（等老師給）。"""
    if task_type in AUTO_GRADED_TYPES:
        return record.score
    return None


def _submission_json(submission, assignment):
    if submission is None:
        return {
            "status": SubmissionStatus.PENDING,
            "score": None,
            "passed": None,
            "teacher_comment": None,
            "attempt_count": 0,
            "submitted_at": None,
            "is_late": False,
        }

    pass_score = (assignment.config or {}).get('pass_score')
    passed = None
    if submission.score is not None and pass_score is not None:
        passed = submission.score >= int(pass_score)

    return {
        "status": submission.status,
        "result_ref_id": submission.result_ref_id,
        "score": submission.score,
        "passed": passed,
        "teacher_comment": submission.teacher_comment,
        "attempt_count": submission.attempt_count or 0,
        "submitted_at": submission.submitted_at.isoformat() if submission.submitted_at else None,
        "is_late": _is_late(assignment, submission.submitted_at) if submission.submitted_at else False,
    }


def _assignment_json(assignment, submission=None, include_config=False):
    classroom = Classroom.query.get(assignment.classroom_id)
    data = {
        "assignment_id": assignment.id,
        "classroom_id": assignment.classroom_id,
        "classroom_name": classroom.name if classroom else None,
        "title": assignment.title,
        "task_type": assignment.task_type,
        "due_at": assignment.due_at.isoformat() if assignment.due_at else None,
        "is_overdue": _is_late(assignment) and (submission is None),
        "created_at": assignment.created_at.isoformat() if assignment.created_at else None,
        "submission": _submission_json(submission, assignment),
    }
    if include_config:
        # 詳情頁才需要題目參數與老師說明，列表頁不帶以減少傳輸量
        data["instructions"] = assignment.instructions
        data["config"] = assignment.config or {}
    return data


# ==========================================
# 繳交核心邏輯（第 5 步各功能會直接呼叫）
# ==========================================

def submit_assignment(student_id, assignment_id, result_ref_id):
    """把一筆作答紀錄繳交到作業上。回傳 (payload, HTTP 狀態碼)。

    重交規則：保留「分數最高的那一次」。練習型作業鼓勵學生再挑戰，
    不該因為第二次考差就把第一次的好成績蓋掉。沒有分數的題型（拍照、對話）
    則以最新一次為準，並把狀態改回「已繳交」讓老師重新看。
    """
    assignment, err, code = _visible_assignment(assignment_id, student_id)
    if err:
        return {"status": "not_found", "error": err}, code

    model = RECORD_MODELS.get(assignment.task_type)
    if model is None:
        return {"status": "invalid_task_type", "error": "作業題型設定有誤，請聯絡老師"}, 500

    record = model.query.get(result_ref_id) if result_ref_id else None
    # 紀錄不存在與「不是你的紀錄」回同一個訊息，不洩漏別人的紀錄是否存在
    if record is None or record.user_id != student_id:
        return {"status": "record_not_found", "error": "找不到這筆作答紀錄"}, 404

    ok, reason = _check_requirements(assignment, record)
    if not ok:
        return {"status": "requirement_not_met", "error": reason}, 422

    new_score = _record_score(assignment.task_type, record)
    new_status = (SubmissionStatus.GRADED
                  if assignment.task_type in AUTO_GRADED_TYPES
                  else SubmissionStatus.SUBMITTED)
    now = datetime.utcnow()

    submission = AssignmentSubmission.query.filter_by(
        assignment_id=assignment.id, student_id=student_id
    ).first()

    if submission is None:
        submission = AssignmentSubmission(
            assignment_id=assignment.id,
            student_id=student_id,
            result_ref_id=record.id,
            score=new_score,
            status=new_status,
            attempt_count=1,
            submitted_at=now,
        )
        db.session.add(submission)
        kept = True
    else:
        submission.attempt_count = (submission.attempt_count or 0) + 1
        if new_score is None:
            # 沒有分數的題型：以最新一次為準，讓老師重新批閱
            kept = True
        else:
            kept = submission.score is None or new_score > submission.score

        if kept:
            submission.result_ref_id = record.id
            submission.score = new_score
            submission.status = new_status
            submission.submitted_at = now

    db.session.commit()

    if submission.attempt_count == 1:
        message = "作業已繳交"
    elif kept:
        message = "已更新為這次的作答"
    else:
        message = f"已記錄這次嘗試，但保留你之前較高的分數（{submission.score} 分）"

    return {
        "status": "success",
        "message": message,
        "kept_this_attempt": kept,
        "is_late": _is_late(assignment, now),
        "assignment": _assignment_json(assignment, submission),
    }, 200


# ==========================================
# 路由
# ==========================================

@student_assignment_bp.route('/my/<int:user_id>', methods=['GET'])
def my_assignments(user_id):
    """學生所有教室的作業，合併成一個清單。

    可選參數：
        classroom_id  只看某一間教室
        status        pending / submitted / graded，只看某種狀態
    排序：還沒交的排前面，其中截止日近的優先；沒有截止日的排在有截止日的後面。
    """
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    classroom_ids = [m.classroom_id for m in
                     ClassroomMember.query.filter_by(student_id=user_id).all()]

    filter_classroom = request.args.get('classroom_id', type=int)
    if filter_classroom is not None:
        if filter_classroom not in classroom_ids:
            return jsonify({"error": "你不在這個教室裡"}), 403
        classroom_ids = [filter_classroom]

    if not classroom_ids:
        return jsonify({"status": "success", "count": 0, "assignments": []}), 200

    active_classroom_ids = [c.id for c in Classroom.query.filter(
        Classroom.id.in_(classroom_ids), Classroom.is_archived.isnot(True)
    ).all()]

    assignments = Assignment.query.filter(
        Assignment.classroom_id.in_(active_classroom_ids),
        Assignment.is_published.is_(True),
    ).all()

    submissions = {
        s.assignment_id: s for s in AssignmentSubmission.query.filter(
            AssignmentSubmission.student_id == user_id,
            AssignmentSubmission.assignment_id.in_([a.id for a in assignments] or [0]),
        ).all()
    }

    filter_status = request.args.get('status')
    result = []
    for a in assignments:
        item = _assignment_json(a, submissions.get(a.id))
        if filter_status and item["submission"]["status"] != filter_status:
            continue
        result.append(item)

    def sort_key(item):
        pending = item["submission"]["status"] == SubmissionStatus.PENDING
        due = item["due_at"] or '9999'
        return (0 if pending else 1, due)

    result.sort(key=sort_key)

    return jsonify({
        "status": "success",
        "count": len(result),
        "pending_count": sum(1 for r in result
                             if r["submission"]["status"] == SubmissionStatus.PENDING),
        "assignments": result,
    }), 200


@student_assignment_bp.route('/<int:assignment_id>', methods=['GET'])
def assignment_detail(assignment_id):
    """作業詳情：老師說明、題目參數，以及學生自己的繳交狀態。"""
    user_id = request.args.get('user_id', type=int)
    if not user_id:
        return jsonify({"error": "缺少使用者 ID"}), 400

    assignment, err, code = _visible_assignment(assignment_id, user_id)
    if err:
        return jsonify({"error": err}), code

    submission = AssignmentSubmission.query.filter_by(
        assignment_id=assignment.id, student_id=user_id
    ).first()

    return jsonify({
        "status": "success",
        "assignment": _assignment_json(assignment, submission, include_config=True),
    }), 200


@student_assignment_bp.route('/submit', methods=['POST'])
def submit():
    """手動繳交：前端在學生完成作答後，帶著作答紀錄的 id 來交。"""
    data = request.get_json() or {}
    user_id = data.get('user_id')
    assignment_id = data.get('assignment_id')
    result_ref_id = data.get('result_ref_id')

    if not user_id or not assignment_id or not result_ref_id:
        return jsonify({"error": "缺少使用者 ID、作業 ID 或作答紀錄 ID"}), 400

    payload, code = submit_assignment(int(user_id), int(assignment_id), int(result_ref_id))
    return jsonify(payload), code
