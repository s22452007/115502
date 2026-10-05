from flask import Blueprint, request, jsonify
from datetime import datetime

from utils.db import db
from utils.auth_token import current_user_id, forbid_unless_owner
from models import User, UserVocab, UserFolder, Vocab
from sqlalchemy import func

vocab_bp = Blueprint('vocab', __name__)


def _folder_denied(folder_id, user_id):
    """指定的資料夾必須是這個使用者自己的（None＝預設相簿，不用檢查）"""
    if folder_id in (None, ''):
        return None
    folder = UserFolder.query.get(folder_id)
    if folder is None or folder.user_id != int(user_id):
        return jsonify({"error": "找不到該資料夾"}), 404
    return None

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
    denied = forbid_unless_owner(uv.user_id) or _folder_denied(target_folder_id, uv.user_id)
    if denied:
        return denied

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
    denied = _folder_denied(folder_id, user_id)
    if denied:
        return denied

    # 檢查是否已收藏
    existing = UserVocab.query.filter_by(user_id=user_id, vocab_id=vocab_id).first()

    if existing and existing.collected_at is not None:
        return jsonify({"error": "已經收藏過囉！"}), 400

    # 檢查收藏位上限
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到使用者"}), 404
    vocab_slot = getattr(user, 'vocab_slot', 50) or 50
    collected_count = UserVocab.query.filter(
        UserVocab.user_id == user_id,
        UserVocab.collected_at.isnot(None),
    ).count()
    if collected_count >= vocab_slot:
        cost_hint = 35 if user.is_premium else 50
        return jsonify({
            "error": f"收藏已達上限（{vocab_slot} 個），花 {cost_hint} 點可擴充 +50 個位置",
            "vocab_slot": vocab_slot,
            "collected_count": collected_count,
        }), 400

    if existing:
        # 之前只有解鎖，現在補上收藏時間和資料夾
        existing.collected_at = datetime.utcnow()
        existing.folder_id = folder_id
        db.session.commit()
        return jsonify({"message": "收藏成功！", "user_vocab_id": existing.id}), 200
    else:
        # 完全沒紀錄，新增一筆
        uv = UserVocab(user_id=user_id, vocab_id=vocab_id, folder_id=folder_id, collected_at=datetime.utcnow())
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
    denied = forbid_unless_owner(folder.user_id)
    if denied:
        return denied

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
    denied = forbid_unless_owner(folder.user_id)
    if denied:
        return denied

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


