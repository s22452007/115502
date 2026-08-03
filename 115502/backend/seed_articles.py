from app import app
from models import db, Article

def seed_articles():
    with app.app_context():
        # 清除舊文章，重新寫入涵蓋 N5~N1 的完整文章清單
        Article.query.delete()
        db.session.commit()

        all_articles = [
            # ==========================================
            # 【 N5 級別 】 (ID: 101 ~ 108)
            # ==========================================
            Article(id=101, theme="日常生活", level="N5", title="毎日の朝ごはん",
                content="<ruby>私<rt>わたし</rt></ruby>は<ruby>毎日<rt>まいにち</rt></ruby>、パンを<ruby>食<rt>た</rt></ruby>べます。そして、コーヒーを<ruby>飲<rt>の</rt></ruby>みます。<ruby>朝<rt>あさ</rt></ruby>ごはんはとても<ruby>大切<rt>たいせつ</rt></ruby>です。",
                translation="我每天吃麵包。然後喝咖啡。早餐非常重要。",
                grammar_points={"grammars": [{"expression": "〜ます", "meaning": "動詞肯定形，表示習慣或未來的動作。", "example": "パンを食べます。"}], "vocabularies": [{"word": "毎日", "reading": "まいにち", "meaning": "每天"}, {"word": "大切", "reading": "たいせつ", "meaning": "重要"}]}),
            Article(id=102, theme="日本文化", level="N5", title="日本のお正月",
                content="<ruby>日本<rt>にほん</rt></ruby>の<ruby>正月<rt>しょうがつ</rt></ruby>は一月一日です。<ruby>家族<rt>かぞく</rt></ruby>といっしょに<ruby>神社<rt>じんじゃ</rt></ruby>へ<ruby>行<rt>い</rt></ruby>きます。<ruby>新<rt>あたら</rt></ruby>しい<ruby>年<rt>とし</rt></ruby>を<ruby>祝<rt>いわ</rt></ruby>います。",
                translation="日本的新年是一月一日。會和家人一起去神社。慶祝新的一年。",
                grammar_points={"grammars": [{"expression": "〜へ行きます", "meaning": "往某個方向/地點去。", "example": "神社へ行きます。"}], "vocabularies": [{"word": "家族", "reading": "かぞく", "meaning": "家人"}, {"word": "正月", "reading": "しょうがつ", "meaning": "新年"}]}),
            Article(id=103, theme="旅遊觀光", level="N5", title="電車で東京へ",
                content="<ruby>明日<rt>あした</rt></ruby>、<ruby>友達<rt>ともだち</rt></ruby>と<ruby>東京<rt>とうきょう</rt></ruby>へ<ruby>行<rt>い</rt></ruby>きます。<ruby>電車<rt>でんしゃ</rt></ruby>で<ruby>行<rt>い</rt></ruby>きます。<ruby>写真<rt>しゃしん</rt></ruby>をたくさん<ruby>撮<rt>と</rt></ruby>ります。",
                translation="明天，我要和朋友去東京。搭電車去。會拍很多照片。",
                grammar_points={"grammars": [{"expression": "〜で（交通工具）", "meaning": "表示使用的交通工具。", "example": "電車で行きます。"}], "vocabularies": [{"word": "電車", "reading": "でんしゃ", "meaning": "電車"}, {"word": "写真", "reading": "しゃしん", "meaning": "照片"}]}),
            Article(id=104, theme="職場應用", level="N5", title="会社での挨拶",
                content="<ruby>会社<rt>かいしゃ</rt></ruby>の<ruby>人<rt>ひと</rt></ruby>に<ruby>会<rt>あ</rt></ruby>いました。「おはようございます」と<ruby>言<rt>い</rt></ruby>います。<ruby>挨拶<rt>あいさつ</rt></ruby>は<ruby>基本<rt>きほん</rt></ruby>です。",
                translation="遇見了公司的人。說「早安」。問候是基本的。",
                grammar_points={"grammars": [{"expression": "〜に会います", "meaning": "與某人見面。", "example": "会社の人に会います。"}], "vocabularies": [{"word": "会社", "reading": "かいしゃ", "meaning": "公司"}, {"word": "挨拶", "reading": "あいさつ", "meaning": "問候"}]}),
            Article(id=105, theme="流行動漫", level="N5", title="アニメが好きです",
                content="わたしは<ruby>日本<rt>にほん</rt></ruby>のアニメが<ruby>好<rt>す</rt></ruby>きです。<ruby>週末<rt>しゅうまつ</rt></ruby>に<ruby>家<rt>いえ</rt></ruby>でアニメを<ruby>見<rt>み</rt></ruby>ます。とても<ruby>面白<rt>おもしろ</rt></ruby>いです。",
                translation="我喜歡日本的動漫。週末在家看動漫。非常有趣。",
                grammar_points={"grammars": [{"expression": "〜が好きです", "meaning": "喜歡某事物。", "example": "アニメが好きです。"}], "vocabularies": [{"word": "週末", "reading": "しゅうまつ", "meaning": "週末"}, {"word": "面白い", "reading": "おもしろい", "meaning": "有趣的"}]}),
            # N5 待解鎖
            Article(id=106, theme="日本美食", level="N5", title="美味しいお寿司",
                content="お<ruby>寿司<rt>すし</rt></ruby>は<ruby>日本<rt>にほん</rt></ruby>の<ruby>有名<rt>ゆうめい</rt></ruby>な<ruby>食<rt>た</rt></ruby>べ<ruby>物<rt>もの</rt></ruby>です。<ruby>魚<rt>さかな</rt></ruby>とご<ruby>飯<rt>はん</rt></ruby>で<ruby>作<rt>つく</rt></ruby>ります。とても<ruby>美味<rt>おい</rt></ruby>しいです。",
                translation="壽司是日本有名的食物。用魚和飯製作。非常美味。",
                grammar_points={"grammars": [{"expression": "〜で作ります", "meaning": "用某材料製作。", "example": "魚とご飯で作ります。"}], "vocabularies": [{"word": "寿司", "reading": "すし", "meaning": "壽司"}, {"word": "魚", "reading": "さかな", "meaning": "魚"}]}),
            Article(id=107, theme="台灣文化", level="N5", title="タピオカミルクティー",
                content="<ruby>台湾<rt>たいわん</rt></ruby>のタピオカミルクティーは<ruby>甘<rt>あま</rt></ruby>くて<ruby>美味<rt>おい</rt></ruby>しいです。<ruby>日本<rt>にほん</rt></ruby>でもとても<ruby>人気<rt>にんき</rt></ruby>があります。",
                translation="台灣的珍珠奶茶又甜又好喝。在日本也非常受歡迎。",
                grammar_points={"grammars": [{"expression": "〜くて", "meaning": "い形容詞的連接形。", "example": "甘くて美味しいです。"}], "vocabularies": [{"word": "甘い", "reading": "あまい", "meaning": "甜的"}, {"word": "人気", "reading": "にんき", "meaning": "受歡迎"}]}),
            Article(id=108, theme="日本傳說", level="N5", title="桃太郎の話",
                content="<ruby>昔<rt>むかし</rt></ruby>、おじいさんとおばあさんがいました。ある<ruby>日<rt>ひ</rt></ruby>、<ruby>大<rt>おお</rt></ruby>きな<ruby>桃<rt>もも</rt></ruby>が<ruby>川<rt>かわ</rt></ruby>から<ruby>流<rt>なが</rt></ruby>れてきました。",
                translation="從前，有一對老爺爺和老奶奶。有一天，一顆大桃子從河裡流了過來。",
                grammar_points={"grammars": [{"expression": "〜がいます", "meaning": "有/存在（用於人或動物）。", "example": "おじいさんがいました。"}], "vocabularies": [{"word": "昔", "reading": "むかし", "meaning": "從前"}, {"word": "川", "reading": "かわ", "meaning": "河川"}]}),


            # ==========================================
            # 【 N4 級別 】 (ID: 201 ~ 208)
            # ==========================================
            Article(id=201, theme="日常生活", level="N4", title="ゴミの捨て方",
                content="<ruby>日本<rt>にほん</rt></ruby>では、ゴミを<ruby>捨<rt>す</rt></ruby>てる<ruby>時<rt>とき</rt></ruby>、ルールを<ruby>守<rt>まも</rt></ruby>らなければなりません。<ruby>燃<rt>も</rt></ruby>えるゴミの<ruby>日<rt>ひ</rt></ruby>は<ruby>決<rt>き</rt></ruby>まっています。",
                translation="在日本丟垃圾時，必須遵守規則。可燃垃圾的日子是規定好的。",
                grammar_points={"grammars": [{"expression": "〜なければなりません", "meaning": "必須...", "example": "ルールを守らなければなりません。"}], "vocabularies": [{"word": "捨てる", "reading": "すてる", "meaning": "丟棄"}, {"word": "守る", "reading": "まもる", "meaning": "遵守"}]}),
            Article(id=202, theme="日本文化", level="N4", title="神社でのお願い",
                content="<ruby>神社<rt>じんじゃ</rt></ruby>へ<ruby>行<rt>い</rt></ruby>ったことがありますか。<ruby>手<rt>て</rt></ruby>を<ruby>洗<rt>あら</rt></ruby>ってから、<ruby>神様<rt>かみさま</rt></ruby>にお<ruby>願<rt>ねが</rt></ruby>いをします。",
                translation="你去過神社嗎？洗手之後，向神明許願。",
                grammar_points={"grammars": [{"expression": "〜たことがあります", "meaning": "有做過...的經驗", "example": "神社へ行ったことがあります。"}], "vocabularies": [{"word": "神様", "reading": "かみさま", "meaning": "神明"}, {"word": "お願い", "reading": "おねがい", "meaning": "願望/請求"}]}),
            Article(id=203, theme="旅遊觀光", level="N4", title="京都の旅館",
                content="<ruby>来週<rt>らいしゅう</rt></ruby>、<ruby>京都<rt>きょうと</rt></ruby>の<ruby>旅館<rt>りょかん</rt></ruby>に<ruby>泊<rt>と</rt></ruby>まるつもりです。<ruby>温泉<rt>おんせん</rt></ruby>に<ruby>入<rt>はい</rt></ruby>ったり、<ruby>日本料理<rt>にほんりょうり</rt></ruby>を<ruby>食<rt>た</rt></ruby>べたりしたいです。",
                translation="下週，我打算住在京都的旅館。想要泡溫泉、吃日本料理。",
                grammar_points={"grammars": [{"expression": "〜つもりです", "meaning": "打算...", "example": "旅館に泊まるつもりです。"}], "vocabularies": [{"word": "旅館", "reading": "りょかん", "meaning": "傳統旅館"}, {"word": "泊まる", "reading": "とまる", "meaning": "住宿"}]}),
            Article(id=204, theme="職場應用", level="N4", title="会議の準備",
                content="<ruby>会議<rt>かいぎ</rt></ruby>が<ruby>始<rt>はじ</rt></ruby>まる<ruby>前<rt>まえ</rt></ruby>に、<ruby>資料<rt>しりょう</rt></ruby>をコピーしておきます。<ruby>先輩<rt>せんぱい</rt></ruby>に<ruby>手伝<rt>てつだ</rt></ruby>ってもらいました。",
                translation="會議開始前，我會事先把資料印好。我請前輩幫忙了。",
                grammar_points={"grammars": [{"expression": "〜ておきます", "meaning": "事先做好準備", "example": "資料をコピーしておきます。"}], "vocabularies": [{"word": "資料", "reading": "しりょう", "meaning": "資料"}, {"word": "手伝う", "reading": "てつだう", "meaning": "幫忙"}]}),
            Article(id=205, theme="流行動漫", level="N4", title="好きなキャラクター",
                content="このアニメのキャラクターは、<ruby>強<rt>つよ</rt></ruby>くてかっこいいので、みんなに<ruby>愛<rt>あい</rt></ruby>されています。<ruby>グッズ<rt>ぐっず</rt></ruby>もたくさん<ruby>売<rt>う</rt></ruby>れています。",
                translation="這個動漫的角色因為既強大又帥氣，所以受到大家喜愛。周邊商品也賣得很好。",
                grammar_points={"grammars": [{"expression": "〜れる／られる", "meaning": "被動態", "example": "みんなに愛されています。"}], "vocabularies": [{"word": "強い", "reading": "つよい", "meaning": "強大的"}, {"word": "売れる", "reading": "うれる", "meaning": "暢銷"}]}),
            # N4 待解鎖
            Article(id=206, theme="日本美食", level="N4", title="ラーメンの食べ方",
                content="<ruby>日本<rt>にほん</rt></ruby>でラーメンを<ruby>食<rt>た</rt></ruby>べる<ruby>時<rt>とき</rt></ruby>、<ruby>音<rt>おと</rt></ruby>を<ruby>立<rt>た</rt></ruby>ててもいいです。それは「<ruby>美味<rt>おい</rt></ruby>しい」という<ruby>意味<rt>いみ</rt></ruby>になるからです。",
                translation="在日本吃拉麵時，發出聲音是可以的。因為那代表著「好吃」的意思。",
                grammar_points={"grammars": [{"expression": "〜てもいいです", "meaning": "表示許可（可以...）", "example": "音を立ててもいいです。"}], "vocabularies": [{"word": "音", "reading": "おと", "meaning": "聲音"}, {"word": "意味", "reading": "いみ", "meaning": "意思"}]}),
            Article(id=207, theme="台灣文化", level="N4", title="台湾の夜市へ行ったこと",
                content="<ruby>私<rt>わたし</rt></ruby>は<ruby>台湾<rt>たいわん</rt></ruby>へ<ruby>行<rt>い</rt></ruby>ったとき、<ruby>夜市<rt>よいち</rt></ruby>で<ruby>臭豆腐<rt>しゅうどうふ</rt></ruby>を<ruby>食<rt>た</rt></ruby>べさせられました。<ruby>臭<rt>くさ</rt></ruby>いですが、<ruby>味<rt>あじ</rt></ruby>はよかったです。",
                translation="我去台灣的時候，在夜市被請吃了臭豆腐。雖然臭，但味道很好。",
                grammar_points={"grammars": [{"expression": "〜させられる", "meaning": "使役被動態（被要求做某事）", "example": "食べさせられました。"}], "vocabularies": [{"word": "臭い", "reading": "くさい", "meaning": "臭的"}, {"word": "味", "reading": "あじ", "meaning": "味道"}]}),
            Article(id=208, theme="日本傳說", level="N4", title="鶴の恩返し",
                content="<ruby>若者<rt>わかもの</rt></ruby>が<ruby>助<rt>たす</rt></ruby>けた<ruby>鶴<rt>つる</rt></ruby>は、<ruby>美<rt>うつく</rt></ruby>しい<ruby>女<rt>おんな</rt></ruby>の<ruby>人<rt>ひと</rt></ruby>になって<ruby>恩返<rt>おんがえ</rt></ruby>しに<ruby>来<rt>き</rt></ruby>ました。<ruby>絶対<rt>ぜったい</rt></ruby>に<ruby>部屋<rt>へや</rt></ruby>を<ruby>見<rt>み</rt></ruby>ないでくださいと<ruby>言<rt>い</rt></ruby>いました。",
                translation="年輕人救下的鶴，變成了一位美麗的女子來報恩。她說請絕對不要看房間裡面。",
                grammar_points={"grammars": [{"expression": "〜ないでください", "meaning": "請不要...", "example": "部屋を見ないでください。"}], "vocabularies": [{"word": "恩返し", "reading": "おんがえし", "meaning": "報恩"}, {"word": "絶対", "reading": "ぜったい", "meaning": "絕對"}]}),


            # ==========================================
            # 【 N3 級別 】 (ID: 301 ~ 308) - 完全保留你原有的 8 篇文章
            # ==========================================
            Article(id=301, theme="日常生活", level="N3", title="毎日のゴミ出しと環境問題",
                content="<ruby>日本<rt>にほん</rt></ruby>では、<ruby>毎<rt>まい</rt></ruby><ruby>日<rt>にち</rt></ruby>のゴミの<ruby>分別<rt>ぶんべつ</rt></ruby>がとても<ruby>厳<rt>きび</rt></ruby>しく<ruby>決<rt>き</rt></ruby>められています。<ruby>燃<rt>も</rt></ruby>えるゴミ、<ruby>燃<rt>も</rt></ruby>えないゴミ、そしてペットボトルなどに<ruby>分<rt>わ</rt></ruby>けなければなりません。<ruby>手帳<rt>てちょう</rt></ruby>には、ゴミの<ruby>収集日<rt>しゅうしゅうび</rt></ruby>が<ruby>詳<rt>くわ</rt></ruby>しく<ruby>書<rt>か</rt></ruby>いてあります。<ruby>綺麗<rt>きれい</rt></ruby>で<ruby>住<rt>す</rt></ruby>みやすい<ruby>街<rt>まち</rt></ruby>を<ruby>守<rt>まも</rt></ruby>るために、みんなルールを<ruby>守<rt>まも</rt></ruby>っています。",
                translation="在日本，每天的垃圾分類被規定得非常嚴格。必須分成可燃垃圾、不可燃垃圾以及寶特瓶等。手冊上詳細地寫著垃圾收集的日子。為了守護乾淨且宜居的街道，大家都在遵守規則。",
                grammar_points={"grammars": [{"expression": "〜てあります", "meaning": "表示某人有目的做的動作，其結果狀態正留存著。", "example": "手帳に書いてあります"}], "vocabularies": [{"word": "分別", "reading": "ぶんべつ", "meaning": "分類"}, {"word": "収集日", "reading": "しゅうしゅうび", "meaning": "收集日"}]}),
            Article(id=302, theme="日本文化", level="N3", title="日本の伝統的なお祭り",
                content="<ruby>夏<rt>なつ</rt></ruby>になると、<ruby>日本<rt>にほん</rt></ruby>のあちこちでお<ruby>祭<rt>まつ</rt></ruby>りが<ruby>開<rt>ひら</rt></ruby>かれます。みんな<ruby>綺麗<rt>きれい</rt></ruby>な<ruby>浴衣<rt>ゆかた</rt></ruby>を<ruby>着<rt>き</rt></ruby>て<ruby>出<rt>で</rt></ruby>かけます。お<ruby>祭<rt>まつ</rt></ruby>りのために、<ruby>何<rt>なん</rt></ruby>ヶ月も<ruby>前<rt>まえ</rt></ruby>から<ruby>踊<rt>おど</rt></ruby>りの<ruby>練習<rt>れんしゅう</rt></ruby>をしておきます。<ruby>屋台<rt>やたい</rt></ruby>で<ruby>美味<rt>おい</rt></ruby>しいものを<ruby>食<rt>た</rt></ruby>べたり、<ruby>花火<rt>はなび</rt></ruby>を<ruby>見<rt>み</rt></ruby>たりするのは、<ruby>日本<rt>にほん</rt></ruby>の<ruby>夏<rt>なつ</rt></ruby>の<ruby>素晴<rt>すば</rt></ruby>らしい<ruby>思<rt>おも</rt></ruby>い<ruby>出<rt>で</rt></ruby>になります。",
                translation="一到夏天，日本各處都會舉辦祭典。大家都會穿上漂亮的浴衣出門。為了祭典，從幾個月前就會預先做好舞蹈的練習。在攤位吃美食、看煙火，會成為日本夏天極棒的回憶。",
                grammar_points={"grammars": [{"expression": "〜ておきます", "meaning": "表示為了某個特定目的，提前、預先做好某個準備動作。", "example": "練習をしておきます"}], "vocabularies": [{"word": "伝統的", "reading": "でんとうてき", "meaning": "傳統的"}, {"word": "屋台", "reading": "やたい", "meaning": "路邊攤/攤位"}]}),
            Article(id=303, theme="旅遊觀光", level="N3", title="京都の古いお寺を巡る旅",
                content="<ruby>京都<rt>きょうと</rt></ruby>には<ruby>古<rt>ふる</rt></ruby>いお<ruby>寺<rt>てら</rt></ruby>や<ruby>神社<rt>じんじゃ</rt></ruby>がたくさん<ruby>残<rt>のこ</rt></ruby>っています。<ruby>秋<rt>あき</rt></ruby>になると、<ruby>紅葉<rt>こうよう</rt></ruby>の<ruby>景色<rt>けしき</rt></ruby>が<ruby>本当<rt>ほんとう</rt></ruby>に<ruby>綺麗<rt>きれい</rt></ruby>です。<ruby>有名<rt>ゆうめい</rt></ruby>な<ruby>観光地<rt>かんこうち</rt></ruby>は<ruby>人<rt>ひと</rt></ruby>が<ruby>多<rt>おお</rt></ruby>いので、<ruby>朝<rt>あさ</rt></ruby><ruby>早<rt>はや</rt></ruby>く<ruby>出発<rt>しゅっぱつ</rt></ruby>するようにしています。<ruby>事前<rt>じぜん</rt></ruby>にチケットを<ruby>買<rt>か</rt></ruby>っておいたので、<ruby>並<rt>なら</rt></ruby>ばずに<ruby>中<rt>なか</rt></ruby>に<ruby>入<rt>はい</rt></ruby>ることができました。",
                translation="京都留存著許多古老寺廟和神社。一到秋天，紅葉的景色真的很美。因為著名的觀光地人很多，我都會注意儘量提早出發。因為事先買好了票，所以不用排隊就能進到裡面。",
                grammar_points={"grammars": [{"expression": "〜ようにしています", "meaning": "表示習慣性地努力做到某事，或持續保持某種作法。", "example": "出発するようにしています"}], "vocabularies": [{"word": "巡る", "reading": "めぐる", "meaning": "環繞/巡訪"}, {"word": "事前", "reading": "じぜん", "meaning": "事先"}]}),
            Article(id=304, theme="職場應用", level="N3", title="日本の会社での挨拶とマナー",
                content="<ruby>日本<rt>にほん</rt></ruby>のビジネス<ruby>社会<rt>しゃかい</rt></ruby>では、<ruby>挨拶<rt>あいさつ</rt></ruby>が<ruby>何<rt>なに</rt></ruby>より<ruby>重視<rt>じゅうし</rt></ruby>されています。<ruby>毎朝<rt>まいあさ</rt></ruby>、<ruby>会社<rt>かいしゃ</rt></ruby>に<ruby>入<rt>はい</rt></ruby>るときは<ruby>大<rt>おお</rt></ruby>きな<ruby>声<rt>こえ</rt></ruby>で「おはようございます」と<ruby>言<rt>い</rt></ruby>わなければなりません。また、<ruby>会議<rt>かいぎ</rt></ruby>の<ruby>資料<rt>しりょう</rt></ruby>は、<ruby>上司<rt>じょうし</rt></ruby>に<ruby>言<rt>い</rt></ruby>われる<ruby>前<rt>まえ</rt></ruby>に<ruby>準備<rt>じゅんび</rt></ruby>しておくことが<ruby>社会人<rt>しゃかいじん</rt></ruby>の<ruby>基本的<rt>きほんてき</rt></ruby>なマナーです。",
                translation="在日本的商業社會中，問候比什麼都受到重視。每天早晨進入公司時，必須大聲說「早安」。此外，在被上司開口要求之前就先將會議資料準備好，是社會人的基本禮儀。",
                grammar_points={"grammars": [{"expression": "〜言われる", "meaning": "被動動詞。表示受到來自他人的某種動作或言論。", "example": "上司に言われる"}], "vocabularies": [{"word": "重視", "reading": "じゅうし", "meaning": "重視"}, {"word": "基本的", "reading": "きほんてき", "meaning": "基本的"}]}),
            Article(id=305, theme="流行動漫", level="N3", title="世界中で愛される日本のアニメ",
                content="<ruby>日本<rt>にほん</rt></ruby>のアニメは、<ruby>子供<rt>こども</rt></ruby>だけでなく<ruby>大人<rt>おとな</rt></ruby>にも<ruby>大人気<rt>だいにんき</rt></ruby>です。<ruby>最近<rt>さいきん</rt></ruby>の<ruby>映画<rt>えいが</rt></ruby>は、<ruby>素晴<rt>すば</rt></ruby>らしい<ruby>映像<rt>えいぞう</rt></ruby><ruby>技術<rt>ぎじゅつ</rt></ruby>が<ruby>使<rt>つか</rt></ruby>われています。<ruby>最新作<rt>さいしんさく</rt></ruby>の<ruby>公開<rt>こうかい</rt></ruby>スケジュールが<ruby>公式<rt>こうしき</rt></ruby>サイトに<ruby>発表<rt>はっぴょう</rt></ruby>してあるので、ファンはみんな<ruby>楽<rt>たの</rt></ruby>しみにチェックしています。",
                translation="日本的動漫不僅受到小孩子，在大人之間也享有人氣。最近的電影中，使用了極佳的影像技術。因為最新作品的上映日程已經公布在官方網站上，粉絲們都滿懷期待地在確認。",
                grammar_points={"grammars": [{"expression": "〜だけでなく", "meaning": "表示不僅僅是前項，也包含後項。", "example": "子供だけでなく"}], "vocabularies": [{"word": "映像", "reading": "えいぞう", "meaning": "影像/畫面"}, {"word": "公開", "reading": "こうかい", "meaning": "公開/上映"}]}),
            # N3 待解鎖
            Article(id=306, theme="日本美食", level="N3", title="日本の屋台文化と隠された魅力",
                content="<ruby>日本<rt>にほん</rt></ruby>のお<ruby>祭<rt>まつ</rt></ruby>りに<ruby>行<rt>い</rt></ruby>くと、たくさんの<ruby>屋台<rt>やたい</rt></ruby>が<ruby>並<rt>なら</rt></ruby>んでいます。たこ<ruby>焼<rt>や</rt></ruby>きやりんご<ruby>飴<rt>あめ</rt></ruby>だけでなく、<ruby>最近<rt>さいきん</rt></ruby>ではさまざまな<ruby>国<rt>くに</rt></ruby>の<ruby>料理<rt>りょうり</rt></ruby>も<ruby>見<rt>み</rt></ruby>かけるようになりました。<ruby>屋台<rt>やたい</rt></ruby>の<ruby>楽<rt>たの</rt></ruby>しさは、ただ<ruby>食<rt>た</rt></ruby>べるだけでなく、その<ruby>活気<rt>かっき</rt></ruby>ある<ruby>雰囲気<rt>ふんいき</rt></ruby>を<ruby>体感<rt>たいかん</rt></ruby>できるところにあります。",
                translation="去日本的祭典時，會看到許多排成一列的攤販。除了章魚燒跟糖蘋果之外，最近也能看到各種國家的料理。攤販的樂趣不僅僅在於吃東西，更在於能親身體驗那充滿活力的氛圍。",
                grammar_points={"grammars": [{"expression": "~だけでなく", "meaning": "不僅…而且…", "example": "たこ焼きだけでなく、色々な料理がある。"}], "vocabularies": [{"word": "屋台", "reading": "やたい", "meaning": "攤販、路邊攤"}, {"word": "魅力", "reading": "みりょく", "meaning": "魅力"}, {"word": "雰囲気", "reading": "ふんいき", "meaning": "氣氛"}, {"word": "活気", "reading": "かっき", "meaning": "活力、熱鬧"}]}),
            Article(id=307, theme="台灣文化", level="N3", title="台湾の夜市：食べて歩く文化の中心",
                content="<ruby>台湾<rt>たいわん</rt></ruby>の<ruby>夜市<rt>よいち</rt></ruby>は、<ruby>地元<rt>じもと</rt></ruby>の<ruby>人々<rt>ひとびと</rt></ruby>だけでなく<ruby>観光客<rt>かんこうきゃく</rt></ruby>にとっても<ruby>大人気<rt>だいにんき</rt></ruby>の<ruby>場所<rt>ばしょ</rt></ruby>です。<ruby>夜遅<rt>よるおそ</rt></ruby>くまで<ruby>多<rt>おお</rt></ruby>くの<ruby>人<rt>ひと</rt></ruby>が<ruby>集<rt>あつ</rt></ruby>まり、<ruby>様々<rt>さまざま</rt></ruby>なグルメを<ruby>味わう<rt>あじわう</rt></ruby>ことができます。<ruby>魯肉飯<rt>ろーふぁん</rt></ruby>や<ruby>小籠包<rt>しょうろんぽう</rt></ruby>など、<ruby>台湾<rt>たいわん</rt></ruby>の<ruby>美味<rt>おい</rt></ruby>しいものを<ruby>一度<rt>いちど</rt></ruby>に<ruby>楽<rt>たの</rt></ruby>しむことができるのが<ruby>大<rt>おお</rt></ruby>きな<ruby>特徴<rt>とくちょう</rt></ruby>です。",
                translation="台灣的夜市不只是當地人的最愛，對觀光客來說也是超人氣的場所。直到深夜都有許多人聚集，可以品嚐各種美食。魯肉飯和小籠包等，能一次享受台灣美味的食物是其最大特色。",
                grammar_points={"grammars": [{"expression": "~だけでなく", "meaning": "不僅…而且…", "example": "地元の人々だけでなく観光客にも人気がある。"}], "vocabularies": [{"word": "夜市", "reading": "よいち", "meaning": "夜市"}, {"word": "観光客", "reading": "かんこうきゃく", "meaning": "觀光客"}, {"word": "味わう", "reading": "あじわう", "meaning": "品嚐"}, {"word": "特徴", "reading": "とくちょう", "meaning": "特色"}]}),
            Article(id=308, theme="日本傳說", level="N3", title="京都に伝わる妖怪の物語",
                content="<ruby>京都<rt>きょうと</rt></ruby>には、<ruby>昔<rt>むかし</rt></ruby>から<ruby>様々<rt>さまざま</rt></ruby>な<ruby>妖怪<rt>ようかい</rt></ruby>の<ruby>伝説<rt>でんせつ</rt></ruby>が<ruby>残<rt>のこ</rt></ruby>っています。<ruby>夜<rt>よる</rt></ruby>になると、<ruby>古<rt>ふる</rt></ruby>い<ruby>道具<rt>どうぐ</rt></ruby>が<ruby>妖怪<rt>ようかい</rt></ruby>に<ruby>変<rt>か</rt></ruby>わるという「<ruby>付喪神<rt>つくもがみ</rt></ruby>」の<ruby>話<rt>はなし</rt></ruby>は<ruby>特<rt>とく</rt></ruby>に<ruby>有名<rt>ゆうめい</rt></ruby>です。<ruby>昔<rt>むかし</rt></ruby>の<ruby>人<rt>ひと</rt></ruby>は、<ruby>物<rt>もの</rt></ruby>を<ruby>大切<rt>たいせつ</rt></ruby>にする<ruby>心<rt>こころ</rt></ruby>をこのような<ruby>物語<rt>ものがたり</rt></ruby>を<ruby>通<rt>つう</rt></ruby>じて<ruby>伝<rt>つた</rt></ruby>えてきました。",
                translation="京都自古以來就流傳著各種妖怪的傳說。到了夜晚，舊工具會變成妖怪的『付喪神』故事特別有名。古人透過這樣的故事，傳達了珍惜物品的心意。",
                grammar_points={"grammars": [{"expression": "~を通じて", "meaning": "透過、藉由", "example": "物語を通じて大切なことを学ぶ。"}], "vocabularies": [{"word": "妖怪", "reading": "ようかい", "meaning": "妖怪"}, {"word": "伝説", "reading": "でんせつ", "meaning": "傳說"}, {"word": "大切", "reading": "たいせつ", "meaning": "珍貴、重要"}, {"word": "付喪神", "reading": "つくもがみ", "meaning": "付喪神（器物放久後化成的妖怪）"}]}),


            # ==========================================
            # 【 N2 級別 】 (ID: 401 ~ 408)
            # ==========================================
            Article(id=401, theme="日常生活", level="N2", title="エコバッグの普及",
                content="<ruby>環境保護<rt>かんきょうほご</rt></ruby>の<ruby>観点<rt>かんてん</rt></ruby>から、スーパーでのレジ<ruby>袋<rt>ぶくろ</rt></ruby>が<ruby>有料化<rt>ゆうりょうか</rt></ruby>されつつある。これに<ruby>伴<rt>ともな</rt></ruby>い、マイバッグを<ruby>持参<rt>じさん</rt></ruby>する<ruby>消費者<rt>しょうひしゃ</rt></ruby>が<ruby>増<rt>ふ</rt></ruby>えた。",
                translation="從環境保護的觀點來看，超市的塑膠袋正逐漸走向收費化。伴隨著這一點，自備購物袋的消費者增加了。",
                grammar_points={"grammars": [{"expression": "〜つつある", "meaning": "正在不斷...、逐漸...", "example": "有料化されつつある。"}], "vocabularies": [{"word": "観点", "reading": "かんてん", "meaning": "觀點"}, {"word": "持参", "reading": "じさん", "meaning": "自備、攜帶"}]}),
            Article(id=402, theme="日本文化", level="N2", title="茶道の精神",
                content="<ruby>茶道<rt>さどう</rt></ruby>には「<ruby>一期一会<rt>いちごいちえ</rt></ruby>」という<ruby>言葉<rt>ことば</rt></ruby>がある。この<ruby>出会<rt>であ</rt></ruby>いは<ruby>二度<rt>にど</rt></ruby>とないかもしれないという<ruby>思<rt>おも</rt></ruby>いのもと、<ruby>誠意<rt>せいい</rt></ruby>を<ruby>尽<rt>つ</rt></ruby>くすことが<ruby>求<rt>もと</rt></ruby>められる。",
                translation="茶道中有一句名言叫做「一期一會」。基於這種相遇可能不會有第二次的想法，被要求必須竭盡誠意。",
                grammar_points={"grammars": [{"expression": "〜のもと", "meaning": "在...的基礎上、在...之下", "example": "思いのもと、誠意を尽くす。"}], "vocabularies": [{"word": "誠意", "reading": "せいい", "meaning": "誠意"}, {"word": "尽くす", "reading": "つくす", "meaning": "竭盡"}]}),
            Article(id=403, theme="旅遊觀光", level="N2", title="温泉旅館のおもてなし",
                content="<ruby>日本<rt>にほん</rt></ruby>の<ruby>旅館<rt>りょかん</rt></ruby>に<ruby>宿泊<rt>しゅくはく</rt></ruby>する<ruby>際<rt>さい</rt></ruby>、きめ<ruby>細<rt>こま</rt></ruby>やかなおもてなしに<ruby>感動<rt>かんどう</rt></ruby>せざるを<ruby>得<rt>え</rt></ruby>ない。<ruby>料理<rt>りょうり</rt></ruby>だけでなく、<ruby>空間<rt>くうかん</rt></ruby>づくりも<ruby>見事<rt>みごと</rt></ruby>である。",
                translation="住宿在日本的傳統旅館時，不得不被其無微不至的款待所感動。不僅是料理，空間營造也非常出色。",
                grammar_points={"grammars": [{"expression": "〜せざるを得ない", "meaning": "不得不...", "example": "感動せざるを得ない。"}], "vocabularies": [{"word": "宿泊", "reading": "しゅくはく", "meaning": "住宿"}, {"word": "見事", "reading": "みごと", "meaning": "出色的"}]}),
            Article(id=404, theme="職場應用", level="N2", title="敬語の正しい使い方",
                content="ビジネスシーンにおいて、<ruby>敬語<rt>けいご</rt></ruby>の<ruby>誤用<rt>ごよう</rt></ruby>は<ruby>相手<rt>あいて</rt></ruby>に<ruby>不快感<rt>ふかいかん</rt></ruby>を<ruby>与<rt>あた</rt></ruby>えかねない。<ruby>尊敬語<rt>そんけいご</rt></ruby>と<ruby>謙譲語<rt>けんじょうご</rt></ruby>をしっかり<ruby>区別<rt>くべつ</rt></ruby>するべきだ。",
                translation="在商務場合中，誤用敬語可能會給對方帶來不快感。應該要好好區分尊敬語和謙讓語。",
                grammar_points={"grammars": [{"expression": "〜かねない", "meaning": "有可能...（多用於負面結果）", "example": "不快感を与えかねない。"}], "vocabularies": [{"word": "誤用", "reading": "ごよう", "meaning": "誤用"}, {"word": "区別", "reading": "くべつ", "meaning": "區分"}]}),
            Article(id=405, theme="流行動漫", level="N2", title="アニメツーリズム",
                content="アニメの<ruby>舞台<rt>ぶたい</rt></ruby>となった<ruby>場所<rt>ばしょ</rt></ruby>を<ruby>巡<rt>めぐ</rt></ruby>る「<ruby>聖地巡礼<rt>せいちじゅんれい</rt></ruby>」は、<ruby>地域<rt>ちいき</rt></ruby><ruby>活性化<rt>かっせいか</rt></ruby>の<ruby>役割<rt>やくわり</rt></ruby>を<ruby>果<rt>は</rt></ruby>たしている。",
                translation="巡訪作為動漫舞台的地方的「聖地巡禮」，發揮了活化地區的作用。",
                grammar_points={"grammars": [{"expression": "〜を果たす", "meaning": "完成、發揮（作用等）", "example": "役割を果たしている。"}], "vocabularies": [{"word": "舞台", "reading": "ぶたい", "meaning": "舞台/背景"}, {"word": "活性化", "reading": "かっせいか", "meaning": "活化"}]}),
            # N2 待解鎖
            Article(id=406, theme="日本美食", level="N2", title="精進料理の奥深さ",
                content="<ruby>肉<rt>にく</rt></ruby>や<ruby>魚<rt>さかな</rt></ruby>を<ruby>一切<rt>いっさい</rt></ruby><ruby>使<rt>つか</rt></ruby>わない<ruby>精進料理<rt>しょうじんりょうり</rt></ruby>は、<ruby>野菜<rt>やさい</rt></ruby>の<ruby>味<rt>あじ</rt></ruby>を<ruby>引<rt>ひ</rt></ruby>き<ruby>出<rt>だ</rt></ruby>す<ruby>工夫<rt>くふう</rt></ruby>がなされている。これは<ruby>仏教<rt>ぶっきょう</rt></ruby>の<ruby>教<rt>おし</rt></ruby>えにほかならない。",
                translation="完全不使用肉或魚的精進料理（素齋），下足了引出蔬菜味道的工夫。這無非就是佛教的教義。",
                grammar_points={"grammars": [{"expression": "〜にほかならない", "meaning": "無非是...、正是...", "example": "仏教の教えにほかならない。"}], "vocabularies": [{"word": "一切", "reading": "いっさい", "meaning": "完全不（搭配否定）"}, {"word": "工夫", "reading": "くふう", "meaning": "巧思、下工夫"}]}),
            Article(id=407, theme="台灣文化", level="N2", title="台湾の茶文化",
                content="<ruby>台湾茶<rt>たいわんちゃ</rt></ruby>の<ruby>魅力<rt>みりょく</rt></ruby>は、その<ruby>豊<rt>ゆた</rt></ruby>かな<ruby>香<rt>かお</rt></ruby>りにある。<ruby>茶器<rt>ちゃき</rt></ruby>を<ruby>温<rt>あたた</rt></ruby>めることから<ruby>始<rt>はじ</rt></ruby>まる<ruby>作法<rt>さほう</rt></ruby>には、<ruby>美学<rt>びがく</rt></ruby>が<ruby>感<rt>かん</rt></ruby>じられる。",
                translation="台灣茶的魅力在於其豐富的香氣。從溫熱茶具開始的禮儀中，能讓人感受到美學。",
                grammar_points={"grammars": [{"expression": "〜ことから", "meaning": "因為...的原因/從...開始", "example": "茶器を温めることから始まる。"}], "vocabularies": [{"word": "香り", "reading": "かおり", "meaning": "香氣"}, {"word": "作法", "reading": "さほう", "meaning": "禮儀、作法"}]}),
            Article(id=408, theme="日本傳說", level="N2", title="妖怪と民間伝承",
                content="<ruby>妖怪<rt>ようかい</rt></ruby>は、<ruby>自然<rt>しぜん</rt></ruby>に<ruby>対<rt>たい</rt></ruby>する<ruby>畏怖<rt>いふ</rt></ruby>の<ruby>念<rt>ねん</rt></ruby>から<ruby>生<rt>う</rt></ruby>み<ruby>出<rt>だ</rt></ruby>されたものにすぎないという<ruby>説<rt>せつ</rt></ruby>がある。",
                translation="有一種說法認為，妖怪只不過是從對大自然的敬畏之心中所產生出來的東西罷了。",
                grammar_points={"grammars": [{"expression": "〜にすぎない", "meaning": "只不過是...", "example": "生み出されたものにすぎない。"}], "vocabularies": [{"word": "畏怖", "reading": "いふ", "meaning": "敬畏"}, {"word": "伝承", "reading": "でんしょう", "meaning": "傳承"}]}),


            # ==========================================
            # 【 N1 級別 】 (ID: 501 ~ 508)
            # ==========================================
            Article(id=501, theme="日常生活", level="N1", title="少子高齢化社会の課題",
                content="<ruby>日本<rt>にほん</rt></ruby>が<ruby>直面<rt>ちょくめん</rt></ruby>する<ruby>少子高齢化<rt>しょうしこうれいか</rt></ruby>は、<ruby>年金<rt>ねんきん</rt></ruby><ruby>制度<rt>せいど</rt></ruby>の<ruby>崩壊<rt>ほうかい</rt></ruby>を<ruby>招<rt>まね</rt></ruby>くおそれがある。<ruby>早急<rt>そうきゅう</rt></ruby>な<ruby>対策<rt>たいさく</rt></ruby>が<ruby>不可欠<rt>ふかけつ</rt></ruby>である。",
                translation="日本面臨的少子高齡化，恐有招致年金制度崩潰之虞。當務之急的對策是不可或缺的。",
                grammar_points={"grammars": [{"expression": "〜おそれがある", "meaning": "恐怕會...、有...的危險", "example": "崩壊を招くおそれがある。"}], "vocabularies": [{"word": "直面", "reading": "ちょくめん", "meaning": "面臨"}, {"word": "不可欠", "reading": "ふかけつ", "meaning": "不可或缺"}]}),
            Article(id=502, theme="日本文化", level="N1", title="侘び寂びの美学",
                content="「わび・さび」とは、<ruby>不完全<rt>ふかんぜん</rt></ruby>なものの中に<ruby>美<rt>び</rt></ruby>を<ruby>見出<rt>みいだ</rt></ruby>す<ruby>日本<rt>にほん</rt></ruby><ruby>特有<rt>とくゆう</rt></ruby>の<ruby>価値観<rt>かちかん</rt></ruby>である。これは<ruby>禅<rt>ぜん</rt></ruby>の<ruby>思想<rt>しそう</rt></ruby>に<ruby>根<rt>ね</rt></ruby>ざしている。",
                translation="「侘寂」是在不完美的事物中發現美的日本特有價值觀。這是根植於禪宗思想的。",
                grammar_points={"grammars": [{"expression": "〜に根ざす", "meaning": "根植於...、起源於...", "example": "禅の思想に根ざしている。"}], "vocabularies": [{"word": "不完全", "reading": "ふかんぜん", "meaning": "不完美、不完全"}, {"word": "価値観", "reading": "かちかん", "meaning": "價值觀"}]}),
            Article(id=503, theme="旅遊觀光", level="N1", title="インバウンド需要の功罪",
                content="<ruby>外国人<rt>がいこくじん</rt></ruby><ruby>観光客<rt>かんこうきゃく</rt></ruby>の<ruby>増加<rt>ぞうか</rt></ruby>は<ruby>経済<rt>けいざい</rt></ruby>を<ruby>潤<rt>うるお</rt></ruby>す<ruby>一方<rt>いっぽう</rt></ruby>、オーバーツーリズムといった<ruby>深刻<rt>しんこく</rt></ruby>な<ruby>弊害<rt>へいがい</rt></ruby>ももたらしている。",
                translation="外國觀光客的增加一方面滋潤了經濟，另一方面也帶來了過度旅遊等嚴重的弊害。",
                grammar_points={"grammars": [{"expression": "〜一方", "meaning": "一方面...另一方面...", "example": "経済を潤す一方、弊害ももたらす。"}], "vocabularies": [{"word": "潤す", "reading": "うるおす", "meaning": "滋潤、使豐裕"}, {"word": "弊害", "reading": "へいがい", "meaning": "弊害、流弊"}]}),
            Article(id=504, theme="職場應用", level="N1", title="グローバル化と企業風土",
                content="<ruby>激<rt>はげ</rt></ruby>しい<ruby>国際<rt>こくさい</rt></ruby><ruby>競争<rt>きょうそう</rt></ruby>を<ruby>生<rt>い</rt></ruby>き<ruby>残<rt>のこ</rt></ruby>るには、<ruby>従来<rt>じゅうらい</rt></ruby>の<ruby>企業<rt>きぎょう</rt></ruby><ruby>風土<rt>ふうど</rt></ruby>を<ruby>一新<rt>いっしん</rt></ruby>しないことには、<ruby>成長<rt>せいちょう</rt></ruby>は<ruby>望<rt>のぞ</rt></ruby>めない。",
                translation="若要在激烈的國際競爭中生存下來，如果不徹底革新傳統的企業文化，就無法指望獲得成長。",
                grammar_points={"grammars": [{"expression": "〜ないことには", "meaning": "如果不...就無法...", "example": "一新しないことには、成長は望めない。"}], "vocabularies": [{"word": "競争", "reading": "きょうそう", "meaning": "競爭"}, {"word": "風土", "reading": "ふうど", "meaning": "風氣、文化"}]}),
            Article(id=505, theme="流行動漫", level="N1", title="サブカルチャーの経済効果",
                content="アニメなどのサブカルチャーは、もはや<ruby>一部<rt>いちぶ</rt></ruby>のマニアのものではなく、<ruby>日本<rt>にほん</rt></ruby><ruby>経済<rt>けいざい</rt></ruby>を<ruby>牽引<rt>けんいん</rt></ruby>する<ruby>立派<rt>りっぱ</rt></ruby>な<ruby>産業<rt>さんぎょう</rt></ruby>たる<ruby>地位<rt>ちい</rt></ruby>を<ruby>確立<rt>かくりつ</rt></ruby>した。",
                translation="動漫等次文化早已不僅是一部分狂熱分子的專利，而是確立了作為牽引日本經濟的出色產業地位。",
                grammar_points={"grammars": [{"expression": "〜たる", "meaning": "作為...的、具備...資格的", "example": "立派な産業たる地位を確立した。"}], "vocabularies": [{"word": "牽引", "reading": "けんいん", "meaning": "牽引、帶動"}, {"word": "確立", "reading": "かくりつ", "meaning": "確立"}]}),
            # N1 待解鎖
            Article(id=506, theme="日本美食", level="N1", title="和食の無形文化遺産登録",
                content="「<ruby>和食<rt>わしょく</rt></ruby>」がユネスコ<ruby>無形<rt>むけい</rt></ruby><ruby>文化<rt>ぶんか</rt></ruby><ruby>遺産<rt>いさん</rt></ruby>に<ruby>登録<rt>とうろく</rt></ruby>されたことは、<ruby>自然<rt>しぜん</rt></ruby>を<ruby>尊<rt>とうと</rt></ruby>ぶ<ruby>日本<rt>にほん</rt></ruby><ruby>人<rt>じん</rt></ruby>の<ruby>精神<rt>せいしん</rt></ruby>が<ruby>世界的<rt>せかいてき</rt></ruby>に<ruby>評価<rt>ひょうか</rt></ruby>されたことにほかならない。",
                translation="「和食」被登錄為聯合國教科文組織無形文化遺產一事，無非就是日本人尊崇大自然的精神在世界上獲得了評價。",
                grammar_points={"grammars": [{"expression": "〜にほかならない", "meaning": "正是...、無非是...", "example": "精神が評価されたことにほかならない。"}], "vocabularies": [{"word": "尊ぶ", "reading": "とうとぶ", "meaning": "尊崇、重視"}, {"word": "遺産", "reading": "いさん", "meaning": "遺產"}]}),
            Article(id=507, theme="台灣文化", level="N1", title="台湾における多文化共生",
                content="<ruby>歴史的<rt>れきしてき</rt></ruby>な<ruby>背景<rt>はいけい</rt></ruby>ゆえに、<ruby>台湾<rt>たいわん</rt></ruby>は<ruby>多様<rt>たよう</rt></ruby>な<ruby>文化<rt>ぶんか</rt></ruby>が<ruby>複雑<rt>ふくざつ</rt></ruby>に<ruby>絡<rt>から</rt></ruby>み<ruby>合<rt>あ</rt></ruby>う<ruby>社会<rt>しゃかい</rt></ruby>を<ruby>形成<rt>けいせい</rt></ruby>してきた。",
                translation="正因為歷史背景的緣故，台灣形成了一個多元文化錯綜複雜交織而成的社會。",
                grammar_points={"grammars": [{"expression": "〜ゆえに", "meaning": "正因為...、由於...", "example": "歴史的な背景ゆえに。"}], "vocabularies": [{"word": "背景", "reading": "はいけい", "meaning": "背景"}, {"word": "絡み合う", "reading": "からみあう", "meaning": "交織、糾纏"}]}),
            Article(id=508, theme="日本傳說", level="N1", title="記紀神話の成り立ち",
                content="『<ruby>古事記<rt>こじき</rt></ruby>』や『<ruby>日本書紀<rt>にほんしょき</rt></ruby>』に<ruby>描<rt>えが</rt></ruby>かれる<ruby>神話<rt>しんわ</rt></ruby>は、<ruby>単<rt>たん</rt></ruby>なる<ruby>物語<rt>ものがたり</rt></ruby>にとどまらず、<ruby>古代<rt>こだい</rt></ruby><ruby>国家<rt>こっか</rt></ruby>の<ruby>権力<rt>けんりょく</rt></ruby><ruby>構造<rt>こうぞう</rt></ruby>を<ruby>反映<rt>はんえい</rt></ruby>している。",
                translation="《古事記》與《日本書紀》中所描繪的神話，不僅僅停留在單純的故事層面，更反映了古代國家的權力結構。",
                grammar_points={"grammars": [{"expression": "〜にとどまらず", "meaning": "不僅限於...", "example": "単なる物語にとどまらず。"}], "vocabularies": [{"word": "反映", "reading": "はんえい", "meaning": "反映"}, {"word": "権力", "reading": "けんりょく", "meaning": "權力"}]}),
        ]

        db.session.add_all(all_articles)
        db.session.commit()
        print("🎉 N5~N1 各級別（含免費5篇、解鎖3篇）文章已全部成功寫入資料庫！")

if __name__ == '__main__':
    seed_articles()