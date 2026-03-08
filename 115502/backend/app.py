import os
from flask import Flask
from flask_cors import CORS
from utils.db import db
from services.quiz import quiz_bp

# 1. 自動抓取 app.py 所在的絕對路徑 (也就是 backend 資料夾的位置)
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

app = Flask(__name__)
CORS(app) # 允許跨網域請求

# 2. 強制把資料庫路徑綁定在 backend/instance/jlens.db
# os.path.join 會幫你把路徑安全地接起來 (不管你是 Windows 還是 Mac 都不會出錯)
instance_path = os.path.join(BASE_DIR, 'instance')
db_path = os.path.join(instance_path, 'jlens.db')

# 3. 防呆機制：如果 instance 資料夾還不存在，就自動幫你建一個
os.makedirs(instance_path, exist_ok=True)

# 設定 SQLite 資料庫，使用絕對路徑
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 初始化資料庫
db.init_app(app)

# 註冊 API 路由 (這樣剛剛寫的 API 網址就會是 http://127.0.0.1:5000/api/quiz/submit )
app.register_blueprint(quiz_bp, url_prefix='/api/quiz')

# 啟動時自動建立資料表
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    print("🚀 後端伺服器啟動中...")
    print(f"📁 資料庫已牢牢綁定於: {db_path}") 
    app.run(debug=True, port=5000)