@vocab_bp.route('/practice_words', methods=['GET'])
def get_practice_words():
    """造句練習可以勾選的單字：收藏過的字 + 拍照辨識過的字。
    同一個字只出現一次，收藏的排前面、其次是最近拍到的；source 標示來源（collected / photo）。
    原本 App 只讀單字本，拍過但沒按星星的字選不到。"""
    user_id = request.args.get('user_id', type=int)
    if not user_id:
        return jsonify({"error": "缺少 user_id"}), 400

    from models import UserPhoto, UserPhotoVocab
    collected = (Vocab.query.join(UserVocab, UserVocab.vocab_id == Vocab.id)
                 .filter(UserVocab.user_id == user_id, UserVocab.collected_at.isnot(None))
                 .order_by(UserVocab.collected_at.desc())
                 .all())
    photographed = (db.session.query(Vocab)
                    .join(UserPhotoVocab, UserPhotoVocab.vocab_id == Vocab.id)
                    .join(UserPhoto, UserPhotoVocab.photo_id == UserPhoto.id)
                    .filter(UserPhoto.user_id == user_id)
                    .group_by(Vocab.id)
                    .order_by(func.max(UserPhoto.created_at).desc())
                    .all())

    words, seen = [], set()
    for source, vocabs in (('collected', collected), ('photo', photographed)):
        for v in vocabs:
            if not v.word or v.word in seen:
                continue
            seen.add(v.word)
            words.append({"vocab_id": v.id, "word": v.word, "kana": v.kana,
                          "meaning": v.meaning, "source": source})
    return jsonify({"words": words}), 200


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
        sentences.append({"level_name": "初階應用", "text": v.sentence_basic,
                          "translation": getattr(v, 'sentence_basic_zh', None)})

    # 2. 中級以上 (N3, N2, N1)：顯示中級 (N3)
    if user_lvl in ['N3', 'N2', 'N1'] and v.sentence_inter:
        sentences.append({"level_name": "中階變化", "text": v.sentence_inter,
                          "translation": getattr(v, 'sentence_inter_zh', None)})

    # 3. 中高級以上 (N2, N1)：顯示中高級 (N2)
    if user_lvl in ['N2', 'N1'] and v.sentence_upper_inter:
        sentences.append({"level_name": "商務/進階", "text": v.sentence_upper_inter,
                          "translation": getattr(v, 'sentence_upper_inter_zh', None)})

    # 4. 高級 (N1)：顯示高級 (N1)
    if user_lvl == 'N1' and v.sentence_advanced:
        sentences.append({"level_name": "高級語感", "text": v.sentence_advanced,
                          "translation": getattr(v, 'sentence_advanced_zh', None)})
        
    # 防呆：如果都沒資料
    if not sentences:
        sentences.append({"level": "提示", "text": "系統努力生成例句中..."})

    # 還有更進階、但目前稱號還看不到的例句（App 顯示「提升稱號可以看到更多例句」）
    available = sum(1 for s in (v.sentence_basic, v.sentence_inter, v.sentence_upper_inter, v.sentence_advanced) if s)
    more_locked = available > len([s for s in sentences if s.get('level_name')])

    # 這個使用者拍照時留下的情境例句（新的在前、同一句不重複，最多 3 句）
    # 原本只有拍照結果頁看得到，從單字本點進來就看不到了
    from models import UserPhoto, UserPhotoVocab
    photo_rows = (db.session.query(UserPhotoVocab.context_sentence, UserPhoto.custom_title, UserPhoto.created_at)
                  .join(UserPhoto, UserPhotoVocab.photo_id == UserPhoto.id)
                  .filter(UserPhoto.user_id == user_id, UserPhotoVocab.vocab_id == vocab_id)
                  .order_by(UserPhoto.created_at.desc())
                  .all())
    context_sentences, seen = [], set()
    for ctx, title, created in photo_rows:
        lines = (ctx or '').strip().split('\n')
        text = lines[0].strip()
        if not text or text in seen:
            continue
        seen.add(text)
        translation = '\n'.join(lines[1:]).strip().strip('（）()').strip()
        context_sentences.append({
            "text": text,
            "translation": translation,
            "photo_title": title,
            "date": created.strftime('%Y-%m-%d') if created else None,
        })
        if len(context_sentences) >= 3:
            break

    folder_name = None
    if is_favorited:
        folder = UserFolder.query.get(uv.folder_id) if uv.folder_id else None
        folder_name = folder.name if folder else '預設相簿'

    return jsonify({
        "vocab_id": v.id,
        "word": v.word,
        "kana": v.kana,
        "meaning": v.meaning,
        "sentences": sentences,
        "more_sentences_locked": more_locked,
        "context_sentences": context_sentences,
        "photo_count": len(photo_rows),          # 在幾張自己的照片裡出現過
        "folder_name": folder_name,              # 收藏在哪個單字本（沒收藏是 null）
        "is_favorited": is_favorited
    }), 200


