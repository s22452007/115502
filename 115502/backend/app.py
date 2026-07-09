import os
from dotenv import load_dotenv
from flask import Flask, request
from flask_cors import CORS
from utils.db import db

# 匯入各個模組的 Blueprint
from services.quiz import quiz_bp
from services.auth import auth_bp
from services.scenario import scenario_bp
from services.user import user_bp
from services.group import group_bp
from services.vocabulary import vocab_bp
from services.tutor import tutor_bp
from services.dialect import dialect_bp
from services.tts import tts_bp
from services.subscription import subscription_bp, MONTHLY_POINTS_GRANT, YEARLY_POINTS_GRANT
from services.store import store_bp
from services.daily_reward import daily_reward_bp

# 👨‍🍳 引入內場廚師 (AI 聊天函數)
from services.tutor import get_ai_reply

# 自動抓取 app.py 所在的絕對路徑
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

app = Flask(__name__)
CORS(app) # 允許跨網域請求

print("================ 我是最新版、超乾淨的 app.py 喔喔喔 ================")

# 強制把資料庫路徑綁定在 backend/instance/jlens.db
instance_path = os.path.join(BASE_DIR, 'instance')
db_path = os.path.join(instance_path, 'jlens.db')

# 防呆機制：如果 instance 資料夾還不存在，就自動幫你建一個
os.makedirs(instance_path, exist_ok=True)

# 設定 SQLite 資料庫，使用絕對路徑
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
from sqlalchemy.pool import NullPool
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
    'poolclass': NullPool,
    'connect_args': {'timeout': 30, 'check_same_thread': False},
}

# 初始化資料庫
db.init_app(app)

# 啟用 WAL 模式：允許多個讀取並發，大幅減少 "database is locked" 錯誤
from sqlalchemy import event as _sa_event
with app.app_context():
    @_sa_event.listens_for(db.engine, 'connect')
    def _set_sqlite_wal(dbapi_conn, _):
        cur = dbapi_conn.cursor()
        cur.execute('PRAGMA journal_mode=WAL')
        cur.execute('PRAGMA busy_timeout=30000')
        cur.close()

# 註冊 API 路由 (綁定網址前綴)
app.register_blueprint(quiz_bp, url_prefix='/api/quiz')
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(scenario_bp, url_prefix='/api/scenario')
app.register_blueprint(user_bp, url_prefix='/api/user')
app.register_blueprint(group_bp, url_prefix='/api/group')
app.register_blueprint(vocab_bp, url_prefix='/api/vocab')
app.register_blueprint(tutor_bp, url_prefix='/api/tutor')
app.register_blueprint(dialect_bp, url_prefix='/api/dialect')
app.register_blueprint(tts_bp, url_prefix='/api/tts')
app.register_blueprint(subscription_bp, url_prefix='/api/subscription')
app.register_blueprint(store_bp, url_prefix='/api/store')
app.register_blueprint(daily_reward_bp, url_prefix='/api/daily')

