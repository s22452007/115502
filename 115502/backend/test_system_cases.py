# -*- coding: utf-8 -*-
"""
SNAP TO LEARN 系統測試（黑箱 API 測試）——系統手冊第十章「測試模型」測試個案

執行（在 backend 目錄）：
    py -3 test_system_cases.py            逐案列出結果與彙總
    py -3 test_system_cases.py --table    另外輸出 Markdown 測試個案表（可貼進系統手冊）

用 Flask test_client() 直接打學生端 App API（app.py）與管理後台（admin_app.py），
預期結果依需求清單（第五章 5-2）與各 service 的實際規則撰寫；實際行為與需求不一致時照實判定不通過。

安全措施（不會動到真實的 instance/jlens.db）：
  1. 在 app.py / admin_app.py 呼叫 db.init_app() 的當下，就把 engine 換成暫存檔
     （tempfile.gettempdir()/jlens_system_cases/），之後 app.py 的建表、補欄位、種入預設資料都寫進暫存檔。
  2. admin_app 有些頁面直接用 sqlite3 連線（DB_FILE_PATH），一併改指暫存檔。
  3. sqlite3.connect 加守門：任何要連往真實 jlens.db 的連線一律導向暫存檔並記錄次數
     （app.py 匯入時有一段直接連線真實資料庫修欄位的程式，會被導向）。
  4. 測試前後比對真實 jlens.db 各表筆數（唯讀連線），不一致時結束代碼為 2。
不連外部服務：
  - google.genai.Client 與 gemini_client.generate_content 一律丟例外，確保不會真的呼叫 Gemini。
  - 拍照辨識（utils.ai_helper.analyze_image_from_path）與 AI 對話（app.get_ai_reply）以固定回應替代，
    只測額度扣除／退還、資料寫入與回應格式；這類個案備註標示「AI 回應以模擬資料替代」。
  - 上傳的照片寫到暫存資料夾，不寫進 static/photos。
其他：A10-15 以 importlib.reload(app) 模擬後端重新啟動（仍使用同一個暫存資料庫）。
結束代碼：0＝腳本執行完畢（個案可能有不通過）；2＝真實資料庫筆數有變動。
"""
import os
import io
import sys
import json
import time
import shutil
import sqlite3
import hashlib
import pathlib
import tempfile
import traceback
import warnings
from datetime import date, datetime, timedelta, timezone
from contextlib import redirect_stdout, redirect_stderr

try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass
warnings.filterwarnings('ignore')

T_START = time.perf_counter()
BACKEND = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BACKEND)
os.chdir(BACKEND)

REAL_DB = os.path.join(BACKEND, 'instance', 'jlens.db')
WORK_DIR = os.path.join(tempfile.gettempdir(), 'jlens_system_cases')
TMP_DB = os.path.join(WORK_DIR, 'jlens_system_cases.db')
UPLOAD_DIR = os.path.join(WORK_DIR, 'photos')
LOG_PATH = os.path.join(WORK_DIR, 'server_output.log')
SHOW_TABLE = '--table' in sys.argv

shutil.rmtree(WORK_DIR, ignore_errors=True)
os.makedirs(UPLOAD_DIR, exist_ok=True)
LOG = open(LOG_PATH, 'w', encoding='utf-8')

# ----------------------------------------------------------------------
# 真實資料庫：測試前快照（唯讀）
# ----------------------------------------------------------------------
_ORIG_CONNECT = sqlite3.connect


def _same_file(a, b):
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))


def table_counts(path):
    """以唯讀模式統計各表筆數（不寫入真實資料庫）"""
    try:
        con = _ORIG_CONNECT(pathlib.Path(path).as_uri() + '?mode=ro', uri=True)
    except sqlite3.Error:
        con = _ORIG_CONNECT(path)
    try:
        names = [r[0] for r in con.execute("select name from sqlite_master where type='table'")]
        return {n: con.execute(f'select count(*) from "{n}"').fetchone()[0] for n in names}
    finally:
        con.close()


def file_digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


REAL_EXISTS = os.path.exists(REAL_DB)
REAL_BEFORE = table_counts(REAL_DB) if REAL_EXISTS else {}
REAL_HASH_BEFORE = file_digest(REAL_DB) if REAL_EXISTS else None

# ----------------------------------------------------------------------
# 守門：任何連往真實 jlens.db 的 sqlite3 連線都導向暫存檔
# ----------------------------------------------------------------------
REDIRECTED = []


def _guarded_connect(database, *args, **kwargs):
    try:
        raw = os.fsdecode(database)
        target = raw
        if raw.startswith('file:'):
            target = raw[5:].split('?', 1)[0]
            if target.startswith('///'):
                target = target[3:]
        if target not in ('', ':memory:') and _same_file(target, REAL_DB):
            REDIRECTED.append(raw)
            database = TMP_DB
            kwargs.pop('uri', None)
    except Exception:
        pass
    return _ORIG_CONNECT(database, *args, **kwargs)


sqlite3.connect = _guarded_connect
sqlite3.dbapi2.connect = _guarded_connect

# ----------------------------------------------------------------------
# 換 engine：在 db.init_app() 當下就把 engine 指到暫存檔（不是改 URI）
# ----------------------------------------------------------------------
from sqlalchemy import create_engine
from sqlalchemy.pool import NullPool
from utils.db import db

_orig_init_app = db.init_app


def _init_app_with_tmp_engine(flask_app):
    _orig_init_app(flask_app)
    db._app_engines[flask_app][None] = create_engine(
        'sqlite:///' + TMP_DB, poolclass=NullPool,
        connect_args={'timeout': 30, 'check_same_thread': False})


db.init_app = _init_app_with_tmp_engine

# ----------------------------------------------------------------------
# 封鎖外部 AI 呼叫
# ----------------------------------------------------------------------
with redirect_stdout(LOG), redirect_stderr(LOG):
    import google.genai as _genai
    from utils import gemini_client


class _NoNetworkClient:
    def __init__(self, *args, **kwargs):
        raise RuntimeError('系統測試中禁止連線外部 AI 服務')


def _blocked_ai(*args, **kwargs):
    raise RuntimeError('系統測試中禁止連線外部 AI 服務')


_genai.Client = _NoNetworkClient
gemini_client.generate_content = _blocked_ai
gemini_client.run_with_legacy_keys = _blocked_ai

# ----------------------------------------------------------------------
# 暫存資料庫先建表並放入兩筆訂閱方案（正式資料庫本來就有這兩筆）。
# app.py 在資料庫「沒有」方案時會用 SubscriptionPlan(points_grant=...) 新建，但模型沒有 points_grant
# 欄位，會直接 TypeError 啟動失敗（全新資料庫無法啟動，見問題清單）；先放入方案讓 app.py 走
# 「更新既有方案」的分支，與正式環境的啟動流程一致。
# ----------------------------------------------------------------------
import models as _models

_pre_engine = create_engine('sqlite:///' + TMP_DB, poolclass=NullPool)
db.metadata.create_all(_pre_engine)
with _pre_engine.begin() as _conn:
    _conn.execute(_models.SubscriptionPlan.__table__.insert(), [
        {'name': 'Premium Pro 月訂閱', 'billing_cycle': 'monthly', 'is_active': True},
        {'name': 'Premium Pro 年訂閱', 'billing_cycle': 'yearly', 'is_active': True},
    ])
_pre_engine.dispose()

# ----------------------------------------------------------------------
# 匯入學生端 App（app.py）與管理後台（admin_app.py）
# ----------------------------------------------------------------------
with redirect_stdout(LOG), redirect_stderr(LOG):
    import app as student_module
    import admin_app as admin_module
    import services.scenario as scenario_module
    import utils.ai_helper as ai_helper

S = student_module.app      # 學生端 App API（正式環境 port 5050）
A = admin_module.app        # 管理後台（正式環境 port 5001）
admin_module.DB_FILE_PATH = TMP_DB          # 後台直接用 sqlite3 的頁面也改用暫存檔
scenario_module.UPLOAD_FOLDER = UPLOAD_DIR  # 拍照上傳改存暫存資料夾

with S.app_context():
    assert db.engine.url.database == TMP_DB, db.engine.url.database
    db.create_all()
with A.app_context():
    assert db.engine.url.database == TMP_DB, db.engine.url.database

from models import (
    User, Admin, Scene, Vocab, UserVocab, UserFolder, UserPhoto, UserPhotoVocab, QuizQuestion,
    Achievement, UserAchievement, FriendRequest, Friendship, StudyGroup, GroupMember, GroupInvite,
    Feedback, PointPackage, SubscriptionPlan, UserSubscription, PointTransaction, ChatSession,
    ChatMessage, SystemLog, AccountType,
)
from werkzeug.security import generate_password_hash, check_password_hash

# ----------------------------------------------------------------------
# 模擬 AI：拍照辨識與 AI 對話
# ----------------------------------------------------------------------
FAKE = {'scan_ok': True, 'chat_ok': True}
FAKE_CHAT_REPLY = '[一蘭|いちらん]へようこそ！ご[注文|ちゅうもん]は[何|なん]にしますか？\n（歡迎光臨一蘭！請問要點什麼呢？）'


def fake_analyze_image_from_path(file_path):
    if not FAKE['scan_ok']:
        return {'success': False, 'error': 'AI 服務目前使用人數較多，請稍等幾秒再試一次。'}
    return {'success': True, 'result': {
        'labels': ['冷蔵庫 (Refrigerator)', '電子レンジ (Microwave)'],
        'scene_category': '居家生活',
        'vocabs': [
            {'word': '冷蔵庫', 'kana': 'れいぞうこ', 'romaji': 'reizouko', 'meaning': '冰箱'},
            {'word': '電子レンジ', 'kana': 'でんしレンジ', 'romaji': 'denshirenji', 'meaning': '微波爐'},
        ],
        'sentences': [
            {'japanese': '[冷蔵庫|れいぞうこ]に[牛乳|ぎゅうにゅう]があります。', 'chinese': '冰箱裡有牛奶。'},
            {'japanese': '[電子|でんし]レンジで[温|あたた]めます。', 'chinese': '用微波爐加熱。'},
        ],
    }}


def fake_get_ai_reply(topic, user_message, chat_history, japanese_level, dialect_id=None):
    if FAKE['chat_ok']:
        return FAKE_CHAT_REPLY, True
    return 'AI 服務目前使用人數較多，請稍等幾秒再試一次。', False


ai_helper.analyze_image_from_path = fake_analyze_image_from_path
ai_helper.generate_context_sentences = lambda *a, **k: {}
student_module.get_ai_reply = fake_get_ai_reply

JPEG_BYTES = b'\xff\xd8\xff\xe0' + b'\x00' * 64 + b'\xff\xd9'

# ----------------------------------------------------------------------
# 測試資料（前置）：題庫、程度徽章、測試單字、管理者帳號
# ----------------------------------------------------------------------
STATE = {}
with S.app_context():
    # 題庫：依 seed.py 的結構，超級新手／N5／N4／N3／N2／N1 各 2 題，共 12 題（由淺入深）
    for stage, tag in [('第一階段：超級新手', '超級新手'), ('第二階段：初級', 'N5'), ('第二階段：初級', 'N4'),
                       ('第三階段：中級', 'N3'), ('第四階段：高級', 'N2'), ('第四階段：高級', 'N1')]:
        for k in range(2):
            db.session.add(QuizQuestion(stage=stage, level_tag=tag, question=f'{tag} 測試題 {k + 1}',
                                        option_a='甲', option_b='乙', option_c='丙', option_d='丁',
                                        correct_answer='A'))
    # 程度認證徽章（正式環境由 seed.py 建立）
    for name in ['新手上路', '生活達人', '交流無礙', '商務菁英', '日語大師']:
        if not Achievement.query.filter_by(name=name).first():
            db.session.add(Achievement(name=name, description=f'{name}（程度認證）'))
    # 測試用場景與 60 個單字
    test_scene = Scene(name='系統測試場景', icon_name='category')
    db.session.add(test_scene)
    db.session.flush()
    vocabs = [Vocab(scene_id=test_scene.id, word=f'テスト語{i:02d}', kana=f'てすとご{i:02d}',
                    meaning=f'測試單字{i:02d}', source='ai') for i in range(1, 61)]
    db.session.add_all(vocabs)
    # 管理者：super_admin、一般 admin、已停用
    for username, role, pw, active in [('sys_super', 'super_admin', 'Admin@1234', True),
                                       ('sys_staff', 'admin', 'Staff@1234', True),
                                       ('sys_disabled', 'admin', 'Disabled@1234', False)]:
        a = Admin(username=username, role=role, is_active=active, must_change_password=False)
        a.set_password(pw)
        db.session.add(a)
    db.session.commit()
    TEST_SCENE_ID = test_scene.id
    VOCAB_IDS = [v.id for v in vocabs]
    SEED_INFO = {
        'plans': SubscriptionPlan.query.filter_by(is_active=True).count(),
        'packages': PointPackage.query.filter_by(is_active=True).count(),
        'theme_official_vocabs': Vocab.query.filter_by(source='admin').count(),
    }

SC = S.test_client()

# ----------------------------------------------------------------------
# 測試框架
# ----------------------------------------------------------------------
FEATURES = {
    'A01': '帳號管理', 'A02': '拍照學習', 'A03': '單字收藏', 'A04': 'AI對話練習', 'A05': '個人檔案',
    'A06': '社群互動', 'A07': '訂閱與點數', 'A09': '系統設定', 'A10': '管理員後台',
}
CASES = []
_serial = {}


class Ctx:
    def __init__(self):
        self.actual = []
        self.notes = []

    def log(self, text):
        self.actual.append(text)

    def note(self, text):
        self.notes.append(text)


def case(prefix, title, pre, steps, expect, note=''):
    def deco(fn):
        _serial[prefix] = _serial.get(prefix, 0) + 1
        CASES.append({'id': f'{prefix}-{_serial[prefix]:02d}', 'feature': FEATURES[prefix], 'title': title,
                      'pre': pre, 'steps': steps, 'expect': expect, 'note': note, 'fn': fn})
        return fn
    return deco


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def J(r):
    return r.get_json(silent=True) or {}


def _fmt(v):
    if isinstance(v, (dict, list)):
        return json.dumps(v, ensure_ascii=False)
    return str(v)


def http(r, *keys):
    """HTTP 狀態碼 + 指定欄位"""
    d = J(r)
    if keys:
        d = {k: d.get(k) for k in keys if k in d}
    if d:
        return f'HTTP {r.status_code}，' + '，'.join(f'{k}={_fmt(v)}' for k, v in d.items())
    return f'HTTP {r.status_code}'


def loc(r):
    return r.headers.get('Location', '')


_n = [0]


def register(tag, password='Pass1234'):
    _n[0] += 1
    email = f'{tag}{_n[0]:03d}@test.local'
    r = SC.post('/api/auth/register', json={'email': email, 'password': password})
    if r.status_code != 201:
        raise RuntimeError(f'前置作業失敗：註冊 {email} 回傳 HTTP {r.status_code}')
    d = r.get_json()
    return {'id': d['user_id'], 'email': email, 'friend_id': d['friend_id'], 'password': password}


def login(u, password=None):
    return SC.post('/api/auth/login', json={'email': u['email'], 'password': password or u['password']})


def user_row(uid):
    with S.app_context():
        u = db.session.get(User, uid)
        return None if u is None else {c.name: getattr(u, c.name) for c in User.__table__.columns}


def set_user(uid, **fields):
    with S.app_context():
        u = db.session.get(User, uid)
        for k, v in fields.items():
            setattr(u, k, v)
        db.session.commit()


def count(model, **filters):
    with S.app_context():
        return model.query.filter_by(**filters).count()


def plan_id(name):
    with S.app_context():
        return SubscriptionPlan.query.filter_by(name=name).first().id


def subscribe(u, cycle='monthly'):
    name = 'Premium Pro 月訂閱' if cycle == 'monthly' else 'Premium Pro 年訂閱'
    return SC.post('/api/subscription/subscribe', json={
        'user_id': u['id'], 'plan_id': plan_id(name), 'billing_cycle': cycle, 'payment_method': 'credit_card'})


def scan(u):
    return SC.post('/api/user/increment_scan', json={'user_id': u['id']})


def use_ai(u):
    return SC.post('/api/user/use_ai', json={'user_id': u['id']})


def usage(u):
    return J(SC.get(f'/api/user/usage_status/{u["id"]}'))


def favorites(u):
    return {(f['name']): f for f in J(SC.get(f'/api/vocab/favorites/{u["id"]}')).get('favorites', [])}


def friends_of(u):
    return J(SC.get(f'/api/user/friends/{u["id"]}')).get('friends', [])


def my_group(u):
    return J(SC.get(f'/api/group/my_group/{u["id"]}'))


