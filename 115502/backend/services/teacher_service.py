import re
import secrets
import string
from datetime import datetime, timedelta
from utils.db import db
from models import (
    User, Classroom, ClassroomMember, Assignment, AssignmentSubmission,
    TaskType, SubmissionStatus, AccountType, LatePolicy, ClassroomAnnouncement,
    Article, SentencePracticeRecord, ArticleProgress, ScoreRecord,
    UserPhoto, UserPhotoVocab, ChatSession, ChatMessage, Dialect
)
# 遲交判斷、遲交扣分跟學生端用同一套，兩邊看到的分數才會一樣
from services.student_assignment import _is_late, late_deduction, late_policy_of
from utils import push

# 資料庫的時間除了作業截止時間 due_at（老師用 datetime-local 輸入的台灣時間）以外，
# 都是 utcnow() 存的 UTC。老師端顯示前一律用 tw_fmt 換成台灣時間；台灣沒有日光節約，固定 +8 即可。
TW_OFFSET = timedelta(hours=8)


def tw_fmt(dt, fmt='%Y-%m-%d %H:%M'):
    """UTC 的 naive datetime → 台灣時間字串；None 回空字串。也註冊成模板的 |tw 過濾器。"""
    return (dt + TW_OFFSET).strftime(fmt) if dt else ''


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
    # 一般使用者的暱稱可以跟別人重複，只找老師帳號，避免對應到剛好同名的一般使用者
    user = User.query.filter_by(username=admin_username, account_type=AccountType.TEACHER).first()
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
            'created_at': tw_fmt(c.created_at)
        })
    return result


def get_classroom_student_stats(classroom_id):
    """學生名冊與學習狀況。作業平均、造句、文章測驗直接沿用成績總表的結果
    （依權重與缺交設定、只算加入班級之後的自主練習），兩頁的數字才會一致。"""
    gb = get_gradebook(classroom_id)
    if not gb:
        return None
    classroom = Classroom.query.get(classroom_id)
    members = {m.student_id: m for m in ClassroomMember.query.filter_by(classroom_id=classroom_id).all()}
    total_assignments = len(gb['assignments'])

    student_stats = []
    total_completed_all = 0
    for row in gb['students']:
        m = members[row['student_id']]
        student = User.query.get(row['student_id'])
        completed_count = sum(1 for c in row['cells'].values() if c['status'] != 'missing')
        total_completed_all += completed_count
        aq = ArticleProgress.query.filter_by(user_id=student.id)
        if m.joined_at:
            aq = aq.filter(ArticleProgress.completed_at >= m.joined_at)

        student_stats.append({
            'student_id': student.id,
            'username': student.username or '未命名',
            'display_name': row['display_name'],
            'email': student.email or '',
            'google_login': bool(student.school_id),   # 學校 Google 帳號登入，沒有密碼可重設
            'joined_at': tw_fmt(m.joined_at, '%Y-%m-%d'),
            'completed_assignments': completed_count,
            'total_assignments': total_assignments,
            'completion_rate': round(completed_count / total_assignments * 100, 1) if total_assignments > 0 else 0,
            'avg_assignment_score': row['assignment_avg'],
            'sentence_count': row['sentence_count'],
            'sentence_avg_score': row['sentence_avg'],
            'article_count': aq.count(),
            'quiz_avg_score': row['quiz_avg'],
        })

    # 班級整體
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


LATE_POLICY_LABELS = {
    LatePolicy.ALLOW: '允許遲交',
    LatePolicy.REJECT: '截止後不收',
    LatePolicy.DEDUCT: '遲交扣分',
}


def set_late_policy(assignment, policy, penalty=0):
    """設定遲交規則（不 commit）。回傳錯誤訊息，成功回 None。"""
    policy = (policy or LatePolicy.ALLOW).strip()
    if policy not in LatePolicy.ALL:
        return '遲交規則不正確'
    pen = 0
    if policy == LatePolicy.DEDUCT:
        try:
            pen = int(round(float(penalty)))
        except (TypeError, ValueError, OverflowError):
            return '遲交扣分要填 1～100 的數字'
        if not 1 <= pen <= 100:
            return '遲交扣分要填 1～100 的數字'
    assignment.late_policy = policy
    assignment.late_penalty = pen
    return None


def late_policy_text(assignment):
    """給人看的遲交規則，例如「遲交扣 10 分」。"""
    policy = late_policy_of(assignment)
    if policy == LatePolicy.DEDUCT:
        return f'遲交扣 {int(assignment.late_penalty or 0)} 分'
    return LATE_POLICY_LABELS[policy]


