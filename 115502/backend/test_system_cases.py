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
  - google.genai.Client 一律丟例外；gemini_client.generate_content 平常也丟例外，
    只有朗讀評分（A11）與造句批改（A12）個案執行期間改回傳固定的模擬回應。
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


class _FakeGeminiResponse:
    def __init__(self, text):
        self.text = text


# 朗讀評分（services/article.py）與造句批改（services/sentence.py）直接呼叫 gemini_client.generate_content。
# 平常一律丟例外（不連外）；個案需要時把 GEMINI_FAKE['handler'] 設成產生模擬回應的函式。
GEMINI_FAKE = {'handler': None}


def _fake_or_blocked_generate_content(feature, contents, config=None, model=None):
    handler = GEMINI_FAKE['handler']
    if handler is None:
        raise RuntimeError('系統測試中禁止連線外部 AI 服務')
    return _FakeGeminiResponse(handler(feature, contents))


_genai.Client = _NoNetworkClient
gemini_client.generate_content = _fake_or_blocked_generate_content
gemini_client.run_with_legacy_keys = _blocked_ai
# 新單字補例句平常在背景執行；測試改成同步，才能在個案裡直接檢查結果
from utils import vocab_sentences as _vocab_sentences
_vocab_sentences.RUN_IN_BACKGROUND = False

# ----------------------------------------------------------------------
# 暫存資料庫先建好空的資料表，訂閱方案與點數方案交給 app.py 啟動時建立，
# 等於同時驗證「全新資料庫可以正常啟動」。
# （app.py 原本用不存在的 points_grant 欄位建方案，全新資料庫會 TypeError，已修正。）
# ----------------------------------------------------------------------
_pre_engine = create_engine('sqlite:///' + TMP_DB, poolclass=NullPool)
db.metadata.create_all(_pre_engine)
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
    ChatMessage, SystemLog, AccountType, Article, ScoreRecord, ReadingEvaluation, UnlockedArticle,
    SentencePracticeRecord, Classroom, ClassroomMember, Assignment, TaskType,
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

# ----------------------------------------------------------------------
# 模擬寄信：忘記密碼的驗證碼不真的寄出，改存在 SENT_MAIL 供個案讀取
# ----------------------------------------------------------------------
import re
import utils.mailer as mailer_module

MAIL_FAKE = {'configured': True}
SENT_MAIL = []


def _fake_send_mail(to, subject, body):
    SENT_MAIL.append({'to': to, 'subject': subject, 'body': body})


mailer_module.is_configured = lambda: MAIL_FAKE['configured']
mailer_module.send_mail = _fake_send_mail

# ----------------------------------------------------------------------
# 模擬 Google 身分憑證驗證：不連線 Google。憑證格式 'valid:<email>' 視為驗證通過，其他一律驗證失敗。
# ----------------------------------------------------------------------
import services.auth as auth_module


def _fake_verify_google_id_token(token):
    if isinstance(token, str) and token.startswith('valid:'):
        return {'email': token.split(':', 1)[1], 'email_verified': True}
    raise ValueError('無效的 Google 身分憑證（測試模擬）')


auth_module.verify_google_id_token = _fake_verify_google_id_token
os.environ['DEMO_PAYMENT'] = 'on'


def last_reset_code(email):
    for m in reversed(SENT_MAIL):
        if m['to'] == email:
            found = re.search(r'驗證碼是 (\d{6})', m['body'])
            return found.group(1) if found else None
    return None


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

# ----------------------------------------------------------------------
# 登入通行證：App 的 API 都要帶通行證（utils/auth_token.py）。
# 測試連線依「這次操作的是誰」自動帶上那個人的通行證，等同該使用者在自己的 App 上操作；
# 要測「沒帶／偽造／冒用別人」時，個案自行指定 headers（NO_AUTH 代表不帶）。
# ----------------------------------------------------------------------
from urllib.parse import parse_qs
from flask.testing import FlaskClient
from itsdangerous import URLSafeTimedSerializer
import itsdangerous.timed as _its_timed
from utils.auth_token import issue_token

ACT = {'uid': None}          # 最近一次操作者
NO_AUTH = {'X-Test-No-Auth': '1'}


def token_for(uid):
    try:
        uid = int(uid)
    except (TypeError, ValueError):
        return None
    with S.app_context():
        u = db.session.get(User, uid)
        return issue_token(u) if u else None


def auth_header(u_or_id):
    uid = u_or_id['id'] if isinstance(u_or_id, dict) else u_or_id
    return {'Authorization': 'Bearer ' + token_for(uid)}


def bearer(token):
    return {'Authorization': 'Bearer ' + token}


def old_token_for(uid, days):
    """模擬 days 天前簽發的通行證"""
    original = _its_timed.TimestampSigner.get_timestamp
    _its_timed.TimestampSigner.get_timestamp = lambda self: int(time.time() - days * 86400)
    try:
        return token_for(uid)
    finally:
        _its_timed.TimestampSigner.get_timestamp = original


def _owner_of(method, path, body):
    """沒有 user_id 的 API：找出這筆資料的主人（正常使用時就是操作者本人）"""
    from models import FriendRequest, UserVocab, UserFolder, UserPhoto, ChatSession, GroupMember
    with S.app_context():
        try:
            endpoint, view_args = S.url_map.bind('localhost').match(path, method=method)
        except Exception:
            return None

        def get(model, key):
            try:
                return db.session.get(model, int(key))
            except (TypeError, ValueError):
                return None

        if endpoint == 'user.respond_friend_request':
            o = get(FriendRequest, body.get('request_id'))
            return o.receiver_id if o else None
        if endpoint == 'vocab.move_vocab':
            o = get(UserVocab, body.get('user_vocab_id'))
            return o.user_id if o else None
        if endpoint in ('vocab.delete_folder', 'vocab.rename_folder'):
            o = get(UserFolder, body.get('folder_id'))
            return o.user_id if o else None
        if endpoint == 'scenario.rename_photo':
            o = get(UserPhoto, body.get('photo_id'))
            return o.user_id if o else None
        if endpoint in ('chat_history.get_session', 'chat_history.delete_session'):
            o = get(ChatSession, view_args.get('session_id'))
            return o.user_id if o else None
        if endpoint == 'group.cancel_invite':
            m = GroupMember.query.filter_by(group_id=body.get('group_id')).first()
            return m.user_id if m else None
        for k in ('user_id', 'sender_id'):
            if k in view_args:
                return view_args[k]
    return None


class AuthTestClient(FlaskClient):
    def open(self, *args, **kwargs):
        headers = dict(kwargs.pop('headers', None) or {})
        no_auth = headers.pop('X-Test-No-Auth', None)
        path = args[0] if args and isinstance(args[0], str) else None
        if not no_auth and 'Authorization' not in headers and path and path.startswith('/api/'):
            tok = token_for(self._actor(kwargs.get('method', 'GET'), path, kwargs))
            if tok:
                headers['Authorization'] = 'Bearer ' + tok
        kwargs['headers'] = headers
        return super().open(*args, **kwargs)

    @staticmethod
    def _actor(method, path, kw):
        base, _, qs = path.partition('?')
        js = kw.get('json') if isinstance(kw.get('json'), dict) else {}
        data = kw.get('data') if isinstance(kw.get('data'), dict) else {}
        uid = None
        for src in (js, data):
            for k in ('user_id', 'sender_id'):
                if src.get(k) not in (None, ''):
                    uid = src[k]
                    break
            if uid is not None:
                break
        if uid is None and parse_qs(qs).get('user_id'):
            uid = parse_qs(qs)['user_id'][0]
        if uid is None:
            uid = _owner_of(method, base, js or data)
        if uid is None:
            return ACT['uid']
        ACT['uid'] = uid
        return uid


S.test_client_class = AuthTestClient
SC = S.test_client()

# ----------------------------------------------------------------------
# 測試框架
# ----------------------------------------------------------------------
FEATURES = {
    'A01': '帳號管理', 'A02': '拍照學習', 'A03': '單字收藏', 'A04': 'AI對話練習', 'A05': '個人檔案',
    'A06': '社群互動', 'A07': '訂閱與點數', 'A09': '系統設定', 'A10': '管理員後台',
    'A11': '閱讀系統', 'A12': '造句系統', 'A13': '校園教育版', 'B02': '安全需求',
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
      steps='POST /api/auth/google_login，帶該停用帳號 Email 的 Google 身分憑證',
      expect='HTTP 403，拒絕登入（與 Email 登入一致）',
      note='只呼叫本系統後端 /google_login，未連線 Google')
def _(c):
    u = STATE['suspended']
    r = SC.post('/api/auth/google_login', json={'id_token': 'valid:' + u['email']})
    c.log(http(r, 'message', 'error', 'user_id'))
    check(r.status_code == 403,
          f'停用帳號仍可透過 Google 登入（HTTP {r.status_code}「{J(r).get("message")}」並取得 user_id）')


@case('A01', 'Google 首次登入自動建立帳號',
      pre='Email「gnew@test.local」尚未註冊',
      steps='POST /api/auth/google_login，帶 gnew@test.local 的 Google 身分憑證、avatar=https://example.com/a.png',
      expect='HTTP 200，訊息「Google 登入成功！」；自動建立帳號並配發 8 碼 friend_id、streak_days=1、儲存大頭貼網址',
      note='未連線 Google，直接呼叫後端；後端未驗證 Google ID Token')
def _(c):
    r = SC.post('/api/auth/google_login', json={'id_token': 'valid:gnew@test.local', 'avatar': 'https://example.com/a.png'})
    d = J(r)
    c.log(http(r, 'message', 'user_id', 'friend_id', 'streak_days', 'avatar'))
    check(r.status_code == 200 and d.get('message') == 'Google 登入成功！', '登入失敗')
    check(len(d.get('friend_id') or '') == 8 and d.get('streak_days') == 1, '回傳資料不正確')
    row = user_row(d.get('user_id'))
    check(row is not None and row['avatar'] == 'https://example.com/a.png', '帳號未建立或大頭貼未儲存')


@case('A01', '檢查暱稱是否可用',
      pre='使用者 A 已將暱稱設為「Sakura01」',
      steps='使用者 B 呼叫 POST /api/user/check_username：\n1. username=sakura01（大小寫不同）\n2. username=Momo_02\n3. username=a（只有 1 個字）',
      expect='1. HTTP 200，available=true（暱稱可以跟別人重複，辨識使用者靠交友 ID）\n2. HTTP 200，available=true\n3. HTTP 400，「暱稱需為 2～20 個字元」')
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
    check(r1.status_code == 200 and J(r1).get('available') is True, '跟別人同名的暱稱被判定為不可用')
    check(r2.status_code == 200 and J(r2).get('available') is True, '可用暱稱被判定為不可用')
    check(r3.status_code == 400 and J(r3).get('error') == '暱稱需為 2～20 個字元', '長度檢查失效')


@case('A01', '修改暱稱（可以跟別人同名）',
      pre='使用者 A 暱稱為「Sakura01」',
      steps='使用者 B 呼叫 POST /api/user/update_username：\n1. username=Taro_02\n2. username=SAKURA01',
      expect='1. HTTP 200，「暱稱更新成功」\n2. HTTP 200，「暱稱更新成功」；B 的暱稱變成 SAKURA01，A 的暱稱維持 Sakura01')
def _(c):
    b = STATE['nickB']
    r1 = SC.post('/api/user/update_username', json={'user_id': b['id'], 'username': 'Taro_02'})
    r2 = SC.post('/api/user/update_username', json={'user_id': b['id'], 'username': 'SAKURA01'})
    row = user_row(b['id'])
    c.log(f'1. {http(r1, "message", "username")}；2. {http(r2, "message", "username")}；資料庫暱稱={row["username"]}')
    check(r1.status_code == 200 and J(r1).get('message') == '暱稱更新成功', '修改暱稱失敗')
    check(r2.status_code == 200 and J(r2).get('message') == '暱稱更新成功', '跟別人同名的暱稱被擋下')
    check(row['username'] == 'SAKURA01', '暱稱沒有更新')
    check(user_row(STATE['nickA']['id'])['username'] == 'Sakura01', '使用者 A 的暱稱被改到')


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
    c.log('刪除後剩餘筆數：' + '、'.join(f'{k}={v} 筆' for k, v in left.items()))
    check(all(v == 0 for v in left.values()),
          '刪除帳號後仍殘留個人資料：' + '、'.join(f'{k} {v} 筆' for k, v in left.items() if v))


def quiz_answers(qs, flags):
    """依每題要答對／答錯產生作答：True 送正確選項文字，False 送其他選項，None 代表選「我還沒學過這個」"""
    with S.app_context():
        out = []
        for q, ok in zip(qs, flags):
            row = db.session.get(QuizQuestion, q['id'])
            right = [row.option_a, row.option_b, row.option_c, row.option_d]['ABCD'.index(row.correct_answer)]
            wrong = next(o for o in q['options'] if o != right)
            out.append({'id': q['id'], 'answer': None if ok is None else (right if ok else wrong)})
        return out


def placement(u, flags):
    """幫還沒有程度的使用者做一次程度測驗"""
    qs = J(SC.get('/api/quiz/questions')).get('questions', [])
    return SC.post('/api/quiz/submit', json={'user_id': u['id'], 'answers': quiz_answers(qs, flags)})


@case('A01', '取得日語程度測驗題目',
      pre='題庫依 seed.py 結構共 12 題（超級新手、N5、N4、N3、N2、N1 各 2 題）',
      steps='GET /api/quiz/questions',
      expect='HTTP 200，回傳 10 題，每題有題目與 4 個選項，依序為 N5、N4、N3、N2、N1 各 2 題；'
             '不回傳正確答案（由後端改考卷），階段標籤不顯示 N5～N1')
