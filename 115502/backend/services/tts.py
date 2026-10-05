# -*- coding: utf-8 -*-
"""
日語語音合成 API。

  - 標準語：使用 gTTS（免費且不需 API 金鑰），回傳 MP3。
  - 指定腔調（dialect_id）或男聲（voice=male）：使用 Gemini 語音模型，
    依腔調的語調與重音朗讀，回傳 WAV。（gTTS 只有一種女聲，也不會腔調）
    Gemini 語音額度用完或失敗時，自動退回 gTTS 標準語音（回應的 dialect_voice 會是 False）。

加了記憶體快取：同一句話只會真的合成一次，之後直接回傳快取結果。
使用者常常會重複點同一句練習發音，快取可以省下每次 1~2 秒的合成與網路時間，
腔調語音的免費額度很少，快取也能省額度。
"""
from flask import Blueprint, request, jsonify
import io
import re
import wave
import base64
import threading
from collections import OrderedDict
from gtts import gTTS
from google.genai import types
from utils import gemini_client

# 建立 Blueprint
tts_bp = Blueprint('tts', __name__)

# ==========================================
# 語音快取（LRU：最久沒用到的先被淘汰）
# ==========================================
# 一句日語的 MP3 約 20~40KB，腔調語音是 WAV（約 200~400KB），
# 所以用「總大小」而不是筆數當上限，避免腔調語音把記憶體吃光。
_CACHE_MAX_BYTES = 24 * 1024 * 1024
_cache = OrderedDict()          # {(腔調 ID, 文字): (base64 音訊, 格式)}
_cache_bytes = 0
_cache_lock = threading.Lock()  # Flask 可能多執行緒同時處理請求，加鎖保護


def _cache_get(key):
    with _cache_lock:
        if key in _cache:
            _cache.move_to_end(key)  # 標記為最近使用
            return _cache[key]
    return None


def _cache_put(key, audio_base64, audio_format):
    global _cache_bytes
    with _cache_lock:
        if key in _cache:
            _cache_bytes -= len(_cache[key][0])
        _cache[key] = (audio_base64, audio_format)
        _cache.move_to_end(key)
        _cache_bytes += len(audio_base64)
        while _cache_bytes > _CACHE_MAX_BYTES and len(_cache) > 1:
            _, (old_audio, _) = _cache.popitem(last=False)  # 淘汰最久沒用到的那筆
            _cache_bytes -= len(old_audio)


# ==========================================
# 腔調語音（Gemini 語音模型）
# ==========================================
# 免費層額度是「每個模型」各自計算，前面的額度用完或無法使用就換下一個。
DIALECT_TTS_MODELS = ['gemini-3.8-flash-tts', 'gemini-3.8-flash-lite-tts',
                      'gemini-3.1-flash-tts-preview', 'gemini-2.5-flash-preview-tts']
# 聲音性別對應的 Gemini 預設聲線
VOICE_NAMES = {'female': 'Leda', 'male': 'Charon'}
# 每種腔調的男女聲各用不同的聲線，聽起來像不同的人（沒列到的用上面的預設）
DIALECT_VOICES = {
    '関西弁': {'female': 'Aoede', 'male': 'Puck'},
    '博多弁': {'female': 'Leda', 'male': 'Achird'},
    '東北弁': {'female': 'Sulafat', 'male': 'Umbriel'},
    '沖縄弁': {'female': 'Callirrhoe', 'male': 'Zubenelgenubi'},
}


def _voice_name(jp_name, voice):
    voice = voice if voice in VOICE_NAMES else 'female'
    return DIALECT_VOICES.get(jp_name, {}).get(voice, VOICE_NAMES[voice])


STANDARD_JP_NAME = '標準語'


def _to_wav(data, mime_type):
    """Gemini 多半回傳沒有檔頭的 PCM（audio/L16），要補上 WAV 檔頭 App 才能播放"""
    mime = (mime_type or '').lower()
    if 'wav' in mime or data[:4] == b'RIFF':
        return data
    match = re.search(r'rate=(\d+)', mime)
    rate = int(match.group(1)) if match else 24000
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)
    return buf.getvalue()


