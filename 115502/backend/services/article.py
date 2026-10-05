import os
import json
import traceback
import re
from google.genai import types

from utils import gemini_client
from utils.ai_helper import JSON_CONFIG, parse_gemini_json
from flask import Blueprint, request, jsonify
from models import db, User, Article, UnlockedArticle
from datetime import datetime
from models import db, User, Article, ArticleProgress, ScoreRecord, ReadingEvaluation, PointTransaction, TransactionType
from utils.group_helper import add_group_progress_and_check_reward
from utils.account_helper import is_payment_free, has_unlimited_usage, reading_daily_limit, today_start_utc

# 宣告 Blueprint
article_bp = Blueprint('article', __name__)

# 後台沒有指定價格時採用的預設解鎖點數
DEFAULT_UNLOCK_COST = 50


def _can_read(user_id, article):
    """免費文章、教育版學生、或已解鎖的付費文章才可以朗讀評分與結算點數。"""
    if article is None:
        return False
    if article.is_free or is_payment_free(User.query.get(user_id)):
        return True
    return UnlockedArticle.query.filter_by(user_id=user_id, article_id=article.id).first() is not None

# ==========================================
# 1. 取得文章列表 (動態判斷是否已解鎖)
# ==========================================
@article_bp.route('/dashboard', methods=['GET'])
def get_article_dashboard():
    """獲取文章練習列表，並檢查每篇文章的解鎖狀態"""
    user_id = request.args.get('user_id', type=int)
    user_level = request.args.get('level', type=str)
    
    if not user_level and user_id:
        # User 沒有 level 欄位，程度存在 japanese_level（原本找 user.level 永遠找不到，一律變成 N3）
        user = User.query.get(user_id)
        if user and user.japanese_level:
            user_level = user.japanese_level
            
    if not user_level:
        user_level = 'N3'
        
    if not user_id:
        return jsonify({"error": "缺少 user_id"}), 400

    try:
        # 1. 抓出該難度等級「已上架」的所有文章（後台可隨時下架）
        articles = Article.query.filter_by(level=user_level).filter(
            Article.is_published.isnot(False)
        ).order_by(Article.id).all()

        # 2. 抓出這個玩家「已經解鎖」的所有文章 ID 清單
        unlocked_records = UnlockedArticle.query.filter_by(user_id=user_id).all()
        unlocked_article_ids = [record.article_id for record in unlocked_records]

        result = []

        # 教育版學生所有文章一律免費、全部視為已解鎖，
        # 前端就不會顯示任何鎖頭或解鎖價格
        edu_free = is_payment_free(User.query.get(user_id))

        for a in articles:
            # 免費與否改由資料庫欄位決定（後台新增的文章一律為付費）
            is_free = edu_free or bool(a.is_free)
            # 動態判斷：如果是免費文章，或是玩家已經解鎖過，is_unlocked 就是 True
            is_unlocked = is_free or (a.id in unlocked_article_ids)

            result.append({
                "id": a.id,
                "theme": a.theme,
                "level": a.level,
                "title": a.title,
                "content": a.content,
                "translation": a.translation,
                "grammar_points": a.grammar_points,
                "is_free": is_free,
                "unlock_cost": 0 if is_free else (a.unlock_cost or DEFAULT_UNLOCK_COST),
                "is_unlocked": is_unlocked
            })

        # 🌟 關鍵修復：還原為前端預期的格式 {"status": "success", "data": [...]}
        return jsonify({
            "status": "success", 
            "data": result
        }), 200

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ==========================================
# 2. 語音發音評估 (STT + LLM 雙階段真實評分)
# ==========================================
@article_bp.route('/evaluate', methods=['POST'])
def evaluate_audio():
    if 'audio' not in request.files:
        return jsonify({"status": "error", "message": "找不到音訊檔案"}), 400

    audio_file = request.files['audio']
    article_text = request.form.get('article_text', '')

    # 評分要綁定「誰、哪一篇」，結算時才能驗證分數沒被竄改。
    # 比對用的文章內容以資料庫為準，不採用前端傳來的文字 ——
    # 否則只要傳一個很短的句子去比對，就能輕鬆拿高分。
    eval_user_id = request.form.get('user_id', type=int)
    eval_article_id = request.form.get('article_id', type=int)
    eval_article = Article.query.get(eval_article_id) if eval_article_id else None
    if eval_article and eval_article.content:
        article_text = eval_article.content
    # 還沒解鎖的付費文章不能朗讀評分（否則不付解鎖點數也能朗讀領點）
    if eval_user_id and eval_article and not _can_read(eval_user_id, eval_article):
        return jsonify({"status": "error", "message": "請先解鎖這篇文章再朗讀"}), 403

    # 每日朗讀評分次數：免費版 1 次、Premium 5 次，教育版不限。
    # 以今天存下的評分紀錄計算，AI 失敗或聽不清楚沒有產生紀錄，就不會被算進去。
    if eval_user_id:
        eval_user = User.query.get(eval_user_id)
        if eval_user and not has_unlimited_usage(eval_user):
            limit = reading_daily_limit(eval_user)
            used = ReadingEvaluation.query.filter(
                ReadingEvaluation.user_id == eval_user_id,
                ReadingEvaluation.created_at >= today_start_utc(),
            ).count()
            if used >= limit:
                tip = '' if eval_user.is_premium else '升級 Premium 每天可以朗讀 5 次。'
                return jsonify({
                    "status": "quota_exceeded",
                    "message": f"今天的 {limit} 次朗讀評分已經用完了，明天再來挑戰吧！{tip}",
                    "daily_limit": limit,
                }), 200

    # 音檔直接讀進記憶體、以 bytes 內嵌送給 Gemini（新版 SDK）。
    # 不再存成固定檔名的暫存檔再 upload_file：
    #   1. 固定檔名 temp_reading.m4a 會讓兩位學生同時錄音時互相覆蓋
    #   2. 舊版 upload_file 走的是已停止維護的 google.generativeai SDK，
    #      沒有其他功能都有的「金鑰／模型備援、塞車重試」，一出錯就直接失敗
    audio_bytes = audio_file.read()
    if not audio_bytes:
        return jsonify({"status": "error", "message": "錄音檔是空的，請再錄一次。"}), 200
    mime_type = _detect_audio_mime(audio_bytes, audio_file.filename or '', audio_file.mimetype or '')
    print(f"DEBUG: 收到錄音 {len(audio_bytes)} bytes，格式判定為 {mime_type}")

    def _analyze():
        audio_part = types.Part.from_bytes(data=audio_bytes, mime_type=mime_type)

        print("DEBUG: [階段 1] 正在聆聽真實錄音，進行轉錄...")
        stt_prompt = "請仔細聆聽這段日文錄音，『一字不漏』地寫下你聽到的日文。如果發音含糊、唸錯或有口音，請直接寫出你實際聽到的『錯誤發音』，絕對不要自動修正為正確的日文。請只輸出日文文字。"

        stt_response = gemini_client.generate_content('article', [audio_part, stt_prompt])
        transcript = (stt_response.text or '').strip()

        if not transcript or len(transcript) < 2:
            return None  # 交由外層回覆「聽不清楚」的訊息

        print("DEBUG: [階段 2] 正在根據真實錄音進行嚴格比對...")
        feedback_prompt = f"""
        你是一位極度專業的日語發音家教。
        【標準答案】：{article_text}
        【學生真實唸出】：{transcript}

        【重要指令】：
        1. 請嚴格執行比對規則。
        2. 所有的評語、糾正與解釋，請務必全部使用「繁體中文」撰寫，絕對不可以使用日文給予評語。

        請以純 JSON 格式回傳（請不要加上 ```json 等 Markdown 標記，只要 JSON 本身）：
        {{
            "score": 100,
            "mistakes": [],
            "overall_feedback": "請在這裡使用繁體中文撰寫評語"
        }}
        """

        feedback_response = gemini_client.generate_content('article', feedback_prompt, config=JSON_CONFIG)

        raw_text = (feedback_response.text or '').strip()
        match = re.search(r'\{.*\}', raw_text, re.DOTALL)
        if not match:
            raise ValueError(f"Gemini 沒有回傳標準的 JSON 格式：{raw_text[:200]}")

        feedback_data = parse_gemini_json(match.group(0))
        final_score = feedback_data.get("score", 0)

        return {
            "status": "success",
            "transcript": transcript,
            "score": final_score,
            "completion_rate": f"{final_score}%",
            "mistakes": feedback_data.get("mistakes", []),
            "overall_feedback": feedback_data.get("overall_feedback", "做得好！繼續保持練習。")
        }

    try:
        result = _analyze()
        if result is None:
            return jsonify({
                "status": "error",
                "message": "無法辨識到有效的語音，請確認麥克風收音或大聲再試一次！"
            }), 200

        # 把 AI 給的分數存在後端，前端只拿到 evaluation_id，結算時以這裡存的分數為準。
        # 沒帶 user_id / article_id 的呼叫拿不到 id，也就無法結算成績。
        if eval_user_id and eval_article:
            try:
                raw_score = float(result.get('score') or 0)
            except (TypeError, ValueError):
                raw_score = 0
            evaluation = ReadingEvaluation(
                user_id=eval_user_id,
                article_id=eval_article.id,
                score=max(0, min(100, int(raw_score))),
            )
            db.session.add(evaluation)
            db.session.commit()
            result['evaluation_id'] = evaluation.id
            result['score'] = evaluation.score  # 讓畫面顯示的分數跟存下來的一致
        return jsonify(result), 200

    except gemini_client.GeminiQuotaExhausted as e:
        # 額度用完：給使用者看得懂的說明
        return jsonify({"status": "error", "message": str(e)}), 200

    except gemini_client.GeminiNotConfigured as e:
        print(f"⚠️ {e}")
        return jsonify({"status": "error", "message": "語音評分服務尚未設定完成，請聯繫開發人員。"}), 200

    except Exception as e:
        traceback.print_exc()
        print(f"🚨 [article] 語音評分失敗：{type(e).__name__}: {e}")
        if gemini_client.is_overloaded_error(e):
            return jsonify({"status": "error", "message": "AI 服務目前使用人數較多，請稍等幾秒再試一次。"}), 200
        return jsonify({"status": "error", "message": "語音評分失敗了，請確認網路連線後再錄一次。"}), 200