def _(c):
    r = SC.get('/api/quiz/questions')
    qs = J(r).get('questions', [])
    levels = [q['level_tag'] for q in qs]
    c.log(f'HTTP {r.status_code}，題數={len(qs)}，各題等級依序：{"、".join(levels)}')
    check(r.status_code == 200 and len(qs) == 10, '題數不是 10 題')
    check(all(len(q['options']) == 4 and q['question'] for q in qs), '題目格式不完整')
    check(all('correctIndex' not in q and 'correct_answer' not in q for q in qs), '題目不應附上正確答案')
    check(all('N' not in q['context'] for q in qs), '題目階段標籤不應顯示 N5～N1 代碼')
    check(levels == ['N5', 'N5', 'N4', 'N4', 'N3', 'N3', 'N2', 'N2', 'N1', 'N1'], '題目未依 N5→N1 由淺入深排列')


@case('A01', '程度測驗全部答對判定為 N1',
      pre='新註冊使用者，japanese_level 尚未設定',
      steps='GET /api/quiz/questions 後，POST /api/quiz/submit，answers=[10 題都選正確選項]',
      expect='HTTP 200，level=N1、correct=10；資料庫 japanese_level 更新為 N1')
def _(c):
    u = register('quiz')
    r = placement(u, [True] * 10)
    row = user_row(u['id'])
    c.log(http(r, 'message', 'level', 'correct') + f'；資料庫 japanese_level={row["japanese_level"]}')
    check(r.status_code == 200 and J(r).get('level') == 'N1' and J(r).get('correct') == 10, '判定等級不是 N1')
    check(row['japanese_level'] == 'N1', '資料庫等級未更新')


@case('A01', '程度測驗部分答對判定為 N4',
      pre='新註冊使用者',
      steps='POST /api/quiz/submit，answers=[第 1～4 題答對、第 5～10 題答錯]',
      expect='HTTP 200，level=N4（第 3、4 題答對達 N4，第 5、6 題全錯停在 N4）；資料庫更新為 N4')
def _(c):
    u = register('quiz')
    r = placement(u, [True] * 4 + [False] * 6)
    row = user_row(u['id'])
    c.log(http(r, 'level') + f'；資料庫 japanese_level={row["japanese_level"]}')
    check(r.status_code == 200 and J(r).get('level') == 'N4' and row['japanese_level'] == 'N4', '判定等級不是 N4')


@case('A01', '程度測驗全部答錯判定為 N5',
      pre='新註冊使用者',
      steps='POST /api/quiz/submit，answers=[10 題都選「我還沒學過這個」]',
      expect='HTTP 200，level=N5；資料庫更新為 N5')
def _(c):
    u = register('quiz')
    r = placement(u, [None] * 10)
    row = user_row(u['id'])
    c.log(http(r, 'level') + f'；資料庫 japanese_level={row["japanese_level"]}')
    check(r.status_code == 200 and J(r).get('level') == 'N5' and row['japanese_level'] == 'N5', '判定等級不是 N5')


@case('A01', '程度測驗每關只對一題不會過關',
      pre='兩位新註冊使用者',
      steps='POST /api/quiz/submit：\n1. 第 1、3、5、7 題答對，其餘答錯（每關各對 1 題）\n'
            '2. 第 1～7 題答對、第 8 題答錯、第 9～10 題答對',
      expect='1. HTTP 200，level=N5（N4 那關兩題沒有都對，停在 N5）\n2. HTTP 200，level=N3（N2 那關只對 1 題，停在 N3）')
def _(c):
    r1 = placement(register('quiz'), [True, False] * 4 + [False, False])
    r2 = placement(register('quiz'), [True] * 7 + [False] + [True] * 2)
    c.log(f'1. {http(r1, "level")}；2. {http(r2, "level")}')
    check(r1.status_code == 200 and J(r1).get('level') == 'N5', '每關各對 1 題卻判定過關')
    check(r2.status_code == 200 and J(r2).get('level') == 'N3', '沒有在 N2 那關停下')


@case('A01', '程度測驗不能偽造作答或重做',
      pre='使用者 Q 尚未設定程度',
      steps='1. POST /api/quiz/submit，舊格式 results=[true×10]\n2. answers 只送 2 題\n'
            '3. 正常作答（全錯）\n4. 再做一次程度測驗（全對）\n5. POST /api/user/update_level，level=N1',
      expect='1. HTTP 400（不接受 App 自己算的對錯）\n2. HTTP 400，「請完成整份測驗再送出」\n3. HTTP 200，level=N5\n'
             '4. HTTP 409，程度不變\n5. HTTP 409，程度仍是 N5')
def _(c):
    u = register('quiz')
    qs = J(SC.get('/api/quiz/questions')).get('questions', [])
    r1 = SC.post('/api/quiz/submit', json={'user_id': u['id'], 'results': [True] * 10})
    r2 = SC.post('/api/quiz/submit', json={'user_id': u['id'], 'answers': quiz_answers(qs[:2], [True, True])})
    r3 = placement(u, [False] * 10)
    r4 = placement(u, [True] * 10)
    r5 = SC.post('/api/user/update_level', json={'user_id': u['id'], 'level': 'N1'})
    lv = user_row(u['id'])['japanese_level']
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}；3. {http(r3, "level")}；4. {http(r4, "error")}；'
          f'5. {http(r5, "error")}；資料庫 japanese_level={lv}')
    check(r1.status_code == 400 and r2.status_code == 400 and J(r2).get('error') == '請完成整份測驗再送出',
          '偽造的作答沒有被擋下')
    check(r3.status_code == 200 and J(r3).get('level') == 'N5', '正常作答判定錯誤')
    check(r4.status_code == 409 and r5.status_code == 409 and lv == 'N5', '已有程度的使用者還能重做程度測驗或直接改程度')


@case('A01', '升級測驗由後端改考卷',
      pre='使用者 U 選「我是日文新手」（程度 N5），測試題庫 N4 有 2 題',
      steps='1. GET /api/quiz/upgrade_questions\n2. POST /api/quiz/upgrade_submit，舊格式 results=[true]\n'
            '3. answers 只送 1 題（答對）\n4. answers 混入 N3 的題目\n5. 完整作答但只對 1 題\n6. 完整作答全對',
      expect='1. HTTP 200，target_level=N4、2 題、不附正確答案\n2～4. HTTP 400，程度維持 N5\n'
             '5. HTTP 200，passed=false（通過需 2 題）\n6. HTTP 200，passed=true，程度升為 N4')
def _(c):
    u = register('upq')
    SC.post('/api/user/update_level', json={'user_id': u['id'], 'level': 'N5'})
    r1 = SC.get(f'/api/quiz/upgrade_questions?user_id={u["id"]}')
    qs = J(r1).get('questions', [])
    n3 = [q for q in J(SC.get('/api/quiz/questions')).get('questions', []) if q['level_tag'] == 'N3'][:1]

    def sub(answers):
        return SC.post('/api/quiz/upgrade_submit', json={'user_id': u['id'], 'answers': answers})

    r2 = SC.post('/api/quiz/upgrade_submit', json={'user_id': u['id'], 'results': [True]})
    r3 = sub(quiz_answers(qs[:1], [True]))
    r4 = sub(quiz_answers(qs[:1] + n3, [True, True]))
    lv_mid = user_row(u['id'])['japanese_level']
    r5 = sub(quiz_answers(qs, [True, False]))
    r6 = sub(quiz_answers(qs, [True, True]))
    lv = user_row(u['id'])['japanese_level']
    c.log(f'1. {http(r1, "target_level", "total", "pass_count")}；2. {http(r2, "error")}；3. {http(r3, "error")}；'
          f'4. {http(r4, "error")}；5. {http(r5, "passed", "correct", "pass_count")}；6. {http(r6, "passed", "level")}')
    check(r1.status_code == 200 and J(r1).get('target_level') == 'N4' and len(qs) == 2, '升級題目不正確')
    check(all('correctIndex' not in q for q in qs), '升級題目不應附上正確答案')
    check(r2.status_code == 400 and r3.status_code == 400 and r4.status_code == 400 and lv_mid == 'N5',
          '偽造的升級作答沒有被擋下')
    check(r5.status_code == 200 and J(r5).get('passed') is False, '答對率不足卻通過')
    check(r6.status_code == 200 and J(r6).get('passed') is True and lv == 'N4', '全對卻沒有升級')


@case('A01', '提交測驗缺少使用者 ID 被拒',
      pre='無',
      steps='POST /api/quiz/submit，只傳 results，未傳 user_id',
      expect='HTTP 400，「缺少使用者 ID」')
def _(c):
    r = SC.post('/api/quiz/submit', json={'results': [True] * 10})
    c.log(http(r, 'error'))
    check(r.status_code == 400 and J(r).get('error') == '缺少使用者 ID', '未正確拒絕')


@case('A01', '校園教育版帳號不可使用 Google 登入或自行刪除帳號',
      pre='老師已建立學生帳號 11156099@school.test（account_type=student）',
      steps='1. POST /api/auth/google_login，帶學生帳號 Email 的 Google 身分憑證\n2. POST /api/user/delete_account，user_id=學生帳號',
      expect='1. HTTP 403，「這個帳號不能使用 Google 登入，請改用帳號密碼登入」\n2. HTTP 403，「校園教育版帳號無法在 App 刪除，請聯繫老師或系統管理員」，帳號仍存在')
def _(c):
    ensure_edu()
    st = STATE['edu_student']
    r1 = SC.post('/api/auth/google_login', json={'id_token': 'valid:' + st['email']})
    r2 = SC.post('/api/user/delete_account', json={'user_id': st['id']})
    still = user_row(st['id']) is not None
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}，帳號仍存在={still}')
    check(r1.status_code == 403 and J(r1).get('error') == '這個帳號不能使用 Google 登入，請改用帳號密碼登入', 'Google 登入未擋下學生帳號')
    check(r2.status_code == 403 and still, '學生帳號可以在 App 自行刪除')


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
      expect='2. HTTP 500，回傳錯誤訊息，已上傳的圖片檔刪除\n3. photo_count_today 退回 1；不新增照片紀錄',
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
    c.log(f'1. {http(r1, "daily_scans")}；2. {http(r2, "error")}，圖片檔 {files_before} → {files_after} 個；'
          f'3. photo_count_today={st.get("photo_count_today")}，照片紀錄 {n_photo} 筆')
    check(files_after == files_before, f'辨識失敗後上傳的圖片檔仍留在伺服器（多 {files_after - files_before} 個檔案）')
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
      pre='免費會員今日已正常拍照辨識 2 次（每次先 /increment_scan 再 /analyze），第 3 次 /increment_scan 回傳 403；AI 辨識以模擬資料替代',
      steps='不經過 /increment_scan，直接 POST /api/scenario/analyze（multipart：user_id、image）',
      expect='額度用完、沒有扣次就呼叫辨識應被拒絕（HTTP 403），不產生新照片紀錄',
      note='AI 回應以模擬資料替代')
def _(c):
    u = register('scanlimit')
    codes = []
    for i in range(2):   # 正常流程：先扣次數再辨識
        codes.append(scan(u).status_code)
        SC.post('/api/scenario/analyze', data={'user_id': str(u['id']), 'image': (io.BytesIO(JPEG_BYTES), f'ok{i}.jpg')},
                content_type='multipart/form-data')
    codes.append(scan(u).status_code)
    before = count(UserPhoto, user_id=u['id'])
    if codes != [200, 200, 403] or before != 2:
        raise RuntimeError(f'前置作業失敗：拍照扣次結果 {codes}、照片 {before} 筆')
    r = SC.post('/api/scenario/analyze', data={'user_id': str(u['id']), 'image': (io.BytesIO(JPEG_BYTES), 'over.jpg')},
                content_type='multipart/form-data')
    n_photo = count(UserPhoto, user_id=u['id'])
    c.log(f'前置正常辨識 2 次、第 3 次扣次狀態碼={codes[-1]}；直接 /analyze {http(r, "error")}，照片紀錄 {before} → {n_photo} 筆')
    check(r.status_code == 403 and n_photo == before,
          f'額度用完仍可辨識（HTTP {r.status_code}，照片 {before} → {n_photo} 筆）：/analyze 本身不檢查額度')


# ======================================================================
# A03 單字收藏
# ======================================================================
@case('A03', '收藏單字成功',
      pre='一般會員 V 尚未收藏任何單字；字典已有測試單字（テスト語01～60）',
      steps='1. POST /api/vocab/collect，user_id=V、vocab_id=テスト語01\n2. GET /api/vocab/favorites/{V}',
      expect='1. HTTP 201，「收藏成功！」並回傳 user_vocab_id\n2. 「預設單字本」count=1')
def _(c):
    u = register('vocab')
    STATE['vocab'] = u
    r = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[0]})
    fav = favorites(u)
    c.log(f'1. {http(r, "message", "user_vocab_id")}；2. 預設單字本 count={fav.get("預設單字本", {}).get("count")}')
    check(r.status_code == 201 and J(r).get('user_vocab_id'), '收藏失敗')
    check(fav.get('預設單字本', {}).get('count') == 1, '預設單字本數量不正確')


@case('A03', '重複收藏同一單字被拒',
      pre='V 已收藏テスト語01',
      steps='再次 POST /api/vocab/collect，vocab_id=テスト語01',
      expect='HTTP 400，「已經收藏過囉！」，收藏數不變')
