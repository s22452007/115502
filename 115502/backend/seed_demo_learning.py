"""後台「學習小組總覽」「造句與朗讀紀錄」的示範資料。

在資料庫加入 10 位示範使用者，以及他們的學習小組、造句紀錄、朗讀成績，
讓後台頁面有資料可以看（例如報告 demo）。示範帳號一律是 demoN@example.com，
不會動到任何既有使用者的資料。

用法（在 backend 資料夾執行）：
    python seed_demo_learning.py           # 加入示範資料（會先清掉上一次加入的）
    python seed_demo_learning.py --clean   # 只清除示範資料

注意：學習小組是一週挑戰制，「進行中」的示範小組到下週就會變成「已過週待結算」，
想重新看到各種狀態時再執行一次即可。
"""
import argparse
import json
import os
import sqlite3
from datetime import datetime, timedelta

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DEFAULT_DB = os.path.join(BASE_DIR, 'instance', 'jlens.db')

# 用 email 與交友 ID 兩個條件一起辨識示範帳號，避免誤刪真實使用者
DEMO_EMAIL_PATTERN = 'demo%@example.com'
DEMO_FRIEND_ID_PATTERN = 'DEMO%'

DEMO_USERS = [  # (暱稱, 日語等級, 大頭貼)
    ('雅婷', 'N4', '🐱'), ('小明', 'N4', '🐶'), ('志豪', 'N4', None), ('怡君', 'N3', '🐰'),
    ('冠宇', 'N3', None), ('佳穎', 'N3', '🦊'), ('宗翰', 'N5', '🐻'), ('詩涵', 'N5', None),
    ('柏宇', 'N5', '🐧'), ('心怡', 'N4', '🦄'),
]

GOAL_COLUMNS = {
    'scans': 'group_scans', 'points': 'group_points', 'logins': 'group_logins',
    'sentences': 'group_sentences', 'articles': 'group_articles',
}


def _columns(conn, table):
    return {r[1]: r for r in conn.execute(f'PRAGMA table_info({table})').fetchall()}


def _insert(conn, table, now, **vals):
    """只寫入資料表實際存在的欄位，其餘 NOT NULL 又沒有預設值的欄位補上空值"""
    cols = _columns(conn, table)
    vals = {k: v for k, v in vals.items() if k in cols}
    for name, (_, _, typ, notnull, default, pk) in cols.items():
        if pk or name in vals or not notnull or default is not None:
            continue
        t = (typ or '').upper()
        vals[name] = 0 if ('INT' in t or 'BOOL' in t) else (str(now) if ('DATE' in t or 'TIME' in t) else '')
    placeholders = ', '.join('?' * len(vals))
    cur = conn.execute(f'INSERT INTO {table} ({", ".join(vals)}) VALUES ({placeholders})', list(vals.values()))
    return cur.lastrowid


def _points(score):
    # 與 services/sentence.py、services/article.py 的發點規則相同
    return 50 if score >= 90 else (30 if score >= 80 else (10 if score >= 60 else 5))


