from flask import Blueprint, request, jsonify
from models import UserPhoto, UserPhotoVocab, UserVocab, Scene
import os
import uuid

scenario_bp = Blueprint('scenario', __name__)

# 設定圖片上傳的儲存路徑
UPLOAD_FOLDER = os.path.join(os.path.abspath(os.path.dirname(os.path.dirname(__file__))), 'static', 'photos')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ==========================================
# 主題收集冊：固定主題清單
#   name           : 與 AI 回傳的 scene_category 對應（必須一致）
#   icon           : Flutter Material icon 名稱
#   target         : 參考用的目標字數。實際分母以 seed_themes.py 種進去的官方字數為準
#                    （見 _theme_progress），這欄只是提醒每個主題該補到幾個字。
# 注意：AI 回傳的 scene_category 會用 name 去 get-or-create 對應的 Scene，
#       不在清單內或空值一律歸到「其他」。
# ==========================================
THEME_DEFS = [
    {'name': '餐廳美食', 'icon': 'restaurant',    'target': 20},
    {'name': '便利商店', 'icon': 'storefront',    'target': 20},
    {'name': '車站交通', 'icon': 'train',         'target': 20},
    {'name': '街道風景', 'icon': 'signpost',      'target': 20},
    {'name': '居家生活', 'icon': 'home',          'target': 25},
    {'name': '學校辦公', 'icon': 'school',        'target': 20},
    {'name': '購物商場', 'icon': 'shopping_bag',  'target': 20},
    {'name': '自然戶外', 'icon': 'park',          'target': 20},
    {'name': '其他',     'icon': 'category',      'target': 15},
]
THEME_BY_NAME = {t['name']: t for t in THEME_DEFS}

# ⚠️ 測試用開關：設 True 時，每次拍照都強制觸發里程碑慶祝動畫（方便預覽效果）。
#    看完動畫後，請把這行改回 False，恢復正常的「真的跨過門檻才觸發」。
#    想預覽「過半」樣式，把下方 forced 的 'complete' 改成 'half' 即可。
MILESTONE_DEBUG_FORCE = False


def get_or_create_theme_scene(category):
    """依 AI 判定的主題名稱取得（或建立）對應的 Scene，回傳該 Scene。

    找不到對應主題（None / 空字串 / 不在清單）一律歸到「其他」。
    """
    from utils.db import db
    from models import Scene

    theme = THEME_BY_NAME.get((category or '').strip()) or THEME_BY_NAME['其他']
    scene = Scene.query.filter_by(name=theme['name']).first()
    if not scene:
        scene = Scene(name=theme['name'], icon_name=theme['icon'])
        db.session.add(scene)
        db.session.flush()  # 先拿到 scene.id 供後續照片/單字綁定
    return scene


# ==========================================
# 🎁 主題收集冊的里程碑獎勵
# ==========================================
# 領過沒有不另外開表：用 PointTransaction.related_feature 存
# 'theme_reward:{scene_id}:{tier}' 當作領取憑證，查得到就是領過了。
THEME_REWARDS = {
    'half':     {'points': 20,  'extra_photo': 0, 'badge': False, 'label': '收集過半'},
    'complete': {'points': 100, 'extra_photo': 3, 'badge': True,  'label': '收集完成'},
}

# 集滿專屬徽章的命名規則（seed_themes.py 會照這個種 Achievement）
def theme_badge_name(theme_name):
    return f'{theme_name}達人'


def _reward_key(scene_id, tier):
    return f'theme_reward:{scene_id}:{tier}'


def _claimed_tiers(user_id, scene_ids):
    """一次查出使用者在這些主題已經領過哪些 tier，回傳 {(scene_id, tier), ...}。"""
    from models import PointTransaction

    if not scene_ids:
        return set()
    keys = {_reward_key(sid, tier) for sid in scene_ids for tier in THEME_REWARDS}
    rows = (PointTransaction.query
            .filter(PointTransaction.user_id == user_id,
                    PointTransaction.related_feature.in_(list(keys)))
            .all())
    claimed = set()
    for r in rows:
        try:
            _, sid, tier = r.related_feature.split(':')
            claimed.add((int(sid), tier))
        except (ValueError, AttributeError):
            continue
    return claimed


