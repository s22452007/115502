from flask import Blueprint, request, jsonify
from models import db, User, PointTransaction, Article, UserArticleUnlock
from datetime import datetime

store_bp = Blueprint('store_bp', __name__)

# 🌟 加購項目扣點配置 (嚴苛版誘餌定價)
ITEM_COSTS = {
    "extra_reading": 20,     # 朗讀評分 20 點
    "extra_chat": 15,        # AI 情境對話 15 點
    "extra_photo": 10,       # 拍照辨識 10 點
    "extra_sentence": 5,     # AI 批改造句 5 點
    "unlock_article": 150,   # 解鎖付費文章 150 點
    "storage_expand": 100    # 擴充單字收藏 100 點
}

@store_bp.route('/items', methods=['GET'])
def get_store_items():
    """提供給前端商城畫面的商品清單"""
    items = [
        {
            "id": "extra_reading",
            "name": "朗讀評分次數",
            "description": "額外增加 1 次 AI 發音與朗讀評分",
            "cost": ITEM_COSTS["extra_reading"]
        },
        {
            "id": "extra_chat",
            "name": "AI 情境對話次數",
            "description": "額外增加 1 次多輪情境模擬對話",
            "cost": ITEM_COSTS["extra_chat"]
        },
        {
            "id": "extra_photo",
            "name": "拍照辨識次數",
            "description": "額外增加 1 次照片單字掃描辨識",
            "cost": ITEM_COSTS["extra_photo"]
        },
        {
            "id": "extra_sentence",
            "name": "AI 批改造句次數",
            "description": "額外增加 1 次日語文法造句 AI 批改",
            "cost": ITEM_COSTS["extra_sentence"]
        },
        {
            "id": "vocab_expand",
            "name": "單字收藏擴充",
            "description": "擴充 20 個單字收藏夾空間",
            "cost": ITEM_COSTS["storage_expand"]
        },
        {
            "id": "vocab_expand_premium",
            "name": "單字收藏擴充 (會員優惠)",
            "description": "擴充 20 個單字收藏夾空間 (Premium 半價)",
            "cost": ITEM_COSTS["storage_expand"] // 2
        }
    ]
    # 回傳 JSON 給前端的 _loadItems()
    return jsonify({"items": items})

@store_bp.route('/purchase_extra', methods=['POST'])
def purchase_extra_feature():
    """處理前端送來的扣點兌換請求"""
    data = request.get_json()
    # 支援前端傳 userId 或 user_id
    user_id = data.get('userId') or data.get('user_id')
    feature_type = data.get('feature')
    quantity = data.get('quantity', 1)

    if not user_id or not feature_type:
        return jsonify({"error": "缺少必要參數"}), 400

    actual_feature = feature_type
    if feature_type in ["vocab_expand", "vocab_expand_premium"]:
        actual_feature = "storage_expand"

    if actual_feature not in ITEM_COSTS:
        return jsonify({"error": "無效的加購項目"}), 400

    cost_per_unit = ITEM_COSTS[actual_feature]
    if feature_type == "vocab_expand_premium":
        cost_per_unit = cost_per_unit // 2
        
    total_cost = cost_per_unit * quantity

    user = User.query.filter_by(id=user_id).first()
    if not user:
        return jsonify({"error": "找不到該使用者"}), 404

    if user.points < total_cost:
        return jsonify({"error": "點數不足喔！請先儲值"}), 400

    try:
        user.points -= total_cost
        
        # 依照兌換項目增加額度
        if actual_feature == "extra_photo":
            user.extra_photos = (user.extra_photos or 0) + quantity
        elif actual_feature == "extra_chat":
            user.extra_chats = (user.extra_chats or 0) + quantity
        elif actual_feature == "extra_sentence":
            user.extra_sentences = (user.extra_sentences or 0) + quantity
        elif actual_feature == "extra_reading":
            user.extra_readings = (user.extra_readings or 0) + quantity
        elif actual_feature == "storage_expand":
            user.max_saved_vocab = (user.max_saved_vocab or 50) + (20 * quantity)

        description_map = {
            "extra_photo": f"加購拍照辨識次數 x {quantity}",
            "extra_chat": f"加購 AI 情境對話次數 x {quantity}",
            "extra_sentence": f"加購 AI 批改造句次數 x {quantity}",
            "extra_reading": f"加購朗讀評分次數 x {quantity}",
            "storage_expand": f"擴充單字收藏空間 x {quantity}"
        }

        # 寫入點數消耗紀錄
        transaction = PointTransaction(
            user_id=user.id,
            amount=-total_cost,
            balance_after=user.points,
            transaction_type="CONSUME",
            description=description_map.get(actual_feature, "加購功能消耗"),
            created_at=datetime.utcnow()
        )
        db.session.add(transaction)
        db.session.commit()

        # 回傳給前端更新錢包餘額
        return jsonify({
            "success": True,
            "total_points": user.points,
            "added_quantity": quantity
        })

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"兌換過程發生錯誤: {str(e)}"}), 500

@store_bp.route('/unlock_article', methods=['POST'])
def unlock_article_service():
    """處理文章解鎖扣點"""
    data = request.get_json()
    user_id = data.get('userId') or data.get('user_id')
    article_id = data.get('articleId') or data.get('article_id')

    user = User.query.filter_by(id=user_id).first()
    article = Article.query.filter_by(id=article_id).first()

    if not user or not article:
        return jsonify({"error": "使用者或文章不存在"}), 404

    cost = getattr(article, 'unlock_cost', None)
    if cost is None or cost <= 0:
        cost = ITEM_COSTS["unlock_article"]

    already_unlocked = UserArticleUnlock.query.filter_by(user_id=user_id, article_id=article_id).first()
    if already_unlocked:
        return jsonify({"error": "此文章已解鎖，無需重複購買"}), 400

    if user.points < cost:
        return jsonify({"error": "點數不足喔！請先儲值"}), 400

    try:
        user.points -= cost
        unlock_record = UserArticleUnlock(
            user_id=user.id,
            article_id=article.id,
            unlocked_at=datetime.utcnow()
        )
        db.session.add(unlock_record)

        transaction = PointTransaction(
            user_id=user.id,
            amount=-cost,
            balance_after=user.points,
            transaction_type="CONSUME",
            description=f"解鎖進階文章: {article.title}",
            created_at=datetime.utcnow()
        )
        db.session.add(transaction)
        db.session.commit()

        return jsonify({
            "success": True,
            "total_points": user.points
        })

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"解鎖失敗: {str(e)}"}), 500