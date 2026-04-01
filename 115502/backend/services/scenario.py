from flask import Blueprint, request, jsonify
from models import UserScene, Scene
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

            # 2. 呼叫 AI 工具函式 (使用更新後的 Google MediaPipe 實作)
            from utils.ai_helper import analyze_image_from_path
            ai_result_wrapper = analyze_image_from_path(file_path)

            if not ai_result_wrapper.get("success"):
                return jsonify({'error': ai_result_wrapper.get("error", "AI 分析失敗")}), 500
            
            ai_data = ai_result_wrapper.get("result", {"labels": ["Unknown"], "text": ""})

            return jsonify({
                'message': '圖片分析成功',
                'file_path': f'/static/photos/{unique_filename}', # 回傳相對路徑
                'result': ai_data
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

@scenario_bp.route('/analyze-text', methods=['POST'])
def analyze_text_scenario():
    """
    接收前端傳來的情境主題 (純文字)，交由 AI 生成相關單字與句子。
    """
    # 1. 取得前端傳來的 JSON 資料
    data = request.get_json()
    
    # 2. 檢查有沒有 'topic' 這個欄位
    if not data or 'topic' not in data:
        return jsonify({'error': '請提供情境主題 (topic)'}), 400

    topic = data['topic'].strip()
    if not topic:
        return jsonify({'error': '情境主題不能為空'}), 400

    try:
        # 3. 呼叫 AI 工具函式 (這裡未來要串接 OpenAI 的 GPT 或 Gemini)
        # ai_result = utils.ai_helper.generate_scenario_from_text(topic)
        
        # --- 以下為假資料 (Mock Data) 供前端串接測試用 ---
        # 這裡我特別針對 "便利商店" 或隨機主題做了一個假的結果
        ai_result = {
            'topic': topic,
            'vocabs': [
                {'word': 'いらっしゃいませ', 'kana': 'いらっしゃいませ', 'meaning': '歡迎光臨', 'romaji': 'irasshaimase'},
                {'word': 'お弁当', 'kana': 'おべんとう', 'meaning': '便當', 'romaji': 'obentou'},
                {'word': '温める', 'kana': 'あたためる', 'meaning': '加熱', 'romaji': 'atatameru'},
                {'word': '袋', 'kana': 'ふくろ', 'meaning': '袋子', 'romaji': 'fukuro'}
            ],
            'sentences': [
                {'japanese': 'お弁当温めますか？', 'chinese': '請問便當需要加熱嗎？'},
                {'japanese': '袋はお持ちですか？', 'chinese': '請問有自備購物袋嗎？'}
            ]
        }
        # --- 假資料結束 ---

        return jsonify({
            'message': f'文字情境「{topic}」生成成功',
            'result': ai_result
        }), 200

    except Exception as e:
        print(f"生成文字情境時發生錯誤: {e}")
        return jsonify({'error': f'伺服器內部錯誤: {str(e)}'}), 500

@scenario_bp.route('/unlocked/<int:user_id>', methods=['GET'])
def get_unlocked_scenes(user_id):
    """
    取得使用者已解鎖的場景列表
    支援 Query Parameter: ?limit=3 (首頁用)
    """
    limit = request.args.get('limit', type=int)
    
    # 依照解鎖時間倒序排列
    query = UserScene.query.filter_by(user_id=user_id).order_by(UserScene.unlocked_at.desc())
    
    if limit:
        user_scenes = query.limit(limit).all()
    else:
        user_scenes = query.all()

    results = []
    for us in user_scenes:
        scene = us.scene
        if scene: # 防呆，確保場景存在
            vocab_count = len(scene.vocabs)
            results.append({
                "scene_id": scene.id,
                "scene_name": scene.name,
                "icon_name": scene.icon_name,
                "unlocked_at": us.unlocked_at.strftime('%Y.%m.%d'),
                "vocab_count": vocab_count
            })
            
    return jsonify({"scenes": results}), 200