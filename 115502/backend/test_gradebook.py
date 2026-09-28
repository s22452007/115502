"""成績總表／學期成績測試。用暫存資料庫，不會動到 instance/jlens.db。

    py -3 test_gradebook.py
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

tmp = os.path.join(tempfile.gettempdir(), 'jlens_test_gradebook.db')
if os.path.exists(tmp):
    os.remove(tmp)
db._app_engines[app][None] = create_engine('sqlite:///' + tmp, poolclass=NullPool)

from models import (
    User, Classroom, ClassroomMember, Assignment, AssignmentSubmission, SubmissionStatus,
    Article, ScoreRecord, SentencePracticeRecord, Admin
)
from services.teacher_service import (
    get_or_create_teacher_user, create_classroom, create_sentence_assignment,
    get_gradebook, save_grade_config, set_assignment_score, gradebook_csv,
)
from werkzeug.security import generate_password_hash
from werkzeug.datastructures import MultiDict

app.config['TESTING'] = True

with app.app_context():
    assert db.engine.url.database == tmp, db.engine.url.database
    db.create_all()

    teacher_id = get_or_create_teacher_user('t_gradebook')
    classroom = create_classroom(teacher_id, "成績測試班")
    cid = classroom.id

    def add_student(name, joined_days_ago=30):
        u = User(email=f'{name}@test.local', password_hash=generate_password_hash('x'), username=name)
        db.session.add(u); db.session.flush()
        db.session.add(ClassroomMember(classroom_id=cid, student_id=u.id, display_name=name,
                                       joined_at=datetime.utcnow() - timedelta(days=joined_days_ago)))
        return u

    s_a = add_student('A_全交')
    s_b = add_student('B_缺一')
    s_c = add_student('C_待批')
    db.session.commit()

    a1 = create_sentence_assignment(cid, '作業一', '', '～ます')
    a2 = create_sentence_assignment(cid, '作業二', '', '～ません')
    a3 = create_sentence_assignment(cid, '期末', '', '～でした')
    now = datetime.utcnow()

    def sub(student, assignment, score, status=SubmissionStatus.GRADED):
        s = AssignmentSubmission.query.filter_by(assignment_id=assignment.id, student_id=student.id).first()
        if not s:
            s = AssignmentSubmission(assignment_id=assignment.id, student_id=student.id)
            db.session.add(s)
        s.score = score
        s.status = status
        s.submitted_at = now
        return s

    # A：80 / 90 / 100 全部有分
    sub(s_a, a1, 80); sub(s_a, a2, 90); sub(s_a, a3, 100)
    # B：60 / 缺 / 90
    sub(s_b, a1, 60); sub(s_b, a3, 90)
    # C：70 / 已交待批 / 缺
    sub(s_c, a1, 70); sub(s_c, a2, None, SubmissionStatus.SUBMITTED)

    # 自主練習：A 加入前一筆 100 分（不該算）、加入後兩筆 80、60
    db.session.add(SentencePracticeRecord(user_id=s_a.id, grammar_point='x', user_sentence='x', score=100,
                                          created_at=now - timedelta(days=60)))
    db.session.add(SentencePracticeRecord(user_id=s_a.id, grammar_point='x', user_sentence='x', score=80))
    db.session.add(SentencePracticeRecord(user_id=s_a.id, grammar_point='x', user_sentence='x', score=60))
    art = Article(title='t', content='c', level='N5', theme='測試')
    db.session.add(art); db.session.flush()
    db.session.add(ScoreRecord(user_id=s_a.id, article_id=art.id, score=50))
    db.session.commit()

    print("=== [1] 預設計分：等權重、缺交算 0、自主練習不計 ===")
    gb = get_gradebook(cid)
    by = {s['display_name']: s for s in gb['students']}
    assert by['A_全交']['assignment_avg'] == 90.0, by['A_全交']
    assert by['A_全交']['final'] == 90.0
    assert by['B_缺一']['assignment_avg'] == 50.0, by['B_缺一']       # (60+0+90)/3
    assert by['B_缺一']['cells'][a2.id]['status'] == 'missing'
    # C：待批不列入、缺交算 0 → (70+0)/2
    assert by['C_待批']['assignment_avg'] == 35.0, by['C_待批']
    assert by['C_待批']['cells'][a2.id]['status'] == 'ungraded'
    # 自主練習只算加入後：(80+60)/2
    assert by['A_全交']['sentence_avg'] == 70.0 and by['A_全交']['sentence_count'] == 2
    assert by['A_全交']['quiz_avg'] == 50.0
    assert gb['summary']['pass_count'] == 1 and gb['summary']['fail_count'] == 2
    assert gb['assignment_pct'] == 100
    print("OK", {k: (v['assignment_avg'], v['final']) for k, v in by.items()})

    print("\n=== [2] 缺交不算 0 ===")
    err = save_grade_config(cid, MultiDict({'sentence_pct': '0', 'quiz_pct': '0'}))  # 沒勾 missing_as_zero
    assert err is None, err
    by = {s['display_name']: s for s in get_gradebook(cid)['students']}
    assert by['B_缺一']['assignment_avg'] == 75.0, by['B_缺一']      # (60+90)/2
    assert by['C_待批']['assignment_avg'] == 70.0
    print("OK")

    print("\n=== [3] 權重 + 自主練習占比 ===")
    form = MultiDict({f'weight_{a1.id}': '1', f'weight_{a2.id}': '1', f'weight_{a3.id}': '3',
                      'missing_as_zero': '1', 'sentence_pct': '20', 'quiz_pct': '10'})
    assert save_grade_config(cid, form) is None
    gb = get_gradebook(cid)
    assert gb['assignment_pct'] == 70
    a = {s['display_name']: s for s in gb['students']}['A_全交']
    # 作業：(80*1 + 90*1 + 100*3)/5 = 94 ；學期：94*0.7 + 70*0.2 + 50*0.1 = 65.8+14+5 = 84.8
    assert a['assignment_avg'] == 94.0, a
    assert a['final'] == 84.8, a
    # B 沒有自主練習紀錄、缺交算 0 → 練習部分算 0：作業 (60+0+270)/5=66 → 66*0.7=46.2
    b = {s['display_name']: s for s in gb['students']}['B_缺一']
    assert b['assignment_avg'] == 66.0 and b['final'] == 46.2, b
    print("OK", a['final'], b['final'])

    print("\n=== [4] 設定驗證 ===")
    assert save_grade_config(cid, MultiDict({'sentence_pct': '70', 'quiz_pct': '40'})) is not None
    assert save_grade_config(cid, MultiDict({f'weight_{a1.id}': '-1'})) is not None
    assert save_grade_config(cid, MultiDict({f'weight_{a1.id}': '0', f'weight_{a2.id}': '0', f'weight_{a3.id}': '0'})) is not None
    assert save_grade_config(cid, MultiDict({f'weight_{a1.id}': 'abc'})) is not None
    print("OK")

    print("\n=== [5] 總表上直接改分 ===")
    ok, err = set_assignment_score(a2.id, s_b.id, '88')          # 缺交補分 → 新建 submission
    assert ok, err
    s = AssignmentSubmission.query.filter_by(assignment_id=a2.id, student_id=s_b.id).first()
    assert s and s.score == 88 and s.status == SubmissionStatus.GRADED and s.submitted_at is None
    ok, err = set_assignment_score(a2.id, s_b.id, '')            # 清除 → 老師手動補的空殼回到未繳
    assert ok and s.score is None and s.status == SubmissionStatus.PENDING
    ok, err = set_assignment_score(a1.id, s_c.id, '')            # 學生有交的清除 → 回到待批
    assert ok
    assert AssignmentSubmission.query.filter_by(assignment_id=a1.id, student_id=s_c.id).first().status == SubmissionStatus.SUBMITTED
    assert set_assignment_score(a1.id, s_c.id, '101')[0] is False
    assert set_assignment_score(a1.id, s_c.id, 'xx')[0] is False
    assert set_assignment_score(a1.id, 99999, '50')[0] is False
    set_assignment_score(a1.id, s_c.id, '70')
    print("OK")

    print("\n=== [6] CSV ===")
    csv_text = gradebook_csv(cid)
    assert csv_text.startswith('﻿')
    lines = csv_text.splitlines()
    assert '學期成績' in lines[0] and '期末（權重 3）' in lines[0], lines[0]
    assert any('缺交' in l for l in lines) and any('待批閱' in l for l in lines)
    assert '計分方式' in lines[-1]
    print("OK", len(lines), "行")

    print("\n=== [7] 路由（super_admin 與老師） ===")
    admin = Admin(username='gb_admin', password_hash=generate_password_hash('x'), role='super_admin', is_active=True, must_change_password=False)
    db.session.add(admin); db.session.commit()
    other_teacher = get_or_create_teacher_user('t_other')
    other_class = create_classroom(other_teacher, '別人的班')

    with app.test_client() as cl:
        with cl.session_transaction() as sess:
            sess['admin_user'] = 'gb_admin'; sess['admin_id'] = admin.id; sess['role'] = 'super_admin'
        r = cl.get(f'/teacher/classroom/{cid}/gradebook', base_url='http://localhost:5001')
        assert r.status_code == 200, r.status_code
        html = r.get_data(as_text=True)
        assert 'A_全交' in html and '作業 70%' in html and '造句 20%' in html, '頁面缺內容'
        r = cl.get(f'/teacher/classroom/{cid}/gradebook/export.csv', base_url='http://localhost:5001')
        assert r.status_code == 200 and r.mimetype == 'text/csv' and 'attachment' in r.headers['Content-Disposition']
        r = cl.post(f'/teacher/classroom/{cid}/gradebook/score', json={'assignment_id': a3.id, 'student_id': s_c.id, 'score': '95'},
                    base_url='http://localhost:5001')
        assert r.status_code == 200, r.get_data(as_text=True)
        j = r.get_json()
        assert j['student']['cells'][str(a3.id)]['score'] == 95 and j['assignment']['id'] == a3.id and 'summary' in j
        r = cl.post(f'/teacher/classroom/{cid}/gradebook/score', json={'assignment_id': a3.id, 'student_id': s_c.id, 'score': '150'},
                    base_url='http://localhost:5001')
        assert r.status_code == 400
        # 作業不屬於這個班
        r = cl.post(f'/teacher/classroom/{other_class.id}/gradebook/score', json={'assignment_id': a3.id, 'student_id': s_c.id, 'score': '1'},
                    base_url='http://localhost:5001')
        assert r.status_code == 404
        r = cl.post(f'/teacher/classroom/{cid}/gradebook/config', data={'sentence_pct': '10', 'quiz_pct': '0', 'missing_as_zero': '1'},
                    base_url='http://localhost:5001', follow_redirects=True)
        assert r.status_code == 200 and '已儲存' in r.get_data(as_text=True)

        # 老師只能看自己的班
        with cl.session_transaction() as sess:
            sess.clear()
            sess['admin_user'] = 't_gradebook'; sess['role'] = 'teacher'; sess['teacher_user_id'] = teacher_id
        r = cl.get(f'/teacher/classroom/{cid}/gradebook', base_url='http://localhost:5001')
        assert r.status_code == 200
        r = cl.get(f'/teacher/classroom/{other_class.id}/gradebook', base_url='http://localhost:5001')
        assert r.status_code == 302 and '/teacher/classrooms' in r.headers['Location']
        r = cl.post(f'/teacher/classroom/{other_class.id}/gradebook/score', json={'assignment_id': a3.id, 'student_id': s_c.id, 'score': '1'},
                    base_url='http://localhost:5001')
        assert r.status_code == 404

        # 一般管理者進不了
        with cl.session_transaction() as sess:
            sess.clear()
            sess['admin_user'] = 'x'; sess['admin_id'] = admin.id; sess['role'] = 'admin'
        r = cl.get(f'/teacher/classroom/{cid}/gradebook', base_url='http://localhost:5001')
        assert r.status_code == 302 and '/dashboard' in r.headers['Location']
    print("OK")

    print("\n=== [8] 沒作業的班：學期成績不會被算成 0 ===")
    empty = create_classroom(teacher_id, '空班')
    add_student('Z'); db.session.commit()
    # 把 Z 加到空班
    z = User.query.filter_by(username='Z').first()
    db.session.add(ClassroomMember(classroom_id=empty.id, student_id=z.id, display_name='Z')); db.session.commit()
    gb = get_gradebook(empty.id)
    zrow = [s for s in gb['students'] if s['display_name'] == 'Z'][0]
    assert zrow['assignment_avg'] is None and zrow['final'] is None, zrow
    print("OK")

print("\n全部通過 ✅")
