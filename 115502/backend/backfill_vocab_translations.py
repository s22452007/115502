# -*- coding: utf-8 -*-
"""
一次性維護腳本：為「舊單字」補齊分級例句的中文翻譯。

背景：
  2026-07-18 之後辨識的新單字，翻譯會在辨識當下一併生成；
  在那之前的舊單字只有日文例句，sentence_*_zh 欄位是空的。
  本腳本用 Gemini 把既有日文例句翻成繁體中文補進去。

特性：
  - 只處理「有日文例句但缺翻譯」的單字（idempotent，可重複執行）
  - 批次處理：一次 Gemini 呼叫翻 8 個單字，節省 API 次數
  - 每批完成就 commit，中途失敗（如額度不足）已完成的批次不會白做
  - 執行前不需要備份（只「填入」原本為空的欄位，不動任何既有資料）

用法：
  cd backend
  python backfill_vocab_translations.py
"""
import os
import json
import sys
from dotenv import load_dotenv

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(BASE_DIR, '.env'), override=True)

from google import genai  # noqa: E402

sys.path.insert(0, BASE_DIR)
from app import app  # noqa: E402
from utils.db import db  # noqa: E402
from models import Vocab  # noqa: E402

BATCH_SIZE = 8  # 一次 Gemini 呼叫處理幾個單字

# 欄位對應：(日文例句欄位, 翻譯欄位, JSON key)
FIELD_MAP = [
    ('sentence_basic',       'sentence_basic_zh',       'basic_zh'),
    ('sentence_inter',       'sentence_inter_zh',       'inter_zh'),
    ('sentence_upper_inter', 'sentence_upper_inter_zh', 'upper_zh'),
    ('sentence_advanced',    'sentence_advanced_zh',    'adv_zh'),
]


def needs_backfill(v):
    """有日文例句、但對應翻譯是空的 → 需要補"""
    for jp_field, zh_field, _ in FIELD_MAP:
        jp = getattr(v, jp_field)
        zh = getattr(v, zh_field)
        if jp and jp.strip() and not (zh and zh.strip()):
            return True
    return False


def build_prompt(batch):
    """組出一批單字的翻譯 prompt，要求嚴格 JSON 回傳"""
    items = []
    for v in batch:
        entry = {'id': v.id, 'word': v.word}
        for jp_field, zh_field, key in FIELD_MAP:
            jp = getattr(v, jp_field)
            zh = getattr(v, zh_field)
            if jp and jp.strip() and not (zh and zh.strip()):
                entry[key.replace('_zh', '_jp')] = jp
        items.append(entry)

    return f'''
請將以下日文例句翻譯成自然通順的繁體中文。
輸入是一個 JSON 陣列，每個項目有 id、word（該例句的關鍵單字），
以及若干日文例句欄位（basic_jp / inter_jp / upper_jp / adv_jp，有的項目可能缺某些欄位）。

請對每個「有提供」的日文欄位，輸出對應的翻譯欄位（basic_zh / inter_zh / upper_zh / adv_zh）。
沒提供的欄位不要輸出。

輸入：
{json.dumps(items, ensure_ascii=False, indent=2)}

請「嚴格」以下列 JSON 陣列格式回傳，不可加上 json 或 markdown 標籤：
[
  {{"id": 1, "basic_zh": "翻譯1", "inter_zh": "翻譯2"}},
  {{"id": 2, "basic_zh": "翻譯3"}}
]
'''


def clean_json(text):
    text = text.strip()
    if text.startswith("```json"):
        text = text.replace("```json", "", 1)
    if text.startswith("```"):
        text = text.replace("```", "", 1)
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def main():
    api_key = os.environ.get("GEMINI_API_KEY_camara") or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ 找不到 GEMINI_API_KEY，請確認 backend/.env")
        return

    client = genai.Client(api_key=api_key)

    with app.app_context():
        targets = [v for v in Vocab.query.order_by(Vocab.id).all() if needs_backfill(v)]
        total = len(targets)
        print(f"共 {total} 個單字需要補翻譯（分 {(total + BATCH_SIZE - 1) // BATCH_SIZE} 批，每批 {BATCH_SIZE} 個）")
        if total == 0:
            print("🎉 沒有需要補的單字，全部都有翻譯了！")
            return

        done = 0
        filled_fields = 0
        for i in range(0, total, BATCH_SIZE):
            batch = targets[i:i + BATCH_SIZE]
            batch_no = i // BATCH_SIZE + 1
            try:
                response = client.models.generate_content(
                    model='gemini-2.5-flash',
                    contents=build_prompt(batch),
                )
                results = json.loads(clean_json(response.text))
            except Exception as e:
                print(f"❌ 第 {batch_no} 批失敗：{str(e)[:200]}")
                print(f"   已完成的 {done} 個單字都已存檔。修復問題後重新執行本腳本即可從缺的地方繼續。")
                return

            by_id = {item.get('id'): item for item in results if isinstance(item, dict)}
            for v in batch:
                item = by_id.get(v.id)
                if not item:
                    print(f"  ⚠️ id={v.id}「{v.word}」Gemini 沒回傳結果，跳過（重跑可再補）")
                    continue
                for jp_field, zh_field, key in FIELD_MAP:
                    jp = getattr(v, jp_field)
                    zh = getattr(v, zh_field)
                    new_zh = (item.get(key) or '').strip()
                    if jp and jp.strip() and not (zh and zh.strip()) and new_zh:
                        setattr(v, zh_field, new_zh)
                        filled_fields += 1
                done += 1

            db.session.commit()  # 每批完成就存檔
            print(f"✅ 第 {batch_no} 批完成（進度 {done}/{total}）")

        print("")
        print("========== Backfill 完成 ==========")
        print(f"補齊單字數：{done} 個")
        print(f"填入翻譯欄位：{filled_fields} 格")


if __name__ == '__main__':
    main()
