from flask import Blueprint, request, jsonify
import google.generativeai as genai

# 建立 Blueprint
tutor_bp = Blueprint('tutor', __name__)

# ==========================================
# 1. 設定您的 API Key 
# (注意：請將下方字串換成您申請到的 API Key)
# 未來專題上線時，建議把它移到 .env 環境變數檔案中會更安全喔！
# ==========================================
GEMINI_API_KEY = "YOUR_API_KEY_HERE" 
genai.configure(api_key=GEMINI_API_KEY)

# 2. 初始化 Gemini 模型 (使用目前最快且免費額度高的 flash 模型)
model = genai.GenerativeModel('gemini-1.5-flash')

@tutor_bp.route('/ask', methods=['POST'])
def ask_question():
    try:
        # 接收前端傳來的問題
        data = request.get_json()
        question = data.get('question', '')

        if not question:
            return jsonify({'error': '沒有收到問題喔'}), 400

        # 3. 設計 AI 的「人設」(Prompt Engineering)
        # 告訴 AI 它現在扮演什麼角色，這會讓回覆更像一個家教
        prompt = f"""
        你現在是一位專業、親切且有耐心的「日文家教老師」。
        請用繁體中文回答學生的日文問題。
        你的回答必須：
        1. 語氣溫柔鼓勵。
        2. 解釋清晰易懂，不要用太艱澀的語言學術語。
        3. 針對學生的問題，提供 1~2 個實用的日文例句（包含假名注音與中文翻譯）。
        
        學生的問題是：「{question}」
        """

        # 4. 呼叫 Gemini 產生回答
        response = model.generate_content(prompt)
        ai_answer = response.text

        # 5. 將真正 AI 的答案回傳給前端
        return jsonify({'answer': ai_answer}), 200

    except Exception as e:
        print(f"AI 家教 API 發生錯誤: {e}")
        return jsonify({'error': 'AI 伺服器發生內部錯誤，請檢查後端終端機'}), 500