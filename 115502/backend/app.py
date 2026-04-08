import os
from dotenv import load_dotenv
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


@app.route('/api/chat', methods=['POST'])
def chat():
    # 1. 接收從 Flutter 傳過來的日文訊息
    user_message = request.form.get('message', '')
    print(f"收到來自 App 的訊息：{user_message}") 

    try:
        # 強迫抓取最新 .env
        load_dotenv(override=True)
        
        # 抓取金鑰
        my_secret_key = os.getenv("GEMINI_API_KEY") 
        print(f"🕵️ 攔截到的金鑰：{my_secret_key}")

        # 把鑰匙交給 Gemini
        genai.configure(api_key=my_secret_key)

        model = genai.GenerativeModel('gemini-1.5-flash')
        prompt = f"""
        你現在是一個親切的日語對話小幫手。
        使用者說了這句話：「{user_message}」
        請用符合 N5~N4 程度的自然日文回覆他，並且在日文後面附上簡單的中文翻譯。
        回覆請盡量簡短，像真人在聊天一樣。
        """

        # 請 AI 產生回覆
        response = model.generate_content(prompt)
        ai_reply = response.text

    except Exception as e:
        print(f"呼叫 Gemini 時發生錯誤: {e}")
        ai_reply = "系統小精靈有點累了，請稍後再試一次！"
    
    # 把熱騰騰的 AI 回覆送回給 Flutter
    return ai_reply

# 🛑 app.run 必須永遠在整個檔案的最下面！
if __name__ == '__main__':
    print("[Startup] 後端伺服器啟動中...")
    print(f"[Database] 資料庫已牢牢綁定於: {db_path}") 

    # 加上 host='0.0.0.0' 代表允許區域網路內的所有設備連線
    app.run(host='0.0.0.0', port=5000, debug=True)