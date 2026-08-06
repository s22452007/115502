import os
import json
import re
from google import genai
from google.genai import types
from dotenv import load_dotenv

# 載入環境變數 (讀取 backend/.env 檔案中的 GEMINI_API_KEY)
# 特別加上 override=True，強制覆蓋終端機中可能殘留的舊變數（避免一直讀到舊金鑰）
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env_path = os.path.join(BASE_DIR, '.env')
load_dotenv(env_path, override=True)

# 要求 Gemini 以 JSON 模式輸出（結構性保證，大幅降低格式錯誤）
JSON_CONFIG = types.GenerateContentConfig(response_mime_type='application/json')


def parse_gemini_json(raw_text):
    """
    解析 Gemini 回傳的 JSON，容忍常見的格式瑕疵：
      - 包在 ```json ... ``` markdown 區塊裡
      - 物件/陣列結尾多一個逗號（trailing comma），例如 {"a":1,} 或 [1,2,]
    解析失敗會拋出 json.JSONDecodeError，由呼叫端處理。
    """
    text = (raw_text or '').strip()

    # 1. 去除 markdown 標籤
    if text.startswith("```json"):
        text = text.replace("```json", "", 1)
    elif text.startswith("```"):
        text = text.replace("```", "", 1)
    if text.endswith("```"):
        text = text[:-3]
    text = text.strip()

    # 2. 先照原樣試一次
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # 3. 移除物件/陣列收尾前多餘的逗號後再試
    #    （只處理結構符號前的逗號，不會動到字串內容裡的逗號）
    cleaned = re.sub(r',(\s*[}\]])', r'\1', text)
    return json.loads(cleaned)

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

        【內容安全守門】：
        在辨識之前，請先判斷這張圖片是否包含裸露、性暗示、色情、血腥或暴力等不當內容。
        若有，請「不要」辨識單字，直接改回傳以下 JSON（不可加上任何其他文字）：
        {"blocked": true, "reason": "圖片包含不當內容，請上傳符合規定的圖片並再試一次。"}

        【主題分類】：
        請判斷這張照片最貼近哪一個「生活情境主題」，並填入 `scene_category`。
        你「只能」從下列清單挑「一個」最貼近的（必須一字不差地照抄，不可自創）：
        ["餐廳美食", "便利商店", "車站交通", "街道風景", "居家生活", "學校辦公", "購物商場", "自然戶外", "其他"]
        若都不貼近，請填 "其他"。

        【極度重要警告】：
        針對你萃取出的每一個單字，你都必須依照 N5~N4(初級), N3(中級), N2(中高級), N1(高級) 的難度，在 `sentences` 陣列的對應位置生成 4 句實用的日文例句。
        這 4 句日文例句「絕對必須明顯地包含該單字本身（或是該單字的動詞變化）」，不可只寫跟圖片有關但不包含該單字的描述句！
        請以自然的方式將單字融入句子中，「絕對不要」使用括號、引號等任何符號將單字框起來（例如：請直接寫 りんごを食べます，不要寫 「りんご」を食べます）。
        此外，針對所有生成的日文例句，只要句中有使用到「漢字」，都必須一律使用 `[漢字|平假名]` 的格式標記該漢字在本句中的讀音（例如：`[私|わたし]は[毎日|まいにち][林檎|りんご]を[食|た]べます。`）。純平假名或外來語片假名則照常填寫，請勿遺漏句中任何一個漢字的讀音標記。
        最後，在生成日文例句的時候，請務必使用專業、正確的文法，不要隨便生成奇怪且不通順的文句，中文翻譯也一樣要求準確。

        請「嚴格」遵守以下 JSON 格式回傳，不可加上 `json` 或 markdown 標籤：
        {
          "labels": ["英文名稱1 (中文翻譯1)", "英文名稱2 (中文翻譯2)"],
          "scene_category": "從主題清單挑一個最貼近的",
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
              "chinese_inter": "中級例句的中文翻譯",
              "japanese_upper": "包含第1個單字的中高級(N2)日文例句",
              "chinese_upper": "中高級例句的中文翻譯",
              "japanese_adv": "包含第1個單字的高級(N1)日文例句",
              "chinese_adv": "高級例句的中文翻譯"
            },
            {
              "japanese": "包含第2個單字的初級(N5-N4)日文例句",
              "chinese": "初級例句的中文翻譯",
              "japanese_inter": "包含第2個單字的中級(N3)日文例句",
              "chinese_inter": "中級例句的中文翻譯",
              "japanese_upper": "包含第2個單字的中高級(N2)日文例句",
              "chinese_upper": "中高級例句的中文翻譯",
              "japanese_adv": "包含第2個單字的高級(N1)日文例句",
              "chinese_adv": "高級例句的中文翻譯"
            }
          ]
        }
        '''

        # 4. 呼叫 Gemini 解析圖片（指定 JSON 輸出模式）
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=[image_part, prompt],
            config=JSON_CONFIG,
        )
        result_text = response.text

        # 5~6. 解析 JSON（自動處理 markdown 標籤與多餘逗號）
        #      若第一次失敗，重試一次再解析（Gemini 偶爾會產生壞掉的格式）
        try:
            result_data = parse_gemini_json(result_text)
        except json.JSONDecodeError:
            print("⚠️ Gemini 回傳格式有誤，正在重試一次...")
            try:
                retry = client.models.generate_content(
                    model='gemini-2.5-flash',
                    contents=[image_part, prompt],
                    config=JSON_CONFIG,
                )
                result_data = parse_gemini_json(retry.text)
            except json.JSONDecodeError as decode_err:
                print("Gemini 回傳的格式不是正確的 JSON:", result_text)
                return {"success": False, "error": f"JSON 解析錯誤: {decode_err}"}

        # 6.5 內容安全守門：Gemini 判定圖片含不當內容時，不辨識、標記為封鎖
        if isinstance(result_data, dict) and result_data.get("blocked"):
            return {
                "success": False,
                "blocked": True,
                "error": result_data.get("reason", "圖片包含不當內容，無法辨識"),
            }

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
        {word: "日文例句\n中文翻譯"} 的 dict；失敗時回傳空 dict（不影響主流程）
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
        4. 句中有使用到「漢字」的部分，請一律使用 `[漢字|平假名]` 的格式標記讀音（例如：`[犬|いぬ]がとても[喜|よろこ]んでいます。`）
        5. 附上繁體中文翻譯
        6. 在生成日文例句的時候，請務必使用專業、正確的文法，不要隨便生成奇怪且不通順的文句，中文翻譯也一樣要求準確。

        請「嚴格」以下列 JSON 格式回傳，不可加上 json 或 markdown 標籤：
        [
          {{"word": "單字1", "japanese": "日文例句1", "chinese": "中文翻譯1"}},
          {{"word": "單字2", "japanese": "日文例句2", "chinese": "中文翻譯2"}}
        ]
        '''

        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=JSON_CONFIG,
        )
        # 解析 JSON（自動處理 markdown 標籤與多餘逗號）
        items = parse_gemini_json(response.text)

        result = {}
        for item in items:
            word = item.get('word', '')
            japanese = item.get('japanese', '')
            chinese = item.get('chinese', '')
            if word and japanese:
                result[word] = f"{japanese}\n{chinese}" if chinese else japanese
        return result

    except Exception as e:
        # 情境例句生成失敗不應影響拍照辨識主流程，安靜降級
        print(f"情境例句生成失敗（降級為無情境例句）: {e}")
        return {}


