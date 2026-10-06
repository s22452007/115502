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
# 拍照、對話作業的 AI 建議分數也改成同步，個案裡才能直接檢查
from utils import assignment_ai as _assignment_ai
_assignment_ai.RUN_IN_BACKGROUND = False

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
# 後台原生 SQL 現在走 SQLAlchemy 的 engine（utils/rawsql.py），換掉 engine 就一併指到暫存檔，不用再另外改路徑
scenario_module.UPLOAD_FOLDER = UPLOAD_DIR  # 拍照上傳改存暫存資料夾
admin_module.PHOTO_DIR = UPLOAD_DIR         # 後台刪照片也只動暫存資料夾，不碰真實的 static/photos

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
    School, Dialect, ClassroomAnnouncement, AssignmentSubmission, SubmissionStatus, LatePolicy,
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


def fake_get_ai_reply(topic, user_message, chat_history, japanese_level, dialect_id=None, persona=None):
    FAKE['last_dialect'] = dialect_id   # 讓個案檢查這次對話實際套用的腔調
    FAKE['last_persona'] = persona      # 以及套用的角色人設
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
auth_module.EDU_SCHOOL_DOMAIN_SUFFIXES = ['.edu.tw']   # 不受本機 .env 影響
os.environ['DEMO_PAYMENT'] = 'on'

# ----------------------------------------------------------------------
# 模擬手機推播：不連線 Firebase。PUSH_FAKE['ready'] 代表伺服器有沒有設定推播金鑰，
# 送出的內容存在 PUSHED；PUSH_FAKE['dead'] 裡的 token 視為「這支手機已經收不到」。
# ----------------------------------------------------------------------
import utils.push as push_module

PUSH_FAKE = {'ready': False, 'dead': []}
PUSHED = []


def _fake_send_multicast(tokens, title, body, data):
    PUSHED.append({'tokens': sorted(tokens), 'title': title, 'body': body, 'data': data})
    return [t for t in tokens if t in PUSH_FAKE['dead']]


push_module.RUN_IN_BACKGROUND = False
push_module._firebase_ready = lambda: PUSH_FAKE['ready']
push_module._send_multicast = _fake_send_multicast


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


@case('A01', '校園教育版帳號不可從一般版 Google 登入或自行刪除帳號',
      pre='老師已建立學生帳號 11156099@school.test（account_type=student）',
      steps='1. POST /api/auth/google_login（一般版入口），帶學生帳號 Email 的 Google 身分憑證\n2. POST /api/user/delete_account，user_id=學生帳號',
      expect='1. HTTP 403，「這是校園教育版的學生帳號，請改從「校園教育版」登入」\n2. HTTP 403，「校園教育版帳號無法在 App 刪除，請聯繫老師或系統管理員」，帳號仍存在')
def _(c):
    ensure_edu()
    st = STATE['edu_student']
    r1 = SC.post('/api/auth/google_login', json={'id_token': 'valid:' + st['email']})
    r2 = SC.post('/api/user/delete_account', json={'user_id': st['id']})
    still = user_row(st['id']) is not None
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}，帳號仍存在={still}')
    check(r1.status_code == 403 and J(r1).get('error') == '這是校園教育版的學生帳號，請改從「校園教育版」登入', 'Google 登入未擋下學生帳號')
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
      expect='1. 50 次皆 HTTP 201\n2. HTTP 400，「收藏已達上限（50 個），花 100 點可擴充 +20 個位置」，回傳 vocab_slot=50、collected_count=50')
def _(c):
    u = register('vocabfull')
    STATE['vocabfull'] = u
    codes = [SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': vid}).status_code for vid in VOCAB_IDS[:50]]
    r = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[50]})
    c.log(f'1. 前 50 次中 HTTP 201 共 {codes.count(201)} 次；2. {http(r, "error", "vocab_slot", "collected_count")}')
    check(codes.count(201) == 50, '前 50 個未全部收藏成功')
    check(r.status_code == 400 and J(r).get('vocab_slot') == 50 and J(r).get('collected_count') == 50, '未擋下第 51 個')
    check(J(r).get('error') == '收藏已達上限（50 個），花 100 點可擴充 +20 個位置', '錯誤訊息不正確')


@case('A03', '花點數擴充收藏位後可繼續收藏',
      pre='W 已收藏 50 個（達上限），並購買 110 點',
      steps='1. POST /api/user/spend_points，feature=vocab_expand\n2. GET /api/user/usage_status/{W}\n3. 再收藏第 51 個單字',
      expect='1. HTTP 200，扣 100 點、effect=「+20 個收藏位」，餘額 10 點\n2. vocab_slot=70\n3. HTTP 201 收藏成功')
def _(c):
    u = STATE['vocabfull']
    SC.post('/api/user/add_points', json={'user_id': u['id'], 'points': 110, 'price': 50, 'payment_method': 'credit_card'})
    r1 = SC.post('/api/user/spend_points', json={'user_id': u['id'], 'feature': 'vocab_expand'})
    st = usage(u)
    r3 = SC.post('/api/vocab/collect', json={'user_id': u['id'], 'vocab_id': VOCAB_IDS[50]})
    c.log(f'1. {http(r1, "effect", "total_points")}；2. vocab_slot={st.get("vocab_slot")}、vocab_count={st.get("vocab_count")}；3. {http(r3, "message")}')
    check(r1.status_code == 200 and J(r1).get('effect') == '+20 個收藏位' and J(r1).get('total_points') == 10, '擴充失敗')
    check(st.get('vocab_slot') == 70, '收藏位未增加')
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
      expect='HTTP 200，扣除 15 點（餘額 125）、effect=「+1 次 AI 對話（永久）」；資料庫 ai_extra_count=1')
def _(c):
    p1 = STATE['points']
    r = SC.post('/api/user/spend_points', json={'user_id': p1['id'], 'feature': 'ai_extra'})
    row = user_row(p1['id'])
    c.log(http(r, 'message', 'total_points', 'effect') + f'；資料庫 ai_extra_count={row["ai_extra_count"]}')
    check(r.status_code == 200 and J(r).get('total_points') == 125 and J(r).get('effect') == '+1 次 AI 對話（永久）', '扣點失敗')
    check(row['ai_extra_count'] == 1, '加購次數未增加')


@case('A07', '點數不足時扣點被拒',
      pre='使用者 P2 只有 5 點',
      steps='POST /api/user/spend_points，feature=photo_extra（需 10 點）',
      expect='HTTP 400，「點數不足，需要 10 點」；點數維持 5，不產生消費紀錄')
def _(c):
    p2 = register('poor')
    SC.post('/api/user/add_points', json={'user_id': p2['id'], 'points': 5, 'price': 0, 'payment_method': 'credit_card'})
    r = SC.post('/api/user/spend_points', json={'user_id': p2['id'], 'feature': 'photo_extra'})
    pts = user_row(p2['id'])['j_pts']
    n_spend = count(PointTransaction, user_id=p2['id'], transaction_type='spend')
    c.log(http(r, 'error') + f'；j_pts={pts}、消費紀錄 {n_spend} 筆')
    check(r.status_code == 400 and J(r).get('error') == '點數不足，需要 10 點', '未擋下')
    check(pts == 5 and n_spend == 0, '點數或紀錄被異動')


@case('A07', '查詢點數交易紀錄',
      pre='P1 有 1 筆購點（+140）與 1 筆消費（-15）',
      steps='GET /api/user/transactions/{P1}',
      expect='HTTP 200，依時間新到舊列出 2 筆：-15（spend，ai_extra）、+140（purchase，google_pay，NT$90）')
def _(c):
    r = SC.get(f'/api/user/transactions/{STATE["points"]["id"]}')
    tx = [(t['points'], t['transaction_type'], t['related_feature'] or t['payment_method'], t['price'])
          for t in J(r).get('transactions', [])]
    c.log(f'HTTP {r.status_code}，transactions={tx}')
    check(r.status_code == 200 and tx == [(-15, 'spend', 'ai_extra', 0), (140, 'purchase', 'google_pay', 90)], '交易紀錄不正確')


@case('A07', '免費會員每日拍照額度 2 次',
      pre='免費會員 U1 今日尚未拍照',
      steps='1. POST /api/user/increment_scan 三次\n2. GET /api/user/usage_status/{U1}',
      expect='1. 前 2 次 HTTP 200（daily_scans=1、2，daily_limit=2）；第 3 次 HTTP 403「今日拍照次數已用完，請花 10 點加購 1 次」\n2. photo_count_today=2、photo_daily_limit=2')
def _(c):
    u1 = register('freeU')
    STATE['freeU'] = u1
    rs = [scan(u1) for _ in range(3)]
    st = usage(u1)
    c.log(f'1. ' + '；'.join(http(r, 'daily_scans', 'daily_limit', 'error') for r in rs)
          + f'；2. photo_count_today={st.get("photo_count_today")}、photo_daily_limit={st.get("photo_daily_limit")}')
    check([r.status_code for r in rs] == [200, 200, 403], '額度判斷不正確')
    check(J(rs[2]).get('error') == '今日拍照次數已用完，請花 10 點加購 1 次', '錯誤訊息不正確')
    check(st.get('photo_count_today') == 2 and st.get('photo_daily_limit') == 2, '使用量不正確')


@case('A07', '每日拍照額度用完後使用加購次數',
      pre='U1 今日 2 次已用完；購買 60 點後兌換拍照加購（10 點，+1 次）',
      steps='1. POST /api/user/spend_points，feature=photo_extra\n2. POST /api/user/increment_scan',
      expect='1. HTTP 200，effect=「+1 次拍照（永久）」，餘額 50 點\n2. HTTP 200，daily_scans=3、extra_count 由 1 變 0\n3. 再拍一次 HTTP 403（加購次數已用完）')
def _(c):
    u1 = STATE['freeU']
    SC.post('/api/user/add_points', json={'user_id': u1['id'], 'points': 60, 'price': 50, 'payment_method': 'credit_card'})
    r1 = SC.post('/api/user/spend_points', json={'user_id': u1['id'], 'feature': 'photo_extra'})
    r2 = scan(u1)
    r3 = scan(u1)
    c.log(f'1. {http(r1, "effect", "total_points")}；2. {http(r2, "daily_scans", "extra_count")}；3. HTTP {r3.status_code}')
    check(r1.status_code == 200 and J(r1).get('effect') == '+1 次拍照（永久）' and J(r1).get('total_points') == 50, '兌換失敗')
    check(r2.status_code == 200 and J(r2).get('daily_scans') == 3 and J(r2).get('extra_count') == 0, '未使用加購次數')
    check(r3.status_code == 403, '加購次數用完後仍可拍照')


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
      expect='前 3 次 HTTP 200（daily_ai=1～3，daily_limit=3）；第 4 次 HTTP 403「今日 AI 對話次數已用完，請花 15 點加購 1 次」')
def _(c):
    u1 = STATE['freeU']
    rs = [use_ai(u1) for _ in range(4)]
    c.log('；'.join(http(r, 'daily_ai', 'daily_limit', 'error') for r in rs))
    check([r.status_code for r in rs] == [200, 200, 200, 403], 'AI 額度判斷不正確')
    check(J(rs[0]).get('daily_limit') == 3 and J(rs[3]).get('error') == '今日 AI 對話次數已用完，請花 15 點加購 1 次', '回傳資料不正確')


@case('A07', '訂閱會員每日 AI 對話額度 10 次',
      pre='U2 已訂閱，今日尚未使用 AI 對話',
      steps='POST /api/user/use_ai 十一次',
      expect='前 10 次 HTTP 200（daily_limit=10），第 11 次 HTTP 403',
      note='Premium 的 AI 對話為每天 10 次（2026-10-05 組內討論定案，需求清單已同步修正）')
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
      pre='使用者 U3 今日尚未拍照、未使用 AI 對話、未造句、未朗讀',
      steps='POST /api/daily/claim，user_id=U3',
      expect='HTTP 400，「今日任務尚未完成」')
def _(c):
    u3 = register('daily')
    STATE['daily'] = u3
    r = SC.post('/api/daily/claim', json={'user_id': u3['id']})
    c.log(http(r, 'error'))
    check(r.status_code == 400 and J(r).get('error') == '今日任務尚未完成', '未擋下')


@case('A07', '完成每日任務領取點數獎勵',
      pre='U3 今日完成拍照 1 次與 AI 對話 1 次（連續登入未滿 7 天）；造句與朗讀以模擬 AI 完成',
      steps='1. 只完成拍照與 AI 對話時 POST /api/daily/claim\n2. 再完成造句批改與文章朗讀評分各 1 次後 GET /api/daily/status\n3. POST /api/daily/claim',
      expect='1. HTTP 400，「今日任務尚未完成」（四項都要完成）\n2. photo_done、ai_done、sentence_done、reading_done 皆為 true，can_claim=true\n'
             '3. HTTP 200，「獎勵領取成功！」，隨機獲得 10～30 點並寫入交易紀錄（reward）')
def _(c):
    u3 = STATE['daily']
    scan(u3)
    use_ai(u3)
    r_half = SC.post('/api/daily/claim', json={'user_id': u3['id']})
    # 造句批改、文章朗讀評分各做一次（AI 以模擬資料替代）
    evaluate_sentence(u3)
    ensure_articles()
    GEMINI_FAKE['handler'] = fake_reading_ai
    try:
        SC.post('/api/articles/evaluate', data={'audio': (io.BytesIO(M4A_BYTES), 'reading.m4a'),
                                                'user_id': str(u3['id']), 'article_id': str(STATE['art_free'])},
                content_type='multipart/form-data')
    finally:
        GEMINI_FAKE['handler'] = None
    # 造句可能帶來獎勵點數，但要等「領取」才入帳，這裡的點數仍只會來自每日任務
    st = J(SC.get(f'/api/daily/status?user_id={u3["id"]}'))
    r = SC.post('/api/daily/claim', json={'user_id': u3['id']})
    pts = J(r).get('pts_earned')
    row = user_row(u3['id'])
    n_tx = count(PointTransaction, user_id=u3['id'], transaction_type='reward', related_feature='daily_task_reward')
    STATE['daily_pts'] = row['j_pts']
    c.log(f'1. {http(r_half, "error")}；2. photo_done={st.get("photo_done")}、ai_done={st.get("ai_done")}、'
          f'sentence_done={st.get("sentence_done")}、reading_done={st.get("reading_done")}、can_claim={st.get("can_claim")}；'
          f'3. {http(r, "message", "pts_earned", "j_pts")}；獎勵交易 {n_tx} 筆')
    check(r_half.status_code == 400 and J(r_half).get('error') == '今日任務尚未完成', '只完成兩項就能領獎')
    check(st.get('sentence_done') is True and st.get('reading_done') is True and st.get('can_claim') is True, '任務狀態不正確')
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


