from flask import Blueprint, jsonify
from models import PointPackage
from utils.payment import demo_payment_enabled

store_bp = Blueprint('store', __name__)

# 🌟 加購項目扣點配置 (嚴苛版誘餌定價)
# 實際扣點與給次數在 services/user.py 的 spend_points（App 的商城與各功能頁都呼叫那一支），
# 這裡只定義價格與商城顯示用的清單；兩邊共用同一份價格，改價只改這裡。
ITEM_COSTS = {
    "reading_extra": 20,          # 朗讀評分 20 點／次
    "ai_extra": 15,               # AI 情境對話 15 點／次
    "photo_extra": 10,            # 拍照辨識 10 點／次
    "sentence_extra": 5,          # AI 批改造句 5 點／次（送出造句時直接支付，不在商城清單）
    "unlock_article": 150,        # 解鎖付費文章的預設價格（後台可為每篇文章另外定價）
    "vocab_expand": 100,          # 擴充單字收藏 100 點
    "vocab_expand_premium": 50,   # 訂閱會員半價
}
EXTRA_PER_PURCHASE = 1            # 加購一次給幾次使用次數
VOCAB_SLOTS_PER_PURCHASE = 20     # 擴充一次給幾個收藏位
VOCAB_SLOT_MAX = 1000

# 商城「點數兌換」分頁的商品清單。id 就是 App 傳給 /api/user/spend_points 的 feature
_STORE_ITEMS = [
    {
        'id': 'reading_extra',
        'name': '朗讀評分次數',
        'description': '額外增加 1 次 AI 發音與朗讀評分，永久有效',
        'cost': ITEM_COSTS['reading_extra'],
        'icon': 'record_voice_over',
        'category': 'permanent',
        'unit': '+1 次',
    },
    {
        'id': 'ai_extra',
        'name': 'AI 情境對話次數',
        'description': '額外增加 1 次 AI 情境對話，永久有效',
        'cost': ITEM_COSTS['ai_extra'],
        'icon': 'smart_toy',
        'category': 'permanent',
        'unit': '+1 次',
    },
    {
        'id': 'photo_extra',
        'name': '拍照辨識次數',
        'description': '額外增加 1 次拍照辨識，永久有效',
        'cost': ITEM_COSTS['photo_extra'],
        'icon': 'camera_alt',
        'category': 'permanent',
        'unit': '+1 次',
    },
    {
        'id': 'vocab_expand',
        'name': '單字收藏擴充',
        'description': f'永久新增 {VOCAB_SLOTS_PER_PURCHASE} 個收藏位（上限 {VOCAB_SLOT_MAX} 個）',
        'cost': ITEM_COSTS['vocab_expand'],
        'icon': 'bookmark_add',
        'category': 'permanent',
        'unit': f'+{VOCAB_SLOTS_PER_PURCHASE} 個',
    },
    {
        'id': 'vocab_expand_premium',
        'name': '單字收藏擴充（訂閱優惠）',
        'description': f'訂閱用戶專屬半價，永久新增 {VOCAB_SLOTS_PER_PURCHASE} 個收藏位（上限 {VOCAB_SLOT_MAX} 個）',
        'cost': ITEM_COSTS['vocab_expand_premium'],
        'icon': 'bookmark_add',
        'category': 'permanent',
        'unit': f'+{VOCAB_SLOTS_PER_PURCHASE} 個',
    },
]


@store_bp.route('/packages', methods=['GET'])
def get_packages():
    pkgs = PointPackage.query.filter_by(is_active=True).order_by(PointPackage.price).all()
    return jsonify({'packages': [
        {
            'id': p.id,
            'name': p.name,
            'points': p.points,
            'price': p.price,
            'tag': p.tag or '',
            'description': p.description or '',
        }
        for p in pkgs
    ], 'demo_payment': demo_payment_enabled()}), 200


@store_bp.route('/items', methods=['GET'])
def get_items():
    return jsonify({'items': _STORE_ITEMS}), 200