def expire_group_of(u, reach_goal=False):
    """模擬一週挑戰期結束：把小組建立時間改成 8 天前（必要時把進度設為達標），再開小組頁觸發結算"""
    with S.app_context():
        m = GroupMember.query.filter_by(user_id=u['id']).first()
        g = db.session.get(StudyGroup, m.group_id)
        g.created_at = datetime.utcnow() - timedelta(days=8)
        if reach_goal:
            g.current_progress = g.goal_target
        db.session.commit()
    return SC.get(f'/api/group/my_group/{u["id"]}')


def accept_group_invite(u):
    invites = J(SC.get(f'/api/group/invites/{u["id"]}')).get('invites', [])
    if not invites:
        raise RuntimeError(f'前置作業失敗：使用者 {u["email"]} 沒有收到小組邀請')
    return SC.post('/api/group/respond_invite', json={
        'invite_id': invites[0]['invite_id'], 'action': 'accept', 'user_id': u['id']})


def tw_today():
    return datetime.now(timezone(timedelta(hours=8))).date()


def admin_client(username=None, password=None):
    c = A.test_client()
    if username:
        r = c.post('/login', data={'username': username, 'password': password})
        if r.status_code != 302 or not loc(r).endswith('/dashboard'):
            raise RuntimeError(f'前置作業失敗：管理者 {username} 登入失敗（HTTP {r.status_code}）')
    return c


def html(r):
    return r.get_data(as_text=True)


# ======================================================================
# A01 帳號管理（含日語程度測驗）
# ======================================================================
@case('A01', 'Email 註冊成功',
      pre='Email「alice@test.local」尚未註冊',
      steps='POST /api/auth/register，email=alice@test.local、password=Pass1234',
      expect='HTTP 201，回傳 user_id、8 碼好友代碼 friend_id、account_type=general；資料庫中的密碼為雜湊值而非明碼')
def _(c):
    r = SC.post('/api/auth/register', json={'email': 'alice@test.local', 'password': 'Pass1234'})
    d = J(r)
    c.log(http(r, 'message', 'user_id', 'friend_id', 'account_type'))
    check(r.status_code == 201, f'狀態碼為 {r.status_code}，不是 201')
    check(len(d.get('friend_id') or '') == 8, 'friend_id 不是 8 碼')
    check(d.get('account_type') == 'general', 'account_type 不是 general')
    row = user_row(d['user_id'])
    hashed = row['password_hash'] != 'Pass1234' and check_password_hash(row['password_hash'], 'Pass1234')
    c.log(f'資料庫 password_hash 以 {row["password_hash"].split("$")[0]} 雜湊儲存' if hashed else '資料庫密碼不是雜湊值')
    check(hashed, '密碼未以雜湊儲存')
    STATE['alice'] = {'id': d['user_id'], 'email': 'alice@test.local', 'password': 'Pass1234',
                      'friend_id': d['friend_id']}


@case('A01', '重複 Email 註冊被拒',
      pre='alice@test.local 已註冊（A01-01）',
      steps='再次 POST /api/auth/register，email=alice@test.local、password=Other999',
      expect='HTTP 400，訊息「這個 Email 已經註冊過囉！」；資料庫該 Email 仍只有 1 筆')
def _(c):
    r = SC.post('/api/auth/register', json={'email': 'alice@test.local', 'password': 'Other999'})
    n = count(User, email='alice@test.local')
    c.log(http(r, 'error') + f'；資料庫該 Email 筆數={n}')
    check(r.status_code == 400 and J(r).get('error') == '這個 Email 已經註冊過囉！', '未正確拒絕重複註冊')
    check(n == 1, '資料庫出現重複帳號')


@case('A01', '註冊資料不完整被拒',
      pre='無',
      steps='POST /api/auth/register，只傳 email=bob@test.local（未填密碼）',
      expect='HTTP 400，訊息「請填寫 Email 與密碼」，不建立帳號')
def _(c):
    r = SC.post('/api/auth/register', json={'email': 'bob@test.local'})
    n = count(User, email='bob@test.local')
    c.log(http(r, 'error') + f'；資料庫該 Email 筆數={n}')
    check(r.status_code == 400 and J(r).get('error') == '請填寫 Email 與密碼', '未正確拒絕')
    check(n == 0, '不完整資料仍建立了帳號')


@case('A01', '正確密碼登入成功',
      pre='alice@test.local 已註冊、今日尚未登入',
      steps='POST /api/auth/login，email=alice@test.local、password=Pass1234',
      expect='HTTP 200，訊息「登入成功！」並回傳 user_id、streak_days=1、j_pts、is_premium 等資料；資料庫最後登入日期更新為今天')
def _(c):
    u = STATE['alice']
    r = login(u)
    d = J(r)
    row = user_row(u['id'])
    c.log(http(r, 'message', 'user_id', 'streak_days', 'j_pts', 'is_premium', 'account_type')
          + f'；資料庫 last_login_date={row["last_login_date"]}')
    check(r.status_code == 200 and d.get('message') == '登入成功！', '登入失敗')
    check(d.get('user_id') == u['id'] and d.get('streak_days') == 1, '回傳資料不正確')
    check(row['last_login_date'] == date.today(), '最後登入日期未更新')


@case('A01', '錯誤密碼登入被拒',
      pre='alice@test.local 已註冊',
      steps='POST /api/auth/login，email=alice@test.local、password=WrongPass',
      expect='HTTP 401，訊息「Email 或密碼錯誤」，不回傳使用者資料')
def _(c):
    r = login(STATE['alice'], 'WrongPass')
    c.log(http(r, 'error', 'user_id'))
    check(r.status_code == 401 and J(r).get('error') == 'Email 或密碼錯誤', '未正確拒絕錯誤密碼')
    check('user_id' not in J(r), '錯誤密碼仍回傳使用者資料')


@case('A01', '未註冊 Email 登入被拒',
      pre='nobody@test.local 未註冊',
      steps='POST /api/auth/login，email=nobody@test.local、password=Pass1234',
      expect='HTTP 401，訊息「尚未註冊過」')
def _(c):
    r = SC.post('/api/auth/login', json={'email': 'nobody@test.local', 'password': 'Pass1234'})
    c.log(http(r, 'error'))
    check(r.status_code == 401 and J(r).get('error') == '尚未註冊過', '未正確拒絕')


@case('A01', '連續登入天數跨日累計',
      pre='使用者昨天有登入：last_login_date=昨天、streak_days=3、total_active_days=5（直接修改資料庫模擬）',
      steps='1. POST /api/auth/login（今天第一次登入）\n2. 同一天再 POST /api/auth/login 一次',
      expect='第一次登入 streak_days 由 3 變 4、total_active_days 由 5 變 6；同日第二次登入不重複累計（仍為 4、6）')
def _(c):
    u = register('streak')
    set_user(u['id'], last_login_date=date.today() - timedelta(days=1), streak_days=3, total_active_days=5)
    r1 = login(u)
    r2 = login(u)
    row = user_row(u['id'])
    c.log(f'第一次登入 {http(r1, "streak_days")}；同日第二次登入 {http(r2, "streak_days")}；'
          f'資料庫 total_active_days={row["total_active_days"]}')
    check(J(r1).get('streak_days') == 4, '跨日連續登入未 +1')
    check(J(r2).get('streak_days') == 4, '同日重複登入被重複累計')
    check(row['total_active_days'] == 6, '累積登入天數不正確')


@case('A01', '中斷登入後連續天數重置',
      pre='使用者最後登入為 3 天前：last_login_date=3 天前、streak_days=10',
      steps='POST /api/auth/login',
      expect='HTTP 200，streak_days 重置為 1')
def _(c):
    u = register('streakbreak')
    set_user(u['id'], last_login_date=date.today() - timedelta(days=3), streak_days=10)
    r = login(u)
    c.log(http(r, 'message', 'streak_days'))
    check(r.status_code == 200 and J(r).get('streak_days') == 1, '中斷後連續天數未重置為 1')


@case('A01', '被停用的帳號無法以 Email 登入',
      pre='使用者已被管理者停用（is_suspended=True）',
      steps='POST /api/auth/login，輸入正確的 Email 與密碼',
      expect='HTTP 403，訊息「此帳號已被停用，請聯繫客服」，不回傳使用者資料')
def _(c):
    u = register('suspended')
    set_user(u['id'], is_suspended=True)
    STATE['suspended'] = u
    r = login(u)
    c.log(http(r, 'error', 'user_id'))
    check(r.status_code == 403 and J(r).get('error') == '此帳號已被停用，請聯繫客服', '停用帳號仍可登入')


@case('A01', '被停用的帳號無法以 Google 登入',
      pre='同 A01-09，使用者已被管理者停用',
      steps='POST /api/auth/google_login，email=該停用帳號的 Email',
      expect='HTTP 403，拒絕登入（與 Email 登入一致）',
      note='只呼叫本系統後端 /google_login，未連線 Google')
def _(c):
    u = STATE['suspended']
    r = SC.post('/api/auth/google_login', json={'email': u['email']})
    c.log(http(r, 'message', 'error', 'user_id'))
    check(r.status_code == 403,
          f'停用帳號仍可透過 Google 登入（HTTP {r.status_code}「{J(r).get("message")}」並取得 user_id）')


@case('A01', 'Google 首次登入自動建立帳號',
      pre='Email「gnew@test.local」尚未註冊',
      steps='POST /api/auth/google_login，email=gnew@test.local、avatar=https://example.com/a.png',
      expect='HTTP 200，訊息「Google 登入成功！」；自動建立帳號並配發 8 碼 friend_id、streak_days=1、儲存大頭貼網址',
      note='未連線 Google，直接呼叫後端；後端未驗證 Google ID Token')
def _(c):
    r = SC.post('/api/auth/google_login', json={'email': 'gnew@test.local', 'avatar': 'https://example.com/a.png'})
    d = J(r)
    c.log(http(r, 'message', 'user_id', 'friend_id', 'streak_days', 'avatar'))
    check(r.status_code == 200 and d.get('message') == 'Google 登入成功！', '登入失敗')
    check(len(d.get('friend_id') or '') == 8 and d.get('streak_days') == 1, '回傳資料不正確')
    row = user_row(d.get('user_id'))
    check(row is not None and row['avatar'] == 'https://example.com/a.png', '帳號未建立或大頭貼未儲存')


@case('A01', '檢查暱稱是否可用',
      pre='使用者 A 已將暱稱設為「Sakura01」',
      steps='使用者 B 呼叫 POST /api/user/check_username：\n1. username=sakura01（大小寫不同）\n2. username=Momo_02\n3. username=a（只有 1 個字）',
      expect='1. HTTP 200，available=false、「此暱稱已被使用」（不分大小寫）\n2. HTTP 200，available=true\n3. HTTP 400，「暱稱需為 2～20 個字元」')
def _(c):
    a, b = register('nickA'), register('nickB')
    STATE['nickA'], STATE['nickB'] = a, b
    pre = SC.post('/api/user/update_username', json={'user_id': a['id'], 'username': 'Sakura01'})
    if pre.status_code != 200:
        raise RuntimeError('前置作業失敗：無法設定使用者 A 的暱稱')
    r1 = SC.post('/api/user/check_username', json={'user_id': b['id'], 'username': 'sakura01'})
    r2 = SC.post('/api/user/check_username', json={'user_id': b['id'], 'username': 'Momo_02'})
    r3 = SC.post('/api/user/check_username', json={'user_id': b['id'], 'username': 'a'})
    c.log(f'1. {http(r1, "available", "error")}；2. {http(r2, "available")}；3. {http(r3, "error")}')
    check(r1.status_code == 200 and J(r1).get('available') is False and J(r1).get('error') == '此暱稱已被使用',
          '重複暱稱未被偵測')
    check(r2.status_code == 200 and J(r2).get('available') is True, '可用暱稱被判定為不可用')
    check(r3.status_code == 400 and J(r3).get('error') == '暱稱需為 2～20 個字元', '長度檢查失效')


@case('A01', '修改暱稱與重複暱稱被拒',
      pre='使用者 A 暱稱為「Sakura01」',
      steps='使用者 B 呼叫 POST /api/user/update_username：\n1. username=Taro_02\n2. username=SAKURA01',
      expect='1. HTTP 200，「暱稱更新成功」\n2. HTTP 400，「此暱稱已被使用」；B 的暱稱維持 Taro_02')
def _(c):
    b = STATE['nickB']
    r1 = SC.post('/api/user/update_username', json={'user_id': b['id'], 'username': 'Taro_02'})
    r2 = SC.post('/api/user/update_username', json={'user_id': b['id'], 'username': 'SAKURA01'})
    row = user_row(b['id'])
    c.log(f'1. {http(r1, "message", "username")}；2. {http(r2, "error")}；資料庫暱稱={row["username"]}')
    check(r1.status_code == 200 and J(r1).get('message') == '暱稱更新成功', '修改暱稱失敗')
    check(r2.status_code == 400 and J(r2).get('error') == '此暱稱已被使用', '重複暱稱未被擋下')
    check(row['username'] == 'Taro_02', '暱稱被錯誤覆寫')


@case('A01', '上傳大頭貼與格式驗證',
      pre='使用者 B 已登入',
      steps='POST /api/user/upload_avatar：\n1. avatar=🐱（預設 emoji 頭像）\n2. avatar=__gallery__（非圖片字串）',
      expect='1. HTTP 200，「大頭貼更新成功！」\n2. HTTP 400，「頭像格式不正確」；資料庫保留 🐱')
def _(c):
    b = STATE['nickB']
    r1 = SC.post('/api/user/upload_avatar', json={'user_id': b['id'], 'avatar': '🐱'})
    r2 = SC.post('/api/user/upload_avatar', json={'user_id': b['id'], 'avatar': '__gallery__'})
    row = user_row(b['id'])
    c.log(f'1. {http(r1, "message")}；2. {http(r2, "error")}；資料庫 avatar={row["avatar"]}')
    check(r1.status_code == 200, 'emoji 頭像上傳失敗')
    check(r2.status_code == 400 and J(r2).get('error') == '頭像格式不正確', '非圖片內容未被擋下')
    check(row['avatar'] == '🐱', '大頭貼被錯誤覆寫')


@case('A01', '刪除帳號：帳號、收藏、資料夾、好友與小組資料清除',
      pre='使用者 D 已建立資料夾、收藏 1 個單字、與 E 互為好友、自己建立 1 個學習小組；另有購點、意見回饋、對話場次與 1 張照片',
      steps='1. POST /api/user/delete_account，user_id=D\n2. 以 D 的帳密 POST /api/auth/login\n3. GET /api/user/friends/E',
      expect='1. HTTP 200，「帳號已刪除」\n2. HTTP 401，「尚未註冊過」\n3. E 的好友列表不再有 D；資料庫中 D 的使用者、收藏、資料夾、好友關係、交友邀請、小組成員紀錄皆為 0，D 建立的小組因無成員一併解散')
def _(c):
    e = register('delE')
    d = register('delD')
    SC.post('/api/vocab/folders', json={'user_id': d['id'], 'name': '我的單字'})
    SC.post('/api/vocab/collect', json={'user_id': d['id'], 'vocab_id': VOCAB_IDS[0]})
    SC.post('/api/user/friend_request/send', json={'sender_id': d['id'], 'receiver_id': e['id']})
    req = J(SC.get(f'/api/user/friend_request/pending/{e["id"]}'))['pending_requests'][0]
    SC.post('/api/user/friend_request/respond', json={'request_id': req['request_id'], 'action': 'accept'})
    gid = J(SC.post('/api/group/create', json={'user_id': d['id'], 'name': '刪除測試小組',
                                               'goal_type': 'scans', 'goal_target': 30}))['group_id']
    SC.post('/api/user/add_points', json={'user_id': d['id'], 'points': 70, 'price': 50, 'payment_method': 'credit_card'})
    SC.post('/api/user/feedback', json={'user_id': d['id'], 'email': d['email'], 'feedback_type': '問題回報',
                                        'content': '刪除帳號測試用回饋'})
    SC.post('/api/chat_history/session', json={'user_id': d['id'], 'topic': '一蘭拉麵'})
    with S.app_context():
        p = UserPhoto(user_id=d['id'], scene_id=TEST_SCENE_ID, image_path='/static/photos/delete_test.jpg')
        db.session.add(p)
        db.session.flush()
        db.session.add(UserPhotoVocab(photo_id=p.id, vocab_id=VOCAB_IDS[1]))
        db.session.commit()
    if not any(f['user_id'] == d['id'] for f in friends_of(e)):
        raise RuntimeError('前置作業失敗：D 與 E 尚未成為好友')

    r = SC.post('/api/user/delete_account', json={'user_id': d['id']})
    r_login = login(d)
    still_friend = any(f['user_id'] == d['id'] for f in friends_of(e))
    with S.app_context():
        left = {
            'user': 1 if db.session.get(User, d['id']) else 0,
            'user_vocab': UserVocab.query.filter_by(user_id=d['id']).count(),
            'user_folder': UserFolder.query.filter_by(user_id=d['id']).count(),
            'friendship': Friendship.query.filter((Friendship.user_id == d['id']) | (Friendship.friend_id == d['id'])).count(),
            'friend_request': FriendRequest.query.filter((FriendRequest.sender_id == d['id']) | (FriendRequest.receiver_id == d['id'])).count(),
            'group_member': GroupMember.query.filter_by(user_id=d['id']).count(),
            'study_group': 1 if db.session.get(StudyGroup, gid) else 0,
        }
    STATE['deleted'] = d
    c.log(f'1. {http(r, "message")}；2. 再登入 {http(r_login, "error")}；3. E 的好友列表仍有 D：{still_friend}')
    c.log('刪除後資料庫剩餘筆數：' + '、'.join(f'{k}={v}' for k, v in left.items()))
    check(r.status_code == 200 and J(r).get('message') == '帳號已刪除', '刪除帳號失敗')
    check(r_login.status_code == 401 and J(r_login).get('error') == '尚未註冊過', '刪除後仍可登入')
    check(not still_friend, '好友列表仍顯示已刪除的帳號')
    check(all(v == 0 for v in left.values()), '部分資料未清除：' + str({k: v for k, v in left.items() if v}))