@case('A12', '免費版每日造句 3 次，超過需付 5 點',
      pre='使用者 W3 今日已造句 3 次（AI 以模擬資料替代），目前 0 點',
      steps='1. 第 4 次 POST /api/sentence/evaluate（不付點）\n2. 第 4 次帶 pay_with_points=true（0 點）\n3. 購買 20 點後，第 4 次帶 pay_with_points=true',
      expect='1. HTTP 400，status=quota_exceeded、「今日免費次數已用盡」\n2. HTTP 400，status=insufficient_points、「點數不足」\n3. HTTP 200 批改成功，扣 5 點（餘額 15），交易紀錄有 -5（spend）',
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
    check((-5, 'spend') in tx, '付費造句扣除的 5 點沒有寫入交易紀錄')
    check(r1.status_code == 400 and J(r1).get('status') == 'quota_exceeded' and J(r1).get('error') == '今日免費次數已用盡', '未擋下第 4 次')
    check(r2.status_code == 400 and J(r2).get('status') == 'insufficient_points', '點數不足未擋下')
    check(r3.status_code == 200 and J(r3).get('status') == 'success' and pts == 15, '付費造句不正確')


@case('A12', '付費造句 AI 批改失敗時退還點數',
      pre='使用者 W4 今日已造句 3 次（AI 以模擬資料替代），購買 20 點',
      steps='第 4 次 POST /api/sentence/evaluate，pay_with_points=true，AI 批改失敗',
      expect='HTTP 500；扣除的 5 點退還（餘額 20），交易紀錄有 -5（spend）與 +5（退還）',
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
    check((-5, 'sentence_extra') in tx and (5, 'sentence_extra_refund') in tx, '扣點與退點沒有寫入交易紀錄')


@case('A12', '造句批改與朗讀評分的每日次數依方案不同',
      pre='免費版使用者 F、Premium 使用者 P（AI 以模擬資料替代）',
      steps='1. GET /api/user/usage_status 查兩人的每日上限\n2. P 造句 5 次後再造第 6 次\n'
            '3. F 朗讀評分 1 次後再朗讀第 2 次\n4. P 朗讀評分 5 次後再朗讀第 6 次',
      expect='1. F：造句 3、朗讀 1；P：造句 5、朗讀 5\n2. 前 5 次成功，第 6 次 HTTP 400 quota_exceeded\n'
             '3. 第 2 次 status=quota_exceeded，提示升級 Premium\n4. 前 5 次成功，第 6 次 status=quota_exceeded',
      note='AI 回應以模擬資料替代')
def _(c):
    ensure_articles()
    aid = STATE['art_free']
    f, p = register('quotaF'), register('quotaP')
    set_user(p['id'], is_premium=True, subscription_end_date=datetime.utcnow() + timedelta(days=30))
    uf = J(SC.get(f'/api/user/usage_status/{f["id"]}'))
    up = J(SC.get(f'/api/user/usage_status/{p["id"]}'))

    p_sentences = [evaluate_sentence(p).status_code for _ in range(5)]
    r_p6 = evaluate_sentence(p)

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
          f'2. P 前 5 次={p_sentences}、第 6 次 {http(r_p6, "status")}；'
          f'3. F 朗讀={f_reads}，提示={f_second.get("message")}；4. P 朗讀={p_reads}')
    check(uf.get('sentence_daily_limit') == 3 and uf.get('reading_daily_limit') == 1, '免費版上限不正確')
    check(up.get('sentence_daily_limit') == 5 and up.get('reading_daily_limit') == 5, 'Premium 上限不正確')
    check(p_sentences == [200] * 5 and r_p6.status_code == 400 and J(r_p6).get('status') == 'quota_exceeded',
          'Premium 造句次數不是 5 次')
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


@case('A13', '學生無法自行退出教室',
      pre='學生在「一年甲班」中',
      steps='1. POST /api/classroom/leave，user_id、classroom_id=一年甲班\n2. GET /api/classroom/my/{學生 id}',
      expect='1. HTTP 404，沒有退出教室的功能\n2. count=1，仍在一年甲班；要離開班級須由老師在班級名冊移出')
def _(c):
    ensure_edu()
    st, rid = STATE['edu_student'], STATE['edu_rooms']['open']
    r1 = SC.post('/api/classroom/leave', json={'user_id': st['id'], 'classroom_id': rid})
    my = J(SC.get(f'/api/classroom/my/{st["id"]}'))
    rooms = [x.get('name') for x in my.get('classrooms', [])]
    c.log(f'1. HTTP {r1.status_code}；2. count={my.get("count")}，教室={rooms}')
    check(r1.status_code == 404, '學生仍可自行退出教室')
    check(my.get('count') == 1 and rooms == ['一年甲班'], '學生不在原本的教室裡')


# ----------------------------------------------------------------------
# A13 校園教育版：學校 Google 帳號登入（services/auth.py）
# ----------------------------------------------------------------------
def ensure_schools():
    """前置：管理者已在後台「學校管理」建立學校"""
    if 'schools' in STATE:
        return STATE['schools']
    with S.app_context():
        uni = School(name='測試科技大學', student_domains='tust.edu.tw')
        hs = School(name='範例高中', student_domains='.example-hs.edu.tw')
        closed = School(name='停用學院', student_domains='closed.edu.tw', is_active=False)
        db.session.add_all([uni, hs, closed])
        db.session.commit()
        STATE['schools'] = {'uni': uni.id, 'hs': hs.id, 'closed': closed.id}
    return STATE['schools']


def edu_google(token, **body):
    return SC.post('/api/auth/edu_google_login', json={'id_token': token, **body})


@case('A13', '選擇學校後以學校 Google 帳號登入，自動建立學生帳號',
      pre='後台已建立「測試科技大學」（@tust.edu.tw）與已停用的「停用學院」；11156001@tust.edu.tw 尚未有帳號；老師的「一年甲班」代碼 K7M3P9',
      steps='1. GET /api/auth/schools\n2. POST /api/auth/edu_google_login，school_id=測試科技大學、Google 身分憑證為 11156001@tust.edu.tw\n'
            '3. 同一個帳號再登入一次\n4. 以班級代碼 K7M3P9 加入教室',
      expect='1. 清單有「測試科技大學」與網域 tust.edu.tw，沒有已停用的學校\n2. HTTP 200，is_new=true、account_type=student，自動建立學生帳號並記下學校\n'
             '3. HTTP 200，is_new=false，沿用同一個帳號\n4. HTTP 201，成功加入教室',
      note='Google 身分憑證驗證以模擬方式進行')
def _(c):
    ensure_edu()
    sch = ensure_schools()
    r1 = SC.get('/api/auth/schools')
    names = {s['name']: s for s in J(r1).get('schools', [])}
    r2 = edu_google('valid:11156001@tust.edu.tw', school_id=sch['uni'])
    r3 = edu_google('valid:11156001@tust.edu.tw', school_id=sch['uni'])
    uid = J(r2).get('user_id')
    row = user_row(uid) if uid else {}
    n = count(User, email='11156001@tust.edu.tw')
    r4 = SC.post('/api/classroom/join', json={'user_id': uid, 'join_code': 'K7M3P9'})
    c.log(f'1. HTTP {r1.status_code}，測試科技大學 domains={(names.get("測試科技大學") or {}).get("domains")}、停用學院在清單={"停用學院" in names}；'
          f'2. {http(r2, "message", "account_type", "is_new", "school_name")}；3. {http(r3, "is_new")}，帳號 {n} 筆；'
          f'4. {http(r4, "status", "message")}')
    check(r1.status_code == 200 and (names.get('測試科技大學') or {}).get('domains') == ['tust.edu.tw']
          and '停用學院' not in names, '學校清單不正確')
    check(r2.status_code == 200 and J(r2).get('is_new') is True and J(r2).get('account_type') == 'student'
          and J(r2).get('school_name') == '測試科技大學' and J(r2).get('token'), '第一次登入沒有建立學生帳號')
    check(row.get('account_type') == 'student' and row.get('school_id') == sch['uni'] and len(row.get('friend_id') or '') == 8,
          '學生帳號資料不正確')
    check(r3.status_code == 200 and J(r3).get('is_new') is False and J(r3).get('user_id') == uid and n == 1, '重複建立帳號')
    check(r4.status_code == 201 and J(r4).get('status') == 'success', '新學生無法用班級代碼加入教室')
    with S.app_context():   # 還原：讓後面的個案看到的一年甲班成員數不受影響
        ClassroomMember.query.filter_by(classroom_id=STATE['edu_rooms']['open'], student_id=uid).delete()
        db.session.commit()


@case('A13', '學校 Google 登入的限制',
      pre='「測試科技大學」（@tust.edu.tw）、「範例高中」（.example-hs.edu.tw）、已停用的「停用學院」；11156777@tust.edu.tw 已是一般版帳號',
      steps='POST /api/auth/edu_google_login：\n1. 沒有選學校\n2. 選已停用的學校\n3. Google 身分憑證無效\n4. 選測試科技大學，用一般 Gmail\n'
            '5. 選測試科技大學，用範例高中的帳號\n6. 用不是學號的帳號 wang.teacher@tust.edu.tw\n7. 用已經是一般版帳號的 11156777@tust.edu.tw',
      expect='1、2. HTTP 400，status=school_required、「請先選擇學校」\n3. HTTP 401\n4. HTTP 403，status=wrong_domain\n'
             '5. HTTP 403，status=wrong_school，提示是範例高中的帳號\n6. HTTP 403，status=not_student\n7. HTTP 403，status=wrong_portal；皆不建立帳號',
      note='Google 身分憑證驗證以模擬方式進行')
def _(c):
    sch = ensure_schools()
    with S.app_context():
        db.session.add(User(email='11156777@tust.edu.tw', username='一般版使用者', account_type=AccountType.GENERAL,
                            password_hash=generate_password_hash('Pass1234')))
        db.session.commit()
        before = User.query.count()
    r1 = edu_google('valid:11156002@tust.edu.tw')
    r2 = edu_google('valid:11156002@closed.edu.tw', school_id=sch['closed'])
    r3 = edu_google('not-a-token', school_id=sch['uni'])
    r4 = edu_google('valid:someone@gmail.com', school_id=sch['uni'])
    r5 = edu_google('valid:11156002@stu.example-hs.edu.tw', school_id=sch['uni'])
    r6 = edu_google('valid:wang.teacher@tust.edu.tw', school_id=sch['uni'])
    r7 = edu_google('valid:11156777@tust.edu.tw', school_id=sch['uni'])
    after = count(User)
    c.log(f'1. {http(r1, "status", "error")}；2. {http(r2, "status")}；3. {http(r3, "error")}；4. {http(r4, "status", "error")}；'
          f'5. {http(r5, "status", "error")}；6. {http(r6, "status", "error")}；7. {http(r7, "status", "error")}；帳號數 {before} → {after}')
    check(r1.status_code == 400 and J(r1).get('status') == 'school_required' and J(r1).get('error') == '請先選擇學校', '沒選學校未擋下')
    check(r2.status_code == 400 and J(r2).get('status') == 'school_required', '已停用的學校仍可登入')
    check(r3.status_code == 401, '無效的身分憑證未擋下')
    check(r4.status_code == 403 and J(r4).get('status') == 'wrong_domain', '一般 Gmail 可登入教育版')
    check(r5.status_code == 403 and J(r5).get('status') == 'wrong_school' and '範例高中' in J(r5).get('error', ''), '別校帳號未擋下')
    check(r6.status_code == 403 and J(r6).get('status') == 'not_student', '非學號帳號未擋下')
    check(r7.status_code == 403 and J(r7).get('status') == 'wrong_portal', '一般版帳號可登入教育版')
    check(before == after, '被拒絕的登入卻建立了帳號')


@case('A13', '清單沒有自己的學校時在 App 新增學校',
      pre='學校清單沒有「新設大學」',
      steps='POST /api/auth/edu_google_login，帶 new_school_name：\n1. 「新設大學」，用一般 Gmail\n2. 「新設大學」，用 b1234567@newuni.edu.tw\n'
            '3. 「新設大學」，用另一個網域 b7654321@another.edu.tw\n4. 名稱打成「新社大學」，用同網域 b2222222@newuni.edu.tw\n5. GET /api/auth/schools',
      expect='1. HTTP 403，status=wrong_domain（只收學校網域）\n2. HTTP 200，school_created=true，學校網域取自 Google 驗證過的 Email，並寫入操作日誌\n'
             '3. HTTP 409（同名但網域不同）\n4. HTTP 200，school_created=false，歸到既有的「新設大學」，不重複建立\n5. 清單出現「新設大學」',
      note='Google 身分憑證驗證以模擬方式進行')
def _(c):
    ensure_schools()
    r1 = edu_google('valid:b1234567@gmail.com', new_school_name='新設大學')
    n1 = count(School, name='新設大學')
    r2 = edu_google('valid:b1234567@newuni.edu.tw', new_school_name='新設大學')
    with S.app_context():
        s = School.query.filter_by(name='新設大學').first()
        info = (s.student_domains, s.created_by_user_id, s.id) if s else (None, None, None)
        n_log = SystemLog.query.filter_by(target_table='school', target_id=info[2], action='CREATE').count()
    r3 = edu_google('valid:b7654321@another.edu.tw', new_school_name='新設大學')
    r4 = edu_google('valid:b2222222@newuni.edu.tw', new_school_name='新社大學')
    n_typo = count(School, name='新社大學')
    names = [x['name'] for x in J(SC.get('/api/auth/schools')).get('schools', [])]
    c.log(f'1. {http(r1, "status")}，建立學校 {n1} 間；2. {http(r2, "school_created", "school_name", "is_new")}，網域={info[0]}、操作日誌 {n_log} 筆；'
          f'3. {http(r3, "error")}；4. {http(r4, "school_created", "school_name")}，「新社大學」{n_typo} 間；5. 清單有新設大學={"新設大學" in names}')
    check(r1.status_code == 403 and J(r1).get('status') == 'wrong_domain' and n1 == 0, '一般 Gmail 可以新增學校')
    check(r2.status_code == 200 and J(r2).get('school_created') is True and J(r2).get('school_name') == '新設大學'
          and info[0] == 'newuni.edu.tw' and info[1] == J(r2).get('user_id') and n_log == 1, '新增學校不正確')
    check(r3.status_code == 409, '同名不同網域未擋下')
    check(r4.status_code == 200 and J(r4).get('school_created') is False and J(r4).get('school_name') == '新設大學' and n_typo == 0,
          '同網域重複建立學校')
    check('新設大學' in names, '新學校沒有出現在清單')


@case('A13', '學校合約名額上限',
      pre='後台已建立「名額學院」（@seat.edu.tw），合約名額暫設為 1 人（後台表單要填 100 的倍數，此處直接改資料庫以便測試）',
      steps='1. s0000001@seat.edu.tw 登入（第 1 位學生）\n2. s0000002@seat.edu.tw 登入（第 2 位）\n3. s0000001@ 再登入一次\n'
            '4. 管理者停用 s0000001@ 後，s0000002@ 再登入\n5. 後台「學校管理」查看名額；把名額改成 150、再改成 300',
      expect='1. HTTP 200，建立帳號\n2. HTTP 403，status=seat_full，提示名額已滿（1 人），不建立帳號\n3. HTTP 200，已有帳號不受名額影響\n'
             '4. HTTP 200，停用的帳號釋出名額\n5. 頁面顯示 1 / 1 與「已滿」；改 150 被拒（要是 100 的倍數）、改 300 成功',
      note='Google 身分憑證驗證以模擬方式進行')
def _(c):
    with S.app_context():
        s = School(name='名額學院', student_domains='seat.edu.tw', seat_limit=1)
        db.session.add(s)
        db.session.commit()
        sid = s.id
    r1 = edu_google('valid:s0000001@seat.edu.tw', school_id=sid)
    r2 = edu_google('valid:s0000002@seat.edu.tw', school_id=sid)
    n2 = count(User, email='s0000002@seat.edu.tw')
    r3 = edu_google('valid:s0000001@seat.edu.tw', school_id=sid)
    set_user(J(r1).get('user_id'), is_suspended=True)
    r4 = edu_google('valid:s0000002@seat.edu.tw', school_id=sid)
    boss = super_client()
    page = boss.get('/school/list').get_data(as_text=True)
    post = lambda url, **d: (boss.post(url, data=d), flashes(boss))[1]
    form = {'name': '名額學院', 'student_domains': 'seat.edu.tw', 'student_id_pattern': ''}
    f5a = post(f'/school/edit/{sid}', **form, seat_limit='150')
    f5b = post(f'/school/edit/{sid}', **form, seat_limit='300')
    with S.app_context():
        limit_after = db.session.get(School, sid).seat_limit
    c.log(f'1. {http(r1, "is_new")}；2. {http(r2, "status", "error")}，帳號 {n2} 筆；3. {http(r3, "is_new")}；4. {http(r4, "is_new")}；'
          f'5. 頁面顯示 1 / 1={"1 / 1" in page}、已滿={"已滿" in page}；改 150：{f5a}；改 300：{f5b}，名額={limit_after}')
    check(r1.status_code == 200 and J(r1).get('is_new') is True, '第 1 位學生無法登入')
    check(r2.status_code == 403 and J(r2).get('status') == 'seat_full' and '1 人' in J(r2).get('error', '') and n2 == 0, '超過名額仍建立帳號')
    check(r3.status_code == 200 and J(r3).get('is_new') is False, '已有帳號的學生被名額擋下')
    check(r4.status_code == 200 and J(r4).get('is_new') is True, '停用帳號後名額沒有釋出')
    check('1 / 1' in page and '已滿' in page, '後台沒有顯示名額使用狀況')
    check('倍數' in str(f5a) and limit_after == 300, '名額修改不正確')


@case('A13', '老師綁定學校，貼名單建立的學生帳號算進合約名額',
      pre='後台已建立「名冊學院」（@roster.edu.tw），合約名額暫設為 2 人；最高管理者已登入',
      steps='1. 於「教師帳號管理」新增老師 chen@roster.edu.tw，學校選名冊學院；再新增 lin@other.test，不選學校\n'
            '2. 陳老師在自己的班級貼名單 3 位學生\n3. 改貼 2 位學生\n4. 林老師在自己的班級貼名單 1 位學生\n'
            '5. 「學校管理」查看名冊學院名額\n6. 管理者把林老師設為名冊學院的老師，再查看名額\n7. 陳老師重設名冊學生的密碼',
      expect='1. 陳老師綁定名冊學院；林老師沒有學校\n2. 提示合約名額不足（名額 2 人、已用 0 人、要新建 3 個），不建立帳號\n'
             '3. 建立 2 個帳號，都屬於名冊學院\n4. 建立 1 個帳號，沒有學校（不計名額）\n5. 顯示 2 / 2 與「已滿」\n'
             '6. 林老師綁定名冊學院，他建立的學生一併算進去，顯示 3 / 2\n7. 名冊帳號仍可重設密碼（不是 Google 帳號）')
def _(c):
    boss = super_client()
    with S.app_context():
        s = School(name='名冊學院', student_domains='roster.edu.tw', seat_limit=2)
        db.session.add(s)
        db.session.commit()
        sid = s.id
    add = lambda **d: (boss.post('/teacher_account/add', data=d), flashes(boss))[1]
    f1a = add(email='chen@roster.edu.tw', username='陳名冊老師', password='Sensei#2026a', school_id=str(sid))
    f1b = add(email='lin@other.test', username='林無校老師', password='Sensei#2026a')
    with S.app_context():
        chen = User.query.filter_by(email='chen@roster.edu.tw').first()
        lin = User.query.filter_by(email='lin@other.test').first()
        chen_school, lin_school = chen.school_id, lin.school_id
        chen.must_change_password = lin.must_change_password = False
        r1 = Classroom(teacher_id=chen.id, name='名冊一班', join_code='RSTR01', is_open=True)
        r2 = Classroom(teacher_id=lin.id, name='無校一班', join_code='RSTR02', is_open=True)
        db.session.add_all([r1, r2])
        db.session.commit()
        rid1, rid2, chen_id, lin_id = r1.id, r2.id, chen.id, lin.id
    web = teacher_client(chen_id, '陳名冊老師')
    web.post(f'/teacher/classroom/{rid1}/students/add', data={'roster': '98000001 甲\n98000002 乙\n98000003 丙'})
    f2 = flashes(web)
    n2 = count(User, email='98000001') + count(User, email='98000003')
    page3 = html(web.post(f'/teacher/classroom/{rid1}/students/add', data={'roster': '98000001 甲\n98000002 乙'}))
    with S.app_context():
        made3 = [u.school_id for u in User.query.filter(User.email.in_(['98000001', '98000002'])).all()]
        u1 = User.query.filter_by(email='98000001').first()
        u1_id = u1.id if u1 else None
    web2 = teacher_client(lin_id, '林無校老師')
    page4 = html(web2.post(f'/teacher/classroom/{rid2}/students/add', data={'roster': '98000009 丁'}))
    with S.app_context():
        s9 = User.query.filter_by(email='98000009').first()
        s9_before, s9_id = (s9.school_id if s9 else 'none'), (s9.id if s9 else None)
    page5 = boss.get('/school/list').get_data(as_text=True)
    boss.post(f'/teacher_account/school/{lin_id}', data={'school_id': str(sid)})
    f6 = flashes(boss)
    with S.app_context():
        lin_after = db.session.get(User, lin_id).school_id
        s9_after = db.session.get(User, s9_id).school_id if s9_id else None
    page6 = boss.get('/school/list').get_data(as_text=True)
    page7 = html(web.post(f'/teacher/classroom/{rid1}/student/{u1_id}/reset_password'))
    f7 = flashes(web)
    c.log(f'1. {f1a}，陳老師 school_id={chen_school}；{f1b}，林老師 school_id={lin_school}；2. {f2}，帳號 {n2} 個；'
          f'3. 畫面提示新建 2 個帳號={"新建立 2 個學生帳號" in page3}，學校={made3}；4. 畫面提示新建 1 個帳號={"新建立 1 個學生帳號" in page4}，學校={s9_before}；'
          f'5. 2 / 2={"2 / 2" in page5}、已滿={"已滿" in page5}；6. {f6}，林老師 school_id={lin_after}、學生 school_id={s9_after}，3 / 2={"3 / 2" in page6}；'
          f'7. 畫面顯示臨時密碼={"臨時密碼" in page7}，提示={f7}')
    check(chen_school == sid and lin_school is None, '新增老師時的學校不正確')
    check(any('合約名額不足' in m for m in f2) and n2 == 0, '超過名額仍建立帳號')
    check('新建立 2 個學生帳號' in page3 and made3 == [sid, sid], '名冊帳號沒有歸到老師的學校')
    check('新建立 1 個學生帳號' in page4 and s9_before is None, '沒有學校的老師建帳號不正確')
    check('2 / 2' in page5 and '已滿' in page5, '後台名額沒有算進名冊帳號')
    check(lin_after == sid and s9_after == sid and '3 / 2' in page6 and any('1 個學生帳號一併算進' in m for m in f6), '設定老師學校沒有帶動學生')
    check('臨時密碼' in page7 and not any('Google' in m for m in f7), '名冊帳號被當成 Google 帳號')


# ----------------------------------------------------------------------
# A13 校園教育版：班級公告、遲交規則、手機推播（老師端網頁 + 學生端 App API）
# ----------------------------------------------------------------------
def ensure_class():
    """前置：林老師的「三年丙班」有學生甲、乙兩人；另有陳老師與不在班上的學生丙"""
    if 'cls' in STATE:
        return STATE['cls']
    with S.app_context():
        def user(email, name, kind):
            u = User(email=email, username=name, account_type=kind, password_hash=generate_password_hash('Pass@1234'))
            db.session.add(u)
            db.session.flush()
            return u.id
        t = user('teacher_lin@school.test', '林老師', AccountType.TEACHER)
        t2 = user('teacher_chen@school.test', '陳老師', AccountType.TEACHER)
        s1 = user('11156101@school.test', '學生甲', AccountType.STUDENT)
        s2 = user('11156102@school.test', '學生乙', AccountType.STUDENT)
        s3 = user('11156103@school.test', '學生丙', AccountType.STUDENT)
        room = Classroom(teacher_id=t, name='三年丙班', join_code='P3C7X2', is_open=True)
        db.session.add(room)
        db.session.flush()
        db.session.add_all([ClassroomMember(classroom_id=room.id, student_id=s1, display_name='學生甲'),
                            ClassroomMember(classroom_id=room.id, student_id=s2, display_name='學生乙')])
        db.session.commit()
        STATE['cls'] = {'teacher': t, 'teacher2': t2, 's1': s1, 's2': s2, 's3': s3, 'room': room.id}
    return STATE['cls']


def teacher_client(teacher_id, name):
    """老師已登入老師後台的瀏覽器"""
    c = A.test_client()
    with c.session_transaction() as sess:
        sess['role'] = 'teacher'
        sess['teacher_user_id'] = teacher_id
        sess['admin_user'] = name
    return c


def flashes(client):
    """取出這次操作後網頁要顯示的提示訊息"""
    with client.session_transaction() as sess:
        return [m for _, m in sess.pop('_flashes', [])]


def announcements_of(uid, room):
    return SC.get(f'/api/classroom/{room}/announcements?user_id={uid}')


def unread_of(uid, room):
    rooms = J(SC.get(f'/api/classroom/my/{uid}')).get('classrooms', [])
    return next((x.get('unread_count') for x in rooms if x['classroom_id'] == room), None)


@case('A13', '老師發布班級公告，學生看到未讀紅點',
      pre='林老師的「三年丙班」有學生甲、乙；學生丙不在班上',
      steps='1. 老師於後台公告頁送出沒有標題的公告\n2. 老師發布公告「期中考範圍」\n3. 學生甲 GET /api/classroom/my/{甲}\n'
            '4. 學生甲 GET /api/classroom/{班級}/announcements，之後再查一次我的教室與公告\n5. 老師端查看已讀人數\n6. 學生丙查看公告',
      expect='1. 提示「請填寫公告標題」，不建立公告\n2. 提示公告已發布\n3. unread_count=1\n4. 列出 1 則公告且 is_new=true；看過之後 unread_count=0、is_new=false\n'
             '5. 已讀 1 人／全班 2 人\n6. HTTP 404，「找不到這個教室」')
def _(c):
    k = ensure_class()
    web = teacher_client(k['teacher'], '林老師')
    url = f'/teacher/classroom/{k["room"]}/announcements'
    web.post(url, data={'title': '   ', 'content': '沒有標題'})
    f1 = flashes(web)
    n1 = count(ClassroomAnnouncement, classroom_id=k['room'])
    web.post(url, data={'title': '期中考範圍', 'content': '第 1～5 課，請帶學生證。'})
    f2 = flashes(web)
    unread1 = unread_of(k['s1'], k['room'])
    r4 = announcements_of(k['s1'], k['room'])
    first = J(r4).get('announcements', [])
    unread2 = unread_of(k['s1'], k['room'])
    again = J(announcements_of(k['s1'], k['room'])).get('announcements', [])
    with A.app_context():
        from services.teacher_service import get_announcements
        t_view = get_announcements(k['room'])
    r6 = announcements_of(k['s3'], k['room'])
    STATE['ann_id'] = first[0]['announcement_id'] if first else None
    c.log(f'1. 提示={f1}，公告 {n1} 則；2. 提示={f2}；3. unread_count={unread1}；'
          f'4. HTTP {r4.status_code}，{[(a["title"], a["is_new"]) for a in first]}，之後 unread_count={unread2}、is_new={[a["is_new"] for a in again]}；'
          f'5. 已讀 {t_view[0]["read_count"]}／{t_view[0]["member_count"]}；6. {http(r6, "error")}')
    check(f1 == ['請填寫公告標題'] and n1 == 0, '沒有標題的公告未擋下')
    check(len(f2) == 1 and f2[0].startswith('公告已發布'), '公告發布失敗')
    check(unread1 == 1, '學生沒有看到未讀紅點')
    check(r4.status_code == 200 and [(a['title'], a['content'], a['is_new']) for a in first]
          == [('期中考範圍', '第 1～5 課，請帶學生證。', True)], '公告內容不正確')
    check(unread2 == 0 and [a['is_new'] for a in again] == [False], '看過之後仍顯示未讀')
    check(t_view[0]['read_count'] == 1 and t_view[0]['member_count'] == 2, '老師端已讀人數不正確')
    check(r6.status_code == 404 and J(r6).get('error') == '找不到這個教室', '非成員可以看公告')


@case('A13', '公告修改、刪除與權限',
      pre='「三年丙班」有 1 則公告「期中考範圍」，學生甲已讀；陳老師不是這班的老師',
      steps='1. 林老師修改公告標題與內容\n2. 陳老師修改、刪除這則公告\n3. 最高管理者於這班的公告頁發布公告\n4. 林老師刪除公告',
      expect='1. 提示「公告已更新」，學生看到新內容，但不會重新變成未讀\n2. 提示「找不到該公告」，公告不變\n'
             '3. 提示管理者無法代替老師發公告，不建立公告\n4. 提示「公告已刪除」，學生端公告為 0 則，並寫入操作日誌')
def _(c):
    k = ensure_class()
    aid = STATE['ann_id']
    web = teacher_client(k['teacher'], '林老師')
    web.post(f'/teacher/announcement/{aid}/edit', data={'title': '期中考範圍（更新）', 'content': '改為第 1～6 課。'})
    f1 = flashes(web)
    unread = unread_of(k['s1'], k['room'])
    seen = J(announcements_of(k['s1'], k['room'])).get('announcements', [])
    other = teacher_client(k['teacher2'], '陳老師')
    other.post(f'/teacher/announcement/{aid}/edit', data={'title': '被別人改掉', 'content': ''})
    f2a = flashes(other)
    other.post(f'/teacher/announcement/{aid}/delete')
    f2b = flashes(other)
    with S.app_context():
        row = db.session.get(ClassroomAnnouncement, aid)
        kept = (row.title, row.updated_at is not None) if row else None
    boss = admin_client('sys_super', 'Admin@1234')
    boss.post(f'/teacher/classroom/{k["room"]}/announcements', data={'title': '管理者代發', 'content': ''})
    f3 = flashes(boss)
    n3 = count(ClassroomAnnouncement, classroom_id=k['room'])
    web.post(f'/teacher/announcement/{aid}/delete')
    f4 = flashes(web)
    left = J(announcements_of(k['s1'], k['room'])).get('announcements', [])
    n_log = count(SystemLog, target_table='classroom_announcement', target_id=aid, action='DELETE')
    c.log(f'1. 提示={f1}，學生看到「{seen[0]["title"] if seen else None}」、unread_count={unread}；2. 提示={f2a + f2b}，公告仍為「{kept[0] if kept else None}」；'
          f'3. 提示={f3}，公告 {n3} 則；4. 提示={f4}，學生端公告 {len(left)} 則、操作日誌 {n_log} 筆')
    check(f1 == ['公告已更新'] and unread == 0 and seen and seen[0]['title'] == '期中考範圍（更新）'
          and seen[0]['content'] == '改為第 1～6 課。' and seen[0]['is_new'] is False, '修改公告不正確')
    check(f2a == ['找不到該公告'] and f2b == ['找不到該公告'] and kept == ('期中考範圍（更新）', True), '別班老師可以動這則公告')
    check(len(f3) == 1 and '管理者無法代替老師發公告' in f3[0] and n3 == 1, '管理者可以代發公告')
    check(f4 == ['公告已刪除'] and left == [] and n_log == 1, '刪除公告不正確')


@case('A13', '出作業時設定遲交規則並自動發公告',
      pre='林老師的「三年丙班」',
      steps='老師於後台「出題新作業」發布造句作業（截止時間為 3 天後）：\n1. 遲交規則選「遲交扣分」、扣 10 分，勾選「通知學生」\n'
            '2. 遲交規則選「遲交扣分」，扣分填「abc」\n3. 遲交規則選「截止後不收」，不勾選通知',
      expect='1. 作業存為遲交扣 10 分；自動發一則「新作業：第二課造句」公告，內文含截止時間與「遲交扣 10 分」，學生可從公告點進作業\n'
             '2. 作業照常發布，提示扣分要填 1～100 的數字，並先設為允許遲交\n3. 作業存為截止後不收，不發公告')
def _(c):
    k = ensure_class()
    web = teacher_client(k['teacher'], '林老師')
    url = f'/teacher/classroom/{k["room"]}/assignment/create'
    due = (datetime.utcnow() + timedelta(hours=8, days=3)).replace(second=0, microsecond=0)

    def create(title, **extra):
        web.post(url, data={'task_type': 'sentence', 'title': title, 'instructions': '用今天教的文法造句',
                            'grammar_point': '〜てください', 'due_at': due.isoformat(timespec='minutes'), **extra})
        msgs = flashes(web)
        with S.app_context():
            a = Assignment.query.filter_by(classroom_id=k['room'], title=title).first()
            return msgs, (a.id, a.late_policy, a.late_penalty) if a else None

    f1, a1 = create('第二課造句', late_policy='deduct', late_penalty='10', announce='1')
    f2, a2 = create('第三課造句', late_policy='deduct', late_penalty='abc')
    f3, a3 = create('第四課造句', late_policy='reject')
    anns = J(announcements_of(k['s1'], k['room'])).get('announcements', [])
    STATE['late_assignments'] = {'deduct': a1[0], 'reject': a3[0]}
    c.log(f'1. 提示={f1}，遲交規則={a1[1:]}；2. 提示={f2}，遲交規則={a2[1:]}；3. 提示={f3}，遲交規則={a3[1:]}；'
          f'公告={[(x["title"], x["content"], x["assignment_id"] == a1[0]) for x in anns]}')
    check(a1[1:] == ('deduct', 10) and a2[1:] == ('allow', 0) and a3[1:] == ('reject', 0), '遲交規則儲存不正確')
    check(any('遲交扣分要填 1～100 的數字' in m and '允許遲交' in m for m in f2), '扣分填錯沒有提醒')
    check(len(anns) == 1 and anns[0]['title'] == '新作業：第二課造句' and anns[0]['assignment_id'] == a1[0]
          and '遲交扣 10 分' in anns[0]['content'] and due.strftime('%Y-%m-%d %H:%M') in anns[0]['content'], '自動公告不正確')


@case('A13', '截止後不收遲交與遲交扣分',
      pre='「三年丙班」有 4 份文章測驗作業（各 2 題）：A 昨天截止、截止後不收；B 昨天截止、遲交扣 10 分；C 昨天截止、允許遲交；D 明天截止、截止後不收',
      steps='學生甲全部答對：\n1. POST /api/assignment/submit_quiz 繳交 A，並 GET /api/assignment/{A}\n2. 繳交 B\n3. 繳交 C\n4. 繳交 D\n'
            '5. GET /api/classroom/{班級}/grades',
      expect='1. HTTP 403，status=closed、「已超過截止時間，老師設定這份作業不收遲交」，不產生繳交紀錄；作業 is_closed=true\n'
             '2. HTTP 200，得 100 分、遲交扣 10 分、計入 90 分\n3. HTTP 200，100 分不扣分\n4. HTTP 200（還沒截止）\n'
             '5. 成績分頁：A 未交；B 原始 100、計入 90、標示遲交；C 100 分、標示遲交；D 100 分')
def _(c):
    k = ensure_class()
    now_tw = datetime.utcnow() + timedelta(hours=8)   # 截止時間存的是老師輸入的台灣時間
    quiz = {'questions': [{'type': 'choice', 'question': '「ねこ」是什麼？', 'options': ['貓', '狗', '鳥', '魚'], 'answer': 'A'},
                          {'type': 'truefalse', 'question': '「いぬ」是狗。', 'answer': 'O'}]}
    ids = {}
    with S.app_context():
        for key, days, policy, pen in [('A', -1, LatePolicy.REJECT, 0), ('B', -1, LatePolicy.DEDUCT, 10),
                                       ('C', -1, LatePolicy.ALLOW, 0), ('D', 1, LatePolicy.REJECT, 0)]:
            a = Assignment(classroom_id=k['room'], title=f'閱讀測驗 {key}', task_type=TaskType.ARTICLE, config=dict(quiz),
                           due_at=now_tw + timedelta(days=days), late_policy=policy, late_penalty=pen, is_published=True)
            db.session.add(a)
            db.session.flush()
            ids[key] = a.id
        db.session.commit()

    def hand_in(key):
        return SC.post('/api/assignment/submit_quiz', json={'user_id': k['s1'], 'assignment_id': ids[key], 'answers': ['A', 'O']})

    rs = {key: hand_in(key) for key in 'ABCD'}
    detail = J(SC.get(f'/api/assignment/{ids["A"]}?user_id={k["s1"]}')).get('assignment', {})
    n_a = count(AssignmentSubmission, assignment_id=ids['A'])
    grades = {g['assignment_id']: g for g in
              J(SC.get(f'/api/classroom/{k["room"]}/grades?user_id={k["s1"]}')).get('assignments', [])}
    cell = {key: (grades[ids[key]]['status'], grades[ids[key]]['score'], grades[ids[key]]['effective'],
                  grades[ids[key]]['deduct'], grades[ids[key]]['late']) for key in 'ABCD'}
    STATE['quiz_ids'] = ids
    c.log(f'1. {http(rs["A"], "status", "error")}，繳交紀錄 {n_a} 筆，is_closed={detail.get("is_closed")}；'
          f'2. {http(rs["B"], "score", "late_deduction", "message")}；3. {http(rs["C"], "score", "late_deduction")}；'
          f'4. {http(rs["D"], "score", "late_deduction")}；5. 成績（狀態, 原始, 計入, 扣分, 遲交）={cell}')
    check(rs['A'].status_code == 403 and J(rs['A']).get('status') == 'closed'
          and J(rs['A']).get('error') == '已超過截止時間，老師設定這份作業不收遲交' and n_a == 0 and detail.get('is_closed') is True,
          '截止後不收的作業仍可繳交')
    check(rs['B'].status_code == 200 and J(rs['B']).get('score') == 100 and J(rs['B']).get('late_deduction') == 10
          and '計入 90 分' in J(rs['B']).get('message', ''), '遲交扣分不正確')
    check(rs['C'].status_code == 200 and J(rs['C']).get('late_deduction') == 0, '允許遲交的作業被扣分')
    check(rs['D'].status_code == 200 and J(rs['D']).get('late_deduction') == 0, '還沒截止的作業被擋下或扣分')
    check(cell['A'][0] == 'missing' and cell['B'] == ('graded', 100, 90, 10, True)
          and cell['C'] == ('graded', 100, 100, 0, True) and cell['D'] == ('graded', 100, 100, 0, False), '成績分頁不正確')


def push_token(uid, token, logout=False):
    return SC.post('/api/user/push_token', json={'user_id': uid, 'token': token, 'logout': logout})


@case('A13', '登記與清除手機推播通知',
      pre='學生甲、乙；手機 A 的推播代碼為 tok-phone-A',
      steps='1. 學生甲在手機 A 登入，POST /api/user/push_token 登記 tok-phone-A\n2. 學生乙改用同一支手機登入並登記\n'
            '3. 學生乙在另一支舊手機（tok-old）登出\n4. 學生乙在手機 A 登出',
      expect='1. 甲的帳號記下這支手機\n2. 這支手機改記在乙的帳號，甲的清空（通知不會推錯人）\n3. 乙的登記不受影響\n4. 乙的登記清除')
def _(c):
    k = ensure_class()

    def tokens():
        return user_row(k['s1'])['push_token'], user_row(k['s2'])['push_token']

    r1 = push_token(k['s1'], 'tok-phone-A')
    t1 = tokens()
    r2 = push_token(k['s2'], 'tok-phone-A')
    t2 = tokens()
    push_token(k['s2'], 'tok-old', logout=True)
    t3 = tokens()
    push_token(k['s2'], 'tok-phone-A', logout=True)
    t4 = tokens()
    c.log(f'1. HTTP {r1.status_code}，（甲, 乙）={t1}；2. HTTP {r2.status_code}，{t2}；3. {t3}；4. {t4}')
    check(r1.status_code == 200 and t1 == ('tok-phone-A', None), '登記失敗')
    check(r2.status_code == 200 and t2 == (None, 'tok-phone-A'), '同一支手機換人登入後沒有移轉')
    check(t3 == (None, 'tok-phone-A'), '在別支手機登出卻清掉了這支手機的登記')
    check(t4 == (None, None), '登出後沒有清除登記')


@case('A13', '公告、新作業與批改完成時推播通知學生',
      pre='「三年丙班」學生甲、乙都已登記手機；學生甲有一份已繳交、待批閱的造句作業',
      steps='1. 老師發布公告「明天停課」\n2. 老師出一份作業並勾選「通知學生」，再出一份不勾選\n3. 老師在批閱頁替學生甲的作業打 88 分\n'
            '4. 學生乙的手機已移除 App，老師再發一則公告\n5. 伺服器沒有設定推播金鑰時，老師再發一則公告',
      expect='1. 推播給甲、乙兩支手機，標題「三年丙班・林老師：明天停課」\n2. 勾選通知的作業推播「三年丙班・林老師：新作業」，沒勾選的不推播\n'
             '3. 只推播給學生甲，標題「作業已批改」，內容含 88 分\n4. 乙的手機登記被清除，之後不再推給他\n5. 公告照常發布，不推播也不出錯',
      note='推播以模擬方式進行，未連線 Firebase')
def _(c):
    k = ensure_class()
    web = teacher_client(k['teacher'], '林老師')
    push_token(k['s1'], 'tok-s1')
    push_token(k['s2'], 'tok-s2')
    with S.app_context():
        hw = Assignment(classroom_id=k['room'], title='第一課造句', task_type=TaskType.SENTENCE,
                        config={'grammar_point': '〜ます'}, is_published=True)
        db.session.add(hw)
        db.session.flush()
        sub = AssignmentSubmission(assignment_id=hw.id, student_id=k['s1'], status=SubmissionStatus.SUBMITTED,
                                   submitted_at=datetime.utcnow())
        db.session.add(sub)
        db.session.commit()
        sub_id = sub.id
    ann_url = f'/teacher/classroom/{k["room"]}/announcements'
    hw_url = f'/teacher/classroom/{k["room"]}/assignment/create'
    PUSH_FAKE.update(ready=True, dead=[])
    del PUSHED[:]
    try:
        web.post(ann_url, data={'title': '明天停課', 'content': '颱風假，作業順延。'})
        f1 = flashes(web)
        p1 = list(PUSHED)
        web.post(hw_url, data={'task_type': 'sentence', 'title': '第五課造句', 'grammar_point': '〜たい', 'announce': '1'})
        web.post(hw_url, data={'task_type': 'sentence', 'title': '第六課造句', 'grammar_point': '〜たい'})
        flashes(web)
        p2 = PUSHED[len(p1):]
        web.post(f'/teacher/submission/{sub_id}/grade', data={'score': '88', 'teacher_comment': '助詞用得很好'})
        f3 = flashes(web)
        p3 = PUSHED[len(p1) + len(p2):]
        PUSH_FAKE['dead'] = ['tok-s2']
        web.post(ann_url, data={'title': '補課時間', 'content': '週六上午。'})
        flashes(web)
        s2_token = user_row(k['s2'])['push_token']
        web.post(ann_url, data={'title': '補課教室', 'content': '改到 301 教室。'})
        flashes(web)
        p4 = PUSHED[len(p1) + len(p2) + len(p3):]
        PUSH_FAKE['ready'] = False
        n_before = len(PUSHED)
        web.post(ann_url, data={'title': '期末考日期', 'content': '下週三。'})
        f5 = flashes(web)
        n_after = len(PUSHED)
    finally:
        PUSH_FAKE.update(ready=False, dead=[])
    n_ann = count(ClassroomAnnouncement, classroom_id=k['room'], title='期末考日期')
    c.log(f'1. 提示={f1}，推播={[(p["tokens"], p["title"]) for p in p1]}；2. 推播={[(p["title"], p["body"]) for p in p2]}；'
          f'3. 提示={f3}，推播={[(p["tokens"], p["title"], p["body"]) for p in p3]}；'
          f'4. 乙的手機登記={s2_token}，之後的推播對象={[p["tokens"] for p in p4]}；5. 提示={f5}，推播 {n_after - n_before} 則，公告 {n_ann} 則')
    check(len(p1) == 1 and p1[0]['tokens'] == ['tok-s1', 'tok-s2'] and p1[0]['title'] == '三年丙班・林老師：明天停課'
          and p1[0]['data'].get('type') == 'announcement' and '已推播到 2 位學生的手機' in f1[0], '公告推播不正確')
    check(len(p2) == 1 and p2[0]['title'] == '三年丙班・林老師：新作業' and p2[0]['body'].startswith('第五課造句'), '新作業推播不正確')
    check(len(p3) == 1 and p3[0]['tokens'] == ['tok-s1'] and p3[0]['title'] == '作業已批改' and '88 分' in p3[0]['body'],
          '批改推播不正確')
    check(s2_token is None and [p['tokens'] for p in p4] == [['tok-s1', 'tok-s2'], ['tok-s1']], '收不到的手機沒有清除')
    check(n_after == n_before and n_ann == 1 and f5 and f5[0].startswith('公告已發布') and '推播' not in f5[0],
          '沒有推播金鑰時公告發布不正常')


# ----------------------------------------------------------------------
# A04 AI對話練習：對話角色與腔調（services/character.py、services/dialect.py）
# ----------------------------------------------------------------------
def characters_of(u):
    return J(SC.get(f'/api/character/list?user_id={u["id"]}'))


CUSTOM_FORM = {'origin': '大阪', 'age': '25', 'gender': '女', 'personality': '開朗健談', 'special_traits': '章魚燒店的店員'}


def create_custom(u, name, **extra):
    return SC.post('/api/character/custom/create', json={'user_id': u['id'], 'name': name, **CUSTOM_FORM, **extra})


def dialect_id_of(name, jp_name, region):
    """取得（沒有就建立）啟用中的腔調"""
    with S.app_context():
        d = Dialect.query.filter_by(name=name, is_active=True).first()
        if d is None:
            d = Dialect(name=name, jp_name=jp_name, region=region, description='',
                        prompt_instruction=f'請用{name}回覆', is_active=True)
            db.session.add(d)
            db.session.commit()
        return d.id


@case('A04', '角色清單只有預設老師，舊的官方角色購買 API 已移除',
      pre='使用者 C 剛註冊、還沒新增過自訂角色',
      steps='1. GET /api/character/list?user_id=C\n2. POST /api/character/buy（舊版購買官方角色的 API）',
      expect='1. 只有免費的「預設老師」、沒有自訂角色、沒有腔調名額、不能用男聲、自訂角色售價 200 點\n2. HTTP 404')
def _(c):
    u = register('chara')
    d = characters_of(u)
    r2 = SC.post('/api/character/buy', json={'user_id': u['id'], 'character_id': 'seto_kei'})
    c.log(f'1. 角色={[x["name"] for x in d.get("characters", [])]}，自訂角色={d.get("custom_characters")}，'
          f'名額={d.get("free_dialect_slots")}，可用男聲={d.get("dialect_unlocked")}，售價={d.get("custom_character_cost")}；'
          f'2. HTTP {r2.status_code}')
    check([x['name'] for x in d.get('characters', [])] == ['預設老師'] and d.get('custom_characters') == []
          and d.get('free_dialect_slots') == 0 and d.get('dialect_unlocked') is False
          and d.get('custom_character_cost') == 200, '角色清單不正確')
    check(r2.status_code == 404, '舊的購買 API 還在')


@case('A04', '每新增一個自訂角色可解鎖一種對話腔調',
      pre='系統有啟用中的腔調「關西腔」「博多腔」；使用者 N 沒新增過自訂角色；使用者 C 有 450 點',
      steps='1. GET /api/dialect/list\n2. N 指定關西腔與 AI 對話（POST /api/chat，dialect_id=關西腔）\n'
            '3. N 用名額解鎖關西腔（POST /api/character/choose_dialect）\n'
            '4. C 新增自訂角色時順便選關西腔\n5. C 指定關西腔對話\n'
            '6. C 再新增一個自訂角色，又選關西腔\n7. C 新增自訂角色時不選腔調，之後用名額解鎖博多腔\n'
            '8. C 指定博多腔對話\n9. C 刪掉第一個角色後指定關西腔對話',
      expect='1. 清單有「關西腔」，並附男女聲試聽音檔欄位\n2. 對話正常，但以標準語回覆（腔調不套用）\n3. HTTP 400，沒有可用的腔調名額\n'
             '4. HTTP 200，已解鎖關西腔、可用男聲\n5. 關西腔套用\n6. HTTP 400，「這個腔調已經解鎖過了」，不扣點\n'
             '7. 新增後名額 1 個；解鎖後已解鎖關西腔與博多腔、名額 0\n8. 博多腔套用\n9. 刪角色不收回腔調，關西腔仍套用',
      note='AI 回應以模擬資料替代，檢查的是交給 AI 的腔調設定')
def _(c):
    did = dialect_id_of('關西腔', '関西弁', '大阪、京都、神戶')
    did2 = dialect_id_of('博多腔', '博多弁', '福岡博多')
    r1 = SC.get('/api/dialect/list')
    row = next((x for x in (r1.get_json() or []) if x['id'] == did), {})
    n, u = register('nodialect'), register('dialectbuyer')
    SC.post('/api/user/add_points', json={'user_id': u['id'], 'points': 450, 'price': 0, 'payment_method': 'credit_card'})

    def talk(who, dialect_id):
        use_ai(who)
        FAKE['last_dialect'] = 'unset'
        r = SC.post('/api/chat', data={'user_id': str(who['id']), 'message': 'こんにちは', 'topic': '日常對話',
                                       'level': 'N5', 'dialect_id': str(dialect_id)})
        return r.status_code, FAKE['last_dialect']

    def choose(who, dialect_id):
        return SC.post('/api/character/choose_dialect', json={'user_id': who['id'], 'dialect_id': dialect_id})

    t2 = talk(n, did)
    r3 = choose(n, did)
    r4 = create_custom(u, '角色一', dialect_id=did)
    t5 = talk(u, did)   # 免費帳號一天只有 3 次 AI 對話，C 共對話 3 次
    r6 = create_custom(u, '角色二', dialect_id=did)
    pts6 = user_row(u['id'])['j_pts']
    r7a = create_custom(u, '角色三')
    r7b = choose(u, did2)
    t8 = talk(u, did2)
    SC.post('/api/character/custom/delete', json={'user_id': u['id'], 'custom_id': J(r4)['character']['custom_id']})
    t9 = talk(u, did)
    c.log(f'1. HTTP {r1.status_code}，{row.get("name")}（{row.get("jp_name")}），試聽欄位={sorted((row.get("samples") or {}).keys())}；'
          f'2. 套用腔調={t2[1]}；3. {http(r3, "error")}；4. {http(r4, "message", "unlocked_dialect_ids", "dialect_unlocked")}；'
          f'5. 關西腔={t5[1] == did}；6. {http(r6, "error")}，點數={pts6}；'
          f'7. 名額={J(r7a).get("free_dialect_slots")}，{http(r7b, "unlocked_dialect_ids", "free_dialect_slots")}；'
          f'8. HTTP {t8[0]}，博多腔={t8[1] == did2}；9. HTTP {t9[0]}，關西腔={t9[1] == did}')
    check(r1.status_code == 200 and row.get('name') == '關西腔' and sorted((row.get('samples') or {}).keys()) == ['female', 'male'],
          '腔調清單不正確')
    check(t2 == (200, None) and r3.status_code == 400, '沒有新增過角色卻能用腔調')
    check(r4.status_code == 200 and J(r4).get('unlocked_dialect_ids') == [did] and J(r4).get('dialect_unlocked') is True,
          '新增角色時解鎖腔調失敗')
    check(t5 == (200, did), '腔調套用不正確')
    check(r6.status_code == 400 and '已經解鎖過' in J(r6).get('error', '') and pts6 == 250, '重複解鎖同一種腔調未擋下')
    check(J(r7a).get('free_dialect_slots') == 1 and r7b.status_code == 200
          and J(r7b).get('unlocked_dialect_ids') == sorted([did, did2]) and J(r7b).get('free_dialect_slots') == 0,
          '用名額解鎖腔調失敗')
    check(t8 == (200, did2) and t9 == (200, did), '解鎖後的腔調沒有套用，或刪角色後被收回')


@case('A04', '花點數新增自訂角色，對話時套用角色人設',
      pre='使用者 K 目前 0 點；使用者 B 是另一位使用者；自訂角色售價 200 點',
      steps='1. 0 點時新增自訂角色\n2. 儲值 450 點後，缺「個性」新增\n3. 六欄都填好新增「佐藤 美咲」\n4. 再新增同名角色、新增名為「預設老師」的角色\n'
            '5. 查角色清單\n6. K 用「佐藤 美咲」對話；K 用「預設老師」對話；B 冒用 K 的「佐藤 美咲」對話\n'
            '7. B 刪除 K 的角色；K 刪除「佐藤 美咲」後再用它對話',
      expect='1. HTTP 400，「點數不足，需要 200 點」\n2. HTTP 400，「請填寫個性」，不扣點\n3. HTTP 200，扣 200 點（餘 250），交易紀錄有 -200\n'
             '4. 皆 HTTP 400，「已經有同名的角色了」\n5. 自訂角色清單有「佐藤 美咲」\n'
             '6. 依序套用佐藤 美咲的人設、不套用（家教模式）、不套用\n7. B 刪除 HTTP 404；K 刪除 HTTP 200，之後對話不套用人設',
      note='AI 回應以模擬資料替代，檢查的是交給 AI 的角色人設')
def _(c):
    k, other = register('custom'), register('customother')
    form = {'user_id': k['id'], 'name': '佐藤 美咲', 'origin': '大阪', 'age': '25', 'gender': '女',
            'personality': '開朗健談', 'special_traits': '章魚燒店的店員'}

    def create(**override):
        return SC.post('/api/character/custom/create', json={**form, **override})

    def talk(u, character):
        use_ai(u)
        FAKE['last_persona'] = 'unset'
        r = SC.post('/api/chat', data={'user_id': str(u['id']), 'message': 'こんにちは', 'topic': '日常對話',
                                       'level': 'N5', 'character': character})
        persona = FAKE['last_persona']
        return r.status_code, persona.get('name') if isinstance(persona, dict) else persona

    r1 = create()
    SC.post('/api/user/add_points', json={'user_id': k['id'], 'points': 450, 'price': 0, 'payment_method': 'credit_card'})
    r2 = create(personality='')
    pts2 = user_row(k['id'])['j_pts']
    r3 = create()
    pts3 = user_row(k['id'])['j_pts']
    r4a, r4b = create(), create(name='預設老師')
    customs = characters_of(k).get('custom_characters', [])
    tx = [(t['points'], t['related_feature']) for t in J(SC.get(f'/api/user/transactions/{k["id"]}')).get('transactions', [])]
    t1, t2, t3 = talk(k, '佐藤 美咲'), talk(k, '預設老師'), talk(other, '佐藤 美咲')
    cid = (J(r3).get('character') or {}).get('custom_id')
    r7a = SC.post('/api/character/custom/delete', json={'user_id': other['id'], 'custom_id': cid})
    r7b = SC.post('/api/character/custom/delete', json={'user_id': k['id'], 'custom_id': cid})
    t7 = talk(k, '佐藤 美咲')
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}，點數={pts2}；3. {http(r3, "message", "total_points")}，點數={pts3}，交易紀錄={tx}；'
          f'4. {http(r4a, "error")}；{http(r4b, "error")}；5. 自訂角色={[x["name"] for x in customs]}；'
          f'6. 套用人設={[t1, t2, t3]}；7. B 刪除 HTTP {r7a.status_code}；{http(r7b, "message")}，之後套用人設={t7}')
    check(r1.status_code == 400 and J(r1).get('error') == '點數不足，需要 200 點', '點數不足未擋下')
    check(r2.status_code == 400 and J(r2).get('error') == '請填寫個性' and pts2 == 450, '缺欄位未擋下')
    check(r3.status_code == 200 and pts3 == 250 and (-200, f'custom_character:{cid}') in tx, '新增自訂角色失敗')
    check(r4a.status_code == 400 and r4b.status_code == 400 and '同名' in J(r4a).get('error', ''), '重名未擋下')
    check([x['name'] for x in customs] == ['佐藤 美咲'], '自訂角色清單不正確')
    check([t1, t2, t3] == [(200, '佐藤 美咲'), (200, None), (200, None)], '角色人設套用不正確')
    check(r7a.status_code == 404 and r7b.status_code == 200 and t7 == (200, None), '刪除自訂角色不正確')


