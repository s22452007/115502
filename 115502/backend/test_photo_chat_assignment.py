# -*- coding: utf-8 -*-
"""拍照 / 對話作業：老師出題 → 學生繳交 → 老師批閱頁，全部在暫存資料庫跑，不碰真實 jlens.db。"""
import os
import sys
import sqlite3
import tempfile

BACKEND = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BACKEND)
os.chdir(BACKEND)
REAL_DB = os.path.join(BACKEND, 'instance', 'jlens.db')


def table_counts(path):
    con = sqlite3.connect(path)
    names = [r[0] for r in con.execute("select name from sqlite_master where type='table'")]
    out = {n: con.execute(f'select count(*) from "{n}"').fetchone()[0] for n in names}
    con.close()
    return out


before = table_counts(REAL_DB) if os.path.exists(REAL_DB) else {}

from sqlalchemy import create_engine
from sqlalchemy.pool import NullPool
from admin_app import app
from utils.db import db

tmp = os.path.join(tempfile.gettempdir(), 'jlens_test_photo_chat.db')
if os.path.exists(tmp):
    os.remove(tmp)
db._app_engines[app][None] = create_engine('sqlite:///' + tmp, poolclass=NullPool)

from models import (
    User, ClassroomMember, Assignment, AssignmentSubmission, TaskType, SubmissionStatus,
    AccountType, Scene, Vocab, UserPhoto, UserPhotoVocab, ChatSession, ChatMessage, Dialect
)
from services.teacher_service import (
    get_or_create_teacher_user, create_classroom,
    create_photo_assignment, create_chat_assignment, get_assignment_submissions_list, strip_furigana
)
from services.student_assignment import submit_assignment, auto_submit_chat, my_assignments
from werkzeug.security import generate_password_hash

# AI 建議分數：測試不連外，用模擬回應；並改成同步執行，繳交後馬上就能檢查
from utils import gemini_client, assignment_ai


class _FakeAI:
    def __init__(self, text):
        self.text = text


def _fake_generate(feature, prompt, config=None, model=None):
    if '主題' in prompt and '"score"' in prompt and 'grammar' not in prompt:
        return _FakeAI('{"score": 28, "reason": "冰箱、菜刀、鍋子都是廚房用品"}')
    return _FakeAI('{"grammar": {"score": 35, "reason": "助詞正確"}, "natural": {"score": 16, "reason": "禮貌得體"},'
                   ' "task": {"score": 27, "reason": "完成點餐"}, "effort": {"score": 8, "reason": "句子完整"},'
                   ' "comment": "點餐用語正確"}')


gemini_client.generate_content = _fake_generate
assignment_ai.RUN_IN_BACKGROUND = False

