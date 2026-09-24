# -*- coding: utf-8 -*-
"""
Gemini 金鑰管理與呼叫封裝。

目的：
  1. 每個 AI 功能各自使用一把金鑰，額度互不影響
     （拍照辨識爆額度時，AI 對話仍可正常使用）
  2. 每個功能都可再設定一把備用金鑰，主金鑰額度用完會自動切換
  3. 額度真的用完時，回報統一且對使用者友善的訊息

.env 設定方式（每個功能一組，備用金鑰選填）：
    GEMINI_KEY_CAMERA=xxx           # 拍照辨識
    GEMINI_KEY_CAMERA_BACKUP=xxx
    GEMINI_KEY_TUTOR=xxx            # AI 對話
    GEMINI_KEY_TUTOR_BACKUP=xxx
    GEMINI_KEY_CONTEXT=xxx          # 情境例句
    GEMINI_KEY_CONTEXT_BACKUP=xxx
    GEMINI_KEY_ARTICLE=xxx          # 文章語音評分
    GEMINI_KEY_ARTICLE_BACKUP=xxx

備用金鑰請使用「不同 Google 帳號」申請，額度才會分開計算。
若上述變數未設定，會自動沿用舊的 GEMINI_API_KEY / GEMINI_API_KEY_camara，
因此不設定也能正常運作（相容舊設定）。
"""
import os
import time
from dotenv import load_dotenv
# ⚠️ 必須使用新版 SDK（google.genai），它才有 Client 類別。
#    不可改成 `import google.generativeai as genai`（舊版），
#    舊版沒有 Client，會在呼叫時噴 AttributeError。
from google import genai

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(_BASE_DIR, '.env'), override=True)

# 使用 latest 別名，會自動指向最新的 flash 模型。
# 原因：Google 會停止讓新申請的金鑰存取舊型號（例如 gemini-2.5-flash
# 對新使用者會回 404），寫死版本號會在換金鑰時突然壞掉。
DEFAULT_MODEL = 'gemini-flash-latest'

# 備援模型清單。
# 免費層額度是「每個專案、每個模型」各自計算的
# （quotaId 是 GenerateRequestsPerDayPerProjectPerModel-FreeTier），
# 所以主模型額度用完時，換一個模型就有全新的額度可用。
#（gemini-2.0-flash 已被 Google 下架，回 404 要求改用 3.6，故移除）
FALLBACK_MODELS = ['gemini-3.5-flash', 'gemini-3-flash-preview', 'gemini-3.6-flash',
                   # 以下同樣支援圖片，各自有獨立的免費每日額度，前面的模型額度用完或塞車時接手
                   'gemini-3.7-flash', 'gemini-3.8-flash', 'gemini-2.5-flash', 'gemini-flash-lite-latest']

# 伺服器忙碌（503）時的自動重試設定。
# 使用者正在等回覆，所以間隔要短，總等待時間控制在 6 秒內。
OVERLOAD_RETRIES = 3
OVERLOAD_BACKOFF = [1, 2, 3]  # 每次重試前等待的秒數
# 後面還有備援模型可以換時，同一個模型重試這麼多次就換下一個（0 = 直接換）
# （塞車通常是「某個模型」整個在塞，原地重試 3 次多半白等；最後一個模型才用滿 OVERLOAD_RETRIES）
OVERLOAD_RETRIES_BEFORE_FALLBACK = 0

# 模型狀態記憶（存在記憶體，後端重啟就清空）：
#   _last_good[feature]：該功能上一次成功的模型，下次優先使用
#   _busy_until[model]：模型剛回 503 的話，這段時間內排到最後面再試
BUSY_COOLDOWN_SECONDS = 120
QUOTA_COOLDOWN_SECONDS = 30 * 60   # 每日額度用完的模型，半小時內都排到最後
_last_good = {}
_busy_until = {}


def _model_order(feature):
    """決定這次嘗試模型的順序：上次成功的模型優先，剛塞車的模型排最後（仍會嘗試，不會被跳過）"""
    models = [DEFAULT_MODEL] + FALLBACK_MODELS
    good = _last_good.get(feature)
    if good in models:
        models.remove(good)
        models.insert(0, good)
    now = time.time()
    ready = [m for m in models if _busy_until.get(m, 0) <= now]
    busy = [m for m in models if _busy_until.get(m, 0) > now]
    return ready + busy

# 各功能的金鑰查找順序：專用主金鑰 → 專用備用金鑰 → 舊版共用金鑰（相容用）
FEATURE_KEY_ENVS = {
    'camera': ['GEMINI_KEY_CAMERA', 'GEMINI_KEY_CAMERA_BACKUP',
               'GEMINI_API_KEY_camara', 'GEMINI_API_KEY'],
    'tutor': ['GEMINI_KEY_TUTOR', 'GEMINI_KEY_TUTOR_BACKUP',
              'GEMINI_API_KEY', 'GEMINI_API_KEY_camara'],
    'context': ['GEMINI_KEY_CONTEXT', 'GEMINI_KEY_CONTEXT_BACKUP',
                'GEMINI_API_KEY_camara', 'GEMINI_API_KEY'],
    'article': ['GEMINI_KEY_ARTICLE', 'GEMINI_KEY_ARTICLE_BACKUP',
                'GEMINI_API_KEY', 'GEMINI_API_KEY_camara'],
}