def kansai_id():
    with S.app_context():
        return Dialect.query.filter_by(name='關西腔', is_active=True).first().id


class FakeTTS:
    """把 AI 語音模型與 gTTS 換成假的，記錄每次 AI 語音的合成參數"""

    def __init__(self):
        import services.tts as tts_module
        self.module, self.calls, self.ok = tts_module, [], True

    def __enter__(self):
        tester = self

        def fake_gemini(text, jp_name, voice='female'):
            tester.calls.append((text, jp_name, voice))
            return (b'RIFF' + b'\x00' * 40) if tester.ok else None

        class FakeGTTS:
            def __init__(self, text, lang):
                self.text = text

            def write_to_fp(self, fp):
                fp.write(b'ID3' + self.text.encode('utf-8'))

        self.orig = self.module.synthesize_with_gemini, self.module.gTTS
        self.module.synthesize_with_gemini, self.module.gTTS = fake_gemini, FakeGTTS
        return self

    def __exit__(self, *exc):
        self.module.synthesize_with_gemini, self.module.gTTS = self.orig

    def say(self, u, **body):
        n = len(self.calls)
        r = SC.post('/api/tts/synthesize', json={'user_id': u['id'], **body})
        return r, self.calls[n:]


@case('A04', '以腔調與男女聲朗讀對話內容',
      pre='系統有啟用中的腔調「關西腔」「博多腔」；使用者 F 沒新增過自訂角色；使用者 U 新增過自訂角色並解鎖關西腔；'
          '語音合成以模擬方式進行（解鎖後的男女聲與腔調用 AI 語音模型，沒解鎖用基本語音）',
      steps='POST /api/tts/synthesize：\n1. 沒有文字\n2. F 朗讀「おはよう」，分別要求女聲、男聲、關西腔\n'
            '3. U 以女聲朗讀「おはよう」\n4. U 以關西腔朗讀「おおきに」\n5. 同一句關西腔再朗讀一次\n6. U 以男聲朗讀「こんばんは」\n'
            '7. U 要求沒解鎖的博多腔\n8. AI 語音模型無法使用時，U 以關西腔朗讀「ほんまに」',
      expect='1. HTTP 400\n2. 三次都回傳基本語音 mp3，不使用 AI 語音模型\n3. 回傳 wav，以標準語、女聲合成\n'
             '4. 回傳 wav，dialect_voice=true，以関西弁、女聲合成\n5. cached=true，不重複合成\n6. 回傳 wav，以標準語、男聲合成\n'
             '7. 不套用博多腔，以標準語、女聲合成\n8. 自動退回基本語音：回傳 mp3，dialect_voice=false',
      note='語音合成以模擬資料替代，未連線語音服務')
