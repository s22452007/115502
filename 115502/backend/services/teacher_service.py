import secrets
import string
from datetime import datetime
from utils.db import db
from models import (
    User, Classroom, ClassroomMember, Assignment, AssignmentSubmission,
    TaskType, SubmissionStatus, AccountType,
    Article, SentencePracticeRecord, ArticleProgress, ScoreRecord
)

# 排除易看錯字元：0, O, 1, I, L
SAFE_CODE_CHARS = ''.join(c for c in string.ascii_uppercase + string.digits if c not in '01OIL')


def generate_unique_join_code(length=6):
    """生成唯一的 6 碼大寫防混淆班級隨機碼。"""
    while True:
        code = ''.join(secrets.choice(SAFE_CODE_CHARS) for _ in range(length))
        if not Classroom.query.filter_by(join_code=code).first():
            return code


def get_or_create_teacher_user(admin_username):
    """確保後台管理員在 User 表中具備對應的 Teacher 帳號，以滿足外鍵關聯。"""
    if not admin_username:
        admin_username = 'teacher'
    user = User.query.filter_by(username=admin_username).first()
    if not user:
        # 嘗試以 email 找找看
        user = User.query.filter_by(email=f"{admin_username}@teacher.edu.tw").first()
    if not user:
        from werkzeug.security import generate_password_hash
        user = User(
            username=admin_username,
            email=f"{admin_username}@teacher.edu.tw",
            password_hash=generate_password_hash('teacher123'),
            account_type=AccountType.TEACHER,
            created_at=datetime.utcnow(),
        )
        db.session.add(user)
        db.session.commit()
    return user.id


def create_classroom(teacher_id, name, description=None):
    """建立新班級並自動生成唯一隨機碼。"""
    join_code = generate_unique_join_code()
    classroom = Classroom(
        teacher_id=teacher_id,
        name=name.strip(),
        description=description.strip() if description else '',
        join_code=join_code,
        is_open=True,
        is_archived=False,
        created_at=datetime.utcnow()
    )
    db.session.add(classroom)
    db.session.commit()
    return classroom


def regenerate_join_code(classroom_id):
    """重新生成班級隨機碼。"""
    classroom = Classroom.query.get(classroom_id)
    if not classroom:
        return None
    classroom.join_code = generate_unique_join_code()
    db.session.commit()
    return classroom.join_code


def toggle_classroom_open(classroom_id):
    """切換班級是否開放加入。"""
    classroom = Classroom.query.get(classroom_id)
    if not classroom:
        return None
    classroom.is_open = not classroom.is_open
    db.session.commit()
    return classroom.is_open


def get_classroom_list():
    """取得所有未封存的班級資訊列表（含成員數、作業數）。"""
    classrooms = Classroom.query.filter_by(is_archived=False).order_by(Classroom.created_at.desc()).all()
    result = []
    for c in classrooms:
        teacher = User.query.get(c.teacher_id)
        member_count = ClassroomMember.query.filter_by(classroom_id=c.id).count()
        assignment_count = Assignment.query.filter_by(classroom_id=c.id).count()
        result.append({
            'id': c.id,
            'name': c.name,
            'description': c.description or '',
            'join_code': c.join_code,
            'is_open': c.is_open,
            'teacher_name': teacher.username if teacher else '教師',
            'member_count': member_count,
            'assignment_count': assignment_count,
            'created_at': c.created_at.strftime('%Y-%m-%d %H:%M') if c.created_at else ''
        })
    return result


