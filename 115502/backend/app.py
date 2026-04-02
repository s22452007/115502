import os
from flask import Flask
from flask_cors import CORS
from utils.db import db
from flask import request
import google.generativeai as genai

# 匯入各個模組的 Blueprint
from services.quiz import quiz_bp
from services.auth import auth_bp
from services.scenario import scenario_bp
from services.user import user_bp
from services.group import group_bp
from services.vocabulary import vocab_bp
from services.tutor import tutor_bp

# 自動抓取 app.py 所在的絕對路徑 (也就是 backend 資料夾的位置)
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

app = Flask(__name__)
CORS(app) # 允許跨網域請求

# 👇 加上這行暗號
print("================ 我是最新版的 app.py 喔喔喔 ================")

# 強制把資料庫路徑綁定在 backend/instance/jlens.db
instance_path = os.path.join(BASE_DIR, 'instance')
db_path = os.path.join(instance_path, 'jlens.db')

# 防呆機制：如果 instance 資料夾還不存在，就自動幫你建一個
os.makedirs(instance_path, exist_ok=True)

# 設定 SQLite 資料庫，使用絕對路徑
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 初始化資料庫
db.init_app(app)

# 註冊 API 路由 (綁定網址前綴)
app.register_blueprint(quiz_bp, url_prefix='/api/quiz')
app.register_blueprint(auth_bp, url_prefix='/api/auth')     # 登入、註冊用這個
app.register_blueprint(scenario_bp, url_prefix='/api/scenario')
app.register_blueprint(user_bp, url_prefix='/api/user')     # 個人資料、好友用這個
app.register_blueprint(group_bp, url_prefix='/api/group')   # 學習小組用這個
app.register_blueprint(vocab_bp, url_prefix='/api/vocab')   # 單字本用這個
app.register_blueprint(tutor_bp, url_prefix='/api/tutor')   # AI家教用這個

# 啟動時自動建立資料表
with app.app_context():
    db.create_all()


