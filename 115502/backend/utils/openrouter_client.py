# -*- coding: utf-8 -*-
"""
OpenRouter 呼叫封裝（OpenAI 相容的 Chat Completions API）。

由 gemini_client.generate_content() 統一呼叫，呼叫端不用改：
  - AI_PROVIDER=gemini（預設）：先用 Gemini，額度用完／塞車／出錯時改走 OpenRouter
  - AI_PROVIDER=openrouter：先用 OpenRouter，失敗時再退回 Gemini
沒設定 OPENROUTER_API_KEY 時完全不會用到這個檔案。

.env 設定方式：
    OPENROUTER_API_KEY=sk-or-v1-xxx
    OPENROUTER_MODEL=google/gemini-3-flash-preview    # 預設模型（實測拍照約 8 秒）
    OPENROUTER_FALLBACK_MODELS=openai/gpt-4o-mini     # 選填，逗號分隔，前面的模型失敗時 OpenRouter 自動接手
    OPENROUTER_MODEL_CAMERA=...                       # 選填，個別功能指定模型（CAMERA/TUTOR/CONTEXT/ARTICLE）

支援：文字、圖片（拍照辨識）、音檔輸入（文章語音評分）、JSON 輸出。
不支援：語音輸出（腔調語音），這類請求仍只走 Gemini，失敗會照舊退回 gTTS。
"""
import base64
import os

import requests
from dotenv import load_dotenv

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(_BASE_DIR, '.env'), override=True)

API_URL = 'https://openrouter.ai/api/v1/chat/completions'
DEFAULT_MODEL = 'google/gemini-3-flash-preview'
# 拍照、文章評分要等模型看完圖片／聽完錄音，給長一點
TIMEOUT_SECONDS = 60

# OpenRouter 的 input_audio 用副檔名式的格式名稱
_AUDIO_FORMATS = {
    'audio/wav': 'wav', 'audio/x-wav': 'wav', 'audio/wave': 'wav',
    'audio/mpeg': 'mp3', 'audio/mp3': 'mp3',
    'audio/aac': 'aac', 'audio/mp4': 'm4a', 'audio/x-m4a': 'm4a', 'audio/m4a': 'm4a',
    'audio/ogg': 'ogg', 'audio/flac': 'flac', 'audio/webm': 'webm', 'audio/aiff': 'aiff',
}


class OpenRouterError(Exception):
    """OpenRouter 回傳錯誤。訊息格式刻意讓 gemini_client 的 is_quota_error / is_overloaded_error 判斷得出來"""

    def __init__(self, status, message):
        self.status = status
        if status in (502, 503, 504) or status is None:
            # 上游模型塞車或連線逾時：統一標成 503，前端會顯示「使用人數較多」
            text = f'OpenRouter 503 UNAVAILABLE ({status}): {message}'
        elif status == 402:
            text = f'OpenRouter 429 credits are depleted: {message}'
        else:
            text = f'OpenRouter {status}: {message}'
        super().__init__(text)


class OpenRouterResponse:
    """只提供呼叫端會用到的 .text，介面與 Gemini 回應一致"""

    def __init__(self, text, model):
        self.text = text
        self.model = model


def get_key():
    value = (os.environ.get('OPENROUTER_API_KEY') or '').strip()
    return '' if value.startswith('<') or value.startswith('在這裡') else value


def is_configured():
    return bool(get_key())


def is_primary():
    return (os.environ.get('AI_PROVIDER') or 'gemini').strip().lower() == 'openrouter'


def supports(config):
    """語音輸出（腔調語音）OpenRouter 做不到，交給 Gemini"""
    modalities = getattr(config, 'response_modalities', None) if config is not None else None
    return not modalities or all(str(m).upper().endswith('TEXT') for m in modalities)


def _models_for(feature):
    primary = (os.environ.get(f'OPENROUTER_MODEL_{feature.upper()}')
               or os.environ.get('OPENROUTER_MODEL') or DEFAULT_MODEL).strip()
    fallbacks = [m.strip() for m in (os.environ.get('OPENROUTER_FALLBACK_MODELS') or '').split(',') if m.strip()]
    return [primary] + [m for m in fallbacks if m != primary]


