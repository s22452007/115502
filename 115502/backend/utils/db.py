"""資料庫共用設定：SQLite（預設）／MySQL（設定 DATABASE_URL）都走這裡。

- database_uri()：沒設 DATABASE_URL 就用 backend/instance/jlens.db，組員電腦不用裝任何東西；
  伺服器在 .env 設 DATABASE_URL=mysql+pymysql://... 就改連 MySQL。
- init_database()：啟動時建表、跑 Flask-Migrate 遷移、補欄位、種預設資料，多個程序同時啟動也只會做一次。
"""
import os
import sys
import time
from contextlib import contextmanager

from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import event, inspect, text
from sqlalchemy.pool import NullPool

db = SQLAlchemy()


# ----------------------------------------------------------------------
# 連線設定
# ----------------------------------------------------------------------
def database_uri(base_dir):
    """DATABASE_URL 有設就用（MySQL），否則退回 backend/instance/jlens.db（SQLite）。"""
    url = (os.getenv('DATABASE_URL') or '').strip()
    if url:
        if url.startswith('mysql://'):          # 沒寫驅動的話補成 PyMySQL
            url = 'mysql+pymysql://' + url[len('mysql://'):]
        return url
    instance = os.path.join(base_dir, 'instance')
    legacy = os.path.join(base_dir, 'jlens.db')  # 很早期的版本把資料庫放在 backend/ 根目錄
    if not os.path.exists(os.path.join(instance, 'jlens.db')) and os.path.exists(legacy):
        return 'sqlite:///' + legacy
    os.makedirs(instance, exist_ok=True)
    return 'sqlite:///' + os.path.join(instance, 'jlens.db')


def is_sqlite(uri):
    return uri.startswith('sqlite')


def engine_options(uri):
    if is_sqlite(uri):
        # NullPool：每個請求各自開關連線，避免多執行緒共用同一條 SQLite 連線
        return {'poolclass': NullPool,
                'connect_args': {'timeout': 30, 'check_same_thread': False}}
    # MySQL：pool_pre_ping 讓被伺服器踢掉的閒置連線自動重連；pool_recycle 要小於 MySQL 的 wait_timeout
    opts = {'pool_pre_ping': True, 'pool_recycle': 280, 'pool_size': 5, 'max_overflow': 10}
    if uri.startswith('mysql'):
        opts['connect_args'] = {'charset': 'utf8mb4'}   # 日文、emoji 都要能存
    return opts


def safe_uri(uri):
    """顯示在 log 的連線字串，把密碼遮掉"""
    if '@' in uri and '://' in uri:
        head, tail = uri.split('://', 1)
        cred, rest = tail.rsplit('@', 1)
        user = cred.split(':', 1)[0]
        return f'{head}://{user}:***@{rest}'
    return uri


def _enable_sqlite_wal(engine):
    """WAL 模式：允許多個讀取並發，大幅減少 "database is locked" 錯誤"""
    @event.listens_for(engine, 'connect')
    def _set_sqlite_wal(dbapi_conn, _):
        cur = dbapi_conn.cursor()
        cur.execute('PRAGMA journal_mode=WAL')
        cur.execute('PRAGMA busy_timeout=30000')
        cur.close()


def configure_app_db(app, base_dir):
    """設定 Flask app 的資料庫連線並 db.init_app()。回傳實際使用的連線字串。"""
    uri = database_uri(base_dir)
    app.config['SQLALCHEMY_DATABASE_URI'] = uri
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SQLALCHEMY_ENGINE_OPTIONS'] = engine_options(uri)
    db.init_app(app)
    with app.app_context():
        if db.engine.dialect.name == 'sqlite':
            _enable_sqlite_wal(db.engine)
    return uri


def skip_db_init():
    """`flask db migrate` 這類指令載入 app 時不要先建表補欄位，否則 autogenerate 會比不出差異。
    也可以用環境變數 JLENS_SKIP_DB_INIT=1 強制略過（搬資料腳本會用）。"""
    if os.getenv('JLENS_SKIP_DB_INIT') == '1':
        return True
    return bool(os.getenv('FLASK_RUN_FROM_CLI')) and 'db' in sys.argv


# ----------------------------------------------------------------------
# 啟動時的資料庫初始化
# ----------------------------------------------------------------------
def init_database(app, seed=None):
    """建表 → 跑遷移 → 補欄位（安全網）→ 種預設資料。

    - 全新資料庫：依模型建全部資料表，直接標記為最新遷移版本。
    - Alembic 之前就有的舊資料庫（組員的 jlens.db）：補缺少的表與欄位後標記版本，之後改走遷移。
    - 已有版本紀錄：執行 flask db upgrade，把還沒跑過的遷移跑完。
    api 與 admin（或 gunicorn 多個 worker）同時啟動時用鎖排隊，確保只有一個在改結構。
    """
    from flask_migrate import stamp, upgrade

    with app.app_context():
        engine = db.engine
        with _init_lock(engine):
            tables = set(inspect(engine).get_table_names())
            if 'alembic_version' not in tables:
                if tables:
                    _legacy_sqlite_fixups(engine)
                    db.create_all()                       # 補整張不存在的表
                    for _table, _column in ensure_model_columns(db):
                        print(f'[DB] 自動補上缺少的欄位 {_table}.{_column}')
                else:
                    db.create_all()
                stamp()                                   # 視為已套用所有遷移
                print('[DB] 資料表已依模型對齊，並標記遷移版本')
            else:
                upgrade()

            # 安全網：模型加了欄位卻忘了產生遷移檔時，先補上讓系統能跑，並提醒負責人補遷移
            for _table, _column in ensure_model_columns(db):
                print(f'[DB] 模型有欄位 {_table}.{_column} 但沒有對應的遷移檔，已自動補上；'
                      f'請執行「flask --app app db migrate -m 說明」產生遷移檔並一起 commit')

            if seed is not None:
                seed()


