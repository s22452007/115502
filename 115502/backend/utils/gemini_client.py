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
import google.generativeai as genai

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(_BASE_DIR, '.env'), override=True)

# 使用 latest 別名，會自動指向最新的 flash 模型。
# 原因：Google 會停止讓新申請的金鑰存取舊型號（例如 gemini-2.5-flash
# 對新使用者會回 404），寫死版本號會在換金鑰時突然壞掉。
DEFAULT_MODEL = 'gemini-flash-latest'

# 伺服器忙碌（503）時的自動重試設定。
# 使用者正在等回覆，所以間隔要短，總等待時間控制在 6 秒內。
OVERLOAD_RETRIES = 3
OVERLOAD_BACKOFF = [1, 2, 3]  # 每次重試前等待的秒數

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


def get_keys(feature):
    """取得該功能所有可用金鑰（依優先順序，已去除重複與空值）"""
    keys = []
    for env_name in FEATURE_KEY_ENVS.get(feature, []):
        value = (os.environ.get(env_name) or '').strip()
        if value and value not in keys and not value.startswith('在這裡'):
            keys.append(value)
    return keys


def generate_content(feature, contents, config=None, model=DEFAULT_MODEL):
    """
    以指定功能的金鑰呼叫 Gemini。
    主金鑰額度用完時自動改用備用金鑰；全部用完則丟出 GeminiQuotaExhausted。
    其他錯誤（例如格式問題、網路問題）原樣丟出，由呼叫端處理。
    """
    keys = get_keys(feature)
    if not keys:
        raise GeminiNotConfigured(feature)

    last_quota_error = None
    for index, key in enumerate(keys):
        try:
            client = genai.Client(api_key=key)
            kwargs = {'model': model, 'contents': contents}
            if config is not None:
                kwargs['config'] = config

            # 503（伺服器忙碌）是暫時性的，重試通常就會成功，
            # 因此同一把金鑰先重試幾次再說（換金鑰對 503 沒有幫助）。
            for attempt in range(OVERLOAD_RETRIES + 1):
                try:
                    return client.models.generate_content(**kwargs)
                except Exception as inner:
                    if is_overloaded_error(inner) and attempt < OVERLOAD_RETRIES:
                        wait = OVERLOAD_BACKOFF[attempt]
                        print(f'⏳ [{feature}] Gemini 忙碌中，{wait} 秒後重試'
                              f'（第 {attempt + 1}/{OVERLOAD_RETRIES} 次）...')
                        time.sleep(wait)
                        continue
                    raise

        except Exception as e:
            if is_quota_error(e):
                last_quota_error = e
                remaining = len(keys) - index - 1
                if remaining > 0:
                    print(f'⚠️ [{feature}] 第 {index + 1} 把金鑰額度已滿，改用備用金鑰...')
                    continue
                break
            raise  # 非額度問題，直接往上拋

    print(f'🚨 [{feature}] 所有金鑰額度都已用完：{last_quota_error}')
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
