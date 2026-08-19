from flask import Blueprint, request, jsonify
import os
import google.generativeai as genai
from dotenv import load_dotenv

# 建立 Blueprint
tutor_bp = Blueprint('tutor', __name__)

# 1. 初始化金鑰
_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(_BASE_DIR, '.env'), override=True)
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# 2. 建立一個專門負責聊天的函數
def get_ai_reply(topic, user_message, chat_history, japanese_level, dialect_id=None):
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
        5. 中文應對教學：如果使用者是用「中文」發言，代表他可能還不知道這句話用日語怎麼說。這時請你扮演貼心的家教：
           (1) 先用繁體中文簡短回應他想表達的意思，讓他知道你聽懂了。
           (2) 接著教他：「這句話用日語可以這樣說：」，給出符合他 JLPT {japanese_level} 程度的日語說法（附上假名讀音與中文翻譯）。
           (3) 最後溫柔地鼓勵他試著用日語說一次，並以你扮演的角色把情境對話接下去。
           如果使用者是用日語發言，就照常進行日語情境對話，不需要進入教學模式。
        6. 排版規則（非常重要，請嚴格遵守）：
           - 你的回覆會直接以「純文字」顯示，絕對不要使用任何 Markdown 符號（如 ** 、 * 、 # 、 - 、 ` ）。
           - 每一句日文獨立成一行。
           - 該句的繁體中文翻譯放在「下一行」，用全形括號（）包住。
           - 不同段落（例如：回應、教學、反問）之間空一行，方便閱讀。
           - 回覆保持簡潔，不要一次塞太多內容。
        7. 漢字標音規則（非常重要）：
           - 日文句子裡「每一個漢字詞」都要加上假名標音，格式固定為 [漢字|假名]。
           - 例如：私 要寫成 [私|わたし]、散歩 要寫成 [散歩|さんぽ]。
           - 一個詞彙的漢字連在一起時整組標音，例如 [公園|こうえん]，不要拆成 [公|こう][園|えん]。
           - 送假名不要包進去，例如「好きです」要寫成 [好|す]きです。
           - 假名（平假名、片假名）本身不需要標音。
           - 中文翻譯的部分「絕對不要」加任何標音。
        """

        # 👇 依使用者選擇的腔調，加入對應的說話方式指令
        if dialect_id:
            from models import Dialect
            dialect = Dialect.query.filter_by(id=dialect_id, is_active=True).first()
            if dialect:
                prompt += f"\n        8. 腔調要求：{dialect.prompt_instruction}"

        if user_message == "[幫我開場]":
            prompt += "\n現在是這個情境的剛開始。請直接用你扮演的角色，熱情或專業地說出一句符合該場景的開場白，並拋出第一個問題或動作！一句話就好，讓使用者有機會回應。"
        else:
            # 第一句話時沒有歷史紀錄，就不要放空的「對話紀錄」段落誤導 AI
            if chat_history and chat_history.strip():
                prompt += (f"\n這是我們之前的對話紀錄（請延續這個脈絡，記得前面提過的人事物）：\n"
                           f"{chat_history}\n")
            prompt += (f"\n使用者剛剛對你說了這句話：「{user_message}」\n"
                       f"請自然地回覆使用者，並記得拋出下一個問題。")

        # 呼叫 Gemini
        print("🔍 準備呼叫 Gemini API...")
        response = _client.models.generate_content(model='gemini-2.5-flash', contents=prompt)
        print("✅ Gemini 回覆完成！")
        return response.text, True   # (回覆內容, 是否成功)

    except gemini_client.GeminiQuotaExhausted as e:
        # 額度用完：明確說明原因，不要讓使用者以為是暫時故障而一直重試
        return str(e)

    except gemini_client.GeminiNotConfigured as e:
        print(f"⚠️ {e}")
        return "AI 對話服務尚未設定完成，請聯繫開發人員。"

    except Exception as e:
        
        print(f"🚨 抓到 Gemini API 錯誤了：{e}")
        if gemini_client.is_overloaded_error(e):
            return "現在使用的人比較多，請稍等幾秒再送出一次！"
        return "系統小精靈有點累了，請稍後再試一次！"