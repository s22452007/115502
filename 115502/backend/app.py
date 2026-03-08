from flask import Flask
from flask_cors import CORS
from utils.db import db
from services.quiz import quiz_bp

app = Flask(__name__)
CORS(app) # 允許跨網域請求

# 設定 SQLite 資料庫，檔案會自動產生在 backend 資料夾下，名為 jlens.db
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///jlens.db'
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
    app.run(debug=True, port=5000)