def post_announcement(classroom_id, title, content='', assignment_id=None):
    """發一則班級公告（不 commit）。"""
    a = ClassroomAnnouncement(classroom_id=classroom_id, title=title.strip()[:100],
                              content=(content or '').strip(), assignment_id=assignment_id,
                              created_at=datetime.utcnow())
    db.session.add(a)
    return a


def announce_assignment(assignment):
    """出作業時順便發的公告：標題「新作業：xxx」，內文放截止時間、遲交規則和老師的說明。"""
    lines = []
    if assignment.due_at:
        lines.append(f"截止時間：{assignment.due_at.strftime('%Y-%m-%d %H:%M')}（{late_policy_text(assignment)}）")
    if assignment.instructions:
        lines.append(assignment.instructions)
    return post_announcement(assignment.classroom_id, f'新作業：{assignment.title}', '\n'.join(lines),
                             assignment_id=assignment.id)


def get_announcements(classroom_id):
    """老師看的公告列表（新的在前），附上幾位學生已經讀過。"""
    members = ClassroomMember.query.filter_by(classroom_id=classroom_id).all()
    rows = ClassroomAnnouncement.query.filter_by(classroom_id=classroom_id) \
        .order_by(ClassroomAnnouncement.created_at.desc()).all()
    titles = {a.id: a.title for a in Assignment.query.filter(
        Assignment.id.in_([r.assignment_id for r in rows if r.assignment_id] or [0]))}
    return [{
        'id': r.id,
        'title': r.title,
        'content': r.content or '',
        'assignment_id': r.assignment_id,
        'assignment_title': titles.get(r.assignment_id),
        'created_at': tw_fmt(r.created_at),
        'updated_at': tw_fmt(r.updated_at),
        # 學生打開過公告頁、而且是在這則公告發出之後打開的，就算讀過
        'read_count': sum(1 for m in members if m.notice_seen_at and r.created_at and m.notice_seen_at >= r.created_at),
        'member_count': len(members),
    } for r in rows]


def push_announcement(announcement):
    """新公告推播給全班。回傳推到幾支手機（沒設定推播時是 0）。"""
    classroom = Classroom.query.get(announcement.classroom_id)
    body = (announcement.content or '').strip().replace('\n', ' ')[:80] or '老師發布了一則新公告'
    return push.notify_classroom(classroom.id, f'{classroom.name}：{announcement.title}', body, {
        'type': 'announcement', 'classroom_id': classroom.id, 'classroom_name': classroom.name,
        'announcement_id': announcement.id})


def push_new_assignment(assignment):
    """新作業推播給全班：作業名稱、截止時間、不收遲交的話也講清楚。"""
    if not assignment.is_published:
        return 0
    classroom = Classroom.query.get(assignment.classroom_id)
    body = assignment.title
    if assignment.due_at:
        body += f"，{assignment.due_at.strftime('%m/%d %H:%M')} 截止"
        if late_policy_of(assignment) != LatePolicy.ALLOW:
            body += f'（{late_policy_text(assignment)}）'
    return push.notify_classroom(classroom.id, f'{classroom.name}：新作業', body, {
        'type': 'assignment', 'assignment_id': assignment.id, 'classroom_id': classroom.id})


def push_graded(submission):
    """老師在批閱頁存好分數，推播給那位學生。成績總表直接改分不推，避免老師調分時學生一直收到通知。"""
    a = Assignment.query.get(submission.assignment_id)
    if not a or not a.is_published or submission.score is None:
        return 0
    body = f'「{a.title}」老師給了 {submission.score} 分'
    deduct = late_deduction(a, submission.submitted_at)
    if deduct:
        body += f'（遲交扣 {deduct}，計 {max(submission.score - deduct, 0)} 分）'
    if submission.teacher_comment:
        body += f'：{submission.teacher_comment[:40]}'
    return push.notify_users([submission.student_id], '作業已批改', body, {
        'type': 'assignment', 'assignment_id': a.id, 'classroom_id': a.classroom_id})


def copy_assignment(assignment, target_classroom_id, due_at=None, publish=True):
    """把作業複製到另一個班（不 commit）：題目、說明、遲交規則照抄，截止時間另外指定。
    文章作業沿用同一篇文章，不會再複製一份文章。"""
    import copy
    new = Assignment(
        classroom_id=target_classroom_id,
        title=assignment.title,
        instructions=assignment.instructions or '',
        task_type=assignment.task_type,
        config=copy.deepcopy(assignment.config) if assignment.config else {},
        due_at=due_at,
        late_policy=late_policy_of(assignment),
        late_penalty=int(assignment.late_penalty or 0),
        is_published=bool(publish),
        created_at=datetime.utcnow(),
    )
    db.session.add(new)
    db.session.flush()
    return new


