from flask import Blueprint, request, jsonify
import io
import base64
from gtts import gTTS

# 建立 Blueprint
tts_bp = Blueprint('tts', __name__)


@tts_bp.route('/synthesize', methods=['POST'])
def synthesize():
    """
    接收文字，使用 gTTS（Google Translate 免費 TTS，不需 API Key）合成日文語音。
    回傳 base64 編碼的 MP3 音訊。
    """
    data = request.get_json(silent=True) or request.form
    text = (data.get('text') or '').strip()

    if not text:
        return jsonify({'error': '請提供要合成的文字 (text)'}), 400

    try:
        # 用 gTTS 生成日語語音
        tts = gTTS(text=text, lang='ja')

        # 寫入記憶體並轉成 base64
        mp3_fp = io.BytesIO()
        tts.write_to_fp(mp3_fp)
        mp3_fp.seek(0)
        audio_base64 = base64.b64encode(mp3_fp.read()).decode('utf-8')

        return jsonify({
            'audio_base64': audio_base64,
            'format': 'mp3',
        }), 200

    except Exception as e:
        print(f"🚨 gTTS 語音合成錯誤：{e}")
        return jsonify({'error': f'TTS 語音合成失敗: {str(e)}'}), 502
