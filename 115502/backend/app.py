import os
from flask import Flask
from flask_cors import CORS
from utils.db import db
from flask import request

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

if __name__ == '__main__':
    print("[Startup] 後端伺服器啟動中...")
    print(f"[Database] 資料庫已牢牢綁定於: {db_path}") 

    # 加上 host='0.0.0.0' 代表允許區域網路內的所有設備連線
    app.run(host='0.0.0.0', port=5000, debug=True)

# 🌟 把 chat 路由搬到這裡！(在 app.run 的上面)
@app.route('/api/chat', methods=['POST'])
def chat():
    # 1. 接收從 Flutter 傳過來的日文訊息
    user_message = request.form.get('message', '')
    
    print(f"收到來自 App 的訊息：{user_message}") # 印在終端機讓你檢查

    # 3. 我們先寫死一句話，測試「前後端有沒有成功通訊」
    ai_reply = f"Python 後端收到你的「{user_message}」囉！Gemini 準備中..."
    
    # 4. 把字串回傳給 Flutter 畫面
    return ai_reply


# 🛑 app.run 必須永遠在整個檔案的最下面！
if __name__ == '__main__':
    print("[Startup] 後端伺服器啟動中...")
    print(f"[Database] 資料庫已牢牢綁定於: {db_path}") 

    # 加上 host='0.0.0.0' 代表允許區域網路內的所有設備連線
    app.run(host='0.0.0.0', port=5000, debug=True)