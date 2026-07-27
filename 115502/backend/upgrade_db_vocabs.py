# -*- coding: utf-8 -*-
"""
全面升級資料庫單字庫腳本：
1. 將系統已知預設單字直接升級為 [漢字|假名] 標音格式與繁體中文翻譯。
2. 對於資料庫中其他沒有標音或沒有翻譯的舊單字，調用 Gemini API 自動生級補齊。
"""
import os
import json
import sys
from dotenv import load_dotenv

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(BASE_DIR, '.env'), override=True)

from google import genai

sys.path.insert(0, BASE_DIR)
from app import app
from utils.db import db
from models import Vocab

SEED_MAP = {
    'ラーメン': {
        'sentence_basic': 'このラーメンは[美味|おい]しいです。', 'sentence_basic_zh': '這碗拉麵很好吃。',
        'sentence_inter': 'このラーメン[屋|や]は[行列|ぎょうれつ]ができるほど[有名|ゆうめい]だ。', 'sentence_inter_zh': '這家拉麵店有名到會排起長龍。',
        'sentence_upper_inter': 'この[店|みせ]のラーメンは、スープがなくなり[次第|しだい][終了|しゅうりょう]となります。', 'sentence_upper_inter_zh': '這家店的拉麵，湯底售完即止。',
        'sentence_advanced': 'こだわりの[豚骨|とんこつ]を[何時間|なんじかん]も[煮込|にこ]んだ、[至極|しごく]のラーメンである。', 'sentence_advanced_zh': '這是將講究的豚骨熬煮數小時而成的極品拉麵。'
    },
    'かえだま': {
        'sentence_basic': '[替玉|かえだま]をお[願|ねが]いします。', 'sentence_basic_zh': '麻煩給我加麵。',
        'sentence_inter': 'スープが[残|のこ]っているので、[替玉|かえだま]を[注文|ちゅうもん]した。', 'sentence_inter_zh': '因為還剩有湯底，所以我點了加麵。',
        'sentence_upper_inter': 'ダイエット[中|ちゅう]にもかかわらず、[誘惑|ゆうわく]に[負|ま]けて[替玉|かえだま]を[頼|たの]んでしまった。', 'sentence_upper_inter_zh': '儘管在減肥中，我還是禁不起誘惑點了加麵。',
        'sentence_advanced': '[博多|はかた]ラーメンの[醍醐味|だいごみ]は、やはり[替玉|かえだま]にあると[言|い]えるだろう。', 'sentence_advanced_zh': '博多拉麵的精髓，果真可以說是在於加麵吧。'
    },
    'きっぷ': {
        'sentence_basic': '[切符|きっぷ]を[買|か]います。', 'sentence_basic_zh': '我要買車票。',
        'sentence_inter': '[券売機|けんばいき]で[新幹線|しんかんせん]の[切符|きっぷ]を[購入|こうにゅう]した。', 'sentence_inter_zh': '我在售票機購買了新幹線的車票。',
        'sentence_upper_inter': '[払|はら]い[戻|もど]し[期間|きかん]を過[す]ぎた[切符|きっぷ]は、[無効|むこう]になってしまうので[注意|ちゅうい]が[必要|ひつよう]だ。', 'sentence_upper_inter_zh': '超過退票期限的車票將會失效，需要特別注意。',
        'sentence_advanced': '[電子|でんし]マネーの[普及|ふきゅう]により、[紙|かみ]の[切符|きっぷ]を[手|て]にする[機会|きかい]はめっきり[減|へ]った。', 'sentence_advanced_zh': '隨著電子支付的普及，拿到紙本車票的機會大幅減少了。'
    },
    'かいさつぐち': {
        'sentence_basic': '[改札口|かいさつぐち]はどこですか？', 'sentence_basic_zh': '請問剪票口在哪裡？',
        'sentence_inter': '[改札口|かいさつぐち]で[友|とも]だちと[待|ま]ち[合|あ]わせをしている。', 'sentence_inter_zh': '我在剪票口和朋友碰面。',
        'sentence_upper_inter': '[朝|あさ]のラッシュ[時|じ]の[改札口|かいさつぐち]は、[前|まえ]に[進|すす]めないほど[混雑|こんざつ]している。', 'sentence_upper_inter_zh': '早晨尖峰時段的剪票口擁擠得讓人無法前進。',
        'sentence_advanced': '[最新|さいしん]の[顔認証|かおにんしょう]システムを[備|そな]えた[改札口|かいさつぐち]が、[一部|いちぶ]の[駅|えき]で[導入|どうにゅう]され[始|はじ]めている。', 'sentence_advanced_zh': '配備最新臉部辨識系統的剪票口，已開始在部分車站導入。'
    },
    'おまもり': {
        'sentence_basic': 'お[守|まも]りを[買|か]いました。', 'sentence_basic_zh': '我買了御守。',
        'sentence_inter': '[神社|じんじゃ]で[合格祈願|ごうかくきがん]のお[守|まも]りを[買|か]った。', 'sentence_inter_zh': '我在神社買了祈求考試合格的御守。',
        'sentence_upper_inter': '[祖母|そぼ]からもらったこのお[守|まも]りは、[私|わたし]にとって[何|なに]よりも[大切|たいせつ]なものだ。', 'sentence_upper_inter_zh': '祖母給我的這個御守，對我來說比什麼都重要。',
        'sentence_advanced': '[古来|こらい]より、お[守|まも]りには[人々|ひとびと]の[切実|せつじつ]な[願|ねが]いと[祈|いの]りが[込|こ]められている。', 'sentence_advanced_zh': '自古以來，御守中便蘊含著人們深切的願望與祈禱。'
    },
    'アニメ': {
        'sentence_basic': '[日本|にほん]のアニメが[好|す]きです。', 'sentence_basic_zh': '我喜歡日本的動畫。',
        'sentence_inter': '[休日|きゅうじつ]は[一日中|いちにちじゅう]アニメを[見|み]て過[す]ごすことが[多|おお]い。', 'sentence_inter_zh': '假日常常一整天看動畫度過。',
        'sentence_upper_inter': '[日本|にほん]のアニメは[国内|こくな]のみならず、[海外|かいがい]でも[高|たか]く[評価|ひょうか]されている。', 'sentence_upper_inter_zh': '日本動畫不僅在國內，在海外也受到高度評價。',
        'sentence_advanced': '[精緻|せいち]な[作画|さくが]と[複雑|ふくざつ]な[人間模様|にんげんもよう]を描[えが]いたそのアニメは、[社会現象|しゃかいげんしょう]を[巻|ま]き[起|お]こした。', 'sentence_advanced_zh': '這部動畫以精緻的作畫和複雜的人際關係描寫，引發了社會現象。'
    },
    'コーヒー': {
        'sentence_basic': 'ホットコーヒーを[一|ひと]つください。', 'sentence_basic_zh': '麻煩給我一杯熱咖啡。',
        'sentence_inter': '[毎朝|まいあさ]、[淹|い]れたてのコーヒーを[飲|の]むのが[日課|にっか]だ。', 'sentence_inter_zh': '每天早晨喝現沖的咖啡是我的日常習慣。',
        'sentence_upper_inter': '[彼|かれ]はコーヒーの[豆|まめ]の[産地|さんち]にまでこだわるほどのコーヒー[好|ず]きだ。', 'sentence_upper_inter_zh': '他是個連咖啡豆產地都極度講究的咖啡愛好者。',
        'sentence_advanced': '[芳醇|ほうじゅん]な[香|かお]りと[深|ふか]いコクが[特徴|とくちょう]のこのコーヒーは、[至福|しふく]のひとときをもたらしてくれる。', 'sentence_advanced_zh': '這款咖啡以濃郁的香氣和深邃的口感為特色，能帶來幸福至極的時光。'
    }
}

