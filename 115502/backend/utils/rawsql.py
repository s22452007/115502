"""後台原本用 sqlite3 直接寫的原生 SQL，改走 SQLAlchemy 的連線（db.engine）。

這樣後台跟 App API 共用同一份連線設定，SQLite、MySQL 都能跑，不再有第二套只認 SQLite 的連線。
用法跟 sqlite3 幾乎一樣：
    conn = RawConnection(db.engine)
    row = conn.execute('SELECT id, name FROM user WHERE id = ?', (user_id,)).fetchone()
    row[0], row['name'], dict(row)      # 三種取值方式都支援（跟 sqlite3.Row 一樣）
    conn.commit(); conn.close()

取出的值會整理成跟 SQLite 一樣的型別：MySQL 回傳的 datetime / date 轉成 'YYYY-MM-DD HH:MM:SS' / 'YYYY-MM-DD' 字串、
SUM / AVG 的 Decimal 轉成 int / float，後台原本針對 SQLite 字串寫的切片、比較、模板都不用改。
"""
from datetime import date, datetime, time as dtime
from decimal import Decimal

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError as DBError  # 後台 except 用，取代 sqlite3.Error

__all__ = ['RawConnection', 'RawRow', 'DBError', 'convert_qmarks', 'normalize_value']


def convert_qmarks(sql, params=()):
    """把 sqlite3 風格的 ? 佔位符換成 SQLAlchemy 的 :p0、:p1…（跳過引號裡的問號）。"""
    if isinstance(params, dict):
        return sql, params
    params = list(params or ())
    out, binds, idx, quote = [], {}, 0, None
    for ch in sql:
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
        elif ch in ("'", '"'):
            quote = ch
            out.append(ch)
        elif ch == '?':
            if idx >= len(params):
                raise ValueError('SQL 的 ? 數量比參數多')
            key = f'p{idx}'
            binds[key] = params[idx]
            out.append(':' + key)
            idx += 1
        else:
            out.append(ch)
    if idx != len(params):
        raise ValueError('SQL 的 ? 數量比參數少')
    return ''.join(out), binds


def normalize_value(v):
    """把 MySQL 驅動回傳的型別整理成 SQLite 會回傳的型別（字串時間、int/float）"""
    if isinstance(v, datetime):
        s = v.strftime('%Y-%m-%d %H:%M:%S')
        return s + f'.{v.microsecond:06d}' if v.microsecond else s
    if isinstance(v, date):
        return v.isoformat()
    if isinstance(v, dtime):
        return v.strftime('%H:%M:%S')
    if isinstance(v, Decimal):
        return int(v) if v == v.to_integral_value() else float(v)
    if isinstance(v, (bytes, bytearray)):
        try:
            return v.decode('utf-8')
        except UnicodeDecodeError:
            return bytes(v)
    return v


class RawRow(tuple):
    """同時支援 row[0]、row['col']、row.col、dict(row)、tuple 解包"""

    def __new__(cls, sa_row):
        values = tuple(normalize_value(v) for v in sa_row)
        self = tuple.__new__(cls, values)
        self._mapping = dict(zip(sa_row._mapping.keys(), values))
        return self

    def __getitem__(self, key):
        if isinstance(key, str):
            return self._mapping[key]
        return tuple.__getitem__(self, key)

    def __getattr__(self, name):
        try:
            return self._mapping[name]
        except KeyError:
            raise AttributeError(name)

    def keys(self):
        return list(self._mapping.keys())

    def get(self, key, default=None):
        return self._mapping.get(key, default)


class RawCursor:
    def __init__(self, result):
        self._result = result

    def fetchone(self):
        row = self._result.fetchone()
        return RawRow(row) if row is not None else None

    def fetchall(self):
        return [RawRow(r) for r in self._result.fetchall()]

    def __iter__(self):
        for r in self._result:
            yield RawRow(r)

    @property
    def lastrowid(self):
        return self._result.lastrowid

    @property
    def rowcount(self):
        return self._result.rowcount


class RawConnection:
    def __init__(self, engine):
        self._conn = engine.connect()

    def execute(self, sql, params=()):
        sql, binds = convert_qmarks(sql, params)
        return RawCursor(self._conn.execute(text(sql), binds))

    def commit(self):
        self._conn.commit()

    def rollback(self):
        self._conn.rollback()

    def close(self):
        self._conn.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()
