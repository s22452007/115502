"""幫還沒有例句的單字補上四個難度的例句與翻譯。

拍照辨識的新字在辨識時就一起產生例句；從文章收藏的新字原本只存單字、讀音、意思，
之後也沒有程式補，單字本點開就永遠顯示「系統努力生成例句中…」。
現在收藏新字時呼叫 fill_sentences_in_background()，在背景請 AI 補齊，不讓收藏按鈕卡住。
既有缺例句的單字可以跑 upgrade_db_vocabs.py 一次補齊。
"""
import json
import threading

from flask import current_app

from utils.db import db
from utils import gemini_client
from utils.ai_helper import JSON_CONFIG, parse_gemini_json

# 測試時可以關掉，改成同步執行
RUN_IN_BACKGROUND = True

SENTENCE_FIELDS = [
    'sentence_basic', 'sentence_basic_zh',
    'sentence_inter', 'sentence_inter_zh',
    'sentence_upper_inter', 'sentence_upper_inter_zh',
    'sentence_advanced', 'sentence_advanced_zh',
]


def _build_prompt(vocabs):
    items = [{'id': v.id, 'word': v.word, 'kana': v.kana, 'meaning': v.meaning} for v in vocabs]
    return f'''
請為以下日文單字，各生成 4 個難度（初級 N5-N4、中級 N3、中高級 N2、高級 N1）的日文例句與通順的繁體中文翻譯。
規則：
1. 例句要自然、文法正確，並且包含該單字本身。
2. 日文例句中的漢字一律用 [漢字|平假名] 標記讀音，例如 [私|わたし]は[毎日|まいにち][林檎|りんご]を[食|た]べます。
   方括號只能用來標讀音，片假名和平假名不要加方括號。
3. 中文翻譯只寫翻譯本身，不要加括號或其他說明。

輸入單字：
{json.dumps(items, ensure_ascii=False)}

請嚴格以下列 JSON 陣列格式回傳，不可加上 markdown 標籤：
[
  {{"id": 1,
    "sentence_basic": "...", "sentence_basic_zh": "...",
    "sentence_inter": "...", "sentence_inter_zh": "...",
    "sentence_upper_inter": "...", "sentence_upper_inter_zh": "...",
    "sentence_advanced": "...", "sentence_advanced_zh": "..."}}
]
'''


def fill_missing_sentences(vocab_ids):
    """補齊這些單字缺少的例句；已經有初級例句的字略過。回傳補了幾個字。要在 app context 裡呼叫。"""
    from models import Vocab
    targets = [v for v in Vocab.query.filter(Vocab.id.in_(list(vocab_ids or []))).all()
               if not (v.sentence_basic or '').strip()]
    if not targets:
        return 0

    response = gemini_client.generate_content('context', _build_prompt(targets), config=JSON_CONFIG)
    items = parse_gemini_json(response.text)
    by_id = {item.get('id'): item for item in (items or []) if isinstance(item, dict)}

    filled = 0
    for v in targets:
        item = by_id.get(v.id)
        if not item:
            continue
        for field in SENTENCE_FIELDS:
            value = str(item.get(field) or '').strip()
            if value and not getattr(v, field):
                setattr(v, field, value[:255])
        filled += 1
    db.session.commit()
    return filled


def _run(vocab_ids):
    try:
        n = fill_missing_sentences(vocab_ids)
        if n:
            print(f"✅ 已幫 {n} 個新單字補上分級例句")
    except Exception as e:
        db.session.rollback()
        # 補例句失敗不影響收藏本身，之後跑 upgrade_db_vocabs.py 可以再補
        print(f"⚠️ 新單字例句生成失敗（之後可用 upgrade_db_vocabs.py 補齊）：{e}")


def _run_in_thread(app, vocab_ids):
    with app.app_context():
        try:
            _run(vocab_ids)
        finally:
            db.session.remove()  # 背景執行緒自己的 session，用完要收掉


def fill_sentences_in_background(vocab_ids):
    """在背景補例句（要在 request 裡呼叫，才拿得到 app）。"""
    ids = [i for i in (vocab_ids or []) if i]
    if not ids:
        return
    if RUN_IN_BACKGROUND:
        app = current_app._get_current_object()
        threading.Thread(target=_run_in_thread, args=(app, ids), daemon=True).start()
    else:
        _run(ids)
