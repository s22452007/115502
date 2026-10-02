"""App 的登入通行證（後端簽發的身分憑證）。

原本 App 每次呼叫 API 只附上 user_id，後端直接相信，任何人改個號碼就能操作別人的帳號。
現在登入成功時發一張通行證，之後每次呼叫都要在 Authorization 標頭帶上：
    Authorization: Bearer <通行證>

- 通行證用伺服器的密鑰簽名，內容是 {uid, v}，別人無法偽造或竄改。
- 有效期 30 天；有在使用就自動延長（超過 1 天的通行證，回應會附上新的 X-Auth-Token）。
- 改密碼或重設密碼時 user.token_version + 1，舊通行證立刻失效；帳號被停用時直接拒絕。
"""
import os
import secrets
from datetime import timedelta

from flask import g, jsonify, request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

TOKEN_MAX_AGE = timedelta(days=30)   # 通行證有效期
RENEW_AFTER = timedelta(days=1)      # 通行證用超過這麼久，就在回應附上新的一張（有在用就不會過期）
HEADER_RENEWED = 'X-Auth-Token'
HEADER_AUTH_ERROR = 'X-Auth-Error'

# 不需要登入就能呼叫的 API（登入註冊本身、不含個人資料的公開清單）
PUBLIC_ENDPOINTS = {
    ('POST', '/api/auth/register'),
    ('POST', '/api/auth/login'),
    ('POST', '/api/auth/google_login'),
    ('POST', '/api/auth/forgot_password'),
    ('POST', '/api/auth/reset_password'),
    ('GET', '/api/store/packages'),
    ('GET', '/api/store/items'),
    ('GET', '/api/subscription/plans'),
    ('GET', '/api/dialect/list'),
    ('GET', '/api/quiz/questions'),
    ('GET', '/api/scenario/scenes'),
}

# 請求裡代表「操作者本人」的欄位：只要有帶，就必須等於通行證上的人
IDENTITY_FIELDS = ('user_id', 'sender_id')

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_serializer = None


def _secret_key():
    """優先用 .env 的 SECRET_KEY；沒設定就自動產生一組存在 instance/，重啟後不會變。"""
    key = (os.getenv('SECRET_KEY') or '').strip()
    if key:
        return key
    path = os.path.join(_BASE_DIR, 'instance', 'auth_secret.key')
    try:
        with open(path, encoding='utf-8') as f:
            key = f.read().strip()
    except FileNotFoundError:
        key = ''
    if not key:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        key = secrets.token_hex(32)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(key)
    return key


def _get_serializer():
    global _serializer
    if _serializer is None:
        _serializer = URLSafeTimedSerializer(_secret_key(), salt='snaptolearn-app-auth')
    return _serializer


def issue_token(user):
    """簽發通行證（登入、註冊、Google 登入成功時呼叫）"""
    return _get_serializer().dumps({'uid': user.id, 'v': user.token_version or 0})


def current_user_id():
    """這次請求的通行證主人（只在需要登入的 API 內有值）"""
    return getattr(g, 'auth_user_id', None)


def _deny(message, status, code):
    # 原因代碼同時放在標頭，App 不用讀內容就能判斷要不要登出（被停用、通行證失效）
    response = jsonify({'error': message, 'auth_error': code})
    response.status_code = status
    response.headers[HEADER_AUTH_ERROR] = code
    return response


def _request_identities():
    """收集請求裡所有代表操作者本人的值（網址、查詢字串、表單、JSON）"""
    values = []
    for field in IDENTITY_FIELDS:
        if request.view_args and field in request.view_args:
            values.append(request.view_args[field])
        if field in request.args:
            values.append(request.args.get(field))
        if request.form and field in request.form:
            values.append(request.form.get(field))
    data = request.get_json(silent=True)
    if isinstance(data, dict):
        for field in IDENTITY_FIELDS:
            if field in data and data[field] not in (None, ''):
                values.append(data[field])
    return values


def check_request():
    """給 app.before_request 用：驗證通行證並確認操作的是本人。回傳 None 表示放行。"""
    if request.method == 'OPTIONS' or not request.path.startswith('/api/'):
        return None
    if (request.method, request.path) in PUBLIC_ENDPOINTS:
        return None

    header = request.headers.get('Authorization', '')
    if not header.startswith('Bearer '):
        return _deny('請先登入', 401, 'login_required')
    try:
        payload, issued_at = _get_serializer().loads(
            header[7:].strip(), max_age=int(TOKEN_MAX_AGE.total_seconds()), return_timestamp=True)
    except SignatureExpired:
        return _deny('登入已過期，請重新登入', 401, 'token_expired')
    except BadSignature:
        return _deny('登入狀態無效，請重新登入', 401, 'token_invalid')

    from models import User
    user = User.query.get(payload.get('uid'))
    if user is None or (user.token_version or 0) != payload.get('v'):
        return _deny('登入已失效，請重新登入', 401, 'token_revoked')
    if getattr(user, 'is_suspended', False):
        return _deny('此帳號已被停用，請聯繫客服', 403, 'suspended')

    for value in _request_identities():
        try:
            same = int(value) == user.id
        except (TypeError, ValueError):
            same = False
        if not same:
            return _deny('不能操作其他使用者的資料', 403, 'forbidden')

    g.auth_user_id = user.id
    # 有在使用就自動延長：通行證用超過 RENEW_AFTER，就在這次回應附上新的一張
    from datetime import datetime, timezone
    if datetime.now(timezone.utc) - issued_at > RENEW_AFTER:
        g.renewed_token = issue_token(user)
    return None


def attach_renewed_token(response):
    """給 app.after_request 用：把延長後的新通行證放進回應標頭"""
    token = getattr(g, 'renewed_token', None)
    if token:
        response.headers[HEADER_RENEWED] = token
    return response


def forbid_unless_owner(owner_id):
    """物件不屬於通行證主人時回傳 403 回應，屬於則回傳 None"""
    if owner_id is None or owner_id != current_user_id():
        return _deny('不能操作其他使用者的資料', 403, 'forbidden')
    return None
