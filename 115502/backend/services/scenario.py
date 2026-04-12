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
    接收前端上傳的相片，交由 AI 分析回傳結果，並將分析出的單字強制寫入使用者的單字圖鑑 (UserVocab)。
    """
    from datetime import datetime
    from utils.db import db
    from models import Scene, Vocab, UserVocab, UserScene

    # 確保有傳 user_id (相機辨識綁定使用者)
    user_id = request.form.get('user_id')
    if not user_id:
        return jsonify({'error': '缺少 user_id'}), 400

    if 'image' not in request.files:
        return jsonify({'error': '沒有找到圖片檔案 (image)'}), 400

    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': '檔案名稱為空'}), 400

    if file:
        try:
            # 1. 生成唯一的檔案名稱並儲存圖片到伺服器
            ext = os.path.splitext(file.filename)[1]
            if not ext:
                ext = '.jpg' # 預設副檔名
            unique_filename = f"{uuid.uuid4()}{ext}"
            file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
            file.save(file_path)
            relative_image_path = f'/static/photos/{unique_filename}'

            # 2. 呼叫 AI 工具函式
            from utils.ai_helper import analyze_image_from_path
            ai_result_wrapper = analyze_image_from_path(file_path)

            if not ai_result_wrapper.get("success"):
                return jsonify({'error': ai_result_wrapper.get("error", "AI 分析失敗")}), 500
            
            ai_data = ai_result_wrapper.get("result", {})
            labels = ai_data.get('labels', [])
            main_label = labels[0] if labels else "未知物件"
            
            # --- 以下為寫入資料庫邏輯 ---
            # 3. 建立一個虛擬的 Scene 來代表這次照片解鎖事件 (由於 Vocab 必須綁定 Scene)
            scene_name = main_label.split(" (")[0][:20] # 取簡單英文名稱或日文為主
            new_scene = Scene(name=f"照片解鎖: {scene_name}", icon_name="camera_alt")
            db.session.add(new_scene)
            db.session.commit() # 取得 new_scene.id

            # 4. 記錄此使用者的解鎖場景
            us = UserScene(
                user_id=user_id,
                scene_id=new_scene.id,
                image_path=relative_image_path,
                unlocked_at=datetime.utcnow()
            )
            db.session.add(us)

            # 5. 把單字寫入 Vocab，並自動寫入 UserVocab (圖鑑)
            vocabs_data = ai_data.get('vocabs', [])
            sentences_data = ai_data.get('sentences', [])
            
            for index, vocab_info in enumerate(vocabs_data):
                sentence = sentences_data[index] if index < len(sentences_data) else {}
                
                # 新增至系統詞庫
                v = Vocab(
                    scene_id=new_scene.id,
                    word=vocab_info.get('word', ''),
                    kana=vocab_info.get('kana', ''),
                    meaning=vocab_info.get('meaning', ''),
                    sentence_basic=sentence.get('japanese', ''),
                )
                db.session.add(v)
                db.session.commit() # 得到 v.id
                
                # 綁定給 UserVocab 成為圖鑑收集物
                uv = UserVocab(
                    user_id=user_id,
                    vocab_id=v.id,
                    image_path=relative_image_path,
                    unlocked_at=datetime.utcnow()
                )
                db.session.add(uv)
                
                # 將產生的 vocab_id 給補回去 ai_data，讓前端可以用來收藏
                vocab_info['vocab_id'] = v.id

            db.session.commit()
            # --- 寫入結束 ---

            return jsonify({
                'message': '圖片分析成功並已存入圖鑑',
                'file_path': relative_image_path,
                'result': ai_data
            }), 200

        except Exception as e:
            print(f"分析圖片時發生錯誤: {e}")
            db.session.rollback()
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