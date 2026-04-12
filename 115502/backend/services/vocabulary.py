from flask import Blueprint, request, jsonify
from datetime import datetime

from utils.db import db
from models import User, UserVocab, UserFolder, Vocab

vocab_bp = Blueprint('vocab', __name__)

# 取得使用者所有資料夾（含預設 + 自訂）+ 各資料夾單字數
@vocab_bp.route('/favorites/<int:user_id>', methods=['GET'])
def get_user_favorites(user_id):
    # 預設資料夾（folder_id 為 null 的單字）
    default_count = UserVocab.query.filter(
        UserVocab.user_id == user_id, 
        UserVocab.folder_id == None,
        UserVocab.collected_at.isnot(None)
    ).count()
    
    result = [{
        "id": None,
        "name": "預設相簿",
        "is_default": True,
        "count": default_count,
    }]

    # 自訂資料夾
    custom_folders = UserFolder.query.filter_by(user_id=user_id).all()
    for cf in custom_folders:
        count = UserVocab.query.filter_by(user_id=user_id, folder_id=cf.id).count()
        result.append({
            "id": cf.id,
            "name": cf.name,
            "is_default": False,
            "count": count,
        })

    return jsonify({"favorites": result}), 200


# 取得某個資料夾裡的單字列表
@vocab_bp.route('/folder_vocabs', methods=['POST'])
def get_folder_vocabs():
    data = request.get_json()
    user_id = data.get('user_id')
    folder_id = data.get('folder_id')

    if not user_id:
        return jsonify({"error": "缺少 user_id"}), 400

    if folder_id is None:
        user_vocabs = UserVocab.query.filter(
            UserVocab.user_id == user_id, 
            UserVocab.folder_id == None,
            UserVocab.collected_at.isnot(None)
        ).all()
    else:
        user_vocabs = UserVocab.query.filter_by(user_id=user_id, folder_id=folder_id).all()

    result = []
    for uv in user_vocabs:
        v = uv.vocab
        result.append({
            "user_vocab_id": uv.id,
            "vocab_id": v.id,
            "word": v.word,
            "kana": v.kana,
            "meaning": v.meaning,
            "scene": v.scene.name if v.scene else "未分類",
            "folder_id": uv.folder_id,
        })

    return jsonify({"vocabs": result}), 200


# 建立自訂資料夾
@vocab_bp.route('/folders', methods=['POST'])
def create_folder():
    data = request.get_json()
    user_id = data.get('user_id')
    name = data.get('name')

    if not user_id or not name:
        return jsonify({"error": "缺少必要資料"}), 400

    new_folder = UserFolder(user_id=user_id, name=name)
    db.session.add(new_folder)
    db.session.commit()

    return jsonify({
        "message": "資料夾建立成功！",
        "folder_id": new_folder.id,
        "name": new_folder.name,
    }), 201


# 移動單字到指定資料夾
@vocab_bp.route('/move_vocab', methods=['POST'])
def move_vocab():
    data = request.get_json()
    user_vocab_id = data.get('user_vocab_id')
    target_folder_id = data.get('target_folder_id')  # None = 移回預設

    if not user_vocab_id:
        return jsonify({"error": "缺少 user_vocab_id"}), 400

    uv = UserVocab.query.get(user_vocab_id)
    if not uv:
        return jsonify({"error": "找不到該收藏紀錄"}), 404

    uv.folder_id = target_folder_id
    db.session.commit()

    return jsonify({"message": "移動成功"}), 200


# 收藏單字（可指定資料夾）
@vocab_bp.route('/collect', methods=['POST'])
def collect_vocab():
    data = request.get_json()
    user_id = data.get('user_id')
    vocab_id = data.get('vocab_id')
    folder_id = data.get('folder_id')  # 可選，None = 預設

    if not user_id or not vocab_id:
        return jsonify({"error": "缺少必要資料"}), 400

    # 檢查是否已收藏
    existing = UserVocab.query.filter_by(user_id=user_id, vocab_id=vocab_id).first()
    
    if existing:
        if existing.collected_at is not None:
            # 真的已經收藏過了
            return jsonify({"error": "已經收藏過囉！"}), 400
        else:
            # 之前只有解鎖，現在補上收藏時間和資料夾
            existing.collected_at = datetime.utcnow()
            existing.folder_id = folder_id
            db.session.commit()
            return jsonify({"message": "收藏成功！", "user_vocab_id": existing.id}), 200
    else:
        # 完全沒紀錄，新增一筆 (只有收藏)
        uv = UserVocab(user_id=user_id, vocab_id=vocab_id, folder_id=folder_id, collected_at=datetime.utcnow())
        db.session.add(uv)
        db.session.commit()
        return jsonify({"message": "收藏成功！", "user_vocab_id": uv.id}), 201
    
    uv = UserVocab(user_id=user_id, vocab_id=vocab_id, folder_id=folder_id)
    db.session.add(uv)
    db.session.commit()

    return jsonify({"message": "收藏成功！", "user_vocab_id": uv.id}), 201