@contextmanager
def _init_lock(engine):
    """MySQL 用 GET_LOCK；SQLite 用資料庫旁的鎖檔。拿不到鎖等最多 120 秒後照常繼續（不讓服務起不來）。"""
    name = engine.dialect.name
    if name == 'mysql':
        conn = engine.connect()
        try:
            got = conn.execute(text("SELECT GET_LOCK('jlens_db_init', 120)")).scalar()
            if not got:
                print('[DB] 等待其他程序初始化資料庫逾時，直接繼續')
            yield
        finally:
            try:
                conn.execute(text("SELECT RELEASE_LOCK('jlens_db_init')"))
            finally:
                conn.close()
        return

    db_file = engine.url.database if name == 'sqlite' else None
    if not db_file or db_file == ':memory:':
        yield
        return

    lock_path = db_file + '.init.lock'
    fd = _acquire_lock_file(lock_path, timeout=120, stale_after=300)
    try:
        yield
    finally:
        if fd is not None:
            os.close(fd)
            try:
                os.unlink(lock_path)
            except OSError:
                pass


def _acquire_lock_file(path, timeout, stale_after):
    deadline = time.time() + timeout
    while True:
        try:
            return os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            try:
                if time.time() - os.path.getmtime(path) > stale_after:
                    os.unlink(path)          # 上次沒正常結束留下的鎖檔
                    continue
            except OSError:
                pass
            if time.time() > deadline:
                print('[DB] 等待其他程序初始化資料庫逾時，直接繼續')
                return None
            time.sleep(0.2)


# ----------------------------------------------------------------------
# 舊資料庫相容
# ----------------------------------------------------------------------
def ensure_model_columns(database=None, tables=None):
    """把模型裡有、但實際資料表裡沒有的欄位用 ALTER TABLE 補上（SQLite、MySQL 都可）。

    只會「新增缺少的欄位」，不會改型別、不會刪欄位、不會動既有資料。
    tables：只檢查這些資料表（None 代表全部）。回傳實際補上的 (table, column) 清單。
    """
    from sqlalchemy.types import Text, JSON

    database = database or db
    engine = database.engine
    inspector = inspect(engine)
    quote = engine.dialect.identifier_preparer.quote
    existing_tables = set(inspector.get_table_names())
    added = []

    for table in database.metadata.tables.values():   # 只是補欄位，不需要依外鍵排序（sorted_tables 會對 school↔user 的互相參照發警告）
        if tables and table.name not in tables:
            continue
        if table.name not in existing_tables:
            continue  # 整張表不存在的交給 create_all 處理
        existing_cols = {c['name'] for c in inspector.get_columns(table.name)}
        for column in table.columns:
            if column.name in existing_cols:
                continue
            col_type = column.type.compile(dialect=engine.dialect)
            ddl = f'ALTER TABLE {quote(table.name)} ADD COLUMN {quote(column.name)} {col_type}'
            default = column.default.arg if column.default is not None and column.default.is_scalar else None
            # MySQL 的 TEXT / JSON 欄位不能有常數預設值
            if default is not None and not (engine.dialect.name == 'mysql' and isinstance(column.type, (Text, JSON))):
                if isinstance(default, bool):
                    default_sql = '1' if default else '0'
                elif isinstance(default, (int, float)):
                    default_sql = str(default)
                else:
                    default_sql = "'" + str(default).replace("'", "''") + "'"
                ddl += f' DEFAULT {default_sql}'
            with engine.connect() as conn:
                conn.execute(text(ddl))
                conn.commit()
            added.append((table.name, column.name))
    return added


def _legacy_sqlite_fixups(engine):
    """很舊的 SQLite 資料庫 user_subscription 還有 NOT NULL 的 status 欄位（模型早就拿掉了），
    ORM 一寫入就會失敗。只在 SQLite 上、而且該欄位存在時重建這張表；MySQL 是新建的不會有這問題。"""
    if engine.dialect.name != 'sqlite':
        return
    import sqlite3
    try:
        conn = sqlite3.connect(engine.url.database, timeout=15)
        cur = conn.cursor()
        cur.execute("PRAGMA table_info(user_subscription);")
        cols = [row[1] for row in cur.fetchall()]
        if 'status' in cols:
            cur.execute("CREATE TABLE IF NOT EXISTS user_subscription_bak AS SELECT * FROM user_subscription;")
            cur.execute("DROP INDEX IF EXISTS uq_user_active_subscription;")
            cur.execute("DROP TABLE user_subscription;")
            cur.execute("""
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
            target = ['id', 'user_id', 'plan_id', 'billing_cycle', 'start_date', 'end_date',
                      'auto_renew', 'payment_method', 'payment_status', 'created_at']
            copy = ', '.join(c for c in target if c in cols)
            cur.execute(f"INSERT INTO user_subscription ({copy}) SELECT {copy} FROM user_subscription_bak;")
            cur.execute("DROP TABLE user_subscription_bak;")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_user_sub_user ON user_subscription(user_id);")
            conn.commit()
            print('[DB] 已移除舊版 user_subscription.status 欄位')
        conn.close()
    except Exception as e:
        print(f"⚠️ user_subscription 欄位修正警告：{e}")
