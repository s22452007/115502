# -*- coding: utf-8 -*-
"""
日語語音合成 API（使用 gTTS，免費且不需 API 金鑰）。

加了記憶體快取：同一句話只會真的合成一次，之後直接回傳快取結果。
使用者常常會重複點同一句練習發音，快取可以省下每次 1~2 秒的合成與網路時間。
"""
from flask import Blueprint, request, jsonify
import io
import base64
import threading
from collections import OrderedDict
from gtts import gTTS

# 建立 Blueprint
tts_bp = Blueprint('tts', __name__)

# ==========================================
# 語音快取（LRU：最久沒用到的先被淘汰）
# ==========================================
# 一句日語的 MP3 約 20~40KB，200 筆大約 4~8MB，記憶體負擔很小。
_CACHE_MAX_SIZE = 200
_cache = OrderedDict()          # {文字: base64 音訊}
_cache_lock = threading.Lock()  # Flask 可能多執行緒同時處理請求，加鎖保護


def _cache_get(text):
    with _cache_lock:
        if text in _cache:
            _cache.move_to_end(text)  # 標記為最近使用
            return _cache[text]
    return None


def _cache_put(text, audio_base64):
    with _cache_lock:
        _cache[text] = audio_base64
        _cache.move_to_end(text)
        while len(_cache) > _CACHE_MAX_SIZE:
            _cache.popitem(last=False)  # 淘汰最久沒用到的那筆


@tts_bp.route('/synthesize', methods=['POST'])
def synthesize():
    """
    接收文字，合成日語語音並回傳 base64 編碼的 MP3。
    相同文字會直接使用快取，不重複合成。
    """
    data = request.get_json(silent=True) or request.form
    text = (data.get('text') or '').strip()

    if not text:
        return jsonify({'error': '請提供要合成的文字 (text)'}), 400

    # 1. 先查快取
    cached = _cache_get(text)
    if cached is not None:
        return jsonify({
            'audio_base64': cached,
            'format': 'mp3',
            'cached': True,
        }), 200

    # 2. 快取沒有才真的合成
    try:
        tts = gTTS(text=text, lang='ja')

        mp3_fp = io.BytesIO()
        tts.write_to_fp(mp3_fp)
        mp3_fp.seek(0)
        audio_base64 = base64.b64encode(mp3_fp.read()).decode('utf-8')

        _cache_put(text, audio_base64)

        return jsonify({
            'audio_base64': audio_base64,
            'format': 'mp3',
            'cached': False,
        }), 200

    except Exception as e:
        print(f"🚨 gTTS 語音合成錯誤：{e}")
        return jsonify({'error': '語音合成失敗，請確認網路連線後再試一次。'}), 502
