import os
from dotenv import load_dotenv
from flask import Flask, request, jsonify
from flask_cors import CORS
from utils.db import db, configure_app_db, init_database, skip_db_init, safe_uri

# 匯入各個模組的 Blueprint
from services.quiz import quiz_bp
from services.auth import auth_bp
from services.scenario import scenario_bp
from services.user import user_bp
from services.group import group_bp
from services.vocabulary import vocab_bp
from services.tutor import tutor_bp
from services.dialect import dialect_bp
from services.character import character_bp
from services.tts import tts_bp
from services.subscription import subscription_bp, MONTHLY_POINTS_GRANT, YEARLY_POINTS_GRANT
from services.store import store_bp
from services.daily_reward import daily_reward_bp
from services.article import article_bp
from services.chat_history import chat_history_bp

# 👨‍🍳 引入內場廚師 (AI 聊天函數)
from services.tutor import get_ai_reply
# 先在上方 import
from services.sentence import sentence_bp
from services.classroom import classroom_bp
from services.student_assignment import student_assignment_bp


# 自動抓取 app.py 所在的絕對路徑
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(BASE_DIR, '.env'))  # DATABASE_URL、金鑰等設定

app = Flask(__name__)
# 允許跨網域請求；網頁版要讀得到自動延長後的新通行證與拒絕原因，所以把這兩個標頭開放給前端
CORS(app, expose_headers=['X-Auth-Token', 'X-Auth-Error'])

# 登入通行證：除了登入註冊與公開清單，App 的 API 都要帶通行證，而且只能操作自己的資料
from utils.auth_token import check_request as _check_auth, attach_renewed_token as _attach_renewed_token
app.before_request(_check_auth)
app.after_request(_attach_renewed_token)

print("================ 我是最新版、超乾淨的 app.py 喔喔喔 ================")

# 資料庫：.env 有 DATABASE_URL 就連 MySQL，沒有就用 backend/instance/jlens.db（SQLite）。
# 連線設定、SQLite 的 WAL 模式都集中在 utils/db.py，後台 admin_app.py 也用同一套。
DB_URI = configure_app_db(app, BASE_DIR)

# 註冊 API 路由 (綁定網址前綴)
app.register_blueprint(quiz_bp, url_prefix='/api/quiz')
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(scenario_bp, url_prefix='/api/scenario')
app.register_blueprint(user_bp, url_prefix='/api/user')
app.register_blueprint(group_bp, url_prefix='/api/group')
app.register_blueprint(vocab_bp, url_prefix='/api/vocab')
app.register_blueprint(tutor_bp, url_prefix='/api/tutor')
app.register_blueprint(dialect_bp, url_prefix='/api/dialect')
app.register_blueprint(character_bp, url_prefix='/api/character')
app.register_blueprint(tts_bp, url_prefix='/api/tts')
app.register_blueprint(subscription_bp, url_prefix='/api/subscription')
app.register_blueprint(store_bp, url_prefix='/api/store')
app.register_blueprint(daily_reward_bp, url_prefix='/api/daily')
app.register_blueprint(article_bp, url_prefix='/api/articles')
app.register_blueprint(chat_history_bp, url_prefix='/api/chat_history')
app.register_blueprint(sentence_bp, url_prefix='/api/sentence')
app.register_blueprint(classroom_bp, url_prefix='/api/classroom')
app.register_blueprint(student_assignment_bp, url_prefix='/api/assignment')
# 資料表版本控管（Flask-Migrate / Alembic）：模型改了欄位請執行
#   flask --app app db migrate -m "說明"   產生 migrations/versions/ 底下的遷移檔並一起 commit
# 組員 pull 之後啟動時會自動 upgrade，不用手動下指令。
from flask_migrate import Migrate
migrate = Migrate(app, db, render_as_batch=True, directory=os.path.join(BASE_DIR, 'migrations'))


