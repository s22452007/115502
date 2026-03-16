from flask import Blueprint, request, jsonify
import os
import uuid

scenario_bp = Blueprint('scenario', __name__)

# 設定圖片上傳的儲存路徑
UPLOAD_FOLDER = os.path.join(os.path.abspath(os.path.dirname(os.path.dirname(__file__))), 'static', 'photos')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@scenario_bp.route('/analyze', methods=['POST'])
def analyze_scene():
    """
    接收前端上傳的相片，並交由 AI 分析回傳結果。
    """
    if 'image' not in request.files:
        return jsonify({'error': '沒有找到圖片檔案 (image)'}), 400

    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': '檔案名稱為空'}), 400

    if file:
        try:
            # 1. 生成唯一的檔案名稱並儲存圖片到伺服器 (模擬)
            ext = os.path.splitext(file.filename)[1]
            if not ext:
                ext = '.jpg' # 預設副檔名
            unique_filename = f"{uuid.uuid4()}{ext}"
            file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
            file.save(file_path)

            # 2. 呼叫 AI 工具函式 (這裡你需要串接 OpenAI 的 GPT-4o 或 Gemini Vision)
            # 假設 ai_helper.py 裡面有一個 analyze_image_from_path(file_path) 函式
            # 由於不確定你的 ai_helper.py 內容，這裡先回傳假資料 (Mock Data)
            # 你可以在這裡替換成真實的 AI 呼叫邏輯：
            # ai_result = utils.ai_helper.analyze_image_from_path(file_path)
            
            # --- 以下為假資料 (Mock Data) 供前端串接測試用 ---
            ai_result = {
                'vocabs': [
                    {'word': 'パソコン', 'kana': 'ぱそこん', 'meaning': '電腦', 'romaji': 'pasokon'},
                    {'word': '机', 'kana': 'つくえ', 'meaning': '桌子', 'romaji': 'tsukue'},
                    {'word': '珈琲', 'kana': 'コーヒー', 'meaning': '咖啡', 'romaji': 'ko-hi-'}
                ],
                'sentences': [
                    {'japanese': '机の上にパソコンがあります。', 'chinese': '桌子上有電腦。'},
                    {'japanese': '私はコーヒーを飲みながら仕事をします。', 'chinese': '我一邊喝咖啡一邊工作。'}
                ]
            }
            # --- 假資料結束 ---

            return jsonify({
                'message': '圖片分析成功',
                'file_path': f'/static/photos/{unique_filename}', # 回傳相對路徑
                'result': ai_result
            }), 200

        except Exception as e:
            print(f"分析圖片時發生錯誤: {e}")
            return jsonify({'error': f'伺服器內部錯誤: {str(e)}'}), 500

@scenario_bp.route('/history', methods=['GET'])
def get_scenario_history():
    """
    查詢過去分析過的場景紀錄。
    (提供給你的擴充範例骨架)
    """
    # TODO: 1. 從 Token 中取得 user_id
    # TODO: 2. 從資料庫 (例如 UserScene 或是自訂的 ScenarioHistory 表) 撈取該使用者的歷史紀錄
    # TODO: 3. 將資料格式化並回傳
    
    return jsonify({
        'message': '歷史紀錄查詢成功 (目前為空，你可以自行實作這裡的邏輯)',
        'history': []
    }), 200