def _reward_state(unlocked, total, scene_id, claimed_set):
    """回傳這個主題兩個 tier 的狀態：locked / claimable / claimed。"""
    ratio = (unlocked / total) if total else 0.0
    reached = {
        'half': total > 0 and ratio >= 0.5,
        'complete': total > 0 and unlocked >= total,
    }
    state = {}
    for tier, cfg in THEME_REWARDS.items():
        if (scene_id, tier) in claimed_set:
            s = 'claimed'
        elif reached[tier]:
            s = 'claimable'
        else:
            s = 'locked'
        state[tier] = {
            'state': s,
            'points': cfg['points'],
            'extra_photo': cfg['extra_photo'],
            'badge': cfg['badge'],
            'label': cfg['label'],
        }
    return state


# 官方字＝seed_themes.py 種進去的收集目標（source='admin'）。
# 完成度一律只看官方字，使用者拍照產生的 AI 新字（source='ai'）不進分母，
# 否則別人拍到新字就會讓你的完成度倒退、集滿的冊子被打破。
OFFICIAL_SOURCE = 'admin'


def _theme_progress(user_id, scene_id):
    """回傳 (unlocked, total)：使用者在該主題已解鎖的官方字數 / 官方字總數。"""
    from models import Vocab, UserVocab
    total = Vocab.query.filter_by(scene_id=scene_id, source=OFFICIAL_SOURCE).count()
    unlocked = (UserVocab.query
                .join(Vocab, UserVocab.vocab_id == Vocab.id)
                .filter(UserVocab.user_id == user_id,
                        Vocab.scene_id == scene_id,
                        Vocab.source == OFFICIAL_SOURCE)
                .count())
    return unlocked, total


def _detect_milestone(theme_name, before_unlocked, before_total, after_unlocked, after_total):
    """判斷這次拍照是否讓主題跨過里程碑門檻，回傳 milestone dict 或 None。

    - complete：這次剛好把整個主題集滿（之前沒滿、現在滿了）
    - half    ：這次跨過 50%（之前 <50%、現在 >=50%）
    集滿優先於過半。前後各用「當下的 total」算比例，避免新增單字造成分母位移誤判。
    """
    if after_total <= 0:
        return None

    was_complete = before_total > 0 and before_unlocked >= before_total
    if after_unlocked >= after_total and not was_complete:
        return {'type': 'complete', 'theme_name': theme_name,
                'unlocked': after_unlocked, 'total': after_total}

    before_ratio = (before_unlocked / before_total) if before_total else 0.0
    after_ratio = after_unlocked / after_total
    if before_ratio < 0.5 <= after_ratio:
        return {'type': 'half', 'theme_name': theme_name,
                'unlocked': after_unlocked, 'total': after_total}

    return None