def _seed_defaults():
    """啟動時種入預設資料（訂閱方案、購點方案、預設場景、主題官方單字），已存在的不動"""
    from models import SubscriptionPlan, PointPackage
    _db = db

    # 跟 utils/account_helper.py 的每日次數一致；單字收藏擴充實際是 50/100 點＝半價（services/store.py）
    _FEATURES = [
        '每天10次拍照辨識',
        '每天10次AI對話',
        '每天5次造句AI批改',
        '每天5次文章朗讀評分',
        '單字收藏擴充半價',
        '學習小組押金5折',
        '學習小組獎勵加倍',
    ]

    # ── 月訂閱、年訂閱方案 ──
    # 只在方案不存在時建立預設值。已存在的方案由管理者在後台維護（價格、上下架、功能說明），
    # 啟動時不能再寫回預設值，否則後台的修改一重啟就被蓋掉。
    # （原本還會寫入 points_grant，但模型沒有這個欄位，全新資料庫建立方案時會直接 TypeError。）
    # 用 billing_cycle 判斷有沒有方案（跟 services/subscription.py 找方案的方式一致），
    # 不用名稱：後台改了方案名稱，重啟後才不會又多建一筆。下面會停用的舊通用方案「Premium Pro」不算
    def _has_plan(cycle):
        return SubscriptionPlan.query.filter(
            SubscriptionPlan.billing_cycle == cycle, SubscriptionPlan.name != 'Premium Pro'
        ).first() is not None

    if not _has_plan('monthly'):
        _db.session.add(SubscriptionPlan(
            name='Premium Pro 月訂閱',
            billing_cycle='monthly',
            price_monthly=149,
            price_yearly=None,
            features_json=_FEATURES,
            points_grant_monthly=MONTHLY_POINTS_GRANT,
            points_grant_yearly=None,
            is_active=True,
        ))

    if not _has_plan('yearly'):
        _db.session.add(SubscriptionPlan(
            name='Premium Pro 年訂閱',
            billing_cycle='yearly',
            price_monthly=None,
            price_yearly=1290,
            features_json=_FEATURES,
            points_grant_monthly=None,
            points_grant_yearly=YEARLY_POINTS_GRANT,
            is_active=True,
        ))

    # 舊的通用方案停用（若存在）
    old_plan = SubscriptionPlan.query.filter_by(name='Premium Pro').first()
    if old_plan:
        old_plan.is_active = False

    _db.session.commit()

    # 購點方案：只補上不存在的預設方案，已存在的交給後台「點數方案管理」維護
    _PACKAGES = [
        ('入門包', 70,  50,  '',      '小試牛刀'),
        ('中包',   140, 90,  '推薦',  '最受歡迎的選擇'),
        ('大包',   380, 170, '最划算','平均單價最低'),
    ]
    for pkg_name, pts, price, tag, desc in _PACKAGES:
        if not PointPackage.query.filter_by(name=pkg_name).first():
            _db.session.add(PointPackage(name=pkg_name, points=pts, price=price, tag=tag, description=desc))
    _db.session.commit()

    # ── 預設場景種入 ──
    from models import Scene
    _SCENES = [
        {'name': '一蘭拉麵',   'icon_name': 'ramen_dining',   'icon_codepoint': 983114, 'show_in_quick_select': True},
        {'name': '遊戲日常',   'icon_name': 'sports_esports',  'icon_codepoint': 61218,  'show_in_quick_select': True},
        {'name': '漫畫展',     'icon_name': 'menu_book',       'icon_codepoint': 61441,  'show_in_quick_select': True},
        {'name': '機場問路',   'icon_name': 'flight_takeoff',  'icon_codepoint': 58681,  'show_in_quick_select': True},
        {'name': '職場新人',   'icon_name': 'work',            'icon_codepoint': 59641,  'show_in_quick_select': True},
        {'name': '動畫巡禮',   'icon_name': 'tv',              'icon_codepoint': 58900,  'show_in_quick_select': True},
        {'name': '迴轉壽司',   'icon_name': 'set_meal',        'icon_codepoint': 61929,  'show_in_quick_select': True},
        {'name': '藥妝店購物', 'icon_name': 'shopping_bag',    'icon_codepoint': 61900,  'show_in_quick_select': True},
    ]
    for s in _SCENES:
        existing = Scene.query.filter_by(name=s['name']).first()
        if not existing:
            _db.session.add(Scene(
                name=s['name'],
                icon_name=s['icon_name'],
                icon_codepoint=s['icon_codepoint'],
                show_in_quick_select=s['show_in_quick_select'],
            ))
        else:
            existing.icon_name = s['icon_name']
            existing.icon_codepoint = s['icon_codepoint']
            existing.show_in_quick_select = s['show_in_quick_select']
    _db.session.commit()

    # ── 主題收集冊：預種各主題官方常見字（idempotent，已存在跳過）──
    try:
        from seed_themes import seed_theme_vocabs, seed_theme_badges
        _added, _promoted = seed_theme_vocabs()
        if _added or _promoted:
            print(f"[Theme] 主題官方單字種入：新增 {_added} 筆、收編既有 {_promoted} 筆")
        _badges = seed_theme_badges()
        if _badges:
            print(f"[Theme] 主題集滿徽章種入：新增 {_badges} 枚")
    except Exception as _e:
        print(f"⚠️ 主題官方單字種入警告：{_e}")


