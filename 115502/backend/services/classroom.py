"""校園教育版 —— 學生端的教室 API。

老師端（建立教室、產生 join_code、管理成員）由另一位同學負責，
這個檔案只處理學生這一側：用代碼加入、看自己加入了哪些教室、看班級公告、退出教室。

join_code 的產生規則在老師端，這裡不產生、只負責比對，
但必須容忍學生手動輸入的各種寫法（小寫、前後空白、中間的空格或連字號）。
"""

from datetime import datetime

from flask import Blueprint, request, jsonify

from utils.db import db
from utils.account_helper import is_edu_student
from models import User, Classroom, ClassroomMember, Assignment, ClassroomAnnouncement
from services.student_assignment import tw_iso

classroom_bp = Blueprint('classroom', __name__)


def normalize_join_code(raw):
    """把學生輸入的教室代碼正規化成資料庫裡的格式。

    學生是用手打的，實際會收到各種寫法：
        '  abc123 '  → 'ABC123'
        'abc-123'    → 'ABC123'
        'abc 123'    → 'ABC123'
    老師端產生的碼一律是全大寫英數，所以這裡去掉所有非英數字元再轉大寫。
    """
    if not raw:
        return ''
    return ''.join(ch for ch in str(raw) if ch.isalnum()).upper()


def _classroom_brief(classroom, member=None):
    """回傳教室的基本資料。teacher 可能已被刪除，所以要防呆。"""
    teacher = User.query.get(classroom.teacher_id)
    data = {
        "classroom_id": classroom.id,
        "name": classroom.name,
        "description": classroom.description,
        "join_code": classroom.join_code,
        "is_open": bool(classroom.is_open),
        "teacher_name": (teacher.username or teacher.email) if teacher else '（老師已離開）',
        "member_count": ClassroomMember.query.filter_by(classroom_id=classroom.id).count(),
    }
    if member is not None:
        data["joined_at"] = member.joined_at.isoformat() if member.joined_at else None
        data["display_name"] = member.display_name
    return data


@classroom_bp.route('/preview', methods=['GET'])
def preview_classroom():
    """輸入代碼後、真正加入前，先讓學生確認是不是這一間。

    避免學生打錯一個字就加進別的班級，事後還要老師手動移除。
    """
    code = normalize_join_code(request.args.get('join_code'))
    if not code:
        return jsonify({"error": "請輸入教室代碼"}), 400

    classroom = Classroom.query.filter_by(join_code=code).first()
    if not classroom or classroom.is_archived:
        return jsonify({"error": "找不到這個教室代碼，請再確認一次"}), 404

    return jsonify({
        "status": "success",
        "classroom": _classroom_brief(classroom),
    }), 200


