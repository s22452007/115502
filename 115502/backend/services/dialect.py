import os
from flask import Blueprint, jsonify
from models import Dialect

dialect_bp = Blueprint('dialect', __name__)

# 試聽音檔：事先用 generate_dialect_samples.py 產生好放在 static/，
# 試聽時直接播檔案，不會每次都去消耗語音模型的額度。
SAMPLE_DIR_NAME = 'dialect_samples'
SAMPLE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          'static', SAMPLE_DIR_NAME)
SAMPLE_VOICES = ('female', 'male')


def sample_url(dialect_id, voice):
    """試聽音檔的網址（相對於伺服器根目錄）；還沒產生就回傳 None"""
    for ext in ('wav', 'mp3'):
        filename = f'{dialect_id}_{voice}.{ext}'
        if os.path.exists(os.path.join(SAMPLE_DIR, filename)):
            return f'/static/{SAMPLE_DIR_NAME}/{filename}'
    return None


@dialect_bp.route('/list', methods=['GET'])
def list_dialects():
    """回傳所有啟用中的腔調清單（提供前端讓使用者選擇 AI 對話腔調，含男女聲試聽音檔）"""
    dialects = Dialect.query.filter_by(is_active=True).order_by(Dialect.id).all()
    return jsonify([
        {
            'id': d.id,
            'name': d.name,
            'jp_name': d.jp_name,
            'region': d.region,
            'description': d.description,
            'samples': {v: sample_url(d.id, v) for v in SAMPLE_VOICES},
        }
        for d in dialects
    ]), 200