BATCH_SIZE = 6

def clean_json(text):
    text = text.strip()
    if text.startswith("```json"):
        text = text.replace("```json", "", 1)
    if text.startswith("```"):
        text = text.replace("```", "", 1)
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()

def build_prompt(batch):
    items = [{'id': v.id, 'word': v.word, 'kana': v.kana, 'meaning': v.meaning} for v in batch]
    return f'''
請為以下日文單字，重新生成或升級 4 個難度層級（初級 N5-N4、中級 N3、中高級 N2、高級 N1）的「日文例句」與「通順繁體中文翻譯」。
極重要規則：日文例句中，只要出現「漢字」，一律嚴格使用 `[漢字|平假名]` 格式標註假名讀音（例：`[私|わたし]は[毎日|まいにち][林檎|りんご]を[食|た]べます。`）。

輸入單字清單：
{json.dumps(items, ensure_ascii=False, indent=2)}

請嚴格以下列 JSON 陣列格式回傳，不可加上任何前置後置說明文字：
[
  {{
    "id": 1,
    "sentence_basic": "初級日文例句[漢字|假名]",
    "sentence_basic_zh": "初級繁體中文翻譯",
    "sentence_inter": "中級日文例句[漢字|假名]",
    "sentence_inter_zh": "中級繁體中文翻譯",
    "sentence_upper_inter": "中高級日文例句[漢字|假名]",
    "sentence_upper_inter_zh": "中高級繁體中文翻譯",
    "sentence_advanced": "高級日文例句[漢字|假名]",
    "sentence_advanced_zh": "高級繁體中文翻譯"
  }}
]
'''