@case('A01', '刪除帳號：拍照紀錄、點數交易、意見回饋、對話紀錄一併清除',
      pre='同 A01-15，使用者 D 刪除前有 1 張照片、1 筆購點交易、1 筆意見回饋、1 個對話場次',
      steps='A01-15 刪除帳號後，查詢資料庫 user_photo、point_transaction、feedback、chat_session 中 user_id=D 的筆數',
      expect='依需求清單 A01「刪除帳號並清除個人所有資料」，上述各表中 D 的資料皆為 0 筆')
def _(c):
    d = STATE.get('deleted')
    if not d:
        raise RuntimeError('前置個案 A01-15 未完成')
    with S.app_context():
        left = {
            '照片 user_photo': UserPhoto.query.filter_by(user_id=d['id']).count(),
            '點數交易 point_transaction': PointTransaction.query.filter_by(user_id=d['id']).count(),
            '意見回饋 feedback': Feedback.query.filter_by(user_id=d['id']).count(),
            '對話場次 chat_session': ChatSession.query.filter_by(user_id=d['id']).count(),
        }
    c.log('刪除後仍殘留：' + '、'.join(f'{k}={v} 筆' for k, v in left.items()))
    check(all(v == 0 for v in left.values()),
          '刪除帳號後仍殘留個人資料：' + '、'.join(f'{k} {v} 筆' for k, v in left.items() if v))


@case('A01', '取得日語程度測驗題目',
      pre='題庫依 seed.py 結構共 12 題（超級新手、N5、N4、N3、N2、N1 各 2 題）',
      steps='GET /api/quiz/questions',
      expect='HTTP 200，回傳 10 題，每題有題目、4 個選項與正確答案索引（0～3），並依難度由淺入深排列')
def _(c):
    r = SC.get('/api/quiz/questions')
    qs = J(r).get('questions', [])
    levels = [q['context'].rsplit('(', 1)[-1].rstrip(')') for q in qs]
    c.log(f'HTTP {r.status_code}，題數={len(qs)}，各題等級依序：{"、".join(levels)}')
    order = ['超級新手', 'N5', 'N4', 'N3', 'N2', 'N1']
    check(r.status_code == 200 and len(qs) == 10, '題數不是 10 題')
    check(all(len(q['options']) == 4 and q['correctIndex'] in (0, 1, 2, 3) and q['question'] for q in qs),
          '題目格式不完整')
    check(levels == sorted(levels, key=order.index), '題目未依難度排列')
    if 'N1' not in levels:
        c.note('題庫雖有 N1 題目，但 API 只取前 10 題，N1 題目不會出現在測驗中（見問題清單）')


@case('A01', '程度測驗全部答對判定為 N1',
      pre='新註冊使用者，japanese_level 尚未設定',
      steps='POST /api/quiz/submit，user_id、results=[10 題皆答對]',
      expect='HTTP 200，level=N1；資料庫 japanese_level 更新為 N1')
def _(c):
    u = register('quiz')
    STATE['quiz'] = u
    r = SC.post('/api/quiz/submit', json={'user_id': u['id'], 'results': [True] * 10})
    row = user_row(u['id'])
    c.log(http(r, 'message', 'level') + f'；資料庫 japanese_level={row["japanese_level"]}')
    check(r.status_code == 200 and J(r).get('level') == 'N1', '判定等級不是 N1')
    check(row['japanese_level'] == 'N1', '資料庫等級未更新')


@case('A01', '程度測驗部分答對判定為 N4',
      pre='同一位使用者（目前 N1）',
      steps='POST /api/quiz/submit，results=[第 1～4 題答對、第 5～10 題答錯]',
      expect='HTTP 200，level=N4（第 3、4 題答對達 N4，第 5、6 題全錯停在 N4）；資料庫更新為 N4')
def _(c):
    u = STATE['quiz']
    r = SC.post('/api/quiz/submit', json={'user_id': u['id'], 'results': [True] * 4 + [False] * 6})
    row = user_row(u['id'])
    c.log(http(r, 'level') + f'；資料庫 japanese_level={row["japanese_level"]}')
    check(r.status_code == 200 and J(r).get('level') == 'N4' and row['japanese_level'] == 'N4', '判定等級不是 N4')


@case('A01', '程度測驗全部答錯判定為 N5',
      pre='同一位使用者（目前 N4）',
      steps='POST /api/quiz/submit，results=[10 題皆答錯]',
      expect='HTTP 200，level=N5；資料庫更新為 N5')
def _(c):
    u = STATE['quiz']
    r = SC.post('/api/quiz/submit', json={'user_id': u['id'], 'results': [False] * 10})
    row = user_row(u['id'])
    c.log(http(r, 'level') + f'；資料庫 japanese_level={row["japanese_level"]}')
    check(r.status_code == 200 and J(r).get('level') == 'N5' and row['japanese_level'] == 'N5', '判定等級不是 N5')


@case('A01', '提交測驗缺少使用者 ID 被拒',
      pre='無',
      steps='POST /api/quiz/submit，只傳 results，未傳 user_id',
      expect='HTTP 400，「缺少使用者 ID」')
def _(c):
    r = SC.post('/api/quiz/submit', json={'results': [True] * 10})
    c.log(http(r, 'error'))
    check(r.status_code == 400 and J(r).get('error') == '缺少使用者 ID', '未正確拒絕')


# ======================================================================
# A02 拍照學習（AI 辨識以模擬資料替代）
# ======================================================================
@case('A02', '拍照辨識成功並寫入照片與單字圖鑑',
      pre='免費會員今日尚未拍照；AI 辨識結果以模擬資料替代（主題「居家生活」，辨識出冷蔵庫、電子レンジ 2 個單字）',
      steps='1. POST /api/user/increment_scan（扣除 1 次拍照額度）\n2. POST /api/scenario/analyze（multipart：user_id、image=kitchen.jpg）',
      expect='1. HTTP 200，daily_scans=1、daily_limit=2\n2. HTTP 200，回傳 photo_id、scene_category=居家生活、2 個單字且各帶 vocab_id；資料庫新增 1 筆照片、2 筆照片單字明細、2 筆「已解鎖未收藏」單字紀錄，照片檔已儲存',
      note='AI 回應以模擬資料替代')
def _(c):
    u = register('scan')
    STATE['scan'] = u
    FAKE['scan_ok'] = True
    r1 = scan(u)
    r2 = SC.post('/api/scenario/analyze', data={'user_id': str(u['id']), 'image': (io.BytesIO(JPEG_BYTES), 'kitchen.jpg')},
                 content_type='multipart/form-data')
    d = J(r2)
    res = d.get('result') or {}
    words = [f"{v.get('word')}(vocab_id={v.get('vocab_id')})" for v in res.get('vocabs', [])]
    with S.app_context():
        n_photo = UserPhoto.query.filter_by(user_id=u['id']).count()
        n_pv = UserPhotoVocab.query.filter_by(photo_id=d.get('photo_id')).count() if d.get('photo_id') else 0
        uvs = UserVocab.query.filter_by(user_id=u['id']).all()
    shells = sum(1 for x in uvs if x.collected_at is None)
    saved = bool(d.get('file_path')) and os.path.exists(os.path.join(UPLOAD_DIR, os.path.basename(d['file_path'])))
    c.log(f'1. {http(r1, "daily_scans", "daily_limit")}')
    c.log(f'2. HTTP {r2.status_code}，message={d.get("message")}，photo_id={d.get("photo_id")}，'
          f'scene_category={res.get("scene_category")}，單字={"、".join(words)}')
    c.log(f'資料庫：照片 {n_photo} 筆、照片單字明細 {n_pv} 筆、已解鎖未收藏單字 {shells} 筆；照片檔已儲存={saved}')
    check(r1.status_code == 200 and J(r1).get('daily_scans') == 1 and J(r1).get('daily_limit') == 2, '扣除額度失敗')
    check(r2.status_code == 200 and d.get('photo_id') and res.get('scene_category') == '居家生活', '辨識回應不正確')
    check(len(words) == 2 and all(v.get('vocab_id') for v in res.get('vocabs', [])), '單字未帶 vocab_id')
    check(n_photo == 1 and n_pv == 2 and shells == 2 and saved, '資料寫入不完整')


@case('A02', '辨識失敗時退還拍照次數',
      pre='A02-01 的使用者今日已用 1 次；AI 辨識以模擬「服務忙碌」失敗替代',
      steps='1. POST /api/user/increment_scan（今日次數變 2）\n2. POST /api/scenario/analyze（AI 回傳失敗）\n3. GET /api/user/usage_status/{user_id}',
      expect='2. HTTP 500，回傳錯誤訊息\n3. photo_count_today 退回 1；不新增照片紀錄',
      note='AI 回應以模擬資料替代')
def _(c):
    u = STATE['scan']
    FAKE['scan_ok'] = False
    try:
        files_before = len(os.listdir(UPLOAD_DIR))
        r1 = scan(u)
        r2 = SC.post('/api/scenario/analyze', data={'user_id': str(u['id']), 'image': (io.BytesIO(JPEG_BYTES), 'fail.jpg')},
                     content_type='multipart/form-data')
        files_after = len(os.listdir(UPLOAD_DIR))
    finally:
        FAKE['scan_ok'] = True
    st = usage(u)
    n_photo = count(UserPhoto, user_id=u['id'])
    c.log(f'1. {http(r1, "daily_scans")}；2. {http(r2, "error")}；3. photo_count_today={st.get("photo_count_today")}，'
          f'照片紀錄 {n_photo} 筆')
    if files_after > files_before:
        c.note(f'辨識失敗後上傳的圖片檔仍留在伺服器（多 {files_after - files_before} 個檔案，無對應照片紀錄）')
    check(r1.status_code == 200 and J(r1).get('daily_scans') == 2, '前置扣次失敗')
    check(r2.status_code == 500 and J(r2).get('error'), '失敗時未回傳錯誤')
    check(st.get('photo_count_today') == 1, '拍照次數未退還')
    check(n_photo == 1, '失敗時仍新增照片紀錄')


@case('A02', '未附圖片的辨識請求被拒',
      pre='使用者已登入',
      steps='POST /api/scenario/analyze，只傳 user_id，不附 image',
      expect='HTTP 400，「沒有找到圖片檔案 (image)」')
def _(c):
    u = STATE['scan']
    r = SC.post('/api/scenario/analyze', data={'user_id': str(u['id'])}, content_type='multipart/form-data')
    c.log(http(r, 'error'))
    check(r.status_code == 400 and J(r).get('error') == '沒有找到圖片檔案 (image)', '未正確拒絕')


@case('A02', '今日拍照額度用完時辨識 API 拒絕服務',
      pre='免費會員今日已用完 2 次拍照額度（第 3 次 /increment_scan 回傳 403）；AI 辨識以模擬資料替代',
      steps='直接 POST /api/scenario/analyze（multipart：user_id、image）',
      expect='依「免費會員每日 2 次」規則，額度用完後辨識應被拒絕，不產生新照片紀錄',
      note='AI 回應以模擬資料替代')
def _(c):
    u = register('scanlimit')
    codes = [scan(u).status_code for _ in range(3)]
    if codes != [200, 200, 403]:
        raise RuntimeError(f'前置作業失敗：拍照扣次結果 {codes}')
    r = SC.post('/api/scenario/analyze', data={'user_id': str(u['id']), 'image': (io.BytesIO(JPEG_BYTES), 'over.jpg')},
                content_type='multipart/form-data')
    n_photo = count(UserPhoto, user_id=u['id'])
    c.log(f'前置 /increment_scan 三次狀態碼={codes}；/analyze {http(r, "message", "error")}，新增照片紀錄 {n_photo} 筆')
    check(r.status_code in (400, 403) and n_photo == 0,
          f'額度用完仍可辨識（HTTP {r.status_code}，新增 {n_photo} 筆照片）：/analyze 本身不檢查額度')


# ======================================================================
# A03 單字收藏
# ======================================================================
@case('A03', '收藏單字成功',
      pre='一般會員 V 尚未收藏任何單字；字典已有測試單字（テスト語01～60）',
      steps='1. POST /api/vocab/collect，user_id=V、vocab_id=テスト語01\n2. GET /api/vocab/favorites/{V}',
      expect='1. HTTP 201，「收藏成功！」並回傳 user_vocab_id\n2. 「預設相簿」count=1')
def _(c):
    u = register('vocab')
    STATE['vocab'] = u
    r = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[0]})
    fav = favorites(u)
    c.log(f'1. {http(r, "message", "user_vocab_id")}；2. 預設相簿 count={fav.get("預設相簿", {}).get("count")}')
    check(r.status_code == 201 and J(r).get('user_vocab_id'), '收藏失敗')
    check(fav.get('預設相簿', {}).get('count') == 1, '預設相簿數量不正確')


@case('A03', '重複收藏同一單字被拒',
      pre='V 已收藏テスト語01',
      steps='再次 POST /api/vocab/collect，vocab_id=テスト語01',
      expect='HTTP 400，「已經收藏過囉！」，收藏數不變')
def _(c):
    u = STATE['vocab']
    r = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[0]})
    fav = favorites(u)
    c.log(http(r, 'error') + f'；預設相簿 count={fav.get("預設相簿", {}).get("count")}')
    check(r.status_code == 400 and J(r).get('error') == '已經收藏過囉！', '未擋下重複收藏')
    check(fav.get('預設相簿', {}).get('count') == 1, '收藏數改變')


@case('A03', '取消收藏（保留圖鑑解鎖狀態）',
      pre='V 已收藏テスト語01',
      steps='1. POST /api/vocab/uncollect，user_id=V、vocab_id=テスト語01\n2. GET /api/vocab/favorites/{V}',
      expect='1. HTTP 200，「已從資料夾移除，但保留圖鑑解鎖狀態」\n2. 預設相簿 count=0；資料庫保留該單字紀錄（collected_at 清空）')
def _(c):
    u = STATE['vocab']
    r = SC.post('/api/vocab/uncollect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[0]})
    fav = favorites(u)
    with S.app_context():
        uv = UserVocab.query.filter_by(user_id=u['id'], vocab_id=VOCAB_IDS[0]).first()
        kept = uv is not None and uv.collected_at is None
    c.log(f'1. {http(r, "message")}；2. 預設相簿 count={fav.get("預設相簿", {}).get("count")}；資料庫保留解鎖紀錄={kept}')
    check(r.status_code == 200, '取消收藏失敗')
    check(fav.get('預設相簿', {}).get('count') == 0 and kept, '取消收藏結果不正確')


@case('A03', '已解鎖單字重新收藏',
      pre='テスト語01 已解鎖但未收藏（A03-03）',
      steps='POST /api/vocab/collect，vocab_id=テスト語01',
      expect='HTTP 200，「收藏成功！」，沿用原本的紀錄（user_vocab_id 不變）；預設相簿 count=1')
def _(c):
    u = STATE['vocab']
    with S.app_context():
        old_id = UserVocab.query.filter_by(user_id=u['id'], vocab_id=VOCAB_IDS[0]).first().id
    r = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[0]})
    fav = favorites(u)
    STATE['vocab_uv_id'] = J(r).get('user_vocab_id')
    c.log(http(r, 'message', 'user_vocab_id') + f'（原紀錄 id={old_id}）；預設相簿 count={fav.get("預設相簿", {}).get("count")}')
    check(r.status_code == 200 and J(r).get('user_vocab_id') == old_id, '未沿用原紀錄')
    check(fav.get('預設相簿', {}).get('count') == 1, '收藏數不正確')


@case('A03', '建立自訂資料夾',
      pre='V 尚無自訂資料夾',
      steps='1. POST /api/vocab/folders，user_id=V、name=動詞\n2. POST /api/vocab/folders，name 空白\n3. GET /api/vocab/favorites/{V}',
      expect='1. HTTP 201，「資料夾建立成功！」並回傳 folder_id\n2. HTTP 400，「缺少必要資料」\n3. 清單出現「動詞」資料夾，count=0')
