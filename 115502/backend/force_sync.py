from app import app
from models import db, SentencePracticeRecord

with app.app_context():
    # 1. 強制刪除舊的 (有缺失欄位的) 造句紀錄表
    print("🗑️ 正在刪除舊的 SentencePracticeRecord 資料表...")
    SentencePracticeRecord.__table__.drop(db.engine, checkfirst=True)
    
    # 2. 依照 models.py 最新定義重新建立
    print("✨ 正在建立全新的 SentencePracticeRecord 資料表...")
    SentencePracticeRecord.__table__.create(db.engine, checkfirst=True)
    
    print("✅ 造句資料表強制刷新成功！現在欄位已經完全對齊了！")