def _(c):
    did = kansai_id()
    did2 = dialect_id_of('博多腔', '博多弁', '福岡博多')
    f, u = register('ttsfree'), register('ttsunlocked')
    SC.post('/api/user/add_points', json={'user_id': u['id'], 'points': 200, 'price': 0, 'payment_method': 'credit_card'})
    create_custom(u, '語音角色', dialect_id=did)
    with FakeTTS() as t:
        r1, _ = t.say(u, text='  ')
        free = [t.say(f, text='おはよう', **extra) for extra in ({'voice': 'female'}, {'voice': 'male'}, {'dialect_id': did})]
        r3, c3 = t.say(u, text='おはよう', voice='female')
        r4, c4 = t.say(u, text='おおきに', dialect_id=did)
        r5, c5 = t.say(u, text='おおきに', dialect_id=did)
        r6, c6 = t.say(u, text='こんばんは', voice='male')
        r7, c7 = t.say(u, text='よかよか', dialect_id=did2)
        t.ok = False
        r8, c8 = t.say(u, text='ほんまに', dialect_id=did)
    c.log(f'1. {http(r1, "error")}；2. 格式={[J(r).get("format") for r, _ in free]}，AI 語音呼叫 {sum(len(x) for _, x in free)} 次；'
          f'3. {http(r3, "format")}，合成參數={c3}；4. {http(r4, "format", "dialect_voice")}，合成參數={c4}；'
          f'5. {http(r5, "cached")}，AI 語音呼叫 {len(c5)} 次；6. {http(r6, "format")}，合成參數={c6}；'
          f'7. {http(r7, "format")}，合成參數={c7}；8. {http(r8, "format", "dialect_voice")}')
    check(r1.status_code == 400, '沒有文字未擋下')
    check(all(r.status_code == 200 and J(r).get('format') == 'mp3' and not x for r, x in free), '沒解鎖卻用了 AI 語音')
    check(J(r3).get('format') == 'wav' and c3 == [('おはよう', '標準語', 'female')], '解鎖後的女聲不正確')
    check(J(r4).get('format') == 'wav' and J(r4).get('dialect_voice') is True and c4 == [('おおきに', '関西弁', 'female')],
          '腔調語音不正確')
    check(J(r5).get('cached') is True and c5 == [], '相同內容沒有使用快取')
    check(J(r6).get('format') == 'wav' and c6 == [('こんばんは', '標準語', 'male')], '男聲不正確')
    check(c7 == [('よかよか', '標準語', 'female')], '套用了沒解鎖的腔調')
    check(r8.status_code == 200 and J(r8).get('format') == 'mp3' and J(r8).get('dialect_voice') is False,
          'AI 語音失敗時沒有退回基本語音')


@case('A13', '老師在對話作業指定的腔調不受角色限制',
      pre='「三年丙班」學生乙沒有新增過自訂角色（沒有腔調名額）；系統有腔調「關西腔」',
      steps='1. 老師出一份 AI 情境對話作業「車站問路」，指定腔調選「關西腔」，最少 1 輪\n2. 學生乙查看作業內容\n'
            '3. 學生乙從作業進入對話並送出一句話\n4. 學生乙在一般對話（不是作業）指定關西腔送出一句話\n'
            '5. 學生乙朗讀 AI 回覆：帶作業編號指定關西腔一次、不帶作業編號一次',
      expect='1. 作業建立成功並記下指定的腔調\n2. 作業內容帶有老師指定的腔調\n3. 對話套用關西腔，達到輪數後自動繳交\n4. 沒有解鎖腔調，一般對話不套用腔調\n5. 帶作業編號時以関西弁、女聲合成；不帶時用基本語音',
      note='AI 回應以模擬資料替代，檢查的是交給 AI 的腔調設定')
def _(c):
    k = ensure_class()
    did = kansai_id()
    s2 = {'id': k['s2']}
    web = teacher_client(k['teacher'], '林老師')
    web.post(f'/teacher/classroom/{k["room"]}/assignment/create',
             data={'task_type': 'chat', 'title': '車站問路', 'chat_topic': '在車站問路', 'dialect_id': str(did), 'min_turns': '1'})
    f1 = flashes(web)
    with S.app_context():
        a = Assignment.query.filter_by(classroom_id=k['room'], title='車站問路').first()
        aid, cfg = a.id, dict(a.config or {})
    detail = J(SC.get(f'/api/assignment/{aid}?user_id={k["s2"]}')).get('assignment', {})
    sid = J(SC.post('/api/chat_history/session', json={'user_id': k['s2'], 'topic': '在車站問路', 'dialect_id': did})).get('session_id')

    def talk(**extra):
        use_ai(s2)
        FAKE['last_dialect'] = 'unset'
        r = SC.post('/api/chat', data={'user_id': str(k['s2']), 'message': 'すみません、駅はどこですか', 'topic': '在車站問路',
                                       'level': 'N5', 'dialect_id': str(did), **extra})
        return r, FAKE['last_dialect']

    r3, used3 = talk(session_id=str(sid), assignment_id=str(aid))
    result = J(r3).get('assignment_result') or {}
    r4, used4 = talk()
    c.log(f'1. 提示={f1}，作業設定={cfg}；2. 作業內容的腔調={(detail.get("config") or {}).get("dialect_id")}；'
          f'3. HTTP {r3.status_code}，套用腔調={"關西腔" if used3 == did else used3}，繳交={result.get("submitted")}（{result.get("turns")}/{result.get("min_turns")} 輪）；'
          f'4. HTTP {r4.status_code}，套用腔調={used4}')
    check(cfg.get('dialect_id') == did and cfg.get('topic') == '在車站問路', '作業沒有記下指定腔調')
    check((detail.get('config') or {}).get('dialect_id') == did, '學生端作業內容沒有腔調')
    check(r3.status_code == 200 and used3 == did and result.get('submitted') is True, '作業對話沒有套用老師指定的腔調或沒有自動繳交')
    check(r4.status_code == 200 and used4 is None, '一般對話不該套用腔調')
    with FakeTTS() as t:
        _, c5a = t.say(s2, text='駅はあちらです', dialect_id=did, assignment_id=aid)
        r5b, c5b = t.say(s2, text='駅はあちらです', dialect_id=did)
    c.log(f'5. 帶作業編號合成參數={c5a}；不帶作業編號 格式={J(r5b).get("format")}、合成參數={c5b}')
    check(c5a == [('駅はあちらです', '関西弁', 'female')] and J(r5b).get('format') == 'mp3' and c5b == [],
          '作業指定腔調的語音不正確')


@case('A13', '把作業複製到老師自己的其他班',
      pre='林老師有「三年丙班」與「三年丁班」（學生丙在丁班）；丙班的「第二課造句」為遲交扣 10 分，已有學生繳交其他作業；陳老師有「二年戊班」',
      steps='於丙班作業列表對「第二課造句」點「複製到其他班」：\n1. 沒有勾選任何班級\n2. 以測試工具把目標指定為陳老師的班\n'
            '3. 勾選丁班、重設截止時間、立即發布並通知學生\n4. 再複製一次到丁班，不勾選立即發布\n5. 最高管理者執行複製',
      expect='1、2. 提示「請勾選要複製到哪個班級」，不建立作業\n3. 丁班多一份同名作業，題目與遲交規則照抄、截止時間為新設定，並自動發公告；不複製繳交紀錄\n'
             '4. 建立為未發布的草稿，不發公告，學生看不到\n5. 提示管理者無法代替老師出題')
def _(c):
    k = ensure_class()
    with S.app_context():
        room_d = Classroom(teacher_id=k['teacher'], name='三年丁班', join_code='D4E8Y6', is_open=True)
        room_e = Classroom(teacher_id=k['teacher2'], name='二年戊班', join_code='E5F9Z7', is_open=True)
        db.session.add_all([room_d, room_e])
        db.session.flush()
        db.session.add(ClassroomMember(classroom_id=room_d.id, student_id=k['s3'], display_name='學生丙'))
        db.session.commit()
        rd, re_ = room_d.id, room_e.id
        src = db.session.get(Assignment, STATE['late_assignments']['deduct'])
        src_info = (src.title, src.config, src.late_policy, src.late_penalty)
    aid = STATE['late_assignments']['deduct']
    web = teacher_client(k['teacher'], '林老師')
    url = f'/teacher/assignment/{aid}/copy'
    due = (datetime.utcnow() + timedelta(hours=8, days=10)).replace(second=0, microsecond=0)

    def in_room(room):
        with S.app_context():
            return [(a.title, a.config, a.late_policy, a.late_penalty, a.due_at, a.is_published, a.id)
                    for a in Assignment.query.filter_by(classroom_id=room).order_by(Assignment.id).all()]

    web.post(url, data={})
    f1 = flashes(web)
    web.post(url, data={'target_classroom_ids': str(re_), 'publish': 'on'})
    f2 = flashes(web)
    n12 = len(in_room(rd)) + len(in_room(re_))
    web.post(url, data={'target_classroom_ids': str(rd), 'due_at': due.isoformat(timespec='minutes'), 'publish': 'on', 'announce': 'on'})
    f3 = flashes(web)
    copied = in_room(rd)
    anns = J(announcements_of(k['s3'], rd)).get('announcements', [])
    n_sub = count(AssignmentSubmission, assignment_id=copied[0][6]) if copied else None
    web.post(url, data={'target_classroom_ids': str(rd), 'announce': 'on'})
    f4 = flashes(web)
    after4 = in_room(rd)
    anns4 = J(announcements_of(k['s3'], rd)).get('announcements', [])
    seen = [x['title'] for x in J(SC.get(f'/api/assignment/my/{k["s3"]}')).get('assignments', [])]
    boss = admin_client('sys_super', 'Admin@1234')
    boss.post(url, data={'target_classroom_ids': str(rd), 'publish': 'on'})
    f5 = flashes(boss)
    c.log(f'1. 提示={f1}；2. 提示={f2}，新增作業 {n12} 份；3. 提示={f3}，丁班作業（名稱, 遲交規則, 扣分, 截止, 已發布）='
          f'{[(x[0], x[2], x[3], str(x[4]), x[5]) for x in copied]}，公告={[x["title"] for x in anns]}，繳交紀錄 {n_sub} 筆；'
          f'4. 提示={f4}，丁班作業 {len(after4)} 份（第 2 份已發布={after4[-1][5] if len(after4) > 1 else None}）、公告 {len(anns4)} 則、學生看到={seen}；'
          f'5. 提示={f5}，丁班作業 {len(in_room(rd))} 份')
    check(f1 == ['請勾選要複製到哪個班級'] and f2 == ['請勾選要複製到哪個班級'] and n12 == 0, '沒選班級或別人的班未擋下')
    check(len(copied) == 1 and copied[0][:4] == src_info and copied[0][4] == due and copied[0][5] is True and n_sub == 0,
          '複製出來的作業不正確')
    check(len(f3) == 1 and '三年丁班' in f3[0] and [x['title'] for x in anns] == ['新作業：第二課造句']
          and anns[0]['assignment_id'] == copied[0][6], '複製後沒有發公告')
    check(len(after4) == 2 and after4[1][5] is False and after4[1][4] is None and len(anns4) == 1
          and seen == ['第二課造句'] and '尚未發布' in f4[0], '草稿複製不正確')
    check(len(f5) == 1 and '管理者無法代替老師出題' in f5[0] and len(in_room(rd)) == 2, '管理者可以代替老師複製作業')


# ======================================================================
# 補齊 App 其餘功能（2026-10-05 盤點路由後補上）
# ======================================================================
def analyze_photo(u, name='photo.jpg'):
    scan(u)
    return SC.post('/api/scenario/analyze', data={'user_id': str(u['id']), 'image': (io.BytesIO(JPEG_BYTES), name)},
                   content_type='multipart/form-data')


def befriend(a, b):
    SC.post('/api/user/friend_request/send', json={'sender_id': a['id'], 'receiver_id': b['id']})
    req = J(SC.get(f'/api/user/friend_request/pending/{b["id"]}'))['pending_requests'][0]
    SC.post('/api/user/friend_request/respond', json={'request_id': req['request_id'], 'action': 'accept'})


@case('A01', '登入後修改密碼',
      pre='使用者 P 已登入，密碼為 Pass1234',
      steps='POST /api/auth/change_password（帶 P 的通行證）：\n1. 目前密碼打錯\n2. 新密碼太短（123）\n3. 目前密碼正確、新密碼 NewPass5678\n'
            '4. 用修改前的通行證查個人檔案\n5. 分別用舊密碼、新密碼登入',
      expect='1. HTTP 400，「目前密碼錯誤」\n2. HTTP 400，提示密碼不符規則\n3. HTTP 200，「密碼已更新」並換發新通行證\n'
             '4. HTTP 401（舊通行證失效）\n5. 舊密碼登入失敗、新密碼登入成功')
def _(c):
    u = register('chpw')
    old = auth_header(u)

    def change(cur, new):
        return SC.post('/api/auth/change_password', json={'current_password': cur, 'new_password': new}, headers=old)

    r1 = change('WrongPass1', 'NewPass5678')
    r2 = change('Pass1234', '123')
    r3 = change('Pass1234', 'NewPass5678')
    r4 = SC.get(f'/api/user/profile_data/{u["id"]}', headers=old)
    r5a, r5b = login(u, 'Pass1234'), login(u, 'NewPass5678')
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "error")}；3. {http(r3, "message")}，換發通行證={bool(J(r3).get("token"))}；'
          f'4. {http(r4, "error")}；5. 舊密碼 HTTP {r5a.status_code}、新密碼 HTTP {r5b.status_code}')
    check(r1.status_code == 400 and J(r1).get('error') == '目前密碼錯誤', '目前密碼錯誤未擋下')
    check(r2.status_code == 400 and J(r2).get('error'), '太短的新密碼未擋下')
    check(r3.status_code == 200 and J(r3).get('message') == '密碼已更新' and J(r3).get('token'), '修改密碼失敗')
    check(r4.status_code == 401, '改密碼後舊通行證仍可使用')
    check(r5a.status_code != 200 and r5b.status_code == 200, '新舊密碼登入結果不正確')


@case('A02', '照片紀錄、照片單字與照片改名',
      pre='訂閱會員 H 拍了 3 張照片（AI 辨識以模擬資料替代，每張辨識出冷蔵庫、電子レンジ）；另一位使用者 X',
      steps='1. GET /api/scenario/unlocked/{H}?limit=2，再取 offset=2\n2. GET /api/scenario/photo_vocabs，帶第一張照片的路徑\n'
            '3. POST /api/scenario/rename_photo，把照片命名為「我家廚房」後重新查詢\n4. 名稱空白\n5. X 修改 H 的照片名稱',
      expect='1. total=3；第一頁 2 筆、has_more=true；第二頁 1 筆、has_more=false；每張照片 vocab_count=2\n2. 列出這張照片的 2 個單字\n'
             '3. HTTP 200，「修改成功」，照片紀錄顯示新名稱\n4. HTTP 400\n5. HTTP 403，名稱不變',
      note='AI 回應以模擬資料替代')
def _(c):
    h, x = register('photos'), register('photosx')
    set_user(h['id'], is_premium=True, subscription_end_date=datetime.utcnow() + timedelta(days=30))
    FAKE['scan_ok'] = True
    codes = [analyze_photo(h, f'p{i}.jpg').status_code for i in range(3)]
    p1 = J(SC.get(f'/api/scenario/unlocked/{h["id"]}?limit=2'))
    p2 = J(SC.get(f'/api/scenario/unlocked/{h["id"]}?limit=2&offset=2'))
    first = p1.get('scenes', [{}])[0]
    r2 = SC.get('/api/scenario/photo_vocabs', query_string={'user_id': h['id'], 'image_path': first.get('image_path')})
    words = sorted(v['word'] for v in J(r2).get('vocabs', []))
    r3 = SC.post('/api/scenario/rename_photo', json={'photo_id': first.get('photo_id'), 'custom_title': '我家廚房'})
    renamed = next((s['scene_name'] for s in J(SC.get(f'/api/scenario/unlocked/{h["id"]}')).get('scenes', [])
                    if s['photo_id'] == first.get('photo_id')), None)
    r4 = SC.post('/api/scenario/rename_photo', json={'photo_id': first.get('photo_id'), 'custom_title': ''})
    r5 = SC.post('/api/scenario/rename_photo', json={'photo_id': first.get('photo_id'), 'custom_title': '被別人改'},
                 headers=auth_header(x))
    with S.app_context():
        title = db.session.get(UserPhoto, first.get('photo_id')).custom_title
    c.log(f'前置辨識狀態碼={codes}；1. total={p1.get("total")}，第一頁 {len(p1.get("scenes", []))} 筆 has_more={p1.get("has_more")}，'
          f'第二頁 {len(p2.get("scenes", []))} 筆 has_more={p2.get("has_more")}，vocab_count={first.get("vocab_count")}；2. HTTP {r2.status_code}，單字={words}；'
          f'3. {http(r3, "message")}，照片紀錄名稱={renamed}；4. {http(r4, "error")}；5. {http(r5, "error")}，名稱仍為「{title}」')
    check(codes == [200] * 3, '前置拍照失敗')
    check(p1.get('total') == 3 and len(p1.get('scenes', [])) == 2 and p1.get('has_more') is True
          and len(p2.get('scenes', [])) == 1 and p2.get('has_more') is False and first.get('vocab_count') == 2, '照片紀錄分頁不正確')
    check(words == ['冷蔵庫', '電子レンジ'], '照片單字不正確')
    check(r3.status_code == 200 and J(r3).get('message') == '修改成功' and renamed == '我家廚房', '照片改名失敗')
    check(r4.status_code == 400, '空白名稱未擋下')
    check(r5.status_code == 403 and title == '我家廚房', '可以修改別人的照片名稱')


@case('A02', '用辨識出的單字練習造句',
      pre='拍照辨識出「冷蔵庫」；AI 批改以模擬資料替代',
      steps='POST /api/scenario/evaluate_sentence：\n1. sentence=冷蔵庫に牛乳があります。、vocabs=[冷蔵庫]\n2. 沒有句子\n3. AI 批改失敗',
      expect='1. HTTP 200，回傳 AI 的批改結果\n2. HTTP 400，「缺少句子或單字資料」\n3. HTTP 500，回傳錯誤訊息',
      note='AI 回應以模擬資料替代')
def _(c):
    u = register('evalphoto')
    state = {'ok': True}

    def fake_eval(sentence, vocabs, context_description=None):
        if not state['ok']:
            return {'success': False, 'error': 'AI 服務目前使用人數較多，請稍等幾秒再試一次。'}
        return {'success': True, 'result': {'is_correct': True, 'score': 90, 'feedback': '文法正確，用到了指定的單字。',
                                            'corrected_sentence': sentence}}

    orig = ai_helper.evaluate_user_sentence
    ai_helper.evaluate_user_sentence = fake_eval
    try:
        body = {'user_id': u['id'], 'sentence': '冷蔵庫に牛乳があります。', 'vocabs': ['冷蔵庫']}
        r1 = SC.post('/api/scenario/evaluate_sentence', json=body)
        r2 = SC.post('/api/scenario/evaluate_sentence', json={'user_id': u['id'], 'vocabs': ['冷蔵庫']})
        state['ok'] = False
        r3 = SC.post('/api/scenario/evaluate_sentence', json=body)
    finally:
        ai_helper.evaluate_user_sentence = orig
    c.log(f'1. {http(r1, "score", "feedback")}；2. {http(r2, "error")}；3. {http(r3, "error")}')
    check(r1.status_code == 200 and J(r1).get('score') == 90 and J(r1).get('feedback'), '批改結果不正確')
    check(r2.status_code == 400 and J(r2).get('error') == '缺少句子或單字資料', '缺少句子未擋下')
    check(r3.status_code == 500 and J(r3).get('error'), 'AI 失敗時沒有回報錯誤')


@case('A03', '單字詳情依程度顯示分級例句',
      pre='單字「紅葉」已有四個難度的例句（A11-06 由文章收藏時補上）；使用者 L5 程度 N5、L1 程度 N1，L1 已收藏這個單字',
      steps='1. L5 GET /api/vocab/detail/{紅葉}\n2. L1 GET /api/vocab/detail/{紅葉}\n3. 查詢不存在的單字',
      expect='1. 只顯示初階例句 1 句，more_sentences_locked=true，is_favorited=false\n'
             '2. 顯示 4 個難度的例句並附翻譯，more_sentences_locked=false，is_favorited=true、收藏在「預設單字本」\n3. HTTP 404')
def _(c):
    l5, l1 = register('detail'), register('detail')
    set_user(l5['id'], japanese_level='N5')
    set_user(l1['id'], japanese_level='N1')
    with S.app_context():
        vid = Vocab.query.filter_by(word='紅葉', kana='こうよう').first().id
    SC.post('/api/vocab/collect', json={'user_id': l1['id'], 'vocab_id': vid})
    r1 = SC.get(f'/api/vocab/detail/{vid}?user_id={l5["id"]}')
    r2 = SC.get(f'/api/vocab/detail/{vid}?user_id={l1["id"]}')
    r3 = SC.get(f'/api/vocab/detail/99999999?user_id={l5["id"]}')
    d1, d2 = J(r1), J(r2)
    c.log(f'1. HTTP {r1.status_code}，例句={[s.get("level_name") for s in d1.get("sentences", [])]}，more_locked={d1.get("more_sentences_locked")}、'
          f'is_favorited={d1.get("is_favorited")}；2. 例句={[s.get("level_name") for s in d2.get("sentences", [])]}，more_locked={d2.get("more_sentences_locked")}、'
          f'is_favorited={d2.get("is_favorited")}、folder_name={d2.get("folder_name")}；3. {http(r3, "error")}')
    check(r1.status_code == 200 and [s.get('level_name') for s in d1.get('sentences', [])] == ['初階應用']
          and d1.get('more_sentences_locked') is True and d1.get('is_favorited') is False, 'N5 看到的例句不正確')
    check([s.get('level_name') for s in d2.get('sentences', [])] == ['初階應用', '中階變化', '商務/進階', '高級語感']
          and all(s.get('translation') for s in d2['sentences']) and d2.get('more_sentences_locked') is False
          and d2.get('is_favorited') is True and d2.get('folder_name') == '預設單字本', 'N1 看到的例句不正確')
    check(r3.status_code == 404, '不存在的單字未回 404')


@case('A03', '場景單字清單、隨機探索與造句可選單字',
      pre='系統測試場景有 60 個單字；使用者 E 拍過 1 張照片（辨識出冷蔵庫、電子レンジ，未收藏），另收藏了テスト語05',
      steps='1. GET /api/vocab/scene/{系統測試場景}?user_id=E\n2. POST /api/vocab/explore，count=5、scene_id=系統測試場景\n'
            '3. GET /api/vocab/practice_words?user_id=E\n4. 不帶 user_id 查詢場景單字',
      expect='1. 列出 60 個單字，只有テスト語05 標示已解鎖\n2. 回傳 5 個單字，優先給還沒解鎖的\n'
             '3. 列出 3 個可選單字：收藏的排最前（source=collected），拍照辨識過的在後（source=photo）\n4. HTTP 400',
      note='AI 回應以模擬資料替代')