# 啟動時自動建立資料表、執行遷移、補欄位、種預設資料（跟 admin_app.py 共用，誰先啟動都行）
if not skip_db_init():
    init_database(app, seed=_seed_defaults)

# ==========================================
# 🛎️ 專屬櫃檯：負責接收 Flutter 傳來的聊天包裹
# ==========================================
@app.route('/api/chat', methods=['POST'])
def chat():
    # 1. 櫃檯接單（把所有 Flutter 傳來的變數收下來）
    user_message = request.form.get('message', '')
    chat_history = request.form.get('history', '')
    topic = request.form.get('topic', '日常對話')
    user_level = request.form.get('level', 'N5') # 接收等級！如果 App 沒傳，預設當作 N5
    dialect_id = request.form.get('dialect_id', type=int) # 接收腔調 ID（可為 None，代表標準語）
    user_id = request.form.get('user_id', type=int) # AI 失敗時要退還次數用
    session_id = request.form.get('session_id', type=int) # 對話紀錄場次（可為 None）

    print(f" 收到包裹 -> 主題：{topic} | 等級：{user_level} | 腔調：{dialect_id} | 訊息：{user_message}")

    # 1b. 必須先透過 /api/user/use_ai 扣過次數才能呼叫 AI。原本這裡不檢查，
    #     次數用完後跳過扣次 API 直接打這支，就能無限對話。
    from services.user import consume_ai_credit
    if not user_id or not consume_ai_credit(user_id):
        from services.user import AI_QUOTA_MSG
        quota_msg = AI_QUOTA_MSG
        if request.form.get('assignment_id', type=int):
            return jsonify({"error": quota_msg, "quota_exceeded": True}), 403
        return quota_msg, 403

    # 1c. 腔調要用買角色的名額解鎖過才能用；沒解鎖就當作標準語（老師在作業指定的腔調不受限）
    if dialect_id and not request.form.get('assignment_id', type=int):
        from services.character import can_use_dialect
        if not can_use_dialect(user_id, dialect_id):
            dialect_id = None

    # 2. 把食材交給內場廚師 (呼叫 tutor.py 的函數，記得把 user_level / dialect_id 也傳進去)
    #     角色人設：官方角色要已擁有、自訂角色要是自己的才套用，否則維持原本的家教模式
    from services.character import character_persona
    persona = character_persona(user_id, request.form.get('character'))
    ai_response_text, ok = get_ai_reply(topic, user_message, chat_history, user_level, dialect_id, persona)

    # 2b. AI 沒有成功產生回覆時，把先前扣掉的對話次數還給使用者
    #     （次數是在送出訊息前就先扣的，失敗了不該算在使用者頭上）
    if not ok and user_id:
        try:
            from services.user import refund_ai_usage
            refund_ai_usage(user_id)
        except Exception as e:
            print(f"⚠️ 退還 AI 次數時發生錯誤：{e}")

    # 2c. 成功回覆才寫入對話紀錄（失敗的對話不留紀錄，避免歷史裡都是錯誤訊息）
    #     開場白（[幫我開場]）不需要記錄使用者那一句，只存 AI 的開場內容
    if ok and session_id:
        try:
            from services.chat_history import save_exchange
            save_exchange(session_id, user_message, ai_response_text, user_id=user_id)
        except Exception as e:
            print(f"⚠️ 儲存對話紀錄時發生錯誤：{e}")

    # 2d. 從作業進來的對話：每輪結束檢查是否達到老師規定的輪數，達到就自動繳交。
    #     一般對話（沒帶 assignment_id）完全不走這段。
    assignment_id = request.form.get('assignment_id', type=int)
    if assignment_id:
        assignment_result = None
        if ok:
            from services.student_assignment import auto_submit_chat
            assignment_result = auto_submit_chat(user_id, assignment_id, session_id)
        # 這支 API 原本回傳純文字，前端直接把整個回應當成 AI 回覆。
        # 作業模式需要多帶繳交進度，所以只有帶 assignment_id 時才改回 JSON，
        # 一般對話維持純文字，現有前端完全不受影響。
        return jsonify({"reply": ai_response_text, "assignment_result": assignment_result})

    # 3. 櫃檯送餐（把熱騰騰的 AI 回覆送回給 Flutter）
    return ai_response_text




# ==========================================

# 🛑 app.run 必須永遠在整個檔案的最下面！
if __name__ == '__main__':
    print("[Startup] 後端伺服器啟動中...")
    print(f"[Database] 使用資料庫: {safe_uri(DB_URI)}")

    # 加上 host='0.0.0.0' 代表允許區域網路內的所有設備連線
    app.run(host='0.0.0.0', port=5050, debug=True)