@scenario_bp.route('/analyze', methods=['POST'])
def analyze_scene():
    """
    接收前端上傳的相片，交由 AI 分析回傳結果，並將分析出的單字強制寫入使用者的單字圖鑑 (UserVocab)。
    """
    from datetime import datetime
    from utils.db import db
    from models import Scene, Vocab, UserVocab, UserPhoto, UserPhotoVocab

    # 確保有傳 user_id (相機辨識綁定使用者)
    user_id = request.form.get('user_id')
    custom_title_input = request.form.get('custom_title')
    context_description = (request.form.get('context_description') or '').strip()  # 使用者描述的當下情境（選填）

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

            # 內容安全守門：Gemini 判定圖片含不當內容 → 刪掉已存的檔案，不留在伺服器
            if ai_result_wrapper.get("blocked"):
                try:
                    if os.path.exists(file_path):
                        os.remove(file_path)
                except OSError:
                    pass
                return jsonify({
                    'error': ai_result_wrapper.get("error", "圖片包含不當內容，無法辨識"),
                    'blocked': True,
                }), 400

            if not ai_result_wrapper.get("success"):
                return jsonify({'error': ai_result_wrapper.get("error", "AI 分析失敗")}), 500
            
            ai_data = ai_result_wrapper.get("result", {})
            labels = ai_data.get('labels', [])
            main_label = labels[0] if labels else "未知物件"

            # 2.5 依 AI 判定的主題取得（或建立）對應的 Scene
            #     照片與這次辨識出的新單字都會歸到這個主題，供「主題收集冊」聚合。
            theme_scene = get_or_create_theme_scene(ai_data.get('scene_category'))
            theme_scene_id = theme_scene.id
            ai_data['scene_category'] = theme_scene.name  # 正規化後回傳給前端

            # 里程碑：記錄「拍照前」此主題的收集進度，拍完後再比一次看有沒有跨過門檻
            ms_before_unlocked, ms_before_total = _theme_progress(user_id, theme_scene_id)

            # --- 以下為寫入資料庫邏輯 (新版主表明細表架構) ---

            # 3. 建立相簿主檔 (UserPhoto)
            photo_title = main_label.split(" (")[0][:20] # 取簡單英文名稱或日文為主
            final_title = custom_title_input if custom_title_input else f"AI辨識: {photo_title}"

            new_photo = UserPhoto(
                user_id=user_id,
                scene_id=theme_scene_id, # 歸到 AI 判定的主題場景
                image_path=relative_image_path,
                custom_title=final_title,
                context_description=context_description or None, # 保留情境原文供日後回顧
                created_at=datetime.utcnow()
            )
            db.session.add(new_photo)
            db.session.flush() # 先 flush 取得 new_photo.id

            # 4. 處理單字並建立明細檔與圖鑑
            vocabs_data = ai_data.get('vocabs', [])
            sentences_data = ai_data.get('sentences', [])

            # 4a. 若使用者有描述情境，為每個單字生成貼近情境的專屬例句
            #     （失敗時回傳空 dict，不影響主流程）
            context_sentences = {}
            if context_description:
                from utils.ai_helper import generate_context_sentences
                context_sentences = generate_context_sentences(context_description, vocabs_data)

            for index, vocab_info in enumerate(vocabs_data):
                sentence = sentences_data[index] if index < len(sentences_data) else {}
                
                # A. 寫入系統詞庫 (Vocab) 前先查重：
                #    同一個單字（word + kana 相同）只保留一筆，重複辨識到就直接沿用現有 id
                v = Vocab.query.filter_by(
                    word=vocab_info.get('word', ''),
                    kana=vocab_info.get('kana', ''),
                ).first()
                if not v:
                    v = Vocab(
                        scene_id=theme_scene_id, # 新單字歸到這次辨識判定的主題場景
                        word=vocab_info.get('word', ''),
                        kana=vocab_info.get('kana', ''),
                        meaning=vocab_info.get('meaning', ''),
                        sentence_basic=sentence.get('japanese', ''),
                        sentence_inter=sentence.get('japanese_inter', ''),
                        sentence_upper_inter=sentence.get('japanese_upper', ''),
                        sentence_advanced=sentence.get('japanese_adv', ''),
                        # 分級例句的中文翻譯（辨識時同一次 Gemini 呼叫順便生成）
                        sentence_basic_zh=sentence.get('chinese', ''),
                        sentence_inter_zh=sentence.get('chinese_inter', ''),
                        sentence_upper_inter_zh=sentence.get('chinese_upper', ''),
                        sentence_advanced_zh=sentence.get('chinese_adv', ''),
                        source='ai'
                    )
                    db.session.add(v)
                    db.session.flush() # 取得 v.id
                else:
                    # 如果現有單字缺少翻譯或標音，用新辨識生成的例句自動幫它補齊升級
                    if not v.sentence_basic_zh and sentence.get('chinese'):
                        v.sentence_basic_zh = sentence.get('chinese', '')
                        v.sentence_inter_zh = sentence.get('chinese_inter', '')
                        v.sentence_upper_inter_zh = sentence.get('chinese_upper', '')
                        v.sentence_advanced_zh = sentence.get('chinese_adv', '')
                    if '[' not in (v.sentence_basic or '') and '[' in sentence.get('japanese', ''):
                        v.sentence_basic = sentence.get('japanese', '')
                        v.sentence_inter = sentence.get('japanese_inter', '')
                        v.sentence_upper_inter = sentence.get('japanese_upper', '')
                        v.sentence_advanced = sentence.get('japanese_adv', '')
                
                # B. 建立照片明細檔 (UserPhotoVocab) -> 記錄這張照片裡有這個字
                #    若有情境例句就一併存入 context_sentence
                ctx_sentence = context_sentences.get(vocab_info.get('word', ''))
                pv = UserPhotoVocab(
                    photo_id=new_photo.id,
                    vocab_id=v.id,
                    context_sentence=ctx_sentence,
                )
                db.session.add(pv)
                # 讓前端結果頁能直接顯示情境例句（不用再打一次 API）
                vocab_info['context_sentence'] = ctx_sentence
                
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

            # 里程碑：拍完後重新計算，判斷是否跨過「過半 / 集滿」門檻（None 代表這次沒跨過）
            ms_after_unlocked, ms_after_total = _theme_progress(user_id, theme_scene_id)
            milestone = _detect_milestone(
                theme_scene.name,
                ms_before_unlocked, ms_before_total,
                ms_after_unlocked, ms_after_total,
            )

            # ⚠️ 測試用：強制觸發（正式上線前務必把 MILESTONE_DEBUG_FORCE 改回 False）
            if MILESTONE_DEBUG_FORCE and milestone is None:
                milestone = {
                    'type': 'complete',  # 想看「過半」樣式改成 'half'
                    'theme_name': theme_scene.name,
                    'unlocked': ms_after_unlocked,
                    'total': ms_after_total,
                    'debug': True,
                }

            # 帶上這個里程碑可以領到什麼，讓慶祝動畫直接告訴使用者「有獎勵待領」
            if milestone:
                cfg = THEME_REWARDS.get(milestone['type'], {})
                milestone['scene_id'] = theme_scene_id
                milestone['reward'] = {
                    'points': cfg.get('points', 0),
                    'extra_photo': cfg.get('extra_photo', 0),
                    'badge': cfg.get('badge', False),
                }

            return jsonify({
                'message': '圖片分析成功並已存入圖鑑',
                'file_path': relative_image_path,
                'result': ai_data,
                'milestone': milestone,  # dict 或 null，供前端結果頁播慶祝動畫
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
            "photo_id": p.id,
            "scene_id": p.scene_id if p.scene_id else 0, 
            "scene_name": p.custom_title or (p.scene.name if p.scene else "單字探險"),
            "icon_name": p.scene.icon_name if p.scene else "image",
            "image_path": p.image_path,
            "context_description": p.context_description, # 當初輸入的情境原文（可為 null）
            "unlocked_at": p.created_at.strftime('%Y.%m.%d'),
            "vocab_count": vocab_count
        })
        
    return jsonify({"scenes": results}), 200