# ==========================================
# 🌟 最終修復版：解決 scene_id NOT NULL 問題
# ==========================================
@vocab_bp.route('/collect_from_article', methods=['POST'])
def collect_from_article():
    data = request.get_json()
    user_id = data.get('user_id')
    word = data.get('word')
    kana = data.get('kana')
    meaning = data.get('meaning')
    folder_id = data.get('folder_id')

    if not user_id or not word:
        return jsonify({"error": "缺少必要資料"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到使用者"}), 404
    denied = _folder_denied(folder_id, user_id)
    if denied:
        return denied

    # 1. 檢查 Vocab 總字庫有沒有這個單字（新字先不寫入，等確認可以收藏後再一起存）
    vocab = Vocab.query.filter_by(word=word).first()

    # 2. 檢查使用者是否已經收藏過這個單字
    existing = UserVocab.query.filter_by(user_id=user_id, vocab_id=vocab.id).first() if vocab else None
    if existing and existing.collected_at is not None:
        return jsonify({"error": "這個單字已經在收藏夾囉！"}), 400

    # 3. 檢查收藏容量上限

    vocab_slot = getattr(user, 'vocab_slot', 50) or 50
    collected_count = UserVocab.query.filter(
        UserVocab.user_id == user_id,
        UserVocab.collected_at.isnot(None)
    ).count()
    
    if collected_count >= vocab_slot:
        cost_hint = 35 if user.is_premium else 50
        return jsonify({
            "error": f"收藏已達上限（{vocab_slot} 個），花 {cost_hint} 點可擴充 +50 個位置"
        }), 400

    # 4. 字庫沒有這個字就新增。vocab.scene_id 不能是空的，文章單字沒有主題資訊，
    #    歸到主題收集冊的「其他」。原本抓資料庫第一個場景，結果文章單字全跑到「一蘭拉麵」。
    #    source 維持 'ai'，不算進主題收集冊的官方字數。
    if not vocab:
        from services.scenario import get_or_create_theme_scene
        vocab = Vocab(
            word=word,
            kana=kana or '',
            meaning=meaning or '',
            scene_id=get_or_create_theme_scene('其他').id,
        )
        db.session.add(vocab)
        db.session.flush()

    # 5. 執行收藏
    if existing:
        existing.collected_at = datetime.utcnow()
        existing.folder_id = folder_id 
    else:
        new_uv = UserVocab(
            user_id=user_id, 
            vocab_id=vocab.id, 
            folder_id=folder_id, 
            collected_at=datetime.utcnow()
        )
        db.session.add(new_uv)
        
    db.session.commit()
    return jsonify({"status": "success", "message": "✅ 成功加入收藏夾！"}), 200


# 單字探險：隨機取得未解鎖／已解鎖單字混合的清單
@vocab_bp.route('/explore', methods=['POST'])
def explore_vocabs():
    """
    前端會傳入 JSON: { user_id: 1, count: 10, scene_id: optional }
    回傳隨機的單字清單，並標示是否已解鎖。

    註：目前 App 沒有呼叫這支 API（單字探險的引導文案已改寫在前端），
        保留供之後「隨機探索單字」功能使用。
    """
    data = request.get_json() or {}
    user_id = data.get('user_id')
    count = int(data.get('count', 10))
    scene_id = data.get('scene_id')

    if not user_id:
        return jsonify({"error": "缺少 user_id"}), 400

    # 取得使用者資料與已解鎖的 vocab id
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "找不到使用者"}), 404
    user_vocab_records = UserVocab.query.filter_by(user_id=user_id).all()
    unlocked_ids = {uv.vocab_id for uv in user_vocab_records}

    # 建立 base query
    q = Vocab.query
    if scene_id:
        q = q.filter_by(scene_id=scene_id)

    # 先試圖取未解鎖的單字（優先讓使用者有新字可以探險）
    unexplored = q.filter(~Vocab.id.in_(list(unlocked_ids))).order_by(func.random()).limit(count).all()

    results = []
    for v in unexplored:
        results.append({
            "vocab_id": v.id,
            "word": v.word,
            "kana": v.kana,
            "meaning": v.meaning,
            "is_unlocked": False,
            "unlock_hint": "可透過拍照辨識解鎖，不會花點數。",
            "action": {"type": "scan", "label": "拍照解鎖"}
        })

    # 若不足，再補已解鎖的隨機單字
    if len(results) < count:
        need = count - len(results)
        locked = q.filter(Vocab.id.in_(list(unlocked_ids))).order_by(func.random()).limit(need).all()
        for v in locked:
            results.append({
                "vocab_id": v.id,
                "word": v.word,
                "kana": v.kana,
                "meaning": v.meaning,
                "is_unlocked": True,
                "unlock_hint": "已解鎖，可加入收藏或觀看例句。",
                "action": {"type": "view", "label": "查看單字"}
            })

    return jsonify({"vocabs": results}), 200
