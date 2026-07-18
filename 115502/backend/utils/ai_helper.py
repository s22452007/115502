import os
import json
from google import genai
from google.genai import types
from dotenv import load_dotenv

# 載入環境變數 (讀取 backend/.env 檔案中的 GEMINI_API_KEY)
# 特別加上 override=True，強制覆蓋終端機中可能殘留的舊變數（避免一直讀到舊金鑰）
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env_path = os.path.join(BASE_DIR, '.env')
load_dotenv(env_path, override=True)

def analyze_image_from_path(file_path):
    """
    使用 Google Gemini API 進行圖像分析與文字辨識。
    """
    try:
        # 1. 取得專屬照片辨識的 API Key 並設定
        api_key = os.environ.get("GEMINI_API_KEY_camara")
        if not api_key or api_key == "在這裡貼上您的Key":
            return {"success": False, "error": "尚未設定 GEMINI_API_KEY_camara。請打開 C:\\Users\\Administrator\\115502\\115502\\backend\\.env 檔案並貼入金鑰。"}
            
        client = genai.Client(api_key=api_key)

        # 2. 讀取圖片（用 bytes + mime_type 傳給新版 Gemini API）
        ext = os.path.splitext(file_path)[1].lower()
        mime_map = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
                    '.png': 'image/png', '.webp': 'image/webp',
                    '.gif': 'image/gif', '.heic': 'image/heic'}
        mime_type = mime_map.get(ext, 'image/jpeg')
        with open(file_path, 'rb') as f:
            image_bytes = f.read()
        image_part = types.Part.from_bytes(data=image_bytes, mime_type=mime_type)

        # 3. 定義 prompt：嚴格要求回傳符合前端格式的 JSON
        prompt = '''
        請分析這張圖片，找出最重要的 3 到 5 個物品，並以合乎語法的 JSON 格式回傳。
        你需要將每個物品翻譯成日文，並提供假名、羅馬拼音、以及中文解釋。
        
        【極度重要警告】：
        針對你萃取出的每一個單字，你都必須依照 N5~N4(初級), N3(中級), N2(中高級), N1(高級) 的難度，在 `sentences` 陣列的對應位置生成 4 句實用的日文例句。
        這 4 句日文例句「絕對必須明顯地包含該單字本身（或是該單字的動詞變化）」，不可只寫跟圖片有關但不包含該單字的描述句！
        請以自然的方式將單字融入句子中，「絕對不要」使用括號、引號等任何符號將單字框起來（例如：請直接寫 りんごを食べます，不要寫 「りんご」を食べます）。

        請「嚴格」遵守以下 JSON 格式回傳，不可加上 `json` 或 markdown 標籤：
        {
          "labels": ["英文名稱1 (中文翻譯1)", "英文名稱2 (中文翻譯2)"],
          "text": "圖中看得到的文字OCR，若沒有請留空字串",
          "vocabs": [
            {
              "word": "日文漢字或單字",
              "kana": "平假名發音",
              "romaji": "羅馬拼音",
              "meaning": "中文解釋"
            }
          ],
          "sentences": [
            {
              "japanese": "包含第1個單字的初級(N5-N4)日文例句",
              "chinese": "初級例句的中文翻譯",
              "japanese_inter": "包含第1個單字的中級(N3)日文例句",
              "japanese_upper": "包含第1個單字的中高級(N2)日文例句",
              "japanese_adv": "包含第1個單字的高級(N1)日文例句"
            },
            {
              "japanese": "包含第2個單字的初級(N5-N4)日文例句",
              "chinese": "初級例句的中文翻譯",
              "japanese_inter": "包含第2個單字的中級(N3)日文例句",
              "japanese_upper": "包含第2個單字的中高級(N2)日文例句",
              "japanese_adv": "包含第2個單字的高級(N1)日文例句"
            }
          ]
        }
        '''

        # 4. 呼叫 Gemini 解析圖片
        response = client.models.generate_content(model='gemini-2.5-flash', contents=[image_part, prompt])
        result_text = response.text.strip()

        # 5. 因為要求回傳 JSON，但 Gemini 有時會加上 markdown (如 ```json ... ```)
        #    這裡做個簡單的清理
        if result_text.startswith("```json"):
            result_text = result_text.replace("```json", "", 1)
            if result_text.endswith("```"):
                result_text = result_text[:-3]
        elif result_text.startswith("```"):
            result_text = result_text.replace("```", "", 1)
            if result_text.endswith("```"):
                result_text = result_text[:-3]

        result_text = result_text.strip()

        # 6. 將文字解析為 Python Dict
        try:
            result_data = json.loads(result_text)
        except json.JSONDecodeError as decode_err:
            print("Gemini 回傳的格式不是正確的 JSON:", result_text)
            return {"success": False, "error": f"JSON 解析錯誤: {decode_err}"}

        # 7. 回傳成功的 JSON 結果 (裡面已經有真實的 vocabs 和 sentences 了)
        return {"success": True, "result": result_data}
        
    except Exception as e:
        print(f"Gemini API 分析錯誤: {e}")
        return {
            "success": False,
            "error": f"AI分析錯誤: {str(e)}"
        }


