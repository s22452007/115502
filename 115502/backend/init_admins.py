"""建立預設管理員帳號（SQLite、MySQL 都適用，依 .env 的 DATABASE_URL 決定連哪個）。

用法（在 backend 資料夾執行）：
    py -3 init_admins.py
    docker compose exec api python init_admins.py      # 伺服器上在容器裡跑

帳號＝學號、預設密碼＝學號，第一次登入後台會被要求立刻改密碼；已存在的帳號不會動。
資料表若還沒建好，匯入 admin_app 時會自動建立（utils/db.init_database）。
"""
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

from admin_app import app
from utils.db import db, safe_uri
from models import Admin

admin_ids = ['11156001', '11156006', '11156015', '11156039', '11156047']


def init_default_admins():
    with app.app_context():
        print(f"👤 開始初始化管理員帳號（資料庫：{safe_uri(str(db.engine.url))}）...")
        for uid in admin_ids:
            if Admin.query.filter_by(username=uid).first():
                print(f"⚠️ 帳號 {uid} 已經存在，跳過。")
                continue
            # 統一給予 super_admin 權限；預設密碼＝學號，第一次登入會被要求立刻改掉
            admin = Admin(username=uid, role='super_admin', is_active=True, must_change_password=True)
            admin.set_password(uid)
            db.session.add(admin)
            print(f"✅ 帳號 {uid} 建立成功！(預設密碼: {uid}，首次登入需修改)")
        db.session.commit()
        print("🎉 管理員帳號初始化完成！")


if __name__ == '__main__':
    init_default_admins()