@scenario_bp.route('/themes/<int:user_id>', methods=['GET'])
def get_themes(user_id):
    """主題收集冊：一律列出所有官方主題（即使還沒拍照）＋ 使用者有照片的其他場景。

    每個主題回傳：封面（最近一張照片，未拍過為 null）、探索照數、已解鎖字數、
    目標字數（＝該主題單字牆總數）、完成度、最近拍攝時間。
    完成度 = 該主題已解鎖 distinct 單字數 / 該主題單字總數（與單字牆一致）。
    """
    from models import Scene, Vocab, UserVocab

    # 1. 使用者拍過的照片，依 scene 聚合封面 / 照片數 / 最近時間
    photos = (UserPhoto.query
              .filter_by(user_id=user_id)
              .order_by(UserPhoto.created_at.desc())
              .all())
    photo_agg = {}  # scene_id -> {cover, count, last_at}
    for p in photos:
        sid = p.scene_id or 0
        a = photo_agg.get(sid)
        if a is None:
            a = photo_agg[sid] = {'cover': p.image_path, 'count': 0, 'last_at': p.created_at}
        a['count'] += 1
        if p.created_at and (a['last_at'] is None or p.created_at > a['last_at']):
            a['last_at'] = p.created_at

    # 2. 要顯示的場景集合：所有官方主題（排除「其他」）＋ 使用者有照片的場景
    official_names = [t['name'] for t in THEME_DEFS if t['name'] != '其他']
    scene_by_id = {s.id: s for s in Scene.query.filter(Scene.name.in_(official_names)).all()}
    photo_scene_ids = [sid for sid in photo_agg if sid]
    if photo_scene_ids:
        for s in Scene.query.filter(Scene.id.in_(photo_scene_ids)).all():
            scene_by_id.setdefault(s.id, s)

    # 3. 逐場景統計單字牆數據（完成度只算官方字；AI 額外字另外計為 bonus）
    claimed_set = _claimed_tiers(user_id, list(scene_by_id.keys()))
    results = []
    for sid, scene in scene_by_id.items():
        unlocked, total = _theme_progress(user_id, sid)
        bonus = (UserVocab.query
                 .join(Vocab, UserVocab.vocab_id == Vocab.id)
                 .filter(UserVocab.user_id == user_id,
                         Vocab.scene_id == sid,
                         Vocab.source != OFFICIAL_SOURCE)
                 .count())
        agg = photo_agg.get(sid, {})
        results.append({
            'scene_id': sid,
            'name': scene.name,
            'icon_name': scene.icon_name or 'category',
            'cover_image': agg.get('cover'),
            'photo_count': agg.get('count', 0),
            'unlocked_count': unlocked,
            'target_count': total,
            'bonus_count': bonus,  # 官方清單以外、自己拍到的額外單字
            'progress': min(1.0, round(unlocked / total, 3)) if total else 0.0,
            'last_at': agg['last_at'].strftime('%Y.%m.%d') if agg.get('last_at') else '',
            'rewards': _reward_state(unlocked, total, sid, claimed_set),
        })

    # 4. 排序：有獎勵可領的排最前面，其次是已開始探索的，最後才是還沒碰過的主題
    def _has_claimable(x):
        return any(r['state'] == 'claimable' for r in x['rewards'].values())

    results.sort(key=lambda x: (
        not _has_claimable(x),                               # 可領取的排最前
        x['photo_count'] == 0 and x['unlocked_count'] == 0,  # 未開始的排後面
        -x['unlocked_count'],
        x['name'],
    ))
    return jsonify({'themes': results}), 200


