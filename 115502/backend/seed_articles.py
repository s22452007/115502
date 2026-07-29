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
                "content": "<ruby>日本<rt>にほん</rt></ruby>では、<ruby>毎<rt>まい</rt></ruby><ruby>日<rt>にち</rt></ruby>のゴミの<ruby>分別<rt>ぶんべつ</rt></ruby>がとても<ruby>厳<rt>きび</rt></ruby>しく<ruby>決<rt>き</rt></ruby>められています。<ruby>燃<rt>も</rt></ruby>えるゴミ、<ruby>燃<rt>も</rt></ruby>えないゴミ、そしてペットボトルなどに<ruby>分<rt>わ</rt></ruby>けなければなりません。<ruby>手帳<rt>てちょう</rt></ruby>には、ゴミの<ruby>収集日<rt>しゅうしゅうび</rt></ruby>が<ruby>詳<rt>くわ</rt></ruby>しく<ruby>書<rt>か</rt></ruby>いてあります。<ruby>綺麗<rt>きれい</rt></ruby>で<ruby>住<rt>す</rt></ruby>みやすい<ruby>街<rt>まち</rt></ruby>を<ruby>守<rt>まも</rt></ruby>るために、みんなルールを<ruby>守<rt>まも</rt></ruby>っています。",
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
                "content": "<ruby>夏<rt>なつ</rt></ruby>になると、<ruby>日本<rt>にほん</rt></ruby>のあちこちでお<ruby>祭<rt>まつ</rt></ruby>りが<ruby>開<rt>ひら</rt></ruby>かれます。みんな<ruby>綺麗<rt>きれい</rt></ruby>な<ruby>浴衣<rt>ゆかた</rt></ruby>を<ruby>着<rt>き</rt></ruby>て<ruby>出<rt>で</rt></ruby>かけます。お<ruby>祭<rt>まつ</rt></ruby>りのために、<ruby>何<rt>なん</rt></ruby>ヶ月も<ruby>前<rt>まえ</rt></ruby>から<ruby>踊<rt>おど</rt></ruby>りの<ruby>練習<rt>れんしゅう</rt></ruby>をしておきます。<ruby>屋台<rt>やたい</rt></ruby>で<ruby>美味<rt>おい</rt></ruby>しいものを<ruby>食<rt>た</rt></ruby>べたり、<ruby>花火<rt>はなび</rt></ruby>を<ruby>見<rt>み</rt></ruby>たりするのは、<ruby>日本<rt>にほん</rt></ruby>の<ruby>夏<rt>なつ</rt></ruby>の<ruby>素晴<rt>すば</rt></ruby>らしい<ruby>想<rt>そう</rt></ruby><ruby>出<rt>で</rt></ruby>になります。",
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
                "content": "<ruby>京都<rt>きょうと</rt></ruby>には<ruby>古<rt>ふる</rt></ruby>いお<ruby>寺<rt>てら</rt></ruby>や<ruby>神社<rt>じんじゃ</rt></ruby>がたくさん<ruby>残<rt>のこ</rt></ruby>っています。<ruby>秋<rt>あき</rt></ruby>になると、<ruby>紅葉<rt>こうよう</rt></ruby>の<ruby>景色<rt>けしき</rt></ruby>が<ruby>本当<rt>ほんとう</rt></ruby>に<ruby>綺麗<rt>きれい</rt></ruby>です。<ruby>有名<rt>ゆうめい</rt></ruby>な<ruby>観光地<rt>かんこうち</rt></ruby>は<ruby>人<rt>ひと</rt></ruby>が<ruby>多<rt>おお</rt></ruby>いので、<ruby>朝<rt>あさ</rt></ruby><ruby>早<rt>はや</rt></ruby>く<ruby>出発<rt>しゅっぱつ</rt></ruby>するようにしています。<ruby>事前<rt>じぜん</rt></ruby>にチケットを<ruby>買<rt>か</rt></ruby>っておいたので、<ruby>並<rt>なら</rt></ruby>ばずに<ruby>中<rt>なか</rt></ruby>に<ruby>入<rt>はい</rt></ruby>ることができました。",
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
                "content": "<ruby>日本<rt>にほん</rt></ruby>のビジネス<ruby>社会<rt>しゃかい</rt></ruby>では、<ruby>挨拶<rt>あいさつ</rt></ruby>が<ruby>何<rt>なに</rt></ruby>より<ruby>重視<rt>じゅうし</rt></ruby>されています。<ruby>毎朝<rt>まいあさ</rt></ruby>、<ruby>会社<rt>かいしゃ</rt></ruby>に<ruby>入<rt>はい</rt></ruby>るときは<ruby>大<rt>おお</rt></ruby>きな<ruby>声<rt>こえ</rt></ruby>で「おはようございます」と<ruby>言<rt>い</rt></ruby>わなければなりません。また、<ruby>会議<rt>かいぎ</rt></ruby>の<ruby>資料<rt>しりょう</rt></ruby>は、<ruby>上司<rt>じょうし</rt></ruby>に<ruby>言<rt>い</rt></ruby>われる<ruby>前<rt>まえ</rt></ruby>に<ruby>準備<rt>じゅんび</rt></ruby>しておくことが<ruby>社会人<rt>しゃかいじん</rt></ruby>の<ruby>基本的<rt>きほんてき</rt></ruby>なマナーです。",
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
                "content": "<ruby>日本<rt>にほん</rt></ruby>のアニメは、<ruby>子供<rt>こども</rt></ruby>だけでなく<ruby>大人<rt>おとな</rt></ruby>にも<ruby>大人気<rt>だいにんき</rt></ruby>です。<ruby>最近<rt>さいきん</rt></ruby>の<ruby>映画<rt>えいが</rt></ruby>は、<ruby>素晴<rt>すば</rt></ruby>らしい<ruby>映像<rt>えいぞう</rt></ruby><ruby>技術<rt>ぎじゅつ</rt></ruby>が<ruby>使<rt>つか</rt></ruby>われています。<ruby>最新作<rt>さいしんさく</rt></ruby>の<ruby>公開<rt>こうかい</rt></ruby>スケジュールが<ruby>公式<rt>こうしき</rt></ruby>サイトに<ruby>発表<rt>はっぴょう</rt></ruby>してあるので、ファンはみんな<ruby>楽<rt>たの</rt></ruby>しみにチェックしています。",
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
                grammar_points=item["grammar_points"] 
            )
            db.session.add(article)
            
        db.session.commit()
        print("🎉 成功灌入 5 篇帶有精美假名（Ruby）的 N3 文章！")

if __name__ == "__main__":
    seed_data()