from app import app
from models import db, Article

def seed_articles():
    with app.app_context():
        # 清除舊文章，重新寫入統整後的完整文章清單
        Article.query.delete()
        db.session.commit()

        all_articles = [
            # ==========================================
            # 1. 舊有經典文章 (ID 1 ~ 6)
            # ==========================================
            Article(
                id=1,
                theme="日常生活", level="N3", 
                title="毎日のゴミ出しと環境問題",
                content="<ruby>日本<rt>にほん</rt></ruby>では、<ruby>毎<rt>まい</rt></ruby><ruby>日<rt>にち</rt></ruby>のゴミの<ruby>分別<rt>ぶんべつ</rt></ruby>がとても<ruby>厳<rt>きび</rt></ruby>しく<ruby>決<rt>き</rt></ruby>められています。<ruby>燃<rt>も</rt></ruby>えるゴミ、<ruby>燃<rt>も</rt></ruby>えないゴミ、そしてペットボトルなどに<ruby>分<rt>わ</rt></ruby>けなければなりません。<ruby>手帳<rt>てちょう</rt></ruby>には、ゴミの<ruby>収集日<rt>しゅうしゅうび</rt></ruby>が<ruby>詳<rt>くわ</rt></ruby>しく<ruby>書<rt>か</rt></ruby>いてあります。<ruby>綺麗<rt>きれい</rt></ruby>で<ruby>住<rt>す</rt></ruby>みやすい<ruby>街<rt>まち</rt></ruby>を<ruby>守<rt>まも</rt></ruby>るために、みんなルールを<ruby>守<rt>まも</rt></ruby>っています。",
                translation="在日本，每天的垃圾分類被規定得非常嚴格。必須分成可燃垃圾、不可燃垃圾以及寶特瓶等。手冊上詳細地寫著垃圾收集的日子。為了守護乾淨且宜居的街道，大家都在遵守規則。",
                grammar_points={
                    "grammars": [{"expression": "〜てあります", "meaning": "表示某人有目的做的動作，其結果狀態正留存著。", "example": "手帳に書いてあります"}],
                    "vocabularies": [
                        {"word": "分別", "reading": "ぶんべつ", "meaning": "分類"},
                        {"word": "収集日", "reading": "しゅうしゅうび", "meaning": "收集日"}
                    ]
                }
            ),
            Article(
                id=2,
                theme="日本文化", level="N3", 
                title="日本の伝統的なお祭り",
                content="<ruby>夏<rt>なつ</rt></ruby>になると、<ruby>日本<rt>にほん</rt></ruby>のあちこちでお<ruby>祭<rt>まつ</rt></ruby>りが<ruby>開<rt>ひら</rt></ruby>かれます。みんな<ruby>綺麗<rt>きれい</rt></ruby>な<ruby>浴衣<rt>ゆかた</rt></ruby>を<ruby>着<rt>き</rt></ruby>て<ruby>出<rt>で</rt></ruby>かけます。お<ruby>祭<rt>まつ</rt></ruby>りのために、<ruby>何<rt>なん</rt></ruby>ヶ月も<ruby>前<rt>まえ</rt></ruby>から<ruby>踊<rt>おど</rt></ruby>りの<ruby>練習<rt>れんしゅう</rt></ruby>をしておきます。<ruby>屋台<rt>やたい</rt></ruby>で<ruby>美味<rt>おい</rt></ruby>しいものを<ruby>食<rt>た</rt></ruby>べたり、<ruby>花火<rt>はなび</rt></ruby>を<ruby>見<rt>み</rt></ruby>たりするのは、<ruby>日本<rt>にほん</rt></ruby>の<ruby>夏<rt>なつ</rt></ruby>の<ruby>素晴<rt>すば</rt></ruby>らしい<ruby>思<rt>おも</rt></ruby>い<ruby></ruby><ruby>出<rt>で</rt></ruby>になります。",
                translation="一到夏天，日本各處都會舉辦祭典。大家都會穿上漂亮的浴衣出門。為了祭典，從幾個月前就會預先做好舞蹈的練習。在攤位吃美食、看煙火，會成為日本夏天極棒的回憶。",
                grammar_points={
                    "grammars": [{"expression": "〜ておきます", "meaning": "表示為了某個特定目的，提前、預先做好某個準備動作。", "example": "練習をしておきます"}],
                    "vocabularies": [
                        {"word": "伝統的", "reading": "でんとうてき", "meaning": "傳統的"},
                        {"word": "屋台", "reading": "やたい", "meaning": "路邊攤/攤位"}
                    ]
                }
            ),
            Article(
                id=3,
                theme="旅遊觀光", level="N3", 
                title="京都の古いお寺を巡る旅",
                content="<ruby>京都<rt>きょうと</rt></ruby>には<ruby>古<rt>ふる</rt></ruby>いお<ruby>寺<rt>てら</rt></ruby>や<ruby>神社<rt>じんじゃ</rt></ruby>がたくさん<ruby>残<rt>のこ</rt></ruby>っています。<ruby>秋<rt>あき</rt></ruby>になると、<ruby>紅葉<rt>こうよう</rt></ruby>の<ruby>景色<rt>けしき</rt></ruby>が<ruby>本当<rt>ほんとう</rt></ruby>に<ruby>綺麗<rt>きれい</rt></ruby>です。<ruby>有名<rt>ゆうめい</rt></ruby>な<ruby>観光地<rt>かんこうち</rt></ruby>は<ruby>人<rt>ひと</rt></ruby>が<ruby>多<rt>おお</rt></ruby>いので、<ruby>朝<rt>あさ</rt></ruby><ruby>早<rt>はや</rt></ruby>く<ruby>出発<rt>しゅっぱつ</rt></ruby>するようにしています。<ruby>事前<rt>じぜん</rt></ruby>にチケットを<ruby>買<rt>か</rt></ruby>っておいたので、<ruby>並<rt>なら</rt></ruby>ばずに<ruby>中<rt>なか</rt></ruby>に<ruby>入<rt>はい</rt></ruby>ることができました。",
                translation="京都留存著許多古老寺廟和神社。一到秋天，紅葉的景色真的很美。因為著名的觀光地人很多，我都會注意儘量提早出發。因為事先買好了票，所以不用排隊就能進到裡面。",
                grammar_points={
                    "grammars": [{"expression": "〜ようにしています", "meaning": "表示習慣性地努力做到某事，或持續保持某種作法。", "example": "出発するようにしています"}],
                    "vocabularies": [
                        {"word": "巡る", "reading": "めぐる", "meaning": "環繞/巡訪"},
                        {"word": "事前", "reading": "じぜん", "meaning": "事先"}
                    ]
                }
            ),
            Article(
                id=4,
                theme="職場應用", level="N3", 
                title="日本の会社での挨拶とマナー",
                content="<ruby>日本<rt>にほん</rt></ruby>のビジネス<ruby>社会<rt>しゃかい</rt></ruby>では、<ruby>挨拶<rt>あいさつ</rt></ruby>が<ruby>何<rt>なに</rt></ruby>より<ruby>重視<rt>じゅうし</rt></ruby>されています。<ruby>毎朝<rt>まいあさ</rt></ruby>、<ruby>会社<rt>かいしゃ</rt></ruby>に<ruby>入<rt>はい</rt></ruby>るときは<ruby>大<rt>おお</rt></ruby>きな<ruby>声<rt>こえ</rt></ruby>で「おはようございます」と<ruby>言<rt>い</rt></ruby>わなければなりません。また、<ruby>会議<rt>かいぎ</rt></ruby>の<ruby>資料<rt>しりょう</rt></ruby>は、<ruby>上司<rt>じょうし</rt></ruby>に<ruby>言<rt>い</rt></ruby>われる<ruby>前<rt>まえ</rt></ruby>に<ruby>準備<rt>じゅんび</rt></ruby>しておくことが<ruby>社会人<rt>しゃかいじん</rt></ruby>の<ruby>基本的<rt>きほんてき</rt></ruby>なマナーです。",
                translation="在日本的商業社會中，問候比什麼都受到重視。每天早晨進入公司時，必須大聲說「早安」。此外，在被上司開口要求之前就先將會議資料準備好，是社會人的基本禮儀。",
                grammar_points={
                    "grammars": [{"expression": "〜言われる", "meaning": "被動動詞。表示受到來自他人的某種動作或言論。", "example": "上司に言われる"}],
                    "vocabularies": [
                        {"word": "重視", "reading": "じゅうし", "meaning": "重視"},
                        {"word": "基本的", "reading": "きほんてき", "meaning": "基本的"}
                    ]
                }
            ),
            Article(
                id=5,
                theme="流行動漫", level="N3", 
                title="世界中で愛される日本のアニメ",
                content="<ruby>日本<rt>にほん</rt></ruby>のアニメは、<ruby>子供<rt>こども</rt></ruby>だけでなく<ruby>大人<rt>おとな</rt></ruby>にも<ruby>大人気<rt>だいにんき</rt></ruby>です。<ruby>最近<rt>さいきん</rt></ruby>の<ruby>映画<rt>えいが</rt></ruby>は、<ruby>素晴<rt>すば</rt></ruby>らしい<ruby>映像<rt>えいぞう</rt></ruby><ruby>技術<rt>ぎじゅつ</rt></ruby>が<ruby>使<rt>つか</rt></ruby>われています。<ruby>最新作<rt>さいしんさく</rt></ruby>の<ruby>公開<rt>こうかい</rt></ruby>スケジュールが<ruby>公式<rt>こうしき</rt></ruby>サイトに<ruby>発表<rt>はっぴょう</rt></ruby>してあるので、ファンはみんな<ruby>楽<rt>たの</rt></ruby>しみにチェックしています。",
                translation="日本的動漫不僅受到小孩子，在大人之間也享有人氣。最近的電影中，使用了極佳的影像技術。因為最新作品的上映日程已經公布在官方網站上，粉絲們都滿懷期待地在確認。",
                grammar_points={
                    "grammars": [{"expression": "〜だけでなく", "meaning": "表示不僅僅是前項，也包含後項。", "example": "子供だけでなく"}],
                    "vocabularies": [
                        {"word": "映像", "reading": "えいぞう", "meaning": "影像/畫面"},
                        {"word": "公開", "reading": "こうかい", "meaning": "公開/上映"}
                    ]
                }
            ),
            
            # ==========================================
            # 2. 升級版的三篇精選文章 (ID 7 ~ 9)
            # ==========================================
            Article(
                id=7,
                theme="日本美食",
                level="N3",
                title="日本の屋台文化と隠された魅力",
                content="<ruby>日本<rt>にほん</rt></ruby>のお<ruby>祭<rt>まつ</rt></ruby>りに<ruby>行<rt>い</rt></ruby>くと、たくさんの<ruby>屋台<rt>やたい</rt></ruby>が<ruby>並<rt>なら</rt></ruby>んでいます。たこ<ruby>焼<rt>や</rt></ruby>きやりんご<ruby>飴<rt>あめ</rt></ruby>だけでなく、<ruby>最近<rt>さいきん</rt></ruby>ではさまざまな<ruby>国<rt>くに</rt></ruby>の<ruby>料理<rt>りょうり</rt></ruby>も<ruby>見<rt>み</rt></ruby>かけるようになりました。<ruby>屋台<rt>やたい</rt></ruby>の<ruby>楽<rt>たの</rt></ruby>しさは、ただ<ruby>食<rt>た</rt></ruby>べるだけでなく、その<ruby>活気<rt>かっき</rt></ruby>ある<ruby>雰囲気<rt>ふんいき</rt></ruby>を<ruby>体感<rt>たいかん</rt></ruby>できるところにあります。",
                translation="去日本的祭典時，會看到許多排成一列的攤販。除了章魚燒跟糖蘋果之外，最近也能看到各種國家的料理。攤販的樂趣不僅僅在於吃東西，更在於能親身體驗那充滿活力的氛圍。",
                grammar_points={
                    "grammars": [{"expression": "~だけでなく", "meaning": "不僅…而且…", "example": "たこ焼きだけでなく、色々な料理がある。"}],
                    "vocabularies": [
                        {"word": "屋台", "reading": "やたい", "meaning": "攤販、路邊攤"},
                        {"word": "魅力", "reading": "みりょく", "meaning": "魅力"},
                        {"word": "雰囲気", "reading": "ふんいき", "meaning": "氣氛"},
                        {"word": "活気", "reading": "かっき", "meaning": "活力、熱鬧"}
                    ]
                }
            ),
            Article(
                id=8,
                theme="台灣文化",
                level="N3",
                title="台湾の夜市：食べて歩く文化の中心",
                content="<ruby>台湾<rt>たいわん</rt></ruby>の<ruby>夜市<rt>よいち</rt></ruby>は、<ruby>地元<rt>じもと</rt></ruby>の<ruby>人々<rt>ひとびと</rt></ruby>だけでなく<ruby>観光客<rt>かんこうきゃく</rt></ruby>にとっても<ruby>大人気<rt>だいにんき</rt></ruby>の<ruby>場所<rt>ばしょ</rt></ruby>です。<ruby>夜遅<rt>よるおそ</rt></ruby>くまで<ruby>多<rt>おお</rt></ruby>くの<ruby>人<rt>ひと</rt></ruby>が<ruby>集<rt>あつ</rt></ruby>まり、<ruby>様々<rt>さまざま</rt></ruby>なグルメを<ruby>味わう<rt>あじわう</rt></ruby>ことができます。<ruby>魯肉飯<rt>ろーふぁん</rt></ruby>や<ruby>小籠包<rt>しょうろんぽう</rt></ruby>など、<ruby>台湾<rt>たいわん</rt></ruby>の<ruby>美味<rt>おい</rt></ruby>しいものを<ruby>一度<rt>いちど</rt></ruby>に<ruby>楽<rt>たの</rt></ruby>しむことができるのが<ruby>大<rt>おお</rt></ruby>きな<ruby>特徴<rt>とくちょう</rt></ruby>です。",
                translation="台灣的夜市不只是當地人的最愛，對觀光客來說也是超人氣的場所。直到深夜都有許多人聚集，可以品嚐各種美食。魯肉飯和小籠包等，能一次享受台灣美味的食物是其最大特色。",
                grammar_points={
                    "grammars": [{"expression": "~だけでなく", "meaning": "不僅…而且…", "example": "地元の人々だけでなく観光客にも人気がある。"}],
                    "vocabularies": [
                        {"word": "夜市", "reading": "よいち", "meaning": "夜市"},
                        {"word": "観光客", "reading": "かんこうきゃく", "meaning": "觀光客"},
                        {"word": "味わう", "reading": "あじわう", "meaning": "品嚐"},
                        {"word": "特徴", "reading": "とくちょう", "meaning": "特色"}
                    ]
                }
            ),
            Article(
                id=9,
                theme="日本傳說",
                level="N3",
                title="京都に伝わる妖怪の物語",
                content="<ruby>京都<rt>きょうと</rt></ruby>には、<ruby>昔<rt>むかし</rt></ruby>から<ruby>様々<rt>さまざま</rt></ruby>な<ruby>妖怪<rt>ようかい</rt></ruby>の<ruby>伝説<rt>でんせつ</rt></ruby>が<ruby>残<rt>のこ</rt></ruby>っています。<ruby>夜<rt>よる</rt></ruby>になると、<ruby>古<rt>ふる</rt></ruby>い<ruby>道具<rt>どうぐ</rt></ruby>が<ruby>妖怪<rt>ようかい</rt></ruby>に<ruby>変<rt>か</rt></ruby>わるという「<ruby>付喪神<rt>つくもがみ</rt></ruby>」の<ruby>話<rt>はなし</rt></ruby>は<ruby>特<rt>とく</rt></ruby>に<ruby>有名<rt>ゆうめい</rt></ruby>です。<ruby>昔<rt>むかし</rt></ruby>の<ruby>人<rt>ひと</rt></ruby>は、<ruby>物<rt>もの</rt></ruby>を<ruby>大切<rt>たいせつ</rt></ruby>にする<ruby>心<rt>こころ</rt></ruby>をこのような<ruby>物語<rt>ものがたり</rt></ruby>を<ruby>通<rt>つう</rt></ruby>じて<ruby>伝<rt>つた</rt></ruby>えてきました。",
                translation="京都自古以來就流傳著各種妖怪的傳說。到了夜晚，舊工具會變成妖怪的『付喪神』故事特別有名。古人透過這樣的故事，傳達了珍惜物品的心意。",
                grammar_points={
                    "grammars": [{"expression": "~を通じて", "meaning": "透過、藉由", "example": "物語を通じて大切なことを学ぶ。"}],
                    "vocabularies": [
                        {"word": "妖怪", "reading": "ようかい", "meaning": "妖怪"},
                        {"word": "伝説", "reading": "でんせつ", "meaning": "傳說"},
                        {"word": "大切", "reading": "たいせつ", "meaning": "珍貴、重要"},
                        {"word": "付喪神", "reading": "つくもがみ", "meaning": "付喪神（器物放久後化成的妖怪）"}
                    ]
                }
            )
        ]

        db.session.add_all(all_articles)
        db.session.commit()
        print("🎉 所有新舊文章已成功統整並寫入資料庫！")

if __name__ == '__main__':
    seed_articles()