def synthesize_with_gemini(text, jp_name, voice='female'):
    """用 Gemini 語音模型以指定腔調（jp_name，例如「関西弁」）與性別朗讀，
    回傳 WAV bytes；全部模型都失敗則回傳 None"""
    # 一定要用這種分段格式：指示直接寫成一句話接在文字前面時，模型有時會把指示本身也唸出來
    jp = jp_name
    prompt = (f"# AUDIO PROFILE\n{jp}のネイティブ話者\n\n"
              f"### DIRECTOR'S NOTES\n"
              f"話者は{jp}のネイティブ。{jp}本来のイントネーションとアクセントで、自然な会話の速さで話す。"
              f"この指示やメモは読み上げず、TRANSCRIPT の文だけを一字一句そのまま読む。\n\n"
              f"#### TRANSCRIPT\n{text}")
    # 正常語速約每字 0.15~0.25 秒；長度遠超過就當作唸了多餘的內容，換下一個模型
    max_seconds = 3 + 0.45 * len(text)
    config = types.GenerateContentConfig(
        response_modalities=['AUDIO'],
        speech_config=types.SpeechConfig(voice_config=types.VoiceConfig(
            prebuilt_voice_config=types.PrebuiltVoiceConfig(
                voice_name=_voice_name(jp_name, voice)))),
    )
    for model in DIALECT_TTS_MODELS:
        try:
            response = gemini_client.generate_content('tts', prompt, config=config, model=model)
            part = response.candidates[0].content.parts[0].inline_data
            wav_bytes = _to_wav(part.data, part.mime_type)
            with wave.open(io.BytesIO(wav_bytes)) as w:
                seconds = w.getnframes() / w.getframerate()
            if seconds > max_seconds:
                print(f'⚠️ [tts] {model} 的語音長度異常（{seconds:.1f} 秒），改試下一個模型')
                continue
            return wav_bytes
        except gemini_client.GeminiNotConfigured as e:
            print(f'⚠️ {e}')
            return None
        except Exception as e:
            print(f'⚠️ [tts] {model} 腔調語音合成失敗，改試下一個模型：{str(e)[:200]}')
    return None


def _get_dialect(dialect_id):
    """取得要用腔調語音的腔調；沒指定、查不到或是標準語都回傳 None（走 gTTS）"""
    try:
        dialect_id = int(dialect_id)
    except (TypeError, ValueError):
        return None
    from models import Dialect
    dialect = Dialect.query.filter_by(id=dialect_id, is_active=True).first()
    if dialect is None or dialect.jp_name == STANDARD_JP_NAME:
        return None
    return dialect


@tts_bp.route('/synthesize', methods=['POST'])
def synthesize():
    """
    接收文字，合成日語語音並回傳 base64 編碼的音訊（format 為 mp3 或 wav）。
    帶 dialect_id 時會用該腔調的語調朗讀，voice 可指定 female（預設）或 male。
    相同文字會直接使用快取，不重複合成。
    """
    data = request.get_json(silent=True) or request.form
    text = (data.get('text') or '').strip()

    if not text:
        return jsonify({'error': '請提供要合成的文字 (text)'}), 400

    dialect = _get_dialect(data.get('dialect_id'))
    voice = 'male' if data.get('voice') == 'male' else 'female'
    # 標準語女聲走 gTTS，其他組合（腔調或男聲）才需要 Gemini 語音模型
    use_gemini = dialect is not None or voice == 'male'
    cache_key = (dialect.id if dialect else None, voice, text)

    # 1. 先查快取
    cached = _cache_get(cache_key)
    if cached is not None:
        return jsonify({
            'audio_base64': cached[0],
            'format': cached[1],
            'cached': True,
            'dialect_voice': cached[1] == 'wav',
        }), 200

    # 2. 腔調或男聲 → 先試 Gemini 語音，失敗才退回下面的標準語音
    if use_gemini:
        jp_name = dialect.jp_name if dialect else STANDARD_JP_NAME
        wav_bytes = synthesize_with_gemini(text, jp_name, voice)
        if wav_bytes:
            audio_base64 = base64.b64encode(wav_bytes).decode('utf-8')
            _cache_put(cache_key, audio_base64, 'wav')
            return jsonify({
                'audio_base64': audio_base64,
                'format': 'wav',
                'cached': False,
                'dialect_voice': True,
            }), 200
        print(f'⚠️ [tts] 「{jp_name}／{voice}」語音無法使用，退回標準語音')

    # 3. 標準語音（退回時只寫進標準語女聲的快取，額度恢復後才能重新合成腔調語音）
    try:
        tts = gTTS(text=text, lang='ja')

        mp3_fp = io.BytesIO()
        tts.write_to_fp(mp3_fp)
        mp3_fp.seek(0)
        audio_base64 = base64.b64encode(mp3_fp.read()).decode('utf-8')

        _cache_put((None, 'female', text), audio_base64, 'mp3')

        return jsonify({
            'audio_base64': audio_base64,
            'format': 'mp3',
            'cached': False,
            'dialect_voice': False,
        }), 200

    except Exception as e:
        print(f"🚨 gTTS 語音合成錯誤：{e}")
        return jsonify({'error': '語音合成失敗，請確認網路連線後再試一次。'}), 502