def _detect_audio_mime(data, filename='', declared=''):
    """
    依檔案開頭的位元組判斷錄音格式。
    前端手機端存的是 .m4a，但網頁版錄出來的其實是 webm/ogg，卻同樣取名 web_audio.m4a，
    照副檔名送給 Gemini 會被拒絕，所以以實際內容為準。
    """
    head = data[:16]
    if len(data) >= 12 and data[4:8] == b'ftyp':
        return 'audio/mp4'                      # m4a / mp4 容器（iOS、Android 的 record 套件）
    if head.startswith(b'\x1a\x45\xdf\xa3'):
        return 'audio/webm'                     # Chrome 網頁版 MediaRecorder
    if head.startswith(b'OggS'):
        return 'audio/ogg'                      # Firefox 網頁版
    if head.startswith(b'RIFF') and data[8:12] == b'WAVE':
        return 'audio/wav'
    if head.startswith(b'fLaC'):
        return 'audio/flac'
    if head.startswith(b'ID3') or (len(head) >= 2 and head[0] == 0xFF and (head[1] & 0xE0) == 0xE0):
        return 'audio/mpeg'                     # mp3
    # 認不出來：用前端宣告的 mimetype，再不然依副檔名猜
    if declared.startswith('audio/'):
        return declared
    ext = os.path.splitext(filename)[1].lower()
    return {'.m4a': 'audio/mp4', '.mp4': 'audio/mp4', '.aac': 'audio/aac',
            '.webm': 'audio/webm', '.ogg': 'audio/ogg', '.wav': 'audio/wav',
            '.mp3': 'audio/mpeg'}.get(ext, 'audio/mp4')


