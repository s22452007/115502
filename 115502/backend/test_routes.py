import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

from admin_app import app

client = app.test_client()

# 教師頁面現在只有老師身分能進：session 要用老師登入後的樣子（role='teacher' + teacher_user_id）
with client.session_transaction() as sess:
    sess['admin_user'] = 'test_teacher_01'
    sess['admin_id'] = None
    sess['role'] = 'teacher'
    from models import User
    with app.app_context():
        teacher = User.query.filter_by(username='test_teacher_01').first()
    sess['teacher_user_id'] = teacher.id if teacher else 1

print("=== 1. 測試 GET /teacher/classrooms ===")
resp = client.get('/teacher/classrooms')
assert resp.status_code == 200, f"Status: {resp.status_code}"
assert "校園教育版 - 班級管理" in resp.get_data(as_text=True)
print("OK: /teacher/classrooms 正常載入")

print("\n=== 2. 測試 GET /teacher/classroom/1/students ===")
resp = client.get('/teacher/classroom/1/students')
assert resp.status_code == 200, f"Status: {resp.status_code}"
assert "學生學習狀況" in resp.get_data(as_text=True)
print("OK: /teacher/classroom/1/students 正常載入")

print("\n=== 3. 測試 GET /teacher/classroom/1/assignments ===")
resp = client.get('/teacher/classroom/1/assignments')
assert resp.status_code == 200, f"Status: {resp.status_code}"
assert "作業列表" in resp.get_data(as_text=True)
print("OK: /teacher/classroom/1/assignments 正常載入")

print("\n=== 4. 測試 GET /teacher/classroom/1/assignment/create ===")
resp = client.get('/teacher/classroom/1/assignment/create')
assert resp.status_code == 200, f"Status: {resp.status_code}"
assert "出題新作業" in resp.get_data(as_text=True)
assert "造句挑戰" in resp.get_data(as_text=True)
assert "文章閱讀" in resp.get_data(as_text=True)
print("OK: /teacher/classroom/1/assignment/create 正常載入")

print("\n=== 5. 測試 GET /teacher/assignment/1/submissions ===")
resp = client.get('/teacher/assignment/1/submissions')
assert resp.status_code == 200, f"Status: {resp.status_code}"
assert "作業作答與批閱名單" in resp.get_data(as_text=True)
print("OK: /teacher/assignment/1/submissions 正常載入")

print("\n=== 6. 測試 GET /teacher/assignment/2/submissions (含測驗題目) ===")
resp = client.get('/teacher/assignment/2/submissions')
assert resp.status_code == 200, f"Status: {resp.status_code}"
assert "作業作答與批閱名單" in resp.get_data(as_text=True)
print("OK: /teacher/assignment/2/submissions 正常載入")

print("\n✅ 所有教師端 Web 頁面渲染與狀態測試全部通過！")
