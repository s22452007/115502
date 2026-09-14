import os
import sys
from datetime import datetime

# 切換工作路徑至 backend
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

from admin_app import app
from utils.db import db
from models import (
    User, Classroom, ClassroomMember, Assignment, AssignmentSubmission,
    TaskType, SubmissionStatus, AccountType, Article, SentencePracticeRecord
)
from services.teacher_service import (
    generate_unique_join_code, get_or_create_teacher_user,
    create_classroom, regenerate_join_code, toggle_classroom_open,
    get_classroom_list, get_classroom_student_stats,
    create_sentence_assignment, create_article_assignment,
    get_assignment_submissions_list, grade_submission
)

with app.app_context():
    print("=== [1. 測試隨機碼生成演算法] ===")
    codes = [generate_unique_join_code() for _ in range(20)]
    assert len(set(codes)) == 20, "隨機碼出現重複！"
    for code in codes:
        assert len(code) == 6, f"隨機碼長度不為 6: {code}"
        assert code == code.upper(), f"隨機碼非大寫: {code}"
        for ch in '01OIL':
            assert ch not in code, f"隨機碼包含易混淆字元 {ch}: {code}"
    print("OK: 隨機碼生成測試全部通過 (長度6、防混淆、無重複)")

    print("\n=== [2. 測試班級建立與隨機碼] ===")
    teacher_id = get_or_create_teacher_user('test_teacher_01')
    assert teacher_id is not None
    classroom = create_classroom(teacher_id, "測試日語班", "測試用班級說明")
    assert classroom.id is not None
    old_code = classroom.join_code
    print(f"班級建立成功: ID={classroom.id}, 名稱={classroom.name}, 隨機碼={old_code}")

    # 測試重產隨機碼
    new_code = regenerate_join_code(classroom.id)
    assert new_code != old_code
    assert len(new_code) == 6
    print(f"隨機碼重新生成成功: {old_code} -> {new_code}")

    # 測試切換加入開關
    is_open = toggle_classroom_open(classroom.id)
    assert is_open is False
    is_open = toggle_classroom_open(classroom.id)
    assert is_open is True
    print("OK: 班級開關切換成功")

    print("\n=== [3. 測試學生加入與學習狀況統計] ===")
    # 建立或取得測試學生
    student = User.query.filter_by(username='test_student_01').first()
    if not student:
        from werkzeug.security import generate_password_hash
        student = User(
            username='test_student_01',
            email='student01@test.com',
            password_hash=generate_password_hash('student123'),
            account_type=AccountType.STUDENT
        )
        db.session.add(student)
        db.session.commit()

    # 加入班級
    member = ClassroomMember.query.filter_by(classroom_id=classroom.id, student_id=student.id).first()
    if not member:
        member = ClassroomMember(classroom_id=classroom.id, student_id=student.id, display_name="王小明")
        db.session.add(member)
        db.session.commit()

    # 加入幾筆測試造句
    s_rec = SentencePracticeRecord(
        user_id=student.id,
        grammar_point="～てもいいです",
        user_sentence="写真を撮ってもいいですか。",
        corrected_sentence="写真を撮ってもいいですか。",
        score=95,
        ai_feedback="文法完全正確！"
    )
    db.session.add(s_rec)
    db.session.commit()

    print("\n=== [4. 測試教師出題：造句挑戰] ===")
    sent_assign = create_sentence_assignment(
        classroom_id=classroom.id,
        title="第1週：許可文法造句",
        instructions="請使用 ～てもいいです 進行造句練習",
        grammar_point="～てもいいです",
        required_vocabs=["写真", "撮る"],
        pass_score=60
    )
    assert sent_assign.id is not None
    assert sent_assign.task_type == TaskType.SENTENCE
    assert sent_assign.config['grammar_point'] == "～てもいいです"
    print(f"造句作業建立成功: ID={sent_assign.id}, 標題={sent_assign.title}")

    print("\n=== [5. 測試教師出題：文章閱讀（上傳文章 + 選擇題 + 是非題）] ===")
    new_art_data = {
        "title": "富士山の一日",
        "level": "N4",
        "content": "富士山は日本で一番高い山です。毎年たくさんの人が登ります。夏はとても綺麗です。",
        "translation": "富士山是日本最高的一座山。每年有許多人登山。夏天非常漂亮。"
    }
    quiz_questions = [
        {
            "type": "single_choice",
            "question": "日本で一番高い山はどこですか？",
            "options": ["阿蘇山", "富士山", "高尾山", "立山"],
            "answer": "B",
            "explanation": "文中第一句提到富士山是日本最高的山。"
        },
        {
            "type": "true_false",
            "question": "富士山は冬しか登れません。",
            "answer": "X",
            "explanation": "文中提到夏天非常美麗且很多人登山。"
        }
    ]
    art_assign = create_article_assignment(
        classroom_id=classroom.id,
        title="閱讀理解：富士山介紹",
        instructions="請先詳細閱讀文章，再完成底下的選擇題與是非題！",
        new_article=new_art_data,
        has_quiz=True,
        questions=quiz_questions
    )
    assert art_assign.id is not None
    assert art_assign.task_type == TaskType.ARTICLE
    assert art_assign.config['has_quiz'] is True
    assert len(art_assign.config['questions']) == 2
    print(f"文章閱讀出題成功: ID={art_assign.id}, 文章ID={art_assign.config['article_id']}, 題數={len(art_assign.config['questions'])}")

    print("\n=== [6. 測試學生繳交測驗與自動批閱] ===")
    from services.student_assignment import submit_quiz
    with app.test_request_context(
        '/api/assignment/submit_quiz',
        json={
            'user_id': student.id,
            'assignment_id': art_assign.id,
            'answers': {'0': 'B', '1': 'X'}  # 全對
        }
    ):
        resp, code = submit_quiz()
        res_data = resp.get_json()
        assert code == 200
        assert res_data['score'] == 100
        assert res_data['correct_count'] == 2
        print(f"學生作答自動閱卷通過: 得分={res_data['score']}, 答對={res_data['correct_count']}/2")

    print("\n=== [7. 測試教師批閱名單與評語評分] ===")
    sub_data = get_assignment_submissions_list(art_assign.id)
    assert len(sub_data['submissions']) >= 1
    target_sub = sub_data['submissions'][0]
    assert target_sub['submission_id'] is not None
    print(f"找到學生繳交紀錄: 學生={target_sub['display_name']}, 目前狀態={target_sub['status']}, 分數={target_sub['score']}")

    # 老師給評語與調整分數
    grade_ok = grade_submission(target_sub['submission_id'], score=98, teacher_comment="答得非常好！請繼續保持！")
    assert grade_ok is True
    updated_sub = AssignmentSubmission.query.get(target_sub['submission_id'])
    assert updated_sub.score == 98
    assert updated_sub.teacher_comment == "答得非常好！請繼續保持！"
    assert updated_sub.status == SubmissionStatus.GRADED
    print("OK: 教師評語與調分儲存成功！")

    print("\n=== [8. 測試班級學生學習狀況統計] ===")
    class_stats = get_classroom_student_stats(classroom.id)
    assert class_stats['summary']['total_students'] >= 1
    assert class_stats['summary']['total_assignments'] >= 2
    student_row = class_stats['students'][0]
    print(f"學生統計: {student_row['display_name']} 作業完成率={student_row['completion_rate']}%, 造句次數={student_row['sentence_count']}")

    print("\n🎉🎉🎉 全部 8 項核心功能測試全部通過！🎉🎉🎉")