def evaluate_user_sentence(sentence, vocabs, context_description):
    """
    評估使用者用辨識出單字造的句子。
    """
    try:
        if not sentence or not vocabs:
            return {"success": False, "error": "缺少句子或單字資料"}

        api_key = os.environ.get("GEMINI_API_KEY_camara") or os.environ.get("GEMINI_API_KEY")
        if not api_key:
            return {"success": False, "error": "尚未設定 API Key"}

        client = genai.Client(api_key=api_key)

        word_list = "、".join(v.get('word', '') or v.get('kana', '') for v in vocabs)
        
        prompt = f'''
        使用者在情境「{context_description or '無特定情境'}」下，
        學到了以下日文單字：{word_list}。
        使用者嘗試用這些單字造了一個日文句子：
        「{sentence}」

        請你扮演專業的日文老師，幫忙評估這個句子。
        要求：
        1. 檢查這個句子是否至少使用了一個上面列出的日文單字（或是它的動詞/形容詞變化形）。
           如果完全沒有用到，請在 `is_valid` 填寫 false，並在 `feedback` 給予鼓勵和提醒，請他們嘗試用上面的單字造句。
        2. 如果有使用，請檢查日文文法是否正確、語意是否自然。
           - 若有錯誤或不自然的地方，請在 `is_valid` 填寫 false，並在 `feedback` 溫柔地指出並解釋錯誤，然後在 `corrected_sentence` 提供修正後的句子。
           - 若完全正確，請在 `is_valid` 填寫 true，並在 `feedback` 給予大大的稱讚，並在 `corrected_sentence` 提供原本的句子。
        3. 必須在 `translation` 提供該句子（或修正後句子）的繁體中文翻譯。
        4. 句中有使用到「漢字」的部分，在 `corrected_sentence` 請一律使用 `[漢字|平假名]` 的格式標記讀音。

        請「嚴格」以下列 JSON 格式回傳，不可加上 json 或 markdown 標籤：
        {{
          "is_valid": true或false,
          "feedback": "給使用者的評語與解釋",
          "corrected_sentence": "修正後或原本正確的日文句子(需含漢字注音標記)",
          "translation": "繁體中文翻譯"
        }}
        '''

        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=JSON_CONFIG,
        )
        result = parse_gemini_json(response.text)
        return {"success": True, "result": result}
    except Exception as e:
        print(f"評估句子失敗: {e}")
        return {"success": False, "error": f"評估失敗: {str(e)}"}