def generate_context_sentences(context_description, vocabs):
    """
    依「使用者拍照當下的情境描述」為每個辨識出的單字生成一句貼近情境的例句。
    一次批次呼叫 Gemini 處理所有單字（節省 API 次數）。

    參數:
        context_description: 使用者輸入的情境，例如「我在遛狗，狗很開心」
        vocabs: [{'word': ..., 'kana': ..., 'meaning': ...}, ...]

    回傳:
        {word: "日文例句\n（中文翻譯）"} 的 dict；失敗時回傳空 dict（不影響主流程）
    """
    try:
        if not context_description or not vocabs:
            return {}

        api_key = os.environ.get("GEMINI_API_KEY_camara") or os.environ.get("GEMINI_API_KEY")
        if not api_key:
            return {}

        client = genai.Client(api_key=api_key)

        word_list = "、".join(v.get('word', '') for v in vocabs if v.get('word'))
        prompt = f'''
        使用者剛拍了一張照片，並描述了當下的情境：「{context_description}」
        這張照片辨識出了以下日文單字：{word_list}

        請為「每一個」單字生成一句例句，要求：
        1. 簡單好懂（N5~N4 程度）
        2. 貼近使用者描述的情境
        3. 例句必須自然地包含該單字本身（不要用括號或引號把單字框起來）
        4. 附上繁體中文翻譯

        請「嚴格」以下列 JSON 格式回傳，不可加上 json 或 markdown 標籤：
        [
          {{"word": "單字1", "japanese": "日文例句1", "chinese": "中文翻譯1"}},
          {{"word": "單字2", "japanese": "日文例句2", "chinese": "中文翻譯2"}}
        ]
        '''

        response = client.models.generate_content(model='gemini-2.5-flash', contents=prompt)
        result_text = response.text.strip()

        # 清理可能的 markdown 標籤
        if result_text.startswith("```json"):
            result_text = result_text.replace("```json", "", 1)
        if result_text.startswith("```"):
            result_text = result_text.replace("```", "", 1)
        if result_text.endswith("```"):
            result_text = result_text[:-3]
        result_text = result_text.strip()

        items = json.loads(result_text)

        result = {}
        for item in items:
            word = item.get('word', '')
            japanese = item.get('japanese', '')
            chinese = item.get('chinese', '')
            if word and japanese:
                result[word] = f"{japanese}\n（{chinese}）" if chinese else japanese
        return result

    except Exception as e:
        # 情境例句生成失敗不應影響拍照辨識主流程，安靜降級
        print(f"情境例句生成失敗（降級為無情境例句）: {e}")
        return {}
