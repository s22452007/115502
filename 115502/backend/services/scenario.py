from flask import Blueprint, request, jsonify
from models import UserPhoto, UserPhotoVocab, UserVocab, Scene
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
            
            # --- 以下為寫入資料庫邏輯 (新版主表明細表架構) ---
            
            # 3. 建立相簿主檔 (UserPhoto)
            photo_title = main_label.split(" (")[0][:20] # 取簡單英文名稱或日文為主
            new_photo = UserPhoto(
                user_id=user_id,
                scene_id=None, # 若沒有特定場景就留空
                image_path=relative_image_path,
                custom_title=f"AI辨識: {photo_title}", # 預設照片名稱
                created_at=datetime.utcnow()
            )
            db.session.add(new_photo)
            db.session.flush() # 先 flush 取得 new_photo.id

            # 4. 處理單字並建立明細檔與圖鑑
            vocabs_data = ai_data.get('vocabs', [])
            sentences_data = ai_data.get('sentences', [])
            
            for index, vocab_info in enumerate(vocabs_data):
                sentence = sentences_data[index] if index < len(sentences_data) else {}
                
                # A. 新增至系統詞庫 (Vocab)
                v = Vocab(
                    scene_id=1, # 這裡給一個預設場景ID避免報錯，或者你可以把 Vocab 的 scene_id 改為 nullable=True
                    word=vocab_info.get('word', ''),
                    kana=vocab_info.get('kana', ''),
                    meaning=vocab_info.get('meaning', ''),
                    sentence_basic=sentence.get('japanese', ''),
                )
                db.session.add(v)
                db.session.flush() # 取得 v.id
                
                # B. 建立照片明細檔 (UserPhotoVocab) -> 記錄這張照片裡有這個字
                pv = UserPhotoVocab(
                    photo_id=new_photo.id,
                    vocab_id=v.id
                )
                db.session.add(pv)
                
                # C. 檢查並更新全域單字圖鑑 (UserVocab)
                # 看看這個字以前有沒有解鎖過
                existing_uv = UserVocab.query.filter_by(user_id=user_id, vocab_id=v.id).first()
                if not existing_uv:
                    # 從來沒看過這個字！建一個「已解鎖但未收藏」的空殼 (collected_at=None)
                    uv_shell = UserVocab(
                        user_id=user_id, 
                        vocab_id=v.id, 
                        collected_at=None, 
                        folder_id=None
                    )
                    db.session.add(uv_shell)
                
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
    # TODO: 2. 從資料庫 (例如 UserVocab 或是自訂的 ScenarioHistory 表) 撈取該使用者的歷史紀錄
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
    取得使用者拍過的照片紀錄
    """
    limit = request.args.get('limit', type=int)
    
    # 1. 直接撈使用者的「拍照事件表」
    query = UserPhoto.query.filter(UserPhoto.user_id == user_id).order_by(UserPhoto.created_at.desc())
    if limit:
        photos = query.limit(limit).all()
    else:
        photos = query.all()
    
    results = []
    for p in photos:
        # 2. 算一下這張照片下面掛了幾個單字
        vocab_count = UserPhotoVocab.query.filter_by(photo_id=p.id).count()
        
        results.append({
            "scene_id": p.scene_id if p.scene_id else 0, 
            "scene_name": p.custom_title or (p.scene.name if p.scene else "單字探險"),
            "icon_name": p.scene.icon_name if p.scene else "image",
            "image_path": p.image_path,
            "unlocked_at": p.created_at.strftime('%Y.%m.%d'),
            "vocab_count": vocab_count
        })
        
    return jsonify({"scenes": results}), 200

@scenario_bp.route('/photo_vocabs', methods=['GET'])
def get_vocabs_by_photo():
    """
    取得特定照片 (image_path) 下辨識出的單字
    """
    user_id = request.args.get('user_id', type=int)
    image_path = request.args.get('image_path', type=str)
    
    if not user_id or not image_path:
        return jsonify({"error": "缺少 user_id 或 image_path"}), 400

    # 1. 先找出這張照片的 ID
    photo = UserPhoto.query.filter_by(user_id=user_id, image_path=image_path).first()
    if not photo:
        return jsonify({"vocabs": []}), 200

    # 2. 撈出這張照片底下的單字明細
    photo_vocabs = UserPhotoVocab.query.filter_by(photo_id=photo.id).all()

    results = []
    for pv in photo_vocabs:
        v = pv.vocab
        if v:
            results.append({
                "vocab_id": v.id,
                "word": v.word,
                "kana": v.kana,
                "meaning": v.meaning,
                "is_unlocked": True # 有拍到就算解鎖
            })
            
    return jsonify({"vocabs": results}), 200