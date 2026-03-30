from flask import Blueprint, request, jsonify
import time

# 建立 Blueprint
tutor_bp = Blueprint('tutor', __name__)

# 這裡的路由是 '/ask'，稍後在 app.py 註冊時會加上 '/api/tutor' 的前綴
# 所以完整的網址會剛好是 Flutter 呼叫的 /api/tutor/ask
@tutor_bp.route('/ask', methods=['POST'])
def ask_question():
    try:
        # 1. 接收前端傳來的問題
        data = request.get_json()
        question = data.get('question', '')

        if not question:
            return jsonify({'error': '沒有收到問題喔'}), 400

        # 2. 模擬 AI 思考時間 (讓前端的轉圈圈有時間展示)
        time.sleep(1.5) 

        # 3. 產生模擬回覆 (確認連線後，未來可以把這裡換成呼叫 ChatGPT API 的程式碼)
        mock_answer = f"您好！您剛剛問了：「{question}」。\n\n這是一個測試回覆，代表您的 Flutter 前端與 Flask 後端已經成功連線囉！未來把 ChatGPT 串接在這裡就可以開始當日文家教了！"

        # 4. 將答案回傳給前端
        return jsonify({'answer': mock_answer}), 200

    except Exception as e:
        print(f"家教 API 發生錯誤: {e}")
        return jsonify({'error': '伺服器發生內部錯誤'}), 500