def get_classroom_student_stats(classroom_id):
    """依班級統計所有學生的學習狀況與作業完成情形。"""
    classroom = Classroom.query.get(classroom_id)
    if not classroom:
        return None

    members = ClassroomMember.query.filter_by(classroom_id=classroom_id).all()
    assignments = Assignment.query.filter_by(classroom_id=classroom_id, is_published=True).all()
    total_assignments = len(assignments)
    assignment_ids = [a.id for a in assignments]

    student_stats = []
    total_completed_all = 0

    for m in members:
        student = User.query.get(m.student_id)
        if not student:
            continue

        # 1. 班級作業繳交狀況
        submissions = AssignmentSubmission.query.filter(
            AssignmentSubmission.assignment_id.in_(assignment_ids),
            AssignmentSubmission.student_id == student.id
        ).all() if assignment_ids else []

        completed_count = sum(1 for s in submissions if s.status in (SubmissionStatus.SUBMITTED, SubmissionStatus.GRADED))
        total_completed_all += completed_count

        scores = [s.score for s in submissions if s.score is not None]
        avg_score = round(sum(scores) / len(scores), 1) if scores else None

        # 2. 造句練習統計 (SentencePracticeRecord)
        sentence_records = SentencePracticeRecord.query.filter_by(user_id=student.id).all()
        sentence_count = len(sentence_records)
        sentence_scores = [r.score for r in sentence_records if r.score is not None]
        sentence_avg = round(sum(sentence_scores) / len(sentence_scores), 1) if sentence_scores else None

        # 3. 文章閱讀與測驗統計 (ArticleProgress & ScoreRecord)
        article_records = ArticleProgress.query.filter_by(user_id=student.id).all()
        article_count = len(article_records)
        score_records = ScoreRecord.query.filter_by(user_id=student.id).all()
        quiz_scores = [r.score for r in score_records if r.score is not None]
        quiz_avg = round(sum(quiz_scores) / len(quiz_scores), 1) if quiz_scores else None

        student_stats.append({
            'student_id': student.id,
            'username': student.username or '未命名',
            'display_name': m.display_name or student.username or '學生',
            'email': student.email or '',
            'joined_at': m.joined_at.strftime('%Y-%m-%d') if m.joined_at else '',
            'completed_assignments': completed_count,
            'total_assignments': total_assignments,
            'completion_rate': round(completed_count / total_assignments * 100, 1) if total_assignments > 0 else 0,
            'avg_assignment_score': avg_score,
            'sentence_count': sentence_count,
            'sentence_avg_score': sentence_avg,
            'article_count': article_count,
            'quiz_avg_score': quiz_avg,
        })

    # 班級整體大數據
    total_students = len(student_stats)
    total_possible = total_students * total_assignments if total_students and total_assignments else 0
    overall_completion_rate = round(total_completed_all / total_possible * 100, 1) if total_possible > 0 else 0

    return {
        'classroom': {
            'id': classroom.id,
            'name': classroom.name,
            'join_code': classroom.join_code,
            'is_open': classroom.is_open,
            'description': classroom.description or '',
        },
        'summary': {
            'total_students': total_students,
            'total_assignments': total_assignments,
            'overall_completion_rate': overall_completion_rate,
        },
        'students': student_stats
    }


def get_student_detail(student_id, classroom_id):
    """查詢單一學生在指定班級的詳細學習與作業歷程。"""
    student = User.query.get(student_id)
    if not student:
        return None

    assignments = Assignment.query.filter_by(classroom_id=classroom_id, is_published=True).all()
    assignments_data = []

    for a in assignments:
        sub = AssignmentSubmission.query.filter_by(assignment_id=a.id, student_id=student_id).first()
        assignments_data.append({
            'assignment_id': a.id,
            'title': a.title,
            'task_type': a.task_type,
            'due_at': a.due_at.strftime('%Y-%m-%d %H:%M') if a.due_at else '無截止日',
            'status': sub.status if sub else 'pending',
            'score': sub.score if sub else None,
            'teacher_comment': sub.teacher_comment if sub else None,
            'submitted_at': sub.submitted_at.strftime('%Y-%m-%d %H:%M') if sub and sub.submitted_at else None,
        })

    # 最新 10 筆造句
    sentences = SentencePracticeRecord.query.filter_by(user_id=student_id).order_by(
        SentencePracticeRecord.created_at.desc()
    ).limit(10).all()
    sentence_list = [{
        'grammar': s.grammar_point,
        'user_sentence': s.user_sentence,
        'corrected': s.corrected_sentence,
        'score': s.score,
        'feedback': s.ai_feedback,
        'created_at': s.created_at.strftime('%Y-%m-%d %H:%M') if s.created_at else ''
    } for s in sentences]

    # 最新 10 筆文章閱讀
    article_progress = ArticleProgress.query.filter_by(user_id=student_id).order_by(
        ArticleProgress.completed_at.desc()
    ).limit(10).all()
    article_list = []
    for ap in article_progress:
        art = Article.query.get(ap.article_id)
        article_list.append({
            'title': art.title if art else '未知文章',
            'level': art.level if art else '',
            'is_completed': ap.is_completed,
            'completed_at': ap.completed_at.strftime('%Y-%m-%d %H:%M') if ap.completed_at else ''
        })

    return {
        'student': {
            'id': student.id,
            'username': student.username,
            'email': student.email,
        },
        'assignments': assignments_data,
        'sentences': sentence_list,
        'articles': article_list
    }


def create_sentence_assignment(classroom_id, title, instructions, grammar_point, required_vocabs=None, pass_score=60, due_at=None):
    """建立造句挑戰作業。"""
    config = {
        'grammar_point': grammar_point.strip(),
        'required_vocabs': [v.strip() for v in required_vocabs if v.strip()] if required_vocabs else [],
        'pass_score': int(pass_score or 60)
    }
    assignment = Assignment(
        classroom_id=classroom_id,
        title=title.strip(),
        instructions=instructions.strip() if instructions else '',
        task_type=TaskType.SENTENCE,
        config=config,
        due_at=due_at,
        is_published=True,
        created_at=datetime.utcnow()
    )
    db.session.add(assignment)
    db.session.commit()
    return assignment


