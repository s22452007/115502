"""手機推播（Firebase Cloud Messaging）：老師發公告、出作業、批改完成時通知學生。

金鑰：Firebase 主控台 →「專案設定」→「服務帳戶」→「產生新的私密金鑰」，
存成 backend/secrets/firebase-service-account.json（.env 的 FIREBASE_CREDENTIALS 可改路徑）。
secrets/ 不進 git、不打包進 Docker 映像，由 docker-compose 掛載進容器。

沒有金鑰或沒裝 firebase-admin 時整個略過、不丟例外：組員電腦和測試環境不用設定也能跑，
學生照樣能靠 App 裡的紅點看到新公告。

推播在背景執行緒送出，老師按下發布不用等 Google 回應；
送不到的 token（App 被移除、重灌）會順手從 user.push_token 清掉。
"""
import os
import threading

from flask import current_app

from utils.db import db

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DEFAULT_CREDENTIALS = os.path.join(BASE_DIR, 'secrets', 'firebase-service-account.json')
# App 端建立的通知頻道（Android 8 以上用來分類、讓使用者個別關閉）
ANDROID_CHANNEL_ID = 'jpn_classroom_channel'
# 測試時改成 False，讓推播在同一個執行緒送完再檢查結果
RUN_IN_BACKGROUND = True

_firebase_app = None
_disabled_reason = None


def _firebase_ready():
    """第一次用到時才初始化 Firebase；失敗就記住原因，之後不再嘗試。"""
    global _firebase_app, _disabled_reason
    if _firebase_app is not None:
        return True
    if _disabled_reason:
        return False
    path = os.getenv('FIREBASE_CREDENTIALS') or DEFAULT_CREDENTIALS
    if not os.path.isabs(path):
        path = os.path.join(BASE_DIR, path)
    if not os.path.isfile(path):
        _disabled_reason = f'找不到金鑰 {path}'
    else:
        try:
            import firebase_admin
            from firebase_admin import credentials
            _firebase_app = firebase_admin.initialize_app(credentials.Certificate(path), name='jlens-push')
        except Exception as e:   # 沒裝套件、金鑰格式錯誤
            _disabled_reason = f'初始化失敗：{e}'
    if _disabled_reason:
        print(f'[推播] 未啟用（{_disabled_reason}），學生仍可在 App 內看到紅點')
        return False
    print('[推播] Firebase 已啟用')
    return True


def _send_multicast(tokens, title, body, data):
    """真的送到 FCM，一次最多 500 支手機。回傳送不到、應該清掉的 token。"""
    from firebase_admin import messaging
    dead = []
    for i in range(0, len(tokens), 500):
        chunk = tokens[i:i + 500]
        message = messaging.MulticastMessage(
            tokens=chunk,
            notification=messaging.Notification(title=title, body=body),
            data=data,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(channel_id=ANDROID_CHANNEL_ID),
            ),
        )
        response = messaging.send_each_for_multicast(message, app=_firebase_app)
        for token, r in zip(chunk, response.responses):
            # 只有「這支手機已經收不到」才清掉。其他錯誤（網路、訊息格式）可能每支都一樣，
            # 清掉會讓全班都收不到，所以不動，下次再試
            if not r.success and isinstance(r.exception, (messaging.UnregisteredError, messaging.SenderIdMismatchError)):
                dead.append(token)
    return dead


def _deliver(app, tokens, title, body, data):
    try:
        dead = _send_multicast(tokens, title, body, data)
    except Exception as e:
        print(f'[推播] 送出失敗（不影響其他功能）：{e}')
        return
    if dead:
        from models import User
        with app.app_context():
            User.query.filter(User.push_token.in_(dead)).update({'push_token': None}, synchronize_session=False)
            db.session.commit()


def notify_users(user_ids, title, body, data=None):
    """推播給這些使用者；沒登記手機的人略過。回傳實際送出的手機數（背景送出時是排進去的數量）。"""
    from models import User
    ids = [i for i in set(user_ids or []) if i]
    if not ids or not _firebase_ready():
        return 0
    tokens = [t for (t,) in db.session.query(User.push_token)
              .filter(User.id.in_(ids), User.push_token.isnot(None), User.push_token != '').all()]
    if not tokens:
        return 0
    # FCM 的 data 只收字串
    payload = {k: '' if v is None else str(v) for k, v in (data or {}).items()}
    title, body = (title or '')[:100], (body or '')[:200]
    app = current_app._get_current_object()
    if RUN_IN_BACKGROUND:
        threading.Thread(target=_deliver, args=(app, tokens, title, body, payload), daemon=True).start()
    else:
        _deliver(app, tokens, title, body, payload)
    return len(tokens)


def notify_classroom(classroom_id, title, body, data=None):
    """推播給班上所有學生。"""
    from models import ClassroomMember
    ids = [m.student_id for m in ClassroomMember.query.filter_by(classroom_id=classroom_id).all()]
    return notify_users(ids, title, body, data)