def _(c):
    u = STATE['vocab']
    r = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[0]})
    fav = favorites(u)
    c.log(http(r, 'error') + f'；預設單字本 count={fav.get("預設單字本", {}).get("count")}')
    check(r.status_code == 400 and J(r).get('error') == '已經收藏過囉！', '未擋下重複收藏')
    check(fav.get('預設單字本', {}).get('count') == 1, '收藏數改變')


@case('A03', '取消收藏（保留圖鑑解鎖狀態）',
      pre='V 已收藏テスト語01',
      steps='1. POST /api/vocab/uncollect，user_id=V、vocab_id=テスト語01\n2. GET /api/vocab/favorites/{V}',
      expect='1. HTTP 200，「已從資料夾移除，但保留圖鑑解鎖狀態」\n2. 預設單字本 count=0；資料庫保留該單字紀錄（collected_at 清空）')
def _(c):
    u = STATE['vocab']
    r = SC.post('/api/vocab/uncollect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[0]})
    fav = favorites(u)
    with S.app_context():
        uv = UserVocab.query.filter_by(user_id=u['id'], vocab_id=VOCAB_IDS[0]).first()
        kept = uv is not None and uv.collected_at is None
    c.log(f'1. {http(r, "message")}；2. 預設單字本 count={fav.get("預設單字本", {}).get("count")}；資料庫保留解鎖紀錄={kept}')
    check(r.status_code == 200, '取消收藏失敗')
    check(fav.get('預設單字本', {}).get('count') == 0 and kept, '取消收藏結果不正確')


@case('A03', '已解鎖單字重新收藏',
      pre='テスト語01 已解鎖但未收藏（A03-03）',
      steps='POST /api/vocab/collect，vocab_id=テスト語01',
      expect='HTTP 200，「收藏成功！」，沿用原本的紀錄（user_vocab_id 不變）；預設單字本 count=1')
def _(c):
    u = STATE['vocab']
    with S.app_context():
        old_id = UserVocab.query.filter_by(user_id=u['id'], vocab_id=VOCAB_IDS[0]).first().id
    r = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[0]})
    fav = favorites(u)
    STATE['vocab_uv_id'] = J(r).get('user_vocab_id')
    c.log(http(r, 'message', 'user_vocab_id') + f'（原紀錄 id={old_id}）；預設單字本 count={fav.get("預設單字本", {}).get("count")}')
    check(r.status_code == 200 and J(r).get('user_vocab_id') == old_id, '未沿用原紀錄')
    check(fav.get('預設單字本', {}).get('count') == 1, '收藏數不正確')


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
    c.log(f'1. {http(r1, "message")}；2. {http(r2, "error")}；目前資料夾={[k for k in fav if k != "預設單字本"]}')
    check(r1.status_code == 200 and '常用動詞' in fav, '改名失敗')
    check(r2.status_code == 400, '空白名稱未被擋下')


@case('A03', '移動單字到資料夾',
      pre='V 的テスト語01 在預設單字本，另有「常用動詞」資料夾',
      steps='1. POST /api/vocab/move_vocab，user_vocab_id、target_folder_id=常用動詞\n2. GET /api/vocab/favorites/{V}\n3. POST /api/vocab/folder_vocabs，folder_id=常用動詞',
      expect='1. HTTP 200，「移動成功」\n2. 「常用動詞」count=1、預設單字本 count=0\n3. 資料夾內含テスト語01')
def _(c):
    u = STATE['vocab']
    r = SC.post('/api/vocab/move_vocab', json={'user_vocab_id': STATE['vocab_uv_id'], 'target_folder_id': STATE['folder_id']})
    fav = favorites(u)
    fv = J(SC.post('/api/vocab/folder_vocabs', json={'user_id': u['id'], 'folder_id': STATE['folder_id']})).get('vocabs', [])
    c.log(f'1. {http(r, "message")}；2. 常用動詞 count={fav.get("常用動詞", {}).get("count")}、預設單字本 count={fav.get("預設單字本", {}).get("count")}；'
          f'3. 資料夾內單字={[v["word"] for v in fv]}')
    check(r.status_code == 200, '移動失敗')
    check(fav.get('常用動詞', {}).get('count') == 1 and fav.get('預設單字本', {}).get('count') == 0, '數量不正確')
    check([v['word'] for v in fv] == ['テスト語01'], '資料夾內容不正確')


@case('A03', '刪除資料夾後單字移回預設單字本',
      pre='「常用動詞」資料夾內有 1 個單字',
      steps='1. POST /api/vocab/delete_folder，folder_id=常用動詞\n2. GET /api/vocab/favorites/{V}',
      expect='1. HTTP 200，「資料夾已刪除，單字已移回預設單字本」\n2. 資料夾消失，預設單字本 count=1（單字仍為收藏狀態）')
def _(c):
    u = STATE['vocab']
    r = SC.post('/api/vocab/delete_folder', json={'folder_id': STATE['folder_id']})
    fav = favorites(u)
    c.log(f'1. {http(r, "message")}；2. 資料夾清單={list(fav)}、預設單字本 count={fav.get("預設單字本", {}).get("count")}')
    check(r.status_code == 200, '刪除資料夾失敗')
    check('常用動詞' not in fav and fav.get('預設單字本', {}).get('count') == 1, '單字未移回預設單字本')


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
      pre='免費會員今日已正常對話 3 次（每次先 /use_ai 再 /api/chat），第 4 次 /use_ai 回傳 403；AI 回覆以模擬資料替代',
      steps='不經過 /use_ai，直接 POST /api/chat（form：message、topic、level、user_id）',
      expect='額度用完、沒有扣次就呼叫對話應被拒絕（HTTP 403），不回傳 AI 回覆',
      note='AI 回應以模擬資料替代')
def _(c):
    u = register('chatlimit')
    codes, replies = [], []
    for _i in range(3):   # 正常流程：先扣次數再對話
        codes.append(use_ai(u).status_code)
        rr = SC.post('/api/chat', data={'message': 'こんにちは', 'topic': '日常對話', 'level': 'N5', 'user_id': str(u['id'])})
        replies.append(rr.status_code)
    codes.append(use_ai(u).status_code)
    if codes != [200, 200, 200, 403] or replies != [200, 200, 200]:
        raise RuntimeError(f'前置作業失敗：AI 扣次結果 {codes}、對話結果 {replies}')
    r = SC.post('/api/chat', data={'message': 'こんにちは', 'topic': '日常對話', 'level': 'N5', 'user_id': str(u['id'])})
    body = r.get_data(as_text=True)
    c.log(f'前置正常對話 3 次、第 4 次扣次狀態碼={codes[-1]}；直接 /api/chat HTTP {r.status_code}「{body}」')
    check(r.status_code == 403 and body != FAKE_CHAT_REPLY,
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
    set_user(u['id'], japanese_level='N4')
    SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[2]})
    r = SC.get(f'/api/user/profile_data/{u["id"]}')
    d = J(r)
    c.log(http(r, 'username', 'is_premium', 'j_pts', 'ability', 'badge_progress'))
    ab = d.get('ability') or {}
    check(r.status_code == 200 and d.get('username') == 'Hana_05', '個人資料不正確')
    check(set(ab) == {'reading', 'culture', 'speaking', 'listening', 'writing'} and all(0.05 <= v <= 1 for v in ab.values()),
          '能力值格式不正確')
    check((d.get('badge_progress') or {}).get('level_01') == 2 and d['badge_progress'].get('vocab_01') == 1, '徽章進度不正確')


@case('A05', '查詢其他使用者的個人檔案被拒',
      pre='使用者 P 已登入；user_id=999999 不是 P',
      steps='P 以自己的通行證 GET /api/user/profile_data/999999',
      expect='HTTP 403，「不能操作其他使用者的資料」')
def _(c):
    r = SC.get('/api/user/profile_data/999999', headers=auth_header(STATE['profile']))
    c.log(http(r, 'error'))
    check(r.status_code == 403 and J(r).get('error') == '不能操作其他使用者的資料', '未擋下')


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


@case('A06', '已處理的交友邀請不能再處理，也不能加自己為好友',
      pre='使用者 K1 向 K2 送出交友邀請，K2 已接受',
      steps='1. K2 對同一筆邀請再 POST /api/user/friend_request/respond，action=accept\n2. K1 POST /api/user/friend_request/send，receiver_id=K1 自己',
      expect='1. HTTP 400，「這個邀請已經處理過了」，雙方各只有 1 筆好友紀錄\n2. HTTP 400，「不能加自己為好友喔！」')
def _(c):
    k1, k2 = register('friendK1'), register('friendK2')
    SC.post('/api/user/friend_request/send', json={'sender_id': k1['id'], 'receiver_id': k2['id']})
    with S.app_context():
        rid = FriendRequest.query.filter_by(sender_id=k1['id'], receiver_id=k2['id']).first().id
    SC.post('/api/user/friend_request/respond', json={'request_id': rid, 'action': 'accept'})
    r1 = SC.post('/api/user/friend_request/respond', json={'request_id': rid, 'action': 'accept'})
    n = count(Friendship, user_id=k1['id']) + count(Friendship, user_id=k2['id'])
    r2 = SC.post('/api/user/friend_request/send', json={'sender_id': k1['id'], 'receiver_id': k1['id']})
    c.log(f'1. {http(r1, "error")}，好友紀錄共 {n} 筆；2. {http(r2, "error")}')
    check(r1.status_code == 400 and J(r1).get('error') == '這個邀請已經處理過了' and n == 2, '同一筆邀請可以重複接受')
    check(r2.status_code == 400 and J(r2).get('error') == '不能加自己為好友喔！', '可以加自己為好友')


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


def send_reset_code(email):
    return SC.post('/api/auth/forgot_password', json={'email': email})


def reset_with_code(email, code, new_password='NewPass88'):
    return SC.post('/api/auth/reset_password', json={'email': email, 'code': code, 'new_password': new_password})


def age_reset_codes(email, seconds=None, expire=False):
    """把該帳號的驗證碼紀錄往前調（模擬時間經過）"""
    from models import PasswordResetCode
    with S.app_context():
        uid = User.query.filter_by(email=email).first().id
        for rec in PasswordResetCode.query.filter_by(user_id=uid).all():
            if seconds:
                rec.created_at = rec.created_at - timedelta(seconds=seconds)
            if expire:
                rec.expires_at = datetime.utcnow() - timedelta(seconds=1)
        db.session.commit()


@case('A09', '寄送驗證碼並以驗證碼重設密碼',
      pre='一般會員 M，密碼 Pass1234；寄信以模擬方式攔截',
      steps='1. POST /api/auth/forgot_password，email=M\n2. 以信中的驗證碼 POST /api/auth/reset_password，new_password=NewPass88\n'
            '3. 分別以新密碼、舊密碼登入\n4. 用同一組驗證碼再重設一次',
      expect='1. HTTP 200，「驗證碼已寄到…，10 分鐘內有效」，寄出含 6 位數驗證碼的信\n2. HTTP 200，「密碼重設成功！請使用新密碼登入」\n'
             '3. 新密碼 HTTP 200、舊密碼 HTTP 401\n4. HTTP 400，「驗證碼已失效，請重新寄送驗證碼」',
      note='寄信以模擬方式攔截，未真的寄出')
def _(c):
    m = register('resetpw')
    r1 = send_reset_code(m['email'])
    code = last_reset_code(m['email'])
    r2 = reset_with_code(m['email'], code)
    r3, r4 = login(m, 'NewPass88'), login(m, 'Pass1234')
    r5 = reset_with_code(m['email'], code, 'Again999')
    c.log(f'1. {http(r1, "message")}，寄出驗證碼={"有" if code else "無"}；2. {http(r2, "message")}；'
          f'3. 新密碼 HTTP {r3.status_code}、舊密碼 HTTP {r4.status_code}；4. {http(r5, "error")}')
    check(r1.status_code == 200 and code and len(code) == 6, '驗證碼沒有寄出')
    check(r2.status_code == 200 and r3.status_code == 200 and r4.status_code == 401, '重設密碼流程不正確')
    check(r5.status_code == 400 and J(r5).get('error') == '驗證碼已失效，請重新寄送驗證碼', '驗證碼可以重複使用')


@case('A09', '沒有驗證碼或驗證碼錯誤無法重設密碼',
      pre='一般會員 N，密碼 Pass1234',
      steps='1. 只帶 email 與 new_password POST /api/auth/reset_password（舊做法，沒有驗證碼）\n'
            '2. 寄送驗證碼後，連續 5 次輸入錯誤驗證碼\n3. 再輸入正確驗證碼\n4. 以原密碼登入',
      expect='1. HTTP 400，「請輸入信箱收到的驗證碼」\n2. 前 4 次「驗證碼錯誤，還可以再試 N 次」，第 5 次「驗證碼錯誤次數過多，請重新寄送驗證碼」\n'
             '3. HTTP 400，驗證碼已作廢\n4. 原密碼仍可登入',
      note='寄信以模擬方式攔截，未真的寄出')
def _(c):
    n = register('resetwrong')
    r1 = SC.post('/api/auth/reset_password', json={'email': n['email'], 'new_password': 'Hack1234'})
    send_reset_code(n['email'])
    code = last_reset_code(n['email'])
    wrong = '000000' if code != '000000' else '111111'
    errs = [J(reset_with_code(n['email'], wrong)).get('error') for _ in range(5)]
    r3 = reset_with_code(n['email'], code)
    r4 = login(n)
    c.log(f'1. {http(r1, "error")}；2. {"／".join(errs)}；3. {http(r3, "error")}；4. 原密碼登入 HTTP {r4.status_code}')
    check(r1.status_code == 400 and J(r1).get('error') == '請輸入信箱收到的驗證碼', '沒有驗證碼也能重設')
    check(errs[:4] == [f'驗證碼錯誤，還可以再試 {k} 次' for k in (4, 3, 2, 1)]
          and errs[4] == '驗證碼錯誤次數過多，請重新寄送驗證碼', '錯誤次數限制不正確')
    check(r3.status_code == 400 and r4.status_code == 200, '輸錯太多次後驗證碼仍可使用')