# 功能名稱（組錯誤訊息用）
FEATURE_LABELS = {
    'camera': '拍照辨識',
    'tutor': 'AI 對話',
    'context': '情境例句',
    'article': '文章語音評分',
}


class GeminiQuotaExhausted(Exception):
    """所有可用金鑰的額度都用完（或都撞到流量限制）了"""

    def __init__(self, feature, original=None):
        self.feature = feature
        self.original = original
        super().__init__(friendly_quota_message(feature, original))


class GeminiNotConfigured(Exception):
    """該功能一把可用的金鑰都沒設定"""

    def __init__(self, feature):
        self.feature = feature
        super().__init__(f'尚未設定「{FEATURE_LABELS.get(feature, feature)}」的 API 金鑰')


def friendly_quota_message(feature, exc=None):
    """
    給使用者看的額度訊息（不含技術細節）。
    會區分「每分鐘流量限制」與「額度真的用完」，
    因為前者只要等十幾秒，後者才需要等到明天——講錯會讓使用者白等一天。
    """
    label = FEATURE_LABELS.get(feature, 'AI')

    if exc is not None and is_rate_limit_error(exc):
        seconds = extract_retry_delay(exc)
        wait_hint = f'約 {seconds} 秒' if seconds else '一下'
        return f'「{label}」請求太頻繁了，請稍等{wait_hint}再試一次！'

    return f'今日的「{label}」服務已達使用上限，請明天再試！其他功能仍可正常使用。'


def is_rate_limit_error(exc):
    """
    判斷是否為「每分鐘請求數」限制（短暫，等一下就好），
    而非每日額度耗盡（要等到隔天或加值）。

    判斷順序很重要：先看 Google 回傳的 quotaId，因為每日額度用盡時
    retryDelay 也可能只有幾十秒，單看秒數會誤判成「等一下就好」。
    """
    msg = str(exc)
    if 'PerDay' in msg:
        return False   # 每日額度用盡，等再久今天也不會恢復
    if 'PerMinute' in msg:
        return True
    # 沒有明確標示時，用 retryDelay 長度推測
    seconds = extract_retry_delay(exc)
    return seconds is not None and seconds <= 120


def extract_retry_delay(exc):
    """從錯誤訊息中取出 Google 建議的重試秒數（取不到則回傳 None）"""
    import re
    match = re.search(r"'retryDelay':\s*'(\d+)s'", str(exc))
    if match:
        return int(match.group(1))
    match = re.search(r'Please retry in ([\d.]+)s', str(exc))
    if match:
        return int(float(match.group(1))) + 1
    return None


def is_quota_error(exc):
    """判斷例外是否為額度/流量限制（429、RESOURCE_EXHAUSTED、額度耗盡）"""
    msg = str(exc)
    return ('429' in msg
            or 'RESOURCE_EXHAUSTED' in msg
            or 'quota' in msg.lower()
            or 'credits are depleted' in msg.lower())


def is_overloaded_error(exc):
    """判斷例外是否為伺服器暫時忙碌（503），這種情況換金鑰沒用"""
    msg = str(exc)
    return '503' in msg or 'UNAVAILABLE' in msg or 'overloaded' in msg.lower()


def _is_thinking_unsupported(exc):
    """模型不接受 thinking 設定（例如舊型號不認得 thinking_level）時，Google 會回 400"""
    msg = str(exc)
    return ('400' in msg or 'INVALID_ARGUMENT' in msg) and 'thinking' in msg.lower()


def _call_model(client, kwargs, feature):
    """呼叫一次模型；帶了 thinking 設定但該模型不支援時，拿掉設定原地重送一次"""
    try:
        return client.models.generate_content(**kwargs)
    except Exception as e:
        cfg = kwargs.get('config')
        if cfg is not None and getattr(cfg, 'thinking_config', None) is not None and _is_thinking_unsupported(e):
            print(f'⚠️ [{feature}] {kwargs["model"]} 不支援思考程度設定，改用預設設定重送...')
            kwargs['config'] = cfg.model_copy(update={'thinking_config': None})
            return client.models.generate_content(**kwargs)
        raise


def get_keys(feature):
    """取得該功能所有可用金鑰（依優先順序，已去除重複與空值）"""
    keys = []
    for env_name in FEATURE_KEY_ENVS.get(feature, []):
        value = (os.environ.get(env_name) or '').strip()
        if value and value not in keys and not value.startswith('在這裡'):
            keys.append(value)
    return keys


