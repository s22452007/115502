import os
import tempfile
import json
import traceback
import re
import random
import time
import google.generativeai as genai
from flask import Blueprint, request, jsonify
from models import db, Article, User, ArticleProgress

# 宣告 Blueprint
article_bp = Blueprint('article', __name__)

# ==========================================
# 1. 取得文章列表 (Dashboard)
# ==========================================
@article_bp.route('/dashboard', methods=['GET'])
def get_article_dashboard():
    """獲取文章練習主頁的5個主題文章"""
    user_id = request.args.get('user_id', type=int)
    user_level = request.args.get('level', type=str)
    
    if not user_level and user_id:
        user = User.query.get(user_id)
        if user and hasattr(user, 'level') and user.level:
            user_level = user.level
            
    if not user_level:
        user_level = 'N3'
        
    themes = ['日常生活', '日本文化', '旅遊觀光', '職場應用', '流行動漫']
    dashboard_data = []
    
    try:
        for theme in themes:
            articles = Article.query.filter_by(level=user_level, theme=theme).all()
            if articles:
                chosen = random.choice(articles)
                dashboard_data.append({
                    "id": chosen.id,
                    "theme": chosen.theme,
                    "title": chosen.title,
                    "level": chosen.level,
                    "content": chosen.content,
                    "translation": chosen.translation,
                    "grammar_points": chosen.grammar_points
                })
            else:
                dashboard_data.append({
                    "id": 0, "theme": theme, "title": f"暫無 {user_level} 程度的文章",
                    "level": user_level, "content": "このテーマの記事はまだありません。",
                    "translation": "這個主題目前還沒有文章喔！", "grammar_points": []
                })
                
        return jsonify({"status": "success", "data": dashboard_data}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ==========================================
# 2. 語音發音評估 (STT + LLM 雙階段真實評分)
# ==========================================
@article_bp.route('/evaluate', methods=['POST'])
def evaluate_audio():
    """
    【100% 真實語音評估架構 - 精準模型導航版】
    """
    if 'audio' not in request.files:
        return jsonify({"status": "error", "message": "找不到音訊檔案"}), 400

    audio_file = request.files['audio']
    article_text = request.form.get('article_text', '')

    temp_dir = tempfile.gettempdir()
    temp_path = os.path.join(temp_dir, "temp_reading.m4a")
    audio_file.save(temp_path)
    audio_upload = None

    try:
        # 🌟 1. 上傳音檔並「智慧等待」
        print("DEBUG: [階段 0] 正在將錄音檔上傳至 Google 伺服器...")
        audio_upload = genai.upload_file(temp_path)
        
        # 確保檔案處理完畢 (處理中則每秒檢查一次)
        while getattr(audio_upload.state, 'name', '') == 'PROCESSING' or audio_upload.state == 1:
            print("...", end="", flush=True)
            time.sleep(1)
            audio_upload = genai.get_file(audio_upload.name)
        print(f"\nDEBUG: 音檔處理完成！狀態: {getattr(audio_upload.state, 'name', audio_upload.state)}")

        # 🌟 2. 精準掃描，自動挑選最佳語音模型 (避開廢棄的 robotics 模型)
        available_models = [m.name for m in genai.list_models() if 'generateContent' in m.supported_generation_methods]
        print(f"DEBUG: 您的 API Key 擁有以下模型權限: {available_models}")
        
        best_model = None
        
        # 優先挑選 Flash (速度快、適合語音)，排除 robotics
        flash_models = [m for m in available_models if 'flash' in m.lower() and 'robotics' not in m.lower()]
        # 備案挑選 Pro，排除 robotics 與純文字的 1.0
        pro_models = [m for m in available_models if 'pro' in m.lower() and 'robotics' not in m.lower() and '1.0' not in m]
        
        if flash_models:
            best_model = flash_models[0]
        elif pro_models:
            best_model = pro_models[0]
        else:
            # 如果真的都沒有，挑選任何不是 robotics 的模型
            safe_models = [m for m in available_models if 'robotics' not in m.lower()]
            if safe_models:
                best_model = safe_models[0]
            else:
                raise ValueError(f"找不到可用的語音模型！目前擁有的模型：{available_models}")
                
        print(f"DEBUG: 🎯 系統已為您自動掛載最佳語音模型 -> {best_model}")
        model = genai.GenerativeModel(best_model)

        # 🟢 3. 第一階段：AI 真實聽寫 (STT)
        print(f"DEBUG: [階段 1] 正在聆聽真實錄音，進行轉錄 (使用 {best_model})...")
        stt_prompt = "請仔細聆聽這段日文錄音，『一字不漏』地寫下你聽到的日文。如果發音含糊、唸錯或有口音，請直接寫出你實際聽到的『錯誤發音』，絕對不要自動修正為正確的日文。請只輸出日文文字。"
        
        stt_response = model.generate_content([stt_prompt, audio_upload])
        stt_response.resolve()
        transcript = stt_response.text.strip()
        print(f"DEBUG: [STT 真實聽寫結果] 學生實際唸出: {transcript}")

        if not transcript or len(transcript) < 2:
            return jsonify({"status": "error", "message": "無法辨識到有效的語音，請確認麥克風收音或大聲再試一次！"}), 200

        # 🟢 4. 第二階段：AI 真實發音比對與點評
        print("DEBUG: [階段 2] 正在根據真實錄音進行嚴格比對...")
        feedback_prompt = f"""
        你是一位極度專業的日語發音家教。
        
        【標準答案】：{article_text}
        【學生真實唸出】：{transcript}
        
        請嚴格執行以下比對規則：
        1. 讀音對齊：請專注比對兩者的「實際發音（假名讀音）」。如果「漢字」與「平假名/片假名」的寫法不同，但「發音完全一樣」，請視為【完全正確】，絕對不扣分！
        2. 真實給分：請完全依照學生「真實唸出」的內容給分。如果發音完全正確給 100 分；每唸錯、漏唸或多唸一個發音，扣 3~5 分。
        3. 抓出真錯：只針對「學生真實唸出」的錯誤進行糾正。請在 mistakes 中精確指出錯誤，例如：『環境』的發音應為『かんきょう』，但唸成了『かんこ』。如果發音完全正確，請給空陣列 []。
        4. 真實評語：根據學生真實犯的錯，給予具體改進建議。
        
        ⚠️ 警告：必須「只」回傳純 JSON 格式。
        {{
            "score": 100,
            "mistakes": [],
            "overall_feedback": "評語寫這裡"
        }}
        """
        
        feedback_response = model.generate_content(feedback_prompt)
        feedback_response.resolve()

        raw_text = feedback_response.text.strip()
        print(f"DEBUG: [LLM 原始回饋字串] {raw_text}") 

        # 🌟 終極防禦：用正規表達式強行挖出 JSON 區塊
        match = re.search(r'\{.*\}', raw_text, re.DOTALL)
        if not match:
            raise ValueError(f"Gemini 沒有回傳標準的 JSON 格式。回傳內容為: {raw_text}")
            
        json_str = match.group(0)
        feedback_data = json.loads(json_str)
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
        print(f"====== ❌ 語音評估發生真實錯誤 ======")
        traceback.print_exc()
        print("================================================")
        return jsonify({
            "status": "error", 
            "message": f"解析失敗原因: {str(e)}"
        }), 200

    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        if audio_upload:
            try:
                genai.delete_file(audio_upload.name)
            except:
                pass


# ==========================================
# 3. 自動建立測試文章工具 (一鍵 Seed)
# ==========================================
@article_bp.route('/seed', methods=['GET'])
def seed_articles():
    """自動為資料庫注入測試用的日文文章"""
    try:
        existing = Article.query.first()
        if existing:
            return jsonify({"message": "資料庫已經有文章囉，不需要重複建立！"}), 200

        dummy_articles = [
            Article(
                theme="日常生活", level="N3", title="朝のルーティン (早晨日常)",
                content="私は毎朝早く起きて、コーヒーを飲みながら新聞を読みます。その後、公園を散歩するのが日課です。",
                translation="我每天早上早起，一邊喝咖啡一邊看報紙。之後去公園散步是我的例行公事。",
                grammar_points={"grammars": [{"expression": "〜ながら", "meaning": "一邊...一邊...", "example": "音楽を聴きながら勉強します。"}]}
            ),
            Article(
                theme="日本文化", level="N3", title="神社での初詣",
                content="日本では、お正月に神社へ行って新しい年を祝います。これを初詣と言います。",
                translation="在日本，過年時會去神社慶祝新年。這被稱為初詣。",
                grammar_points={"grammars": [{"expression": "〜と言います", "meaning": "叫做...", "example": "この花は桜と言います。"}]}
            ),
            Article(
                theme="旅遊觀光", level="N3", title="京都の秋",
                content="秋の京都は紅葉がとても美しいです。多くの観光客が写真を撮りに来ます。",
                translation="秋天的京都楓葉非常美麗。許多觀光客會來拍照。",
                grammar_points={"grammars": [{"expression": "〜に来ます", "meaning": "來做(某事)", "example": "日本へ日本語を勉強しに来ました。"}]}
            )
        ]
        
        db.session.add_all(dummy_articles)
        db.session.commit()
        return jsonify({"message": "✅ 測試文章建立成功！請重整 App 畫面。"}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"建立失敗: {str(e)}"}), 500