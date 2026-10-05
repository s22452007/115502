# 1. Python 內建標準庫
import os
import re
from datetime import date, datetime, timedelta

# 2. 第三方套件 (Third-Party)
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash

# 3. 本地端模組 (Local)
from utils.db import db
from utils.auth_helper import generate_friend_id, is_valid_email, default_username
from utils.subscription_helper import check_and_expire_subscription
from utils.group_helper import add_group_progress_and_check_reward
from utils.auth_token import issue_token, current_user_id
from utils import password_policy
from models import (
    User, UserAchievement, Achievement,
    UserVocab, UserFolder, FriendRequest, Friendship,
    StudyGroup, GroupMember, GroupInvite, AccountType, School, SystemLog
)

# 建立 auth 的 Blueprint
auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    email = (data.get('email') or '').strip()
    password = data.get('password')

    if not email or not password:
        return jsonify({"error": "請填寫 Email 與密碼"}), 400
    if not is_valid_email(email):
        return jsonify({"error": "請輸入正確的 Email（例如 name@gmail.com）"}), 400

    # 檢查是否已經被註冊過
    if User.query.filter_by(email=email).first():
        return jsonify({"error": "這個 Email 已經註冊過囉！"}), 400

    # 自行註冊只能建立一般版帳號：
    #   - 'teacher' 必須由後台建立，否則任何人都能把自己變成老師去建教室、看學生資料
    #   - 'student' 只能用學校 Google 帳號登入（/edu_google_login，檢查學校網域與學號），
    #     或由老師在後台班級名冊建立（帳號是學號、初始密碼隨機），不能在這裡自己註冊
    account_type = (data.get('account_type') or AccountType.GENERAL).strip().lower()
    if account_type == AccountType.STUDENT:
        return jsonify({"error": "校園教育版帳號由老師建立，請向老師確認你的帳號"}), 403
    if account_type != AccountType.GENERAL:
        return jsonify({"error": "帳號類型不正確"}), 400

    # 一般使用者自行設定的密碼：8 個字元以上即可（強度只是參考）
    pw_error = password_policy.validate(password, account=email)
    if pw_error:
        return jsonify({"error": pw_error}), 400

    # 將密碼加密後，存入資料庫
    hashed_pw = generate_password_hash(password)

    # 在建立新使用者時，給他一組隨機交友 ID
    new_friend_id = generate_friend_id()
    new_user = User(
        email=email,
        username=default_username(email),   # 預設暱稱＝Email @ 前面那段，之後可以在個人檔案改
        password_hash=hashed_pw,
        friend_id=new_friend_id,
        account_type=account_type,
        # 註冊完直接進 App、不會再經過 /login，所以註冊當天就算第 1 天登入，
        # 否則首頁會顯示「已連續登入 0 天」，要等明天再登入才變 1 天
        streak_days=1,
        total_active_days=1,
        last_login_date=date.today(),
        last_scan_date=date.today(),
        last_seen_at=datetime.utcnow(),
    )

    db.session.add(new_user)
    db.session.commit()

    return jsonify({
        "message": "註冊成功！",
        "token": issue_token(new_user),   # 登入通行證：之後呼叫 API 都要帶在 Authorization 標頭
        "user_id": new_user.id,
        "email": new_user.email,
        "username": new_user.username,
        "streak_days": new_user.streak_days,
        "friend_id": new_friend_id,
        "account_type": account_type,
    }), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    print("=== [DEBUG] login ===")
    print("收到 email:", repr(email))
    print("收到 password 長度:", len(password) if password else 0)

    # 一般版入口一定要用 Email 登入（校園教育版學生用學號，不在此限）
    if (data.get('portal') or '').strip().lower() == 'general' and not is_valid_email((email or '').strip()):
        return jsonify({"error": "請輸入正確的 Email（例如 name@gmail.com）"}), 400

    user = User.query.filter_by(email=email).first()

    print("查到 user:", user)
    print("user.id:", user.id if user else None)
    print("user.password_hash 前20碼:", user.password_hash[:20] if user else None)

    if not user:
        return jsonify({"error": "尚未註冊過"}), 401

    if getattr(user, 'is_suspended', False):
        return jsonify({"error": "此帳號已被停用，請聯繫客服"}), 403

    pw_match = (check_password_hash(user.password_hash, password)
                and not password_policy.is_google_placeholder_input(password, user.email))
    print("密碼比對結果:", pw_match)
    print("=== [DEBUG end] ===")

    # 如果帳號密碼正確
    if pw_match:

        # 登入入口分流：校園教育版入口只收學生帳號，一般版入口只收一般帳號。
        # 放在密碼驗證之後，避免用錯誤密碼就能試出某個帳號是哪一種類型。
        # portal 沒帶時不檢查，保留給舊版前端與其他呼叫端。
        portal = (data.get('portal') or '').strip().lower()
        account_type = getattr(user, 'account_type', None) or AccountType.GENERAL
        if portal == 'edu' and account_type != AccountType.STUDENT:
            return jsonify({
                "status": "wrong_portal",
                "error": "這不是校園教育版的學生帳號，請改從「一般自主學習」登入",
            }), 403
        if portal == 'general' and account_type != AccountType.GENERAL:
            return jsonify({
                "status": "wrong_portal",
                "error": ("這是校園教育版的學生帳號，請改從「校園教育版」登入"
                          if account_type == AccountType.STUDENT
                          else "這個帳號不能從一般版登入"),
            }), 403

        # 防呆：如果舊玩家沒有 friend_id，就在登入時幫他補發一個
        if not user.friend_id:
            user.friend_id = generate_friend_id()
            db.session.commit()
        # 舊帳號沒有暱稱時補一個（Email @ 前面那段），各畫面才不會顯示「使用者」
        if not user.username:
            user.username = default_username(user.email)
            db.session.commit()

        # ----- 登入天數與任務重置邏輯 -----
        today = date.today()
        
        # 先用一個變數記錄「這是不是他今天第一次登入？」
        is_first_login_today = (user.last_login_date != today)
        
        if is_first_login_today:
            # 1. 算個人的馬拉松與連勝天數
            user.total_active_days = (user.total_active_days or 0) + 1

            if user.last_login_date == today - timedelta(days=1):
                user.streak_days = (user.streak_days or 0) + 1
            else:
                user.streak_days = 1

            # 2. 算小組的貢獻 (確保一天只能加一次！)
            member_record = GroupMember.query.filter_by(user_id=user.id).first()
            if member_record:
                member_record.group_logins = (member_record.group_logins or 0) + 1

                # 小組總進度統一交給 group_helper 處理，它會自己判斷這個小組的
                # 目標類型是不是 'logins'，不是就不動。
                #
                # 這裡原本自己重寫了一套：只在 goal_type 是 'logins' / 'scans' 時
                # 才算出 total，卻無條件執行 group.current_progress = total，
                # 所以目標是 'sentences' 或 'articles' 的小組，成員一登入就會
                # 噴 UnboundLocalError 讓 /api/auth/login 回 500。
                # 而且它先把進度覆寫成總和、後面又額外 +1，等於重複累加。
                add_group_progress_and_check_reward(user.id, 'logins')


        # 不管是不是第一次登入，都要更新最後上線時間
        user.last_login_date = today
        user.last_seen_at = datetime.utcnow()

        # 檢查並重置今日拍照次數
        if user.last_scan_date != today:
            user.daily_scans = 0
            user.last_scan_date = today

        db.session.commit()

        # 登入時同步訂閱過期狀態
        check_and_expire_subscription(user)

        end_date = getattr(user, 'subscription_end_date', None)
        return jsonify({
            "message": "登入成功！",
            "token": issue_token(user),   # 登入通行證：之後呼叫 API 都要帶在 Authorization 標頭
            "user_id": user.id,
            "email": user.email,
            "japanese_level": user.japanese_level,
            "avatar": user.avatar,
            "streak_days": user.streak_days,
            "j_pts": user.j_pts,
            "daily_scans": user.daily_scans,
            "friend_id": user.friend_id,
            "username": user.username,
            "is_premium": bool(getattr(user, 'is_premium', False)),
            # 前端靠這個欄位決定進一般版還是校園教育版
            "account_type": getattr(user, 'account_type', 'general'),
            # 老師建立的學生帳號（初始密碼是老師拿到的臨時密碼）或被重設過密碼：App 要先帶去改密碼
            "must_change_password": bool(getattr(user, 'must_change_password', False)),
            "subscription_end_date": end_date.isoformat() if end_date else None,
            "auto_renew": bool(getattr(user, 'auto_renew', False)),
        }), 200
    else:
        return jsonify({"error": "Email 或密碼錯誤"}), 401
    