def _to_content_part(item):
    """把 Gemini 的 contents 元素（字串或 types.Part）轉成 OpenAI 格式的 content part"""
    if isinstance(item, str):
        return {'type': 'text', 'text': item}

    text = getattr(item, 'text', None)
    if text:
        return {'type': 'text', 'text': text}

    blob = getattr(item, 'inline_data', None)
    if blob is not None and blob.data:
        mime = (blob.mime_type or '').lower()
        b64 = base64.b64encode(blob.data).decode('ascii')
        if mime.startswith('image/'):
            return {'type': 'image_url', 'image_url': {'url': f'data:{mime};base64,{b64}'}}
        if mime.startswith('audio/'):
            fmt = _AUDIO_FORMATS.get(mime.split(';')[0], mime.split('/')[-1].split(';')[0])
            return {'type': 'input_audio', 'input_audio': {'data': b64, 'format': fmt}}
        raise OpenRouterError(400, f'不支援的附件格式 {mime}')

    raise OpenRouterError(400, f'不支援的內容型別 {type(item).__name__}')


def _build_messages(contents):
    items = contents if isinstance(contents, (list, tuple)) else [contents]
    parts = [_to_content_part(i) for i in items]
    # 純文字就直接送字串，相容性最好（部分模型不吃 content 陣列）
    if len(parts) == 1 and parts[0]['type'] == 'text':
        return [{'role': 'user', 'content': parts[0]['text']}]
    return [{'role': 'user', 'content': parts}]


def generate_content(feature, contents, config=None):
    key = get_key()
    if not key:
        raise OpenRouterError(401, '尚未設定 OPENROUTER_API_KEY')

    models = _models_for(feature)
    # 一定要設上限：沒設的話 OpenRouter 會照模型最大輸出（6 萬多 token）預扣點數，餘額不夠就整個拒絕。
    # 拍照辨識（5 個單字 × 4 級例句）的 JSON 約 3000 token，8192 很夠用
    max_tokens = int(os.environ.get('OPENROUTER_MAX_TOKENS') or 8192)
    body = {'model': models[0], 'messages': _build_messages(contents), 'max_tokens': max_tokens}
    if len(models) > 1:
        body['models'] = models   # OpenRouter 內建的模型備援：前一個失敗自動換下一個
    if config is not None and getattr(config, 'response_mime_type', None) == 'application/json':
        body['response_format'] = {'type': 'json_object'}
    if config is not None and getattr(config, 'thinking_config', None) is not None:
        # 對應 Gemini 的 thinking_level=LOW；不支援推理設定的模型 OpenRouter 會自動忽略
        body['reasoning'] = {'effort': 'low', 'exclude': True}

    try:
        resp = requests.post(API_URL, json=body, timeout=TIMEOUT_SECONDS, headers={
            'Authorization': f'Bearer {key}',
            'X-Title': 'JLens',
        })
    except requests.RequestException as e:
        raise OpenRouterError(None, str(e)) from e

    try:
        data = resp.json()
    except ValueError:
        raise OpenRouterError(resp.status_code, resp.text[:200])

    # OpenRouter 有時 HTTP 200 但內容是 error（上游模型出錯）
    if resp.status_code >= 400 or 'error' in data:
        err = data.get('error') or {}
        status = err.get('code') if isinstance(err.get('code'), int) else resp.status_code
        raise OpenRouterError(status, err.get('message') or resp.text[:200])

    choices = data.get('choices') or []
    text = (choices[0].get('message') or {}).get('content') if choices else None
    if not text:
        raise OpenRouterError(503, f'{data.get("model")} 沒有回傳內容')
    print(f'🔀 [{feature}] 由 OpenRouter（{data.get("model")}）回覆')
    return OpenRouterResponse(text, data.get('model'))
