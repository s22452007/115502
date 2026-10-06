# ⚠️ 只適用 SQLite（instance/jlens.db）的舊版工具。資料表結構現在由 migrations/ 管理、啟動時自動套用；伺服器改用 MySQL 後此腳本不適用。
import sqlite3
conn = sqlite3.connect('instance/jlens.db')
conn.execute("UPDATE user SET photo_extra_count = 0 WHERE id = 3")
conn.commit()
print('done')
conn.close()