def main():
    api_key = os.environ.get("GEMINI_API_KEY_camara") or os.environ.get("GEMINI_API_KEY")
    client = genai.Client(api_key=api_key) if api_key else None

    with app.app_context():
        all_vocabs = Vocab.query.all()
        print(f"進度：掃描資料庫中 {len(all_vocabs)} 個單字...")
        
        seed_updated = 0
        ai_targets = []
        
        for v in all_vocabs:
            key = v.kana if v.kana in SEED_MAP else (v.word if v.word in SEED_MAP else None)
            if key and SEED_MAP[key]:
                data = SEED_MAP[key]
                v.sentence_basic = data['sentence_basic']
                v.sentence_basic_zh = data['sentence_basic_zh']
                v.sentence_inter = data['sentence_inter']
                v.sentence_inter_zh = data['sentence_inter_zh']
                v.sentence_upper_inter = data['sentence_upper_inter']
                v.sentence_upper_inter_zh = data['sentence_upper_inter_zh']
                v.sentence_advanced = data['sentence_advanced']
                v.sentence_advanced_zh = data['sentence_advanced_zh']
                seed_updated += 1
            else:
                # 檢查是否缺少標音 (沒有 '[') 或缺少中文翻譯
                if not v.sentence_basic_zh or '[' not in (v.sentence_basic or ''):
                    ai_targets.append(v)

        db.session.commit()
        print(f"✅ 已直接秒速更新 {seed_updated} 個已知預設單字的標音與翻譯！")
        
        if not ai_targets:
            print("🎉 所有單字都已完成 [漢字|假名] 標音與中文翻譯，無須額外呼叫 AI！")
            return
            
        if not client:
            print("❌ 找不到 GEMINI_API_KEY，無法處理其餘單字。")
            return

        total = len(ai_targets)
        print(f"🤖 剩下 {total} 個單字需要使用 AI 升級標音與翻譯...")
        
        done = 0
        for i in range(0, total, BATCH_SIZE):
            batch = ai_targets[i:i + BATCH_SIZE]
            batch_no = i // BATCH_SIZE + 1
            try:
                print(f"正在處理第 {batch_no} 批 ({len(batch)} 個單字)...")
                response = client.models.generate_content(
                    model='gemini-2.5-flash',
                    contents=build_prompt(batch),
                )
                results = json.loads(clean_json(response.text))
                by_id = {item.get('id'): item for item in results if isinstance(item, dict)}
                
                for v in batch:
                    item = by_id.get(v.id)
                    if item:
                        for field in ['sentence_basic', 'sentence_basic_zh', 'sentence_inter', 'sentence_inter_zh', 'sentence_upper_inter', 'sentence_upper_inter_zh', 'sentence_advanced', 'sentence_advanced_zh']:
                            val = item.get(field)
                            if val and val.strip():
                                setattr(v, field, val.strip())
                        done += 1
                db.session.commit()
                print(f"✅ 第 {batch_no} 批存檔成功！(進度 {done}/{total})")
            except Exception as e:
                print(f"⚠️ 第 {batch_no} 批遭遇問題: {e}")
                
        print(f"========== 升級完成：共成功升級 {seed_updated + done} 個單字 ==========")

if __name__ == '__main__':
    main()