def _(c):
    u = STATE['vocab']
    r1 = SC.post('/api/vocab/folders', json={'user_id': u['id'], 'name': '動詞'})
    r2 = SC.post('/api/vocab/folders', json={'user_id': u['id'], 'name': ''})
    fav = favorites(u)
    STATE['folder_id'] = J(r1).get('folder_id')
    c.log(f'1. {http(r1, "message", "folder_id")}；2. {http(r2, "error")}；3. 「動詞」count={fav.get("動詞", {}).get("count")}')
    check(r1.status_code == 201 and J(r1).get('folder_id'), '建立資料夾失敗')
    check(r2.status_code == 400, '空白名稱未被擋下')
    check(fav.get('動詞', {}).get('count') == 0, '資料夾未出現在清單')


@case('A03', '資料夾重新命名',
      pre='V 有「動詞」資料夾',
      steps='1. POST /api/vocab/rename_folder，folder_id、name=常用動詞\n2. 同一資料夾 name=空白字元',
      expect='1. HTTP 200，「重新命名成功」，清單顯示「常用動詞」\n2. HTTP 400，「缺少必要資料」')
def _(c):
    u = STATE['vocab']
    fid = STATE['folder_id']
    r1 = SC.post('/api/vocab/rename_folder', json={'folder_id': fid, 'name': '常用動詞'})
    r2 = SC.post('/api/vocab/rename_folder', json={'folder_id': fid, 'name': '   '})
    fav = favorites(u)
    c.log(f'1. {http(r1, "message")}；2. {http(r2, "error")}；目前資料夾={[k for k in fav if k != "預設相簿"]}')
    check(r1.status_code == 200 and '常用動詞' in fav, '改名失敗')
    check(r2.status_code == 400, '空白名稱未被擋下')


@case('A03', '移動單字到資料夾',
      pre='V 的テスト語01 在預設相簿，另有「常用動詞」資料夾',
      steps='1. POST /api/vocab/move_vocab，user_vocab_id、target_folder_id=常用動詞\n2. GET /api/vocab/favorites/{V}\n3. POST /api/vocab/folder_vocabs，folder_id=常用動詞',
      expect='1. HTTP 200，「移動成功」\n2. 「常用動詞」count=1、預設相簿 count=0\n3. 資料夾內含テスト語01')
def _(c):
    u = STATE['vocab']
    r = SC.post('/api/vocab/move_vocab', json={'user_vocab_id': STATE['vocab_uv_id'], 'target_folder_id': STATE['folder_id']})
    fav = favorites(u)
    fv = J(SC.post('/api/vocab/folder_vocabs', json={'user_id': u['id'], 'folder_id': STATE['folder_id']})).get('vocabs', [])
    c.log(f'1. {http(r, "message")}；2. 常用動詞 count={fav.get("常用動詞", {}).get("count")}、預設相簿 count={fav.get("預設相簿", {}).get("count")}；'
          f'3. 資料夾內單字={[v["word"] for v in fv]}')
    check(r.status_code == 200, '移動失敗')
    check(fav.get('常用動詞', {}).get('count') == 1 and fav.get('預設相簿', {}).get('count') == 0, '數量不正確')
    check([v['word'] for v in fv] == ['テスト語01'], '資料夾內容不正確')


@case('A03', '刪除資料夾後單字移回預設相簿',
      pre='「常用動詞」資料夾內有 1 個單字',
      steps='1. POST /api/vocab/delete_folder，folder_id=常用動詞\n2. GET /api/vocab/favorites/{V}',
      expect='1. HTTP 200，「資料夾已刪除，單字已移回預設相簿」\n2. 資料夾消失，預設相簿 count=1（單字仍為收藏狀態）')
def _(c):
    u = STATE['vocab']
    r = SC.post('/api/vocab/delete_folder', json={'folder_id': STATE['folder_id']})
    fav = favorites(u)
    c.log(f'1. {http(r, "message")}；2. 資料夾清單={list(fav)}、預設相簿 count={fav.get("預設相簿", {}).get("count")}')
    check(r.status_code == 200, '刪除資料夾失敗')
    check('常用動詞' not in fav and fav.get('預設相簿', {}).get('count') == 1, '單字未移回預設相簿')


@case('A03', '收藏達上限（預設 50 個）時被擋',
      pre='一般會員 W，收藏位 vocab_slot=50（預設）',
      steps='1. 連續 POST /api/vocab/collect 收藏 50 個不同單字\n2. 收藏第 51 個單字',
      expect='1. 50 次皆 HTTP 201\n2. HTTP 400，「收藏已達上限（50 個），花 50 點可擴充 +50 個位置」，回傳 vocab_slot=50、collected_count=50')
def _(c):
    u = register('vocabfull')
    STATE['vocabfull'] = u
    codes = [SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': vid}).status_code for vid in VOCAB_IDS[:50]]
    r = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[50]})
    c.log(f'1. 前 50 次中 HTTP 201 共 {codes.count(201)} 次；2. {http(r, "error", "vocab_slot", "collected_count")}')
    check(codes.count(201) == 50, '前 50 個未全部收藏成功')
    check(r.status_code == 400 and J(r).get('vocab_slot') == 50 and J(r).get('collected_count') == 50, '未擋下第 51 個')
    check(J(r).get('error') == '收藏已達上限（50 個），花 50 點可擴充 +50 個位置', '錯誤訊息不正確')


@case('A03', '花點數擴充收藏位後可繼續收藏',
      pre='W 已收藏 50 個（達上限），並購買 60 點',
      steps='1. POST /api/user/spend_points，feature=vocab_expand\n2. GET /api/user/usage_status/{W}\n3. 再收藏第 51 個單字',
      expect='1. HTTP 200，扣 50 點、effect=「+50 個收藏位」，餘額 10 點\n2. vocab_slot=100\n3. HTTP 201 收藏成功')
def _(c):
    u = STATE['vocabfull']
    SC.post('/api/user/add_points', json={'user_id': u['id'], 'points': 60, 'price': 50, 'payment_method': 'credit_card'})
    r1 = SC.post('/api/user/spend_points', json={'user_id': u['id'], 'feature': 'vocab_expand'})
    st = usage(u)
    r3 = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[50]})
    c.log(f'1. {http(r1, "effect", "total_points")}；2. vocab_slot={st.get("vocab_slot")}、vocab_count={st.get("vocab_count")}；3. {http(r3, "message")}')
    check(r1.status_code == 200 and J(r1).get('effect') == '+50 個收藏位' and J(r1).get('total_points') == 10, '擴充失敗')
    check(st.get('vocab_slot') == 100, '收藏位未增加')
    check(r3.status_code == 201, '擴充後仍無法收藏')


# ======================================================================
# A04 AI 對話練習（AI 回覆以模擬資料替代）
# ======================================================================
@case('A04', '情境對話一輪問答並保存紀錄',
      pre='免費會員今日尚未使用 AI 對話；AI 回覆以模擬資料替代',
      steps='1. POST /api/chat_history/session，topic=一蘭拉麵（建立對話場次）\n2. POST /api/user/use_ai（扣除 1 次）\n3. POST /api/chat（form：message=ラーメンをください、topic、level=N5、user_id、session_id）\n4. GET /api/chat_history/session/{session_id}',
      expect='1. HTTP 201 回傳 session_id\n2. HTTP 200，daily_ai=1、daily_limit=3\n3. HTTP 200，回傳 AI 回覆文字\n4. 該場次保存 2 則訊息（使用者 1、AI 1）',
      note='AI 回應以模擬資料替代')
def _(c):
    u = register('chat')
    STATE['chat'] = u
    FAKE['chat_ok'] = True
    r1 = SC.post('/api/chat_history/session', json={'user_id': u['id'], 'topic': '一蘭拉麵'})
    sid = J(r1).get('session_id')
    STATE['chat_session'] = sid
    r2 = use_ai(u)
    r3 = SC.post('/api/chat', data={'message': 'ラーメンをください', 'topic': '一蘭拉麵', 'level': 'N5',
                                    'user_id': str(u['id']), 'session_id': str(sid)})
    msgs = J(SC.get(f'/api/chat_history/session/{sid}')).get('messages', [])
    reply = r3.get_data(as_text=True)
    c.log(f'1. {http(r1, "session_id")}；2. {http(r2, "daily_ai", "daily_limit")}；3. HTTP {r3.status_code}，回傳模擬 AI 回覆（中譯：{reply.splitlines()[-1] if reply else ""}）；'
          f'4. 訊息 {len(msgs)} 則（{"、".join(m["role"] for m in msgs)}）')
    check(r1.status_code == 201 and sid, '建立場次失敗')
    check(r2.status_code == 200 and J(r2).get('daily_ai') == 1 and J(r2).get('daily_limit') == 3, '扣次失敗')
    check(r3.status_code == 200 and reply == FAKE_CHAT_REPLY, '未回傳 AI 回覆')
    check([m['role'] for m in msgs] == ['user', 'ai'], '對話紀錄未保存')


@case('A04', 'AI 回覆失敗時退還對話次數',
      pre='A04-01 的使用者今日已用 1 次；AI 回覆以模擬「服務忙碌」失敗替代',
      steps='1. POST /api/user/use_ai（今日次數變 2）\n2. POST /api/chat（AI 失敗）\n3. GET /api/user/usage_status/{user_id}、GET /api/chat_history/session/{session_id}',
      expect='2. 回傳失敗提示文字\n3. ai_count_today 退回 1；失敗的對話不寫入紀錄（仍為 2 則）',
      note='AI 回應以模擬資料替代')
def _(c):
    u = STATE['chat']
    sid = STATE['chat_session']
    FAKE['chat_ok'] = False
    try:
        r1 = use_ai(u)
        r2 = SC.post('/api/chat', data={'message': 'おすすめは？', 'topic': '一蘭拉麵', 'level': 'N5',
                                        'user_id': str(u['id']), 'session_id': str(sid)})
    finally:
        FAKE['chat_ok'] = True
    st = usage(u)
    msgs = J(SC.get(f'/api/chat_history/session/{sid}')).get('messages', [])
    c.log(f'1. {http(r1, "daily_ai")}；2. HTTP {r2.status_code}「{r2.get_data(as_text=True)}」；3. ai_count_today={st.get("ai_count_today")}、訊息 {len(msgs)} 則')
    check(J(r1).get('daily_ai') == 2, '前置扣次失敗')
    check(st.get('ai_count_today') == 1, 'AI 次數未退還')
    check(len(msgs) == 2, '失敗的對話被寫入紀錄')


@case('A04', '今日 AI 對話額度用完時對話 API 拒絕服務',
      pre='免費會員今日已用完 3 次 AI 對話額度（第 4 次 /use_ai 回傳 403）；AI 回覆以模擬資料替代',
      steps='直接 POST /api/chat（form：message、topic、level、user_id）',
      expect='依「免費會員每日 3 次」規則，額度用完後對話應被拒絕，不回傳 AI 回覆',
      note='AI 回應以模擬資料替代')
def _(c):
    u = register('chatlimit')
    codes = [use_ai(u).status_code for _ in range(4)]
    if codes != [200, 200, 200, 403]:
        raise RuntimeError(f'前置作業失敗：AI 扣次結果 {codes}')
    r = SC.post('/api/chat', data={'message': 'こんにちは', 'topic': '日常對話', 'level': 'N5', 'user_id': str(u['id'])})
    body = r.get_data(as_text=True)
    c.log(f'前置 /use_ai 四次狀態碼={codes}；/api/chat HTTP {r.status_code}，回傳 AI 回覆={body == FAKE_CHAT_REPLY}')
    check(r.status_code in (400, 403) and body != FAKE_CHAT_REPLY,
          f'額度用完仍取得 AI 回覆（HTTP {r.status_code}）：/api/chat 本身不檢查額度')


# ======================================================================
# A05 個人檔案與成就
# ======================================================================
@case('A05', '取得個人檔案資料',
      pre='使用者 P：暱稱 Hana_05、程度 N4、已收藏 1 個單字',
      steps='GET /api/user/profile_data/{P}',
      expect='HTTP 200，回傳 username、avatar、is_premium、j_pts、五大能力值 ability（閱讀、文化、口說、聽力、寫作，介於 0.05～1）、徽章進度 badge_progress（level_01=2 代表 N4、vocab_01=1）')
def _(c):
    u = register('profile')
    STATE['profile'] = u
    SC.post('/api/user/update_username', json={'user_id': u['id'], 'username': 'Hana_05'})
    SC.post('/api/user/update_level', json={'user_id': u['id'], 'level': 'N4'})
    SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[2]})
    r = SC.get(f'/api/user/profile_data/{u["id"]}')
    d = J(r)
    c.log(http(r, 'username', 'is_premium', 'j_pts', 'ability', 'badge_progress'))
    ab = d.get('ability') or {}
    check(r.status_code == 200 and d.get('username') == 'Hana_05', '個人資料不正確')
    check(set(ab) == {'reading', 'culture', 'speaking', 'listening', 'writing'} and all(0.05 <= v <= 1 for v in ab.values()),
          '能力值格式不正確')
    check((d.get('badge_progress') or {}).get('level_01') == 2 and d['badge_progress'].get('vocab_01') == 1, '徽章進度不正確')


@case('A05', '查詢不存在的使用者個人檔案',
      pre='user_id=999999 不存在',
      steps='GET /api/user/profile_data/999999',
      expect='HTTP 404，「找不到使用者」')
def _(c):
    r = SC.get('/api/user/profile_data/999999')
    c.log(http(r, 'error'))
    check(r.status_code == 404 and J(r).get('error') == '找不到使用者', '未回傳 404')


@case('A05', '拍照與連續登入累積徽章進度',
      pre='使用者 P 昨天有登入（streak_days=6、total_active_days=6），尚未拍照',
      steps='1. POST /api/user/increment_scan 兩次\n2. POST /api/auth/login\n3. GET /api/user/profile_data/{P}',
      expect='badge_progress：camera_01（快門獵人）=2、streak_01（學習火種）=7、marathon_01（學習馬拉松）=7',
      note='徽章等級門檻由 App 依 badge_progress 判定，後端提供累計值')
def _(c):
    u = STATE['profile']
    set_user(u['id'], last_login_date=date.today() - timedelta(days=1), streak_days=6, total_active_days=6)
    scan(u)
    scan(u)
    login(u)
    bp = J(SC.get(f'/api/user/profile_data/{u["id"]}')).get('badge_progress') or {}
    c.log(f'badge_progress={_fmt(bp)}')
    check(bp.get('camera_01') == 2 and bp.get('streak_01') == 7 and bp.get('marathon_01') == 7, '徽章進度未正確累積')


@case('A05', '徽章解鎖彈窗標記為已讀',
      pre='使用者 P 的學習火種徽章達到第 2 級',
      steps='1. POST /api/user/mark_badge_seen，badge_id=streak_01、level=2\n2. GET /api/user/profile_data/{P}',
      expect='1. HTTP 200，「徽章彈窗已標記為看過」\n2. notified_levels={"streak_01": 2}（同一級不再重複跳出）')
def _(c):
    u = STATE['profile']
    r = SC.post('/api/user/mark_badge_seen', json={'user_id': u['id'], 'badge_id': 'streak_01', 'level': 2})
    nl = J(SC.get(f'/api/user/profile_data/{u["id"]}')).get('notified_levels')
    c.log(f'1. {http(r, "message")}；2. notified_levels={_fmt(nl)}')
    check(r.status_code == 200 and nl == {'streak_01': 2}, '已讀標記失敗')


@case('A05', '依日語程度發放程度認證徽章',
      pre='系統已建立程度徽章（新手上路、生活達人…）；使用者 P 程度 N4、尚無徽章',
      steps='1. POST /api/user/grant_initial_badges，level=N4\n2. 再呼叫一次\n3. GET /api/user/achievements/{P}',
      expect='1. HTTP 200，granted=[新手上路, 生活達人]\n2. granted=[]（不重複發放）\n3. general 徽章列表含這 2 枚')
def _(c):
    u = STATE['profile']
    r1 = SC.post('/api/user/grant_initial_badges', json={'user_id': u['id'], 'level': 'N4'})
    r2 = SC.post('/api/user/grant_initial_badges', json={'user_id': u['id'], 'level': 'N4'})
    names = sorted(b['name'] for b in J(SC.get(f'/api/user/achievements/{u["id"]}')).get('general', []))
    c.log(f'1. {http(r1, "granted")}；2. {http(r2, "granted")}；3. general={names}')
    check(r1.status_code == 200 and J(r1).get('granted') == ['新手上路', '生活達人'], '首次發放不正確')
    check(J(r2).get('granted') == [], '重複發放徽章')
    check(names == sorted(['新手上路', '生活達人']), '徽章列表不正確')


@case('A05', '集滿主題收集冊解鎖主題徽章',
      pre='使用者已拍照解鎖「便利商店」主題全部官方單字（直接寫入解鎖紀錄模擬）',
      steps='1. POST /api/scenario/claim_theme_reward，scene_id=便利商店、tier=complete\n2. GET /api/user/achievements/{user_id}\n3. 再領一次',
      expect='1. HTTP 200，badge_name=便利商店達人、pts_earned=100、bonus_photo=3\n2. 主題徽章「便利商店達人」unlocked=true、theme_unlocked=1\n3. HTTP 400，「這個獎勵已經領過了」')
