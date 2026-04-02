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
        # 1. 取得 API Key 並設定
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key or api_key == "在這裡貼上您的Key":
            return {"success": False, "error": "尚未設定 GEMINI_API_KEY。請打開 C:\\Users\\Administrator\\115502\\115502\\backend\\.env 檔案並貼入金鑰。"}
            
        genai.configure(api_key=api_key)
        
        # 2. 選擇 Gemini 模型
        model = genai.GenerativeModel('gemini-2.5-flash')
        
        # 3. 讀取圖片
        img = Image.open(file_path)
        
        # 4. 設計 Prompt
        prompt = '''
        請以合乎語法的 JSON 格式分析這張圖片。
        1. 找出圖中最多 5 個主要或明顯的物品。
        2. 若圖中有任何文字，請進行 OCR 取出。
        
        你需要嚴格遵守以下 JSON 格式回傳，不要加上任何 markdown 標記 (如 ```json)：
        {
          "labels": ["英文名稱1 (中文翻譯1)", "英文名稱2 (中文翻譯2)"],
          "text": "圖中看得到的文字，若沒有請留空字串"
        }
        '''
        
        # 5. 呼叫 Gemini API
        response = model.generate_content([prompt, img])
        
        # 6. 解析回應
        response_text = response.text.strip()
        # 防呆機制：清除 Gemini 可能回傳的 markdown 格式或首尾空白
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        if response_text.startswith("```"):
            response_text = response_text[3:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
            
        result_data = json.loads(response_text.strip())
        
        labels = result_data.get("labels", [])
        text = result_data.get("text", "")
        
        if not labels:
            labels = ["Unknown Object (未辨識出特定物件)"]
            
        # 7. 保留原本的假資料格式供前端串接/擴充使用
        result_data["vocabs"] = [
            {'word': 'パソコン', 'kana': 'ぱそこん', 'meaning': '電腦', 'romaji': 'pasokon'},
            {'word': '机', 'kana': 'つくえ', 'meaning': '桌子', 'romaji': 'tsukue'},
            {'word': '珈琲', 'kana': 'コーヒー', 'meaning': '咖啡', 'romaji': 'ko-hi-'}
        ]
        result_data["sentences"] = [
            {'japanese': '机の上にパソコンがあります。', 'chinese': '桌子上有電腦。'},
            {'japanese': '私はコーヒーを飲みながら仕事をします。', 'chinese': '我一邊喝咖啡一邊工作。'}
        ]
        
        return {
            "success": True,
            "result": result_data
        }
        
    except Exception as e:
        print(f"Gemini API 分析錯誤: {e}")
        return {
            "success": False,
            "error": f"AI分析錯誤: {str(e)}"
        }