# ==========================================
# 忘記密碼：先寄驗證碼到信箱，再用驗證碼設定新密碼
# ==========================================
# 原本 /reset_password 只要知道 Email 就能直接改密碼，等於任何人都能盜用一般帳號。
RESET_CODE_TTL = timedelta(minutes=10)      # 驗證碼有效時間
RESET_CODE_COOLDOWN = timedelta(seconds=60)  # 同一個帳號重寄的間隔
RESET_CODE_MAX_ATTEMPTS = 5                  # 同一組驗證碼最多可以輸錯幾次


def _reset_target(email):
    """找出可以在 App 重設密碼的帳號；不行時回傳 (None, 錯誤回應)。"""
    user = User.query.filter_by(email=email).first()
    if not user:
        return None, (jsonify({"error": "找不到此 Email，請確認是否輸入正確"}), 404)
    # 老師帳號同時是後台登入帳號、學生帳號就是學號（沒有真正的信箱），
    # 都不開放在 App 重設，改由老師在班級名冊、或 super_admin 在教師帳號管理重設。
    account_type = getattr(user, 'account_type', None) or AccountType.GENERAL
    if account_type == AccountType.STUDENT:
        return None, (jsonify({"error": "校園教育版帳號無法在這裡重設密碼，請老師在班級名冊幫你重設"}), 403)
    if account_type != AccountType.GENERAL:
        return None, (jsonify({"error": "這個帳號無法在 App 重設密碼，請聯繫系統管理員"}), 403)
    return user, None


