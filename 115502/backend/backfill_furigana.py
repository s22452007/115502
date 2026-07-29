# -*- coding: utf-8 -*-
"""
一次性維護腳本：為「舊例句」補上漢字標音（Furigana）。

背景：
  前端 FuriganaText 元件會把 `[漢字|假名]` 語法渲染成漢字上方的小字標音。
  新辨識的例句已由 Gemini 直接產生標音格式，但更早以前存入的例句是純文字，
  沒有標音資料可渲染。本腳本用 Gemini 為既有例句補上標音。

處理對象：
  1. vocab 的 4 個分級例句欄位（sentence_basic / inter / upper_inter / advanced）
  2. user_photo_vocab.context_sentence 的日文行（第一行；中文翻譯行不動）

特性：
  - 只處理「沒有標音」的例句（idempotent，可重複執行）
  - 批次處理，一次 Gemini 呼叫處理多句，節省 API 次數
  - 每批完成就 commit，中途失敗已完成的批次不會白做
  - 安全檢查：標音後「去掉標音的純文字」必須與原句一致，
    不一致就捨棄該句（避免 Gemini 順手改寫句子內容）

用法：
  cd backend
  python backfill_furigana.py
"""
import os
import re
import json
import sys
import time

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, BASE_DIR)

from google import genai  # noqa: E402
from app import app  # noqa: E402
from utils.db import db  # noqa: E402
from models import Vocab, UserPhotoVocab  # noqa: E402
from utils.ai_helper import parse_gemini_json, JSON_CONFIG  # noqa: E402

BATCH_SIZE = 12  # 一次 Gemini 呼叫處理幾個句子

SENTENCE_FIELDS = [
    'sentence_basic',
    'sentence_inter',
    'sentence_upper_inter',
    'sentence_advanced',
]

# 判斷是否已有 [漢字|假名] 標音
HAS_FURIGANA = re.compile(r'\[[^|\]]+\|[^\]]+\]')
# 是否含有漢字（沒有漢字的句子不需要標音）
HAS_KANJI = re.compile(r'[一-龯㐀-䶿々]')


def strip_furigana(text):
    """把 [漢字|假名] 還原成純漢字，用於比對句子內容有沒有被改寫"""
    return HAS_FURIGANA.sub(lambda m: m.group(0)[1:-1].split('|')[0], text)


def needs_furigana(text):
    if not text or not text.strip():
        return False
    if HAS_FURIGANA.search(text):
        return False  # 已經有標音
    return bool(HAS_KANJI.search(text))  # 有漢字才需要標音


def annotate_batch(client, sentences):
    """
    sentences: [{'key': 任意識別字串, 'text': 日文句子}, ...]
    回傳 {key: 標好音的句子}
    """
    prompt = f'''
請為以下日文句子的「漢字」加上假名標音。

規則（非常重要）：
1. 標音格式固定為 [漢字|假名]，例如：私 → [私|わたし]
2. 只加標音，「絕對不可以」修改、增刪句子的任何文字或標點
3. 假名（平假名、片假名）本身不需要標音
4. 一個詞彙的漢字連在一起時整組標音，例如 [散歩|さんぽ]、[公園|こうえん]
5. 送假名不要包進去，例如「好きです」要寫成 [好|す]きです

輸入 JSON：
{json.dumps(sentences, ensure_ascii=False, indent=2)}

請「嚴格」以下列 JSON 陣列格式回傳，不可加上 json 或 markdown 標籤：
[
  {{"key": "識別字串", "annotated": "標好音的句子"}}
]
'''
    # 遇到暫時性錯誤（503 過載 / 429 節流）自動重試，間隔漸增
    last_err = None
    for attempt in range(4):
        try:
            response = client.models.generate_content(
                model='gemini-2.5-flash',
                contents=prompt,
                config=JSON_CONFIG,
            )
            results = parse_gemini_json(response.text)
            return {
                item.get('key'): item.get('annotated', '')
                for item in results if isinstance(item, dict)
            }
        except Exception as e:
            last_err = e
            msg = str(e)
            if '429' in msg or 'RESOURCE_EXHAUSTED' in msg:
                # 免費層有每分鐘請求上限，等超過一分鐘讓額度回復
                wait = 65 * (attempt + 1)
                print(f"   ⏳ 已達速率上限，{wait} 秒後重試（第 {attempt + 1} 次）...")
                time.sleep(wait)
                continue
            if '503' in msg or 'UNAVAILABLE' in msg:
                wait = 10 * (attempt + 1)
                print(f"   ⏳ Gemini 忙碌中，{wait} 秒後重試（第 {attempt + 1} 次）...")
                time.sleep(wait)
                continue
            raise
    raise last_err