@scenario_bp.route('/claim_theme_reward', methods=['POST'])
def claim_theme_reward():
    """領取主題收集冊的里程碑獎勵（過半 / 集滿）。

    前端傳 { user_id, scene_id, tier }。伺服器自己重算進度後才發，
    不信任前端傳來的完成度；重複領取以 PointTransaction 的憑證擋掉。
    """
    from utils.db import db
    from models import User, Scene, Achievement, UserAchievement, PointTransaction, TransactionType

    data = request.get_json() or {}
    user_id = data.get('user_id')
    scene_id = data.get('scene_id')
    tier = data.get('tier')

    if not user_id or not scene_id or tier not in THEME_REWARDS:
        return jsonify({'error': '缺少 user_id / scene_id，或 tier 不合法'}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': '找不到使用者'}), 404
    scene = Scene.query.get(scene_id)
    if not scene:
        return jsonify({'error': '找不到主題'}), 404

    # 1. 重新計算進度，確認真的達標
    unlocked, total = _theme_progress(user_id, scene_id)
    ratio = (unlocked / total) if total else 0.0
    reached = (unlocked >= total) if tier == 'complete' else (ratio >= 0.5)
    if total <= 0 or not reached:
        return jsonify({'error': '這個主題還沒達到領取條件', 'unlocked': unlocked, 'total': total}), 400

    # 2. 擋重複領取
    key = _reward_key(scene_id, tier)
    if PointTransaction.query.filter_by(user_id=user_id, related_feature=key).first():
        return jsonify({'error': '這個獎勵已經領過了'}), 400

    cfg = THEME_REWARDS[tier]

    # 3. 發點數與額外拍照次數
    user.j_pts = (user.j_pts or 0) + cfg['points']
    if cfg['extra_photo']:
        user.photo_extra_count = (user.photo_extra_count or 0) + cfg['extra_photo']

    db.session.add(PointTransaction(
        user_id=user.id,
        points=cfg['points'],
        price=0,
        payment_method='theme_reward',
        transaction_type=TransactionType.REWARD,
        related_feature=key,  # 同時是「領過了」的憑證
    ))

    # 4. 集滿才發主題徽章（徽章不存在就跳過，不擋領獎）
    badge_name = None
    if cfg['badge']:
        ach = Achievement.query.filter_by(name=theme_badge_name(scene.name)).first()
        if ach:
            owned = UserAchievement.query.filter_by(
                user_id=user_id, achievement_id=ach.id).first()
            if not owned:
                db.session.add(UserAchievement(user_id=user_id, achievement_id=ach.id))
            badge_name = ach.name

    db.session.commit()

    return jsonify({
        'message': '獎勵領取成功！',
        'theme_name': scene.name,
        'tier': tier,
        'label': cfg['label'],
        'pts_earned': cfg['points'],
        'bonus_photo': cfg['extra_photo'],
        'badge_name': badge_name,
        'j_pts': user.j_pts,
    }), 200


@scenario_bp.route('/theme_vocabs/<int:user_id>/<int:scene_id>', methods=['GET'])
def get_theme_vocabs(user_id, scene_id):
    """主題單字牆：回傳某主題的官方收集目標，並標記使用者是否已解鎖。

    - 牆上只放官方字（source='admin'），數量固定，所以「集滿」才有意義。
    - 未解鎖的字不回傳字面（保留剪影神秘感），但給 hint（中文意思）當可行動的線索，
      使用者才知道該去拍什麼；hint_len 用來畫剪影寬度。
    - 使用者自己拍到、官方清單以外的字放進 bonus，不計入完成度。
    """
    from models import Vocab, UserVocab

    vocabs = (Vocab.query
              .filter_by(scene_id=scene_id, source=OFFICIAL_SOURCE)
              .order_by(Vocab.id).all())
    unlocked_ids = {
        uv.vocab_id for uv in UserVocab.query.filter_by(user_id=user_id).all()
    }

    results = []
    unlocked_count = 0
    for v in vocabs:
        if v.id in unlocked_ids:
            unlocked_count += 1
            results.append({
                'vocab_id': v.id,
                'word': v.word,
                'kana': v.kana,
                'meaning': v.meaning,
                'is_unlocked': True,
            })
        else:
            # 剪影：不洩漏日文字面，只給中文意思與長度提示
            results.append({
                'vocab_id': v.id,
                'is_unlocked': False,
                'hint': v.meaning,
                'hint_len': len(v.kana or ''),
            })

    # 已解鎖排前面，剪影排後面
    results.sort(key=lambda x: not x['is_unlocked'])

    # 額外收穫：這個主題裡使用者拍到、但不在官方清單上的字
    bonus_rows = (Vocab.query
                  .join(UserVocab, UserVocab.vocab_id == Vocab.id)
                  .filter(UserVocab.user_id == user_id,
                          Vocab.scene_id == scene_id,
                          Vocab.source != OFFICIAL_SOURCE)
                  .order_by(Vocab.id).all())
    bonus = [{
        'vocab_id': v.id,
        'word': v.word,
        'kana': v.kana,
        'meaning': v.meaning,
        'is_unlocked': True,
    } for v in bonus_rows]

    return jsonify({
        'vocabs': results,
        'total': len(vocabs),
        'unlocked': unlocked_count,
        'bonus': bonus,
    }), 200


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
                "context_sentence": pv.context_sentence,  # 拍照當下的情境例句（可為 null）
                "is_unlocked": True # 有拍到就算解鎖
            })

    return jsonify({"vocabs": results}), 200

