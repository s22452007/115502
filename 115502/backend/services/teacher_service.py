import re
import secrets
import string
from datetime import datetime
from utils.db import db
from models import (
    User, Classroom, ClassroomMember, Assignment, AssignmentSubmission,
    TaskType, SubmissionStatus, AccountType,
    Article, SentencePracticeRecord, ArticleProgress, ScoreRecord,
    UserPhoto, ChatSession, ChatMessage, Dialect
)

# 對話內容存的是 App 用的標音格式 [漢字|かな]，老師後台改成「漢字（かな）」比較好讀
_FURIGANA_RE = re.compile(r'\[([^\[\]|]+)\|([^\[\]]+)\]')


def strip_furigana(text):
    return _FURIGANA_RE.sub(r'\1（\2）', text or '')


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


def get_classroom_list(teacher_id=None, archived=False):
    """取得班級資訊列表（含成員數、作業數）。

    teacher_id 有給時只回傳該老師自己的班級（後台老師登入用）；沒給就是全部。
    archived=False（預設）列使用中的班級，True 則列已封存的。
    """
    query = Classroom.query.filter(Classroom.is_archived.is_(True) if archived else Classroom.is_archived.isnot(True))
    if teacher_id is not None:
        query = query.filter_by(teacher_id=teacher_id)
    classrooms = query.order_by(Classroom.created_at.desc()).all()
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
            'is_archived': bool(c.is_archived),
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


def create_photo_assignment(classroom_id, title, instructions, theme='', min_vocab_count=3, due_at=None):
    """建立拍照學習作業。學生拍一張照片，AI 辨識出的單字數要達到門檻才算繳交。"""
    try:
        min_vocab_count = int(min_vocab_count or 0)
    except (TypeError, ValueError):
        min_vocab_count = 0
    config = {
        'theme': (theme or '').strip(),
        'min_vocab_count': max(min_vocab_count, 0),
    }
    assignment = Assignment(
        classroom_id=classroom_id,
        title=title.strip(),
        instructions=instructions.strip() if instructions else '',
        task_type=TaskType.PHOTO,
        config=config,
        due_at=due_at,
        is_published=True,
        created_at=datetime.utcnow()
    )
    db.session.add(assignment)
    db.session.commit()
    return assignment


