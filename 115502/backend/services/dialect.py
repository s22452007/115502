from flask import Blueprint, jsonify
from models import Dialect

dialect_bp = Blueprint('dialect', __name__)


@dialect_bp.route('/list', methods=['GET'])
def list_dialects():
    """回傳所有啟用中的腔調清單（提供前端讓使用者選擇 AI 對話腔調）"""
    dialects = Dialect.query.filter_by(is_active=True).order_by(Dialect.id).all()
    return jsonify([
        {
            'id': d.id,
            'name': d.name,
            'jp_name': d.jp_name,
            'region': d.region,
            'description': d.description,
        }
        for d in dialects
    ]), 200