# 啟動時自動建立資料表與執行遷移
with app.app_context():
    db.create_all()  # 建立所有新表

    from models import SubscriptionPlan, PointPackage
    from utils.db import db as _db
    from sqlalchemy import text

    # ── SQLite 欄位遷移：新增 billing_cycle / price_monthly nullable 支援 ──
    for col_sql in [
        'ALTER TABLE subscription_plan ADD COLUMN billing_cycle VARCHAR(10)',
    ]:
        try:
            with _db.engine.connect() as conn:
                conn.execute(text(col_sql))
                conn.commit()
        except Exception:
            pass  # 欄位已存在，略過

    # ── 移除 user_subscription.status NOT NULL 欄位（若存在）──
    import sqlite3 as _sqlite3
    _db_path = os.path.join(BASE_DIR, 'instance', 'jlens.db')
    try:
        _conn = _sqlite3.connect(_db_path, timeout=15)
        _conn.execute('PRAGMA journal_mode=WAL')
        _cur = _conn.cursor()
        _cur.execute("PRAGMA table_info(user_subscription);")
        _us_cols = [row[1] for row in _cur.fetchall()]
        if 'status' in _us_cols:
            _cur.execute("CREATE TABLE IF NOT EXISTS user_subscription_bak AS SELECT * FROM user_subscription;")
            _cur.execute("DROP INDEX IF EXISTS uq_user_active_subscription;")
            _cur.execute("DROP TABLE user_subscription;")
            _cur.execute("""
                CREATE TABLE user_subscription (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    plan_id INTEGER NOT NULL,
                    billing_cycle VARCHAR(10) NOT NULL,
                    start_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    end_date DATETIME NOT NULL,
                    auto_renew BOOLEAN DEFAULT 1,
                    payment_method VARCHAR(50),
                    payment_status VARCHAR(20) NOT NULL DEFAULT 'paid',
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(user_id) REFERENCES user(id),
                    FOREIGN KEY(plan_id) REFERENCES subscription_plan(id)
                );
            """)
            _target = ['id','user_id','plan_id','billing_cycle','start_date','end_date',
                       'auto_renew','payment_method','payment_status','created_at']
            _copy = ', '.join(c for c in _target if c in _us_cols)
            _cur.execute(f"INSERT INTO user_subscription ({_copy}) SELECT {_copy} FROM user_subscription_bak;")
            _cur.execute("DROP TABLE user_subscription_bak;")
            _cur.execute("CREATE INDEX IF NOT EXISTS idx_user_sub_user ON user_subscription(user_id);")
            _conn.commit()
        _conn.close()
    except Exception as _e:
        print(f"⚠️ user_subscription 欄位修正警告：{_e}")

    _FEATURES = [
        '每天10次拍照辨識',
        '每天10次AI對話',
        '單字收藏擴充6折',
        '學習小組押金5折',
        '學習小組獎勵加倍',
    ]

    # ── 月訂閱方案 ──
    monthly_plan = SubscriptionPlan.query.filter_by(name='Premium Pro 月訂閱').first()
    if monthly_plan:
        monthly_plan.price_monthly = 149
        monthly_plan.price_yearly = None
        monthly_plan.billing_cycle = 'monthly'
        monthly_plan.points_grant_monthly = MONTHLY_POINTS_GRANT
        monthly_plan.points_grant_yearly = None
        monthly_plan.points_grant = MONTHLY_POINTS_GRANT
        monthly_plan.features_json = _FEATURES
        monthly_plan.is_active = True
    else:
        _db.session.add(SubscriptionPlan(
            name='Premium Pro 月訂閱',
            billing_cycle='monthly',
            price_monthly=149,
            price_yearly=None,
            features_json=_FEATURES,
            points_grant=MONTHLY_POINTS_GRANT,
            points_grant_monthly=MONTHLY_POINTS_GRANT,
            points_grant_yearly=None,
            is_active=True,
        ))

    # ── 年訂閱方案 ──
    yearly_plan = SubscriptionPlan.query.filter_by(name='Premium Pro 年訂閱').first()
    if yearly_plan:
        yearly_plan.price_monthly = None
        yearly_plan.price_yearly = 1290
        yearly_plan.billing_cycle = 'yearly'
        yearly_plan.points_grant_monthly = None
        yearly_plan.points_grant_yearly = YEARLY_POINTS_GRANT
        yearly_plan.points_grant = YEARLY_POINTS_GRANT
        yearly_plan.features_json = _FEATURES
        yearly_plan.is_active = True
    else:
        _db.session.add(SubscriptionPlan(
            name='Premium Pro 年訂閱',
            billing_cycle='yearly',
            price_monthly=None,
            price_yearly=1290,
            features_json=_FEATURES,
            points_grant=YEARLY_POINTS_GRANT,
            points_grant_monthly=None,
            points_grant_yearly=YEARLY_POINTS_GRANT,
            is_active=True,
        ))

    # 舊的通用方案停用（若存在）
    old_plan = SubscriptionPlan.query.filter_by(name='Premium Pro').first()
    if old_plan:
        old_plan.is_active = False

    _db.session.commit()

    # 購點方案（idempotent upsert）
    _PACKAGES = [
        ('入門包', 70,  50,  '',      '小試牛刀'),
        ('中包',   140, 90,  '推薦',  '最受歡迎的選擇'),
        ('大包',   380, 170, '最划算','平均單價最低'),
    ]
    for pkg_name, pts, price, tag, desc in _PACKAGES:
        pkg = PointPackage.query.filter_by(name=pkg_name).first()
        if pkg:
            pkg.points = pts
            pkg.price = price
            pkg.tag = tag
            pkg.description = desc
            pkg.is_active = True
        else:
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

    print(f" 收到包裹 -> 主題：{topic} | 等級：{user_level} | 腔調：{dialect_id} | 訊息：{user_message}")

    # 2. 把食材交給內場廚師 (呼叫 tutor.py 的函數，記得把 user_level / dialect_id 也傳進去)
    ai_response_text = get_ai_reply(topic, user_message, chat_history, user_level, dialect_id)

    # 3. 櫃檯送餐（把熱騰騰的 AI 回覆送回給 Flutter）
    return ai_response_text

# ==========================================

# 🛑 app.run 必須永遠在整個檔案的最下面！
if __name__ == '__main__':
    print("[Startup] 後端伺服器啟動中...")
    print(f"[Database] 資料庫已牢牢綁定於: {db_path}") 

    # 加上 host='0.0.0.0' 代表允許區域網路內的所有設備連線
    app.run(host='0.0.0.0', port=5050, debug=True)