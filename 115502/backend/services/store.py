from flask import Blueprint, jsonify
from models import PointPackage

store_bp = Blueprint('store', __name__)

# 商店可購買的功能道具（靜態定義，後端維護）
_STORE_ITEMS = [
    {
        'id': 'photo_extra',
        'name': '拍照辨識加購',
        'description': '+5 次拍照辨識，永久有效',
        'cost': 30,
        'icon': 'camera_alt',
        'category': 'permanent',
        'unit': '+5 次',
    },
    {
        'id': 'ai_extra',
        'name': 'AI 對話加購',
        'description': '+5 次 AI 對話，永久有效',
        'cost': 30,
        'icon': 'smart_toy',
        'category': 'permanent',
        'unit': '+5 次',
    },
    {
        'id': 'vocab_expand',
        'name': '單字收藏擴充',
        'description': '永久新增 50 個收藏位（上限 500 個）',
        'cost': 50,
        'icon': 'bookmark_add',
        'category': 'permanent',
        'unit': '+50 個',
    },
    {
        'id': 'vocab_expand_premium',
        'name': '單字收藏擴充（訂閱優惠）',
        'description': '訂閱用戶專屬 6 折，永久新增 50 個收藏位（上限 500 個）',
        'cost': 30,
        'icon': 'bookmark_add',
        'category': 'permanent',
        'unit': '+50 個',
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
    ]}), 200


@store_bp.route('/items', methods=['GET'])
def get_items():
    return jsonify({'items': _STORE_ITEMS}), 200