def create_chat_assignment(classroom_id, title, instructions, topic, dialect_id=None, min_turns=6, due_at=None):
    """建立 AI 情境對話作業。App 會直接用 config['topic'] 開對話，所以繳交時 topic 一定對得上。"""
    topic = (topic or '').strip()
    if not topic:
        raise ValueError("對話作業必須指定情境主題")
    try:
        min_turns = int(min_turns or 0)
    except (TypeError, ValueError):
        min_turns = 0
    config = {
        'topic': topic,
        'dialect_id': int(dialect_id) if dialect_id else None,
        'min_turns': max(min_turns, 0),
    }
    assignment = Assignment(
        classroom_id=classroom_id,
        title=title.strip(),
        instructions=instructions.strip() if instructions else '',
        task_type=TaskType.CHAT,
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
            elif assignment.task_type == TaskType.PHOTO:
                photo = UserPhoto.query.get(sub.result_ref_id)
                if photo:
                    vocabs = []
                    for pv in photo.photo_vocabs:
                        if pv.vocab:
                            vocabs.append({
                                'word': pv.vocab.word,
                                'kana': pv.vocab.kana,
                                'meaning': pv.vocab.meaning,
                            })
                    submission_detail = {
                        'type': 'photo',
                        'image_path': photo.image_path,
                        'custom_title': photo.custom_title or '',
                        'scene_name': photo.scene.name if photo.scene else '',
                        'context_description': photo.context_description or '',
                        'vocabs': vocabs,
                    }
            elif assignment.task_type == TaskType.CHAT:
                chat = ChatSession.query.get(sub.result_ref_id)
                if chat:
                    messages = ChatMessage.query.filter_by(session_id=chat.id).order_by(ChatMessage.created_at, ChatMessage.id).all()
                    submission_detail = {
                        'type': 'chat',
                        'topic': chat.topic,
                        'character_name': chat.character_name or '',
                        'user_turns': sum(1 for m in messages if m.role == 'user'),
                        'messages': [{'role': m.role, 'content': strip_furigana(m.content)} for m in messages],
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

    dialect_name = None
    if assignment.task_type == TaskType.CHAT and assignment.config and assignment.config.get('dialect_id'):
        d = Dialect.query.get(assignment.config.get('dialect_id'))
        dialect_name = d.name if d else None

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
            'dialect_name': dialect_name,
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


# ==========================================
# 班級成績總表 / 學期成績
# ==========================================
TASK_TYPE_LABELS = {
    TaskType.SENTENCE: '造句',
    TaskType.PHOTO: '拍照',
    TaskType.CHAT: '對話',
    TaskType.ARTICLE: '閱讀',
}

DEFAULT_GRADE_CONFIG = {
    'assignment_weights': {},   # {"<assignment_id>": 權重}，沒設的作業視為 1
    'missing_as_zero': True,    # 缺交算 0 分；False 則缺交不列入平均
    'sentence_pct': 0,          # 造句練習均分占學期成績的 %
    'quiz_pct': 0,              # 文章測驗均分占學期成績的 %
}


def get_grade_config(classroom):
    """把 Classroom.grade_config 補上預設值，保證每個欄位都有、型別正確。"""
    raw = classroom.grade_config if isinstance(classroom.grade_config, dict) else {}
    cfg = {
        'assignment_weights': {},
        'missing_as_zero': bool(raw.get('missing_as_zero', DEFAULT_GRADE_CONFIG['missing_as_zero'])),
        'sentence_pct': _clamp_pct(raw.get('sentence_pct', 0)),
        'quiz_pct': _clamp_pct(raw.get('quiz_pct', 0)),
    }
    for key, value in (raw.get('assignment_weights') or {}).items():
        try:
            w = float(value)
        except (TypeError, ValueError):
            continue
        if w >= 0:
            cfg['assignment_weights'][str(key)] = w
    # 兩個自主練習加起來超過 100 就把後者砍到剩下的空間
    if cfg['sentence_pct'] + cfg['quiz_pct'] > 100:
        cfg['quiz_pct'] = 100 - cfg['sentence_pct']
    return cfg


def _clamp_pct(value):
    try:
        v = int(round(float(value)))
    except (TypeError, ValueError):
        return 0
    return max(0, min(100, v))


def _weighted_avg(pairs, missing_as_zero):
    """pairs：[(分數或 None, 權重)]。權重 <= 0 的不算；None 依 missing_as_zero 決定算 0 還是跳過。"""
    acc = 0.0
    total_w = 0.0
    for score, weight in pairs:
        if weight is None or weight <= 0:
            continue
        if score is None:
            if not missing_as_zero:
                continue
            score = 0
        acc += score * weight
        total_w += weight
    return round(acc / total_w, 1) if total_w else None


def _self_practice_avgs(student_id, since):
    """學生加入班級之後的造句、文章測驗均分。since 為 None 就全部計入。"""
    sq = SentencePracticeRecord.query.filter_by(user_id=student_id)
    qq = ScoreRecord.query.filter_by(user_id=student_id)
    if since:
        sq = sq.filter(SentencePracticeRecord.created_at >= since)
        qq = qq.filter(ScoreRecord.created_at >= since)
    s_scores = [r.score for r in sq.all() if r.score is not None]
    q_scores = [r.score for r in qq.all() if r.score is not None]
    return {
        'sentence_avg': round(sum(s_scores) / len(s_scores), 1) if s_scores else None,
        'sentence_count': len(s_scores),
        'quiz_avg': round(sum(q_scores) / len(q_scores), 1) if q_scores else None,
        'quiz_count': len(q_scores),
    }


def _cell_for(sub):
    """一格作業成績。status：missing 缺交 / ungraded 已交待批 / graded 有分數。"""
    if sub is None or sub.status == SubmissionStatus.PENDING:
        return {'score': None, 'status': 'missing', 'submission_id': sub.id if sub else None}
    if sub.score is None:
        return {'score': None, 'status': 'ungraded', 'submission_id': sub.id}
    return {'score': sub.score, 'status': 'graded', 'submission_id': sub.id}


def _compute_grades(assignments, cells, cfg, practice):
    """回傳 (作業加權平均, 學期成績)。
    已交但還沒分數的作業不算缺交、不列入平均；真正缺交才依 missing_as_zero 處理。"""
    pairs = []
    for a in assignments:
        cell = cells.get(a.id) or {'score': None, 'status': 'missing'}
        weight = cfg['assignment_weights'].get(str(a.id), 1.0)
        if cell['status'] == 'ungraded':
            continue
        pairs.append((cell['score'], weight))
    assignment_avg = _weighted_avg(pairs, cfg['missing_as_zero'])

    a_pct = 100 - cfg['sentence_pct'] - cfg['quiz_pct']
    parts = [
        (practice['sentence_avg'], cfg['sentence_pct']),
        (practice['quiz_avg'], cfg['quiz_pct']),
    ]
    # 班上還沒有任何作業時，作業這塊不佔分，避免全班學期成績被算成 0
    if assignments:
        parts.insert(0, (assignment_avg, a_pct))
    final = _weighted_avg(parts, cfg['missing_as_zero'])
    return assignment_avg, final


def get_gradebook(classroom_id):
    """班級成績總表：每位學生 × 每份作業的分數，加上自主練習均分與依權重算出的學期成績。"""
    classroom = Classroom.query.get(classroom_id)
    if not classroom:
        return None
    cfg = get_grade_config(classroom)

    assignments = Assignment.query.filter_by(classroom_id=classroom_id, is_published=True) \
        .order_by(Assignment.created_at.asc()).all()
    assignment_ids = [a.id for a in assignments]
    members = ClassroomMember.query.filter_by(classroom_id=classroom_id).all()

    subs = AssignmentSubmission.query.filter(AssignmentSubmission.assignment_id.in_(assignment_ids)).all() \
        if assignment_ids else []
    sub_map = {(s.assignment_id, s.student_id): s for s in subs}

    students = []
    for m in members:
        student = User.query.get(m.student_id)
        if not student:
            continue
        cells = {a.id: _cell_for(sub_map.get((a.id, student.id))) for a in assignments}
        practice = _self_practice_avgs(student.id, m.joined_at)
        assignment_avg, final = _compute_grades(assignments, cells, cfg, practice)
        students.append({
            'student_id': student.id,
            'display_name': m.display_name or student.username or '學生',
            'username': student.username or '',
            'cells': cells,
            'assignment_avg': assignment_avg,
            'final': final,
            **practice,
        })
    students.sort(key=lambda s: s['display_name'])

    assignment_rows = []
    for a in assignments:
        graded = [s['cells'][a.id]['score'] for s in students if s['cells'][a.id]['status'] == 'graded']
        missing = sum(1 for s in students if s['cells'][a.id]['status'] == 'missing')
        assignment_rows.append({
            'id': a.id,
            'title': a.title,
            'task_type': a.task_type,
            'type_label': TASK_TYPE_LABELS.get(a.task_type, a.task_type),
            'weight': cfg['assignment_weights'].get(str(a.id), 1.0),
            'due_at': a.due_at.strftime('%m/%d') if a.due_at else '',
            'class_avg': round(sum(graded) / len(graded), 1) if graded else None,
            'graded_count': len(graded),
            'missing_count': missing,
        })

    finals = [s['final'] for s in students if s['final'] is not None]
    return {
        'classroom': {'id': classroom.id, 'name': classroom.name, 'join_code': classroom.join_code},
        'config': cfg,
        'assignment_pct': 100 - cfg['sentence_pct'] - cfg['quiz_pct'],
        'assignments': assignment_rows,
        'students': students,
        'summary': {
            'student_count': len(students),
            'class_final_avg': round(sum(finals) / len(finals), 1) if finals else None,
            'pass_count': sum(1 for f in finals if f >= 60),
            'fail_count': sum(1 for f in finals if f < 60),
        },
    }


def save_grade_config(classroom_id, form):
    """存學期成績設定。form 是 request.form。回傳錯誤訊息，成功回 None。"""
    classroom = Classroom.query.get(classroom_id)
    if not classroom:
        return '找不到該班級'

    assignments = Assignment.query.filter_by(classroom_id=classroom_id, is_published=True).all()
    weights = {}
    for a in assignments:
        raw = (form.get(f'weight_{a.id}') or '').strip()
        if raw == '':
            continue
        try:
            w = float(raw)
        except ValueError:
            return f'「{a.title}」的權重不是數字'
        if w < 0:
            return f'「{a.title}」的權重不能是負數'
        weights[str(a.id)] = w
    if assignments and all(weights.get(str(a.id), 1.0) <= 0 for a in assignments):
        return '至少要有一份作業的權重大於 0'

    sentence_pct = _clamp_pct(form.get('sentence_pct', 0))
    quiz_pct = _clamp_pct(form.get('quiz_pct', 0))
    if sentence_pct + quiz_pct > 100:
        return '造句與文章測驗的占比加起來不能超過 100%'

    classroom.grade_config = {
        'assignment_weights': weights,
        'missing_as_zero': form.get('missing_as_zero') == '1',
        'sentence_pct': sentence_pct,
        'quiz_pct': quiz_pct,
    }
    db.session.commit()
    return None


def set_assignment_score(assignment_id, student_id, raw_score):
    """老師在成績總表直接改一格分數。空字串代表清除分數。回傳 (成功, 錯誤訊息)。"""
    assignment = Assignment.query.get(assignment_id)
    if not assignment:
        return False, '找不到該作業'
    if not ClassroomMember.query.filter_by(classroom_id=assignment.classroom_id, student_id=student_id).first():
        return False, '該學生不在這個班級'

    raw = (raw_score if raw_score is not None else '').strip()
    score = None
    if raw != '':
        try:
            score = int(round(float(raw)))
        except ValueError:
            return False, '分數要是 0～100 的數字'
        if not 0 <= score <= 100:
            return False, '分數要在 0～100 之間'

    sub = AssignmentSubmission.query.filter_by(assignment_id=assignment_id, student_id=student_id).first()
    if score is None:
        if sub:
            sub.score = None
            # 學生有交東西就退回待批閱；老師手動補的空殼就回到未繳
            sub.status = SubmissionStatus.SUBMITTED if sub.submitted_at else SubmissionStatus.PENDING
            sub.updated_at = datetime.utcnow()
    else:
        if not sub:
            sub = AssignmentSubmission(assignment_id=assignment_id, student_id=student_id)
            db.session.add(sub)
        sub.score = score
        sub.status = SubmissionStatus.GRADED
        sub.updated_at = datetime.utcnow()
    db.session.commit()
    return True, None


def gradebook_csv(classroom_id):
    """成績總表轉成 CSV 文字（含 BOM，Excel 直接開中文不會亂碼）。"""
    import csv
    import io
    data = get_gradebook(classroom_id)
    if not data:
        return None
    buf = io.StringIO()
    writer = csv.writer(buf)
    header = ['帳號／學號', '姓名'] + [f"{a['title']}（權重 {a['weight']:g}）" for a in data['assignments']]
    header += ['作業平均', '造句均分', '文章測驗均分', '學期成績']
    writer.writerow(header)

    def fmt(v):
        return '' if v is None else v

    for s in data['students']:
        row = [s['username'], s['display_name']]
        for a in data['assignments']:
            cell = s['cells'][a['id']]
            row.append(fmt(cell['score']) if cell['status'] == 'graded' else ('待批閱' if cell['status'] == 'ungraded' else '缺交'))
        row += [fmt(s['assignment_avg']), fmt(s['sentence_avg']), fmt(s['quiz_avg']), fmt(s['final'])]
        writer.writerow(row)

    cfg = data['config']
    writer.writerow([])
    writer.writerow(['計分方式', f"作業 {data['assignment_pct']}%、造句 {cfg['sentence_pct']}%、文章測驗 {cfg['quiz_pct']}%",
                     '缺交算 0 分' if cfg['missing_as_zero'] else '缺交不列入平均'])
    return '﻿' + buf.getvalue()
