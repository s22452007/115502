"""班級報表／學生詳細成果測試。用暫存資料庫，不會動到 instance/jlens.db。

    py -3 test_classroom_report.py
"""
import os
import sys
import tempfile
from datetime import datetime, timedelta

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

from sqlalchemy import create_engine
from sqlalchemy.pool import NullPool
from admin_app import app
from utils.db import db

tmp = os.path.join(tempfile.gettempdir(), 'jlens_test_classroom_report.db')
if os.path.exists(tmp):
    os.remove(tmp)
db._app_engines[app][None] = create_engine('sqlite:///' + tmp, poolclass=NullPool)

from models import (
    User, ClassroomMember, AssignmentSubmission, SubmissionStatus, Article, ArticleProgress,
    SentencePracticeRecord, UserPhoto, ChatSession, Admin
)
from services.teacher_service import (
    get_or_create_teacher_user, create_classroom, create_sentence_assignment, create_article_assignment,
    get_classroom_report, get_student_report, student_report_csv, _distribution,
)
from services.student_assignment import student_assignment_bp  # noqa: F401  確認 answer_detail 改動可匯入
from werkzeug.security import generate_password_hash

app.config['TESTING'] = True

with app.app_context():
    assert db.engine.url.database == tmp, db.engine.url.database
    db.create_all()
    now = datetime.utcnow()

    print("=== [1] _distribution ===")
    d = _distribution([55, 65, 75, 85, 95, None])
    assert d['n'] == 5 and [b['count'] for b in d['buckets']] == [1, 1, 1, 1, 1]
    assert d['mean'] == 75.0 and d['median'] == 75.0 and d['min'] == 55 and d['max'] == 95 and d['pass_rate'] == 80
    e = _distribution([None])
    assert e['n'] == 0 and e['mean'] is None and all(b['count'] == 0 for b in e['buckets'])
    print("OK")

    teacher_id = get_or_create_teacher_user('t_report')
    classroom = create_classroom(teacher_id, "報表測試班")
    cid = classroom.id

    def add_student(name, joined_days_ago=30):
        u = User(email=f'{name}@test.local', password_hash=generate_password_hash('x'), username=name)
        db.session.add(u); db.session.flush()
        db.session.add(ClassroomMember(classroom_id=cid, student_id=u.id, display_name=name,
                                       joined_at=now - timedelta(days=joined_days_ago)))
        return u

    s1, s2, s3 = add_student('甲'), add_student('乙'), add_student('丙')
    db.session.commit()

    a1 = create_sentence_assignment(cid, '造句一', '', '～ます')
    art = Article(title='文章', content='c', level='N5', theme='測試')
    db.session.add(art); db.session.commit()
    questions = [
        {'type': 'single_choice', 'question': 'Q1', 'options': ['a', 'b', 'c', 'd'], 'answer': 'A', 'explanation': 'e1'},
        {'type': 'true_false', 'question': 'Q2', 'options': [], 'answer': 'O', 'explanation': ''},
    ]
    a2 = create_article_assignment(cid, '閱讀測驗', '', article_id=art.id, has_quiz=True, questions=questions)

    def sub(student, assignment, score, detail=None, status=SubmissionStatus.GRADED):
        s = AssignmentSubmission(assignment_id=assignment.id, student_id=student.id, score=score, status=status,
                                 submitted_at=now, answer_detail=detail)
        db.session.add(s)

    def detail(ans1, ans2):
        return [
            {'question_index': 0, 'type': 'single_choice', 'question': 'Q1', 'your_answer': ans1, 'correct_answer': 'A', 'is_correct': ans1 == 'A', 'explanation': 'e1'},
            {'question_index': 1, 'type': 'true_false', 'question': 'Q2', 'your_answer': ans2, 'correct_answer': 'O', 'is_correct': ans2 == 'O', 'explanation': ''},
        ]

    sub(s1, a1, 90); sub(s2, a1, 50)                       # 丙缺交
    sub(s1, a2, 100, detail('A', 'O')); sub(s2, a2, 50, detail('B', 'O')); sub(s3, a2, 0, detail('C', 'X'))

    # 造句：甲 ～ます 80、～て 40；乙 ～ます 60；丙 沒有。甲另有加入前的一筆 100（不計）
    db.session.add_all([
        SentencePracticeRecord(user_id=s1.id, grammar_point='～ます', user_sentence='x', score=80),
        SentencePracticeRecord(user_id=s1.id, grammar_point='～て', user_sentence='x', score=40),
        SentencePracticeRecord(user_id=s2.id, grammar_point='～ます', user_sentence='x', score=60, created_at=now - timedelta(days=20)),
        SentencePracticeRecord(user_id=s1.id, grammar_point='～ます', user_sentence='x', score=100, created_at=now - timedelta(days=90)),
    ])
    # 活動：甲今天拍照、乙 20 天前對話、丙從未
    db.session.add(UserPhoto(user_id=s1.id, image_path='x.jpg', created_at=now))
    db.session.add(ChatSession(user_id=s2.id, topic='點餐', started_at=now - timedelta(days=20), last_message_at=now - timedelta(days=20), message_count=4))
    db.session.add(ArticleProgress(user_id=s1.id, article_id=art.id, score=70, is_completed=True, completed_at=now - timedelta(days=1)))
    db.session.commit()

    print("\n=== [2] 班級報表 ===")
    r = get_classroom_report(cid)
    assert r['student_count'] == 3
    assert r['distributions']['final']['n'] == 3
    d1 = r['distributions'][str(a1.id)]
    assert d1['n'] == 2 and d1['mean'] == 70.0 and d1['median'] == 70.0
    row1 = next(a for a in r['assignments'] if a['id'] == a1.id)
    assert row1['submitted'] == 2 and row1['submit_rate'] == 67 and row1['missing_count'] == 1 and row1['pass_rate'] == 50
    # 文法：～て 40 最弱排第一；～ます (80+60)/2=70，加入前那筆 100 不算
    assert r['grammar'][0]['point'] == '～て' and r['grammar'][0]['avg'] == 40.0 and r['grammar'][0]['low_rate'] == 100
    ms = next(g for g in r['grammar'] if g['point'] == '～ます')
    assert ms['avg'] == 70.0 and ms['count'] == 2 and ms['students'] == 2
    # 測驗錯題
    assert len(r['quiz_reports']) == 1
    q = r['quiz_reports'][0]
    assert q['answered_students'] == 3
    assert q['questions'][0]['correct_rate'] == 33 and q['questions'][0]['options'] == {'A': 1, 'B': 1, 'C': 1, 'D': 0}
    assert q['questions'][1]['correct_rate'] == 67 and q['questions'][1]['options'] == {'O': 2, 'X': 1}
    assert q['hardest'][0]['index'] == 1
    # 活躍度：本週甲有活動；乙 20 天前、丙從未 → 兩位不活躍
    assert r['active_this_week'] >= 1
    assert len(r['weekly']) == 8 and sum(w['events'] for w in r['weekly']) >= 2
    names = [i['display_name'] for i in r['inactive']]
    assert '乙' in names and '丙' in names and '甲' not in names, names
    assert next(i for i in r['inactive'] if i['display_name'] == '丙')['last_seen'] is None
    print("OK  最弱文法:", r['grammar_weakest'][0]['point'], "| 不活躍:", names)

    print("\n=== [3] 學生詳細成果 ===")
    sr = get_student_report(cid, s1.id)
    assert sr['grade']['rank'] == 1 and sr['grade']['ranked_total'] == 3
    assert sr['grade']['final'] == 95.0
    assert sr['grade']['diff'] is not None and sr['grade']['diff'] > 0
    a_row = next(a for a in sr['assignments'] if a['id'] == a1.id)
    assert a_row['score'] == 90 and a_row['class_avg'] == 70.0 and a_row['diff'] == 20.0
    te = next(g for g in sr['grammar'] if g['point'] == '～て')
    assert te['avg'] == 40.0 and te['class_avg'] == 40.0 and te['diff'] == 0.0
    assert sr['quiz_total'] == 2 and sr['quiz_correct'] == 2 and sr['wrong_questions'] == []
    types = {t['type'] for t in sr['timeline']}
    assert types == {'sentence', 'photo', 'article'}, types
    assert sr['activity_counts']['sentence'] == 2      # 加入前的不算
    assert sr['timeline'][0]['type'] in ('photo', 'sentence')   # 最新在前

    sr3 = get_student_report(cid, s3.id)
    assert sr3['grade']['rank'] == 3
    assert len(sr3['wrong_questions']) == 2 and sr3['wrong_questions'][0]['your_answer'] == 'C'
    assert next(a for a in sr3['assignments'] if a['id'] == a1.id)['status'] == 'missing'
    assert sr3['timeline'] == []
    assert get_student_report(cid, 99999) is None
    print("OK  甲排名", sr['grade']['rank'], "| 丙錯題", len(sr3['wrong_questions']))

    print("\n=== [4] 個人成績單 CSV ===")
    csv_text = student_report_csv(cid, s3.id)
    assert csv_text.startswith('﻿') and '錯題' in csv_text and '缺交' in csv_text and '～て' not in csv_text
    print("OK")

    print("\n=== [5] 路由 ===")
    admin = Admin(username='rp_admin', password_hash=generate_password_hash('x'), role='super_admin', is_active=True, must_change_password=False)
    db.session.add(admin); db.session.commit()
    other = create_classroom(get_or_create_teacher_user('t_other2'), '別班')
    with app.test_client() as cl:
        with cl.session_transaction() as sess:
            sess['admin_user'] = 'rp_admin'; sess['admin_id'] = admin.id; sess['role'] = 'super_admin'
        r = cl.get(f'/teacher/classroom/{cid}/report', base_url='http://localhost:5001')
        assert r.status_code == 200
        html = r.get_data(as_text=True)
        assert '～て' in html and '閱讀測驗' in html and '丙' in html and 'distChart' in html
        r = cl.get(f'/teacher/classroom/{cid}/student/{s3.id}/report', base_url='http://localhost:5001')
        assert r.status_code == 200
        html = r.get_data(as_text=True)
        assert '丙 的詳細成果' in html and '3 / 3' in html and 'Q1' in html
        r = cl.get(f'/teacher/classroom/{cid}/student/{s3.id}/report.csv', base_url='http://localhost:5001')
        assert r.status_code == 200 and r.mimetype == 'text/csv'
        r = cl.get(f'/teacher/classroom/{cid}/student/99999/report', base_url='http://localhost:5001')
        assert r.status_code == 302
        # 學生不在這個班 → 找不到
        r = cl.get(f'/teacher/classroom/{other.id}/student/{s3.id}/report', base_url='http://localhost:5001')
        assert r.status_code == 302
        # 空班報表也能開
        r = cl.get(f'/teacher/classroom/{other.id}/report', base_url='http://localhost:5001')
        assert r.status_code == 200 and '還沒有已發布的作業' in r.get_data(as_text=True)

        with cl.session_transaction() as sess:
            sess.clear()
            sess['admin_user'] = 't_report'; sess['role'] = 'teacher'; sess['teacher_user_id'] = teacher_id
        assert cl.get(f'/teacher/classroom/{cid}/report', base_url='http://localhost:5001').status_code == 200
        assert cl.get(f'/teacher/classroom/{other.id}/report', base_url='http://localhost:5001').status_code == 302
        assert cl.get(f'/teacher/classroom/{cid}/students', base_url='http://localhost:5001').status_code == 200
    print("OK")

print("\n全部通過 ✅")
