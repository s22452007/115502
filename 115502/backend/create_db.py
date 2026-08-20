from app import app
from models import db

# 建立所有還沒被建立的資料表
with app.app_context():
    db.create_all()
    print("✅ 資料表建立/更新完成！")