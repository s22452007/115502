import json
from app import app
from models import db, Article

def seed_data():
    with app.app_context():
        # 先清除舊的文章資料，避免重複執行時資料爆滿
        db.session.query(Article).delete()
        
        sample_articles = [
            {
                "theme": "日常生活",
                "level": "N3",
                "title": "毎日のゴミ出しと環境問題",
                "content": "日本では、毎日のゴミの分別がとても厳しく決められています。燃えるゴミ、燃えないゴミ、そしてペットボトルなどに分けなければなりません。手帳には、ゴミの収集日が詳しく書いてあります。綺麗で住みやすい街を守るために、みんなルールを守っています。",
                "translation": "在日本，每天的垃圾分類被規定得非常嚴格。必須分成可燃垃圾、不可燃垃圾以及寶特瓶等。手冊上詳細地寫著垃圾收集的日子。為了守護乾淨且宜居的街道，大家都在遵守規則。",
                "grammar_points": {
                    "grammars": [
                        {"expression": "〜てあります", "meaning": "表示某人有目的做的動作，其結果狀態正留存著。", "example": "手帳に書いてあります（手冊上寫著）"}
                    ],
                    "vocabularies": [
                        {"word": "分別", "reading": "ぶんべつ", "meaning": "分類"},
                        {"word": "収集日", "reading": "しゅうしゅうび", "meaning": "收集日"}
                    ]
                }
            },
            {
                "theme": "日本文化",
                "level": "N3",
                "title": "日本の伝統的なお祭り",
                "content": "夏になると、日本のあちこちでお祭りが開かれます。みんな綺麗な浴衣を着て出かけます。お祭りのために、何ヶ月も前から踊りの練習をしておきます。屋台で美味しいものを食べたり、花火を見たりするのは、日本の夏の素晴らしい思い出になります。",
                "translation": "一到夏天，日本各處都會舉辦祭典。大家都會穿上漂亮的浴衣出門。為了祭典，從幾個月前就會預先做好舞蹈的練習。在攤位吃美食、看煙火，會成為日本夏天極棒的回憶。",
                "grammar_points": {
                    "grammars": [
                        {"expression": "〜ておきます", "meaning": "表示為了某個特定目的，提前、預先做好某個準備動作。", "example": "練習をしておきます（預先做好練習）"}
                    ],
                    "vocabularies": [
                        {"word": "伝統的", "reading": "でんとうてき", "meaning": "傳統的"},
                        {"word": "屋台", "reading": "やたい", "meaning": "路邊攤/攤位"}
                    ]
                }
            },
            {
                "theme": "旅遊觀光",
                "level": "N3",
                "title": "京都の古いお寺を巡る旅",
                "content": "京都には古いお寺や神社がたくさん残っています。秋になると、紅葉の景色が本当に綺麗です。有名な観光地は人が多いので、朝早く出発するようにしています。事前にチケットを買っておいたので、並ばずに中に入ることができました。",
                "translation": "京都留存著許多古老寺廟和神社。一到秋天，紅葉的景色真的很美。因為著名的觀光地人很多，我都會注意儘量提早出發。因為事先買好了票，所以不用排隊就能進到裡面。",
                "grammar_points": {
                    "grammars": [
                        {"expression": "〜ようにしています", "meaning": "表示習慣性地努力做到某事，或持續保持某種作法。", "example": "出発するようにしています（努力做到提早出發）"}
                    ],
                    "vocabularies": [
                        {"word": "巡る", "reading": "めぐる", "meaning": "環繞/巡訪"},
                        {"word": "事前", "reading": "じぜん", "meaning": "事先"}
                    ]
                }
            },
            {
                "theme": "職場應用",
                "level": "N3",
                "title": "日本の会社での挨拶とマナー",
                "content": "日本のビジネス社会では、挨拶が何より重視されています。毎朝、会社に入るときは大きな声で「おはようございます」と言わなければなりません。また、会議の資料は、上司に言われる前に準備しておくことが社会人の基本的なマナーです。",
                "translation": "在日本的商業社會中，問候比什麼都受到重視。每天早晨進入公司時，必須大聲說「早安」。此外，在被上司開口要求之前就先將會議資料準備好，是社會人的基本禮儀。",
                "grammar_points": {
                    "grammars": [
                        {"expression": "〜言われる", "meaning": "被動動詞。表示受到來自他人的某種動作或言論。", "example": "上司に言われる（被上司說/要求）"}
                    ],
                    "vocabularies": [
                        {"word": "重視", "reading": "じゅうし", "meaning": "重視"},
                        {"word": "基本的", "reading": "きほんてき", "meaning": "基本的"}
                    ]
                }
            },
            {
                "theme": "流行動漫",
                "level": "N3",
                "title": "世界中で愛される日本のアニメ",
                "content": "日本のアニメは、子供だけでなく大人にも大人気です。最近の映画は、素晴らしい映像技術が使われています。最新作の公開スケジュールが公式サイトに発表してあるので、ファンはみんな楽しみにチェックしています。",
                "translation": "日本的動漫不僅受到小孩子，在大人之間也享有人氣。最近的電影中，使用了極佳的影像技術。因為最新作品的上映日程已經公布在官方網站上，粉絲們都滿懷期待地在確認。",
                "grammar_points": {
                    "grammars": [
                        {"expression": "〜だけでなく", "meaning": "表示不僅僅是前項，也包含後項（不只……而且……）。", "example": "子供だけでなく（不僅是小孩子）"}
                    ],
                    "vocabularies": [
                        {"word": "映像", "reading": "えいぞう", "meaning": "影像/畫面"},
                        {"word": "公開", "reading": "こうかい", "meaning": "公開/上映"}
                    ]
                }
            }
        ]

        for item in sample_articles:
            article = Article(
                theme=item["theme"],
                level=item["level"],
                title=item["title"],
                content=item["content"],
                translation=item["translation"],
                # 將 dictionary 結構直接丟給 JSON 欄位，SQLAlchemy 會自動處理
                grammar_points=item["grammar_points"] 
            )
            db.session.add(article)
            
        db.session.commit()
        print("🎉 成功灌入 5 篇精美 N3 文章與文法單字資料！")

if __name__ == "__main__":
    seed_data()