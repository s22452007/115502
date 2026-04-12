import os
import google.generativeai as genai
from dotenv import load_dotenv

# 1. 初始化金鑰 (放在這裡，app.py 就不用管金鑰了)
load_dotenv(override=True)
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel('gemini-2.5-flash')

# 2. 建立一個專門負責聊天的函數
def get_ai_reply(topic, user_message, chat_history):
    try:
        prompt = f"""
        【系統設定】
        你現在是一個專業的日語會話陪練員。
        使用者目前選擇的模擬情境 / 主題是：「{topic}」

        【你的任務】
        1. 角色扮演：請根據「{topic}」這個主題，自動判斷並扮演最適合的角色。
        2. 語言程度：請使用符合 JLPT N5~N4 程度的自然日文與使用者對話。
        3. 引導對話：每次回覆的最後，務必「反問一個問題」或「做出一個情境引導」。
        4. 雙語輸出：請在每一句日文的下方，換行並附上（簡單的繁體中文翻譯）。
        """

        if user_message == "[幫我開場]":
            prompt += "\n現在是這個情境的剛開始。請直接用你扮演的角色，熱情或專業地說出一句符合該場景的開場白，並拋出第一個問題或動作！"
        else:
            prompt += f"\n這是我們之前的對話紀錄：\n{chat_history}\n\n使用者剛剛對你說了這句話：「{user_message}」\n請自然地回覆使用者，並記得拋出下一個問題。"

        # 呼叫 Gemini
        response = model.generate_content(prompt)
        return response.text

    except Exception as e:
        print(f"❌ 廚房發生錯誤: {e}")
        return "系統小精靈有點累了，請稍後再試一次！"