# 取消收藏單字
@vocab_bp.route('/uncollect', methods=['POST'])
def uncollect_vocab():
    data = request.get_json()
    user_id = data.get('user_id')
    vocab_id = data.get('vocab_id')

    if not user_id or not vocab_id:
        return jsonify({"error": "缺少必要資料"}), 400

    # 尋找使用者的收藏紀錄
    uv = UserVocab.query.filter_by(user_id=user_id, vocab_id=vocab_id).first()
    if not uv:
        return jsonify({"error": "找不到該收藏紀錄"}), 404

    # 只要單字存在於 UserVocab，就代表它有被解鎖（因為拍照時會建空殼）。
    # 取消收藏只要把資料夾跟時間拔掉即可，保留解鎖狀態，不要 delete(uv)！
    uv.folder_id = None
    uv.collected_at = None
    db.session.commit()
    
    return jsonify({"message": "已從資料夾移除，但保留圖鑑解鎖狀態"}), 200

# 刪除資料夾（裡面的單字移回預設）
@vocab_bp.route('/delete_folder', methods=['POST'])
def delete_folder():
    data = request.get_json()
    folder_id = data.get('folder_id')

    if not folder_id:
        return jsonify({"error": "缺少 folder_id"}), 400

    folder = UserFolder.query.get(folder_id)
    if not folder:
        return jsonify({"error": "找不到該資料夾"}), 404

    # 把裡面的單字移回預設
    UserVocab.query.filter_by(folder_id=folder_id).update({"folder_id": None})
    db.session.delete(folder)
    db.session.commit()

    return jsonify({"message": "資料夾已刪除，單字已移回預設相簿"}), 200


# 重新命名資料夾
@vocab_bp.route('/rename_folder', methods=['POST'])
def rename_folder():
    data = request.get_json()
    folder_id = data.get('folder_id')
    name = (data.get('name') or '').strip()

    if not folder_id or not name:
        return jsonify({"error": "缺少必要資料"}), 400

    folder = UserFolder.query.get(folder_id)
    if not folder:
        return jsonify({"error": "找不到該資料夾"}), 404

    folder.name = name
    db.session.commit()

    return jsonify({"message": "重新命名成功"}), 200

@vocab_bp.route('/scene/<int:scene_id>', methods=['GET'])
def get_scene_vocabs(scene_id):
    """
    點開的單字：取得特定場景下的所有單字，並標示該使用者是否已解鎖(打勾)
    必須傳入 Query Parameter: ?user_id=1
    """
    user_id = request.args.get('user_id', type=int)
    if not user_id:
        return jsonify({"error": "缺少 user_id"}), 400

    # 1. 撈出該場景的所有系統單字
    scene_vocabs = Vocab.query.filter_by(scene_id=scene_id).all()
    
    # 2. 撈出使用者已經解鎖/收藏的單字 ID 列表
    user_vocab_records = UserVocab.query.filter_by(user_id=user_id).all()
    user_vocab_ids = [uv.vocab_id for uv in user_vocab_records]

    results = []
    for v in scene_vocabs:
        results.append({
            "vocab_id": v.id,
            "word": v.word,
            "kana": v.kana,
            "meaning": v.meaning,
            "is_unlocked": v.id in user_vocab_ids  # True 前端就顯示綠色打勾
        })
        
    return jsonify({"vocabs": results}), 200


@vocab_bp.route('/detail/<int:vocab_id>', methods=['GET'])
def get_vocab_detail(vocab_id):
    """
    單字詳細頁面：取得單字詳細資訊(含例句、音檔)，並標示是否已加入收藏夾(黃星星)
    必須傳入 Query Parameter: ?user_id=1
    """
    user_id = request.args.get('user_id', type=int)
    v = Vocab.query.get(vocab_id)
    user = User.query.get(user_id)

    if not v or not user:
        return jsonify({"error": "找不到資料"}), 404

    # 檢查是否已收藏 (有 collected_at 紀錄代表星星要亮起)
    uv = UserVocab.query.filter_by(user_id=user_id, vocab_id=vocab_id).first()
    is_favorited = (uv is not None and uv.collected_at is not None)
    
    user_lvl = user.japanese_level or 'N5' # 如果玩家沒設定，預設為 N5
    
    sentences = []
    
    # 1. 所有人：顯示初級 (N5, N4)
    if v.sentence_basic:
        sentences.append({"level_name": "初階應用", "text": v.sentence_basic})
        
    # 2. 中級以上 (N3, N2, N1)：顯示中級 (N3)
    if user_lvl in ['N3', 'N2', 'N1'] and v.sentence_inter:
        sentences.append({"level_name": "中階變化", "text": v.sentence_inter})
        
    # 3. 中高級以上 (N2, N1)：顯示中高級 (N2)
    if user_lvl in ['N2', 'N1'] and v.sentence_upper_inter:
        sentences.append({"level_name": "商務/進階", "text": v.sentence_upper_inter})
        
    # 4. 高級 (N1)：顯示高級 (N1)
    if user_lvl == 'N1' and v.sentence_advanced:
        sentences.append({"level_name": "高級語感", "text": v.sentence_advanced})
        
    # 防呆：如果都沒資料
    if not sentences:
        sentences.append({"level": "提示", "text": "系統努力生成例句中..."})

    return jsonify({
        "vocab_id": v.id,
        "word": v.word,
        "kana": v.kana,
        "meaning": v.meaning,
        "sentences": sentences,
        "is_favorited": is_favorited
    }), 200