def main():
    api_key = os.environ.get("GEMINI_API_KEY_camara") or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ 找不到 GEMINI_API_KEY，請確認 backend/.env")
        return

    client = genai.Client(api_key=api_key)

    with app.app_context():
        # ── 收集所有需要標音的句子 ──
        jobs = []  # (key, text, 套用函式)

        for v in Vocab.query.order_by(Vocab.id).all():
            for field in SENTENCE_FIELDS:
                text = getattr(v, field)
                if needs_furigana(text):
                    jobs.append({'key': f'v{v.id}:{field}', 'text': text})

        for pv in UserPhotoVocab.query.order_by(UserPhotoVocab.id).all():
            cs = pv.context_sentence
            if not cs:
                continue
            jp_line = cs.split('\n')[0]  # 只處理日文行
            if needs_furigana(jp_line):
                jobs.append({'key': f'p{pv.id}:context', 'text': jp_line})

        total = len(jobs)
        print(f"共 {total} 個句子需要補標音"
              f"（分 {(total + BATCH_SIZE - 1) // BATCH_SIZE} 批，每批 {BATCH_SIZE} 句）")
        if total == 0:
            print("🎉 沒有需要補的句子，全部都有標音了！")
            return

        applied = 0
        skipped = 0
        for i in range(0, total, BATCH_SIZE):
            batch = jobs[i:i + BATCH_SIZE]
            batch_no = i // BATCH_SIZE + 1
            try:
                annotated_map = annotate_batch(client, batch)
            except Exception as e:
                print(f"❌ 第 {batch_no} 批失敗：{str(e)[:200]}")
                print(f"   已完成的 {applied} 句都已存檔，修復後重跑本腳本即可繼續。")
                return

            for job in batch:
                key = job['key']
                original = job['text']
                annotated = (annotated_map.get(key) or '').strip()

                # 安全檢查：去掉標音後必須與原句完全一致
                if not annotated or strip_furigana(annotated) != original:
                    skipped += 1
                    continue

                prefix, field = key.split(':', 1)
                obj_id = int(prefix[1:])
                if prefix.startswith('v'):
                    v = db.session.get(Vocab, obj_id)
                    if v:
                        setattr(v, field, annotated)
                        applied += 1
                else:
                    pv = db.session.get(UserPhotoVocab, obj_id)
                    if pv and pv.context_sentence:
                        lines = pv.context_sentence.split('\n')
                        lines[0] = annotated  # 只換日文行，翻譯行保留
                        pv.context_sentence = '\n'.join(lines)
                        applied += 1

            db.session.commit()
            print(f"✅ 第 {batch_no} 批完成（進度 {min(i + BATCH_SIZE, total)}/{total}）")

            # 主動放慢節奏，避免觸發免費層的每分鐘請求上限
            if i + BATCH_SIZE < total:
                time.sleep(8)

        print("")
        print("========== 標音補齊完成 ==========")
        print(f"成功補上標音：{applied} 句")
        if skipped:
            print(f"安全檢查未通過而跳過：{skipped} 句（句子內容被更動，已保留原文）")


if __name__ == '__main__':
    main()