def _(c):
    u = register('theme')
    with S.app_context():
        scene = Scene.query.filter_by(name='便利商店').first()
        if not scene:
            raise RuntimeError('前置作業失敗：沒有「便利商店」主題（app.py 種入失敗）')
        official = Vocab.query.filter_by(scene_id=scene.id, source='admin').all()
        for v in official:
            db.session.add(UserVocab(user_id=u['id'], vocab_id=v.id, collected_at=None))
        db.session.commit()
        sid, total = scene.id, len(official)
    STATE['theme_scene'] = sid
    r1 = SC.post('/api/scenario/claim_theme_reward', json={'user_id': u['id'], 'scene_id': sid, 'tier': 'complete'})
    ach = J(SC.get(f'/api/user/achievements/{u["id"]}'))
    badge = next((t for t in ach.get('theme', []) if t['name'] == '便利商店達人'), {})
    r3 = SC.post('/api/scenario/claim_theme_reward', json={'user_id': u['id'], 'scene_id': sid, 'tier': 'complete'})
    c.log(f'官方單字 {total} 個全部解鎖；1. {http(r1, "badge_name", "pts_earned", "bonus_photo", "j_pts")}；'
          f'2. 便利商店達人 unlocked={badge.get("unlocked")}、theme_unlocked={ach.get("theme_unlocked")}；3. {http(r3, "error")}')
    check(total > 0, '主題沒有官方單字')
    check(r1.status_code == 200 and J(r1).get('badge_name') == '便利商店達人' and J(r1).get('pts_earned') == 100
          and J(r1).get('bonus_photo') == 3, '領取獎勵失敗')
    check(badge.get('unlocked') is True and ach.get('theme_unlocked') == 1, '主題徽章未解鎖')
    check(r3.status_code == 400 and J(r3).get('error') == '這個獎勵已經領過了', '可重複領取')


@case('A05', '主題收集未達條件不可領取獎勵',
      pre='新使用者尚未解鎖「便利商店」任何單字',
      steps='POST /api/scenario/claim_theme_reward，scene_id=便利商店、tier=half',
      expect='HTTP 400，「這個主題還沒達到領取條件」，不發點數')
def _(c):
    u = register('themeno')
    r = SC.post('/api/scenario/claim_theme_reward', json={'user_id': u['id'], 'scene_id': STATE['theme_scene'], 'tier': 'half'})
    row = user_row(u['id'])
    c.log(http(r, 'error', 'unlocked', 'total') + f'；j_pts={row["j_pts"]}')
    check(r.status_code == 400 and J(r).get('error') == '這個主題還沒達到領取條件' and row['j_pts'] == 0, '未正確拒絕')


# ======================================================================
# A06 社群互動：好友與學習小組
# ======================================================================
@case('A06', '以好友代碼搜尋使用者',
      pre='使用者 F2 已註冊，擁有 8 碼好友代碼',
      steps='F1 呼叫 POST /api/user/search_friend，friend_id=F2 的好友代碼',
      expect='HTTP 200，回傳 F2 的 user_id、email、friend_id、avatar')
def _(c):
    f1, f2, f3 = register('friend1'), register('friend2'), register('friend3')
    STATE.update(f1=f1, f2=f2, f3=f3)
    r = SC.post('/api/user/search_friend', json={'friend_id': f2['friend_id']})
    c.log(http(r, 'user_id', 'email', 'friend_id'))
    check(r.status_code == 200 and J(r).get('user_id') == f2['id'] and J(r).get('friend_id') == f2['friend_id'], '搜尋結果不正確')


@case('A06', '搜尋不存在的好友代碼',
      pre='好友代碼 ZZZZ0000 不存在',
      steps='POST /api/user/search_friend，friend_id=ZZZZ0000',
      expect='HTTP 404，「找不到此 ID 的用戶」')
def _(c):
    r = SC.post('/api/user/search_friend', json={'friend_id': 'ZZZZ0000'})
    c.log(http(r, 'error'))
    check(r.status_code == 404 and '找不到此 ID 的用戶' in (J(r).get('error') or ''), '未回傳 404')


@case('A06', '送出交友邀請',
      pre='F1 與 F2 尚非好友',
      steps='1. POST /api/user/friend_request/send，sender_id=F1、receiver_id=F2\n2. GET /api/user/friend_request/pending/{F2}',
      expect='1. HTTP 201，「邀請已順利送出！」\n2. F2 的待處理邀請中有 F1')
def _(c):
    f1, f2 = STATE['f1'], STATE['f2']
    r = SC.post('/api/user/friend_request/send', json={'sender_id': f1['id'], 'receiver_id': f2['id']})
    pend = J(SC.get(f'/api/user/friend_request/pending/{f2["id"]}')).get('pending_requests', [])
    c.log(f'1. {http(r, "message")}；2. F2 待處理邀請寄件者={[p["sender_id"] for p in pend]}（F1={f1["id"]}）')
    check(r.status_code == 201, '送出邀請失敗')
    check([p['sender_id'] for p in pend] == [f1['id']], '對方未收到邀請')
    STATE['req_f1_f2'] = pend[0]['request_id']


@case('A06', '重複送出交友邀請被拒',
      pre='F1 已向 F2 送出邀請且尚未處理',
      steps='再次 POST /api/user/friend_request/send，sender_id=F1、receiver_id=F2',
      expect='HTTP 400，「已經發送過邀請，請靜候對方同意喔！」')
def _(c):
    f1, f2 = STATE['f1'], STATE['f2']
    r = SC.post('/api/user/friend_request/send', json={'sender_id': f1['id'], 'receiver_id': f2['id']})
    c.log(http(r, 'error'))
    check(r.status_code == 400 and J(r).get('error') == '已經發送過邀請，請靜候對方同意喔！', '未擋下重複邀請')


@case('A06', '接受交友邀請成為雙向好友',
      pre='F2 收到 F1 的交友邀請',
      steps='1. POST /api/user/friend_request/respond，request_id、action=accept\n2. GET /api/user/friends/{F1}、GET /api/user/friends/{F2}',
      expect='1. HTTP 200，「已接受邀請！」\n2. F1 的好友有 F2、F2 的好友有 F1')
def _(c):
    f1, f2 = STATE['f1'], STATE['f2']
    r = SC.post('/api/user/friend_request/respond', json={'request_id': STATE['req_f1_f2'], 'action': 'accept'})
    l1 = [f['user_id'] for f in friends_of(f1)]
    l2 = [f['user_id'] for f in friends_of(f2)]
    c.log(f'1. {http(r, "message")}；2. F1 好友={l1}、F2 好友={l2}')
    check(r.status_code == 200 and J(r).get('message') == '已接受邀請！', '接受邀請失敗')
    check(l1 == [f2['id']] and l2 == [f1['id']], '未建立雙向好友關係')


@case('A06', '拒絕交友邀請',
      pre='F3 向 F1 送出交友邀請',
      steps='1. POST /api/user/friend_request/respond，action=reject\n2. 查詢 F1 好友列表與待處理邀請',
      expect='1. HTTP 200，「已拒絕邀請！」\n2. F1 好友列表沒有 F3，待處理邀請為空')
def _(c):
    f1, f3 = STATE['f1'], STATE['f3']
    SC.post('/api/user/friend_request/send', json={'sender_id': f3['id'], 'receiver_id': f1['id']})
    req = J(SC.get(f'/api/user/friend_request/pending/{f1["id"]}'))['pending_requests'][0]
    r = SC.post('/api/user/friend_request/respond', json={'request_id': req['request_id'], 'action': 'reject'})
    fl = [f['user_id'] for f in friends_of(f1)]
    pend = J(SC.get(f'/api/user/friend_request/pending/{f1["id"]}')).get('pending_requests', [])
    c.log(f'1. {http(r, "message")}；2. F1 好友={fl}、待處理邀請 {len(pend)} 筆')
    check(r.status_code == 200 and J(r).get('message') == '已拒絕邀請！', '拒絕失敗')
    check(f3['id'] not in fl and not pend, '拒絕後仍成為好友或邀請未處理')


@case('A06', '已是好友再送邀請被拒',
      pre='F1 與 F2 已是好友',
      steps='POST /api/user/friend_request/send，sender_id=F1、receiver_id=F2',
      expect='HTTP 400，「你們已經是好友了！」')
def _(c):
    r = SC.post('/api/user/friend_request/send', json={'sender_id': STATE['f1']['id'], 'receiver_id': STATE['f2']['id']})
    c.log(http(r, 'error'))
    check(r.status_code == 400 and J(r).get('error') == '你們已經是好友了！', '未擋下')


@case('A06', '設定好友暱稱（備註）',
      pre='F1 與 F2 已是好友',
      steps='1. POST /api/user/friend/update_nickname，user_id=F1、friend_id=F2 的好友代碼、nickname=小花\n2. 查詢 F1、F2 的好友列表',
      expect='1. HTTP 200，「暱稱已更新」\n2. F1 看到 F2 的 nickname=小花；F2 端不受影響（nickname 為空）')
def _(c):
    f1, f2 = STATE['f1'], STATE['f2']
    r = SC.post('/api/user/friend/update_nickname', json={'user_id': f1['id'], 'friend_id': f2['friend_id'], 'nickname': '小花'})
    n1 = [f['nickname'] for f in friends_of(f1)]
    n2 = [f['nickname'] for f in friends_of(f2)]
    c.log(f'1. {http(r, "message")}；2. F1 端暱稱={n1}、F2 端暱稱={n2}')
    check(r.status_code == 200 and n1 == ['小花'] and n2 == [None], '暱稱設定不正確')


@case('A06', '刪除好友',
      pre='F1 與 F2 已是好友',
      steps='1. POST /api/user/friend/delete，user_id=F1、friend_id=F2 的好友代碼\n2. 查詢雙方好友列表\n3. 再刪一次',
      expect='1. HTTP 200，「好友已成功刪除」\n2. 雙方好友列表皆不再有對方\n3. HTTP 404，「找不到好友紀錄」')
def _(c):
    f1, f2 = STATE['f1'], STATE['f2']
    r1 = SC.post('/api/user/friend/delete', json={'user_id': f1['id'], 'friend_id': f2['friend_id']})
    l1, l2 = friends_of(f1), friends_of(f2)
    r3 = SC.post('/api/user/friend/delete', json={'user_id': f1['id'], 'friend_id': f2['friend_id']})
    c.log(f'1. {http(r1, "message")}；2. F1 好友 {len(l1)} 人、F2 好友 {len(l2)} 人；3. {http(r3, "error")}')
    check(r1.status_code == 200 and not l1 and not l2, '刪除好友失敗')
    check(r3.status_code == 404 and J(r3).get('error') == '找不到好友紀錄', '重複刪除未回傳 404')


@case('A06', '建立學習小組並邀請好友',
      pre='免費會員 G1 本週尚未建立或加入小組；好友 G2、G3',
      steps='1. POST /api/group/create，user_id=G1、name=週末讀書會、goal_type=scans、goal_target=30、friend_ids=[G2, G3 好友代碼]\n2. GET /api/group/my_group/{G1}\n3. GET /api/group/invites/{G2}',
      expect='1. HTTP 201，「小組建立成功，已發送邀請給好友！」，免押金（new_j_pts 維持 0）\n2. has_group=true、成員 1 人、邀請中 2 人\n3. G2 收到「週末讀書會」邀請')
def _(c):
    g1, g2, g3 = register('group1'), register('group2'), register('group3')
    STATE.update(g1=g1, g2=g2, g3=g3)
    r = SC.post('/api/group/create', json={'user_id': g1['id'], 'name': '週末讀書會', 'goal_type': 'scans',
                                           'goal_target': 30, 'friend_ids': [g2['friend_id'], g3['friend_id']]})
    mg = my_group(g1)
    inv = J(SC.get(f'/api/group/invites/{g2["id"]}')).get('invites', [])
    c.log(f'1. {http(r, "message", "group_id", "new_j_pts")}；2. has_group={mg.get("has_group")}、成員 {len(mg.get("members", []))} 人、'
          f'邀請中 {len(mg.get("pending_invites", []))} 人；3. G2 收到邀請={[i["group_name"] for i in inv]}')
    check(r.status_code == 201 and J(r).get('new_j_pts') == 0, '建立小組失敗')
    check(mg.get('has_group') and len(mg.get('members', [])) == 1 and len(mg.get('pending_invites', [])) == 2, '小組資料不正確')
    check([i['group_name'] for i in inv] == ['週末讀書會'], '好友未收到邀請')


@case('A06', '接受小組邀請加入小組',
      pre='G2 收到 G1 的小組邀請',
      steps='1. POST /api/group/respond_invite，invite_id、action=accept、user_id=G2\n2. GET /api/group/my_group/{G1}',
      expect='1. HTTP 200，「已成功加入小組！」\n2. 小組成員 2 人')
def _(c):
    r = accept_group_invite(STATE['g2'])
    mg = my_group(STATE['g1'])
    c.log(f'1. {http(r, "message", "new_j_pts")}；2. 成員 {len(mg.get("members", []))} 人')
    check(r.status_code == 200 and J(r).get('message') == '已成功加入小組！', '加入失敗')
    check(len(mg.get('members', [])) == 2, '成員數不正確')


@case('A06', '拒絕小組邀請',
      pre='G3 收到 G1 的小組邀請',
      steps='1. POST /api/group/respond_invite，action=reject、user_id=G3\n2. GET /api/group/my_group/{G3}、GET /api/group/invites/{G3}',
      expect='1. HTTP 200，「已拒絕邀請」\n2. G3 has_group=false，待處理邀請為空')
def _(c):
    g3 = STATE['g3']
    inv = J(SC.get(f'/api/group/invites/{g3["id"]}'))['invites'][0]
    r = SC.post('/api/group/respond_invite', json={'invite_id': inv['invite_id'], 'action': 'reject', 'user_id': g3['id']})
    mg = my_group(g3)
    left = J(SC.get(f'/api/group/invites/{g3["id"]}')).get('invites', [])
    c.log(f'1. {http(r, "message")}；2. has_group={mg.get("has_group")}、待處理邀請 {len(left)} 筆')
    check(r.status_code == 200 and J(r).get('message') == '已拒絕邀請', '拒絕失敗')
    check(mg.get('has_group') is False and not left, '拒絕後狀態不正確')


@case('A06', '小組共同目標進度追蹤',
      pre='「週末讀書會」目標為拍照 30 次，目前進度 0；成員 G2',
      steps='1. G2 POST /api/user/increment_scan（拍照 1 次）\n2. GET /api/group/my_group/{G1}',
      expect='小組 current_progress=1，G2 的個人貢獻 group_scans=1')
def _(c):
    scan(STATE['g2'])
    mg = my_group(STATE['g1'])
    contrib = {m['user_id']: m['group_scans'] for m in mg.get('members', [])}
    g1_id, g2_id = STATE['g1']['id'], STATE['g2']['id']
    c.log(f'current_progress={mg.get("current_progress")}/{mg.get("goal_target")}，個人拍照貢獻 G1={contrib.get(g1_id)}、G2={contrib.get(g2_id)}')
    check(mg.get('current_progress') == 1 and contrib.get(g2_id) == 1, '進度未累計')


@case('A06', '小組人數上限 5 人',
      pre='隊長 H 建立小組並邀請 5 位使用者，其中 4 位已接受（小組共 5 人）',
      steps='第 5 位受邀者 POST /api/group/respond_invite，action=accept',
      expect='HTTP 400，「這個小組已經客滿了！」；小組維持 5 人，該使用者未加入')
def _(c):
    h = register('host')
    invitees = [register(f'inv{i}') for i in range(1, 6)]
    SC.post('/api/group/create', json={'user_id': h['id'], 'name': '五人小隊', 'goal_type': 'scans', 'goal_target': 30,
                                       'friend_ids': [x['friend_id'] for x in invitees]})
    codes = [accept_group_invite(x).status_code for x in invitees[:4]]
    r = accept_group_invite(invitees[4])
    members = len(my_group(h).get('members', []))
    joined = my_group(invitees[4]).get('has_group')
    c.log(f'前 4 位接受狀態碼={codes}；第 5 位 {http(r, "error")}；小組成員 {members} 人；第 5 位 has_group={joined}')
    check(codes == [200] * 4, '前置作業：前 4 位未全部加入')
    check(r.status_code == 400 and J(r).get('error') == '這個小組已經客滿了！', '未擋下第 6 人')
    check(members == 5 and joined is False, '人數上限失效')


@case('A06', '免費會員每週 1 次免押金',
      pre='免費會員 Q（0 點）本週第一次建立小組',
      steps='1. POST /api/group/create\n2. GET /api/group/check_quota/{Q}\n3. 將小組建立時間改為上週並開啟小組頁觸發結算（模擬一週挑戰結束）\n4. 本週再 POST /api/group/create',
      expect='1. HTTP 201，免押金（new_j_pts=0）\n2. free_quota=1、free_used=1、remaining_free=0\n4. HTTP 400，「本週免費額度（1 次）已用完，且點數不足 20 點押金！」')