def create_article_assignment(classroom_id, title, instructions, article_id=None, new_article=None, has_quiz=False, questions=None, due_at=None):
    """建立文章閱讀作業（支援新建文章、選擇題與是非題出題）。"""
    # 1. 若是上傳全新文章
    if new_article:
        art = Article(
            title=new_article['title'].strip(),
            theme='edu',
            level=new_article.get('level', 'N3').strip(),
            content=new_article['content'].strip(),
            translation=new_article.get('translation', '').strip(),
            grammar_points=new_article.get('grammar_points', []),
            is_free=True,
            is_published=True,
            created_at=datetime.utcnow()
        )
        db.session.add(art)
        db.session.flush() # 取得 art.id
        article_id = art.id

    if not article_id:
        raise ValueError("必須指定文章或提供新文章資料")

    config = {
        'article_id': int(article_id),
        'has_quiz': bool(has_quiz),
        'questions': questions if has_quiz and questions else []
    }

    assignment = Assignment(
        classroom_id=classroom_id,
        title=title.strip(),
        instructions=instructions.strip() if instructions else '',
        task_type=TaskType.ARTICLE,
        config=config,
        due_at=due_at,
        is_published=True,
        created_at=datetime.utcnow()
    )
    db.session.add(assignment)
    db.session.commit()
    return assignment


def get_assignment_submissions_list(assignment_id):
    """取得指定作業在該班級的學生繳交與批閱名單。"""
    assignment = Assignment.query.get(assignment_id)
    if not assignment:
        return None

    classroom = Classroom.query.get(assignment.classroom_id)
    members = ClassroomMember.query.filter_by(classroom_id=assignment.classroom_id).all()

    submissions_map = {
        s.student_id: s for s in AssignmentSubmission.query.filter_by(assignment_id=assignment_id).all()
    }

    students_submissions = []
    submitted_count = 0

    for m in members:
        student = User.query.get(m.student_id)
        if not student:
            continue

        sub = submissions_map.get(student.id)
        is_submitted = sub is not None and sub.status in (SubmissionStatus.SUBMITTED, SubmissionStatus.GRADED)
        if is_submitted:
            submitted_count += 1

        submission_detail = None
        if sub and sub.result_ref_id:
            if assignment.task_type == TaskType.SENTENCE:
                record = SentencePracticeRecord.query.get(sub.result_ref_id)
                if record:
                    submission_detail = {
                        'type': 'sentence',
                        'user_sentence': record.user_sentence,
                        'corrected': record.corrected_sentence,
                        'ai_feedback': record.ai_feedback,
                        'ai_score': record.score,
                    }
            elif assignment.task_type == TaskType.ARTICLE:
                ap = ArticleProgress.query.get(sub.result_ref_id)
                submission_detail = {
                    'type': 'article',
                    'is_completed': ap.is_completed if ap else True,
                }

        students_submissions.append({
            'student_id': student.id,
            'username': student.username,
            'display_name': m.display_name or student.username,
            'email': student.email,
            'submission_id': sub.id if sub else None,
            'status': sub.status if sub else SubmissionStatus.PENDING,
            'score': sub.score if sub else None,
            'teacher_comment': sub.teacher_comment if sub else '',
            'attempt_count': sub.attempt_count if sub else 0,
            'submitted_at': sub.submitted_at.strftime('%Y-%m-%d %H:%M') if sub and sub.submitted_at else '尚未繳交',
            'detail': submission_detail
        })

    article_info = None
    if assignment.task_type == TaskType.ARTICLE and assignment.config:
        art_id = assignment.config.get('article_id')
        if art_id:
            art = Article.query.get(art_id)
            if art:
                article_info = {
                    'id': art.id,
                    'title': art.title,
                    'level': art.level,
                    'content': art.content,
                    'translation': art.translation,
                }

    return {
        'assignment': {
            'id': assignment.id,
            'classroom_id': classroom.id,
            'classroom_name': classroom.name,
            'title': assignment.title,
            'instructions': assignment.instructions,
            'task_type': assignment.task_type,
            'config': assignment.config or {},
            'due_at': assignment.due_at.strftime('%Y-%m-%d %H:%M') if assignment.due_at else '無截止日',
            'created_at': assignment.created_at.strftime('%Y-%m-%d %H:%M') if assignment.created_at else '',
        },
        'stats': {
            'total_students': len(members),
            'submitted_count': submitted_count,
            'pending_count': len(members) - submitted_count,
        },
        'article_info': article_info,
        'submissions': students_submissions
    }


def grade_submission(submission_id, score, teacher_comment=''):
    """批閱作業：儲存分數與教師評語。"""
    sub = AssignmentSubmission.query.get(submission_id)
    if not sub:
        return False
    if score is not None and str(score).strip() != '':
        sub.score = int(score)
    sub.teacher_comment = teacher_comment.strip() if teacher_comment else ''
    sub.status = SubmissionStatus.GRADED
    sub.updated_at = datetime.utcnow()
    db.session.commit()
    return True
