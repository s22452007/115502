import os
from dotenv import load_dotenv
from flask import Flask, request
from flask_cors import CORS
from utils.db import db

# 匯入各個模組的 Blueprint
from services.quiz import quiz_bp
from services.auth import auth_bp
from services.scenario import scenario_bp
from services.user import user_bp
from services.group import group_bp
from services.vocabulary import vocab_bp
from services.tutor import tutor_bp

# 👨‍🍳 引入內場廚師 (AI 聊天函數)
from services.tutor import get_ai_reply

# 自動抓取 app.py 所在的絕對路徑
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

app = Flask(__name__)
CORS(app) # 允許跨網域請求

print("================ 我是最新版、超乾淨的 app.py 喔喔喔 ================")

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
app.register_blueprint(auth_bp, url_prefix='/api/auth')    
app.register_blueprint(scenario_bp, url_prefix='/api/scenario')
app.register_blueprint(user_bp, url_prefix='/api/user')    
app.register_blueprint(group_bp, url_prefix='/api/group')  
app.register_blueprint(vocab_bp, url_prefix='/api/vocab')  
app.register_blueprint(tutor_bp, url_prefix='/api/tutor')  

# 啟動時自動建立資料表
with app.app_context():
    db.create_all()

# ==========================================
# 🛎️ 專屬櫃檯：負責接收 Flutter 傳來的聊天包裹
# ==========================================
@app.route('/api/chat', methods=['POST'])
def chat():
    # 1. 櫃檯接單（把所有 Flutter 傳來的變數收下來）
    user_message = request.form.get('message', '')
    chat_history = request.form.get('history', '') 
    topic = request.form.get('topic', '日常對話') 
    user_level = request.form.get('level', 'N5') # 🌟 接收等級！如果 App 沒傳，預設當作 N5

    print(f"📦 收到包裹 -> 主題：{topic} | 等級：{user_level} | 訊息：{user_message}")

    # 2. 把食材交給內場廚師 (呼叫 tutor.py 的函數，記得把 user_level 也傳進去)
    ai_response_text = get_ai_reply(topic, user_message, chat_history, user_level)

    # 3. 櫃檯送餐（把熱騰騰的 AI 回覆送回給 Flutter）
    return ai_response_text

# ==========================================

# 🛑 app.run 必須永遠在整個檔案的最下面！
if __name__ == '__main__':
    print("[Startup] 後端伺服器啟動中...")
    print(f"[Database] 資料庫已牢牢綁定於: {db_path}") 

    # 加上 host='0.0.0.0' 代表允許區域網路內的所有設備連線
    app.run(host='0.0.0.0', port=5000, debug=True)