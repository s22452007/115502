import sqlite3
conn = sqlite3.connect('instance/jlens.db')
conn.execute("UPDATE user SET photo_extra_count = 0 WHERE id = 3")
conn.commit()
print('done')
conn.close()
