import os
import tempfile
import json
import traceback
import re
import random
import time
import google.generativeai as genai

from flask import Blueprint, request, jsonify
from models import db, User, Article, UnlockedArticle
from datetime import datetime

# 宣告 Blueprint
article_bp = Blueprint('article', __name__)

# ==========================================
# 1. 取得文章列表 (動態判斷是否已解鎖)
# ==========================================
@article_bp.route('/dashboard', methods=['GET'])
def get_article_dashboard():
    """獲取文章練習列表，並檢查每篇文章的解鎖狀態"""
    user_id = request.args.get('user_id', type=int)
    user_level = request.args.get('level', type=str)
    
    if not user_level and user_id:
        user = User.query.get(user_id)
        if user and hasattr(user, 'level') and user.level:
            user_level = user.level
            
    if not user_level:
        user_level = 'N3'
        
    if not user_id:
        return jsonify({"error": "缺少 user_id"}), 400

    try:
        # 1. 抓出該難度等級的所有文章
        articles = Article.query.filter_by(level=user_level).all()

        # 2. 抓出這個玩家「已經解鎖」的所有文章 ID 清單
        unlocked_records = UnlockedArticle.query.filter_by(user_id=user_id).all()
        unlocked_article_ids = [record.article_id for record in unlocked_records]

        result = []
       # 這些 ID 對應各級別的 5 篇一般文章，使用者不需付費即可閱讀
        free_article_ids = [
            101, 102, 103, 104, 105,  # N5
            201, 202, 203, 204, 205,  # N4
            301, 302, 303, 304, 305,  # N3
            401, 402, 403, 404, 405,  # N2
            501, 502, 503, 504, 505   # N1
]

        for a in articles:
            # 動態判斷：如果是免費文章，或是玩家已經解鎖過，is_unlocked 就是 True
            is_unlocked = (a.id in free_article_ids) or (a.id in unlocked_article_ids)

            result.append({
                "id": a.id,
                "theme": a.theme,
                "level": a.level,
                "title": a.title,
                "content": a.content,
                "translation": a.translation,
                "grammar_points": a.grammar_points,
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

    temp_dir = tempfile.gettempdir()
    temp_path = os.path.join(temp_dir, "temp_reading.m4a")
    audio_file.save(temp_path)
    audio_upload = None

    try:
        print("DEBUG: [階段 0] 正在將錄音檔上傳至 Google 伺服器...")
        audio_upload = genai.upload_file(temp_path)
        
        while getattr(audio_upload.state, 'name', '') == 'PROCESSING' or audio_upload.state == 1:
            print("...", end="", flush=True)
            time.sleep(1)
            audio_upload = genai.get_file(audio_upload.name)
        print(f"\nDEBUG: 音檔處理完成！狀態: {getattr(audio_upload.state, 'name', audio_upload.state)}")

        available_models = [m.name for m in genai.list_models() if 'generateContent' in m.supported_generation_methods]
        best_model = None
        
        flash_models = [m for m in available_models if 'flash' in m.lower() and 'robotics' not in m.lower()]
        pro_models = [m for m in available_models if 'pro' in m.lower() and 'robotics' not in m.lower() and '1.0' not in m]
        
        if flash_models:
            best_model = flash_models[0]
        elif pro_models:
            best_model = pro_models[0]
        else:
            safe_models = [m for m in available_models if 'robotics' not in m.lower()]
            if safe_models:
                best_model = safe_models[0]
            else:
                raise ValueError(f"找不到可用的語音模型！")
                
        model = genai.GenerativeModel(best_model)

        print(f"DEBUG: [階段 1] 正在聆聽真實錄音，進行轉錄...")
        stt_prompt = "請仔細聆聽這段日文錄音，『一字不漏』地寫下你聽到的日文。如果發音含糊、唸錯或有口音，請直接寫出你實際聽到的『錯誤發音』，絕對不要自動修正為正確的日文。請只輸出日文文字。"
        
        stt_response = model.generate_content([stt_prompt, audio_upload])
        stt_response.resolve()
        transcript = stt_response.text.strip()

        if not transcript or len(transcript) < 2:
            return jsonify({"status": "error", "message": "無法辨識到有效的語音，請確認麥克風收音或大聲再試一次！"}), 200

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
        
        feedback_response = model.generate_content(feedback_prompt)
        feedback_response.resolve()

        raw_text = feedback_response.text.strip()
        match = re.search(r'\{.*\}', raw_text, re.DOTALL)
        if not match:
            raise ValueError(f"Gemini 沒有回傳標準的 JSON 格式。")
            
        feedback_data = json.loads(match.group(0))
        final_score = feedback_data.get("score", 0)

        return jsonify({
            "status": "success",
            "transcript": transcript,
            "score": final_score,
            "completion_rate": f"{final_score}%",
            "mistakes": feedback_data.get("mistakes", []),
            "overall_feedback": feedback_data.get("overall_feedback", "做得好！繼續保持練習。")
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"status": "error", "message": f"解析失敗原因: {str(e)}"}), 200

    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        if audio_upload:
            try:
                genai.delete_file(audio_upload.name)
            except:
                pass


# ==========================================
# 3. 強制重設並注入帶有 Ruby 假名的測試文章
# ==========================================
@article_bp.route('/seed', methods=['GET'])
def seed_articles():
    """自動清除舊文章，並強制注入帶有假名標註的日文文章"""
    try:
        Article.query.delete()
        db.session.commit()

        dummy_articles = [
            Article(
                theme="日常生活", level="N3", title="朝のルーティン (早晨日常)",
                content="<ruby>私<rt>わたし</rt></ruby>は<ruby>毎朝<rt>まいあさ</rt></ruby><ruby>早<rt>はや</rt></ruby>く<ruby>起<rt>お</rt></ruby>きて、コーヒーを飲みながら<ruby>新聞<rt>しんぶん</rt></ruby>を<ruby>読<rt>よ</rt></ruby>みます。その後、<ruby>公園<rt>こうえん</rt></ruby>を<ruby>散歩<rt>さんぽ</rt></ruby>するのが<ruby>日課<rt>にっか</rt></ruby>です。",
                translation="我每天早上早起，一邊喝咖啡一邊看報紙。之後去公園散步是我的例行公事。",
                grammar_points={"grammars": [{"expression": "〜ながら", "meaning": "一邊...一邊...", "example": "音楽を聴きながら勉強します。"}]}
            ),
            Article(
                theme="日本文化", level="N3", title="神社での初詣",
                content="<ruby>日本<rt>にほん</rt></ruby>では、お<ruby>正月<rt>しょうがつ</rt></ruby>に<ruby>神社<rt>じんじゃ</rt></ruby>へ<ruby>行<rt>い</rt></ruby>って<ruby>新<rt>あたら</rt></ruby>しい<ruby>年<rt>とし</rt></ruby>を<ruby>祝<rt>いわ</rt></ruby>います。これを<ruby>初詣<rt>はつもうで</rt></ruby>と言います。",
                translation="在日本，過年時會去神社慶祝新年。這被稱為初詣。",
                grammar_points={"grammars": [{"expression": "〜と言います", "meaning": "叫做...", "example": "この花は桜と言います。"}]}
            ),
            Article(
                theme="旅遊觀光", level="N3", title="京都の秋",
                content="<ruby>秋<rt>あき</rt></ruby>の<ruby>京都<rt>きょうと</rt></ruby>は<ruby>紅葉<rt>こうよう</rt></ruby>がとても<ruby>美<rt>うつく</rt></ruby>しいです。<ruby>多<rt>おお</rt></ruby>くの<ruby>観光客<rt>かんこうきゃく</rt></ruby>が<ruby>写真<rt>しゃしん</rt></ruby>を<ruby>撮<rt>と</rt></ruby>りに来ます。",
                translation="秋天的京都楓葉非常美麗。許多觀光客會來拍照。",
                grammar_points={"grammars": [{"expression": "〜に来ます", "meaning": "來做(某事)", "example": "日本へ日本語を勉強しに来ました。"}]}
            )
        ]
        
        db.session.add_all(dummy_articles)
        db.session.commit()
        return jsonify({"message": "✅ 成功清除舊資料，並已注入帶有假名的最新測試文章！"}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"建立失敗: {str(e)}"}), 500


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

    # 1. 檢查是否已經解鎖過
    existing_unlock = UnlockedArticle.query.filter_by(user_id=user_id, article_id=article_id).first()
    if existing_unlock:
        return jsonify({"status": "already_unlocked", "message": "此文章已解鎖"}), 200

    try:
        # 2. 單純寫入解鎖紀錄 (點數檢查與扣除交由 Flutter 前端處理)
        new_unlock = UnlockedArticle(user_id=user_id, article_id=article_id)
        db.session.add(new_unlock)
        db.session.commit()

        return jsonify({
            "status": "success", 
            "message": "解鎖成功"
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"解鎖失敗: {str(e)}"}), 500