def _(c):
    q = register('quotaQ')
    STATE['quotaQ'] = q
    r1 = SC.post('/api/group/create', json={'user_id': q['id'], 'name': 'Q 的小組1', 'goal_type': 'scans', 'goal_target': 30})
    quota = J(SC.get(f'/api/group/check_quota/{q["id"]}'))
    r3 = expire_group_of(q)
    r4 = SC.post('/api/group/create', json={'user_id': q['id'], 'name': 'Q 的小組2', 'goal_type': 'scans', 'goal_target': 30})
    c.log(f'1. {http(r1, "new_j_pts")}；2. {_fmt(quota)}；3. 結算 {http(r3, "just_expired", "message")}；4. {http(r4, "error")}')
    check(r1.status_code == 201 and J(r1).get('new_j_pts') == 0, '第一次未免押金')
    check(quota.get('free_quota') == 1 and quota.get('free_used') == 1 and quota.get('remaining_free') == 0, '額度統計不正確')
    check(J(r3).get('just_expired') is True, '前置結算失敗')
    check(r4.status_code == 400 and J(r4).get('error') == '本週免費額度（1 次）已用完，且點數不足 20 點押金！', '未要求押金')


@case('A06', '免費額度用完後支付 20 點押金加入',
      pre='Q 本週免費額度已用完，購買 30 點',
      steps='1. POST /api/group/create\n2. GET /api/user/transactions/{Q}',
      expect='1. HTTP 201，扣除押金 20 點（new_j_pts=10）\n2. 交易紀錄有一筆 -20 點（related_feature=group_deposit_free）')
def _(c):
    q = STATE['quotaQ']
    SC.post('/api/user/add_points', json={'user_id': q['id'], 'points': 30, 'price': 0, 'payment_method': 'credit_card'})
    r = SC.post('/api/group/create', json={'user_id': q['id'], 'name': 'Q 的小組3', 'goal_type': 'scans', 'goal_target': 30})
    tx = J(SC.get(f'/api/user/transactions/{q["id"]}')).get('transactions', [])
    dep = [t for t in tx if t['related_feature'] == 'group_deposit_free']
    c.log(f'1. {http(r, "message", "new_j_pts")}；2. 押金交易={[(t["points"], t["related_feature"]) for t in dep]}')
    check(r.status_code == 201 and J(r).get('new_j_pts') == 10, '押金扣除不正確')
    check([t['points'] for t in dep] == [-20], '缺少押金交易紀錄')


@case('A06', '小組挑戰成功結算退還押金並發放獎勵',
      pre='Q 已付 20 點押金加入小組（目標拍照 30 次，標準難度），目前餘額 10 點；小組進度已達標',
      steps='將小組建立時間改為上週（模擬一週結束），GET /api/group/my_group/{Q} 觸發結算',
      expect='回傳 just_expired=true、訊息含「挑戰成功」；退還押金 20 點並發放完成獎勵 5 點（付押金之免費會員、標準難度），new_j_pts=35；小組解散')
def _(c):
    q = STATE['quotaQ']
    r = expire_group_of(q, reach_goal=True)
    d = J(r)
    after = my_group(q)
    c.log(f'{http(r, "just_expired", "message", "new_j_pts")}；結算後 has_group={after.get("has_group")}')
    check(d.get('just_expired') is True and '挑戰成功' in (d.get('message') or ''), '未結算或判定失敗')
    check(d.get('new_j_pts') == 35, f'點數不正確（{d.get("new_j_pts")}）')
    check(after.get('has_group') is False, '小組未解散')


@case('A06', '訂閱會員每週 3 次免押金，第 4 次押金 10 點',
      pre='使用者 R 訂閱月繳方案（獲贈 20 點），本週尚未參加小組',
      steps='1. GET /api/group/check_quota/{R}\n2. 連續 3 次：POST /api/group/create 後模擬一週結束結算\n3. 第 4 次 POST /api/group/create',
      expect='1. free_quota=3\n2. 3 次皆 HTTP 201 且免押金（new_j_pts 維持 20）\n3. HTTP 201，扣押金 10 點（new_j_pts=10）')
def _(c):
    rr = register('premiumR')
    subscribe(rr)
    quota = J(SC.get(f'/api/group/check_quota/{rr["id"]}'))
    pts = []
    for i in range(3):
        r = SC.post('/api/group/create', json={'user_id': rr['id'], 'name': f'R 的小組{i + 1}', 'goal_type': 'scans', 'goal_target': 30})
        pts.append((r.status_code, J(r).get('new_j_pts')))
        expire_group_of(rr)
    r4 = SC.post('/api/group/create', json={'user_id': rr['id'], 'name': 'R 的小組4', 'goal_type': 'scans', 'goal_target': 30})
    c.log(f'1. free_quota={quota.get("free_quota")}；2. 前 3 次（狀態碼, 餘額）={pts}；3. {http(r4, "new_j_pts")}')
    check(quota.get('free_quota') == 3, '訂閱會員免費額度不是 3')
    check(pts == [(201, 20)] * 3, '前 3 次未免押金')
    check(r4.status_code == 201 and J(r4).get('new_j_pts') == 10, '第 4 次押金不是 10 點')


# ======================================================================
# A07 訂閱與點數
# ======================================================================
@case('A07', '取得訂閱方案',
      pre='系統啟動時已建立月訂閱、年訂閱方案',
      steps='GET /api/subscription/plans',
      expect='HTTP 200，回傳 2 個方案：月訂閱 NT$149（贈 20 點）、年訂閱 NT$1290（贈 300 點），功能清單含「每天10次拍照辨識」「每天10次AI對話」')
def _(c):
    r = SC.get('/api/subscription/plans')
    plans = {p['name']: p for p in J(r).get('plans', [])}
    m, y = plans.get('Premium Pro 月訂閱', {}), plans.get('Premium Pro 年訂閱', {})
    c.log(f'HTTP {r.status_code}，方案={list(plans)}；月訂閱 price_monthly={m.get("price_monthly")}、贈點={m.get("points_grant_monthly")}；'
          f'年訂閱 price_yearly={y.get("price_yearly")}、贈點={y.get("points_grant_yearly")}；功能={m.get("features")}')
    check(r.status_code == 200 and len(plans) == 2, '方案數量不正確')
    check(m.get('price_monthly') == 149 and m.get('points_grant_monthly') == 20, '月訂閱資料不正確')
    check(y.get('price_yearly') == 1290 and y.get('points_grant_yearly') == 300, '年訂閱資料不正確')
    check('每天10次拍照辨識' in (m.get('features') or []) and '每天10次AI對話' in (m.get('features') or []), '功能清單不正確')


@case('A07', '取得點數購買方案',
      pre='系統啟動時已建立入門包、中包、大包',
      steps='GET /api/store/packages',
      expect='HTTP 200，依價格排序回傳：入門包 70 點／NT$50、中包 140 點／NT$90、大包 380 點／NT$170')
def _(c):
    r = SC.get('/api/store/packages')
    pk = [(p['name'], p['points'], p['price']) for p in J(r).get('packages', [])]
    c.log(f'HTTP {r.status_code}，packages={pk}')
    check(r.status_code == 200 and pk == [('入門包', 70, 50), ('中包', 140, 90), ('大包', 380, 170)], '點數方案不正確')


@case('A07', '啟用 7 天免費試用',
      pre='使用者 T1 從未試用、無訂閱',
      steps='1. POST /api/subscription/trial，user_id=T1\n2. GET /api/subscription/status/{T1}',
      expect='1. HTTP 200，「免費試用已啟用（7 天）」、is_premium=true、到期日為 7 天後\n2. subscription.status=trial、trial_used=true')
def _(c):
    t1 = register('trial')
    STATE['trial'] = t1
    r = SC.post('/api/subscription/trial', json={'user_id': t1['id']})
    st = J(SC.get(f'/api/subscription/status/{t1["id"]}'))
    days = (datetime.fromisoformat(J(r)['end_date']) - datetime.utcnow()).total_seconds() / 86400 if J(r).get('end_date') else None
    c.log(f'1. {http(r, "message", "is_premium")}，距到期約 {days:.2f} 天；2. status={(st.get("subscription") or {}).get("status")}、'
          f'trial_used={st.get("trial_used")}' if days is not None else http(r))
    check(r.status_code == 200 and J(r).get('is_premium') is True, '試用啟用失敗')
    check(days is not None and 6.99 < days <= 7.0, '試用期不是 7 天')
    check((st.get('subscription') or {}).get('status') == 'trial' and st.get('trial_used') is True, '訂閱狀態不正確')


@case('A07', '免費試用一生限一次',
      pre='T1 已使用過試用',
      steps='1. 試用期間再 POST /api/subscription/trial\n2. 取消並將試用改為已到期（模擬 7 天後），GET /api/subscription/status/{T1}\n3. 試用到期後再 POST /api/subscription/trial',
      expect='1. HTTP 400，「您已使用過免費試用」\n2. is_premium=false\n3. HTTP 400，「您已使用過免費試用」')
def _(c):
    t1 = STATE['trial']
    r1 = SC.post('/api/subscription/trial', json={'user_id': t1['id']})
    SC.post(f'/api/subscription/cancel/{t1["id"]}')
    with S.app_context():
        sub = UserSubscription.query.filter_by(user_id=t1['id']).first()
        sub.end_date = datetime.utcnow() - timedelta(days=1)
        sub.start_date = datetime.utcnow() - timedelta(days=8)
        db.session.commit()
    st = J(SC.get(f'/api/subscription/status/{t1["id"]}'))
    r3 = SC.post('/api/subscription/trial', json={'user_id': t1['id']})
    c.log(f'1. {http(r1, "error")}；2. is_premium={st.get("is_premium")}；3. {http(r3, "error")}')
    check(r1.status_code == 400 and J(r1).get('error') == '您已使用過免費試用', '試用期間可重複申請')
    check(st.get('is_premium') is False, '試用到期後仍為 Premium')
    check(r3.status_code == 400 and J(r3).get('error') == '您已使用過免費試用', '到期後可再次試用')


@case('A07', '訂閱月繳方案',
      pre='使用者 T2 為免費會員、0 點',
      steps='1. POST /api/subscription/subscribe，plan_id=月訂閱、billing_cycle=monthly\n2. GET /api/subscription/status/{T2}\n3. GET /api/user/transactions/{T2}',
      expect='1. HTTP 200，「訂閱成功！」、is_premium=true、贈送 20 點、到期日為 30 天後\n2. status=active\n3. 有一筆 +20 點訂閱贈點（subscription_grant）')
def _(c):
    t2 = register('sub')
    STATE['sub'] = t2
    r = subscribe(t2)
    d = J(r)
    st = J(SC.get(f'/api/subscription/status/{t2["id"]}'))
    tx = J(SC.get(f'/api/user/transactions/{t2["id"]}')).get('transactions', [])
    days = (datetime.fromisoformat(d['end_date']) - datetime.utcnow()).total_seconds() / 86400 if d.get('end_date') else 0
    c.log(f'1. {http(r, "message", "is_premium", "points_granted", "total_points")}，距到期約 {days:.2f} 天；'
          f'2. status={(st.get("subscription") or {}).get("status")}；3. 交易={[(t["points"], t["transaction_type"]) for t in tx]}')
    check(r.status_code == 200 and d.get('is_premium') is True and d.get('points_granted') == 20, '訂閱失敗')
    check(29.99 < days <= 30.0, '訂閱期不是 30 天')
    check((st.get('subscription') or {}).get('status') == 'active', '狀態不是 active')
    check([(t['points'], t['transaction_type']) for t in tx] == [(20, 'subscription_grant')], '贈點交易不正確')


@case('A07', '取消訂閱（效期保留至到期日）',
      pre='T2 訂閱中（月繳、自動續訂）',
      steps='1. POST /api/subscription/cancel/{T2}\n2. GET /api/subscription/status/{T2}',
      expect='1. HTTP 200，「已取消自動續訂，訂閱效期至 YYYY-MM-DD」\n2. is_premium 仍為 true、status=cancelled、auto_renew=false')
def _(c):
    t2 = STATE['sub']
    r = SC.post(f'/api/subscription/cancel/{t2["id"]}')
    st = J(SC.get(f'/api/subscription/status/{t2["id"]}'))
    sub = st.get('subscription') or {}
    c.log(f'1. {http(r, "message", "status")}；2. is_premium={st.get("is_premium")}、status={sub.get("status")}、auto_renew={sub.get("auto_renew")}')
    check(r.status_code == 200 and (J(r).get('message') or '').startswith('已取消自動續訂，訂閱效期至'), '取消失敗')
    check(st.get('is_premium') is True and sub.get('status') == 'cancelled' and sub.get('auto_renew') is False, '取消後狀態不正確')


@case('A07', '沒有有效訂閱時取消被拒',
      pre='T2 已取消自動續訂',
      steps='再次 POST /api/subscription/cancel/{T2}',
      expect='HTTP 404，「找不到有效訂閱」')
def _(c):
    r = SC.post(f'/api/subscription/cancel/{STATE["sub"]["id"]}')
    c.log(http(r, 'error'))
    check(r.status_code == 404 and J(r).get('error') == '找不到有效訂閱', '未正確拒絕')


@case('A07', '購買點數（加點）',
      pre='使用者 P1 為 0 點',
      steps='POST /api/user/add_points，points=140、price=90、payment_method=google_pay',
      expect='HTTP 200，「成功儲值 140 點！」、total_points=140')
def _(c):
    p1 = register('points')
    STATE['points'] = p1
    r = SC.post('/api/user/add_points', json={'user_id': p1['id'], 'points': 140, 'price': 90, 'payment_method': 'google_pay'})
    c.log(http(r, 'message', 'total_points'))
    check(r.status_code == 200 and J(r).get('total_points') == 140 and J(r).get('message') == '成功儲值 140 點！', '加點失敗')


@case('A07', '加點數量不合法被拒',
      pre='P1 目前 140 點',
      steps='1. POST /api/user/add_points，points=0\n2. POST /api/user/add_points，points=-50',
      expect='兩次皆 HTTP 400，「缺少使用者 ID 或點數數量錯誤」；點數維持 140')
def _(c):
    p1 = STATE['points']
    r1 = SC.post('/api/user/add_points', json={'user_id': p1['id'], 'points': 0})
    r2 = SC.post('/api/user/add_points', json={'user_id': p1['id'], 'points': -50})
    pts = user_row(p1['id'])['j_pts']
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}；j_pts={pts}')
    check(r1.status_code == 400 and r2.status_code == 400 and pts == 140, '未擋下不合法點數')


@case('A07', '消費點數兌換加購次數（扣點）',
      pre='P1 有 140 點',
      steps='POST /api/user/spend_points，feature=ai_extra',
      expect='HTTP 200，扣除 60 點（餘額 80）、effect=「+5 次 AI 對話（永久）」；資料庫 ai_extra_count=5')
def _(c):
    p1 = STATE['points']
    r = SC.post('/api/user/spend_points', json={'user_id': p1['id'], 'feature': 'ai_extra'})
    row = user_row(p1['id'])
    c.log(http(r, 'message', 'total_points', 'effect') + f'；資料庫 ai_extra_count={row["ai_extra_count"]}')
    check(r.status_code == 200 and J(r).get('total_points') == 80 and J(r).get('effect') == '+5 次 AI 對話（永久）', '扣點失敗')
    check(row['ai_extra_count'] == 5, '加購次數未增加')


@case('A07', '點數不足時扣點被拒',
      pre='使用者 P2 只有 10 點',
      steps='POST /api/user/spend_points，feature=photo_extra（需 60 點）',
      expect='HTTP 400，「點數不足，需要 60 點」；點數維持 10，不產生消費紀錄')
def _(c):
    p2 = register('poor')
    SC.post('/api/user/add_points', json={'user_id': p2['id'], 'points': 10, 'price': 0, 'payment_method': 'credit_card'})
    r = SC.post('/api/user/spend_points', json={'user_id': p2['id'], 'feature': 'photo_extra'})
    pts = user_row(p2['id'])['j_pts']
    n_spend = count(PointTransaction, user_id=p2['id'], transaction_type='spend')
    c.log(http(r, 'error') + f'；j_pts={pts}、消費紀錄 {n_spend} 筆')
    check(r.status_code == 400 and J(r).get('error') == '點數不足，需要 60 點', '未擋下')
    check(pts == 10 and n_spend == 0, '點數或紀錄被異動')


@case('A07', '查詢點數交易紀錄',
      pre='P1 有 1 筆購點（+140）與 1 筆消費（-60）',
      steps='GET /api/user/transactions/{P1}',
      expect='HTTP 200，依時間新到舊列出 2 筆：-60（spend，ai_extra）、+140（purchase，google_pay，NT$90）')