def clean(conn):
    ids = [r[0] for r in conn.execute(
        'SELECT id FROM user WHERE email LIKE ? AND friend_id LIKE ?',
        (DEMO_EMAIL_PATTERN, DEMO_FRIEND_ID_PATTERN)).fetchall()]
    if not ids:
        return 0
    ph = ', '.join('?' * len(ids))

    group_ids = [r[0] for r in conn.execute(
        f'SELECT DISTINCT group_id FROM group_member WHERE user_id IN ({ph})', ids).fetchall()]
    conn.execute(f'DELETE FROM group_invite WHERE sender_id IN ({ph}) OR receiver_id IN ({ph})', ids + ids)

    # 所有帶 user_id 的資料表（小組成員、造句、朗讀……）一律清掉示範帳號的資料
    tables = [r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type = 'table'").fetchall()]
    for table in tables:
        if table != 'user' and 'user_id' in _columns(conn, table):
            conn.execute(f'DELETE FROM {table} WHERE user_id IN ({ph})', ids)
    if 'friendship' in tables and 'friend_id' in _columns(conn, 'friendship'):
        conn.execute(f'DELETE FROM friendship WHERE friend_id IN ({ph})', ids)

    # 只刪掉「示範成員離開後已經沒有人」的小組，真實使用者也在的小組不動
    for gid in group_ids:
        if conn.execute('SELECT COUNT(*) FROM group_member WHERE group_id = ?', (gid,)).fetchone()[0] == 0:
            conn.execute('DELETE FROM group_invite WHERE group_id = ?', (gid,))
            conn.execute('DELETE FROM study_group WHERE id = ?', (gid,))

    conn.execute(f'DELETE FROM user WHERE id IN ({ph})', ids)
    return len(ids)


def seed(conn):
    now = datetime.utcnow()
    users = {}
    for i, (name, level, avatar) in enumerate(DEMO_USERS, start=1):
        users[name] = _insert(conn, 'user', now,
                              email=f'demo{i}@example.com', password_hash='!demo-account-cannot-login',
                              username=name, friend_id=f'DEMO{i:03d}', japanese_level=level,
                              avatar=avatar, j_pts=120, account_type='general',
                              created_at=now - timedelta(days=30))

    # ---- 學習小組：進行中、已達標、已過週待結算各一種 ----
    def add_group(name, goal_type, target, progress, created, members, invite_to=None):
        gid = _insert(conn, 'study_group', now, name=name, goal_type=goal_type, goal_target=target,
                      current_progress=progress, created_at=created)
        for who, contribution, deposit in members:
            _insert(conn, 'group_member', now, group_id=gid, user_id=users[who], joined_at=created,
                    has_claimed=0, paid_deposit=1 if deposit else 0, deposit_amount=deposit,
                    **{GOAL_COLUMNS[goal_type]: contribution})
        if invite_to:
            _insert(conn, 'group_invite', now, group_id=gid, sender_id=users[members[0][0]],
                    receiver_id=users[invite_to], status='pending', created_at=now)

    add_group('N4 造句衝刺隊', 'sentences', 30, 18, now - timedelta(minutes=30),
              [('雅婷', 9, 20), ('小明', 6, 0), ('志豪', 3, 10)], invite_to='心怡')
    add_group('每天登入不偷懶', 'logins', 21, 21, now - timedelta(minutes=20),
              [('怡君', 7, 0), ('冠宇', 7, 20), ('佳穎', 7, 0)])
    add_group('拍照探險小隊', 'scans', 40, 23, now - timedelta(days=9),
              [('宗翰', 15, 20), ('詩涵', 8, 20)])
    add_group('閱讀馬拉松', 'articles', 10, 4, now - timedelta(minutes=10),
              [('柏宇', 3, 0), ('心怡', 1, 10)])

    # ---- 造句紀錄 ----
    sentences = [
        ('雅婷', '〜てもいいですか', ['写真'], 'ここで写真を撮ってもいいですか。', 'ここで写真を撮ってもいいですか。', '1. 文法使用正確，語意自然。', 95, 1),
        ('小明', '〜たことがある', ['富士山'], '私は富士山に登ったことがあります。', '私は富士山に登ったことがあります。', '1. 完全正確。', 90, 1),
        ('志豪', '〜ために', ['日本'], '日本に行くのために、お金を貯めます。', '日本に行くために、お金を貯めます。', '1. 文法錯誤：動詞辭書形直接接「ために」，不需要「の」', 62, 0),
        ('怡君', '〜てください', ['名前'], 'ここに名前を書いてください。', 'ここに名前を書いてください。', '1. 正確。', 88, 1),
        ('冠宇', '〜ために', ['健康'], '健康ために毎日走ります。', '健康のために毎日走ります。', '1. 助詞遺漏：名詞接「ために」要加「の」', 55, 0),
        ('佳穎', '〜つもりです', ['来年'], '来年日本へ行くつもりです。', '来年、日本へ行くつもりです。', '1. 語意正確\n2. 可在「来年」後加頓號，句子更自然', 85, 0),
        ('宗翰', '〜ために', [], '勉強するために図書館へ行きます。', '勉強するために図書館へ行きます。', '1. 正確。', 80, 1),
        ('詩涵', '〜てもいいですか', ['窓'], '窓を開けるもいいですか。', '窓を開けてもいいですか。', '1. 變形錯誤：開ける 應改為 開けて', 40, 0),
        ('柏宇', '〜たことがある', ['寿司'], '寿司を食べることがあります。', '寿司を食べたことがあります。', '1. 變形錯誤：表示經驗要用た形「食べた」', 45, 0),
        ('心怡', '〜てください', ['ちょっと'], 'ちょっと待ってください。', 'ちょっと待ってください。', '1. 正確。', 92, 1),
    ]
    for i, (who, grammar, vocabs, sentence, corrected, feedback, score, claimed) in enumerate(sentences):
        _insert(conn, 'sentence_practice_record', now, user_id=users[who], grammar_point=grammar,
                selected_vocabs=json.dumps(vocabs, ensure_ascii=False), user_sentence=sentence,
                corrected_sentence=corrected, ai_feedback=feedback, score=score,
                points_earned=_points(score), is_claimed=claimed,
                created_at=now - timedelta(minutes=37 * (len(sentences) - i)))

    # ---- 朗讀成績（柏宇對同一篇唸 6 次，示範重複測驗偵測）----
    def article_ids(level):
        return [r[0] for r in conn.execute('SELECT id FROM articles WHERE level = ? ORDER BY id LIMIT 3', (level,))]

    n5, n4 = article_ids('N5'), article_ids('N4')
    pool = n5 + n4
    reading_count = 0
    if pool:
        pick = lambda ids, idx: ids[idx] if len(ids) > idx else pool[idx % len(pool)]
        readings = [('柏宇', pick(n5, 0), [58, 65, 72, 80, 88, 95]), ('雅婷', pick(n4, 0), [70, 82, 91]),
                    ('小明', pick(n5, 0), [76]), ('怡君', pick(n4, 1), [64]),
                    ('冠宇', pick(n5, 1), [45, 61]), ('心怡', pick(n5, 2), [93])]
        t = now - timedelta(hours=6)
        for who, article_id, scores in readings:
            for score in scores:
                t += timedelta(minutes=9)
                _insert(conn, 'score_record', now, user_id=users[who], article_id=article_id,
                        score=score, points_earned=_points(score), created_at=t)
                reading_count += 1

    return {'users': len(users), 'groups': 4, 'sentences': len(sentences), 'readings': reading_count}


def main():
    parser = argparse.ArgumentParser(description='後台學習成果頁面的示範資料')
    parser.add_argument('--clean', action='store_true', help='只清除示範資料')
    parser.add_argument('--db', default=DEFAULT_DB, help='資料庫路徑（預設 instance/jlens.db）')
    args = parser.parse_args()

    conn = sqlite3.connect(args.db)
    try:
        removed = clean(conn)
        if removed:
            print(f'已清除示範資料：{removed} 位示範使用者及其小組、造句、朗讀紀錄')
        if not args.clean:
            s = seed(conn)
            if not s['readings']:
                print('提醒：資料庫沒有任何文章，已略過朗讀成績（可先執行 seed_articles.py）')
            print(f"已加入示範資料：{s['users']} 位使用者、{s['groups']} 個學習小組、"
                  f"{s['sentences']} 筆造句、{s['readings']} 筆朗讀成績")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == '__main__':
    main()