@scenario_bp.route('/rename_photo', methods=['POST'])
def rename_photo():
    """
    更新使用者自訂照片名稱
    """
    from utils.db import db
    data = request.json
    photo_id = data.get('photo_id')
    new_title = data.get('custom_title')
    
    if not photo_id or not new_title:
        return jsonify({'error': '缺少 photo_id 或 custom_title'}), 400
        
    photo = UserPhoto.query.get(photo_id)
    if not photo:
        return jsonify({'error': '找不到照片'}), 404
        
    photo.custom_title = new_title
    db.session.commit()

    return jsonify({'message': '修改成功', 'custom_title': new_title}), 200


@scenario_bp.route('/scenes', methods=['GET'])
def get_all_scenes():
    """取得預設場景列表（含 icon_name 與 icon_codepoint）
    ?quick_select=true → 只回傳 show_in_quick_select=True 的場景
    """
    from models import Scene
    quick_select = request.args.get('quick_select', '').lower() == 'true'
    query = Scene.query.order_by(Scene.id)
    if quick_select:
        query = query.filter_by(show_in_quick_select=True)
    scenes = query.all()
    return jsonify([
        {
            'id': s.id,
            'name': s.name,
            'icon_name': s.icon_name,
            'icon_codepoint': s.icon_codepoint,
        }
        for s in scenes
    ]), 200


@scenario_bp.route('/evaluate_sentence', methods=['POST'])
def evaluate_sentence():
    """
    評估使用者用辨識出單字造的句子。
    """
    data = request.json
    sentence = data.get('sentence')
    vocabs = data.get('vocabs')
    context_description = data.get('context_description')

    if not sentence or not vocabs:
        return jsonify({'error': '缺少句子或單字資料'}), 400

    from utils.ai_helper import evaluate_user_sentence
    ai_result = evaluate_user_sentence(sentence, vocabs, context_description)

    if not ai_result.get("success"):
        return jsonify({'error': ai_result.get("error", "評估失敗")}), 500

    return jsonify(ai_result.get("result")), 200