# 註：原本這裡有 GET /api/articles/seed，不需登入、呼叫一次就會刪光全部文章並換成 3 篇測試文章，
#     前端也沒有使用，已移除。需要測試文章請在後台新增，或執行 seed_articles.py。


# ==========================================
# 4. 解鎖文章 API (配合原有系統，單純寫入紀錄)
# ==========================================
@article_bp.route('/unlock', methods=['POST'])
def unlock_article():
    data = request.get_json()
    user_id = data.get('user_id')
    article_id = data.get('article_id')

    if not user_id or not article_id:
        return jsonify({"error": "缺少必要參數"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"status": "error", "message": "找不到使用者"}), 404

    article = Article.query.get(article_id)
    if not article:
        return jsonify({"status": "error", "message": "找不到文章"}), 404

    # 免費文章不需要解鎖紀錄，直接放行
    if article.is_free:
        return jsonify({
            "status": "success",
            "message": "此文章免費閱讀",
            "cost": 0,
            "new_j_pts": user.j_pts or 0
        }), 200

    # 1. 檢查是否已經解鎖過
    existing_unlock = UnlockedArticle.query.filter_by(user_id=user_id, article_id=article_id).first()
    if existing_unlock:
        return jsonify({
            "status": "already_unlocked",
            "message": "此文章已解鎖",
            "new_j_pts": user.j_pts or 0
        }), 200

    # 2. 以後台設定的價格為準，點數不足就擋下來。
    #    教育版學生所有文章免費，成本直接歸零、不做點數檢查。
    cost = 0 if is_payment_free(user) else (
        article.unlock_cost if article.unlock_cost is not None else DEFAULT_UNLOCK_COST
    )
    if cost > 0 and (user.j_pts or 0) < cost:
        return jsonify({
            "status": "not_enough_points",
            "message": f"J-pts 不足，解鎖此文章需要 {cost} 點",
            "cost": cost,
            "new_j_pts": user.j_pts or 0
        }), 400

    try:
        # 3. 扣點並寫入解鎖紀錄
        user.j_pts = (user.j_pts or 0) - cost
        new_unlock = UnlockedArticle(user_id=user_id, article_id=article_id)
        db.session.add(new_unlock)
        # 扣點也要記一筆交易紀錄，App 交易紀錄與後台使用者詳細頁才看得到
        if cost > 0:
            db.session.add(PointTransaction(
                user_id=user_id,
                points=-cost,
                price=0,
                payment_method='points',
                transaction_type=TransactionType.SPEND,
                related_feature='article_unlock',
            ))
        db.session.commit()

        return jsonify({
            "status": "success", 
            "message": "解鎖成功",
            "cost": cost,
            "new_j_pts": user.j_pts
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"解鎖失敗: {str(e)}"}), 500


    # ==========================================