def _quiz_summary(answer_detail):
    """一位學生的文章測驗：答對幾題、錯了哪些。舊的繳交紀錄沒有逐題作答，回 None。"""
    if not isinstance(answer_detail, list) or not answer_detail:
        return None
    wrong = [{
        'index': (item.get('question_index') or 0) + 1,
        'question': item.get('question') or '',
        'your_answer': item.get('your_answer') or '—',
        'correct_answer': item.get('correct_answer') or '',
    } for item in answer_detail if not item.get('is_correct')]
    return {'total': len(answer_detail), 'correct': len(answer_detail) - len(wrong), 'wrong': wrong}


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
        if sub and assignment.task_type == TaskType.ARTICLE and sub.status in (SubmissionStatus.SUBMITTED, SubmissionStatus.GRADED):
            # 文章測驗的逐題作答存在繳交紀錄本身（answer_detail），不在 ArticleProgress
            ap = ArticleProgress.query.get(sub.result_ref_id) if sub.result_ref_id else None
            submission_detail = {
                'type': 'article',
                'is_completed': ap.is_completed if ap else True,
                'quiz': _quiz_summary(sub.answer_detail),
            }
        elif sub and sub.result_ref_id:
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
            'submitted_at': tw_fmt(sub.submitted_at) if sub and sub.submitted_at else '尚未繳交',
            'is_late': bool(sub and sub.submitted_at and _is_late(assignment, sub.submitted_at)),
            'late_deduct': late_deduction(assignment, sub.submitted_at) if sub else 0,
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
            'created_at': tw_fmt(assignment.created_at),
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


def parse_score(raw):
    """老師輸入的分數 → (0～100 的整數，空白則 None, 錯誤訊息)。小數四捨五入。
    批閱頁和成績總表共用，兩邊擋的規則才一樣。"""
    raw = '' if raw is None else str(raw).strip()
    if raw == '':
        return None, None
    try:
        score = int(round(float(raw)))
    except (ValueError, OverflowError):   # 'abc'、'nan' 是 ValueError，'inf' 是 OverflowError
        return None, '分數要是 0～100 的數字'
    if not 0 <= score <= 100:
        return None, '分數要在 0～100 之間'
    return score, None


def grade_submission(submission_id, score, teacher_comment=''):
    """批閱作業：儲存分數與教師評語。回傳 (成功, 錯誤訊息)。"""
    sub = AssignmentSubmission.query.get(submission_id)
    if not sub:
        return False, '找不到該繳交紀錄'
    value, error = parse_score(score)
    if error:
        return False, error
    if value is None:
        return False, '請輸入分數'
    sub.score = value
    sub.teacher_comment = teacher_comment.strip() if teacher_comment else ''
    sub.status = SubmissionStatus.GRADED
    sub.updated_at = datetime.utcnow()
    db.session.commit()
    return True, None


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


def _cell_for(sub, assignment):
    """一格作業成績。status：missing 缺交 / ungraded 已交待批 / graded 有分數。
    late：學生超過截止時間才交（老師手動補分、沒有 submitted_at 的不算）。
    score 是原始分數（表格上可以改的那個）；effective 是扣完遲交分數、真正拿去算成績的分數。"""
    if sub is None or sub.status == SubmissionStatus.PENDING:
        return {'score': None, 'effective': None, 'deduct': 0, 'status': 'missing',
                'submission_id': sub.id if sub else None, 'late': False}
    late = bool(sub.submitted_at and _is_late(assignment, sub.submitted_at))
    deduct = late_deduction(assignment, sub.submitted_at)
    if sub.score is None:
        return {'score': None, 'effective': None, 'deduct': deduct, 'status': 'ungraded',
                'submission_id': sub.id, 'late': late}
    return {'score': sub.score, 'effective': max(sub.score - deduct, 0), 'deduct': deduct, 'status': 'graded',
            'submission_id': sub.id, 'late': late}