@case('A09', '驗證碼重寄間隔與有效期限',
      pre='一般會員 P2',
      steps='1. 連續兩次 POST /api/auth/forgot_password\n2. 模擬 61 秒後再寄一次，以第一封的驗證碼重設\n3. 模擬新驗證碼超過 10 分鐘後，以新驗證碼重設',
      expect='1. 第二次 HTTP 429，「驗證碼剛寄出，請 N 秒後再試」\n2. 寄送成功；舊驗證碼已作廢，重設失敗\n3. HTTP 400，「驗證碼已失效，請重新寄送驗證碼」',
      note='寄信以模擬方式攔截；時間經過以修改資料庫時間模擬')
def _(c):
    p = register('resetcool')
    send_reset_code(p['email'])
    old = last_reset_code(p['email'])
    r1 = send_reset_code(p['email'])
    age_reset_codes(p['email'], seconds=61)
    r2 = send_reset_code(p['email'])
    new = last_reset_code(p['email'])
    r3 = reset_with_code(p['email'], old) if old != new else None
    age_reset_codes(p['email'], expire=True)
    r4 = reset_with_code(p['email'], new)
    c.log(f'1. 第二次 {http(r1, "error")}；2. 再寄 HTTP {r2.status_code}，用舊驗證碼重設 {http(r3, "error") if r3 else "（新舊驗證碼相同，略過）"}；'
          f'3. {http(r4, "error")}')
    check(r1.status_code == 429 and '秒後再試' in (J(r1).get('error') or ''), '可以連續重寄')
    check(r2.status_code == 200 and (r3 is None or r3.status_code == 400), '重寄後舊驗證碼仍有效')
    check(r4.status_code == 400 and J(r4).get('error') == '驗證碼已失效，請重新寄送驗證碼', '過期的驗證碼仍可使用')


@case('A09', '校園教育版學生帳號不可在 App 重設密碼',
      pre='學生帳號（account_type=student，由老師建立）',
      steps='1. POST /api/auth/forgot_password，email=學生帳號\n2. 以原密碼登入',
      expect='1. HTTP 403，「校園教育版帳號無法在這裡重設密碼，請老師在班級名冊幫你重設」，不寄信\n2. 原密碼仍可登入')
def _(c):
    with S.app_context():
        st = User(email='stu001@test.local', password_hash=generate_password_hash('11156001'),
                  account_type=AccountType.STUDENT, friend_id='STU00001')
        db.session.add(st)
        db.session.commit()
    sent_before = len(SENT_MAIL)
    r1 = send_reset_code('stu001@test.local')
    r2 = SC.post('/api/auth/login', json={'email': 'stu001@test.local', 'password': '11156001'})
    c.log(f'1. {http(r1, "error")}，寄出信件 {len(SENT_MAIL) - sent_before} 封；2. 原密碼登入 {http(r2, "message")}')
    check(r1.status_code == 403 and J(r1).get('error') == '校園教育版帳號無法在這裡重設密碼，請老師在班級名冊幫你重設'
          and len(SENT_MAIL) == sent_before, '未擋下')
    check(r2.status_code == 200, '原密碼被改掉')


@case('A09', '不存在的 Email 或寄信服務未設定時無法寄送驗證碼',
      pre='nobody@test.local 未註冊；一般會員 Q 已註冊',
      steps='1. POST /api/auth/forgot_password，email=nobody@test.local\n2. 寄信帳號未設定時，Q POST /api/auth/forgot_password',
      expect='1. HTTP 404，「找不到此 Email，請確認是否輸入正確」\n2. HTTP 503，「寄信服務尚未設定，請聯繫系統管理員」')
def _(c):
    q = register('resetnomail')
    r1 = send_reset_code('nobody@test.local')
    MAIL_FAKE['configured'] = False
    try:
        r2 = send_reset_code(q['email'])
    finally:
        MAIL_FAKE['configured'] = True
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}')
    check(r1.status_code == 404 and J(r1).get('error') == '找不到此 Email，請確認是否輸入正確', '未回傳 404')
    check(r2.status_code == 503 and J(r2).get('error') == '寄信服務尚未設定，請聯繫系統管理員', '未提示寄信服務未設定')


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
      steps='1. 不登入後台，以 App 的 POST /api/user/feedback/reply 冒充官方回覆\n'
            '2. 管理者 POST /feedback/reply/{回饋 id}，reply=感謝建議，深色模式已排入開發\n3. App GET /api/user/feedback/{K}',
      expect='1. HTTP 404（App 端沒有回覆 API），回饋仍未回覆\n2. HTTP 302\n3. 該筆回饋 reply 顯示官方回覆內容，replied_at 有值')
def _(c):
    ac = admin_client('sys_super', 'Admin@1234')
    if not STATE.get('feedback_id'):
        raise RuntimeError('前置個案 A09-03 未完成')
    r0 = SC.post('/api/user/feedback/reply', json={'feedback_id': STATE['feedback_id'], 'reply': '冒充的官方回覆'})
    fb0 = J(SC.get(f'/api/user/feedback/{STATE["feedback"]["id"]}')).get('feedbacks', [{}])[0]
    r = ac.post(f'/feedback/reply/{STATE["feedback_id"]}', data={'reply': '感謝建議，深色模式已排入開發'})
    fb = J(SC.get(f'/api/user/feedback/{STATE["feedback"]["id"]}')).get('feedbacks', [{}])[0]
    c.log(f'1. HTTP {r0.status_code}，reply={fb0.get("reply")}；2. HTTP {r.status_code}；3. reply={fb.get("reply")}、replied_at={fb.get("replied_at")}')
    check(r0.status_code == 404 and fb0.get('reply') is None, 'App API 可以冒充官方回覆')
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
# A11 閱讀系統（services/article.py、vocabulary.py /collect_from_article）
# ======================================================================
M4A_BYTES = b'\x00\x00\x00\x18ftypM4A \x00\x00\x02\x00' + b'\x00' * 128   # 只有檔頭的 m4a，供格式判斷用
FAKE_TRANSCRIPT = 'あきのきょうとはこうようがとてもうつくしいです。'


def fake_reading_ai(feature, contents):
    """朗讀評分的模擬 AI：第一次呼叫（含音訊）回轉錄文字，第二次回評分 JSON"""
    if isinstance(contents, list):
        return FAKE_TRANSCRIPT
    return '{"score": 92, "mistakes": [], "overall_feedback": "發音清楚，語調自然，「紅葉」的長音再拉長一點會更好。"}'


def ensure_articles():
    """前置：後台已上架的分級文章（含假名標音、翻譯、文法解析）"""
    if 'art_free' in STATE:
        return
    grammar = {'grammars': [{'expression': '〜ながら', 'meaning': '一邊...一邊...', 'example': '音楽を聴きながら勉強します。'}]}
    with S.app_context():
        rows = {
            'art_free': Article(theme='日常生活', level='N3', title='朝のルーティン',
                                content='<ruby>私<rt>わたし</rt></ruby>は<ruby>毎朝<rt>まいあさ</rt></ruby>コーヒーを<ruby>飲<rt>の</rt></ruby>みながら<ruby>新聞<rt>しんぶん</rt></ruby>を<ruby>読<rt>よ</rt></ruby>みます。',
                                translation='我每天早上一邊喝咖啡一邊看報紙。', grammar_points=grammar,
                                is_free=True, unlock_cost=0, is_published=True),
            'art_paid': Article(theme='旅遊觀光', level='N3', title='京都の秋',
                                content='<ruby>秋<rt>あき</rt></ruby>の<ruby>京都<rt>きょうと</rt></ruby>は<ruby>紅葉<rt>こうよう</rt></ruby>がとても<ruby>美<rt>うつく</rt></ruby>しいです。',
                                translation='秋天的京都楓葉非常美麗。',
                                grammar_points={'grammars': [{'expression': '〜に来ます', 'meaning': '來做(某事)', 'example': '日本へ勉強しに来ました。'}]},
                                is_free=False, unlock_cost=50, is_published=True),
            'art_hidden': Article(theme='日本文化', level='N3', title='下架中的文章', content='テスト', translation='測試',
                                  is_free=True, is_published=False),
            'art_n5': Article(theme='日常生活', level='N5', title='はじめまして', content='はじめまして。', translation='初次見面。',
                              is_free=True, is_published=True),
        }
        db.session.add_all(rows.values())
        db.session.commit()
        STATE.update({k: v.id for k, v in rows.items()})


@case('A11', '依程度取得分級文章列表',
      pre='後台已上架 N3 文章 2 篇（「朝のルーティン」免費、「京都の秋」付費 50 點）、N3 下架文章 1 篇、N5 文章 1 篇；使用者 R 程度 N3、0 點',
      steps='GET /api/articles/dashboard?user_id=R&level=N3',
      expect='HTTP 200，status=success，只列出 N3 且上架中的 2 篇（不含下架與 N5 文章）；免費文章 is_unlocked=true、unlock_cost=0；付費文章 is_unlocked=false、unlock_cost=50')
def _(c):
    ensure_articles()
    r_user = register('reader')
    STATE['reader'] = r_user
    set_user(r_user['id'], japanese_level='N3')
    r = SC.get(f'/api/articles/dashboard?user_id={r_user["id"]}&level=N3')
    data = J(r).get('data', [])
    brief = [(a['title'], a['is_unlocked'], a['unlock_cost']) for a in data]
    c.log(f'HTTP {r.status_code}，status={J(r).get("status")}，文章（標題, 已解鎖, 解鎖點數）={brief}')
    check(r.status_code == 200 and J(r).get('status') == 'success', '列表取得失敗')
    check(brief == [('朝のルーティン', True, 0), ('京都の秋', False, 50)], '列表內容或解鎖狀態不正確')


@case('A11', '文章提供假名標音、中文翻譯與文法解析',
      pre='同 A11-01 的 N3 文章',
      steps='GET /api/articles/dashboard?user_id=R&level=N3，檢查每篇文章的 content、translation、grammar_points',
      expect='每篇 content 以 <ruby>漢字<rt>假名</rt></ruby> 標音；translation 有中文翻譯；grammar_points 列出文法（expression、meaning、example）')
def _(c):
    data = J(SC.get(f'/api/articles/dashboard?user_id={STATE["reader"]["id"]}&level=N3')).get('data', [])
    rows = []
    ok = bool(data)
    for a in data:
        g = ((a.get('grammar_points') or {}).get('grammars') or [{}])[0]
        has_ruby = '<ruby>' in (a.get('content') or '') and '<rt>' in (a.get('content') or '')
        rows.append(f'「{a["title"]}」標音={has_ruby}、翻譯「{a.get("translation")}」、文法 {g.get("expression")}（{g.get("meaning")}）')
        ok = ok and has_ruby and bool(a.get('translation')) and all(g.get(k) for k in ('expression', 'meaning', 'example'))
    c.log('；'.join(rows))
    check(ok, '有文章缺少標音、翻譯或文法解析')


@case('A11', '以點數解鎖付費文章',
      pre='使用者 R 為 0 點；「京都の秋」需 50 點',
      steps='1. POST /api/articles/unlock，user_id=R、article_id=京都の秋\n2. R 購買 60 點後再解鎖一次\n3. 再解鎖第三次\n4. GET /api/articles/dashboard 與 /api/user/transactions/{R}',
      expect='1. HTTP 400，status=not_enough_points、「J-pts 不足，解鎖此文章需要 50 點」\n2. HTTP 200，status=success、扣 50 點（new_j_pts=10）\n3. HTTP 200，status=already_unlocked，不再扣點\n4. 文章 is_unlocked=true；交易紀錄有 -50（article_unlock）')
def _(c):
    u, aid = STATE['reader'], STATE['art_paid']
    r1 = SC.post('/api/articles/unlock', json={'user_id': u['id'], 'article_id': aid})
    SC.post('/api/user/add_points', json={'user_id': u['id'], 'points': 60, 'price': 50, 'payment_method': 'credit_card'})
    r2 = SC.post('/api/articles/unlock', json={'user_id': u['id'], 'article_id': aid})
    r3 = SC.post('/api/articles/unlock', json={'user_id': u['id'], 'article_id': aid})
    art = next((a for a in J(SC.get(f'/api/articles/dashboard?user_id={u["id"]}&level=N3')).get('data', []) if a['id'] == aid), {})
    tx = [(t['points'], t['related_feature']) for t in J(SC.get(f'/api/user/transactions/{u["id"]}')).get('transactions', [])
          if t['related_feature'] == 'article_unlock']
    c.log(f'1. {http(r1, "status", "message")}；2. {http(r2, "status", "cost", "new_j_pts")}；3. {http(r3, "status", "new_j_pts")}；'
          f'4. is_unlocked={art.get("is_unlocked")}、解鎖交易={tx}')
    check(r1.status_code == 400 and J(r1).get('status') == 'not_enough_points'
          and J(r1).get('message') == 'J-pts 不足，解鎖此文章需要 50 點', '點數不足未擋下')
    check(r2.status_code == 200 and J(r2).get('status') == 'success' and J(r2).get('new_j_pts') == 10, '解鎖失敗')
    check(r3.status_code == 200 and J(r3).get('status') == 'already_unlocked' and J(r3).get('new_j_pts') == 10, '重複解鎖又扣點')
    check(art.get('is_unlocked') is True and tx == [(-50, 'article_unlock')], '解鎖狀態或交易紀錄不正確')