with app.app_context():
    assert db.engine.url.database == tmp, db.engine.url.database
    db.create_all()

    teacher_id = get_or_create_teacher_user('t_photo_chat')
    classroom = create_classroom(teacher_id, "拍照對話測試班")
    student = User(email='s1@test.local', password_hash=generate_password_hash('x'), username='s_photo_chat')
    db.session.add(student); db.session.flush()
    db.session.add(ClassroomMember(classroom_id=classroom.id, student_id=student.id, display_name='小明'))
    dialect = Dialect(name='關西腔', jp_name='関西弁', region='大阪', description='', prompt_instruction='x', is_active=True)
    scene = Scene(name='廚房')
    db.session.add_all([dialect, scene]); db.session.flush()
    vocabs = [Vocab(scene_id=scene.id, word=w, kana=k, meaning=m) for w, k, m in
              [('冷蔵庫', 'れいぞうこ', '冰箱'), ('包丁', 'ほうちょう', '菜刀'), ('鍋', 'なべ', '鍋子')]]
    db.session.add_all(vocabs); db.session.commit()

    print("=== [1] 老師出拍照作業 ===")
    pa = create_photo_assignment(classroom.id, "拍一張廚房", "請拍你家廚房", theme="廚房裡的東西", min_vocab_count="2")
    assert pa.task_type == TaskType.PHOTO and pa.config == {'theme': '廚房裡的東西', 'min_vocab_count': 2}, pa.config

    print("=== [2] 老師出對話作業 ===")
    ca = create_chat_assignment(classroom.id, "餐廳點餐", "", topic="在餐廳點餐", dialect_id=dialect.id, min_turns="2")
    assert ca.task_type == TaskType.CHAT and ca.config == {'topic': '在餐廳點餐', 'dialect_id': dialect.id, 'min_turns': 2}, ca.config
    try:
        create_chat_assignment(classroom.id, "空主題", "", topic="  ")
        raise AssertionError("空主題應該被擋下")
    except ValueError:
        pass

    print("=== [3] 學生端看得到兩份作業與 config ===")
    with app.test_request_context('/api/assignment/mine'):
        resp, code = my_assignments(student.id)
        mine = resp.get_json()['assignments']
    types = {a['task_type'] for a in mine}
    assert {'photo', 'chat'} <= types, types

    print("=== [4] 學生拍照：單字不足 → 422；夠 → 已繳交 ===")
    photo_bad = UserPhoto(user_id=student.id, scene_id=scene.id, image_path='/static/photos/bad.jpg')
    db.session.add(photo_bad); db.session.flush()
    db.session.add(UserPhotoVocab(photo_id=photo_bad.id, vocab_id=vocabs[0].id)); db.session.commit()
    payload, code = submit_assignment(student.id, pa.id, photo_bad.id)
    assert code == 422, (code, payload)

    photo_ok = UserPhoto(user_id=student.id, scene_id=scene.id, image_path='/static/photos/ok.jpg',
                         custom_title='我家廚房', context_description='早餐時間')
    db.session.add(photo_ok); db.session.flush()
    db.session.add_all([UserPhotoVocab(photo_id=photo_ok.id, vocab_id=v.id, context_sentence='x') for v in vocabs])
    db.session.commit()
    payload, code = submit_assignment(student.id, pa.id, photo_ok.id)
    assert code == 200 and payload['assignment']['submission']['status'] == SubmissionStatus.SUBMITTED, (code, payload)

    print("=== [5] 學生對話：輪數不夠 → in_progress；夠 → 自動繳交 ===")
    sess = ChatSession(user_id=student.id, topic='在餐廳點餐', character_name='預設老師', dialect_id=dialect.id)
    db.session.add(sess); db.session.flush()
    db.session.add(ChatMessage(session_id=sess.id, role='user', content='すみません、[注文|ちゅうもん]をお[願|ねが]いします。'))
    db.session.add(ChatMessage(session_id=sess.id, role='ai', content='はい、どうぞ。'))
    db.session.commit()
    r = auto_submit_chat(student.id, ca.id, sess.id)
    assert r['submitted'] is False and r['status'] == 'in_progress', r
    db.session.add(ChatMessage(session_id=sess.id, role='user', content='ラーメンをください。')); db.session.commit()
    r = auto_submit_chat(student.id, ca.id, sess.id)
    assert r['submitted'] is True and r['assignment']['submission']['status'] == SubmissionStatus.SUBMITTED, r

    print("=== [6] 老師批閱頁資料 ===")
    d = get_assignment_submissions_list(pa.id)
    s0 = d['submissions'][0]
    assert s0['status'] == 'submitted' and s0['detail']['type'] == 'photo', s0
    assert s0['detail']['image_path'] == '/static/photos/ok.jpg'
    assert [v['word'] for v in s0['detail']['vocabs']] == ['冷蔵庫', '包丁', '鍋'], s0['detail']
    assert s0['detail']['scene_name'] == '廚房' and s0['detail']['custom_title'] == '我家廚房'

    d = get_assignment_submissions_list(ca.id)
    assert d['assignment']['dialect_name'] == '關西腔'
    s0 = d['submissions'][0]
    assert s0['detail']['type'] == 'chat' and s0['detail']['user_turns'] == 2, s0
    assert s0['detail']['messages'][0]['content'] == 'すみません、注文（ちゅうもん）をお願（ねが）いします。', s0['detail']['messages'][0]
    assert strip_furigana('[食|た]べる') == '食（た）べる'

    print("=== [6b] AI 建議分數：繳交後自動產生，老師確認前不算成績 ===")
    d = get_assignment_submissions_list(pa.id)
    s0 = d['submissions'][0]
    # 拍照：完成 60 + 符合主題 28（模擬 AI）+ 額外單字 2（要求 2 個、辨識出 3 個）
    assert s0['ai_score'] == 90 and s0['score'] is None and s0['status'] == 'submitted', s0
    assert [i['label'] for i in s0['ai_feedback']['items']] == ['完成任務', '符合主題', '額外單字'], s0['ai_feedback']
    d = get_assignment_submissions_list(ca.id)
    s0 = d['submissions'][0]
    # 對話：35 + 16 + 27 + 8
    assert s0['ai_score'] == 86 and s0['score'] is None and len(s0['ai_feedback']['items']) == 4, s0
    assert s0['ai_feedback']['comment'] == '點餐用語正確'

    print("=== [7] 後台頁面：出題表單 / 列表 / 批閱頁 都能渲染 ===")
    app.config['TESTING'] = True
    client = app.test_client()
    with client.session_transaction() as sess_:
        sess_['role'] = 'teacher'
        sess_['teacher_user_id'] = teacher_id
        sess_['admin_user'] = 't_photo_chat'
    r = client.get(f'/teacher/classroom/{classroom.id}/assignment/create')
    html = r.get_data(as_text=True)
    assert r.status_code == 200, r.status_code
    for needle in ['optPhoto', 'optChat', 'photoSection', 'chatSection', '關西腔', 'value="廚房"']:
        assert needle in html, needle

    r = client.get(f'/teacher/classroom/{classroom.id}/assignments')
    html = r.get_data(as_text=True)
    assert r.status_code == 200 and '拍照學習' in html and 'AI 情境對話' in html and '在餐廳點餐' in html

    r = client.get(f'/teacher/assignment/{pa.id}/submissions')
    html = r.get_data(as_text=True)
    assert r.status_code == 200 and '/static/photos/ok.jpg' in html and '冷蔵庫' in html, r.status_code
    # 批閱頁顯示 AI 建議分數與理由，分數欄預先填好建議分數
    assert 'AI 建議 90 分' in html and '符合主題 28/30' in html and 'value="90"' in html
    r = client.get(f'/teacher/assignment/{ca.id}/submissions')
    html = r.get_data(as_text=True)
    assert r.status_code == 200 and '查看對話紀錄' in html and 'ラーメンをください。' in html and '注文（ちゅうもん）' in html

    print("=== [8] 後台 POST 出題路由：photo / chat 分支 ===")
    n = Assignment.query.count()
    r = client.post(f'/teacher/classroom/{classroom.id}/assignment/create', data={
        'task_type': 'photo', 'title': '路由拍照', 'instructions': '', 'photo_theme': '書桌', 'min_vocab_count': '4'})
    assert r.status_code == 302, r.status_code
    r = client.post(f'/teacher/classroom/{classroom.id}/assignment/create', data={
        'task_type': 'chat', 'title': '路由對話', 'chat_topic': '問路', 'dialect_id': '', 'min_turns': '5'})
    assert r.status_code == 302, r.status_code
    r = client.post(f'/teacher/classroom/{classroom.id}/assignment/create', data={
        'task_type': 'chat', 'title': '沒主題', 'chat_topic': ''})
    assert r.status_code == 302
    assert Assignment.query.count() == n + 2, Assignment.query.count()
    a1 = Assignment.query.filter_by(title='路由拍照').one()
    assert a1.config == {'theme': '書桌', 'min_vocab_count': 4}, a1.config
    a2 = Assignment.query.filter_by(title='路由對話').one()
    assert a2.config == {'topic': '問路', 'dialect_id': None, 'min_turns': 5}, a2.config

    db.session.remove()

after = table_counts(REAL_DB) if os.path.exists(REAL_DB) else {}
diff = {k: (before.get(k), after.get(k)) for k in set(before) | set(after) if before.get(k) != after.get(k)}
assert not diff, f"真實資料庫被動到了: {diff}"
print("\n全部通過，真實 jlens.db 各表筆數前後一致。")
