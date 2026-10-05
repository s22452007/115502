"""學生端教室頁（TronClass 式分頁）測試：教室卡片待辦、成績分頁、老師改顯示名稱。用暫存資料庫，不會動到 instance/jlens.db。

    py -3 test_classroom_student_view.py
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

tmp = os.path.join(tempfile.gettempdir(), 'jlens_test_classroom_student_view.db')
if os.path.exists(tmp):
    os.remove(tmp)
db._app_engines[app][None] = create_engine('sqlite:///' + tmp, poolclass=NullPool)

from models import User, ClassroomMember, AssignmentSubmission, SubmissionStatus, LatePolicy, SystemLog
from services.teacher_service import (
    get_or_create_teacher_user, create_classroom, create_sentence_assignment, create_photo_assignment,
    create_chat_assignment, set_late_policy, get_gradebook,
)
from services.classroom import my_classrooms, classroom_grades
from werkzeug.security import generate_password_hash

app.config['TESTING'] = True


def call(view, path, *args):
    """直接呼叫學生端 API 的 view（學生端 blueprint 掛在 app.py，這裡不用起整個 App）。"""
    with app.test_request_context(path):
        resp, status = view(*args)
        return status, resp.get_json()


with app.app_context():
    assert db.engine.url.database == tmp, db.engine.url.database
    db.create_all()
    now = datetime.utcnow()
    now_tw = now + timedelta(hours=8)   # 作業截止時間存的是台灣時間

    teacher_id = get_or_create_teacher_user('t_student_view')
    classroom = create_classroom(teacher_id, "一年甲班", "每週三交作業")
    cid = classroom.id

    def add_student(name, room=cid):
        u = User(email=f'{name}@test.local', password_hash=generate_password_hash('x'), username=name)
        db.session.add(u); db.session.flush()
        if room:
            db.session.add(ClassroomMember(classroom_id=room, student_id=u.id, display_name=f'{name}同學',
                                           joined_at=now - timedelta(days=30)))
        return u

    me, mate = add_student('乙'), add_student('甲')
    outsider = add_student('丙', room=None)
    db.session.commit()

    # a1 遲交扣 10 分、學生遲交拿 80；a2 下週截止還沒交；a3 截止後不收、沒交；a4 沒截止日、已交待批；a5 已逾期可遲交、沒交
    a1 = create_sentence_assignment(cid, '造句一', '', '～ます', due_at=now_tw - timedelta(days=3))
    set_late_policy(a1, LatePolicy.DEDUCT, 10)
    a2 = create_sentence_assignment(cid, '造句二', '', '～たい', due_at=now_tw + timedelta(days=7))
    a3 = create_photo_assignment(cid, '拍廚房', '', '廚房', due_at=now_tw - timedelta(days=2))
    set_late_policy(a3, LatePolicy.REJECT)
    a4 = create_chat_assignment(cid, '點餐對話', '', '在餐廳點餐')
    a5 = create_sentence_assignment(cid, '造句三', '', '～ている', due_at=now_tw - timedelta(days=1))
    draft = create_sentence_assignment(cid, '草稿', '', '～ません', due_at=now_tw + timedelta(days=1))
    draft.is_published = False
    db.session.add(AssignmentSubmission(assignment_id=a1.id, student_id=me.id, score=80,
                                        status=SubmissionStatus.GRADED, submitted_at=now - timedelta(days=1),
                                        teacher_comment='句型對了'))
    db.session.add(AssignmentSubmission(assignment_id=a4.id, student_id=me.id,
                                        status=SubmissionStatus.SUBMITTED, submitted_at=now))
    db.session.add(AssignmentSubmission(assignment_id=a2.id, student_id=mate.id, score=90,
                                        status=SubmissionStatus.GRADED, submitted_at=now))
    db.session.commit()

    print("=== [1] 教室卡片待辦 ===")
    status, body = call(my_classrooms, f'/api/classroom/my/{me.id}', me.id)
    room = body['classrooms'][0]
    print({k: room[k] for k in ('assignment_count', 'pending_count', 'overdue_count', 'next_due_at', 'member_count')})
    assert status == 200
    assert room['assignment_count'] == 5, '草稿不能算進作業數'
    assert room['pending_count'] == 2, 'a2、a5 待交；a3 截止後不收不算'
    assert room['overdue_count'] == 1, 'a5 已逾期'
    assert room['next_due_at'] == a2.due_at.isoformat(), '最近截止要是還沒過期的 a2'
    assert room['member_count'] == 2 and room['description'] == '每週三交作業'
    status, body = call(my_classrooms, f'/api/classroom/my/{mate.id}', mate.id)
    room = body['classrooms'][0]
    assert room['pending_count'] == 3 and room['overdue_count'] == 2 and room['next_due_at'] is None, room
    print("OK")

    print("=== [2] 成績分頁 ===")
    status, body = call(classroom_grades, f'/api/classroom/{cid}/grades?user_id={me.id}', cid)
    rows = {r['assignment_id']: r for r in body['assignments']}
    print(body['summary'])
    assert status == 200 and 'final' not in body, '學期成績只給老師看'
    assert draft.id not in rows and len(rows) == 5
    assert body['summary'] == {'total': 5, 'submitted': 2, 'graded': 1, 'graded_avg': 70.0}
    r1 = rows[a1.id]
    assert (r1['status'], r1['score'], r1['effective'], r1['deduct'], r1['late']) == ('graded', 80, 70, 10, True), r1
    assert r1['teacher_comment'] == '句型對了' and 'weight' not in r1
    gb_cell = next(s for s in get_gradebook(cid)['students'] if s['student_id'] == me.id)['cells'][a1.id]
    assert gb_cell['effective'] == r1['effective'], '跟成績總表的分數要一樣'
    assert rows[a4.id]['status'] == 'ungraded' and not rows[a4.id]['is_overdue']
    assert rows[a2.id]['status'] == 'missing' and not rows[a2.id]['is_overdue']
    assert rows[a3.id]['is_overdue'] and rows[a5.id]['is_overdue']
    status, _ = call(classroom_grades, f'/api/classroom/{cid}/grades?user_id={outsider.id}', cid)
    assert status == 404, '非成員不能看成績'
    print("OK")

    print("=== [3] 老師在「個人資料」改顯示名稱，學生端看到新名字 ===")
    web = app.test_client()
    with web.session_transaction() as sess:
        sess['role'] = 'teacher'
        sess['teacher_user_id'] = teacher_id
        sess['admin_user'] = 't_student_view'
    r = web.get('/teacher/profile')
    assert r.status_code == 200 and 't_student_view' in r.get_data(as_text=True)

    def rename(name):
        html = web.post('/teacher/profile', data={'username': name}).get_data(as_text=True)
        return html, User.query.get(teacher_id).username

    html, now_name = rename('   ')
    assert '請輸入顯示名稱' in html and now_name == 't_student_view'
    html, now_name = rename('名' * 31)
    assert '最多 30 個字' in html and now_name == 't_student_view'
    html, now_name = rename('甲')          # App 學生的暱稱也算，不能撞名
    assert '已經有人使用' in html and 'value="甲"' in html and now_name == 't_student_view', '撞名要擋，並保留剛打的字'
    html, now_name = rename('  王小明老師 ')
    assert '已更新' in html and now_name == '王小明老師', now_name
    with web.session_transaction() as sess:
        assert sess['admin_user'] == '王小明老師', '側欄名字要跟著換'
    log = SystemLog.query.filter_by(target_table='user', target_id=teacher_id, action='UPDATE').all()[-1]
    assert log.old_value == {'username': 't_student_view'} and log.new_value['username'] == '王小明老師'
    status, body = call(my_classrooms, f'/api/classroom/my/{me.id}', me.id)
    assert body['classrooms'][0]['teacher_name'] == '王小明老師', '學生端要直接看到新名字'
    html, _ = rename('王小明老師')
    assert '名稱沒有變更' in html
    print("OK")

    print("=== [4] 封存後看不到 ===")
    classroom.is_archived = True
    db.session.commit()
    status, _ = call(classroom_grades, f'/api/classroom/{cid}/grades?user_id={me.id}', cid)
    assert status == 404
    status, body = call(my_classrooms, f'/api/classroom/my/{me.id}', me.id)
    assert body['count'] == 0
    print("OK")

    db.session.remove()

os.remove(tmp)
print("\n全部通過")
