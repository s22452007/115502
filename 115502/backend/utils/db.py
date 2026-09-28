from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


def ensure_model_columns(database=None, tables=None):
    """把模型裡有、但實際 SQLite 資料表裡沒有的欄位用 ALTER TABLE 補上。

    jlens.db 不進 git，每個組員電腦上都是自己的資料庫；模型一加欄位，舊資料庫一查就會
    「no such column」而 500。啟動時跑一次這個函式，舊資料庫就能自動跟上模型。
    只會「新增缺少的欄位」，不會改型別、不會刪欄位、不會動既有資料。

    tables：只檢查這些資料表（None 代表全部）。回傳實際補上的 (table, column) 清單。
    """
    from sqlalchemy import inspect, text

    database = database or db
    engine = database.engine
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())
    added = []

    for table in database.metadata.sorted_tables:
        if tables and table.name not in tables:
            continue
        if table.name not in existing_tables:
            continue  # 整張表不存在的交給 create_all 處理
        existing_cols = {c['name'] for c in inspector.get_columns(table.name)}
        for column in table.columns:
            if column.name in existing_cols:
                continue
            col_type = column.type.compile(dialect=engine.dialect)
            ddl = f'ALTER TABLE "{table.name}" ADD COLUMN "{column.name}" {col_type}'
            default = column.default.arg if column.default is not None and column.default.is_scalar else None
            if default is not None:
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
