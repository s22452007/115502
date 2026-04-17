import os
import json
import google.generativeai as genai
from PIL import Image
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
            
        genai.configure(api_key=api_key)
        
        # 2. 讀取圖片
        img = Image.open(file_path)
        
        # 3. 定義 prompt：嚴格要求回傳符合前端格式的 JSON
        prompt = '''
        請分析這張圖片，找出最重要的 3 到 5 個物品，並以合乎語法的 JSON 格式回傳。
        你需要將每個物品翻譯成日文，並提供假名、羅馬拼音、以及中文解釋。
        
        【極度重要警告】：
        針對你萃取出的每一個單字，你都必須依照 N5~N4(初級), N3(中級), N2(中高級), N1(高級) 的難度，在 `sentences` 陣列的對應位置生成 4 句實用的日文例句。
        這 4 句日文例句「絕對必須明顯地包含該單字本身（或是該單字的動詞變化）」，不可只寫跟圖片有關但不包含該單字的描述句！

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
              "japanese": "這是一句一定有包含第1個單字的日文例句",
              "chinese": "例句1的中文翻譯"
            },
            {
              "japanese": "這是一句一定有包含第2個單字的日文例句",
              "chinese": "例句2的中文翻譯"
            }
          ]
        }
        '''

        # 4. 呼叫 Gemini 解析圖片
        model = genai.GenerativeModel("gemini-2.5-flash")
        response = model.generate_content([img, prompt])
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