def generate_content(feature, contents, config=None, model=None):
    """
    以指定功能的金鑰呼叫 Gemini。

    額度用完時的切換順序：
      1. 同一個模型，換下一把金鑰（不同帳號的金鑰有各自的額度）
      2. 所有金鑰都滿了，換下一個模型重來
         （免費層額度是「每專案每模型」分開算，換模型等同拿到新額度）
    全部用完才丟出 GeminiQuotaExhausted。
    其他錯誤（例如格式問題、網路問題）原樣丟出，由呼叫端處理。
    """
    keys = get_keys(feature)
    if not keys:
        raise GeminiNotConfigured(feature)

    # 呼叫端有指定模型就只用它，否則依「上次成功優先、剛塞車排後」的順序嘗試主模型與備援模型
    models_to_try = [model] if model else _model_order(feature)

    last_quota_error = None
    last_overloaded_error = None
    for model_index, current_model in enumerate(models_to_try):
        has_next_model = model_index + 1 < len(models_to_try)
        retries = OVERLOAD_RETRIES_BEFORE_FALLBACK if has_next_model else OVERLOAD_RETRIES
        for index, key in enumerate(keys):
            try:
                client = genai.Client(api_key=key)
                kwargs = {'model': current_model, 'contents': contents}
                if config is not None:
                    kwargs['config'] = config

                # 503（伺服器忙碌）是暫時性的，重試有機會成功，
                # 因此同一把金鑰先重試再說（換金鑰對 503 沒有幫助）。
                for attempt in range(retries + 1):
                    try:
                        response = _call_model(client, kwargs, feature)
                        _last_good[feature] = current_model
                        _busy_until.pop(current_model, None)
                        return response
                    except Exception as inner:
                        if is_overloaded_error(inner) and attempt < retries:
                            wait = OVERLOAD_BACKOFF[attempt]
                            print(f'⏳ [{feature}] {current_model} 忙碌中，{wait} 秒後重試'
                                  f'（第 {attempt + 1}/{retries} 次）...')
                            time.sleep(wait)
                            continue
                        raise

            except Exception as e:
                # 模型不存在或無權使用 → 這個模型跳過，換下一個
                if '404' in str(e) or 'NOT_FOUND' in str(e):
                    print(f'⚠️ [{feature}] 模型 {current_model} 無法使用，改試下一個模型...')
                    break
                # 上面已經對同一個模型重試過仍是 503 → 換模型（塞車是「每個模型」各自的狀況，
                # 常見情形是預設模型爆量、備援模型還很空，尤其圖片請求）
                if is_overloaded_error(e):
                    _busy_until[current_model] = time.time() + BUSY_COOLDOWN_SECONDS
                    last_overloaded_error = e
                    if model_index + 1 < len(models_to_try):
                        print(f'⚠️ [{feature}] {current_model} 忙碌中，'
                              f'改用備援模型 {models_to_try[model_index + 1]}...')
                        break
                    raise  # 連最後一個備援模型都塞車，才回報「使用人數較多」
                if is_quota_error(e):
                    last_quota_error = e
                    if index + 1 < len(keys):
                        print(f'⚠️ [{feature}] 第 {index + 1} 把金鑰額度已滿，改用備用金鑰...')
                        continue
                    # 這個模型的所有金鑰都滿了 → 排到後面、換模型
                    #（每分鐘流量限制等一下就好；每日額度用完則半小時內都先別試它）
                    cooldown = BUSY_COOLDOWN_SECONDS if is_rate_limit_error(e) else QUOTA_COOLDOWN_SECONDS
                    _busy_until[current_model] = time.time() + cooldown
                    if model_index + 1 < len(models_to_try):
                        print(f'⚠️ [{feature}] {current_model} 額度已滿，'
                              f'改用備援模型 {models_to_try[model_index + 1]}...')
                    break
                raise  # 非額度問題，直接往上拋

    # 有模型只是暫時塞車（等一下就能用）時，回報「使用人數較多」，
    # 不要因為最後試到的模型剛好額度用完，就叫使用者「明天再試」
    if last_overloaded_error is not None:
        print(f'🚨 [{feature}] 可用的模型都在塞車或額度已滿')
        raise last_overloaded_error
    print(f'🚨 [{feature}] 所有金鑰與備援模型的額度都已用完：{last_quota_error}')
    raise GeminiQuotaExhausted(feature, last_quota_error)


def run_with_legacy_keys(feature, task):
    """
    給仍使用舊版 google.generativeai SDK 的功能使用（例如文章語音評分需要上傳音檔）。

    會依序用該功能的每一把金鑰呼叫 genai.configure() 後執行 task()，
    遇到額度問題自動換下一把；全部用完則丟出 GeminiQuotaExhausted。

    參數:
        task: 一個無參數的函式，內容為實際的 Gemini 操作
    """
    import google.generativeai as legacy_genai

    keys = get_keys(feature)
    if not keys:
        raise GeminiNotConfigured(feature)

    last_quota_error = None
    for index, key in enumerate(keys):
        try:
            legacy_genai.configure(api_key=key)
            return task()
        except Exception as e:
            if is_quota_error(e):
                last_quota_error = e
                if len(keys) - index - 1 > 0:
                    print(f'⚠️ [{feature}] 第 {index + 1} 把金鑰額度已滿，改用備用金鑰...')
                    continue
                break
            raise

    print(f'🚨 [{feature}] 所有金鑰額度都已用完：{last_quota_error}')
    raise GeminiQuotaExhausted(feature, last_quota_error)