@case('A11', '朗讀錄音 AI 評分、結算點數並保留朗讀歷史',
      pre='R 已解鎖「京都の秋」，目前 10 點；AI 轉錄與評分以模擬資料替代（92 分）',
      steps='1. POST /api/articles/evaluate（multipart：audio=reading.m4a、user_id、article_id）\n2. POST /api/articles/submit_score，user_id、article_id、evaluation_id\n3. GET /api/articles/history/{R}',
      expect='1. HTTP 200，status=success，回傳轉錄文字、score=92、evaluation_id\n2. HTTP 200，「成績結算成功！」，90 分以上得 50 點（total_points=60）、is_new_record=true\n3. 歷史紀錄 1 筆：京都の秋、92 分、50 點',
      note='AI 回應以模擬資料替代')
def _(c):
    u, aid = STATE['reader'], STATE['art_paid']
    GEMINI_FAKE['handler'] = fake_reading_ai
    r1 = SC.post('/api/articles/evaluate', data={'audio': (io.BytesIO(M4A_BYTES), 'reading.m4a'),
                                                 'user_id': str(u['id']), 'article_id': str(aid)},
                 content_type='multipart/form-data')
    GEMINI_FAKE['handler'] = None
    eid = J(r1).get('evaluation_id')
    STATE['reading_eval'] = eid
    r2 = SC.post('/api/articles/submit_score', json={'user_id': u['id'], 'article_id': aid, 'evaluation_id': eid})
    hist = J(SC.get(f'/api/articles/history/{u["id"]}')).get('data', [])
    c.log(f'1. {http(r1, "status", "transcript", "score", "evaluation_id")}；2. {http(r2, "message", "points_earned", "total_points", "is_new_record")}；'
          f'3. 歷史={[(h["article_title"], h["score"], h["points_earned"]) for h in hist]}')
    check(r1.status_code == 200 and J(r1).get('status') == 'success' and J(r1).get('score') == 92 and eid, '評分失敗')
    check(J(r1).get('transcript') == FAKE_TRANSCRIPT, '未回傳轉錄文字')
    check(r2.status_code == 200 and J(r2).get('points_earned') == 50 and J(r2).get('total_points') == 60
          and J(r2).get('is_new_record') is True, '結算不正確')
    check([(h['article_title'], h['score'], h['points_earned']) for h in hist] == [('京都の秋', 92, 50)], '朗讀歷史不正確')


@case('A11', '同一次朗讀評分不能重複結算或被他人冒用',
      pre='R 的朗讀評分（A11-04）已結算；另一位使用者 S2',
      steps='1. R 以同一個 evaluation_id 再 POST /api/articles/submit_score\n2. S2 以 R 的 evaluation_id POST /api/articles/submit_score\n3. 查詢 R 的點數與朗讀歷史',
      expect='1. HTTP 409，「這次的朗讀成績已經結算過了」\n2. HTTP 404，「找不到這次的朗讀評分，請重新錄音」\n3. R 仍為 60 點、歷史仍為 1 筆')
def _(c):
    u, aid, eid = STATE['reader'], STATE['art_paid'], STATE.get('reading_eval')
    if not eid:
        raise RuntimeError('前置個案 A11-04 未完成')
    other = register('reader2')
    r1 = SC.post('/api/articles/submit_score', json={'user_id': u['id'], 'article_id': aid, 'evaluation_id': eid})
    r2 = SC.post('/api/articles/submit_score', json={'user_id': other['id'], 'article_id': aid, 'evaluation_id': eid})
    pts = user_row(u['id'])['j_pts']
    n_hist = len(J(SC.get(f'/api/articles/history/{u["id"]}')).get('data', []))
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}；3. R 點數={pts}、歷史 {n_hist} 筆')
    check(r1.status_code == 409 and J(r1).get('error') == '這次的朗讀成績已經結算過了', '可重複結算')
    check(r2.status_code == 404 and J(r2).get('error') == '找不到這次的朗讀評分，請重新錄音', '可冒用他人評分')
    check(pts == 60 and n_hist == 1, '點數或歷史被異動')


@case('A11', '文章單字長按收藏',
      pre='R 尚未收藏任何單字；「紅葉」不在系統字典中',
      steps='1. POST /api/vocab/collect_from_article，user_id=R、word=紅葉、kana=こうよう、meaning=楓葉\n2. GET /api/vocab/favorites/{R}\n3. 再收藏一次同一個字',
      expect='1. HTTP 200，「✅ 成功加入收藏夾！」，字典新增「紅葉」並歸到主題「其他」，並由 AI 補上四個難度的例句與翻譯\n'
             '2. 預設單字本 count=1\n3. HTTP 400，「這個單字已經在收藏夾囉！」\n'
             '4. GET /api/vocab/lookup?word=紅葉：found=true、有初級例句、is_favorited=true',
      note='AI 例句以模擬資料替代')
def _(c):
    u = STATE['reader']
    body = {'user_id': u['id'], 'word': '紅葉', 'kana': 'こうよう', 'meaning': '楓葉'}
    fake = {'sentence_basic': '[紅葉|こうよう]がきれいです。', 'sentence_basic_zh': '楓葉很漂亮。',
            'sentence_inter': '[秋|あき]になると[紅葉|こうよう]を[見|み]に[行|い]く。', 'sentence_inter_zh': '一到秋天就去賞楓。',
            'sentence_upper_inter': '[紅葉|こうよう]の[名所|めいしょ]は[観光客|かんこうきゃく]で[賑|にぎ]わう。', 'sentence_upper_inter_zh': '賞楓名勝擠滿觀光客。',
            'sentence_advanced': '[山|やま]一面が[紅葉|こうよう]に[染|そ]まる[光景|こうけい]は[圧巻|あっかん]だ。', 'sentence_advanced_zh': '整座山染紅的景象令人嘆為觀止。'}

    def fake_sentences(feature, contents):
        import re as _re
        vid = int(_re.search(r'"id": (\d+)', contents).group(1))
        return json.dumps([dict(fake, id=vid)], ensure_ascii=False)

    GEMINI_FAKE['handler'] = fake_sentences
    try:
        r1 = SC.post('/api/vocab/collect_from_article', json=body)
    finally:
        GEMINI_FAKE['handler'] = None
    fav = favorites(u)
    r3 = SC.post('/api/vocab/collect_from_article', json=body)
    r4 = SC.get(f'/api/vocab/lookup?user_id={u["id"]}&word=紅葉')
    with S.app_context():
        v = Vocab.query.filter_by(word='紅葉', kana='こうよう').first()
        scene_name = v.scene.name if v and v.scene else None
        filled = bool(v and v.sentence_basic and v.sentence_advanced_zh)
    c.log(f'1. {http(r1, "status", "message")}，字典新增紅葉={v is not None}（歸入場景「{scene_name}」），補上例句={filled}；'
          f'2. 預設單字本 count={fav.get("預設單字本", {}).get("count")}；3. {http(r3, "error")}；'
          f'4. {http(r4, "found", "sentence", "is_favorited")}')
    check(r1.status_code == 200 and J(r1).get('status') == 'success' and v is not None, '收藏失敗')
    check(filled, '文章新字沒有補上分級例句')
    check(J(r4).get('found') is True and J(r4).get('sentence') == fake['sentence_basic'] and J(r4).get('is_favorited') is True
          and J(r4).get('folder_name') == '預設單字本' and J(r4).get('user_vocab_id'),
          '字典查詢結果不正確')
    check(scene_name == '其他', f'文章新字被歸到「{scene_name}」，應歸到主題收集冊的「其他」')
    check(fav.get('預設單字本', {}).get('count') == 1, '收藏數不正確')
    check(r3.status_code == 400 and J(r3).get('error') == '這個單字已經在收藏夾囉！', '未擋下重複收藏')


@case('A11', '未解鎖的付費文章不能朗讀評分，文章重設 API 已移除',
      pre='使用者 L 為 0 點，尚未解鎖「京都の秋」',
      steps='1. POST /api/articles/evaluate（multipart：audio、user_id=L、article_id=京都の秋）\n2. GET /api/articles/seed（舊的「清除並重設文章」API）',
      expect='1. HTTP 403，「請先解鎖這篇文章再朗讀」，不產生朗讀評分\n2. HTTP 404，文章數量不變',
      note='AI 回應以模擬資料替代（本個案不應呼叫到 AI）')
def _(c):
    ensure_articles()
    lu = register('lockedReader')
    before = count(Article)
    GEMINI_FAKE['handler'] = fake_reading_ai
    try:
        r1 = SC.post('/api/articles/evaluate', data={'audio': (io.BytesIO(M4A_BYTES), 'reading.m4a'),
                                                     'user_id': str(lu['id']), 'article_id': str(STATE['art_paid'])},
                     content_type='multipart/form-data')
    finally:
        GEMINI_FAKE['handler'] = None
    n_eval = count(ReadingEvaluation, user_id=lu['id'])
    r2 = SC.get('/api/articles/seed')
    after = count(Article)
    c.log(f'1. {http(r1, "status", "message")}，朗讀評分 {n_eval} 筆；2. HTTP {r2.status_code}，文章數 {before} → {after}')
    check(r1.status_code == 403 and n_eval == 0, '未解鎖的付費文章仍可朗讀評分')
    check(r2.status_code == 404 and after == before, '文章重設 API 仍可呼叫')


# ======================================================================
# A12 造句系統（services/sentence.py）
# ======================================================================
FAKE_SENTENCE_RESULT = ('{"score": 85, "is_grammar_correct": true, '
                        '"corrected_sentence": "健康のために、毎日冷蔵庫の野菜を食べています。", '
                        '"strict_feedback": "1. 文法「〜ために」使用正確\\n2. 助詞「を」正確"}')


def fake_sentence_ai(feature, contents):
    return FAKE_SENTENCE_RESULT


def evaluate_sentence(u, vocabs=None, pay=False, sentence='健康のために、毎日冷蔵庫の野菜を食べます。'):
    GEMINI_FAKE['handler'] = fake_sentence_ai
    try:
        return SC.post('/api/sentence/evaluate', json={
            'user_id': u['id'], 'grammar_point': '〜ために', 'selected_vocabs': vocabs or [],
            'user_sentence': sentence, 'pay_with_points': pay})
    finally:
        GEMINI_FAKE['handler'] = None


@case('A12', '依使用者程度取得文法造句題目',
      pre='使用者 W1 程度 N4，今日尚未造句',
      steps='1. GET /api/sentence/get_task?user_id=W1\n2. GET /api/sentence/get_task（未帶 user_id）',
      expect='1. HTTP 200，level=N4，回傳一題 N4 文法（grammar、meaning、3 個例句），today_count=0\n2. HTTP 400，「缺少 user_id」')
def _(c):
    from services.sentence import GRAMMAR_DB
    w1 = register('writer')
    STATE['writer'] = w1
    set_user(w1['id'], japanese_level='N4')
    r1 = SC.get(f'/api/sentence/get_task?user_id={w1["id"]}')
    r2 = SC.get('/api/sentence/get_task')
    d = J(r1)
    task = d.get('data') or {}
    in_n4 = task.get('grammar') in [g['grammar'] for g in GRAMMAR_DB['N4']]
    c.log(f'1. HTTP {r1.status_code}，level={d.get("level")}，題目={task.get("grammar")}（{task.get("meaning")}），'
          f'例句 {len(task.get("examples") or [])} 句，屬於 N4 題庫={in_n4}，today_count={d.get("today_count")}；2. {http(r2, "error")}')
    check(r1.status_code == 200 and d.get('level') == 'N4' and in_n4 and len(task.get('examples') or []) == 3, '題目不正確')
    check(d.get('today_count') == 0, '今日次數不正確')
    check(r2.status_code == 400 and J(r2).get('error') == '缺少 user_id', '未擋下缺少 user_id')


@case('A12', '使用收藏單字造句並由 AI 批改',
      pre='W1 已收藏「冷蔵庫」；AI 批改以模擬資料替代（85 分）',
      steps='1. 從收藏夾取得單字（POST /api/vocab/folder_vocabs）\n2. POST /api/sentence/evaluate，grammar_point=〜ために、selected_vocabs=[冷蔵庫]、user_sentence=健康のために、毎日冷蔵庫の野菜を食べます。\n3. POST /api/sentence/evaluate 未帶 user_sentence',
      expect='2. HTTP 200，status=success，score=85、修正句與條列評語、80 分以上可得 30 點，句子用到選用的「冷蔵庫」再加 10 點（points_earned=40、vocab_bonus=10）、回傳 record_id；資料庫紀錄保存選用的收藏單字\n3. HTTP 400，「缺少必要參數」',
      note='AI 回應以模擬資料替代')