@classroom_bp.route('/join', methods=['POST'])
def join_classroom():
    """學生用代碼加入教室。一個學生可以同時加入多間。"""
    data = request.get_json() or {}
    user_id = data.get('user_id')
    code = normalize_join_code(data.get('join_code'))

    if not user_id:
        return jsonify({"error": "缺少使用者 ID"}), 400
    if not code:
        return jsonify({"error": "請輸入教室代碼"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    # 只有教育版的學生帳號能加入教室。一般版帳號沒有老師、沒有作業，
    # 讓它加進來只會讓老師的名單出現查不到來歷的人。
    if not is_edu_student(user):
        return jsonify({
            "status": "not_student",
            "error": "只有校園教育版的學生帳號可以加入教室",
        }), 403

    classroom = Classroom.query.filter_by(join_code=code).first()
    if not classroom or classroom.is_archived:
        return jsonify({
            "status": "code_not_found",
            "error": "找不到這個教室代碼，請再確認一次",
        }), 404

    # 已經在這間教室裡：直接當成成功，不要報錯。
    # 學生按兩次送出、或從舊畫面重送都會走到這裡，報錯只會讓他困惑。
    existing = ClassroomMember.query.filter_by(
        classroom_id=classroom.id, student_id=user_id
    ).first()
    if existing:
        return jsonify({
            "status": "already_joined",
            "message": f"你已經在「{classroom.name}」裡了",
            "classroom": _classroom_brief(classroom, existing),
        }), 200

    # 老師關閉加入之後才來的人要擋掉，但已經在裡面的成員不受影響
    # （所以這個檢查放在 already_joined 之後）。
    if not classroom.is_open:
        return jsonify({
            "status": "classroom_closed",
            "error": f"「{classroom.name}」已經關閉加入，請聯絡老師",
        }), 403

    member = ClassroomMember(
        classroom_id=classroom.id,
        student_id=user_id,
        # 預設用暱稱讓老師認得出是誰，之後老師可以改成座號或真名
        display_name=user.username or user.email,
        joined_at=datetime.utcnow(),
    )
    db.session.add(member)
    db.session.commit()

    return jsonify({
        "status": "success",
        "message": f"已加入「{classroom.name}」",
        "classroom": _classroom_brief(classroom, member),
    }), 201


@classroom_bp.route('/my/<int:user_id>', methods=['GET'])
def my_classrooms(user_id):
    """學生加入的所有教室，附上每間還沒完成的作業數。"""
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    members = ClassroomMember.query.filter_by(student_id=user_id).all()

    result = []
    for member in members:
        classroom = Classroom.query.get(member.classroom_id)
        if not classroom or classroom.is_archived:
            continue  # 老師已封存的教室不顯示

        brief = _classroom_brief(classroom, member)
        brief["assignment_count"] = Assignment.query.filter_by(
            classroom_id=classroom.id, is_published=True
        ).count()
        brief["unread_count"] = _unread_announcements(classroom.id, member)
        result.append(brief)

    result.sort(key=lambda c: c["joined_at"] or '', reverse=True)

    return jsonify({
        "status": "success",
        "count": len(result),
        "classrooms": result,
    }), 200


def _seen_since(member):
    """比這個時間新的公告算未讀；還沒打開過公告頁（None）就是全部未讀。

    不從加入班級算起：老師常常先建班、發公告，再從名冊加學生，
    那些公告學生一則都還沒看過，不能因為發得比較早就當成已讀。
    """
    return member.notice_seen_at


def _unread_announcements(classroom_id, member):
    q = ClassroomAnnouncement.query.filter_by(classroom_id=classroom_id)
    since = _seen_since(member)
    if since:
        q = q.filter(ClassroomAnnouncement.created_at > since)
    return q.count()


@classroom_bp.route('/<int:classroom_id>/announcements', methods=['GET'])
def classroom_announcements(classroom_id):
    """教室公告，新的在前。學生打開公告頁就算看過，回傳後這班的公告都標成已讀。

    出作業時自動發的公告會帶 assignment_id，前端可以直接點進作業；
    作業後來被下架的話不給 assignment_id，避免點進去才發現找不到。
    """
    user_id = request.args.get('user_id', type=int)
    if not user_id:
        return jsonify({"error": "缺少使用者 ID"}), 400

    classroom = Classroom.query.get(classroom_id)
    member = ClassroomMember.query.filter_by(classroom_id=classroom_id, student_id=user_id).first()
    if not classroom or classroom.is_archived or not member:
        return jsonify({"error": "找不到這個教室"}), 404

    since = _seen_since(member)
    rows = ClassroomAnnouncement.query.filter_by(classroom_id=classroom_id) \
        .order_by(ClassroomAnnouncement.created_at.desc()).limit(100).all()
    published = {a.id for a in Assignment.query.filter(
        Assignment.id.in_([r.assignment_id for r in rows if r.assignment_id] or [0]),
        Assignment.is_published.is_(True),
    )}
    announcements = [{
        "announcement_id": r.id,
        "title": r.title,
        "content": r.content or '',
        "assignment_id": r.assignment_id if r.assignment_id in published else None,
        "created_at": tw_iso(r.created_at),     # 台灣時間，前端直接顯示
        "updated_at": tw_iso(r.updated_at),
        "is_new": since is None or (r.created_at is not None and r.created_at > since),
    } for r in rows]

    member.notice_seen_at = datetime.utcnow()
    db.session.commit()

    return jsonify({
        "status": "success",
        "classroom": _classroom_brief(classroom, member),
        "announcements": announcements,
    }), 200


@classroom_bp.route('/leave', methods=['POST'])
def leave_classroom():
    """學生退出教室。

    只刪除成員關聯，作業繳交紀錄與學生自己的學習紀錄都保留 ——
    退出不該讓已經完成的作業成績消失，老師之後仍要查得到。
    """
    data = request.get_json() or {}
    user_id = data.get('user_id')
    classroom_id = data.get('classroom_id')

    if not user_id or not classroom_id:
        return jsonify({"error": "缺少使用者 ID 或教室 ID"}), 400

    member = ClassroomMember.query.filter_by(
        classroom_id=classroom_id, student_id=user_id
    ).first()
    if not member:
        return jsonify({"error": "你不在這個教室裡"}), 404

    db.session.delete(member)
    db.session.commit()

    return jsonify({"status": "success", "message": "已退出教室"}), 200
