# -*- coding: utf-8 -*-
"""把既有的 SQLite 資料（instance/jlens.db）整批搬進 MySQL。換資料庫時在伺服器上執行一次就好。

用法（在 backend 資料夾；先用 docker compose up -d mysql 把 MySQL 跑起來、而且裡面還是空的）：
    py -3 migrate_sqlite_to_mysql.py --to "mysql+pymysql://jlens:密碼@127.0.0.1:3306/jlens?charset=utf8mb4"

    --from     來源 SQLite 檔（預設 instance/jlens.db）
    --to       目標 MySQL 連線字串（沒給就讀 .env 的 DATABASE_URL）
    --force    目標已經有資料也照搬（會先把目標的所有資料表砍掉重建）
    --truncate VARCHAR 欄位內容超過模型長度時截斷後寫入（預設不截斷：該筆會寫入失敗並列出來，請先把模型長度加大）

做的事：
    1. 依 models.py 在 MySQL 建全部資料表
    2. 依資料表相依順序逐表複製，保留原本的 id
    3. 標記 Alembic 遷移版本（之後 api/admin 啟動時看到版本紀錄，就不會再重建或重複種預設資料）
    4. 逐表核對兩邊筆數

搬完直接 docker compose up -d，照片檔（static/photos/）另外複製即可，資料庫裡只存檔名。
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone

os.environ['JLENS_SKIP_DB_INIT'] = '1'     # 匯入 app 時不要自己建表、種資料，交給這支腳本控制

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, BASE_DIR)

from dotenv import load_dotenv
load_dotenv(os.path.join(BASE_DIR, '.env'))

import sqlalchemy as sa
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.pool import NullPool

BATCH = 500

# SQLite 的舊資料裡 NOT NULL 欄位可能是 NULL（欄位是後來用 ALTER TABLE 補上的，舊紀錄沒值），MySQL 會拒收。
# 這裡列出已知欄位的補值；沒列的就用模型的預設值，字串欄位最後退回空字串，並在結尾列出補了幾筆。
NULL_FIXUPS = {
    ('point_transaction', 'transaction_type'): 'purchase',   # 早期購點紀錄沒有類型，後台一直把 NULL 當購買
}


def parse_dt(value):
    """SQLite 存的時間字串 → datetime（存的是 UTC；帶時區的先換成 UTC 再去掉時區）"""
    if value is None or value == '':
        return None
    if isinstance(value, datetime):
        return value
    s = str(value).strip()
    for fmt in ('%Y-%m-%d %H:%M:%S.%f', '%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S.%f', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d'):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    try:
        dt = datetime.fromisoformat(s.replace('Z', '+00:00'))
        if dt.tzinfo is not None:
            dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
        return dt
    except ValueError:
        raise ValueError(f'看不懂的時間格式: {value!r}')


def fill_null(column, nulls_filled):
    """NOT NULL 欄位遇到 NULL 時的補值；補不出來就維持 None 讓 MySQL 報錯"""
    key = (column.table.name, column.name)
    if key in NULL_FIXUPS:
        value = NULL_FIXUPS[key]
    elif column.default is not None and column.default.is_scalar:
        value = column.default.arg
    elif isinstance(column.type, sa.String):
        value = ''
    elif isinstance(column.type, sa.Boolean):
        value = False
    elif isinstance(column.type, (sa.Integer, sa.Float)):
        value = 0
    else:
        return None
    nulls_filled[key] = nulls_filled.get(key, 0) + 1
    return value


def convert(column, value, truncate, oversize, nulls_filled=None):
    """把 SQLite 取出的原始值轉成 MySQL 欄位型別能接受的 Python 值"""
    if value is None:
        if not column.nullable and not column.primary_key and nulls_filled is not None:
            return fill_null(column, nulls_filled)
        return None
    t = column.type
    if isinstance(t, sa.DateTime):
        return parse_dt(value)
    if isinstance(t, sa.Date):
        dt = parse_dt(value)
        return dt.date() if dt else None
    if isinstance(t, sa.Boolean):
        if isinstance(value, str):
            return value.strip().lower() in ('1', 'true', 't', 'yes')
        return bool(value)
    if isinstance(t, sa.JSON):
        if isinstance(value, (bytes, bytearray)):
            value = value.decode('utf-8', 'replace')
        if isinstance(value, str):
            try:
                return json.loads(value)
            except ValueError:
                return value            # 不是合法 JSON 的舊資料就當字串存
        return value
    if isinstance(t, sa.String) and not isinstance(t, sa.Text) and t.length and isinstance(value, str):
        if len(value) > t.length:
            oversize.append((column.table.name, column.name, len(value), t.length))
            if truncate:
                return value[:t.length]
    if isinstance(t, (sa.Integer, sa.Float)) and isinstance(value, str):
        value = value.strip()
        if value == '':
            return None
        return float(value) if isinstance(t, sa.Float) else int(float(value))
    return value


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--from', dest='src', default=os.path.join(BASE_DIR, 'instance', 'jlens.db'))
    ap.add_argument('--to', dest='dst', default=None)
    ap.add_argument('--force', action='store_true')
    ap.add_argument('--truncate', action='store_true')
    args = ap.parse_args()

    src_path = os.path.abspath(args.src)
    if not os.path.exists(src_path):
        sys.exit(f'找不到來源 SQLite 檔：{src_path}')
    dst_url = (args.dst or os.getenv('DATABASE_URL') or '').strip()
    if not dst_url or dst_url.startswith('sqlite'):
        sys.exit('請用 --to 指定 MySQL 連線字串（或在 .env 設 DATABASE_URL），例如 '
                 'mysql+pymysql://jlens:密碼@127.0.0.1:3306/jlens?charset=utf8mb4')
    if dst_url.startswith('mysql://'):
        dst_url = 'mysql+pymysql://' + dst_url[len('mysql://'):]
    os.environ['DATABASE_URL'] = dst_url

    from utils.db import safe_uri
    print(f'來源：{src_path}')
    print(f'目標：{safe_uri(dst_url)}')

    from app import app                 # 讀 models、設定好目標連線（JLENS_SKIP_DB_INIT=1 不會建表）
    from utils.db import db
    from flask_migrate import stamp

    src = create_engine('sqlite:///' + src_path.replace('\\', '/'), poolclass=NullPool)
    src_insp = inspect(src)
    src_tables = set(src_insp.get_table_names())

    failed, oversize, report, nulls_filled = [], [], [], {}
    with app.app_context():
        dst = db.engine
        existing = inspect(dst).get_table_names()
        if existing:
            with dst.connect() as c:
                total = sum(c.execute(text(f'SELECT COUNT(*) FROM `{t}`')).scalar() for t in existing)
            if total and not args.force:
                sys.exit(f'目標資料庫已經有 {len(existing)} 張表、{total} 筆資料。確定要全部砍掉重搬請加 --force。')
            if args.force:
                print(f'--force：清掉目標既有的 {len(existing)} 張表')
                with dst.begin() as c:
                    c.execute(text('SET FOREIGN_KEY_CHECKS=0'))
                    for t in existing:
                        c.execute(text(f'DROP TABLE IF EXISTS `{t}`'))
                    c.execute(text('SET FOREIGN_KEY_CHECKS=1'))

        print('建立資料表…')
        db.metadata.create_all(dst)

        print('複製資料…')
        with src.connect() as sconn:
            for table in db.metadata.sorted_tables:
                if table.name not in src_tables:
                    report.append((table.name, 0, 0, '來源沒有這張表（略過）'))
                    continue
                src_cols = {c['name'] for c in src_insp.get_columns(table.name)}
                cols = [c for c in table.columns if c.name in src_cols]
                missing_in_src = [c.name for c in table.columns if c.name not in src_cols]
                col_sql = ', '.join(f'"{c.name}"' for c in cols)
                raw_rows = sconn.execute(text(f'SELECT {col_sql} FROM "{table.name}"')).fetchall()
                rows = []
                try:
                    for raw in raw_rows:
                        rows.append({c.name: convert(c, v, args.truncate, oversize, nulls_filled) for c, v in zip(cols, raw)})
                except Exception as e:
                    failed.append((table.name, f'資料轉換失敗：{e}'))
                    report.append((table.name, len(raw_rows), 0, '失敗'))
                    continue
                try:
                    with dst.begin() as dconn:
                        dconn.execute(text('SET FOREIGN_KEY_CHECKS=0'))
                        for i in range(0, len(rows), BATCH):
                            dconn.execute(table.insert(), rows[i:i + BATCH])
                        dconn.execute(text('SET FOREIGN_KEY_CHECKS=1'))
                    note = f'來源缺欄位 {", ".join(missing_in_src)}（補 NULL/預設）' if missing_in_src else ''
                    report.append((table.name, len(raw_rows), len(rows), note))
                except Exception as e:
                    failed.append((table.name, str(e).splitlines()[0][:200]))
                    report.append((table.name, len(raw_rows), 0, '失敗'))

        print('標記 Alembic 遷移版本…')
        stamp()

        print('\n核對筆數：')
        bad = 0
        with dst.connect() as dconn:
            for name, n_src, n_ins, note in report:
                n_dst = dconn.execute(text(f'SELECT COUNT(*) FROM `{name}`')).scalar() if name in src_tables else 0
                mark = 'OK ' if n_src == n_dst else 'XX '
                if n_src != n_dst:
                    bad += 1
                print(f'  {mark}{name:<32} SQLite {n_src:>6}  →  MySQL {n_dst:>6}  {note}')

    if nulls_filled:
        print('\nNOT NULL 欄位的 NULL 舊資料已補值：')
        for (t, c), n in nulls_filled.items():
            print(f'  {t}.{c}: {n} 筆 → {NULL_FIXUPS.get((t, c), "模型預設值/空值")!r}')
    if oversize:
        print('\n以下欄位內容超過模型定義的長度（SQLite 不檢查長度，MySQL 會）：')
        seen = set()
        for t, c, got, limit in oversize:
            if (t, c) in seen:
                continue
            seen.add((t, c))
            n = sum(1 for x in oversize if x[0] == t and x[1] == c)
            print(f'  {t}.{c}: {n} 筆超過 {limit} 字（最長 {max(x[2] for x in oversize if x[0] == t and x[1] == c)}）'
                  + ('，已截斷' if args.truncate else '，請加大 models.py 的長度後重跑，或加 --truncate 截斷'))
    if failed:
        print('\n失敗的資料表：')
        for t, msg in failed:
            print(f'  {t}: {msg}')
        sys.exit(1)
    if bad:
        sys.exit(1)
    print('\n搬移完成。接著 docker compose up -d 啟動 api / admin 即可。')


if __name__ == '__main__':
    main()