def _(c):
    w1 = STATE['writer']
    with S.app_context():
        fridge = Vocab.query.filter_by(word='冷蔵庫', kana='れいぞうこ').first()
        fridge_id = fridge.id if fridge else None
    if not fridge_id:
        raise RuntimeError('前置作業失敗：字典沒有「冷蔵庫」')
    SC.post('/api/vocab/collect', json={'user_id': w1['id'], 'vocab_id': fridge_id})
    words = [v['word'] for v in J(SC.post('/api/vocab/folder_vocabs', json={'user_id': w1['id'], 'folder_id': None})).get('vocabs', [])]
    r = evaluate_sentence(w1, vocabs=words)
    d = J(r)
    STATE['sentence_record'] = d.get('record_id')
    r_bad = SC.post('/api/sentence/evaluate', json={'user_id': w1['id'], 'grammar_point': '〜ために'})
    with S.app_context():
        rec = db.session.get(SentencePracticeRecord, d.get('record_id')) if d.get('record_id') else None
        saved_vocabs = rec.selected_vocabs if rec else None
    c.log(f'1. 收藏單字={words}；2. {http(r, "status", "score", "corrected_sentence", "points_earned", "record_id")}，'
          f'資料庫保存的選用單字={saved_vocabs}；3. {http(r_bad, "error")}')
    check(words == ['冷蔵庫'], '收藏夾內容不正確')
    check(r.status_code == 200 and d.get('status') == 'success' and d.get('score') == 85
          and d.get('points_earned') == 40 and d.get('vocab_bonus') == 10 and d.get('used_vocabs') == ['冷蔵庫']
          and d.get('record_id'), '批改結果不正確')
    check(d.get('corrected_sentence') and d.get('strict_feedback'), '缺少修正句或評語')
    check(saved_vocabs == ['冷蔵庫'], '未保存選用的收藏單字')
    check(r_bad.status_code == 400 and J(r_bad).get('error') == '缺少必要參數', '未擋下缺少參數')


@case('A12', '查詢造句歷史紀錄',
      pre='W1 已完成 1 次造句（A12-02），尚未領取獎勵',
      steps='GET /api/sentence/history/{W1}',
      expect='HTTP 200，列出 1 筆：文法〜ために、原句、修正句、AI 評語、85 分、可領 40 點（含單字加分 10）、is_claimed=false')
def _(c):
    w1 = STATE['writer']
    r = SC.get(f'/api/sentence/history/{w1["id"]}')
    hist = J(r).get('data', [])
    h = hist[0] if hist else {}
    c.log(f'HTTP {r.status_code}，{len(hist)} 筆；grammar_point={h.get("grammar_point")}、score={h.get("score")}、'
          f'points_earned={h.get("points_earned")}、is_claimed={h.get("is_claimed")}、有修正句={bool(h.get("corrected_sentence"))}、有評語={bool(h.get("ai_feedback"))}')
    check(r.status_code == 200 and len(hist) == 1 and h.get('grammar_point') == '〜ために' and h.get('score') == 85
          and h.get('points_earned') == 40 and h.get('is_claimed') is False
          and h.get('corrected_sentence') and h.get('ai_feedback'), '歷史紀錄不正確')


@case('A12', '領取造句獎勵且不能重複領取',
      pre='W1 有一筆未領取的造句紀錄（40 點），目前 0 點',
      steps='1. POST /api/sentence/claim，record_id、user_id=W1\n2. 再領一次\n3. GET /api/sentence/history/{W1}',
      expect='1. HTTP 200，status=success、total_points=40，交易紀錄新增 +40（reward）\n2. HTTP 400，「無法領取或已領取過」，點數不變\n3. is_claimed=true')
def _(c):
    w1, rid = STATE['writer'], STATE.get('sentence_record')
    if not rid:
        raise RuntimeError('前置個案 A12-02 未完成')
    r1 = SC.post('/api/sentence/claim', json={'record_id': rid, 'user_id': w1['id']})
    r2 = SC.post('/api/sentence/claim', json={'record_id': rid, 'user_id': w1['id']})
    pts = user_row(w1['id'])['j_pts']
    claimed = J(SC.get(f'/api/sentence/history/{w1["id"]}')).get('data', [{}])[0].get('is_claimed')
    tx = [t for t in J(SC.get(f'/api/user/transactions/{w1["id"]}')).get('transactions', [])]
    c.log(f'1. {http(r1, "status", "total_points")}；2. {http(r2, "error")}，點數={pts}；3. is_claimed={claimed}；交易紀錄 {len(tx)} 筆')
    check(r1.status_code == 200 and J(r1).get('total_points') == 40, '領取失敗')
    check([(t['points'], t['transaction_type']) for t in tx] == [(40, 'reward')], '領取的點數沒有寫入交易紀錄')
    check(r2.status_code == 400 and J(r2).get('error') == '無法領取或已領取過' and pts == 40, '可重複領取')
    check(claimed is True, '領取狀態未更新')


@case('A12', '不能領取他人的造句獎勵',
      pre='W1 另有一筆未領取的造句紀錄（40 點，AI 以模擬資料替代）；使用者 W2 為 0 點',
      steps='W2 POST /api/sentence/claim，record_id=W1 的紀錄、user_id=W2',
      expect='HTTP 400 或 403 拒絕領取；W2 點數維持 0，W1 的紀錄仍為未領取',
      note='AI 回應以模擬資料替代')
def _(c):
    w1 = STATE['writer']
    w2 = register('writer2')
    rid = J(evaluate_sentence(w1, vocabs=['冷蔵庫'])).get('record_id')
    if not rid:
        raise RuntimeError('前置作業失敗：無法建立造句紀錄')
    r = SC.post('/api/sentence/claim', json={'record_id': rid, 'user_id': w2['id']})
    pts = user_row(w2['id'])['j_pts']
    with S.app_context():
        claimed = db.session.get(SentencePracticeRecord, rid).is_claimed
    c.log(f'{http(r, "status", "total_points", "error")}；W2 點數={pts}；W1 紀錄 is_claimed={claimed}')
    check(r.status_code in (400, 403) and pts == 0 and claimed is False,
          f'W2 領走了 W1 的造句獎勵（HTTP {r.status_code}，W2 點數變 {pts}）：/claim 未檢查紀錄擁有者')


@case('A12', '免費版每日造句 3 次，超過需付 10 點',
      pre='使用者 W3 今日已造句 3 次（AI 以模擬資料替代），目前 0 點',
      steps='1. 第 4 次 POST /api/sentence/evaluate（不付點）\n2. 第 4 次帶 pay_with_points=true（0 點）\n3. 購買 20 點後，第 4 次帶 pay_with_points=true',
      expect='1. HTTP 400，status=quota_exceeded、「今日免費次數已用盡」\n2. HTTP 400，status=insufficient_points、「點數不足」\n3. HTTP 200 批改成功，扣 10 點（餘額 10），交易紀錄有 -10（spend）',
      note='AI 回應以模擬資料替代')
def _(c):
    w3 = register('writer3')
    first3 = [evaluate_sentence(w3).status_code for _ in range(3)]
    r1 = evaluate_sentence(w3)
    r2 = evaluate_sentence(w3, pay=True)
    SC.post('/api/user/add_points', json={'user_id': w3['id'], 'points': 20, 'price': 0, 'payment_method': 'credit_card'})
    r3 = evaluate_sentence(w3, pay=True)
    pts = user_row(w3['id'])['j_pts']
    tx = [(t['points'], t['transaction_type']) for t in J(SC.get(f'/api/user/transactions/{w3["id"]}')).get('transactions', [])]
    c.log(f'前 3 次狀態碼={first3}；1. {http(r1, "status", "error")}；2. {http(r2, "status", "error")}；'
          f'3. {http(r3, "status", "score")}，點數={pts}；交易紀錄={tx}')
    check(first3 == [200] * 3, '前 3 次未全部成功')
    check((-10, 'spend') in tx, '付費造句扣除的 10 點沒有寫入交易紀錄')
    check(r1.status_code == 400 and J(r1).get('status') == 'quota_exceeded' and J(r1).get('error') == '今日免費次數已用盡', '未擋下第 4 次')
    check(r2.status_code == 400 and J(r2).get('status') == 'insufficient_points', '點數不足未擋下')
    check(r3.status_code == 200 and J(r3).get('status') == 'success' and pts == 10, '付費造句不正確')


@case('A12', '付費造句 AI 批改失敗時退還點數',
      pre='使用者 W4 今日已造句 3 次（AI 以模擬資料替代），購買 20 點',
      steps='第 4 次 POST /api/sentence/evaluate，pay_with_points=true，AI 批改失敗',
      expect='HTTP 500；扣除的 10 點退還（餘額 20），交易紀錄有 -10（spend）與 +10（退還）',
      note='AI 失敗以模擬方式產生')
def _(c):
    w4 = register('writer4')
    first3 = [evaluate_sentence(w4).status_code for _ in range(3)]
    SC.post('/api/user/add_points', json={'user_id': w4['id'], 'points': 20, 'price': 0, 'payment_method': 'credit_card'})
    r = SC.post('/api/sentence/evaluate', json={'user_id': w4['id'], 'grammar_point': '〜ために', 'selected_vocabs': [],
                                               'user_sentence': '健康のために走ります。', 'pay_with_points': True})
    pts = user_row(w4['id'])['j_pts']
    tx = [(t['points'], t['related_feature']) for t in J(SC.get(f'/api/user/transactions/{w4["id"]}')).get('transactions', [])]
    c.log(f'前 3 次狀態碼={first3}；第 4 次 HTTP {r.status_code}，點數={pts}；交易紀錄={tx}')
    check(first3 == [200] * 3, '前 3 次未全部成功')
    check(r.status_code == 500 and pts == 20, 'AI 失敗後點數沒有退還')
    check((-10, 'sentence_extra') in tx and (10, 'sentence_extra_refund') in tx, '扣點與退點沒有寫入交易紀錄')


@case('A12', '造句批改與朗讀評分的每日次數依方案不同',
      pre='免費版使用者 F、Premium 使用者 P（AI 以模擬資料替代）',
      steps='1. GET /api/user/usage_status 查兩人的每日上限\n2. P 造句 10 次後再造第 11 次\n'
            '3. F 朗讀評分 1 次後再朗讀第 2 次\n4. P 朗讀評分 5 次後再朗讀第 6 次',
      expect='1. F：造句 3、朗讀 1；P：造句 10、朗讀 5\n2. 前 10 次成功，第 11 次 HTTP 400 quota_exceeded\n'
             '3. 第 2 次 status=quota_exceeded，提示升級 Premium\n4. 前 5 次成功，第 6 次 status=quota_exceeded',
      note='AI 回應以模擬資料替代')
def _(c):
    ensure_articles()
    aid = STATE['art_free']
    f, p = register('quotaF'), register('quotaP')
    set_user(p['id'], is_premium=True, subscription_end_date=datetime.utcnow() + timedelta(days=30))
    uf = J(SC.get(f'/api/user/usage_status/{f["id"]}'))
    up = J(SC.get(f'/api/user/usage_status/{p["id"]}'))

    p_sentences = [evaluate_sentence(p).status_code for _ in range(10)]
    r_p11 = evaluate_sentence(p)

    def read(u):
        return SC.post('/api/articles/evaluate', data={'audio': (io.BytesIO(M4A_BYTES), 'reading.m4a'),
                                                       'user_id': str(u['id']), 'article_id': str(aid)},
                       content_type='multipart/form-data')

    GEMINI_FAKE['handler'] = fake_reading_ai
    try:
        f_reads = [J(read(f)).get('status') for _ in range(2)]
        f_second = J(read(f))
        p_reads = [J(read(p)).get('status') for _ in range(6)]
    finally:
        GEMINI_FAKE['handler'] = None
    c.log(f'1. F 造句 {uf.get("sentence_daily_limit")}、朗讀 {uf.get("reading_daily_limit")}；'
          f'P 造句 {up.get("sentence_daily_limit")}、朗讀 {up.get("reading_daily_limit")}；'
          f'2. P 前 10 次={p_sentences}、第 11 次 {http(r_p11, "status")}；'
          f'3. F 朗讀={f_reads}，提示={f_second.get("message")}；4. P 朗讀={p_reads}')
    check(uf.get('sentence_daily_limit') == 3 and uf.get('reading_daily_limit') == 1, '免費版上限不正確')
    check(up.get('sentence_daily_limit') == 10 and up.get('reading_daily_limit') == 5, 'Premium 上限不正確')
    check(p_sentences == [200] * 10 and r_p11.status_code == 400 and J(r_p11).get('status') == 'quota_exceeded',
          'Premium 造句次數不是 10 次')
    check(f_reads == ['success', 'quota_exceeded'] and 'Premium' in (f_second.get('message') or ''),
          '免費版朗讀次數不是 1 次')
    check(p_reads == ['success'] * 5 + ['quota_exceeded'], 'Premium 朗讀次數不是 5 次')


# ======================================================================
# A13 校園教育版：學生端（services/auth.py、services/classroom.py）
# ======================================================================
def ensure_edu():
    """前置：老師已建立教室並把學生加入名冊（老師端另有測試腳本）"""
    if 'edu_student' in STATE:
        return
    with S.app_context():
        teacher = User(email='teacher_wang@school.test', username='王老師', account_type=AccountType.TEACHER,
                       password_hash=generate_password_hash('Teacher@1234'))
        student = User(email='11156099@school.test', username='學生小明', account_type=AccountType.STUDENT,
                       password_hash=generate_password_hash('11156099'))
        db.session.add_all([teacher, student])
        db.session.flush()
        open_room = Classroom(teacher_id=teacher.id, name='一年甲班', join_code='K7M3P9', is_open=True)
        closed_room = Classroom(teacher_id=teacher.id, name='二年乙班', join_code='Q4W8R2', is_open=False)
        archived_room = Classroom(teacher_id=teacher.id, name='去年的班級', join_code='Z9X8C7', is_archived=True)
        db.session.add_all([open_room, closed_room, archived_room])
        db.session.flush()
        db.session.add_all([
            Assignment(classroom_id=open_room.id, title='第一課造句', task_type=TaskType.SENTENCE,
                       config={'grammar_point': '〜てください'}, is_published=True),
            Assignment(classroom_id=open_room.id, title='草稿作業', task_type=TaskType.SENTENCE,
                       config={'grammar_point': '〜ないでください'}, is_published=False),
            # 學生原本就在去年的班級，老師已封存
            ClassroomMember(classroom_id=archived_room.id, student_id=student.id, display_name='學生小明'),
        ])
        db.session.commit()
        STATE['edu_student'] = {'id': student.id, 'email': student.email, 'password': '11156099'}
        STATE['edu_rooms'] = {'open': open_room.id, 'closed': closed_room.id, 'archived': archived_room.id}