@auth_bp.route('/forgot_password', methods=['POST'])
def forgot_password():
    """寄出 6 位數驗證碼到使用者的信箱"""
    import secrets
    from models import PasswordResetCode
    from utils import mailer

    data = request.get_json() or {}
    email = (data.get('email') or '').strip()
    if not email:
        return jsonify({"error": "請輸入註冊的 Email"}), 400

    user, err = _reset_target(email)
    if err:
        return err

    now = datetime.utcnow()
    last = (PasswordResetCode.query.filter_by(user_id=user.id)
            .order_by(PasswordResetCode.created_at.desc()).first())
    if last and last.created_at and now - last.created_at < RESET_CODE_COOLDOWN:
        wait = int((RESET_CODE_COOLDOWN - (now - last.created_at)).total_seconds()) + 1
        return jsonify({"error": f"驗證碼剛寄出，請 {wait} 秒後再試", "retry_after": wait}), 429

    if not mailer.is_configured():
        return jsonify({"error": "寄信服務尚未設定，請聯繫系統管理員"}), 503

    code = f"{secrets.randbelow(1000000):06d}"
    # 新驗證碼寄出後，舊的一律作廢，只有最新一封信裡的驗證碼有效
    PasswordResetCode.query.filter_by(user_id=user.id, used_at=None).update(
        {'used_at': now}, synchronize_session=False)
    record = PasswordResetCode(user_id=user.id, code_hash=generate_password_hash(code),
                               expires_at=now + RESET_CODE_TTL, created_at=now)
    db.session.add(record)

    minutes = int(RESET_CODE_TTL.total_seconds() // 60)
    try:
        mailer.send_mail(
            user.email,
            'SNAP TO LEARN 密碼重設驗證碼',
            f'你好：\n\n你的密碼重設驗證碼是 {code}，{minutes} 分鐘內有效。\n\n'
            f'如果不是你本人申請，請忽略這封信，你的密碼不會被更改。\n\nSNAP TO LEARN',
        )
    except Exception as e:
        db.session.rollback()
        print(f"⚠️ 寄送密碼重設驗證碼失敗：{e}")
        return jsonify({"error": "驗證碼寄送失敗，請稍後再試"}), 502

    db.session.commit()
    return jsonify({"message": f"驗證碼已寄到 {email}，{minutes} 分鐘內有效"}), 200


@auth_bp.route('/reset_password', methods=['POST'])
def reset_password():
    """用信箱收到的驗證碼設定新密碼"""
    from models import PasswordResetCode

    data = request.get_json() or {}
    email = (data.get('email') or '').strip()
    code = (data.get('code') or '').strip()
    new_password = data.get('new_password')

    if not email or not new_password:
        return jsonify({"error": "請填寫 Email 與新密碼"}), 400
    if not code:
        return jsonify({"error": "請輸入信箱收到的驗證碼"}), 400

    user, err = _reset_target(email)
    if err:
        return err

    now = datetime.utcnow()
    record = (PasswordResetCode.query.filter_by(user_id=user.id, used_at=None)
              .order_by(PasswordResetCode.created_at.desc()).first())
    if not record or record.expires_at < now:
        return jsonify({"error": "驗證碼已失效，請重新寄送驗證碼"}), 400

    if not check_password_hash(record.code_hash, code):
        record.attempts = (record.attempts or 0) + 1
        if record.attempts >= RESET_CODE_MAX_ATTEMPTS:
            record.used_at = now   # 輸錯太多次直接作廢，避免被猜中
            db.session.commit()
            return jsonify({"error": "驗證碼錯誤次數過多，請重新寄送驗證碼"}), 400
        db.session.commit()
        left = RESET_CODE_MAX_ATTEMPTS - record.attempts
        return jsonify({"error": f"驗證碼錯誤，還可以再試 {left} 次"}), 400

    pw_error = password_policy.validate(new_password, account=user.email, old_hash=user.password_hash)
    if pw_error:
        return jsonify({"error": pw_error}), 400

    # 將新密碼加密後，覆蓋掉舊密碼；驗證碼用過就作廢
    user.password_hash = generate_password_hash(new_password)
    user.must_change_password = False
    user.token_version = (user.token_version or 0) + 1   # 其他裝置上的舊通行證全部失效
    record.used_at = now
    db.session.commit()

    return jsonify({"message": "密碼重設成功！請使用新密碼登入"}), 200

@auth_bp.route('/change_password', methods=['POST'])
def change_password():
    """已登入的使用者自己改密碼；老師建立的學生帳號第一次登入時一定會走到這裡。

    學生與老師帳號的密碼至少要「中」，一般使用者 8 個字元以上即可。
    改完後舊的通行證全部失效（其他裝置要重新登入），這台裝置則換發一張新的。
    """
    data = request.get_json() or {}
    current = data.get('current_password') or ''
    new_password = data.get('new_password') or ''

    user = User.query.get(current_user_id())
    if user is None:
        return jsonify({"error": "請先登入"}), 401
    if (not check_password_hash(user.password_hash, current)
            or password_policy.is_google_placeholder_input(current, user.email)):
        return jsonify({"error": "目前密碼錯誤"}), 400

    account_type = getattr(user, 'account_type', None) or AccountType.GENERAL
    pw_error = password_policy.validate(
        new_password,
        account=user.email,
        require_medium=account_type in (AccountType.STUDENT, AccountType.TEACHER),
        old_hash=user.password_hash,
    )
    if pw_error:
        return jsonify({"error": pw_error}), 400

    user.password_hash = generate_password_hash(new_password)
    user.must_change_password = False
    user.token_version = (user.token_version or 0) + 1
    db.session.commit()

    return jsonify({"message": "密碼已更新", "token": issue_token(user)}), 200


# ==========================================
# 第三方登入整合 API (Google Login)
# ==========================================
FIREBASE_PROJECT_ID = os.getenv('FIREBASE_PROJECT_ID', 'jpn-learning-app-115502-abddb')


def verify_google_id_token(id_token_str):
    """向 Google 驗證 App 端 Firebase 登入後拿到的身分憑證，回傳憑證內容（含已驗證的 email）。"""
    from google.oauth2 import id_token as google_id_token
    from google.auth.transport import requests as google_requests
    return google_id_token.verify_firebase_token(
        id_token_str, google_requests.Request(), audience=FIREBASE_PROJECT_ID)


@auth_bp.route('/google_login', methods=['POST'])
def google_login():
    data = request.get_json() or {}
    id_token_str = (data.get('id_token') or '').strip()

    # 原本直接相信前端傳來的 email，任何人送一個別人的 email 就能登入那個帳號。
    # 現在必須附上 Firebase 登入後的身分憑證，Email 以 Google 驗證過的為準。
    if not id_token_str:
        return jsonify({"error": "請更新 App 後再使用 Google 登入"}), 400
    try:
        claims = verify_google_id_token(id_token_str)
    except Exception as e:
        print(f"⚠️ Google 身分憑證驗證失敗：{e}")
        return jsonify({"error": "Google 登入驗證失敗，請重新登入"}), 401
    email = (claims.get('email') or '').strip()
    if not email or not claims.get('email_verified', False):
        return jsonify({"error": "這個 Google 帳號沒有已驗證的 Email"}), 401

    # Google 登入通常可以順便拿到大頭貼網址，可以選擇性傳入
    avatar = data.get('avatar') or claims.get('picture') or ''

    user = User.query.filter_by(email=email).first()

    if not user:
        # 狀況 A：這是一個全新的使用者，自動幫他在資料庫建檔！
        new_friend_id = generate_friend_id()
        # 因為是用 Google 登入，不需要輸入密碼，所以隨機塞一個極高強度的假密碼給他
        # 以前是固定的 "GOOGLE_OAUTH_" + email，知道 Email 就能用密碼登入，改成隨機
        dummy_pwd = generate_password_hash(password_policy.GOOGLE_PLACEHOLDER_PREFIX + os.urandom(16).hex())
        
        user = User(email=email, username=default_username(email), password_hash=dummy_pwd,
                    friend_id=new_friend_id, avatar=avatar)
        db.session.add(user)
        db.session.commit() # 先 commit 讓 user 產生 id
    else:
        # 停用與帳號類型的檢查要跟 Email 登入一致，否則被停用的帳號換成 Google 登入就能繞過。
        if getattr(user, 'is_suspended', False):
            return jsonify({"error": "此帳號已被停用，請聯繫客服"}), 403
        # 這裡是一般版入口：學生帳號要從校園教育版登入，老師帳號是後台帳號
        account_type = getattr(user, 'account_type', None) or AccountType.GENERAL
        if account_type == AccountType.STUDENT:
            return jsonify({"status": "wrong_portal",
                            "error": "這是校園教育版的學生帳號，請改從「校園教育版」登入"}), 403
        if account_type != AccountType.GENERAL:
            return jsonify({"error": "這個帳號不能使用 Google 登入，請改用帳號密碼登入"}), 403

        # 狀況 B：老用戶，防呆檢查有沒有交友 ID
        if not user.friend_id:
            user.friend_id = generate_friend_id()
        # 如果老用戶沒頭像，但這次 Google 有傳過來，就順便更新
        if avatar and not user.avatar:
            user.avatar = avatar
        if not user.username:
            user.username = default_username(user.email)

    _record_social_login(user)
    return jsonify({"message": "Google 登入成功！", **_social_login_payload(user)}), 200


def _record_social_login(user):
    """Google 登入（一般版、校園教育版）共用：登入天數、小組登入目標、每日拍照次數、訂閱過期"""
    today = date.today()

    # 只要今天還沒登入過，馬拉松總天數就 +1
    if user.last_login_date != today:
        user.total_active_days = (user.total_active_days or 0) + 1

        # 接著算連續登入 (學習火種)
        if user.last_login_date == today - timedelta(days=1):
            # 狀況 B：昨天有登入，連勝 +1
            user.streak_days = (user.streak_days or 0) + 1
        else:
            # 狀況 C：斷掉了，或是第一次登入，重置為 1
            user.streak_days = 1

        # 小組的登入目標也要算 Google 登入的成員（Email 登入那邊有算，這裡原本漏了）
        member_record = GroupMember.query.filter_by(user_id=user.id).first()
        if member_record:
            member_record.group_logins = (member_record.group_logins or 0) + 1
            add_group_progress_and_check_reward(user.id, 'logins')

    # 把最後登入日期更新為今天
    user.last_login_date = today
    user.last_seen_at = datetime.utcnow()

    if user.last_scan_date != today:
        user.daily_scans = 0
        user.last_scan_date = today

    db.session.commit()

    # 登入時同步訂閱過期狀態
    check_and_expire_subscription(user)


def _social_login_payload(user):
    end_date = getattr(user, 'subscription_end_date', None)
    return {
        "token": issue_token(user),   # 登入通行證：之後呼叫 API 都要帶在 Authorization 標頭
        "user_id": user.id,
        "email": user.email,
        "japanese_level": user.japanese_level,
        "avatar": user.avatar,
        "streak_days": user.streak_days,
        "j_pts": user.j_pts,
        "daily_scans": user.daily_scans,
        "friend_id": user.friend_id,
        "username": user.username,
        "is_premium": bool(getattr(user, 'is_premium', False)),
        # 前端靠這個欄位決定進一般版還是校園教育版
        "account_type": getattr(user, 'account_type', 'general'),
        "subscription_end_date": end_date.isoformat() if end_date else None,
        "auto_renew": bool(getattr(user, 'auto_renew', False)),
    }


# ==========================================
# 校園教育版：先選學校，再用學校 Google 帳號登入
# ==========================================
# 學生不用等老師貼名單：第一次登入自動建立學生帳號，之後用老師給的班級代碼加入班級。
# 清單裡沒有自己的學校時，學生可以在 App 直接新增：輸入學校名稱後用學校 Google 帳號登入，
# 網域取自 Google 驗證過的 Email，不讓學生自己打（打錯或亂填 gmail.com 都不行）。
# super_admin 可以在後台「學校管理」頁修改學號格式、停用學校。

# App 新增學校時允許的網域結尾。只收學校網域，否則有人把 gmail.com 登記成學校，
# 任何 Gmail 都能登入教育版、免費不限次數使用
EDU_SCHOOL_DOMAIN_SUFFIXES = [d.strip().lower() for d in
                              (os.getenv('EDU_SCHOOL_DOMAIN_SUFFIXES') or '.edu.tw').split(',') if d.strip()]


def _is_school_domain(domain):
    return any(domain.endswith(suffix) for suffix in EDU_SCHOOL_DOMAIN_SUFFIXES)

@auth_bp.route('/schools', methods=['GET'])
def list_schools():
    """App 校園教育版登入頁的學校清單（只列啟用中的）"""
    schools = School.query.filter_by(is_active=True).order_by(School.name).all()
    result = []
    for s in schools:
        domains = s.domain_list()
        result.append({
            "school_id": s.id,
            "name": s.name,
            # 顯示「用 xxx.edu.tw 的學校信箱登入」，搜尋也比對這個（模擬器只能打英文時很好用）
            "domains": [d.lstrip('.') for d in domains],
            # 網頁版 Google 帳號選單的網域篩選：只有一個、而且不含子網域時才篩，
            # 否則學生信箱在子網域（g.xxx.edu.tw）的人會在選單裡找不到自己的帳號
            "hd": domains[0] if len(domains) == 1 and not domains[0].startswith('.') else None,
        })
    return jsonify({"schools": result}), 200


@auth_bp.route('/edu_google_login', methods=['POST'])
def edu_google_login():
    data = request.get_json() or {}
    id_token_str = (data.get('id_token') or '').strip()
    if not id_token_str:
        return jsonify({"error": "沒有收到 Google 登入資料，請再試一次"}), 400

    # 兩種情況：從清單選學校（school_id），或清單裡沒有、在 App 新增學校（new_school_name）
    new_school_name = (data.get('new_school_name') or '').strip()[:50]
    school = None
    if data.get('school_id'):
        school = School.query.get(data.get('school_id'))
        if not school or not school.is_active:
            return jsonify({"status": "school_required", "error": "請先選擇學校"}), 400
    elif not new_school_name:
        return jsonify({"status": "school_required", "error": "請先選擇學校"}), 400

    try:
        claims = verify_google_id_token(id_token_str)
    except Exception as e:
        print(f"⚠️ Google 身分憑證驗證失敗：{e}")
        return jsonify({"error": "Google 登入驗證失敗，請重新登入"}), 401
    # Google 登入拿到的 Email 都是小寫，統一才不會同一個人變成兩個帳號
    email = (claims.get('email') or '').strip().lower()
    if not email or not claims.get('email_verified', False):
        return jsonify({"error": "這個 Google 帳號沒有已驗證的 Email"}), 401

    # 網域與學號都以 Google 驗證過的 Email 判斷；App 端的帳號篩選只是方便，擋人靠這裡
    local, _, domain = email.partition('@')
    creating_school = False
    if school is None:
        if not _is_school_domain(domain):
            return jsonify({"status": "wrong_domain",
                            "error": f"要用學校配發的 Google 帳號（{'、'.join(EDU_SCHOOL_DOMAIN_SUFFIXES)} 結尾）才能新增學校，一般 Gmail 不行"}), 403
        # 這個網域已經有學校了（可能名稱打得不一樣）：直接用那一間，不重複建立
        school = next((s for s in School.query.all() if s.domain_allowed(domain)), None)
        if school is not None and not school.is_active:
            return jsonify({"error": f"{school.name}目前沒有開放登入，請聯繫老師或系統管理員"}), 403
        if school is None:
            if School.query.filter_by(name=new_school_name).first():
                return jsonify({"error": f"已經有「{new_school_name}」，但信箱網域不一樣。請確認學校名稱，或從清單選這間學校"}), 409
            # 先不寫進資料庫，確定這個人可以登入（是學生、不是一般版帳號）才建立
            school = School(name=new_school_name, student_domains=domain)
            creating_school = True
    elif not school.domain_allowed(domain):
        other = next((s for s in School.query.filter_by(is_active=True).all()
                      if s.id != school.id and s.domain_allowed(domain)), None)
        if other:
            return jsonify({"status": "wrong_school",
                            "error": f"「{email}」是{other.name}的帳號，請重新選擇學校"}), 403
        allowed = '、'.join('@' + d.lstrip('.') for d in school.domain_list())
        return jsonify({"status": "wrong_domain",
                        "error": f"請使用{school.name}配發的 Google 帳號（{allowed}）登入，一般 Gmail 不能登入校園教育版"}), 403
    if not school.student_no(local):
        return jsonify({"status": "not_student",
                        "error": f"「{email}」不是學生帳號（帳號不是學號）。老師請從網頁後台登入"}), 403

    avatar = data.get('avatar') or claims.get('picture') or ''
    user = User.query.filter(db.func.lower(User.email) == email).first()
    is_new = user is None

    if not is_new:
        if getattr(user, 'is_suspended', False):
            return jsonify({"error": "此帳號已被停用，請聯繫老師或系統管理員"}), 403
        account_type = getattr(user, 'account_type', None) or AccountType.GENERAL
        if account_type == AccountType.GENERAL:
            return jsonify({"status": "wrong_portal",
                            "error": "這個 Google 帳號已經是一般自主學習版的帳號，請改從「一般自主學習」登入"}), 403
        if account_type != AccountType.STUDENT:
            return jsonify({"status": "wrong_portal", "error": "這是老師帳號，請從網頁後台登入"}), 403

    if creating_school:
        db.session.add(school)
        db.session.flush()
        print(f"[NEW] 學生從 App 新增學校: {school.name}（@{domain}，{email}）")

    if is_new:
        user = User(
            email=email,
            username=(claims.get('name') or '').strip()[:30] or default_username(email),
            # 用 Google 登入沒有密碼，塞一組隨機的，密碼登入永遠對不上
            password_hash=generate_password_hash(password_policy.GOOGLE_PLACEHOLDER_PREFIX + os.urandom(16).hex()),
            friend_id=generate_friend_id(),
            avatar=avatar or None,
            account_type=AccountType.STUDENT,
            school_id=school.id,
        )
        db.session.add(user)
        db.session.flush()
        print(f"[NEW] 以學校 Google 帳號建立學生: {email}（{school.name}）")
    else:
        if not user.school_id:
            user.school_id = school.id
        if avatar and not user.avatar:
            user.avatar = avatar
        if not user.friend_id:
            user.friend_id = generate_friend_id()

    if creating_school:
        # 記下是哪個學生新增的，管理者在後台看得到，名稱打錯可以改
        school.created_by_user_id = user.id
        db.session.add(SystemLog(user_id=user.id, action='CREATE', target_table='school', target_id=school.id,
                                 new_value={'name': school.name, 'student_domains': domain, 'via': 'app'}))

    _record_social_login(user)   # 裡面會 commit，學校、學生帳號一起寫進去
    return jsonify({
        "message": "登入成功！",
        **_social_login_payload(user),
        # 第一次登入還沒加入任何班級，App 提示輸入老師給的班級代碼
        "is_new": is_new,
        "school_id": school.id,       # App 記住這間學校，下次直接選好
        "school_name": school.name,
        "school_created": creating_school,
    }), 200