def _(c):
    e = register('explore')
    FAKE['scan_ok'] = True
    analyze_photo(e)
    SC.post('/api/vocab/collect', json={'user_id': e['id'], 'vocab_id': VOCAB_IDS[4]})
    r1 = SC.get(f'/api/vocab/scene/{TEST_SCENE_ID}?user_id={e["id"]}')
    sv = J(r1).get('vocabs', [])
    unlocked = [v['word'] for v in sv if v['is_unlocked']]
    r2 = SC.post('/api/vocab/explore', json={'user_id': e['id'], 'count': 5, 'scene_id': TEST_SCENE_ID})
    ex = J(r2).get('vocabs', [])
    r3 = SC.get(f'/api/vocab/practice_words?user_id={e["id"]}')
    pw = [(w['word'], w['source']) for w in J(r3).get('words', [])]
    r4 = SC.get(f'/api/vocab/scene/{TEST_SCENE_ID}', headers=auth_header(e))
    c.log(f'1. HTTP {r1.status_code}，單字 {len(sv)} 個，已解鎖={unlocked}；2. HTTP {r2.status_code}，{len(ex)} 個，已解鎖的有 {sum(v["is_unlocked"] for v in ex)} 個；'
          f'3. 可選單字={pw}；4. {http(r4, "error")}')
    check(r1.status_code == 200 and len(sv) == 60 and unlocked == ['テスト語05'], '場景單字清單不正確')
    check(r2.status_code == 200 and len(ex) == 5 and not any(v['is_unlocked'] for v in ex), '隨機探索不正確')
    check(pw[:1] == [('テスト語05', 'collected')] and sorted(pw[1:]) == [('冷蔵庫', 'photo'), ('電子レンジ', 'photo')], '造句可選單字不正確')
    check(r4.status_code == 400, '缺少 user_id 未擋下')


@case('A04', '對話紀錄清單與 AI 小抄',
      pre='使用者 T 開了三場對話：「一蘭拉麵」聊了 1 句、「便利商店」聊了 1 句（較晚）、「機場」還沒聊',
      steps='1. GET /api/chat_history/sessions?user_id=T\n2. 不帶 user_id\n3. POST /api/user/update_profile，cheat_sheet=我在學旅遊日語\n4. update_profile 不帶 user_id',
      expect='1. 只列出聊過的 2 場，新的排前面，並附最後一則訊息的預覽；沒聊過的「機場」不顯示\n2. HTTP 400\n3. HTTP 200，「AI 小抄更新成功！」並存入資料庫\n4. HTTP 400',
      note='AI 回應以模擬資料替代')
def _(c):
    t = register('sessions')
    FAKE['chat_ok'] = True

    def open_chat(topic, say=None):
        sid = J(SC.post('/api/chat_history/session', json={'user_id': t['id'], 'topic': topic})).get('session_id')
        if say:
            use_ai(t)
            SC.post('/api/chat', data={'user_id': str(t['id']), 'message': say, 'topic': topic, 'level': 'N5', 'session_id': str(sid)})
        return sid

    s1 = open_chat('一蘭拉麵', 'ラーメンをください')
    s2 = open_chat('便利商店', 'おにぎりはどこですか')
    open_chat('機場')
    with S.app_context():   # 讓兩場的最後訊息時間有先後
        db.session.get(ChatSession, s1).last_message_at = datetime.utcnow() - timedelta(minutes=5)
        db.session.commit()
    r1 = SC.get(f'/api/chat_history/sessions?user_id={t["id"]}')
    rows = J(r1).get('sessions', [])
    r2 = SC.get('/api/chat_history/sessions', headers=auth_header(t))
    r3 = SC.post('/api/user/update_profile', data={'user_id': str(t['id']), 'cheat_sheet': '我在學旅遊日語'})
    sheet = user_row(t['id'])['ai_cheat_sheet']
    r4 = SC.post('/api/user/update_profile', data={'cheat_sheet': 'x'}, headers=auth_header(t))
    c.log(f'1. HTTP {r1.status_code}，場次（主題, 訊息數）={[(x["topic"], x["message_count"]) for x in rows]}，都有預覽={all(x.get("preview") for x in rows)}；'
          f'2. {http(r2, "error")}；3. {http(r3, "message")}，資料庫小抄={sheet}；4. {http(r4, "error")}')
    check(r1.status_code == 200 and [x['session_id'] for x in rows] == [s2, s1] and all(x.get('preview') for x in rows), '對話紀錄清單不正確')
    check(r2.status_code == 400, '缺少 user_id 未擋下')
    check(r3.status_code == 200 and J(r3).get('message') == 'AI 小抄更新成功！' and sheet == '我在學旅遊日語', 'AI 小抄沒有儲存')
    check(r4.status_code == 400, '缺少 user_id 未擋下')


@case('A05', '主題收集冊與主題單字牆',
      pre='使用者 M 已解鎖「便利商店」主題的 2 個官方單字（直接寫入解鎖紀錄模擬），其餘主題尚未開始',
      steps='1. GET /api/scenario/themes/{M}\n2. GET /api/scenario/theme_vocabs/{M}/{便利商店}\n3. GET /api/scenario/scenes 與 ?quick_select=true',
      expect='1. 列出 8 個官方主題（不含「其他」），「便利商店」已解鎖 2 個、進度=2/目標數，排在還沒開始的主題前面\n'
             '2. total=目標數、unlocked=2；已解鎖的顯示單字，未解鎖的只給中文提示、不洩漏日文\n3. 回傳場景清單；quick_select 只回傳快速選擇用的場景')
def _(c):
    m = register('themes')
    sid = STATE['theme_scene']
    with S.app_context():
        official = Vocab.query.filter_by(scene_id=sid, source='admin').order_by(Vocab.id).all()
        for v in official[:2]:
            db.session.add(UserVocab(user_id=m['id'], vocab_id=v.id))
        db.session.commit()
        total = len(official)
    r1 = SC.get(f'/api/scenario/themes/{m["id"]}')
    themes = J(r1).get('themes', [])
    cvs = next((t for t in themes if t['scene_id'] == sid), {})
    r2 = SC.get(f'/api/scenario/theme_vocabs/{m["id"]}/{sid}')
    wall = J(r2)
    locked = [v for v in wall.get('vocabs', []) if not v['is_unlocked']]
    r3a, r3b = SC.get('/api/scenario/scenes'), SC.get('/api/scenario/scenes?quick_select=true')
    all_scenes, quick = r3a.get_json() or [], r3b.get_json() or []
    c.log(f'1. HTTP {r1.status_code}，主題 {len(themes)} 個，第一個={themes[0]["name"] if themes else None}，便利商店 {cvs.get("unlocked_count")}/{cvs.get("target_count")}（progress={cvs.get("progress")}）；'
          f'2. total={wall.get("total")}、unlocked={wall.get("unlocked")}，未解鎖 {len(locked)} 個、有洩漏日文={any("word" in v for v in locked)}、都有提示={all(v.get("hint") for v in locked)}；'
          f'3. 場景 {len(all_scenes)} 個、快速選擇 {len(quick)} 個')
    check(r1.status_code == 200 and len(themes) == 8 and all(t['name'] != '其他' for t in themes)
          and themes[0]['scene_id'] == sid and cvs.get('unlocked_count') == 2 and cvs.get('target_count') == total
          and cvs.get('progress') == round(2 / total, 3), '主題收集冊不正確')
    check(wall.get('total') == total and wall.get('unlocked') == 2 and len(locked) == total - 2
          and not any('word' in v or 'kana' in v for v in locked) and all(v.get('hint') for v in locked)
          and all(v['is_unlocked'] for v in wall['vocabs'][:2]), '主題單字牆不正確')
    check(r3a.status_code == 200 and len(all_scenes) >= 8 and len(quick) <= len(all_scenes)
          and all('icon_name' in s for s in all_scenes), '場景清單不正確')


@case('A06', '小組追加邀請、取消邀請與不可中途退出',
      pre='隊長 Q1 已建立小組「晨讀小組」，好友為 Q2、Q3；Q4 不在小組裡',
      steps='1. Q1 POST /api/group/invite_friends 邀請 Q2、Q3，再邀請一次 Q2\n2. POST /api/group/friends_detailed_status 查好友狀態\n'
            '3. Q4 替這個小組發邀請\n4. Q1 取消對 Q3 的邀請，再取消一次\n5. Q1 POST /api/group/leave',
      expect='1. 第一次「成功發送 2 個邀請！」，重複邀請不會再送（0 個）\n2. Q2、Q3 皆標示已邀請\n3. HTTP 403，「你不在這個小組裡」\n'
             '4. 第一次「已成功取消邀請」，Q3 不再有邀請；第二次 HTTP 404\n5. HTTP 400，挑戰結算前無法退出')
def _(c):
    q1, q2, q3, q4 = (register('ginv') for _ in range(4))
    befriend(q1, q2)
    befriend(q1, q3)
    gid = J(SC.post('/api/group/create', json={'user_id': q1['id'], 'name': '晨讀小組', 'goal_type': 'scans', 'goal_target': 30})).get('group_id')
    STATE['ginv'] = (q1, q2, gid)

    def invite(sender, ids):
        return SC.post('/api/group/invite_friends', json={'group_id': gid, 'sender_id': sender['id'], 'friend_ids': ids})

    r1a = invite(q1, [q2['friend_id'], q3['friend_id']])
    r1b = invite(q1, [q2['friend_id']])
    r2 = SC.post('/api/group/friends_detailed_status', json={'group_id': gid, 'user_id': q1['id']})
    status = sorted((f['friend_id'] == q2['friend_id'] and 'Q2' or 'Q3', f['is_invited'], f['has_group']) for f in J(r2).get('friends', []))
    r3 = invite(q4, [q2['friend_id']])
    cancel = lambda: SC.post('/api/group/cancel_invite', json={'group_id': gid, 'receiver_id': q3['friend_id']})
    r4a = cancel()
    left = len(J(SC.get(f'/api/group/invites/{q3["id"]}')).get('invites', []))
    r4b = cancel()
    r5 = SC.post('/api/group/leave', json={'user_id': q1['id'], 'group_id': gid})
    c.log(f'1. {http(r1a, "message")}；{http(r1b, "message")}；2. 好友（誰, 已邀請, 已有小組）={status}；3. {http(r3, "error")}；'
          f'4. {http(r4a, "message")}，Q3 的邀請 {left} 筆；{http(r4b, "error")}；5. {http(r5, "error")}')
    check(gid and r1a.status_code == 200 and J(r1a).get('message') == '成功發送 2 個邀請！' and J(r1b).get('message') == '成功發送 0 個邀請！',
          '追加邀請不正確')
    check(status == [('Q2', True, False), ('Q3', True, False)], '好友邀請狀態不正確')
    check(r3.status_code == 403 and J(r3).get('error') == '你不在這個小組裡', '非成員可以替小組發邀請')
    check(r4a.status_code == 200 and J(r4a).get('message') == '已成功取消邀請' and left == 0 and r4b.status_code == 404, '取消邀請不正確')
    check(r5.status_code == 400 and '無法退出' in J(r5).get('error', ''), '挑戰期間可以退出小組')


@case('A06', '小組達標後提前領獎並結業',
      pre='延續 A06-20：隊長 Q1 的「晨讀小組」（目標拍照 30 次，免押金）只有 Q1 一人，Q2 仍在受邀中',
      steps='1. 進度未達標時 POST /api/group/claim_reward\n2. 把小組進度設為達標（模擬成員完成 30 次拍照）後再領一次\n'
            '3. 達標前先確認：達標的小組再邀請好友\n4. 領獎後查詢我的小組，並再領一次',
      expect='1. HTTP 400，「任務尚未達成，還不能領獎喔！」\n2. HTTP 200，發放獎勵並結業\n3. HTTP 400，「小組已達標，無法再發送邀請！」\n'
             '4. Q1 已沒有小組，小組解散；再領 HTTP 404')
def _(c):
    q1, q2, gid = STATE['ginv']
    claim = lambda: SC.post('/api/group/claim_reward', json={'group_id': gid, 'user_id': q1['id']})
    r1 = claim()
    with S.app_context():
        g = db.session.get(StudyGroup, gid)
        g.current_progress = g.goal_target
        db.session.commit()
    r3 = SC.post('/api/group/invite_friends', json={'group_id': gid, 'sender_id': q1['id'], 'friend_ids': [q2['friend_id']]})
    before = user_row(q1['id'])['j_pts']
    r2 = claim()
    after = user_row(q1['id'])['j_pts']
    n_group = count(StudyGroup, id=gid)
    n_member = count(GroupMember, user_id=q1['id'])
    r4 = claim()
    c.log(f'1. {http(r1, "error")}；2. {http(r2, "message", "new_j_pts")}，點數 {before} → {after}；3. {http(r3, "error")}；'
          f'4. Q1 的小組成員紀錄 {n_member} 筆、小組 {n_group} 個；再領 {http(r4, "error")}')
    check(r1.status_code == 400 and J(r1).get('error') == '任務尚未達成，還不能領獎喔！', '未達標可以領獎')
    check(r3.status_code == 400 and J(r3).get('error') == '小組已達標，無法再發送邀請！', '達標後仍可邀請')
    check(r2.status_code == 200 and '結業' in J(r2).get('message', '') and after > before, '達標領獎失敗')
    check(n_member == 0 and n_group == 0 and r4.status_code == 404, '領獎後小組沒有解散或可重複領獎')


@case('A07', '月繳訂閱排程升級為年繳',
      pre='使用者 S1 已訂閱月繳（獲贈 20 點）；S2 沒有訂閱；S3 已訂閱年繳',
      steps='1. S1 POST /api/subscription/schedule_upgrade\n2. S1 再排程一次\n3. S1 POST /api/subscription/pay_pending\n'
            '4. S2、S3 分別排程升級\n5. S1 DELETE /api/subscription/schedule_upgrade/{S1}，再刪一次',
      expect='1. HTTP 200，年繳在月繳到期後自動接續，立即獲贈年繳的 300 點（共 320 點）\n2. HTTP 400，「已有排程升級」\n'
             '3. HTTP 200，「此排程已完成付款」\n4. S2 HTTP 404「找不到有效訂閱」；S3 HTTP 400「已是年繳方案」\n5. 第一次「已取消排程升級」，第二次 HTTP 404')
def _(c):
    s1, s2, s3 = register('upg'), register('upg'), register('upg')
    subscribe(s1, 'monthly')
    subscribe(s3, 'yearly')
    up = lambda u: SC.post('/api/subscription/schedule_upgrade', json={'user_id': u['id'], 'payment_method': 'credit_card'})
    r1 = up(s1)
    with S.app_context():
        subs = UserSubscription.query.filter_by(user_id=s1['id']).order_by(UserSubscription.start_date).all()
        chained = len(subs) == 2 and subs[1].start_date == subs[0].end_date and subs[1].billing_cycle == 'yearly'
    r2 = up(s1)
    r3 = SC.post('/api/subscription/pay_pending', json={'user_id': s1['id']})
    r4a, r4b = up(s2), up(s3)
    r5a = SC.delete(f'/api/subscription/schedule_upgrade/{s1["id"]}')
    r5b = SC.delete(f'/api/subscription/schedule_upgrade/{s1["id"]}')
    c.log(f'1. {http(r1, "message", "points_granted", "total_points")}，年繳接在月繳到期日之後={chained}；2. {http(r2, "error")}；3. {http(r3, "message")}；'
          f'4. S2 {http(r4a, "error")}；S3 {http(r4b, "error")}；5. {http(r5a, "message")}；{http(r5b, "error")}')
    check(r1.status_code == 200 and J(r1).get('points_granted') == 300 and J(r1).get('total_points') == 320 and chained, '排程升級不正確')
    check(r2.status_code == 400 and J(r2).get('error') == '已有排程升級', '可以重複排程')
    check(r3.status_code == 200 and J(r3).get('message') == '此排程已完成付款', '排程付款狀態不正確')
    check(r4a.status_code == 404 and J(r4a).get('error') == '找不到有效訂閱' and r4b.status_code == 400
          and J(r4b).get('error') == '已是年繳方案', '不符資格的升級未擋下')
    check(r5a.status_code == 200 and J(r5a).get('message') == '已取消排程升級' and r5b.status_code == 404, '取消排程不正確')


@case('A07', '查詢點數可兌換的加購項目',
      pre='無',
      steps='GET /api/store/items',
      expect='HTTP 200，列出可用點數兌換的加購項目：朗讀評分 20 點、AI 對話 15 點、拍照辨識 10 點（各 +1 次），單字收藏擴充 100 點（訂閱會員 50 點）')
def _(c):
    r = SC.get('/api/store/items')
    items = J(r).get('items', [])
    c.log(f'HTTP {r.status_code}，項目={[(i.get("id") or i.get("feature"), i.get("name"), i.get("cost")) for i in items]}')
    check(r.status_code == 200 and len(items) >= 2 and all(i.get('name') and i.get('cost') for i in items), '兌換項目清單不正確')
    cost = {i.get('id'): i.get('cost') for i in items}
    check(cost == {'reading_extra': 20, 'ai_extra': 15, 'photo_extra': 10, 'vocab_expand': 100, 'vocab_expand_premium': 50},
          '加購項目的價格不正確')


@case('A11', '每日朗讀次數用完後以點數加購朗讀評分',
      pre='免費會員 X 今日已朗讀評分 1 次（每日上限 1 次），目前 0 點；AI 評分以模擬資料替代',
      steps='1. 再朗讀一次\n2. 0 點時 POST /api/user/spend_points，feature=reading_extra\n3. 購買 20 點後兌換，並查 usage_status\n'
            '4. 再朗讀一次，並查 usage_status\n5. 再朗讀一次',
      expect='1. status=quota_exceeded，提示可到商城花 20 點加購 1 次\n2. HTTP 400，「點數不足，需要 20 點」\n'
             '3. HTTP 200，扣 20 點、「+1 次朗讀評分（永久）」，reading_extra_count=1\n'
             '4. status=success，使用加購次數，reading_extra_count=0\n5. status=quota_exceeded',
      note='AI 回應以模擬資料替代')
def _(c):
    ensure_articles()
    aid = STATE['art_free']
    x = register('readextra')

    def read():
        GEMINI_FAKE['handler'] = fake_reading_ai
        try:
            return J(SC.post('/api/articles/evaluate', data={'audio': (io.BytesIO(M4A_BYTES), 'reading.m4a'),
                                                             'user_id': str(x['id']), 'article_id': str(aid)},
                             content_type='multipart/form-data'))
        finally:
            GEMINI_FAKE['handler'] = None

    first = read()
    d1 = read()
    r2 = SC.post('/api/user/spend_points', json={'user_id': x['id'], 'feature': 'reading_extra'})
    SC.post('/api/user/add_points', json={'user_id': x['id'], 'points': 20, 'price': 0, 'payment_method': 'credit_card'})
    r3 = SC.post('/api/user/spend_points', json={'user_id': x['id'], 'feature': 'reading_extra'})
    extra3 = usage(x).get('reading_extra_count')
    d4 = read()
    extra4 = usage(x).get('reading_extra_count')
    d5 = read()
    c.log(f'前置朗讀={first.get("status")}；1. {d1.get("status")}，提示={d1.get("message")}；2. {http(r2, "error")}；'
          f'3. {http(r3, "effect", "total_points")}，reading_extra_count={extra3}；'
          f'4. {d4.get("status")}，used_extra={d4.get("used_extra")}，reading_extra_count={extra4}；5. {d5.get("status")}')
    check(first.get('status') == 'success' and d1.get('status') == 'quota_exceeded'
          and '花 20 點加購 1 次' in (d1.get('message') or ''), '次數用完的提示不正確')
    check(r2.status_code == 400 and J(r2).get('error') == '點數不足，需要 20 點', '點數不足未擋下')
    check(r3.status_code == 200 and J(r3).get('effect') == '+1 次朗讀評分（永久）' and J(r3).get('total_points') == 0
          and extra3 == 1, '加購朗讀次數失敗')
    check(d4.get('status') == 'success' and d4.get('used_extra') is True and extra4 == 0, '加購次數沒有被使用')
    check(d5.get('status') == 'quota_exceeded', '加購次數用完後仍可朗讀')


# ======================================================================
# 補齊管理後台其餘功能（2026-10-05 盤點路由後補上）
# ======================================================================
import contextlib


@contextlib.contextmanager
def admin_settings(**values):
    """暫時指定後台的環境設定（正式環境寫在 .env），個案結束後還原"""
    old = {k: getattr(admin_module, k) for k in values}
    for k, v in values.items():
        setattr(admin_module, k, v)
    try:
        yield
    finally:
        for k, v in old.items():
            setattr(admin_module, k, v)


def super_client():
    return admin_client('sys_super', 'Admin@1234')


def admin_login_as(username, password):
    c = A.test_client()
    return c, c.post('/login', data={'username': username, 'password': password})


def teacher_web_login(email, password):
    c = A.test_client()
    return c, c.post('/login', data={'login_as': 'teacher', 'email': email, 'password': password})


def logs(table, target_id=None, action=None):
    with S.app_context():
        q = SystemLog.query.filter_by(target_table=table)
        if target_id is not None:
            q = q.filter_by(target_id=target_id)
        if action:
            q = q.filter_by(action=action)
        return q.count()


@case('A10', '最高管理者新增管理者帳號',
      pre='最高管理者 sys_super 已登入；一般管理者 sys_staff',
      steps='於「管理員帳號」頁新增帳號：\n1. 帳號空白\n2. 密碼太弱（12345678）\n3. 帳號 kanri01、權限 admin、密碼 Kanri#2026a\n4. 再新增一次 kanri01\n'
            '5. 一般管理者 sys_staff 送出新增帳號\n6. kanri01 第一次登入',
      expect='1. 提示「請輸入帳號」\n2. 提示密碼強度不足\n3. 建立成功並寫入操作日誌\n4. 提示帳號已存在\n5. 被導回儀表板，不建立帳號\n6. 登入後被導到修改密碼頁')
def _(c):
    boss = super_client()
    add = lambda cl, **d: (cl.post('/admin_account/add', data=d), flashes(cl))[1]
    f1 = add(boss, username='', role='admin', password='Kanri#2026a')
    f2 = add(boss, username='kanri00', role='admin', password='12345678')
    f3 = add(boss, username='kanri01', role='admin', password='Kanri#2026a')
    f4 = add(boss, username='kanri01', role='admin', password='Kanri#2026a')
    staff = admin_client('sys_staff', 'Staff@1234')
    r5 = staff.post('/admin_account/add', data={'username': 'kanri02', 'role': 'admin', 'password': 'Kanri#2026a'})
    with S.app_context():
        row = Admin.query.filter_by(username='kanri01').first()
        info = (row.role, row.must_change_password, row.id) if row else None
        n = Admin.query.filter(Admin.username.in_(['kanri00', 'kanri02'])).count()
    cl, r6 = admin_login_as('kanri01', 'Kanri#2026a')
    STATE['kanri'] = info[2] if info else None
    c.log(f'1. {f1}；2. {f2}；3. {f3}，帳號（權限, 需改密碼）={info[:2] if info else None}、操作日誌 {logs("admin", info[2], "CREATE") if info else 0} 筆；'
          f'4. {f4}；5. HTTP {r5.status_code} → {loc(r5)}，多建帳號 {n} 個；6. HTTP {r6.status_code} → {loc(r6)}')
    check(f1 == ['請輸入帳號'] and len(f2) == 1 and f2[0] and '已建立' not in f2[0], '不合格的帳號資料未擋下')
    check(len(f3) == 1 and '已建立管理員「kanri01」' in f3[0] and info[:2] == ('admin', True) and logs('admin', info[2], 'CREATE') == 1,
          '新增管理者失敗')
    check(f4 == ['帳號「kanri01」已存在'], '重複帳號未擋下')
    check(r5.status_code == 302 and loc(r5).endswith('/dashboard') and n == 0, '一般管理者可以新增帳號')
    check(r6.status_code == 302 and 'change_password' in loc(r6), '新帳號第一次登入沒有要求改密碼')


@case('A10', '管理者修改密碼與登出',
      pre='kanri01 用最高管理者給的密碼 Kanri#2026a 登入，尚未改密碼',
      steps='於「修改密碼」頁：\n1. 目前密碼打錯\n2. 新密碼與確認密碼不一致\n3. 新密碼太弱\n4. 目前密碼正確、新密碼 Kanri#2027b\n'
            '5. 點擊登出後直接開啟儀表板\n6. 分別用舊密碼、新密碼登入',
      expect='1. 「目前密碼錯誤」\n2. 「新密碼與確認密碼不一致」\n3. 提示密碼強度不足\n4. 「密碼已成功更新」\n5. 被導回登入頁\n6. 舊密碼無法登入；新密碼登入後直接進儀表板')