@case('A12', '選用單字有用到才加分',
      pre='使用者 W5 程度 N4；AI 批改以模擬資料替代（85 分，基本 30 點）',
      steps='1. 不選單字造句\n2. 選「冷蔵庫」但句子沒用到\n3. 選「冷蔵庫、野菜」且都有用到',
      expect='1. points_earned=30、vocab_bonus=0\n2. points_earned=30、vocab_bonus=0、unused_vocabs=[冷蔵庫]\n'
             '3. points_earned=50、vocab_bonus=20、used_vocabs=[冷蔵庫, 野菜]')
def _(c):
    w5 = register('writer')
    set_user(w5['id'], japanese_level='N4')
    d1 = J(evaluate_sentence(w5, sentence='健康のために、毎日走ります。'))
    d2 = J(evaluate_sentence(w5, vocabs=['冷蔵庫'], sentence='健康のために、毎日走ります。'))
    d3 = J(evaluate_sentence(w5, vocabs=['冷蔵庫', '野菜']))
    c.log(f'1. points={d1.get("points_earned")}、bonus={d1.get("vocab_bonus")}；'
          f'2. points={d2.get("points_earned")}、bonus={d2.get("vocab_bonus")}、unused={d2.get("unused_vocabs")}；'
          f'3. points={d3.get("points_earned")}、bonus={d3.get("vocab_bonus")}、used={d3.get("used_vocabs")}')
    check(d1.get('points_earned') == 30 and d1.get('vocab_bonus') == 0, '沒選單字卻加分')
    check(d2.get('points_earned') == 30 and d2.get('vocab_bonus') == 0 and d2.get('unused_vocabs') == ['冷蔵庫'],
          '選了單字但沒用到卻加分')
    check(d3.get('points_earned') == 50 and d3.get('vocab_bonus') == 20 and d3.get('used_vocabs') == ['冷蔵庫', '野菜'],
          '用到選用單字沒有加分')


@case('A13', '學生帳號由校園教育版入口登入',
      pre='老師已在班級名冊建立學生帳號 11156099@school.test（account_type=student，密碼為學號）',
      steps='POST /api/auth/login，email=11156099@school.test、password=11156099、portal=edu',
      expect='HTTP 200，「登入成功！」，account_type=student（App 依此進入校園教育版），並補發 friend_id')
def _(c):
    ensure_edu()
    st = STATE['edu_student']
    r = SC.post('/api/auth/login', json={'email': st['email'], 'password': st['password'], 'portal': 'edu'})
    c.log(http(r, 'message', 'user_id', 'account_type', 'friend_id'))
    check(r.status_code == 200 and J(r).get('account_type') == 'student' and J(r).get('user_id') == st['id'], '學生登入失敗')
    check(len(J(r).get('friend_id') or '') == 8, '未補發 friend_id')


@case('A13', '登入入口分流與學生帳號不可自行註冊',
      pre='一般會員帳號 G（account_type=general）；學生帳號 11156099@school.test',
      steps='1. G 以 portal=edu 登入\n2. 學生以 portal=general 登入\n3. POST /api/auth/register，account_type=student（自行註冊學生帳號）',
      expect='1. HTTP 403，status=wrong_portal、「這不是校園教育版的學生帳號，請改從「一般自主學習」登入」\n2. HTTP 403，status=wrong_portal、「這是校園教育版的學生帳號，請改從「校園教育版」登入」\n3. HTTP 403，「校園教育版帳號由老師建立，請向老師確認你的帳號」，不建立帳號')
def _(c):
    ensure_edu()
    g = register('general')
    st = STATE['edu_student']
    r1 = SC.post('/api/auth/login', json={'email': g['email'], 'password': g['password'], 'portal': 'edu'})
    r2 = SC.post('/api/auth/login', json={'email': st['email'], 'password': st['password'], 'portal': 'general'})
    r3 = SC.post('/api/auth/register', json={'email': 'selfstudent@test.local', 'password': 'Pass1234', 'account_type': 'student'})
    n = count(User, email='selfstudent@test.local')
    c.log(f'1. {http(r1, "status", "error")}；2. {http(r2, "status", "error")}；3. {http(r3, "error")}，建立帳號 {n} 筆')
    check(r1.status_code == 403 and J(r1).get('status') == 'wrong_portal'
          and J(r1).get('error') == '這不是校園教育版的學生帳號，請改從「一般自主學習」登入', '一般帳號可進教育版')
    check(r2.status_code == 403 and J(r2).get('status') == 'wrong_portal'
          and J(r2).get('error') == '這是校園教育版的學生帳號，請改從「校園教育版」登入', '學生帳號可進一般版')
    check(r3.status_code == 403 and J(r3).get('error') == '校園教育版帳號由老師建立，請向老師確認你的帳號' and n == 0, '可自行註冊學生帳號')


@case('A13', '以教室代碼預覽並加入教室',
      pre='老師的「一年甲班」代碼 K7M3P9、開放加入，目前 0 位學生',
      steps='1. GET /api/classroom/preview?join_code= k7m-3p9 （小寫、含空白與連字號）\n2. 學生 POST /api/classroom/join，user_id、join_code=k7m3p9',
      expect='1. HTTP 200，代碼自動正規化，回傳教室名稱「一年甲班」、老師「王老師」、成員 0 人\n2. HTTP 201，status=success、「已加入「一年甲班」」，成員變 1 人')
def _(c):
    ensure_edu()
    st = STATE['edu_student']
    r1 = SC.get('/api/classroom/preview?join_code=%20k7m-3p9%20')
    room = J(r1).get('classroom') or {}
    r2 = SC.post('/api/classroom/join', json={'user_id': st['id'], 'join_code': 'k7m3p9'})
    joined = J(r2).get('classroom') or {}
    c.log(f'1. HTTP {r1.status_code}，教室={room.get("name")}、老師={room.get("teacher_name")}、代碼={room.get("join_code")}、成員={room.get("member_count")}；'
          f'2. {http(r2, "status", "message")}，成員={joined.get("member_count")}')
    check(r1.status_code == 200 and room.get('name') == '一年甲班' and room.get('teacher_name') == '王老師'
          and room.get('member_count') == 0, '預覽失敗')
    check(r2.status_code == 201 and J(r2).get('status') == 'success' and J(r2).get('message') == '已加入「一年甲班」'
          and joined.get('member_count') == 1, '加入失敗')


@case('A13', '錯誤代碼、非學生帳號、已關閉或已封存的教室無法加入',
      pre='「二年乙班」（Q4W8R2）已關閉加入；「去年的班級」（Z9X8C7）已封存；一般會員帳號 G',
      steps='1. GET /api/classroom/preview?join_code=ABC999（不存在）\n2. 學生 POST /api/classroom/join，join_code=ABC999\n3. 一般會員 G POST /api/classroom/join，join_code=K7M3P9\n4. 學生加入 Q4W8R2\n5. 預覽 Z9X8C7',
      expect='1. HTTP 404，「找不到這個教室代碼，請再確認一次」\n2. HTTP 404，status=code_not_found\n3. HTTP 403，status=not_student、「只有校園教育版的學生帳號可以加入教室」\n4. HTTP 403，status=classroom_closed、「「二年乙班」已經關閉加入，請聯絡老師」\n5. HTTP 404')
def _(c):
    ensure_edu()
    st = STATE['edu_student']
    g = register('generaljoin')
    r1 = SC.get('/api/classroom/preview?join_code=ABC999')
    r2 = SC.post('/api/classroom/join', json={'user_id': st['id'], 'join_code': 'ABC999'})
    r3 = SC.post('/api/classroom/join', json={'user_id': g['id'], 'join_code': 'K7M3P9'})
    r4 = SC.post('/api/classroom/join', json={'user_id': st['id'], 'join_code': 'Q4W8R2'})
    r5 = SC.get('/api/classroom/preview?join_code=Z9X8C7')
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "status")}；3. {http(r3, "status", "error")}；4. {http(r4, "status", "error")}；5. {http(r5, "error")}')
    check(r1.status_code == 404 and J(r1).get('error') == '找不到這個教室代碼，請再確認一次', '錯誤代碼預覽未擋下')
    check(r2.status_code == 404 and J(r2).get('status') == 'code_not_found', '錯誤代碼加入未擋下')
    check(r3.status_code == 403 and J(r3).get('status') == 'not_student'
          and J(r3).get('error') == '只有校園教育版的學生帳號可以加入教室', '一般帳號可加入教室')
    check(r4.status_code == 403 and J(r4).get('status') == 'classroom_closed'
          and J(r4).get('error') == '「二年乙班」已經關閉加入，請聯絡老師', '已關閉教室可加入')
    check(r5.status_code == 404, '已封存教室仍可預覽')


@case('A13', '重複加入視為成功，並查詢我的教室',
      pre='學生已加入「一年甲班」（有 1 份已發布作業、1 份草稿）；學生原本也在已封存的「去年的班級」',
      steps='1. 學生再次 POST /api/classroom/join，join_code=K7M3P9\n2. GET /api/classroom/my/{學生 id}',
      expect='1. HTTP 200，status=already_joined、「你已經在「一年甲班」裡了」，成員仍 1 人\n2. HTTP 200，count=1，只列出「一年甲班」（不顯示已封存教室），assignment_count=1（草稿不計）')
def _(c):
    ensure_edu()
    st = STATE['edu_student']
    r1 = SC.post('/api/classroom/join', json={'user_id': st['id'], 'join_code': 'K7M3P9'})
    r2 = SC.get(f'/api/classroom/my/{st["id"]}')
    rooms = [(x['name'], x['assignment_count'], x['member_count']) for x in J(r2).get('classrooms', [])]
    c.log(f'1. {http(r1, "status", "message")}，成員={(J(r1).get("classroom") or {}).get("member_count")}；'
          f'2. HTTP {r2.status_code}，count={J(r2).get("count")}，教室（名稱, 作業數, 成員數）={rooms}')
    check(r1.status_code == 200 and J(r1).get('status') == 'already_joined'
          and J(r1).get('message') == '你已經在「一年甲班」裡了' and (J(r1).get('classroom') or {}).get('member_count') == 1, '重複加入處理不正確')
    check(r2.status_code == 200 and J(r2).get('count') == 1 and rooms == [('一年甲班', 1, 1)], '我的教室列表不正確')


@case('A13', '退出教室',
      pre='學生在「一年甲班」中',
      steps='1. POST /api/classroom/leave，user_id、classroom_id=一年甲班\n2. GET /api/classroom/my/{學生 id}\n3. 再退出一次\n4. POST /api/classroom/leave 未帶 classroom_id',
      expect='1. HTTP 200，「已退出教室」\n2. count=0\n3. HTTP 404，「你不在這個教室裡」\n4. HTTP 400，「缺少使用者 ID 或教室 ID」')
def _(c):
    ensure_edu()
    st, rid = STATE['edu_student'], STATE['edu_rooms']['open']
    r1 = SC.post('/api/classroom/leave', json={'user_id': st['id'], 'classroom_id': rid})
    my = J(SC.get(f'/api/classroom/my/{st["id"]}'))
    r3 = SC.post('/api/classroom/leave', json={'user_id': st['id'], 'classroom_id': rid})
    r4 = SC.post('/api/classroom/leave', json={'user_id': st['id']})
    c.log(f'1. {http(r1, "status", "message")}；2. count={my.get("count")}；3. {http(r3, "error")}；4. {http(r4, "error")}')
    check(r1.status_code == 200 and J(r1).get('message') == '已退出教室', '退出失敗')
    check(my.get('count') == 0, '退出後仍顯示教室')
    check(r3.status_code == 404 and J(r3).get('error') == '你不在這個教室裡', '重複退出未回 404')
    check(r4.status_code == 400 and J(r4).get('error') == '缺少使用者 ID 或教室 ID', '缺少參數未擋下')


# ======================================================================
# B02 安全需求：登入通行證、Google 身分憑證、模擬付款開關
# ======================================================================
@case('B02', '未登入呼叫需要登入的 API 被拒，公開清單不受影響',
      pre='使用者 U 已註冊',
      steps='1. 不帶通行證 GET /api/user/profile_data/{U}\n2. 不帶通行證 GET /api/store/packages',
      expect='1. HTTP 401，「請先登入」\n2. HTTP 200，回傳點數方案')
def _(c):
    u = register('noauth')
    r1 = SC.get(f'/api/user/profile_data/{u["id"]}', headers=NO_AUTH)
    r2 = SC.get('/api/store/packages', headers=NO_AUTH)
    c.log(f'1. {http(r1, "error")}；2. HTTP {r2.status_code}，方案 {len(J(r2).get("packages", []))} 個')
    check(r1.status_code == 401 and J(r1).get('error') == '請先登入', '未登入仍可呼叫')
    check(r2.status_code == 200 and J(r2).get('packages'), '公開清單被擋下')