def _(c):
    r = SC.get(f'/api/user/transactions/{STATE["points"]["id"]}')
    tx = [(t['points'], t['transaction_type'], t['related_feature'] or t['payment_method'], t['price'])
          for t in J(r).get('transactions', [])]
    c.log(f'HTTP {r.status_code}，transactions={tx}')
    check(r.status_code == 200 and tx == [(-60, 'spend', 'ai_extra', 0), (140, 'purchase', 'google_pay', 90)], '交易紀錄不正確')


@case('A07', '免費會員每日拍照額度 2 次',
      pre='免費會員 U1 今日尚未拍照',
      steps='1. POST /api/user/increment_scan 三次\n2. GET /api/user/usage_status/{U1}',
      expect='1. 前 2 次 HTTP 200（daily_scans=1、2，daily_limit=2）；第 3 次 HTTP 403「今日拍照次數已用完，請花 60 點加購 5 次」\n2. photo_count_today=2、photo_daily_limit=2')
def _(c):
    u1 = register('freeU')
    STATE['freeU'] = u1
    rs = [scan(u1) for _ in range(3)]
    st = usage(u1)
    c.log(f'1. ' + '；'.join(http(r, 'daily_scans', 'daily_limit', 'error') for r in rs)
          + f'；2. photo_count_today={st.get("photo_count_today")}、photo_daily_limit={st.get("photo_daily_limit")}')
    check([r.status_code for r in rs] == [200, 200, 403], '額度判斷不正確')
    check(J(rs[2]).get('error') == '今日拍照次數已用完，請花 60 點加購 5 次', '錯誤訊息不正確')
    check(st.get('photo_count_today') == 2 and st.get('photo_daily_limit') == 2, '使用量不正確')


@case('A07', '每日拍照額度用完後使用加購次數',
      pre='U1 今日 2 次已用完；購買 60 點後兌換拍照加購（+5 次）',
      steps='1. POST /api/user/spend_points，feature=photo_extra\n2. POST /api/user/increment_scan',
      expect='1. HTTP 200，effect=「+5 次拍照（永久）」\n2. HTTP 200，daily_scans=3、extra_count 由 5 變 4')
def _(c):
    u1 = STATE['freeU']
    SC.post('/api/user/add_points', json={'user_id': u1['id'], 'points': 60, 'price': 50, 'payment_method': 'credit_card'})
    r1 = SC.post('/api/user/spend_points', json={'user_id': u1['id'], 'feature': 'photo_extra'})
    r2 = scan(u1)
    c.log(f'1. {http(r1, "effect", "total_points")}；2. {http(r2, "daily_scans", "extra_count")}')
    check(r1.status_code == 200 and J(r1).get('effect') == '+5 次拍照（永久）', '兌換失敗')
    check(r2.status_code == 200 and J(r2).get('daily_scans') == 3 and J(r2).get('extra_count') == 4, '未使用加購次數')


@case('A07', '訂閱會員每日拍照額度 10 次',
      pre='使用者 U2 已訂閱月繳方案，今日尚未拍照',
      steps='1. POST /api/user/increment_scan 十一次\n2. GET /api/user/usage_status/{U2}',
      expect='1. 前 10 次 HTTP 200（daily_limit=10），第 11 次 HTTP 403\n2. photo_daily_limit=10、photo_count_today=10')
def _(c):
    u2 = register('premU')
    STATE['premU'] = u2
    subscribe(u2)
    codes = [scan(u2).status_code for _ in range(11)]
    st = usage(u2)
    c.log(f'1. 狀態碼={codes}；2. photo_count_today={st.get("photo_count_today")}、photo_daily_limit={st.get("photo_daily_limit")}')
    check(codes == [200] * 10 + [403], '訂閱會員拍照額度不是 10 次')
    check(st.get('photo_daily_limit') == 10 and st.get('photo_count_today') == 10, '使用量不正確')


@case('A07', '免費會員每日 AI 對話額度 3 次',
      pre='U1 今日尚未使用 AI 對話',
      steps='POST /api/user/use_ai 四次',
      expect='前 3 次 HTTP 200（daily_ai=1～3，daily_limit=3）；第 4 次 HTTP 403「今日 AI 對話次數已用完，請花 60 點加購 5 次」')
def _(c):
    u1 = STATE['freeU']
    rs = [use_ai(u1) for _ in range(4)]
    c.log('；'.join(http(r, 'daily_ai', 'daily_limit', 'error') for r in rs))
    check([r.status_code for r in rs] == [200, 200, 200, 403], 'AI 額度判斷不正確')
    check(J(rs[0]).get('daily_limit') == 3 and J(rs[3]).get('error') == '今日 AI 對話次數已用完，請花 60 點加購 5 次', '回傳資料不正確')


@case('A07', '訂閱會員每日 AI 對話額度 10 次',
      pre='U2 已訂閱，今日尚未使用 AI 對話',
      steps='POST /api/user/use_ai 十一次',
      expect='前 10 次 HTTP 200（daily_limit=10），第 11 次 HTTP 403',
      note='需求清單 A07 寫 Premium「無限 AI 對話」，程式與方案功能清單為「每天10次AI對話」，依本測試規格（訂閱 10 次）判定，需求清單文字需更新')
def _(c):
    u2 = STATE['premU']
    rs = [use_ai(u2) for _ in range(11)]
    c.log(f'狀態碼={[r.status_code for r in rs]}，daily_limit={J(rs[0]).get("daily_limit")}')
    check([r.status_code for r in rs] == [200] * 10 + [403] and J(rs[0]).get('daily_limit') == 10, '訂閱會員 AI 額度不是 10 次')


@case('A07', '跨日自動重置每日額度',
      pre='U1 今日拍照 3 次、AI 對話 3 次皆已用完；將最後重置日改為昨天（模擬隔天）',
      steps='1. GET /api/user/usage_status/{U1}\n2. POST /api/user/increment_scan',
      expect='1. photo_count_today=0、ai_count_today=0\n2. HTTP 200，daily_scans=1')
def _(c):
    u1 = STATE['freeU']
    set_user(u1['id'], last_reset_date=tw_today() - timedelta(days=1))
    st = usage(u1)
    r = scan(u1)
    c.log(f'1. photo_count_today={st.get("photo_count_today")}、ai_count_today={st.get("ai_count_today")}；2. {http(r, "daily_scans")}')
    check(st.get('photo_count_today') == 0 and st.get('ai_count_today') == 0, '跨日未重置')
    check(r.status_code == 200 and J(r).get('daily_scans') == 1, '重置後無法拍照')


@case('A07', '每日任務未完成不可領取獎勵',
      pre='使用者 U3 今日尚未拍照、未使用 AI 對話',
      steps='POST /api/daily/claim，user_id=U3',
      expect='HTTP 400，「今日任務尚未完成」')
def _(c):
    u3 = register('daily')
    STATE['daily'] = u3
    r = SC.post('/api/daily/claim', json={'user_id': u3['id']})
    c.log(http(r, 'error'))
    check(r.status_code == 400 and J(r).get('error') == '今日任務尚未完成', '未擋下')


@case('A07', '完成每日任務領取點數獎勵',
      pre='U3 今日完成拍照 1 次與 AI 對話 1 次（連續登入未滿 7 天）',
      steps='1. GET /api/daily/status?user_id=U3\n2. POST /api/daily/claim',
      expect='1. photo_done=true、ai_done=true、can_claim=true\n2. HTTP 200，「獎勵領取成功！」，隨機獲得 10～30 點並寫入交易紀錄（reward）')
def _(c):
    u3 = STATE['daily']
    scan(u3)
    use_ai(u3)
    st = J(SC.get(f'/api/daily/status?user_id={u3["id"]}'))
    r = SC.post('/api/daily/claim', json={'user_id': u3['id']})
    pts = J(r).get('pts_earned')
    row = user_row(u3['id'])
    n_tx = count(PointTransaction, user_id=u3['id'], transaction_type='reward', related_feature='daily_task_reward')
    STATE['daily_pts'] = row['j_pts']
    c.log(f'1. photo_done={st.get("photo_done")}、ai_done={st.get("ai_done")}、can_claim={st.get("can_claim")}；'
          f'2. {http(r, "message", "pts_earned", "j_pts")}；獎勵交易 {n_tx} 筆')
    check(st.get('can_claim') is True, '任務狀態不正確')
    check(r.status_code == 200 and isinstance(pts, int) and 10 <= pts <= 30 and row['j_pts'] == pts, '獎勵不正確')
    check(n_tx == 1, '未寫入交易紀錄')


@case('A07', '每日任務獎勵不能重複領取',
      pre='U3 今日已領取獎勵',
      steps='再次 POST /api/daily/claim',
      expect='HTTP 400，「今日獎勵已領取」；點數不變')
def _(c):
    u3 = STATE['daily']
    r = SC.post('/api/daily/claim', json={'user_id': u3['id']})
    pts = user_row(u3['id'])['j_pts']
    c.log(http(r, 'error') + f'；j_pts={pts}（領取後為 {STATE.get("daily_pts")}）')
    check(r.status_code == 400 and J(r).get('error') == '今日獎勵已領取' and pts == STATE.get('daily_pts'), '可重複領取')


# ======================================================================
# A09 系統設定：意見回饋、密碼重設
# ======================================================================
@case('A09', '送出意見回饋',
      pre='使用者 K 已登入',
      steps='POST /api/user/feedback，user_id=K、email、feedback_type=功能建議、content=希望增加深色模式',
      expect='HTTP 200，「感謝你的回饋！我們會盡快處理」；資料庫新增 1 筆回饋')
def _(c):
    k = register('feedback')
    STATE['feedback'] = k
    r = SC.post('/api/user/feedback', json={'user_id': k['id'], 'email': k['email'], 'feedback_type': '功能建議',
                                            'content': '希望增加深色模式'})
    n = count(Feedback, user_id=k['id'])
    c.log(http(r, 'message') + f'；資料庫回饋 {n} 筆')
    check(r.status_code == 200 and J(r).get('message') == '感謝你的回饋！我們會盡快處理' and n == 1, '送出失敗')


@case('A09', '意見回饋內容空白或未選類型被拒',
      pre='使用者 K 已登入',
      steps='1. POST /api/user/feedback，content=空白\n2. POST /api/user/feedback，content 有值但 feedback_type 空白',
      expect='1. HTTP 400，「請輸入回饋內容」\n2. HTTP 400，「請選擇回饋類型」；不新增資料')
def _(c):
    k = STATE['feedback']
    r1 = SC.post('/api/user/feedback', json={'user_id': k['id'], 'feedback_type': '問題回報', 'content': '   '})
    r2 = SC.post('/api/user/feedback', json={'user_id': k['id'], 'feedback_type': '', 'content': '閃退'})
    n = count(Feedback, user_id=k['id'])
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}；資料庫回饋仍為 {n} 筆')
    check(r1.status_code == 400 and J(r1).get('error') == '請輸入回饋內容', '空白內容未擋下')
    check(r2.status_code == 400 and J(r2).get('error') == '請選擇回饋類型', '未選類型未擋下')
    check(n == 1, '不合法資料被寫入')


@case('A09', '查詢個人歷史回饋',
      pre='使用者 K 已送出 1 筆回饋，官方尚未回覆',
      steps='GET /api/user/feedback/{K}',
      expect='HTTP 200，列出 1 筆：類型「功能建議」、內容、建立時間（台灣時間），reply 為空')
def _(c):
    r = SC.get(f'/api/user/feedback/{STATE["feedback"]["id"]}')
    fb = J(r).get('feedbacks', [])
    c.log(f'HTTP {r.status_code}，feedbacks={_fmt([{k: f[k] for k in ("feedback_type", "content", "reply", "created_at")} for f in fb])}')
    check(r.status_code == 200 and len(fb) == 1 and fb[0]['feedback_type'] == '功能建議' and fb[0]['reply'] is None
          and fb[0]['created_at'], '查詢結果不正確')
    STATE['feedback_id'] = fb[0]['id']


@case('A09', '重設密碼後以新密碼登入',
      pre='一般會員 M，密碼 Pass1234',
      steps='1. POST /api/auth/reset_password，email=M、new_password=NewPass88\n2. 以新密碼登入\n3. 以舊密碼登入',
      expect='1. HTTP 200，「密碼重設成功！請使用新密碼登入」\n2. HTTP 200 登入成功\n3. HTTP 401',
      note='App 端目前只有「忘記密碼／重設密碼」API，未要求驗證舊密碼或驗證碼')
def _(c):
    m = register('resetpw')
    r1 = SC.post('/api/auth/reset_password', json={'email': m['email'], 'new_password': 'NewPass88'})
    r2 = login(m, 'NewPass88')
    r3 = login(m, 'Pass1234')
    c.log(f'1. {http(r1, "message")}；2. {http(r2, "message")}；3. {http(r3, "error")}')
    check(r1.status_code == 200 and r2.status_code == 200 and r3.status_code == 401, '重設密碼流程不正確')


@case('A09', '校園教育版學生帳號不可在 App 重設密碼',
      pre='學生帳號（account_type=student，由老師建立）',
      steps='POST /api/auth/reset_password，email=學生帳號、new_password=Hack1234',
      expect='HTTP 403，「校園教育版帳號無法在這裡重設密碼，請老師在班級名冊幫你重設」；原密碼仍可登入')
def _(c):
    with S.app_context():
        st = User(email='stu001@test.local', password_hash=generate_password_hash('11156001'),
                  account_type=AccountType.STUDENT, friend_id='STU00001')
        db.session.add(st)
        db.session.commit()
    r1 = SC.post('/api/auth/reset_password', json={'email': 'stu001@test.local', 'new_password': 'Hack1234'})
    r2 = SC.post('/api/auth/login', json={'email': 'stu001@test.local', 'password': '11156001'})
    c.log(f'1. {http(r1, "error")}；2. 原密碼登入 {http(r2, "message")}')
    check(r1.status_code == 403 and J(r1).get('error') == '校園教育版帳號無法在這裡重設密碼，請老師在班級名冊幫你重設', '未擋下')
    check(r2.status_code == 200, '原密碼被改掉')


@case('A09', '不存在的 Email 重設密碼',
      pre='nobody@test.local 未註冊',
      steps='POST /api/auth/reset_password，email=nobody@test.local、new_password=Pass9999',
      expect='HTTP 404，「找不到此 Email，請確認是否輸入正確」')
def _(c):
    r = SC.post('/api/auth/reset_password', json={'email': 'nobody@test.local', 'new_password': 'Pass9999'})
    c.log(http(r, 'error'))
    check(r.status_code == 404 and J(r).get('error') == '找不到此 Email，請確認是否輸入正確', '未回傳 404')


# ======================================================================
# A10 管理員後台（admin_app.py）
# ======================================================================
@case('A10', '管理者登入成功',
      pre='super_admin 帳號 sys_super（密碼 Admin@1234）',
      steps='1. POST /login，username=sys_super、password=Admin@1234\n2. GET /dashboard',
      expect='1. HTTP 302 導向 /dashboard\n2. HTTP 200 顯示儀表板；資料庫記錄最後登入時間')
def _(c):
    ac = admin_client()
    r1 = ac.post('/login', data={'username': 'sys_super', 'password': 'Admin@1234'})
    r2 = ac.get('/dashboard')
    with A.app_context():
        last = Admin.query.filter_by(username='sys_super').first().last_login_at
    c.log(f'1. HTTP {r1.status_code} → {loc(r1)}；2. HTTP {r2.status_code}；last_login_at 已記錄={last is not None}')
    check(r1.status_code == 302 and loc(r1).endswith('/dashboard'), '登入未導向儀表板')
    check(r2.status_code == 200 and last is not None, '儀表板無法開啟')


@case('A10', '管理者密碼錯誤登入失敗',
      pre='sys_super 帳號存在',
      steps='1. POST /login，username=sys_super、password=wrong\n2. GET /dashboard',
      expect='1. HTTP 200 停留在登入頁並顯示「帳號或密碼錯誤，請重新輸入」\n2. HTTP 302 導回 /login')
def _(c):
    ac = admin_client()
    r1 = ac.post('/login', data={'username': 'sys_super', 'password': 'wrong'})
    r2 = ac.get('/dashboard')
    shown = '帳號或密碼錯誤，請重新輸入' in html(r1)
    c.log(f'1. HTTP {r1.status_code}，顯示錯誤訊息={shown}；2. HTTP {r2.status_code} → {loc(r2)}')
    check(r1.status_code == 200 and shown, '未顯示錯誤')
    check(r2.status_code == 302 and loc(r2).endswith('/login'), '未登入仍可進入後台')


@case('A10', '已停用的管理者帳號無法登入',
      pre='管理者 sys_disabled 已被 super_admin 停用（is_active=false）',
      steps='POST /login，username=sys_disabled、password=Disabled@1234（正確密碼）',
      expect='HTTP 200 停留在登入頁，顯示「此管理員帳號已被停用，請聯繫 super_admin」')