# 🌟 新增：成績結算與點數獎勵 API
# ==========================================
@article_bp.route('/submit_score', methods=['POST'])
def submit_score():
    data = request.get_json()
    user_id = data.get('user_id')
    article_id = data.get('article_id')
    evaluation_id = data.get('evaluation_id')

    if not user_id or not article_id:
        return jsonify({"error": "缺少必要參數"}), 400

    # 分數只認後端存下的 AI 評分結果，前端送來的 score 一律不採用。
    # 同時確認這筆評分是這個人、這篇文章的，而且還沒結算過。
    evaluation = ReadingEvaluation.query.get(evaluation_id) if evaluation_id else None
    if (evaluation is None
            or evaluation.user_id != int(user_id)
            or evaluation.article_id != int(article_id)):
        return jsonify({"status": "error", "error": "找不到這次的朗讀評分，請重新錄音"}), 404
    if evaluation.settled_at is not None:
        return jsonify({"status": "error", "error": "這次的朗讀成績已經結算過了"}), 409
    if not _can_read(int(user_id), Article.query.get(int(article_id))):
        return jsonify({"status": "error", "error": "請先解鎖這篇文章"}), 403
    score = evaluation.score

    try:
        # 1. 🏅 區間點數獎勵邏輯 (90分以上50點, 80分以上30點, 及格10點, 參加5點)
        points_earned = 50 if score >= 90 else (30 if score >= 80 else (10 if score >= 60 else 5))

        # 2. 📈 檢查最高分並更新 ArticleProgress
        progress = ArticleProgress.query.filter_by(user_id=user_id, article_id=article_id).first()
        is_new_record = False
        highest_score = score

        if not progress:
            # 第一次測驗
            progress = ArticleProgress(user_id=user_id, article_id=article_id, score=score, is_completed=True)
            db.session.add(progress)
            is_new_record = True
        else:
            highest_score = progress.score
            if score > progress.score:
                progress.score = score  # 刷新最高分
                is_new_record = True
                highest_score = score

        # 3. 💾 寫入本次成績「歷史紀錄」
        new_record = ScoreRecord(user_id=user_id, article_id=article_id, score=score, points_earned=points_earned)
        db.session.add(new_record)

        # 4. 💰 更新使用者的總點數 (j_pts)
        user = User.query.get(user_id)
        if user:
            user.j_pts = (user.j_pts or 0) + points_earned
            # 得到的點數也記一筆交易紀錄（跟每日任務獎勵一樣）
            db.session.add(PointTransaction(
                user_id=user_id,
                points=points_earned,
                price=0,
                payment_method='reading_reward',
                transaction_type=TransactionType.REWARD,
                related_feature='reading_score_reward',
            ))

        # 5. 📊 更新小組閱讀進度（分數 >= 60 才算完成）
        if score >= 60:
            try:
                add_group_progress_and_check_reward(user_id, 'articles', 1)
            except Exception as ge:
                print(f"⚠️ 更新小組閱讀進度失敗（不影響成績結算）：{ge}")

        # 這筆評分結算完就作廢，不能再拿同一次成績重複領點數
        evaluation.settled_at = datetime.utcnow()
        db.session.commit()

        response = {
            "status": "success",
            "score": score,
            "points_earned": points_earned,
            "total_points": user.j_pts if user else 0,
            "is_new_record": is_new_record,
            "highest_score": highest_score,
            "progress_id": progress.id,  # 作業繳交用的作答紀錄 id
            "message": "成績結算成功！"
        }

        # 從作業進來的閱讀：結算完直接繳交
        from services.student_assignment import auto_submit
        assignment_result = auto_submit(user_id, data.get('assignment_id'), progress.id)
        if assignment_result is not None:
            response['assignment_result'] = assignment_result

        return jsonify(response), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

# ==========================================
# 🌟 新增：查詢個人歷史成績 API
# ==========================================
@article_bp.route('/history/<int:user_id>', methods=['GET'])
def get_user_history(user_id):
    try:
        # 按照時間由新到舊排序
        records = ScoreRecord.query.filter_by(user_id=user_id).order_by(ScoreRecord.created_at.desc()).all()
        
        result = []
        for r in records:
            article = Article.query.get(r.article_id)
            result.append({
                "record_id": r.id,
                "article_title": article.title if article else "已刪除的文章",
                "score": r.score,
                "points_earned": r.points_earned,
                "date": r.created_at.strftime('%Y-%m-%d %H:%M')
            })

        return jsonify({"status": "success", "data": result}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500