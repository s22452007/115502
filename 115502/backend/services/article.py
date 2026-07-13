from flask import Blueprint, request, jsonify
from models import db, Article, User, ArticleProgress
import random

article_bp = Blueprint('article', __name__)

@article_bp.route('/dashboard', methods=['GET'])
def get_article_dashboard():
    """
    獲取文章練習主頁的5個主題文章
    支援參數: ?user_id=1&level=N3 (level可選，若無則自動查user表或預設N3)
    """
    user_id = request.args.get('user_id', type=int)
    user_level = request.args.get('level', type=str)
    
    # 雙重保險機制：如果前端沒傳level，就去資料庫查該使用者的等級
    if not user_level and user_id:
        user = User.query.get(user_id)
        if user and hasattr(user, 'level') and user.level:
            user_level = user.level
            
    # 如果都拿不到，預設為 N3 等級
    if not user_level:
        user_level = 'N3'
        
    # 定義你要求的 5 個主要主題
    themes = ['日常生活', '日本文化', '旅遊觀光', '職場應用', '流行動漫']
    dashboard_data = []
    
    try:
        for theme in themes:
            # 撈出該等級、該主題的所有文章
            articles = Article.query.filter_by(level=user_level, theme=theme).all()
            
            if articles:
                # 從中隨機抽取一篇，達到「每次點進去或刷新都有新鮮感」的效果
                chosen = random.choice(articles)
                dashboard_data.append({
                    "id": chosen.id,
                    "theme": chosen.theme,
                    "title": chosen.title,
                    "level": chosen.level,
                    "content": chosen.content,
                    "translation": chosen.translation,
                    "grammar_points": chosen.grammar_points # JSON 格式會自動解析
                })
            else:
                # 預留骨架，防止資料庫完全沒資料時前端崩潰
                dashboard_data.append({
                    "id": 0,
                    "theme": theme,
                    "title": f"暫無 {user_level} 程度的文章",
                    "level": user_level,
                    "content": "このテーマの記事はまだありません。",
                    "translation": "這個主題目前還沒有文章喔！",
                    "grammar_points": []
                })
                
        return jsonify({
            "status": "success",
            "data": dashboard_data
        }), 200
        
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": f"撈取文章失敗: {str(e)}"
        }), 500