@case('B02', '登入取得通行證並以通行證操作自己的資料',
      pre='使用者 U 已註冊',
      steps='1. POST /api/auth/login\n2. 以回傳的通行證 GET /api/user/profile_data/{U}',
      expect='1. HTTP 200，回傳 token\n2. HTTP 200，回傳 U 的個人檔案')
def _(c):
    u = register('withtoken')
    r1 = login(u)
    tok = J(r1).get('token') or ''
    r2 = SC.get(f'/api/user/profile_data/{u["id"]}', headers=bearer(tok)) if tok else None
    c.log(f'1. HTTP {r1.status_code}，token 長度 {len(tok)}；2. HTTP {r2.status_code if r2 else "-"}')
    check(r1.status_code == 200 and tok, '登入沒有回傳通行證')
    check(r2 is not None and r2.status_code == 200, '用通行證查自己的資料失敗')


@case('B02', '以自己的通行證操作他人資料被拒',
      pre='使用者 A、B 已註冊，B 有 100 點',
      steps='A 以自己的通行證：\n1. POST /api/user/spend_points，user_id=B\n2. GET /api/user/transactions/{B}\n3. POST /api/user/delete_account，user_id=B',
      expect='三次皆 HTTP 403，「不能操作其他使用者的資料」；B 的點數與帳號不受影響')
def _(c):
    a, b = register('ownerA'), register('ownerB')
    SC.post('/api/user/add_points', json={'user_id': b['id'], 'points': 100, 'price': 0, 'payment_method': 'credit_card'})
    h = auth_header(a)
    r1 = SC.post('/api/user/spend_points', json={'user_id': b['id'], 'feature': 'ai_extra'}, headers=h)
    r2 = SC.get(f'/api/user/transactions/{b["id"]}', headers=h)
    r3 = SC.post('/api/user/delete_account', json={'user_id': b['id']}, headers=h)
    row = user_row(b['id'])
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}；3. {http(r3, "error")}；B 點數={row["j_pts"] if row else None}、帳號存在={row is not None}')
    check([r.status_code for r in (r1, r2, r3)] == [403, 403, 403], '可以操作別人的資料')
    check(row is not None and row['j_pts'] == 100, 'B 的資料被改動')


@case('B02', '以物件編號操作他人的對話、資料夾與交友邀請被拒',
      pre='B 有一場對話與一個資料夾；C 向 B 送出交友邀請；A 已登入',
      steps='A 以自己的通行證：\n1. GET /api/chat_history/session/{B 的對話}\n2. POST /api/vocab/delete_folder，B 的資料夾\n3. POST /api/user/friend_request/respond，C 寄給 B 的邀請',
      expect='三次皆 HTTP 403；B 的資料夾仍在、邀請仍待回覆')
def _(c):
    a, b, cc = register('objA'), register('objB'), register('objC')
    sid = J(SC.post('/api/chat_history/session', json={'user_id': b['id'], 'topic': '私人對話'})).get('session_id')
    fid = J(SC.post('/api/vocab/folders', json={'user_id': b['id'], 'name': 'B 的資料夾'})).get('folder_id')
    SC.post('/api/user/friend_request/send', json={'sender_id': cc['id'], 'receiver_id': b['id']})
    with S.app_context():
        rid = FriendRequest.query.filter_by(sender_id=cc['id'], receiver_id=b['id']).first().id
    h = auth_header(a)
    r1 = SC.get(f'/api/chat_history/session/{sid}', headers=h)
    r2 = SC.post('/api/vocab/delete_folder', json={'folder_id': fid}, headers=h)
    r3 = SC.post('/api/user/friend_request/respond', json={'request_id': rid, 'action': 'accept'}, headers=h)
    from models import UserFolder
    with S.app_context():
        folder_left = db.session.get(UserFolder, fid) is not None
        status = db.session.get(FriendRequest, rid).status
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}；3. {http(r3, "error")}；資料夾仍在={folder_left}、邀請狀態={status}')
    check([r.status_code for r in (r1, r2, r3)] == [403, 403, 403], '可以用編號操作別人的資料')
    check(folder_left and status == 'pending', 'B 的資料被改動')


@case('B02', '偽造或竄改的通行證被拒',
      pre='使用者 U 已註冊',
      steps='1. 竄改通行證最後兩個字元後 GET /api/user/profile_data/{U}\n2. 用不同密鑰自行簽一張 U 的通行證後呼叫',
      expect='兩次皆 HTTP 401，「登入狀態無效，請重新登入」')
def _(c):
    u = register('forge')
    tok = token_for(u['id'])
    tampered = tok[:-2] + ('AA' if not tok.endswith('AA') else 'BB')
    fake = URLSafeTimedSerializer('not-the-server-key', salt='snaptolearn-app-auth').dumps({'uid': u['id'], 'v': 0})
    r1 = SC.get(f'/api/user/profile_data/{u["id"]}', headers=bearer(tampered))
    r2 = SC.get(f'/api/user/profile_data/{u["id"]}', headers=bearer(fake))
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}')
    check(all(r.status_code == 401 and J(r).get('error') == '登入狀態無效，請重新登入' for r in (r1, r2)), '偽造的通行證可以使用')


@case('B02', '通行證 30 天到期，有在使用則自動延長',
      pre='使用者 U 已註冊',
      steps='1. 以 31 天前簽發的通行證呼叫 API\n2. 以 2 天前簽發的通行證呼叫 API\n3. 以第 2 步回應附的新通行證呼叫 API',
      expect='1. HTTP 401，「登入已過期，請重新登入」\n2. HTTP 200，回應標頭附上新的通行證（X-Auth-Token）\n3. HTTP 200')
def _(c):
    u = register('expire')
    url = f'/api/user/profile_data/{u["id"]}'
    r1 = SC.get(url, headers=bearer(old_token_for(u['id'], 31)))
    r2 = SC.get(url, headers=bearer(old_token_for(u['id'], 2)))
    renewed = r2.headers.get('X-Auth-Token') or ''
    r3 = SC.get(url, headers=bearer(renewed)) if renewed else None
    c.log(f'1. {http(r1, "error")}；2. HTTP {r2.status_code}，附上新通行證={bool(renewed)}；3. HTTP {r3.status_code if r3 else "-"}')
    check(r1.status_code == 401 and J(r1).get('error') == '登入已過期，請重新登入', '過期的通行證仍可使用')
    check(r2.status_code == 200 and renewed and r3 is not None and r3.status_code == 200, '沒有自動延長')


@case('B02', '重設密碼後舊通行證立即失效',
      pre='使用者 U 已登入（持有通行證 T1）；寄信以模擬方式攔截',
      steps='1. 以 T1 呼叫 API\n2. 用 Email 驗證碼重設密碼\n3. 再以 T1 呼叫 API\n4. 以新密碼登入取得 T2 後呼叫 API',
      expect='1. HTTP 200\n3. HTTP 401，「登入已失效，請重新登入」\n4. HTTP 200',
      note='寄信以模擬方式攔截，未真的寄出')
def _(c):
    u = register('revoke')
    url = f'/api/user/profile_data/{u["id"]}'
    t1 = J(login(u)).get('token')
    r1 = SC.get(url, headers=bearer(t1))
    send_reset_code(u['email'])
    reset_with_code(u['email'], last_reset_code(u['email']), 'NewPass88')
    r3 = SC.get(url, headers=bearer(t1))
    t2 = J(login(u, 'NewPass88')).get('token')
    r4 = SC.get(url, headers=bearer(t2))
    c.log(f'1. HTTP {r1.status_code}；3. {http(r3, "error")}；4. HTTP {r4.status_code}')
    check(r1.status_code == 200 and r4.status_code == 200, '正常通行證無法使用')
    check(r3.status_code == 401 and J(r3).get('error') == '登入已失效，請重新登入', '改密碼後舊通行證仍可使用')


@case('B02', '帳號被停用後通行證立即失效',
      pre='使用者 X 已登入（持有通行證）；super_admin 已登入後台',
      steps='1. 管理者停用 X（POST /user/suspend/{X}）\n2. X 以原通行證呼叫 API\n3. 管理者解除停用',
      expect='2. HTTP 403，「此帳號已被停用，請聯繫客服」')
def _(c):
    x = register('suspendtok')
    tok = J(login(x)).get('token')
    ac = admin_client('sys_super', 'Admin@1234')
    ac.post(f'/user/suspend/{x["id"]}')
    r = SC.get(f'/api/user/profile_data/{x["id"]}', headers=bearer(tok))
    ac.post(f'/user/suspend/{x["id"]}')
    c.log(f'2. {http(r, "error")}')
    check(r.status_code == 403 and J(r).get('error') == '此帳號已被停用，請聯繫客服', '停用後通行證仍可使用')


@case('B02', 'Google 登入必須附上有效的 Google 身分憑證',
      pre='使用者 V（victim）已用 Email 註冊；Google 身分憑證驗證以模擬方式進行',
      steps='1. 只帶 V 的 Email、不帶身分憑證 POST /api/auth/google_login\n2. 帶無效的身分憑證\n3. Email 填 V、但身分憑證屬於 attacker@test.local',
      expect='1. HTTP 400，「請更新 App 後再使用 Google 登入」\n2. HTTP 401，「Google 登入驗證失敗，請重新登入」\n3. 以身分憑證上的 attacker 登入，不會登入 V 的帳號',
      note='Google 身分憑證驗證以模擬方式進行，未連線 Google')
def _(c):
    v = register('victim')
    r1 = SC.post('/api/auth/google_login', json={'email': v['email']})
    r2 = SC.post('/api/auth/google_login', json={'email': v['email'], 'id_token': 'forged-token'})
    r3 = SC.post('/api/auth/google_login', json={'email': v['email'], 'id_token': 'valid:attacker@test.local'})
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}；3. {http(r3, "email")}，登入的 user_id={J(r3).get("user_id")}（V={v["id"]}）')
    check(r1.status_code == 400 and J(r1).get('error') == '請更新 App 後再使用 Google 登入', '沒有身分憑證仍可登入')
    check(r2.status_code == 401 and J(r2).get('error') == 'Google 登入驗證失敗，請重新登入', '無效的身分憑證可以登入')
    check(r3.status_code == 200 and J(r3).get('email') == 'attacker@test.local' and J(r3).get('user_id') != v['id'],
          '可以用別人的 Email 冒用 Google 登入')


@case('B02', '模擬付款關閉時無法購點與訂閱，免費試用不受影響',
      pre='.env 設 DEMO_PAYMENT=off（測試中暫時切換）；使用者 Y 已註冊',
      steps='1. GET /api/store/packages、/api/subscription/plans\n2. POST /api/user/add_points\n3. POST /api/subscription/subscribe\n4. POST /api/subscription/trial',
      expect='1. demo_payment=false\n2、3. HTTP 403，「付款功能尚未開放」\n4. HTTP 200，試用啟用')
def _(c):
    y = register('nopay')
    os.environ['DEMO_PAYMENT'] = 'off'
    try:
        p1 = J(SC.get('/api/store/packages')).get('demo_payment')
        p2 = J(SC.get('/api/subscription/plans')).get('demo_payment')
        r2 = SC.post('/api/user/add_points', json={'user_id': y['id'], 'points': 70, 'price': 50, 'payment_method': 'credit_card'})
        r3 = subscribe(y)
        r4 = SC.post('/api/subscription/trial', json={'user_id': y['id']})
    finally:
        os.environ['DEMO_PAYMENT'] = 'on'
    c.log(f'1. packages demo_payment={p1}、plans demo_payment={p2}；2. {http(r2, "error")}；3. {http(r3, "error")}；4. {http(r4, "message")}')
    check(p1 is False and p2 is False, '沒有回報付款已關閉')
    check(all(r.status_code == 403 and J(r).get('error') == '付款功能尚未開放' for r in (r2, r3)), '付款關閉仍可購點或訂閱')
    check(r4.status_code == 200, '免費試用被擋下')


@case('B02', '網頁版跨網域可以帶通行證並讀到延長後的通行證',
      pre='App 網頁版與後端不同網域（例如 localhost:xxxx 呼叫 127.0.0.1:5050）',
      steps='1. 瀏覽器預檢請求 OPTIONS /api/user/profile_data/{U}，宣告要帶 Authorization 標頭\n2. 帶 Origin 與 2 天前簽發的通行證 GET 同一支 API',
      expect='1. 預檢通過，允許 Authorization 標頭（不需要通行證）\n2. HTTP 200，回應開放 X-Auth-Token、X-Auth-Error 標頭給網頁讀取')
def _(c):
    u = register('cors')
    url = f'/api/user/profile_data/{u["id"]}'
    r1 = SC.options(url, headers={**NO_AUTH, 'Origin': 'http://localhost:5173', 'Access-Control-Request-Method': 'GET',
                                   'Access-Control-Request-Headers': 'authorization'})
    allow = (r1.headers.get('Access-Control-Allow-Headers') or '').lower()
    r2 = SC.get(url, headers={'Origin': 'http://localhost:5173', **bearer(old_token_for(u['id'], 2))})
    expose = (r2.headers.get('Access-Control-Expose-Headers') or '').lower()
    c.log(f'1. HTTP {r1.status_code}，允許標頭={allow}；2. HTTP {r2.status_code}，開放標頭={expose}')
    check(r1.status_code in (200, 204) and 'authorization' in allow, '預檢請求不允許 Authorization')
    check(r2.status_code == 200 and 'x-auth-token' in expose and 'x-auth-error' in expose, '網頁讀不到延長後的通行證')


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
            GEMINI_FAKE['handler'] = None
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