def _(c):
    cl, _r = admin_login_as('kanri01', 'Kanri#2026a')

    def change(cur, new, confirm=None):
        return html(cl.post('/admin/change_password', data={'current_password': cur, 'new_password': new,
                                                            'confirm_password': confirm or new}))

    h1 = change('Wrong#0000a', 'Kanri#2027b')
    h2 = change('Kanri#2026a', 'Kanri#2027b', 'Kanri#2027c')
    h3 = change('Kanri#2026a', 'abcdefgh')
    h4 = change('Kanri#2026a', 'Kanri#2027b')
    cl.get('/logout')
    r5 = cl.get('/dashboard')
    _c1, r6a = admin_login_as('kanri01', 'Kanri#2026a')
    _c2, r6b = admin_login_as('kanri01', 'Kanri#2027b')
    c.log(f'1. 目前密碼錯誤={"目前密碼錯誤" in h1}；2. 不一致={"新密碼與確認密碼不一致" in h2}；3. 未更新={"密碼已成功更新" not in h3}；'
          f'4. 已更新={"密碼已成功更新" in h4}；5. HTTP {r5.status_code} → {loc(r5)}；6. 舊密碼 HTTP {r6a.status_code}、新密碼 HTTP {r6b.status_code} → {loc(r6b)}')
    check('目前密碼錯誤' in h1 and '新密碼與確認密碼不一致' in h2 and '密碼已成功更新' not in h3, '錯誤的改密碼請求未擋下')
    check('密碼已成功更新' in h4, '修改密碼失敗')
    check(r5.status_code == 302 and 'login' in loc(r5), '登出後仍可進後台')
    check(r6a.status_code == 200 and '帳號或密碼錯誤' in html(r6a), '舊密碼仍可登入')
    check(r6b.status_code == 302 and loc(r6b).endswith('/dashboard'), '新密碼無法登入')


@case('A10', '管理者帳號的權限切換、停用與重設密碼',
      pre='最高管理者 sys_super 已登入；kanri01 為一般管理者',
      steps='於「管理員帳號」頁：\n1. 把 kanri01 的權限改為 super_admin，再改回 admin\n2. 修改自己的權限、停用自己\n3. 停用 kanri01 後，kanri01 嘗試登入\n'
            '4. 重新啟用 kanri01\n5. 重設 kanri01 的密碼為 Reset#2026c 後，kanri01 用新密碼登入',
      expect='1. 權限依序變為 super_admin、admin，並留下操作日誌\n2. 提示不能修改自己的權限、不能停用自己的帳號\n'
             '3. 停用成功；kanri01 登入時顯示帳號已被停用\n4. 啟用成功\n5. 重設成功；kanri01 登入後被導到修改密碼頁')
def _(c):
    boss = super_client()
    kid = STATE['kanri']
    with S.app_context():
        me = Admin.query.filter_by(username='sys_super').first().id
    post = lambda url, **d: (boss.post(url, data=d), flashes(boss))[1]
    role = lambda: count(Admin, id=kid, role='super_admin')
    f1a = post(f'/admin_account/toggle_role/{kid}')
    up = role()
    f1b = post(f'/admin_account/toggle_role/{kid}')
    f2a = post(f'/admin_account/toggle_role/{me}')
    f2b = post(f'/admin_account/toggle_active/{me}')
    f3 = post(f'/admin_account/toggle_active/{kid}')
    _c, r3 = admin_login_as('kanri01', 'Kanri#2027b')
    f4 = post(f'/admin_account/toggle_active/{kid}')
    f5 = post(f'/admin_account/reset_password/{kid}', password='Reset#2026c')
    _c, r5 = admin_login_as('kanri01', 'Reset#2026c')
    c.log(f'1. {f1a}；{f1b}，操作日誌 {logs("admin", kid, "UPDATE")} 筆；2. {f2a}；{f2b}；3. {f3}，登入顯示已停用={"已被停用" in html(r3)}；'
          f'4. {f4}；5. {f5}，登入 HTTP {r5.status_code} → {loc(r5)}')
    check('super_admin' in f1a[0] and up == 1 and '改為 admin' in f1b[0] and role() == 0, '權限切換不正確')
    check(f2a == ['不能修改自己的權限'] and f2b == ['不能停用自己的帳號'], '可以修改自己的權限或停用自己')
    check(f3 == ['已停用「kanri01」'] and r3.status_code == 200 and '已被停用' in html(r3), '停用後仍可登入')
    check(f4 == ['已啟用「kanri01」'], '重新啟用失敗')
    page = boss.get('/admin_account/list')
    check(page.status_code == 200 and 'kanri01' in html(page), '管理員帳號列表不正確')
    check('已重設「kanri01」的密碼' in f5[0] and r5.status_code == 302 and 'change_password' in loc(r5), '重設密碼不正確')


@case('A10', '文章管理：新增、修改、上下架與刪除',
      pre='管理者已登入；App 使用者 R2 程度 N2',
      steps='於「文章管理」頁：\n1. 新增文章但沒有標題；等級選錯；解鎖點數填 0\n2. 新增 N2 文章「東京の朝」，解鎖 80 點、立即上架，R2 於 App 查看 N2 文章\n'
            '3. 修改標題為「東京の朝（改）」、解鎖 60 點\n4. 下架後 R2 再查看，之後重新上架\n5. 刪除文章',
      expect='1. 分別提示標題與內容必填、請選擇正確的難度、解鎖點數必須大於 0，皆不建立文章\n2. 新增成功（提示寫「中高級」不顯示 N2），App 的中高級文章列表出現這篇（未解鎖）\n'
             '3. 修改成功，資料與操作日誌更新\n4. 下架後 App 看不到，上架後恢復\n5. 刪除成功，App 看不到並留下操作日誌')
def _(c):
    cl = admin_client('sys_staff', 'Staff@1234')
    r2 = register('artadmin')
    set_user(r2['id'], japanese_level='N2')
    base = {'title': '東京の朝', 'level': 'N2', 'theme': '日常生活', 'content': '[東京|とうきょう]の[朝|あさ]は[忙|いそが]しいです。',
            'translation': '東京的早晨很忙碌。', 'unlock_cost': '80', 'is_published': 'on'}
    post = lambda url, **d: (cl.post(url, data=d), flashes(cl))[1]
    titles = lambda: [x['title'] for x in J(SC.get(f'/api/articles/dashboard?user_id={r2["id"]}&level=N2')).get('data', [])]
    f1 = [post('/article/add', **dict(base, title='')), post('/article/add', **dict(base, level='N9')),
          post('/article/add', **dict(base, unlock_cost='0'))]
    n1 = count(Article, title='東京の朝')
    f2 = post('/article/add', **base)
    with S.app_context():
        a = Article.query.filter_by(title='東京の朝').first()
        aid, cost, free = a.id, a.unlock_cost, a.is_free
    seen2 = titles()
    f3 = post(f'/article/edit/{aid}', **dict(base, title='東京の朝（改）', unlock_cost='60'))
    with S.app_context():
        a = db.session.get(Article, aid)
        edited = (a.title, a.unlock_cost)
    f4a = post(f'/article/toggle/{aid}')
    seen4a = titles()
    f4b = post(f'/article/toggle/{aid}')
    seen4b = titles()
    page = html(cl.get('/article/list?keyword=東京'))
    f5 = post(f'/article/delete/{aid}')
    seen5 = titles()
    c.log(f'1. {f1}，建立 {n1} 篇；2. {f2}，解鎖點數={cost}、免費={free}，App 看到={seen2}；3. {f3}，資料={edited}；'
          f'4. {f4a}，App 看到={seen4a}；{f4b}，App 看到={seen4b}；5. {f5}，App 看到={seen5}；'
          f'操作日誌（新增, 修改, 刪除）={logs("articles", aid, "CREATE")}, {logs("articles", aid, "UPDATE")}, {logs("articles", aid, "DELETE")}')
    check(f1 == [['標題與日文內容為必填欄位'], ['請選擇正確的難度（入門～高級）'], ['解鎖點數必須大於 0（新文章一律付費解鎖）']] and n1 == 0,
          '不合格的文章未擋下')
    check('已新增中高級文章「東京の朝」' in f2[0] and cost == 80 and free is False and '東京の朝' in seen2, '新增文章失敗')
    check(f3 == ['已更新文章「東京の朝（改）」'] and edited == ('東京の朝（改）', 60) and '東京の朝（改）' in page, '修改文章失敗')
    check(f4a == ['已下架「東京の朝（改）」'] and '東京の朝（改）' not in seen4a
          and f4b == ['已上架「東京の朝（改）」'] and '東京の朝（改）' in seen4b, '上下架不正確')
    check(f5 == ['已刪除文章「東京の朝（改）」'] and '東京の朝（改）' not in seen5 and count(Article, id=aid) == 0
          and logs('articles', aid, 'DELETE') == 1, '刪除文章失敗')


@case('A10', '測驗題目管理：新增、修改、搜尋與刪除',
      pre='管理者已登入',
      steps='於「測驗題目」頁：\n1. 新增題目但缺少選項 D；正確答案填 E\n2. 新增一題 N3 題目「後台測試題：正確的助詞是？」，答案 B\n'
            '3. 修改題目文字與正確答案為 C\n4. 以關鍵字「後台測試題」搜尋\n5. 刪除這一題',
      expect='1. 兩次都不會新增題目\n2. 題目新增成功並寫入操作日誌\n3. 題目與答案更新\n4. 搜尋結果列出這一題\n5. 題目刪除並寫入操作日誌')
def _(c):
    cl = admin_client('sys_staff', 'Staff@1234')
    base = {'stage': '第三階段：中級', 'level_tag': 'N3', 'question': '後台測試題：正確的助詞是？',
            'option_a': 'は', 'option_b': 'を', 'option_c': 'に', 'option_d': 'で', 'correct_answer': 'b'}
    before = count(QuizQuestion)
    cl.post('/quiz/add', data=dict(base, option_d=''))
    cl.post('/quiz/add', data=dict(base, correct_answer='E'))
    n1 = count(QuizQuestion) - before
    cl.post('/quiz/add', data=base)
    with S.app_context():
        q = QuizQuestion.query.filter_by(question=base['question']).first()
        qid, ans = (q.id, q.correct_answer) if q else (None, None)
    cl.post(f'/quiz/edit/{qid}', data=dict(base, question='後台測試題：請選出正確的助詞', correct_answer='C'))
    with S.app_context():
        q = db.session.get(QuizQuestion, qid)
        edited = (q.question, q.correct_answer)
    found = '請選出正確的助詞' in html(cl.get('/quiz/list?q=後台測試題'))
    other = '請選出正確的助詞' in html(cl.get('/quiz/list?q=不存在的關鍵字'))
    cl.post(f'/quiz/delete/{qid}')
    left = count(QuizQuestion, id=qid)
    c.log(f'1. 多出 {n1} 題；2. 題目編號={qid}、答案={ans}；3. {edited}；4. 搜尋到={found}、無關的關鍵字搜尋到={other}；5. 剩 {left} 題；'
          f'操作日誌（新增, 修改, 刪除）={logs("quiz_question", qid, "INSERT")}, {logs("quiz_question", qid, "UPDATE")}, {logs("quiz_question", qid, "DELETE")}')
    check(n1 == 0, '不完整的題目被新增')
    check(qid and ans == 'B' and logs('quiz_question', qid, 'INSERT') == 1, '新增題目失敗')
    check(edited == ('後台測試題：請選出正確的助詞', 'C'), '修改題目失敗')
    check(found and not other, '題目搜尋不正確')
    check(left == 0 and logs('quiz_question', qid, 'DELETE') == 1 and count(QuizQuestion) == before, '刪除題目失敗')


@case('A10', '教材單字管理：新增、修改與刪除',
      pre='管理者已登入',
      steps='於「教材單字」頁：\n1. 新增單字「後台語」（こうだいご／後台測試單字）\n2. 修改為「後台語改」\n3. 查看單字列表\n4. 刪除這個單字',
      expect='1. 單字新增為官方單字並寫入操作日誌\n2. 單字更新\n3. 列表顯示修改後的單字\n4. 單字刪除並寫入操作日誌')
def _(c):
    cl = admin_client('sys_staff', 'Staff@1234')
    cl.post('/vocab/add', data={'word': '後台語', 'kana': 'こうだいご', 'meaning': '後台測試單字'})
    with S.app_context():
        v = Vocab.query.filter_by(word='後台語').first()
        vid, source = (v.id, v.source) if v else (None, None)
    cl.post(f'/vocab/edit/{vid}', data={'word': '後台語改', 'kana': 'こうだいごかい', 'meaning': '後台測試單字（改）'})
    with S.app_context():
        v = db.session.get(Vocab, vid)
        edited = (v.word, v.kana, v.meaning)
    r3 = cl.get('/vocab/list')
    listed = '後台語改' in html(r3)
    cl.post(f'/vocab/delete/{vid}')
    left = count(Vocab, id=vid)
    c.log(f'1. 單字編號={vid}、來源={source}；2. {edited}；3. HTTP {r3.status_code}，列表有這個字={listed}；4. 剩 {left} 筆；'
          f'操作日誌（新增, 修改, 刪除）={logs("vocab", vid, "INSERT")}, {logs("vocab", vid, "UPDATE")}, {logs("vocab", vid, "DELETE")}')
    check(vid and source == 'admin' and logs('vocab', vid, 'INSERT') == 1, '新增單字失敗')
    check(edited == ('後台語改', 'こうだいごかい', '後台測試單字（改）') and listed, '修改單字失敗')
    check(left == 0 and logs('vocab', vid, 'DELETE') == 1, '刪除單字失敗')


@case('A10', '成就徽章管理：檢視解鎖情形與補建主題徽章',
      pre='管理者已登入；資料庫少了一個主題徽章（以測試工具刪除模擬）',
      steps='1. 開啟「成就徽章」頁\n2. 點擊補建主題徽章\n3. 再補建一次',
      expect='1. 頁面列出各徽章與解鎖人數，並提示缺少的主題徽章\n2. 補建缺少的 1 個徽章並寫入操作日誌\n3. 提示主題徽章都已存在')
def _(c):
    cl = admin_client('sys_staff', 'Staff@1234')
    with A.app_context():
        names = [b for b, _t in admin_module._theme_badge_names()]
    with S.app_context():
        held = {ua.achievement_id for ua in UserAchievement.query.all()}
        victim = next(a for a in Achievement.query.filter(Achievement.name.in_(names)).all() if a.id not in held)
        gone = victim.name
        db.session.delete(victim)
        db.session.commit()
    r1 = cl.get('/achievement/list')
    page = html(r1)
    cl.post('/achievement/sync_theme')
    f2 = flashes(cl)
    back = count(Achievement, name=gone)
    cl.post('/achievement/sync_theme')
    f3 = flashes(cl)
    c.log(f'1. HTTP {r1.status_code}，頁面有「新手上路」={"新手上路" in page}、提到缺少的「{gone}」={gone in page}；2. {f2}，徽章 {back} 個；3. {f3}')
    check(r1.status_code == 200 and '新手上路' in page and gone in page, '成就徽章頁不正確')
    check(len(f2) == 1 and f'已補建 1 個主題徽章：{gone}' == f2[0] and back == 1, '補建主題徽章失敗')
    check(f3 == ['主題徽章都已存在，不需要補建'], '重複補建')


@case('A10', '照片管控與刪除意見回饋',
      pre='使用者 PH 拍了 1 張照片並命名為「違規照片測試」，另送出 1 筆意見回饋；管理者已登入',
      steps='1. 開啟「照片管控」頁\n2. 刪除這張照片後，PH 於 App 查看照片紀錄\n3. 於「意見回饋」頁刪除 PH 的回饋後，PH 於 App 查看回饋紀錄',
      expect='1. 列表顯示這張照片與上傳者\n2. 照片、照片檔案與照片單字明細刪除，App 的照片紀錄為 0 筆\n3. 回饋刪除並寫入操作日誌，App 的回饋紀錄為 0 筆',
      note='AI 回應以模擬資料替代')
def _(c):
    ph = register('photoadmin')
    SC.post('/api/user/update_username', json={'user_id': ph['id'], 'username': 'Photo_Tester'})
    FAKE['scan_ok'] = True
    pid = (J(analyze_photo(ph)).get('result') or {}).get('photo_id') or J(SC.get(f'/api/scenario/unlocked/{ph["id"]}'))['scenes'][0]['photo_id']
    SC.post('/api/scenario/rename_photo', json={'photo_id': pid, 'custom_title': '違規照片測試'})
    SC.post('/api/user/feedback', json={'user_id': ph['id'], 'email': ph['email'], 'feedback_type': '問題回報', 'content': '這筆回饋要被刪除'})
    with S.app_context():
        fid = Feedback.query.filter_by(user_id=ph['id']).first().id
        photo_file = os.path.join(UPLOAD_DIR, os.path.basename(UserPhoto.query.get(pid).image_path))
    file_before = os.path.isfile(photo_file)
    cl = admin_client('sys_staff', 'Staff@1234')
    r1 = cl.get('/photo/list')
    page = html(r1)
    r2 = cl.post(f'/photo/delete/{pid}')
    file_after = os.path.isfile(photo_file)
    n_photo, n_pv = count(UserPhoto, id=pid), count(UserPhotoVocab, photo_id=pid)
    app_total = J(SC.get(f'/api/scenario/unlocked/{ph["id"]}')).get('total')
    r3 = cl.post(f'/feedback/delete/{fid}')
    n_fb = count(Feedback, id=fid)
    app_fb = J(SC.get(f'/api/user/feedback/{ph["id"]}'))
    c.log(f'1. HTTP {r1.status_code}，列表有這張照片={"違規照片測試" in page}、有上傳者={"Photo_Tester" in page}；'
          f'2. HTTP {r2.status_code}，照片 {n_photo} 筆、單字明細 {n_pv} 筆、照片檔案存在={file_after}，App 照片紀錄 {app_total} 筆；'
          f'3. HTTP {r3.status_code}，回饋 {n_fb} 筆、操作日誌 {logs("feedback", fid, "DELETE")} 筆')
    check(r1.status_code == 200 and '違規照片測試' in page and 'Photo_Tester' in page, '照片管控列表不正確')
    check(r2.status_code == 302 and n_photo == 0 and n_pv == 0 and app_total == 0, '刪除照片失敗')
    check(file_before and not file_after, '照片檔案沒有一併刪除')
    check(r3.status_code == 302 and n_fb == 0 and logs('feedback', fid, 'DELETE') == 1, '刪除回饋失敗')
    check('這筆回饋要被刪除' not in json.dumps(app_fb, ensure_ascii=False), 'App 仍看得到已刪除的回饋')


@case('A10', '營運資料查詢頁：購買紀錄、學習紀錄與學習小組',
      pre='管理者已登入；使用者 BUY 購買過 140 點並兌換過加購、做過 1 次造句；另有一個進行中的學習小組「後台檢視小組」',
      steps='1. 開啟「購買紀錄」頁\n2. 開啟「學習紀錄」頁的造句分頁（以 BUY 的 Email 搜尋）與朗讀分頁\n3. 開啟「學習小組」頁，並切換為只看進行中\n'
            '4. 開啟舊網址「點數管理」與「點數方案」',
      expect='1. 列出 BUY 的購點紀錄（140 點／NT$90），不包含兌換消費\n2. 造句分頁列出 BUY 的造句紀錄；朗讀分頁正常顯示\n'
             '3. 列出「後台檢視小組」與成員\n4. 分別導到使用者資料頁與方案管理頁')
def _(c):
    buy = register('opsbuy')
    SC.post('/api/user/add_points', json={'user_id': buy['id'], 'points': 140, 'price': 90, 'payment_method': 'google_pay'})
    SC.post('/api/store/redeem', json={'user_id': buy['id'], 'feature': 'ai_extra'})
    evaluate_sentence(buy)
    SC.post('/api/group/create', json={'user_id': buy['id'], 'name': '後台檢視小組', 'goal_type': 'scans', 'goal_target': 30})
    cl = super_client()
    r1 = cl.get('/purchase/list')
    p1 = html(r1)
    r2a = cl.get('/record/list', query_string={'tab': 'sentence', 'q': buy['email']})
    r2b = cl.get('/record/list?tab=reading')
    p2 = html(r2a)
    r3a, r3b = cl.get('/group/list'), cl.get('/group/list?status=active')
    r4a, r4b = cl.get('/customer/list'), cl.get('/package/list')
    c.log(f'1. HTTP {r1.status_code}，有 BUY 的紀錄={buy["email"] in p1}；2. 造句分頁 HTTP {r2a.status_code}，有 BUY 的造句={"健康のために" in p2}；朗讀分頁 HTTP {r2b.status_code}；'
          f'3. HTTP {r3a.status_code}／{r3b.status_code}，有這個小組={"後台檢視小組" in html(r3b)}；4. → {loc(r4a)}、{loc(r4b)}')
    check(r1.status_code == 200 and buy['email'] in p1 and '140' in p1, '購買紀錄頁不正確')
    check(r2a.status_code == 200 and '健康のために' in p2 and r2b.status_code == 200, '學習紀錄頁不正確')
    check(r3a.status_code == 200 and r3b.status_code == 200 and '後台檢視小組' in html(r3a) and '後台檢視小組' in html(r3b), '學習小組頁不正確')
    check(r4a.status_code == 302 and 'user' in loc(r4a) and r4b.status_code == 302 and 'plan' in loc(r4b), '舊網址沒有導到新頁面')


@case('A10', '新增訂閱方案',
      pre='最高管理者已登入；App 目前有 2 個訂閱方案',
      steps='於「方案管理」的訂閱方案分頁：\n1. 方案名稱空白送出\n2. 新增「測試季訂閱」（月繳 NT$399、贈 60 點），再於 App 查看訂閱方案',
      expect='1. 不新增方案\n2. 方案新增並寫入操作日誌，App 的訂閱方案多出「測試季訂閱」')
def _(c):
    cl = super_client()
    before = count(SubscriptionPlan)
    cl.post('/plan/add', data={'name': '', 'billing_cycle': 'monthly', 'price_monthly': '399'})
    n1 = count(SubscriptionPlan) - before
    r2 = cl.post('/plan/add', data={'name': '測試季訂閱', 'billing_cycle': 'monthly', 'price_monthly': '399', 'points_grant_monthly': '60'})
    with S.app_context():
        p = SubscriptionPlan.query.filter_by(name='測試季訂閱').first()
        info = (p.id, p.price_monthly, p.points_grant_monthly, p.is_active) if p else None
    names = [x['name'] for x in J(SC.get('/api/subscription/plans')).get('plans', [])]
    n_log = logs('subscription_plan', info[0], 'INSERT') if info else 0
    with S.app_context():   # 清掉測試方案，避免影響之後依方案數量判斷的個案
        SubscriptionPlan.query.filter_by(name='測試季訂閱').delete()
        db.session.commit()
    c.log(f'1. 多出 {n1} 個方案；2. HTTP {r2.status_code}，方案（月費, 贈點, 啟用）={info[1:] if info else None}、操作日誌 {n_log} 筆，App 方案={names}')
    check(n1 == 0, '名稱空白的方案被新增')
    check(info and info[1:] == (399, 60, True) and n_log == 1 and '測試季訂閱' in names, '新增訂閱方案失敗')


# ----------------------------------------------------------------------
# A13 校園教育版：學校管理、老師帳號、班級與名冊（後台）
# ----------------------------------------------------------------------
@case('A13', '後台學校管理：新增、修改學號格式與停用',
      pre='最高管理者已登入',
      steps='於「學校管理」頁：\n1. 新增學校但名稱空白；網域填「not a domain」；學號格式填錯誤的正規式\n'
            '2. 新增「後台新增大學」，網域 adminuni.edu.tw、學號格式 ^s(\\d{8})$，再於 App 查看學校清單\n3. 再新增一次同名學校\n'
            '4. 學生分別用 s12345678@、11156001@adminuni.edu.tw 登入\n5. 把學號格式改回預設後，11156001@ 再登入\n'
            '6. 停用這間學校後查看 App 學校清單並登入，之後重新啟用\n7. 一般管理者開啟學校管理頁',
      expect='1. 分別提示請輸入學校名稱、網域格式不正確、學號格式寫錯了\n2. 新增成功，App 清單出現這間學校\n3. 提示已經有這間學校\n'
             '4. 符合學號格式的可以登入，不符合的被拒（not_student）\n5. 修改成功，11156001@ 可以登入\n'
             '6. 停用後 App 清單不顯示、無法登入；啟用後恢復\n7. 被導回儀表板',
      note='Google 身分憑證驗證以模擬方式進行')