def _(c):
    ac = admin_client()
    r = ac.post('/login', data={'username': 'sys_disabled', 'password': 'Disabled@1234'})
    shown = '此管理員帳號已被停用' in html(r)
    c.log(f'HTTP {r.status_code}，顯示停用訊息={shown}')
    check(r.status_code == 200 and shown, '停用帳號仍可登入')


@case('A10', '未登入存取後台頁面被導回登入頁',
      pre='瀏覽器未登入後台',
      steps='依序 GET /dashboard、/user/list、/plan/list、/feedback/list',
      expect='全部 HTTP 302 導向 /login')
def _(c):
    ac = admin_client()
    res = {p: ac.get(p) for p in ['/dashboard', '/user/list', '/plan/list', '/feedback/list']}
    c.log('；'.join(f'{p} → HTTP {r.status_code} {loc(r)}' for p, r in res.items()))
    check(all(r.status_code == 302 and loc(r).endswith('/login') for r in res.values()), '有頁面未導回登入頁')


@case('A10', '查詢使用者資料',
      pre='管理者已登入；App 使用者 alice@test.local 存在',
      steps='GET /user/list?q=alice',
      expect='HTTP 200，列表中顯示 alice@test.local')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    r = ac.get('/user/list?q=alice')
    found = 'alice@test.local' in html(r)
    c.log(f'HTTP {r.status_code}，列表含 alice@test.local={found}')
    check(r.status_code == 200 and found, '查無使用者')


@case('A10', '停用使用者帳號',
      pre='管理者已登入；App 使用者 X 正常可登入',
      steps='1. POST /user/suspend/{X}\n2. X 以正確帳密 POST /api/auth/login',
      expect='1. HTTP 302 返回列表，資料庫 is_suspended=true\n2. HTTP 403，「此帳號已被停用，請聯繫客服」')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    x = register('adminX')
    STATE['adminX'] = x
    before = login(x).status_code
    r1 = ac.post(f'/user/suspend/{x["id"]}')
    sus = user_row(x['id'])['is_suspended']
    r2 = login(x)
    c.log(f'停用前登入 HTTP {before}；1. HTTP {r1.status_code}，is_suspended={sus}；2. {http(r2, "error")}')
    check(before == 200 and r1.status_code == 302 and sus is True, '停用失敗')
    check(r2.status_code == 403, '停用後仍可登入')


@case('A10', '解除停用使用者帳號',
      pre='使用者 X 已被停用',
      steps='1. 再次 POST /user/suspend/{X}（切換狀態）\n2. X POST /api/auth/login',
      expect='1. HTTP 302，is_suspended=false\n2. HTTP 200 登入成功')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    x = STATE['adminX']
    r1 = ac.post(f'/user/suspend/{x["id"]}')
    sus = user_row(x['id'])['is_suspended']
    r2 = login(x)
    c.log(f'1. HTTP {r1.status_code}，is_suspended={sus}；2. {http(r2, "message")}')
    check(r1.status_code == 302 and sus is False and r2.status_code == 200, '解除停用失敗')


@case('A10', '管理者調整使用者點數',
      pre='管理者已登入；使用者 X 目前 0 點',
      steps='1. POST /customer/adjust_pts/{X}，amount=100、reason=活動補償\n2. App GET /api/user/transactions/{X}',
      expect='1. HTTP 302，X 點數變 100，並寫入操作日誌 system_log\n2. 交易紀錄出現 +100（admin_adjust，原因「活動補償」）')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    x = STATE['adminX']
    r = ac.post(f'/customer/adjust_pts/{x["id"]}', data={'amount': '100', 'reason': '活動補償'})
    pts = user_row(x['id'])['j_pts']
    tx = [(t['points'], t['transaction_type'], t['related_feature'])
          for t in J(SC.get(f'/api/user/transactions/{x["id"]}')).get('transactions', [])]
    logs = count(SystemLog, target_table='user', target_id=x['id'])
    c.log(f'1. HTTP {r.status_code}，j_pts={pts}、system_log {logs} 筆；2. transactions={tx}')
    check(r.status_code == 302 and pts == 100 and logs == 1, '調整失敗')
    check(tx == [(100, 'admin_adjust', '活動補償')], 'App 端交易紀錄不正確')


@case('A10', '新增點數方案',
      pre='super_admin 已登入',
      steps='1. POST /package/add，name=測試超值包、points=500、price=220、tag=限時\n2. App GET /api/store/packages',
      expect='1. HTTP 302 返回方案管理頁\n2. App 端方案列表出現「測試超值包」500 點／NT$220')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    r = ac.post('/package/add', data={'name': '測試超值包', 'points': '500', 'price': '220', 'tag': '限時', 'description': '系統測試'})
    pk = {p['name']: p for p in J(SC.get('/api/store/packages')).get('packages', [])}
    got = pk.get('測試超值包', {})
    STATE['pkg_id'] = got.get('id')
    c.log(f'1. HTTP {r.status_code} → {loc(r)}；2. 測試超值包={_fmt({k: got.get(k) for k in ("points", "price", "tag")}) if got else "不存在"}')
    check(r.status_code == 302 and got.get('points') == 500 and got.get('price') == 220 and got.get('tag') == '限時', '新增失敗')


@case('A10', '修改點數方案',
      pre='「測試超值包」已上架',
      steps='1. POST /package/edit/{id}，name=測試超值包（調整）、points=600、price=250\n2. App GET /api/store/packages',
      expect='1. HTTP 302\n2. App 端顯示「測試超值包（調整）」600 點／NT$250')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    r = ac.post(f'/package/edit/{STATE["pkg_id"]}', data={'name': '測試超值包（調整）', 'points': '600', 'price': '250',
                                                         'tag': '', 'description': ''})
    pk = {p['id']: p for p in J(SC.get('/api/store/packages')).get('packages', [])}
    got = pk.get(STATE['pkg_id'], {})
    c.log(f'1. HTTP {r.status_code}；2. {_fmt({k: got.get(k) for k in ("name", "points", "price")})}')
    check(r.status_code == 302 and got.get('name') == '測試超值包（調整）' and got.get('points') == 600 and got.get('price') == 250, '修改失敗')


@case('A10', '點數方案下架與重新上架',
      pre='「測試超值包（調整）」上架中',
      steps='1. POST /package/toggle/{id}（下架），App GET /api/store/packages\n2. 再 POST /package/toggle/{id}（上架），App 再查詢',
      expect='1. HTTP 302，App 端看不到該方案\n2. HTTP 302，App 端重新出現該方案')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    pid = STATE['pkg_id']
    r1 = ac.post(f'/package/toggle/{pid}')
    off = any(p['id'] == pid for p in J(SC.get('/api/store/packages')).get('packages', []))
    r2 = ac.post(f'/package/toggle/{pid}')
    on = any(p['id'] == pid for p in J(SC.get('/api/store/packages')).get('packages', []))
    c.log(f'1. HTTP {r1.status_code}，下架後 App 可見={off}；2. HTTP {r2.status_code}，上架後 App 可見={on}')
    check(r1.status_code == 302 and off is False, '下架失敗')
    check(r2.status_code == 302 and on is True, '上架失敗')


@case('A10', '訂閱方案下架與重新上架',
      pre='年訂閱方案上架中',
      steps='1. POST /plan/toggle/{年訂閱 id}，App GET /api/subscription/plans\n2. 再 POST /plan/toggle/{年訂閱 id}，App 再查詢',
      expect='1. HTTP 302，App 端只剩月訂閱，並寫入操作日誌\n2. HTTP 302，App 端恢復 2 個方案')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    yid = plan_id('Premium Pro 年訂閱')
    r1 = ac.post(f'/plan/toggle/{yid}')
    names1 = [p['name'] for p in J(SC.get('/api/subscription/plans')).get('plans', [])]
    r2 = ac.post(f'/plan/toggle/{yid}')
    names2 = [p['name'] for p in J(SC.get('/api/subscription/plans')).get('plans', [])]
    logs = count(SystemLog, target_table='subscription_plan', target_id=yid)
    c.log(f'1. HTTP {r1.status_code}，App 方案={names1}；2. HTTP {r2.status_code}，App 方案={names2}；操作日誌 {logs} 筆')
    check(r1.status_code == 302 and names1 == ['Premium Pro 月訂閱'], '下架失敗')
    check(r2.status_code == 302 and sorted(names2) == sorted(['Premium Pro 月訂閱', 'Premium Pro 年訂閱']), '上架失敗')
    check(logs == 2, '未寫入操作日誌')


@case('A10', '一般管理者無權管理方案',
      pre='一般管理者 sys_staff（role=admin）已登入',
      steps='1. GET /plan/list\n2. POST /package/add，name=越權方案、points=1、price=1',
      expect='皆 HTTP 302 導回 /dashboard；不新增「越權方案」')
def _(c):
    ac = admin_client('sys_staff', 'Staff@1234')
    r1 = ac.get('/plan/list')
    r2 = ac.post('/package/add', data={'name': '越權方案', 'points': '1', 'price': '1'})
    n = count(PointPackage, name='越權方案')
    c.log(f'1. HTTP {r1.status_code} → {loc(r1)}；2. HTTP {r2.status_code} → {loc(r2)}；資料庫「越權方案」{n} 筆')
    check(r1.status_code == 302 and loc(r1).endswith('/dashboard'), '一般管理者可進入方案管理')
    check(r2.status_code == 302 and loc(r2).endswith('/dashboard') and n == 0, '一般管理者可新增方案')


@case('A10', '管理者回覆意見回饋',
      pre='使用者 K 已送出回饋（A09-01）；管理者已登入',
      steps='1. POST /feedback/reply/{回饋 id}，reply=感謝建議，深色模式已排入開發\n2. App GET /api/user/feedback/{K}',
      expect='1. HTTP 302\n2. 該筆回饋 reply 顯示官方回覆內容，replied_at 有值')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    if not STATE.get('feedback_id'):
        raise RuntimeError('前置個案 A09-03 未完成')
    r = ac.post(f'/feedback/reply/{STATE["feedback_id"]}', data={'reply': '感謝建議，深色模式已排入開發'})
    fb = J(SC.get(f'/api/user/feedback/{STATE["feedback"]["id"]}')).get('feedbacks', [{}])[0]
    c.log(f'1. HTTP {r.status_code}；2. reply={fb.get("reply")}、replied_at={fb.get("replied_at")}')
    check(r.status_code == 302 and fb.get('reply') == '感謝建議，深色模式已排入開發' and fb.get('replied_at'), '回覆未出現在 App 端')


@case('A10', '後台修改的內建方案在後端重新啟動後維持不變',
      pre='super_admin 已登入；月訂閱 NT$149、「中包」上架中',
      steps='1. POST /plan/edit/{月訂閱 id}，price_monthly=129；POST /package/toggle/{中包 id}（下架）\n2. App 查詢確認已生效\n3. 重新啟動學生端後端（重新載入 app.py，暫存資料庫不變）\n4. App 再 GET /api/subscription/plans、/api/store/packages',
      expect='4. 管理者的設定應保留：月訂閱仍為 NT$129、「中包」仍為下架（App 看不到）',
      note='以重新載入 app.py 模擬後端重新啟動')
def _(c):
    import importlib
    ac = admin_client('sys_super', 'Admin@1234')
    mid = plan_id('Premium Pro 月訂閱')
    with S.app_context():
        mid_pkg = PointPackage.query.filter_by(name='中包').first().id
    ac.post(f'/plan/edit/{mid}', data={'name': 'Premium Pro 月訂閱', 'price_monthly': '129', 'points_grant_monthly': '20'})
    ac.post(f'/package/toggle/{mid_pkg}')

    def snapshot(client):
        price = next((p['price_monthly'] for p in J(client.get('/api/subscription/plans')).get('plans', [])
                      if p['name'] == 'Premium Pro 月訂閱'), None)
        has_mid = any(p['name'] == '中包' for p in J(client.get('/api/store/packages')).get('packages', []))
        return price, has_mid

    before = snapshot(SC)
    n_redirect = len(REDIRECTED)
    importlib.reload(student_module)              # 重新執行 app.py 的啟動流程
    student_module.get_ai_reply = fake_get_ai_reply
    with student_module.app.app_context():
        assert db.engine.url.database == TMP_DB
    after = snapshot(student_module.app.test_client())
    c.log(f'重啟前 App：月訂閱價格={before[0]}、中包可見={before[1]}；重啟後 App：月訂閱價格={after[0]}、中包可見={after[1]}'
          f'（重啟時直接連線真實資料庫 {len(REDIRECTED) - n_redirect} 次，已導向暫存檔）')
    check(before == (129, False), '前置作業：後台修改未生效')
    check(after == (129, False), f'重新啟動後設定被 app.py 覆蓋：月訂閱價格變回 {after[0]}、中包重新上架={after[1]}')


# ======================================================================
# 執行
# ======================================================================
def _cell(text):
    return (text or '').replace('|', '／').replace('\n', '<br>')


def main():
    print('=' * 78)
    print(' SNAP TO LEARN 系統測試（黑箱 API 測試）')
    print(f' 暫存資料庫：{TMP_DB}')
    print(f' 測試資料：啟用中訂閱方案 {SEED_INFO["plans"]} 個、點數方案 {SEED_INFO["packages"]} 個、'
          f'主題官方單字 {SEED_INFO["theme_official_vocabs"]} 個（由 app.py 啟動流程種入暫存資料庫）')
    print('=' * 78)
    results = []
    for cs in CASES:
        ctx = Ctx()
        fail = ''
        LOG.write(f'\n===== {cs["id"]} {cs["title"]} =====\n')
        LOG.flush()
        try:
            with redirect_stdout(LOG), redirect_stderr(LOG):
                cs['fn'](ctx)
            verdict = '通過'
        except AssertionError as e:
            verdict, fail = '不通過', str(e)
        except Exception as e:
            verdict, fail = '不通過', f'執行時發生例外 {type(e).__name__}: {e}'
            LOG.write(traceback.format_exc())
        finally:
            FAKE['scan_ok'] = FAKE['chat_ok'] = True
        notes = '；'.join(x for x in [cs['note']] + ctx.notes if x)
        results.append({**{k: v for k, v in cs.items() if k != 'fn'}, 'verdict': verdict,
                        'actual': '；'.join(ctx.actual), 'fail': fail, 'notes': notes})
        print(f'[{cs["id"]}] {cs["title"]} ... {verdict}')
        if ctx.actual:
            print(f'         實際：{"；".join(ctx.actual)}')
        if fail:
            print(f'         不通過原因：{fail}')
        if ctx.notes:
            print(f'         附註：{"；".join(ctx.notes)}')

    LOG.flush()
    with S.app_context():
        db.session.remove()
    elapsed = time.perf_counter() - T_START

    real_after = table_counts(REAL_DB) if REAL_EXISTS else {}
    diff = {k: (REAL_BEFORE.get(k), real_after.get(k)) for k in set(REAL_BEFORE) | set(real_after)
            if REAL_BEFORE.get(k) != real_after.get(k)}
    hash_same = (file_digest(REAL_DB) == REAL_HASH_BEFORE) if REAL_EXISTS else None

    passed = [r for r in results if r['verdict'] == '通過']
    failed = [r for r in results if r['verdict'] != '通過']
    print('=' * 78)
    print(f'彙總：共 {len(results)} 個個案，通過 {len(passed)}，不通過 {len(failed)}')
    if failed:
        print('不通過個案：' + '、'.join(f'{r["id"]} {r["title"]}' for r in failed))
    print(f'執行時間：{elapsed:.1f} 秒')
    if not REAL_EXISTS:
        print('真實資料庫 instance/jlens.db 不存在，略過比對')
    elif diff:
        print(f'⚠ 真實資料庫 instance/jlens.db 筆數有變動：{diff}')
    else:
        print(f'真實資料庫 instance/jlens.db：{len(REAL_BEFORE)} 張表筆數前後一致；主檔 SHA-256 前後'
              + ('一致' if hash_same else '不同（筆數一致，可能是其他程式開著資料庫做 WAL checkpoint）'))
    print(f'直接連往真實資料庫的 sqlite3 連線：攔截並導向暫存檔 {len(REDIRECTED)} 次'
          + ('（app.py 啟動時的欄位修正程式；含 A10-15 模擬重新啟動）' if REDIRECTED else ''))
    print(f'伺服器端輸出紀錄：{LOG_PATH}')

    with open(os.path.join(WORK_DIR, 'results.json'), 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=1, default=str)

    if SHOW_TABLE:
        print('\n| 編號 | 功能 | 測試項目 | 前置條件 | 測試步驟/輸入 | 預期結果 | 實際結果 | 判定 | 備註 |')
        print('|---|---|---|---|---|---|---|---|---|')
        for r in results:
            actual = r['actual'] + (f'<br>不通過原因：{r["fail"]}' if r['fail'] else '')
            print('| ' + ' | '.join(_cell(x) for x in [r['id'], r['feature'], r['title'], r['pre'], r['steps'],
                                                      r['expect'], actual, r['verdict'], r['notes']]) + ' |')
    LOG.close()
    return 2 if diff else 0


if __name__ == '__main__':
    sys.exit(main())