def _compute_grades(assignments, cells, cfg, practice):
    """回傳 (作業加權平均, 學期成績)。
    已交但還沒分數的作業不算缺交、不列入平均；真正缺交才依 missing_as_zero 處理。"""
    pairs = []
    for a in assignments:
        cell = cells.get(a.id) or {'score': None, 'status': 'missing'}
        weight = cfg['assignment_weights'].get(str(a.id), 1.0)
        if cell['status'] == 'ungraded':
            continue
        pairs.append((cell.get('effective'), weight))
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
        cells = {a.id: _cell_for(sub_map.get((a.id, student.id)), a) for a in assignments}
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
        graded = [s['cells'][a.id]['effective'] for s in students if s['cells'][a.id]['status'] == 'graded']
        missing = sum(1 for s in students if s['cells'][a.id]['status'] == 'missing')
        assignment_rows.append({
            'id': a.id,
            'title': a.title,
            'task_type': a.task_type,
            'type_label': TASK_TYPE_LABELS.get(a.task_type, a.task_type),
            'weight': cfg['assignment_weights'].get(str(a.id), 1.0),
            'late_policy': late_policy_of(a),
            'late_penalty': int(a.late_penalty or 0),
            'due_at': a.due_at.strftime('%m/%d') if a.due_at else '',
            'class_avg': round(sum(graded) / len(graded), 1) if graded else None,
            'graded_count': len(graded),
            'missing_count': missing,
        })

    finals = [s['final'] for s in students if s['final'] is not None]
    hidden = Assignment.query.filter_by(classroom_id=classroom_id, is_published=False) \
        .order_by(Assignment.created_at.asc()).all()
    return {
        'classroom': {'id': classroom.id, 'name': classroom.name, 'join_code': classroom.join_code},
        'config': cfg,
        'hidden_assignments': [{'id': a.id, 'title': a.title} for a in hidden],
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
    # 表單只有發布中的作業；下架中的作業沿用原本的權重，重新發布後才不會被重設回 1
    hidden_ids = {str(a.id) for a in Assignment.query.filter_by(classroom_id=classroom_id, is_published=False)}
    weights = {k: v for k, v in get_grade_config(classroom)['assignment_weights'].items() if k in hidden_ids}
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


def get_my_grades(classroom_id, student_id):
    """學生在 App 教室「成績」分頁看到的內容：各作業分數與繳交進度。

    各作業的分數學生本來就看得到（作業清單、作業詳情），這裡只是整理成一張表。
    遲交扣分、缺交判斷跟成績總表用同一套（_cell_for），兩邊看到的分數才會一樣。
    學期成績（權重、自主練習占比）只給老師看，不回傳。
    """
    if not ClassroomMember.query.filter_by(classroom_id=classroom_id, student_id=student_id).first():
        return None

    assignments = Assignment.query.filter_by(classroom_id=classroom_id, is_published=True) \
        .order_by(Assignment.created_at.asc()).all()
    subs = {s.assignment_id: s for s in AssignmentSubmission.query.filter(
        AssignmentSubmission.student_id == student_id,
        AssignmentSubmission.assignment_id.in_([a.id for a in assignments] or [0]),
    )}
    cells = {a.id: _cell_for(subs.get(a.id), a) for a in assignments}

    rows = []
    for a in assignments:
        cell = cells[a.id]
        sub = subs.get(a.id)
        rows.append({
            'assignment_id': a.id,
            'title': a.title,
            'task_type': a.task_type,
            'type_label': TASK_TYPE_LABELS.get(a.task_type, a.task_type),
            'due_at': a.due_at.isoformat() if a.due_at else None,   # 老師設定的台灣時間
            'status': cell['status'],            # missing 未交 / ungraded 待批閱 / graded 有分數
            'score': cell['score'],              # 原始分數
            'effective': cell['effective'],      # 扣完遲交分數、真正計入成績的分數
            'deduct': cell['deduct'],
            'late': cell['late'],
            # 還沒交而且已經過了截止時間，前端顯示「缺交」；還沒到截止的只算「未繳交」
            'is_overdue': cell['status'] == 'missing' and _is_late(a),
            'teacher_comment': (sub.teacher_comment if sub else None) or '',
        })

    graded = [c['effective'] for c in cells.values() if c['status'] == 'graded']
    return {
        'assignments': rows,
        'summary': {
            'total': len(assignments),
            'submitted': sum(1 for c in cells.values() if c['status'] != 'missing'),
            'graded': len(graded),
            'graded_avg': round(sum(graded) / len(graded), 1) if graded else None,
        },
    }


def set_assignment_score(assignment_id, student_id, raw_score):
    """老師在成績總表直接改一格分數。空字串代表清除分數。回傳 (成功, 錯誤訊息)。"""
    assignment = Assignment.query.get(assignment_id)
    if not assignment:
        return False, '找不到該作業'
    if not ClassroomMember.query.filter_by(classroom_id=assignment.classroom_id, student_id=student_id).first():
        return False, '該學生不在這個班級'

    score, error = parse_score(raw_score)
    if error:
        return False, error

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


CSV_BOM = '\ufeff'   # Excel 用 BOM 判斷 UTF-8，中文才不會亂碼


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
            row.append(fmt(cell['effective']) if cell['status'] == 'graded' else ('待批閱' if cell['status'] == 'ungraded' else '缺交'))
        row += [fmt(s['assignment_avg']), fmt(s['sentence_avg']), fmt(s['quiz_avg']), fmt(s['final'])]
        writer.writerow(row)

    cfg = data['config']
    writer.writerow([])
    writer.writerow(['計分方式', f"作業 {data['assignment_pct']}%、造句 {cfg['sentence_pct']}%、文章測驗 {cfg['quiz_pct']}%",
                     '缺交算 0 分' if cfg['missing_as_zero'] else '缺交不列入平均']
                    + (['遲交扣分已算入各作業分數'] if any(a['late_policy'] == LatePolicy.DEDUCT for a in data['assignments']) else []))
    return CSV_BOM + buf.getvalue()


# ==========================================
# 班級報表 / 學生詳細成果
# ==========================================
SCORE_BUCKETS = [(0, 59, '0–59'), (60, 69, '60–69'), (70, 79, '70–79'), (80, 89, '80–89'), (90, 100, '90–100')]


def _distribution(values):
    """一組分數的分布與統計量。values 裡的 None 會先剔除。"""
    import statistics
    vals = [v for v in values if v is not None]
    buckets = []
    for lo, hi, label in SCORE_BUCKETS:
        n = sum(1 for v in vals if lo <= v <= hi)
        buckets.append({'label': label, 'count': n, 'pct': round(n / len(vals) * 100) if vals else 0})
    if not vals:
        return {'n': 0, 'buckets': buckets, 'mean': None, 'median': None, 'min': None, 'max': None, 'std': None, 'pass_rate': None}
    return {
        'n': len(vals),
        'buckets': buckets,
        'mean': round(statistics.mean(vals), 1),
        'median': round(statistics.median(vals), 1),
        'min': min(vals),
        'max': max(vals),
        'std': round(statistics.pstdev(vals), 1) if len(vals) > 1 else 0.0,
        'pass_rate': round(sum(1 for v in vals if v >= 60) / len(vals) * 100),
    }


def _member_joined_map(classroom_id):
    """{student_id: joined_at}，只計學生加入班級之後的自主練習。"""
    return {m.student_id: m.joined_at for m in ClassroomMember.query.filter_by(classroom_id=classroom_id).all()}


def _sentence_records_for_class(joined):
    """全班加入班級後的造句紀錄。"""
    if not joined:
        return []
    rows = SentencePracticeRecord.query.filter(SentencePracticeRecord.user_id.in_(list(joined.keys()))).all()
    return [r for r in rows if r.score is not None
            and (not joined.get(r.user_id) or not r.created_at or r.created_at >= joined[r.user_id])]


def _grammar_stats(records):
    """依文法點統計：平均、練習次數、低於 60 分的比例、練過的人數。由弱到強排序。"""
    by_point = {}
    for r in records:
        p = by_point.setdefault(r.grammar_point or '（未標文法）', {'scores': [], 'students': set()})
        p['scores'].append(r.score)
        p['students'].add(r.user_id)
    out = []
    for point, p in by_point.items():
        s = p['scores']
        out.append({
            'point': point,
            'count': len(s),
            'students': len(p['students']),
            'avg': round(sum(s) / len(s), 1),
            'low_rate': round(sum(1 for v in s if v < 60) / len(s) * 100),
        })
    out.sort(key=lambda x: (x['avg'], -x['count']))
    return out


def _quiz_question_stats(assignment, submissions):
    """一份文章測驗作業的每題答對率與選項分布。submissions 要是同一份作業的繳交紀錄。"""
    questions = (assignment.config or {}).get('questions') or []
    if not questions:
        return None
    details = [s.answer_detail for s in submissions if isinstance(s.answer_detail, list) and s.answer_detail]
    rows = []
    for idx, q in enumerate(questions):
        is_choice = q.get('type') == 'single_choice'
        option_labels = ['A', 'B', 'C', 'D'] if is_choice else ['O', 'X']
        options = {label: 0 for label in option_labels}
        answered = correct = 0
        for d in details:
            item = next((x for x in d if x.get('question_index') == idx), None)
            if not item:
                continue
            answered += 1
            ans = str(item.get('your_answer') or '').strip().upper()
            if ans in options:
                options[ans] += 1
            if item.get('is_correct'):
                correct += 1
        rows.append({
            'index': idx + 1,
            'type': q.get('type'),
            'question': q.get('question') or '',
            'option_texts': q.get('options') or [],
            'correct_answer': str(q.get('answer') or '').upper(),
            'explanation': q.get('explanation') or '',
            'answered': answered,
            'correct_count': correct,
            'correct_rate': round(correct / answered * 100) if answered else None,
            'options': options,
        })
    return {
        'assignment_id': assignment.id,
        'title': assignment.title,
        'question_count': len(questions),
        'answered_students': len(details),
        'questions': rows,
        'hardest': sorted([r for r in rows if r['correct_rate'] is not None], key=lambda r: r['correct_rate'])[:3],
    }


def _activity_events(student_ids, since=None):
    """全班的學習活動事件：(student_id, 時間, 類型)。"""
    if not student_ids:
        return []
    events = []
    q = SentencePracticeRecord.query.filter(SentencePracticeRecord.user_id.in_(student_ids))
    if since:
        q = q.filter(SentencePracticeRecord.created_at >= since)
    events += [(r.user_id, r.created_at, 'sentence') for r in q.all() if r.created_at]
    q = ArticleProgress.query.filter(ArticleProgress.user_id.in_(student_ids))
    if since:
        q = q.filter(ArticleProgress.completed_at >= since)
    events += [(r.user_id, r.completed_at, 'article') for r in q.all() if r.completed_at]
    q = UserPhoto.query.filter(UserPhoto.user_id.in_(student_ids))
    if since:
        q = q.filter(UserPhoto.created_at >= since)
    events += [(r.user_id, r.created_at, 'photo') for r in q.all() if r.created_at]
    q = ChatSession.query.filter(ChatSession.user_id.in_(student_ids))
    if since:
        q = q.filter(ChatSession.started_at >= since)
    events += [(r.user_id, r.started_at, 'chat') for r in q.all() if r.started_at]
    return events


def get_classroom_report(classroom_id, weeks=8, inactive_days=14):
    """班級報表：成績分布、作業比較、文法弱點、測驗錯題、學習活躍度。"""
    from datetime import timedelta
    import statistics
    gb = get_gradebook(classroom_id)
    if not gb:
        return None
    students = gb['students']
    assignments = gb['assignments']

    # 1. 成績分布：學期成績 + 每份作業
    distributions = {'final': _distribution([s['final'] for s in students])}
    for a in assignments:
        distributions[str(a['id'])] = _distribution(
            [s['cells'][a['id']]['effective'] for s in students if s['cells'][a['id']]['status'] == 'graded'])

    # 2. 各作業比較
    n = len(students)
    assignment_rows = []
    for a in assignments:
        cells = [s['cells'][a['id']] for s in students]
        graded = [c['effective'] for c in cells if c['status'] == 'graded']
        submitted = sum(1 for c in cells if c['status'] != 'missing')
        assignment_rows.append({
            **a,
            'median': round(statistics.median(graded), 1) if graded else None,
            'submit_rate': round(submitted / n * 100) if n else 0,
            'submitted': submitted,
            'pass_rate': round(sum(1 for v in graded if v >= 60) / len(graded) * 100) if graded else None,
        })

    # 3. 文法弱點（造句）
    joined = _member_joined_map(classroom_id)
    grammar = _grammar_stats(_sentence_records_for_class(joined))

    # 4. 文章測驗錯題
    quiz_reports = []
    article_assignments = Assignment.query.filter_by(classroom_id=classroom_id, is_published=True, task_type=TaskType.ARTICLE) \
        .order_by(Assignment.created_at.asc()).all()
    for a in article_assignments:
        subs = AssignmentSubmission.query.filter_by(assignment_id=a.id).all()
        stats = _quiz_question_stats(a, subs)
        if stats:
            quiz_reports.append(stats)

    # 5. 學習活躍度：最近 N 週每週有活動的人數與次數；很久沒動的學生名單
    # 週次以台灣時間的週一 0 點切；資料庫是 UTC，查詢時再換回 UTC，事件時間換成台灣時間再分週
    now = datetime.utcnow()
    now_tw = now + TW_OFFSET
    week_start = (now_tw - timedelta(days=now_tw.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    first_week = week_start - timedelta(weeks=weeks - 1)
    student_ids = list(joined.keys())
    recent = [(sid, ts + TW_OFFSET, kind) for sid, ts, kind in _activity_events(student_ids, since=first_week - TW_OFFSET)]
    weekly = []
    for i in range(weeks):
        ws = first_week + timedelta(weeks=i)
        we = ws + timedelta(weeks=1)
        in_week = [e for e in recent if ws <= e[1] < we]
        weekly.append({
            'label': ws.strftime('%m/%d'),
            'active_students': len({e[0] for e in in_week}),
            'events': len(in_week),
            'by_type': {t: sum(1 for e in in_week if e[2] == t) for t in ('sentence', 'article', 'photo', 'chat')},
        })
    last_seen = {}
    for sid, ts, _ in _activity_events(student_ids):
        if sid not in last_seen or ts > last_seen[sid]:
            last_seen[sid] = ts
    inactive = []
    for s in students:
        ts = last_seen.get(s['student_id'])
        days = (now - ts).days if ts else None
        if ts is None or days >= inactive_days:
            inactive.append({'student_id': s['student_id'], 'display_name': s['display_name'],
                             'last_seen': tw_fmt(ts, '%Y-%m-%d') or None, 'days': days})
    inactive.sort(key=lambda x: (x['days'] is not None, -(x['days'] or 0)))

    return {
        'classroom': gb['classroom'],
        'config': gb['config'],
        'summary': gb['summary'],
        'student_count': n,
        'distributions': distributions,
        'assignments': assignment_rows,
        'grammar': grammar,
        'grammar_weakest': grammar[:5],
        'quiz_reports': quiz_reports,
        'weekly': weekly,
        'inactive': inactive,
        'inactive_days': inactive_days,
        'active_this_week': weekly[-1]['active_students'] if weekly else 0,
    }


def get_student_report(classroom_id, student_id):
    """單一學生在班級裡的詳細成果：成績與排名、各作業對照班平均、文法弱點、錯題、學習歷程。"""
    gb = get_gradebook(classroom_id)
    if not gb:
        return None
    me = next((s for s in gb['students'] if s['student_id'] == student_id), None)
    if not me:
        return None
    member = ClassroomMember.query.filter_by(classroom_id=classroom_id, student_id=student_id).first()
    since = member.joined_at if member else None

    ranked = sorted([s for s in gb['students'] if s['final'] is not None], key=lambda s: -s['final'])
    rank = next((i + 1 for i, s in enumerate(ranked) if s['student_id'] == student_id), None)

    # 各作業：自己的分數 vs 班平均
    assignment_series = []
    for a in gb['assignments']:
        cell = me['cells'][a['id']]
        assignment_series.append({
            'id': a['id'], 'title': a['title'], 'type_label': a['type_label'], 'task_type': a['task_type'],
            'due_at': a['due_at'], 'score': cell['effective'], 'raw_score': cell['score'], 'deduct': cell['deduct'],
            'status': cell['status'], 'late': cell['late'],
            'class_avg': a['class_avg'],
            'diff': round(cell['effective'] - a['class_avg'], 1) if cell['effective'] is not None and a['class_avg'] is not None else None,
        })

    # 文法：自己 vs 班上
    joined = _member_joined_map(classroom_id)
    class_records = _sentence_records_for_class(joined)
    class_grammar = {g['point']: g for g in _grammar_stats(class_records)}
    my_grammar = _grammar_stats([r for r in class_records if r.user_id == student_id])
    for g in my_grammar:
        g['class_avg'] = class_grammar.get(g['point'], {}).get('avg')
        g['diff'] = round(g['avg'] - g['class_avg'], 1) if g['class_avg'] is not None else None

    # 錯題：文章測驗有逐題作答的
    wrong = []
    quiz_total = quiz_correct = 0
    for a in Assignment.query.filter_by(classroom_id=classroom_id, is_published=True, task_type=TaskType.ARTICLE).all():
        sub = AssignmentSubmission.query.filter_by(assignment_id=a.id, student_id=student_id).first()
        if not sub or not isinstance(sub.answer_detail, list):
            continue
        for item in sub.answer_detail:
            quiz_total += 1
            if item.get('is_correct'):
                quiz_correct += 1
            else:
                wrong.append({
                    'assignment_title': a.title, 'question': item.get('question') or '',
                    'your_answer': item.get('your_answer') or '—', 'correct_answer': item.get('correct_answer') or '',
                    'explanation': item.get('explanation') or '',
                })

    # 學習歷程時間軸（加入班級後，最新 60 筆）
    timeline = []
    sq = SentencePracticeRecord.query.filter_by(user_id=student_id)
    aq = ArticleProgress.query.filter_by(user_id=student_id)
    pq = UserPhoto.query.filter_by(user_id=student_id)
    cq = ChatSession.query.filter_by(user_id=student_id)
    if since:
        sq = sq.filter(SentencePracticeRecord.created_at >= since)
        aq = aq.filter(ArticleProgress.completed_at >= since)
        pq = pq.filter(UserPhoto.created_at >= since)
        cq = cq.filter(ChatSession.started_at >= since)
    for r in sq.all():
        timeline.append({'type': 'sentence', 'label': '造句', 'at': r.created_at, 'title': r.grammar_point or '',
                         'detail': r.user_sentence or '', 'sub': r.corrected_sentence or '', 'score': r.score})
    for r in aq.all():
        art = Article.query.get(r.article_id)
        timeline.append({'type': 'article', 'label': '閱讀', 'at': r.completed_at, 'title': art.title if art else '文章',
                         'detail': f"程度 {art.level}" if art and art.level else '', 'sub': '', 'score': r.score})
    for r in pq.all():
        vocab_n = UserPhotoVocab.query.filter_by(photo_id=r.id).count()
        timeline.append({'type': 'photo', 'label': '拍照', 'at': r.created_at, 'title': r.custom_title or '拍照學習',
                         'detail': f'學到 {vocab_n} 個單字', 'sub': '', 'score': None})
    for r in cq.all():
        timeline.append({'type': 'chat', 'label': '對話', 'at': r.started_at, 'title': r.topic or '情境對話',
                         'detail': f'{r.message_count or 0} 則訊息', 'sub': '', 'score': None})
    timeline = [t for t in timeline if t['at']]
    timeline.sort(key=lambda t: t['at'], reverse=True)
    counts = {t: sum(1 for x in timeline if x['type'] == t) for t in ('sentence', 'article', 'photo', 'chat')}
    for t in timeline:
        t['at'] = tw_fmt(t['at'])

    user = User.query.get(student_id)
    return {
        'classroom': gb['classroom'],
        'config': gb['config'],
        'assignment_pct': gb['assignment_pct'],
        'student': {
            'id': student_id, 'display_name': me['display_name'], 'username': me['username'],
            'email': user.email if user else '', 'joined_at': tw_fmt(since, '%Y-%m-%d'),
        },
        'grade': {
            'final': me['final'], 'assignment_avg': me['assignment_avg'],
            'rank': rank, 'ranked_total': len(ranked),
            'class_avg': gb['summary']['class_final_avg'],
            'diff': round(me['final'] - gb['summary']['class_final_avg'], 1)
                    if me['final'] is not None and gb['summary']['class_final_avg'] is not None else None,
            'sentence_avg': me['sentence_avg'], 'sentence_count': me['sentence_count'],
            'quiz_avg': me['quiz_avg'], 'quiz_count': me['quiz_count'],
        },
        'assignments': assignment_series,
        'grammar': my_grammar,
        'wrong_questions': wrong,
        'quiz_total': quiz_total,
        'quiz_correct': quiz_correct,
        'timeline': timeline[:60],
        'activity_counts': counts,
    }


def student_report_csv(classroom_id, student_id):
    """個人成績單 CSV（含 BOM）。"""
    import csv
    import io
    data = get_student_report(classroom_id, student_id)
    if not data:
        return None
    buf = io.StringIO()
    w = csv.writer(buf)
    g = data['grade']
    w.writerow(['班級', data['classroom']['name']])
    w.writerow(['學生', data['student']['display_name'], data['student']['username']])
    w.writerow(['學期成績', '' if g['final'] is None else g['final'],
                '排名', f"{g['rank']}/{g['ranked_total']}" if g['rank'] else '',
                '班平均', '' if g['class_avg'] is None else g['class_avg']])
    w.writerow([])
    w.writerow(['作業', '類型', '分數', '班平均', '狀態'])
    status_text = {'graded': '已評分', 'ungraded': '待批閱', 'missing': '缺交'}
    for a in data['assignments']:
        w.writerow([a['title'], a['type_label'], '' if a['score'] is None else a['score'],
                    '' if a['class_avg'] is None else a['class_avg'], status_text.get(a['status'], a['status'])])
    w.writerow([])
    w.writerow(['文法點', '練習次數', '我的平均', '班平均'])
    for gr in data['grammar']:
        w.writerow([gr['point'], gr['count'], gr['avg'], '' if gr['class_avg'] is None else gr['class_avg']])
    if data['wrong_questions']:
        w.writerow([])
        w.writerow(['錯題（作業）', '題目', '我的答案', '正確答案'])
        for q in data['wrong_questions']:
            w.writerow([q['assignment_title'], q['question'], q['your_answer'], q['correct_answer']])
    return CSV_BOM + buf.getvalue()
