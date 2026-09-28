"""後台登不進去時的自我檢查工具（組員自己跑，把輸出貼給負責人）。

    py -3 check_admin_db.py                 # 只檢查，不改任何東西
    py -3 check_admin_db.py --reset 11156015  # 把該管理員密碼重設成學號，下次登入會要求改密碼
"""
import os
import sqlite3
import subprocess
import sys

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, BASE_DIR)
# Windows 終端機預設 cp950，中文與 git 輸出會變亂碼
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

print('=' * 60)
print('1. 程式碼版本')
try:
    print('   目前 commit:', subprocess.check_output(['git', 'log', '--oneline', '-1'], cwd=BASE_DIR, encoding='utf-8', errors='replace').strip())
    print('   （修登入 500 的 commit 是 4dd9263，沒有的話請先 git pull）')
except Exception as e:
    print('   讀不到 git 資訊:', e)

print('\n2. 資料庫位置')
path1 = os.path.join(BASE_DIR, 'instance', 'jlens.db')
path2 = os.path.join(BASE_DIR, 'jlens.db')
db_path = path1 if os.path.exists(path1) else path2
print('   後台實際使用:', db_path, '(存在)' if os.path.exists(db_path) else '(不存在！啟動時會建一個空的)')
if not os.path.exists(db_path):
    sys.exit('   → 沒有資料庫。請向負責人拿一份 jlens.db 放到 backend/instance/ 底下。')

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

print('\n3. admin 資料表欄位')
cols = [r['name'] for r in conn.execute('PRAGMA table_info(admin)')]
if not cols:
    sys.exit('   → 沒有 admin 資料表，這份資料庫不對。請向負責人拿一份 jlens.db。')
print('  ', cols)
for need in ('role', 'is_active', 'must_change_password', 'last_login_at'):
    print(f'   {need:22s}', '有' if need in cols else '缺 ← 啟動最新版 admin_app.py 會自動補')

print('\n4. 管理員帳號')
select_cols = [c for c in ('id', 'username', 'role', 'is_active', 'must_change_password') if c in cols]
rows = conn.execute(f'SELECT {", ".join(select_cols)} FROM admin').fetchall()
if not rows:
    print('   admin 表是空的 → 請執行 py -3 init_admins.py 建立預設帳號（密碼＝學號）')
for r in rows:
    print('  ', dict(r))

reset = None
if '--reset' in sys.argv:
    idx = sys.argv.index('--reset')
    reset = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else None
if reset:
    from werkzeug.security import generate_password_hash
    if not conn.execute('SELECT 1 FROM admin WHERE username = ?', (reset,)).fetchone():
        sys.exit(f'\n   找不到管理員 {reset}')
    sets = 'password_hash = ?'
    params = [generate_password_hash(reset)]
    if 'must_change_password' in cols:
        sets += ', must_change_password = 1'
    if 'is_active' in cols:
        sets += ', is_active = 1'
    conn.execute(f'UPDATE admin SET {sets} WHERE username = ?', params + [reset])
    conn.commit()
    print(f'\n5. 已把 {reset} 的密碼重設成學號「{reset}」，並確保帳號啟用；登入後會要求改密碼')

conn.close()
print('=' * 60)
print('請把上面整段輸出，連同「登入時畫面上的錯誤文字」一起貼給負責人。')