def _(c):
    boss = super_client()
    post = lambda url, **d: (boss.post(url, data=d), flashes(boss))[1]
    app_names = lambda: [x['name'] for x in J(SC.get('/api/auth/schools')).get('schools', [])]
    good = {'name': '後台新增大學', 'student_domains': 'adminuni.edu.tw', 'student_id_pattern': r'^s(\d{8})$'}
    f1 = [post('/school/add', **dict(good, name='')), post('/school/add', **dict(good, student_domains='not a domain')),
          post('/school/add', **dict(good, student_id_pattern='^s(\\d{8'))]
    f2 = post('/school/add', **good)
    sid = None
    with S.app_context():
        s = School.query.filter_by(name='後台新增大學').first()
        sid = s.id if s else None
    listed2 = '後台新增大學' in app_names()
    f3 = post('/school/add', **good)
    r4a = edu_google('valid:s12345678@adminuni.edu.tw', school_id=sid)
    r4b = edu_google('valid:11156001@adminuni.edu.tw', school_id=sid)
    f5 = post(f'/school/edit/{sid}', name='後台新增大學', student_domains='adminuni.edu.tw', student_id_pattern='')
    r5 = edu_google('valid:11156001@adminuni.edu.tw', school_id=sid)
    f6a = post(f'/school/toggle/{sid}')
    listed6 = '後台新增大學' in app_names()
    r6 = edu_google('valid:s12345678@adminuni.edu.tw', school_id=sid)
    f6b = post(f'/school/toggle/{sid}')
    page = boss.get('/school/list')
    r7 = admin_client('sys_staff', 'Staff@1234').get('/school/list')
    c.log(f'1. {f1}；2. {f2}，App 清單有這間學校={listed2}；3. {f3}；4. s12345678 {http(r4a, "is_new")}；11156001 {http(r4b, "status")}；'
          f'5. {f5}，11156001 HTTP {r5.status_code}；6. {f6a}，App 清單有={listed6}，登入 {http(r6, "status")}；{f6b}，App 清單有={"後台新增大學" in app_names()}；'
          f'7. HTTP {r7.status_code} → {loc(r7)}；操作日誌（新增, 修改）={logs("school", sid, "CREATE")}, {logs("school", sid, "UPDATE")}')
    check(f1[0] == ['請輸入學校名稱'] and '網域格式不正確' in f1[1][0] and '學號格式' in f1[2][0], '不合格的學校資料未擋下')
    check('已新增「後台新增大學」' in f2[0] and listed2 and logs('school', sid, 'CREATE') == 1, '新增學校失敗')
    check(f3 == ['已經有「後台新增大學」了'], '同名學校未擋下')
    check(r4a.status_code == 200 and r4b.status_code == 403 and J(r4b).get('status') == 'not_student', '學號格式沒有生效')
    check(f5 == ['已更新「後台新增大學」'] and r5.status_code == 200, '修改學號格式沒有生效')
    check('已停用「後台新增大學」' in f6a[0] and not listed6 and r6.status_code == 400 and f6b == ['已啟用「後台新增大學」']
          and '後台新增大學' in app_names(), '停用／啟用學校不正確')
    check(page.status_code == 200 and '後台新增大學' in html(page), '學校管理頁不正確')
    check(r7.status_code == 302 and loc(r7).endswith('/dashboard'), '一般管理者可以進學校管理')


@case('A13', '管理者建立老師帳號，老師登入後修改密碼',
      pre='最高管理者已登入；App 一般使用者 G',
      steps='1. 於「老師帳號」頁新增老師：Email 格式錯誤；密碼太弱\n2. 新增老師 sato@school.test「佐藤老師」，密碼 Sensei#2026a\n'
            '3. 再用同一個 Email、同一個姓名新增\n4. 老師於登入頁「老師」分頁用錯誤密碼登入；G 用自己的帳密登入\n5. 佐藤老師用正確密碼登入\n'
            '6. 於個人資料頁修改密碼：目前密碼錯誤、兩次不一致、改為 Sensei#2027b\n7. 改完後開啟班級管理頁',
      expect='1. 分別提示請輸入正確的 Email、密碼強度不足\n2. 建立成功並寫入操作日誌\n3. 分別提示 Email 已被使用、已經有老師叫這個名字\n'
             '4. 分別顯示「Email 或密碼錯誤」「這不是老師帳號」\n5. 登入成功，但先被導到個人資料頁要求修改密碼\n'
             '6. 前兩次被拒，第三次顯示密碼已更新\n7. 可以正常進入班級管理頁')
def _(c):
    boss = super_client()
    g = register('notteacher')
    add = lambda **d: (boss.post('/teacher_account/add', data=d), flashes(boss))[1]
    f1 = [add(email='sato-at-school', username='佐藤老師', password='Sensei#2026a'),
          add(email='sato@school.test', username='佐藤老師', password='12345678')]
    f2 = add(email='sato@school.test', username='佐藤老師', password='Sensei#2026a')
    with S.app_context():
        t = User.query.filter_by(email='sato@school.test').first()
        tid, info = (t.id, (t.account_type, t.must_change_password, t.teacher_status or 'approved')) if t else (None, None)
    f3 = [add(email='sato@school.test', username='佐藤二號', password='Sensei#2026a'),
          add(email='sato2@school.test', username='佐藤老師', password='Sensei#2026a')]
    _c, r4a = teacher_web_login('sato@school.test', 'Wrong#0000a')
    _c, r4b = teacher_web_login(g['email'], g['password'])
    web, r5 = teacher_web_login('sato@school.test', 'Sensei#2026a')
    blocked = web.get('/teacher/classrooms')

    def change(cur, new, confirm=None):
        return html(web.post('/teacher/change_password', data={'current_password': cur, 'new_password': new,
                                                               'confirm_password': confirm or new}))

    h6 = [change('Wrong#0000a', 'Sensei#2027b'), change('Sensei#2026a', 'Sensei#2027b', 'Sensei#2027c'),
          change('Sensei#2026a', 'Sensei#2027b')]
    r7 = web.get('/teacher/classrooms')
    STATE['sato'] = tid
    c.log(f'1. {f1}；2. {f2}，帳號（類型, 需改密碼, 審核）={info}、操作日誌 {logs("user", tid, "CREATE")} 筆；3. {f3}；'
          f'4. 錯誤密碼={"Email 或密碼錯誤" in html(r4a)}、一般帳號={"這不是老師帳號" in html(r4b)}；5. HTTP {r5.status_code} → {loc(r5)}，改密碼前開班級頁 → {loc(blocked)}；'
          f'6. {["目前密碼錯誤" in h6[0], "新密碼與確認密碼不一致" in h6[1], "密碼已更新" in h6[2]]}；7. HTTP {r7.status_code}')
    check(f1[0] == ['請輸入正確的 Email'] and len(f1[1]) == 1 and '已建立' not in f1[1][0], '不合格的老師資料未擋下')
    check('已建立老師帳號「佐藤老師」' in f2[0] and info == ('teacher', True, 'approved') and logs('user', tid, 'CREATE') == 1, '建立老師帳號失敗')
    check('已經被使用' in f3[0][0] and '已經有老師叫「佐藤老師」' in f3[1][0], '重複的老師資料未擋下')
    check('Email 或密碼錯誤' in html(r4a) and '這不是老師帳號' in html(r4b), '錯誤的老師登入未擋下')
    check(r5.status_code == 302 and 'profile' in loc(r5) and blocked.status_code == 302 and 'profile' in loc(blocked),
          '第一次登入沒有要求改密碼')
    check('目前密碼錯誤' in h6[0] and '新密碼與確認密碼不一致' in h6[1] and '密碼已更新' in h6[2], '老師修改密碼不正確')
    check(r7.status_code == 200, '改完密碼仍進不了班級管理')


@case('A13', '停用與重新啟用老師帳號',
      pre='佐藤老師已登入後台（A13 上一個個案）；最高管理者已登入',
      steps='1. 最高管理者於「老師帳號」頁停用佐藤老師\n2. 佐藤老師已登入的瀏覽器重新整理班級管理頁\n3. 佐藤老師重新登入\n4. 最高管理者重新啟用後，佐藤老師再登入',
      expect='1. 停用成功並寫入操作日誌\n2. 立即被登出、導回登入頁\n3. 顯示「此老師帳號已被停用」\n4. 啟用成功，可以登入')
def _(c):
    boss = super_client()
    tid = STATE['sato']
    web, _r = teacher_web_login('sato@school.test', 'Sensei#2027b')
    ok_before = web.get('/teacher/classrooms').status_code
    boss.post(f'/teacher_account/toggle/{tid}')
    f1 = flashes(boss)
    r2 = web.get('/teacher/classrooms')
    _c, r3 = teacher_web_login('sato@school.test', 'Sensei#2027b')
    boss.post(f'/teacher_account/toggle/{tid}')
    f4 = flashes(boss)
    _c, r4 = teacher_web_login('sato@school.test', 'Sensei#2027b')
    page = boss.get('/teacher_account/list')
    c.log(f'停用前開班級頁 HTTP {ok_before}；1. {f1}；2. HTTP {r2.status_code} → {loc(r2)}；3. 顯示已停用={"已被停用" in html(r3)}；'
          f'4. {f4}，登入 HTTP {r4.status_code} → {loc(r4)}')
    check(ok_before == 200 and f1 == ['已停用「佐藤老師」'], '停用老師失敗')
    check(r2.status_code == 302 and 'login' in loc(r2), '停用後已登入的老師沒有被登出')
    check(r3.status_code == 200 and '此老師帳號已被停用' in html(r3), '停用後仍可登入')
    check(f4 == ['已啟用「佐藤老師」'] and r4.status_code == 302 and 'classrooms' in loc(r4), '重新啟用後無法登入')
    check(page.status_code == 200 and '佐藤老師' in html(page), '老師帳號列表不正確')


@case('A13', '老師填申請表並以驗證信建立待審核帳號',
      pre='老師後台限定學校網域 @school.test；yamada@school.test 尚未有帳號；寄信以模擬方式攔截',
      steps='於登入頁點「申請老師帳號」：\n1. 沒填姓名；沒填系所；用一般 Gmail 申請\n2. 填「山田老師／yamada@school.test／應用日語系」送出，馬上再送一次\n'
            '3. 開啟信裡的驗證連結，設定密碼時兩次輸入不一致\n4. 設定密碼 Kaiwa#2026a\n5. 開啟被竄改的連結；開啟已逾時的連結\n6. 同一個 Email 再申請一次',
      expect='1. 分別提示請輸入姓名、請輸入系所或單位、請使用學校 Email\n2. 寄出驗證信到該信箱；馬上再送提示驗證信剛寄出\n'
             '3. 提示兩次輸入的密碼不一致，不建立帳號\n4. 建立「待審核」的老師帳號，並記下系所\n5. 分別提示驗證連結不正確、連結已逾時\n'
             '6. 提示這個 Email 已經送出申請',
      note='寄信以模擬方式攔截，未實際寄出')
def _(c):
    MAIL_FAKE['configured'] = True
    web = A.test_client()
    good = {'username': '山田老師', 'email': 'Yamada@school.test', 'department': '應用日語系', 'note': '教日語會話'}
    with admin_settings(TEACHER_GOOGLE_DOMAINS=['school.test']):
        apply_ = lambda cl, **d: html(cl.post('/teacher/apply', data=d))
        h1 = [apply_(web, **dict(good, username='')), apply_(web, **dict(good, department='')),
              apply_(web, **dict(good, email='yamada@gmail.com'))]
        n_mail = len(SENT_MAIL)
        h2a = apply_(web, **good)
        mail = SENT_MAIL[-1] if len(SENT_MAIL) > n_mail else {}
        h2b = apply_(web, **good)
        token = (re.search(r'token=(\S+)', mail.get('body', '')) or [None, ''])[1]
        g3 = web.get(f'/teacher/apply/verify?token={token}')
        h3 = html(web.post('/teacher/apply/verify', data={'token': token, 'password': 'Kaiwa#2026a', 'confirm_password': 'Kaiwa#2026b'}))
        n3 = count(User, email='yamada@school.test')
        h4 = web.post('/teacher/apply/verify', data={'token': token, 'password': 'Kaiwa#2026a', 'confirm_password': 'Kaiwa#2026a'})
        with S.app_context():
            t = User.query.filter_by(email='yamada@school.test').first()
            info = (t.account_type, t.teacher_status, t.teacher_department, t.username) if t else None
            STATE['yamada'] = t.id if t else None
        h5a = html(web.get(f'/teacher/apply/verify?token={token[:-3]}abc'))
        with admin_settings(TEACHER_APPLY_LINK_MINUTES=-1):
            h5b = html(web.get(f'/teacher/apply/verify?token={token}'))
        h6 = apply_(A.test_client(), **good)
    c.log(f'1. {["請輸入姓名" in h1[0], "請輸入系所或單位" in h1[1], "請使用學校 Email" in h1[2]]}；2. 收件人={mail.get("to")}、主旨={mail.get("subject")}，'
          f'再送={"驗證信剛寄出" in h2b}；3. 設定密碼頁 HTTP {g3.status_code}，不一致={"兩次輸入的密碼不一致" in h3}、帳號 {n3} 個；'
          f'4. HTTP {h4.status_code}，帳號（類型, 審核, 系所, 姓名）={info}；5. {["驗證連結不正確" in h5a, "請重新填寫申請表" in h5b]}；6. {"已經送出申請" in h6}')
    check('請輸入姓名' in h1[0] and '請輸入系所或單位' in h1[1] and '請使用學校 Email' in h1[2], '不合格的申請未擋下')
    check(mail.get('to') == 'yamada@school.test' and token and '驗證信剛寄出' in h2b, '驗證信寄送不正確')
    check(g3.status_code == 200 and '兩次輸入的密碼不一致' in h3 and n3 == 0, '密碼不一致仍建立帳號')
    check(h4.status_code == 200 and info == ('teacher', 'pending', '應用日語系', '山田老師'), '沒有建立待審核帳號')
    check('驗證連結不正確' in h5a and '請重新填寫申請表' in h5b, '失效的驗證連結未擋下')
    check('已經送出申請' in h6, '重複申請未擋下')


@case('A13', '老師帳號審核：等待審核、核准與拒絕',
      pre='山田老師的帳號待審核（上一個個案）；另有一位待審核的「鈴木老師」；佐藤老師已核准',
      steps='1. 山田老師用申請時的密碼登入，開啟班級管理頁\n2. 最高管理者於「老師帳號」頁核准山田老師\n3. 山田老師重新整理班級管理頁\n'
            '4. 最高管理者拒絕已核准的佐藤老師\n5. 最高管理者拒絕待審核的鈴木老師',
      expect='1. 登入成功但只能看到「等待審核」頁\n2. 核准成功、寫入操作日誌，並寄信通知老師\n3. 可以進入班級管理頁\n'
             '4. 提示只能拒絕待審核的帳號，帳號保留\n5. 申請被移除並寫入操作日誌',
      note='寄信以模擬方式攔截，未實際寄出')
def _(c):
    MAIL_FAKE['configured'] = True
    boss = super_client()
    yid = STATE['yamada']
    with S.app_context():
        s = User(email='suzuki@school.test', username='鈴木老師', account_type=AccountType.TEACHER, teacher_status='pending',
                 password_hash=generate_password_hash('Suzuki#2026a'))
        db.session.add(s)
        db.session.commit()
        sid = s.id
    web, r1 = teacher_web_login('yamada@school.test', 'Kaiwa#2026a')
    r1b = web.get('/teacher/classrooms')
    r1c = web.get('/teacher/pending')
    n_mail = len(SENT_MAIL)
    boss.post(f'/teacher_account/approve/{yid}')
    f2 = flashes(boss)
    mail = SENT_MAIL[-1] if len(SENT_MAIL) > n_mail else {}
    r3 = web.get('/teacher/classrooms')
    boss.post(f'/teacher_account/reject/{STATE["sato"]}')
    f4 = flashes(boss)
    boss.post(f'/teacher_account/reject/{sid}')
    f5 = flashes(boss)
    c.log(f'1. 登入 HTTP {r1.status_code}，班級頁 → {loc(r1b)}，等待頁 HTTP {r1c.status_code}；2. {f2}，通知信收件人={mail.get("to")}、主旨={mail.get("subject")}；'
          f'3. HTTP {r3.status_code}；4. {f4}，佐藤老師帳號 {count(User, id=STATE["sato"])} 個；5. {f5}，鈴木老師帳號 {count(User, id=sid)} 個、操作日誌 {logs("user", sid, "DELETE")} 筆')
    check(r1.status_code == 302 and r1b.status_code == 302 and 'pending' in loc(r1b) and r1c.status_code == 200, '待審核的老師可以使用後台')
    check('已核准「山田老師」的老師身分' in f2[0] and '已寄信通知老師' in f2[0] and mail.get('to') == 'yamada@school.test'
          and user_row(yid)['teacher_status'] == 'approved', '核准不正確')
    check(r3.status_code == 200, '核准後仍進不了班級管理')
    check('只能拒絕「待審核」的帳號' in f4[0] and count(User, id=STATE['sato']) == 1, '已核准的帳號被移除')
    check('已拒絕並移除「鈴木老師」' in f5[0] and count(User, id=sid) == 0 and logs('user', sid, 'DELETE') == 1, '拒絕申請不正確')


@case('A13', '老師用學校 Google 帳號登入後台',
      pre='老師後台限定學校網域 @school.test；App 一般使用者 gen@school.test；佐藤老師帳號已存在',
      steps='於登入頁「老師」分頁用 Google 登入：\n1. 沒有收到 Google 登入資料；Google 身分憑證無效\n2. 用一般 Gmail\n3. 用帳號是學號的 11156047@school.test\n'
            '4. 用已經是 App 一般帳號的 gen@school.test\n5. 第一次用 tanaka@school.test 登入\n6. 已有帳號的佐藤老師用 Google 登入\n7. 伺服器沒有設定 Google 登入時',
      expect='1. 分別提示沒有收到登入資料、驗證失敗\n2. 提示請使用學校配發的 Google 帳號\n3. 提示看起來是學生帳號，請改走申請表\n4. 提示已是 App 的一般使用者帳號\n'
             '5. 自動建立「待審核」的老師帳號，登入後只看到等待審核頁\n6. 直接登入並進入班級管理\n7. 提示尚未設定 Google 登入',
      note='Google 身分憑證驗證以模擬方式進行')
def _(c):
    with S.app_context():
        db.session.add(User(email='gen@school.test', username='一般使用者甲', account_type=AccountType.GENERAL,
                            password_hash=generate_password_hash('Pass1234')))
        db.session.commit()

    def fake_verify(credential):
        if credential.startswith('valid:'):
            email = credential.split(':', 1)[1]
            return {'email': email, 'email_verified': True, 'name': '田中老師' if email.startswith('tanaka') else ''}
        raise ValueError('bad token')

    go = lambda cred=None: (lambda cl: (cl, cl.post('/login/google', data={'credential': cred} if cred else {})))(A.test_client())
    with admin_settings(GOOGLE_WEB_CLIENT_ID='test-client-id', _verify_google_id_token=fake_verify,
                        TEACHER_GOOGLE_DOMAINS=['school.test'], TEACHER_GOOGLE_STUDENT_PATTERN=r'^\d+$',
                        TEACHER_GOOGLE_ALLOWED_EMAILS=set()):
        h1 = [html(go()[1]), html(go('garbage')[1])]
        h2 = html(go('valid:someone@gmail.com')[1])
        h3 = html(go('valid:11156047@school.test')[1])
        n3 = count(User, email='11156047@school.test')
        h4 = html(go('valid:gen@school.test')[1])
        web5, r5 = go('valid:tanaka@school.test')
        r5b = web5.get('/teacher/classrooms')
        with S.app_context():
            t = User.query.filter_by(email='tanaka@school.test').first()
            info = (t.account_type, t.teacher_status, t.username) if t else None
        web6, r6 = go('valid:sato@school.test')
        r6b = web6.get('/teacher/classrooms')
        r_get = A.test_client().get('/login/google')
    with admin_settings(GOOGLE_WEB_CLIENT_ID=''):
        h7 = html(go('valid:tanaka@school.test')[1])
    c.log(f'1. {["沒有收到 Google 登入資料" in h1[0], "Google 登入驗證失敗" in h1[1]]}；2. {"請使用學校配發的 Google 帳號" in h2}；3. {"看起來是學生帳號" in h3}，建立帳號 {n3} 個；'
          f'4. {"已是 App 的一般使用者帳號" in h4}；5. HTTP {r5.status_code}，帳號（類型, 審核, 姓名）={info}，班級頁 → {loc(r5b)}；'
          f'6. HTTP {r6.status_code} → {loc(r6)}，班級頁 HTTP {r6b.status_code}；7. {"尚未設定 Google 登入" in h7}；直接開網址 → {loc(r_get)}')
    check('沒有收到 Google 登入資料' in h1[0] and 'Google 登入驗證失敗' in h1[1], '無效的 Google 登入未擋下')
    check('請使用學校配發的 Google 帳號' in h2 and '看起來是學生帳號' in h3 and n3 == 0 and '已是 App 的一般使用者帳號' in h4,
          '不符資格的帳號未擋下')
    check(r5.status_code == 302 and info == ('teacher', 'pending', '田中老師') and 'pending' in loc(r5b), '第一次 Google 登入沒有建立待審核帳號')
    check(r6.status_code == 302 and 'classrooms' in loc(r6) and r6b.status_code == 200, '已核准的老師無法用 Google 登入')
    check('尚未設定 Google 登入' in h7 and r_get.status_code == 302 and 'login' in loc(r_get), '未設定 Google 登入時的處理不正確')


@case('A13', '老師建立班級與班級設定',
      pre='林老師已登入後台；學生丙（不在林老師的任何新班級）；陳老師為其他老師',
      steps='於「班級管理」頁：\n1. 建立班級但名稱空白\n2. 建立「四年戊班」\n3. 最高管理者建立班級\n4. 修改班級名稱為「四年戊班（日文）」與說明\n'
            '5. 關閉加入後學生丙用代碼加入；重新開放後再加入\n6. 重新產生班級代碼後，分別用舊、新代碼查詢\n'
            '7. 封存班級後學生丙查看我的教室；取消封存後再查看\n8. 陳老師修改這個班級',
      expect='1. 提示「請填寫班級名稱」\n2. 建立成功並產生班級代碼\n3. 提示管理者無法代替老師建立班級\n4. 更新成功，學生端看到新名稱\n'
             '5. 關閉時顯示已經關閉加入；開放後加入成功\n6. 舊代碼查不到、新代碼查得到\n7. 封存後學生看不到這個班級，取消封存後恢復\n8. 提示「找不到該班級」')
def _(c):
    k = ensure_class()
    web = teacher_client(k['teacher'], '林老師')
    post = lambda cl, url, **d: (cl.post(url, data=d), flashes(cl))[1]
    f1 = post(web, '/teacher/classroom/create', name='  ', description='')
    f2 = post(web, '/teacher/classroom/create', name='四年戊班', description='週五上課')
    with S.app_context():
        room = Classroom.query.filter_by(teacher_id=k['teacher'], name='四年戊班').first()
        rid, code = room.id, room.join_code
    boss = super_client()
    f3 = post(boss, '/teacher/classroom/create', name='管理者代建', description='')
    f4 = post(web, f'/teacher/classroom/{rid}/edit', name='四年戊班（日文）', description='改到週四上課')
    f5a = post(web, f'/teacher/classroom/{rid}/toggle_open')
    join = lambda cd: SC.post('/api/classroom/join', json={'user_id': k['s3'], 'join_code': cd})
    r5a = join(code)
    f5b = post(web, f'/teacher/classroom/{rid}/toggle_open')
    r5b = join(code)
    joined_name = (J(r5b).get('classroom') or {}).get('name')
    f6 = post(web, f'/teacher/classroom/{rid}/regenerate_code')
    with S.app_context():
        new_code = db.session.get(Classroom, rid).join_code
    r6a, r6b = SC.get(f'/api/classroom/preview?join_code={code}'), SC.get(f'/api/classroom/preview?join_code={new_code}')
    mine = lambda: [x['name'] for x in J(SC.get(f'/api/classroom/my/{k["s3"]}')).get('classrooms', [])]
    f7a = post(web, f'/teacher/classroom/{rid}/archive')
    mine7a = mine()
    f7b = post(web, f'/teacher/classroom/{rid}/archive')
    mine7b = mine()
    other = teacher_client(k['teacher2'], '陳老師')
    f8 = post(other, f'/teacher/classroom/{rid}/edit', name='被別人改', description='')
    STATE['room5'] = rid
    c.log(f'1. {f1}；2. {f2}；3. {f3}；4. {f4}；5. {f5a}，加入 {http(r5a, "status")}；{f5b}，加入 {http(r5b, "status")}（{joined_name}）；'
          f'6. {f6}，舊代碼 HTTP {r6a.status_code}、新代碼 HTTP {r6b.status_code}；7. {f7a}，學生看到={mine7a}；{f7b}，學生看到={mine7b}；8. {f8}')
    check(f1 == ['請填寫班級名稱'], '空白班級名稱未擋下')
    check(len(code or '') >= 6 and f'班級「四年戊班」建立成功！班級代碼為：{code}' == f2[0], '建立班級失敗')
    check('管理者無法代替老師建立班級' in f3[0] and count(Classroom, name='管理者代建') == 0, '管理者可以代建班級')
    check(f4 == ['班級「四年戊班（日文）」已更新'] and joined_name == '四年戊班（日文）', '修改班級失敗')
    check('關閉加入' in f5a[0] and r5a.status_code == 403 and J(r5a).get('status') == 'classroom_closed'
          and '開放加入' in f5b[0] and r5b.status_code == 201, '開關加入不正確')
    check(new_code != code and new_code in f6[0] and r6a.status_code == 404 and r6b.status_code == 200, '重新產生代碼不正確')
    check('已封存' in f7a[0] and '四年戊班（日文）' not in mine7a and '已取消封存' in f7b[0] and '四年戊班（日文）' in mine7b, '封存不正確')
    check(f8 == ['找不到該班級'], '別的老師可以修改班級')


