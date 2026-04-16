from flask import Blueprint, request, jsonify
import os
import google.generativeai as genai
from dotenv import load_dotenv

# 建立 Blueprint
tutor_bp = Blueprint('tutor', __name__)

# 1. 初始化金鑰 (放在這裡，app.py 就不用管金鑰了)
load_dotenv(override=True)
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
model = genai.GenerativeModel('gemini-1.5-flash')

# 2. 建立一個專門負責聊天的函數
def get_ai_reply(topic, user_message, chat_history, japanese_level):
    try:
        prompt = f"""
        【系統設定】
        你現在是一個專業的日語會話陪練員。
        使用者目前選擇的模擬情境 / 主題是：「{topic}」

        【你的任務】
        1. 角色扮演：請根據「{topic}」這個主題，自動判斷並扮演最適合的角色。
        
        # 👇 2. 這裡原本寫死的 N5~N4，換成活的變數！
        2. 語言程度：請嚴格使用符合 JLPT {japanese_level} 程度的單字與文法，與使用者進行自然對話。如果使用者的程度較初階（如 N5），請盡量使用簡單、簡短的句子。
        
        3. 引導對話：每次回覆的最後，務必「反問一個問題」或「做出一個情境引導」。
        4. 雙語輸出：請在每一句日文的下方，換行並附上（簡單的繁體中文翻譯）。
        """

        if user_message == "[幫我開場]":
            prompt += "\n現在是這個情境的剛開始。請直接用你扮演的角色，熱情或專業地說出一句符合該場景的開場白，並拋出第一個問題或動作！"
        else:
            prompt += f"\n這是我們之前的對話紀錄：\n{chat_history}\n\n使用者剛剛對你說了這句話：「{user_message}」\n請自然地回覆使用者，並記得拋出下一個問題。"

        # 呼叫 Gemini
        print("🔍 準備呼叫 Gemini API...")  # 👈 加這行
        response = model.generate_content(prompt)
        print("✅ Gemini 回覆完成！")       # 👈 加這行
        return response.text

    except Exception as e:
        
        print(f"🚨 抓到 Gemini API 錯誤了：{e}")
        return "系統小精靈有點累了，請稍後再試一次！"