@case('A13', '班級名冊：貼上名單建立學生帳號、改名與移出',
      pre='林老師的「四年戊班（日文）」目前只有學生丙；帳號 gen9001 已是一般版使用者',
      steps='於班級名冊頁：\n1. 沒貼名單就送出\n2. 貼上名單：「11156201 王小明」「11156202,李小華」「@@bad 格式錯誤」「gen9001 一般使用者」\n'
            '3. 再貼一次「11156201 王小明」\n4. 把 11156201 的顯示名稱改為「王小明（班長）」\n5. 把 11156202 移出班級\n6. 最高管理者貼名單',
      expect='1. 提示請貼上學生名單\n2. 建立 2 個學生帳號並加入班級（第一次登入須改密碼），畫面只顯示這一次的初始密碼；格式錯誤與已是一般版的帳號各有提示\n'
             '3. 提示 1 位原本就在班上，不重複建立\n4. 顯示名稱更新\n5. 移出班級並寫入操作日誌，學生帳號保留\n6. 提示管理者無法代替老師新增學生')
def _(c):
    k = ensure_class()
    rid = STATE['room5']
    with S.app_context():
        db.session.add(User(email='gen9001', username='一般使用者乙', account_type=AccountType.GENERAL,
                            password_hash=generate_password_hash('Pass1234')))
        db.session.commit()
    web = teacher_client(k['teacher'], '林老師')
    add_url = f'/teacher/classroom/{rid}/students/add'
    web.post(add_url, data={'roster': '  \n '})
    f1 = flashes(web)
    r2 = web.post(add_url, data={'roster': '11156201 王小明\n11156202,李小華\n@@bad 格式錯誤\ngen9001 一般使用者'})
    f2 = flashes(web)
    page2 = html(r2)
    with S.app_context():
        made = {u.email: (u.id, u.account_type, u.must_change_password) for u in
                User.query.filter(User.email.in_(['11156201', '11156202'])).all()}
        names = {m.student_id: m.display_name for m in ClassroomMember.query.filter_by(classroom_id=rid).all()}
    u1, u2 = made.get('11156201', (None,))[0], made.get('11156202', (None,))[0]
    web.post(add_url, data={'roster': '11156201 王小明'})
    f3 = flashes(web)
    web.post(f'/teacher/classroom/{rid}/student/{u1}/rename', data={'display_name': '王小明（班長）'})
    f4 = flashes(web)
    with S.app_context():
        new_name = ClassroomMember.query.filter_by(classroom_id=rid, student_id=u1).first().display_name
    web.post(f'/teacher/classroom/{rid}/student/{u2}/remove')
    f5 = flashes(web)
    boss = super_client()
    boss.post(add_url, data={'roster': '11156203 管理者代加'})
    f6 = flashes(boss)
    STATE['roster'] = (u1, u2)
    c.log(f'1. {f1}；2. 畫面提示（新建 2 個帳號, 一般版帳號無法加入, 格式錯誤）={["新建立 2 個學生帳號" in page2, "gen9001" in page2, "@@bad" in page2]}，帳號（類型, 需改密碼）={[v[1:] for v in made.values()]}，名冊顯示名稱={[names.get(u1), names.get(u2)]}，畫面有帳號與初始密碼區={"11156201" in page2}；'
          f'3. {f3}，帳號數 {count(User, email="11156201")}；4. {f4}，{new_name}；5. {f5}，成員紀錄 {count(ClassroomMember, classroom_id=rid, student_id=u2)} 筆、帳號 {count(User, id=u2)} 個；6. {f6}')
    check(f1 == ['請貼上學生名單，每行一位：學號 姓名'], '空白名單未擋下')
    check(r2.status_code == 200 and '新建立 2 個學生帳號' in page2 and 'gen9001' in page2 and '@@bad' in page2, '貼上名單的結果提示不正確')
    check(all(v[1:] == ('student', True) for v in made.values()) and len(made) == 2
          and (names.get(u1), names.get(u2)) == ('王小明', '李小華') and '11156201' in page2, '學生帳號或名冊不正確')
    check(any('1 位原本就在班上' in m for m in f3) and count(User, email='11156201') == 1, '重複貼名單不正確')
    check(f4 == ['學生顯示名稱已更新'] and new_name == '王小明（班長）', '修改顯示名稱失敗')
    check(f5 == ['已將「李小華」移出班級'] and count(ClassroomMember, classroom_id=rid, student_id=u2) == 0
          and count(User, id=u2) == 1 and logs('classroom_member', None, 'DELETE') >= 1, '移出學生不正確')
    check('管理者無法代替老師新增學生' in f6[0] and count(User, email='11156203') == 0, '管理者可以代加學生')


@case('A13', '老師重設學生密碼',
      pre='「四年戊班（日文）」有老師建立的學生 11156201（已登入 App）、用學校 Google 帳號登入的學生、以及一位一般版帳號的成員',
      steps='於班級名冊頁：\n1. 重設 11156201 的密碼\n2. 11156201 用重設前的通行證查個人檔案\n3. 重設用學校 Google 帳號登入的學生\n'
            '4. 重設一般版帳號的成員\n5. 陳老師重設 11156201 的密碼',
      expect='1. 重設成功，畫面顯示臨時密碼，學生下次登入須改密碼，並寫入操作日誌\n2. HTTP 401（已登入的裝置被登出）\n'
             '3. 提示用學校 Google 帳號登入、沒有密碼可以重設\n4. 提示這不是校園教育版的學生帳號\n5. 提示「找不到該學生」')
def _(c):
    k = ensure_class()
    rid = STATE['room5']
    u1, _u2 = STATE['roster']
    with S.app_context():
        google_stu = User.query.filter_by(email='11156001@tust.edu.tw').first().id
        general = User.query.filter_by(email='gen9001').first().id
        db.session.add_all([ClassroomMember(classroom_id=rid, student_id=google_stu, display_name='Google 學生'),
                            ClassroomMember(classroom_id=rid, student_id=general, display_name='一般帳號')])
        db.session.commit()
        old_hash = db.session.get(User, u1).password_hash
    old_token = auth_header(u1)
    web = teacher_client(k['teacher'], '林老師')
    reset = lambda cl, uid: (cl.post(f'/teacher/classroom/{rid}/student/{uid}/reset_password'), flashes(cl))
    r1, f1 = reset(web, u1)
    row = user_row(u1)
    r2 = SC.get(f'/api/user/profile_data/{u1}', headers=old_token)
    _r, f3 = reset(web, google_stu)
    _r, f4 = reset(web, general)
    _r, f5 = reset(teacher_client(k['teacher2'], '陳老師'), u1)
    c.log(f'1. HTTP {r1.status_code}，畫面顯示已重設={"已重設「王小明（班長）」的密碼" in html(r1)}，密碼已換={row["password_hash"] != old_hash}、需改密碼={row["must_change_password"]}、操作日誌 {logs("user", u1, "UPDATE")} 筆；'
          f'2. {http(r2, "error")}；3. {f3}；4. {f4}；5. {f5}')
    check(r1.status_code == 200 and '已重設「王小明（班長）」的密碼' in html(r1) and row['password_hash'] != old_hash
          and row['must_change_password'] is True and logs('user', u1, 'UPDATE') >= 1 and '11156201' in html(r1), '重設學生密碼不正確')
    check(r2.status_code == 401, '重設密碼後舊通行證仍可使用')
    check('沒有密碼可以重設' in f3[0] and '這不是校園教育版的學生帳號' in f4[0], '不能重設的帳號未擋下')
    check(f5 == ['找不到該學生'] and user_row(u1)['password_hash'] == row['password_hash'], '別的老師可以重設學生密碼')


@case('A13', '作業編輯、下架與刪除',
      pre='林老師的「三年丙班」有作業「第四課造句」（截止後不收）；學生甲在班上；另以測試資料讓學生甲已繳交「第三課造句」',
      steps='於作業列表：\n1. 編輯「第四課造句」但標題空白\n2. 把標題改為「第四課造句（修訂）」、遲交規則改為遲交扣 5 分\n3. 下架後學生甲查看我的作業，再重新發布\n'
            '4. 最高管理者編輯這份作業；陳老師下架這份作業\n5. 刪除已有 1 份繳交的「第三課造句」',
      expect='1. 提示「請填寫作業標題」\n2. 更新成功\n3. 下架後學生看不到，重新發布後恢復\n4. 分別提示管理者無法代替老師編輯作業、找不到該作業\n'
             '5. 作業與 1 份繳交紀錄一併刪除，並寫入操作日誌')
def _(c):
    k = ensure_class()
    aid = STATE['late_assignments']['reject']
    with S.app_context():
        third = Assignment.query.filter_by(classroom_id=k['room'], title='第三課造句').first().id
        db.session.add(AssignmentSubmission(assignment_id=third, student_id=k['s1'], status=SubmissionStatus.SUBMITTED,
                                            submitted_at=datetime.utcnow()))
        db.session.commit()
    web = teacher_client(k['teacher'], '林老師')
    post = lambda cl, url, **d: (cl.post(url, data=d), flashes(cl))[1]
    seen = lambda: [x['title'] for x in J(SC.get(f'/api/assignment/my/{k["s1"]}')).get('assignments', [])]
    f1 = post(web, f'/teacher/assignment/{aid}/edit', title=' ', is_published='on')
    f2 = post(web, f'/teacher/assignment/{aid}/edit', title='第四課造句（修訂）', instructions='請用兩種句型', is_published='on',
              late_policy='deduct', late_penalty='5')
    with S.app_context():
        a = db.session.get(Assignment, aid)
        edited = (a.title, a.late_policy, a.late_penalty)
    f3a = post(web, f'/teacher/assignment/{aid}/toggle_publish')
    seen3a = '第四課造句（修訂）' in seen()
    f3b = post(web, f'/teacher/assignment/{aid}/toggle_publish')
    seen3b = '第四課造句（修訂）' in seen()
    f4a = post(super_client(), f'/teacher/assignment/{aid}/edit', title='管理者改的', is_published='on')
    f4b = post(teacher_client(k['teacher2'], '陳老師'), f'/teacher/assignment/{aid}/toggle_publish')
    f5 = post(web, f'/teacher/assignment/{third}/delete')
    c.log(f'1. {f1}；2. {f2}，作業（標題, 遲交規則, 扣分）={edited}；3. {f3a}，學生看得到={seen3a}；重新發布後看得到={seen3b}；4. {f4a}；{f4b}；'
          f'5. {f5}，作業 {count(Assignment, id=third)} 份、繳交紀錄 {count(AssignmentSubmission, assignment_id=third)} 筆、操作日誌 {logs("assignment", third, "DELETE")} 筆')
    check(f1 == ['請填寫作業標題'], '空白標題未擋下')
    check(f2 == ['作業「第四課造句（修訂）」已更新'] and edited == ('第四課造句（修訂）', 'deduct', 5), '編輯作業失敗')
    check('已下架' in f3a[0] and not seen3a and '已發布' in f3b[0] and seen3b, '下架／發布不正確')
    check('管理者無法代替老師編輯作業' in f4a[0] and f4b == ['找不到該作業'], '沒有權限的人可以改作業')
    check('作業「第三課造句」已刪除，學生的 1 份繳交紀錄一併移除' == f5[0] and count(Assignment, id=third) == 0
          and count(AssignmentSubmission, assignment_id=third) == 0 and logs('assignment', third, 'DELETE') == 1, '刪除作業不正確')


@case('A13', '老師聯絡管理者',
      pre='還沒登入的老師；最高管理者已登入',
      steps='於登入頁點「聯絡管理者」：\n1. Email 格式錯誤；沒選問題類型；沒填內容\n2. 填 Email、類型「無法登入」與內容後送出\n3. 馬上再送一次\n4. 最高管理者開啟「意見回饋」頁',
      expect='1. 分別提示請輸入正確的 Email、請選擇問題類型、請說明遇到的問題\n2. 送出成功，存成一筆「老師聯絡：無法登入」的回饋\n3. 提示剛剛已經送出\n4. 管理者看得到這筆聯絡內容')
def _(c):
    web = A.test_client()
    good = {'email': 'kato@school.test', 'topic': '無法登入', 'content': '用學校 Google 帳號登入一直失敗'}
    send = lambda **d: html(web.post('/teacher/contact', data=d))
    h1 = [send(**dict(good, email='kato')), send(**dict(good, topic='亂填')), send(**dict(good, content=''))]
    n1 = count(Feedback, email='kato@school.test')
    r_form = web.get('/teacher/contact?topic=忘記密碼')
    send(**good)
    with S.app_context():
        fb = Feedback.query.filter_by(email='kato@school.test').first()
        info = (fb.feedback_type, fb.content, fb.user_id) if fb else None
    h3 = send(**good)
    page = html(super_client().get('/feedback/list'))
    c.log(f'1. {["請輸入正確的 Email" in h1[0], "請選擇問題類型" in h1[1], "請說明遇到的問題" in h1[2]]}，回饋 {n1} 筆；表單頁 HTTP {r_form.status_code}；'
          f'2. 回饋（類型, 內容, 使用者）={info}；3. 提示剛剛已經送出={"剛剛已經送出" in h3}，回饋 {count(Feedback, email="kato@school.test")} 筆；'
          f'4. 管理者看得到={"用學校 Google 帳號登入一直失敗" in page}')
    check('請輸入正確的 Email' in h1[0] and '請選擇問題類型' in h1[1] and '請說明遇到的問題' in h1[2] and n1 == 0 and r_form.status_code == 200,
          '不合格的聯絡內容未擋下')
    check(info == ('老師聯絡：無法登入', '用學校 Google 帳號登入一直失敗', None), '聯絡內容沒有存成回饋')
    check('剛剛已經送出' in h3 and count(Feedback, email='kato@school.test') == 1, '可以連續送出')
    check('用學校 Google 帳號登入一直失敗' in page, '管理者看不到老師的聯絡內容')


# ----------------------------------------------------------------------
# A13 校園教育版：老師忘記密碼（管理者寄重設連結，老師自己設定新密碼）
# ----------------------------------------------------------------------
def new_teacher(email, name, password='Old@Pass1'):
    with S.app_context():
        t = User(email=email, username=name, account_type=AccountType.TEACHER,
                 password_hash=generate_password_hash(password))
        db.session.add(t)
        db.session.commit()
        return t.id


def last_reset_link(email):
    """信裡的重設連結（只取路徑與參數）"""
    for m in reversed(SENT_MAIL):
        if m['to'] == email:
            found = re.search(r'https?://[^/\s]+(/teacher/reset_password\?token=\S+)', m['body'])
            return found.group(1) if found else None
    return None


def teacher_login(email, password):
    return A.test_client().post('/login', data={'login_as': 'teacher', 'email': email, 'password': password})


@case('A13', '管理者寄重設連結，老師自己設定新密碼',
      pre='老師帳號「吳老師」（wu@school.edu.tw）密碼為 Old@Pass1；寄信服務已設定',
      steps='1. 一般管理者對吳老師送出重設密碼\n2. 最高管理者送出重設密碼並自行指定 password=Hack@1234\n3. 老師開啟信中連結\n'
            '4. 送出兩次不一致的密碼、強度不足的密碼\n5. 送出新密碼 New@Pass2\n6. 再次開啟同一個連結\n7. 分別以舊密碼、新密碼登入老師後台',
      expect='1. 被擋下，不寄信\n2. 提示已寄出重設連結，信寄到老師信箱；密碼不變（指定的密碼不被採用）\n3. 顯示設定新密碼頁\n'
             '4. 分別提示「兩次輸入的密碼不一致」與密碼強度不足，密碼不變\n5. 顯示「密碼已更新」，不需要再強制改密碼，寫入操作日誌\n'
             '6. 提示連結已經使用過或已失效\n7. 舊密碼登入失敗，新密碼登入成功')
def _(c):
    email = 'wu@school.edu.tw'
    tid = new_teacher(email, '吳老師')
    url = f'/teacher_account/reset_password/{tid}'
    n_mail = len(SENT_MAIL)
    r1 = admin_client('sys_staff', 'Staff@1234').post(url, data={'mode': 'link'})
    mail1 = len(SENT_MAIL) - n_mail
    boss = admin_client('sys_super', 'Admin@1234')
    r2 = boss.post(url, data={'mode': 'link', 'password': 'Hack@1234'})
    f2 = flashes(boss)
    link = last_reset_link(email)
    hash2 = user_row(tid)['password_hash']
    web = A.test_client()
    r3 = web.get(link)
    token = parse_qs(link.split('?', 1)[1])['token'][0]
    r4a = web.post('/teacher/reset_password', data={'token': token, 'password': 'New@Pass2', 'confirm_password': 'New@Pass3'})
    r4b = web.post('/teacher/reset_password', data={'token': token, 'password': 'abcdefgh', 'confirm_password': 'abcdefgh'})
    hash4 = user_row(tid)['password_hash']
    r5 = web.post('/teacher/reset_password', data={'token': token, 'password': 'New@Pass2', 'confirm_password': 'New@Pass2'})
    row5 = user_row(tid)
    with S.app_context():
        logs = [l.new_value for l in SystemLog.query.filter_by(target_table='user', target_id=tid).order_by(SystemLog.id).all()]
    r6 = web.get(link)
    r7a = teacher_login(email, 'Old@Pass1')
    r7b = teacher_login(email, 'New@Pass2')
    c.log(f'1. HTTP {r1.status_code}，寄出 {mail1} 封；2. 提示={f2}，信中有連結={bool(link)}，Hack@1234 可登入={check_password_hash(hash2, "Hack@1234")}；'
          f'3. HTTP {r3.status_code}，設定新密碼頁={"設定新密碼" in html(r3)}；'
          f'4. 不一致={"兩次輸入的密碼不一致" in html(r4a)}、強度不足仍停在設定頁={"error-box" in html(r4b)}，密碼不變={hash4 == hash2}；'
          f'5. 密碼已更新={"密碼已更新" in html(r5)}，must_change_password={row5["must_change_password"]}，操作日誌={logs}；'
          f'6. 已失效={"已經使用過或已失效" in html(r6)}；7. 舊密碼 HTTP {r7a.status_code}、新密碼 HTTP {r7b.status_code} → {loc(r7b)}')
    check(mail1 == 0 and r1.status_code in (302, 403), '一般管理者可以重設老師密碼')
    check(len(f2) == 1 and email in f2[0] and link, '沒有寄出重設連結')
    check(check_password_hash(hash2, 'Old@Pass1') and not check_password_hash(hash2, 'Hack@1234'), '管理者可以自行指定老師密碼')
    check(r3.status_code == 200 and '設定新密碼' in html(r3), '重設連結打不開')
    check('兩次輸入的密碼不一致' in html(r4a) and 'error-box' in html(r4b) and hash4 == hash2, '不合格的密碼未擋下')
    check('密碼已更新' in html(r5) and check_password_hash(row5['password_hash'], 'New@Pass2')
          and not row5['must_change_password'], '新密碼沒有生效')
    check(logs == [{'password_reset': 'link_sent'}, {'password': 'reset_by_link'}], '操作日誌不正確')
    check('已經使用過或已失效' in html(r6), '用過的連結仍可使用')
    check(r7a.status_code == 200 and 'Email 或密碼錯誤' in html(r7a), '舊密碼仍可登入')
    check(r7b.status_code == 302 and loc(r7b).endswith('/teacher/classrooms'), '新密碼無法登入')


@case('A13', '重設連結逾時、遭竄改，與老師收不到信時改發臨時密碼',
      pre='老師帳號「鄭老師」（cheng@school.edu.tw）密碼為 Old@Pass1',
      steps='1. 開啟 31 分鐘前寄出的重設連結\n2. 開啟內容被改過的連結\n3. 寄信服務未設定時，最高管理者寄重設連結\n'
            '4. 最高管理者先寄出重設連結，再改為產生臨時密碼\n5. 老師開啟步驟 4 的重設連結\n6. 老師以臨時密碼登入',
      expect='1. 提示連結已超過 30 分鐘\n2. 提示連結不正確\n3. 提示寄信服務尚未設定，密碼不變\n'
             '4. 畫面顯示系統產生的 8 碼臨時密碼，原密碼失效\n5. 提示連結已經使用過或已失效\n6. 登入後被導向個人資料頁，要求先改密碼')
def _(c):
    email = 'cheng@school.edu.tw'
    tid = new_teacher(email, '鄭老師')
    url = f'/teacher_account/reset_password/{tid}'
    boss = admin_client('sys_super', 'Admin@1234')
    web = A.test_client()

    # 模擬 31 分鐘前寄出的連結：只把簽發時間往前調（不能連管理者的操作一起調，登入狀態也會跟著失效）
    original = _its_timed.TimestampSigner.get_timestamp
    _its_timed.TimestampSigner.get_timestamp = lambda self: int(time.time() - 31 * 60)
    try:
        with A.app_context():
            old_token = admin_module._teacher_reset_token(db.session.get(User, tid))
    finally:
        _its_timed.TimestampSigner.get_timestamp = original
    r1 = web.get('/teacher/reset_password?token=' + old_token)
    boss.post(url, data={'mode': 'link'})
    flashes(boss)
    r2 = web.get('/teacher/reset_password?token=' + 'x' + last_reset_link(email).split('token=', 1)[1])

    MAIL_FAKE['configured'] = False
    try:
        boss.post(url, data={'mode': 'link'})
    finally:
        MAIL_FAKE['configured'] = True
    f3 = flashes(boss)
    hash3 = user_row(tid)['password_hash']

    boss.post(url, data={'mode': 'link'})
    flashes(boss)
    link4 = last_reset_link(email)
    r4 = boss.post(url, data={'mode': 'temp'})
    found = re.search(r'<code>([a-z0-9]{8})</code>', html(r4))
    temp = found.group(1) if found else None
    row4 = user_row(tid)
    r5 = web.get(link4)
    r6 = teacher_login(email, temp or '')
    c.log(f'1. 逾時={"已超過 30 分鐘" in html(r1)}；2. 不正確={"重設連結不正確" in html(r2)}；3. 提示={f3}，密碼不變={check_password_hash(hash3, "Old@Pass1")}；'
          f'4. HTTP {r4.status_code}，畫面有臨時密碼={bool(temp)}，原密碼可用={check_password_hash(row4["password_hash"], "Old@Pass1")}，'
          f'must_change_password={row4["must_change_password"]}；5. 已失效={"已經使用過或已失效" in html(r5)}；6. HTTP {r6.status_code} → {loc(r6)}')
    check('已超過 30 分鐘' in html(r1), '逾時的連結仍可使用')
    check('重設連結不正確' in html(r2), '被竄改的連結仍可使用')
    check(len(f3) == 1 and '寄信服務尚未設定' in f3[0] and check_password_hash(hash3, 'Old@Pass1'), '寄信服務未設定時處理不正確')
    check(r4.status_code == 200 and temp and check_password_hash(row4['password_hash'], temp)
          and not check_password_hash(row4['password_hash'], 'Old@Pass1') and row4['must_change_password'], '臨時密碼不正確')
    check('已經使用過或已失效' in html(r5), '改發臨時密碼後舊連結仍可使用')
    check(r6.status_code == 302 and loc(r6).endswith('/teacher/profile'), '臨時密碼登入後沒有要求改密碼')


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
