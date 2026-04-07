from app import app
from utils.db import db
from datetime import date
from models import User, Scene, Vocab, Achievement, UserAbility, UserAchievement, UserScene, UserVocab, QuizQuestion
from werkzeug.security import generate_password_hash

def seed_data():
    with app.app_context():
        print("🧹 正在清理舊資料，準備重建世界...")
        db.drop_all()
        db.create_all()

        print("🌱 開始種植豪華版預設資料...")

        # ==========================================
        # 1. 建立系統預設場景 (Scene)
        # ==========================================
        scene1 = Scene(name='一蘭拉麵店', icon_name='ramen_dining')
        scene2 = Scene(name='新宿車站', icon_name='train')
        scene3 = Scene(name='淺草寺', icon_name='temple_buddhist')
        scene4 = Scene(name='秋葉原電器街', icon_name='videogame_asset')
        scene5 = Scene(name='星巴克咖啡', icon_name='local_cafe')
        db.session.add_all([scene1, scene2, scene3, scene4, scene5])
        db.session.commit() 

        # ==========================================
        # 2. 建立系統單字庫 (Vocab) - 支援適性化分級例句！
        # ==========================================
        vocabs = [
            Vocab(scene_id=scene1.id, word='ラーメン', kana='ラーメン', meaning='拉麵', 
                  sentence_basic='このラーメンは美味しいです。', 
                  sentence_inter='このラーメン屋は行列ができるほど有名だ。', 
                  sentence_upper_inter='この店のラーメンは、スープがなくなり次第終了となります。',
                  sentence_advanced='こだわりの豚骨を何時間も煮込んだ、至極のラーメンである。',
                  audio_filename='ramen.mp3'),
            
            Vocab(scene_id=scene1.id, word='替玉', kana='かえだま', meaning='加麵', 
                  sentence_basic='替玉をお願いします。', 
                  sentence_inter='スープが残っているので、替玉を注文した。',
                  sentence_upper_inter='ダイエット中にもかかわらず、誘惑に負けて替玉を頼んでしまった。',
                  sentence_advanced='博多ラーメンの醍醐味は、やはり替玉にあると言えるだろう。',
                  audio_filename='kaedama.mp3'),
            
            Vocab(scene_id=scene2.id, word='切符', kana='きっぷ', meaning='車票', 
                  sentence_basic='切符を買います。', 
                  sentence_inter='券売機で新幹線の切符を購入した。',
                  sentence_upper_inter='払い戻し期間を過ぎた切符は、無効になってしまうので注意が必要だ。',
                  sentence_advanced='電子マネーの普及により、紙の切符を手にする機会はめっきり減った。',
                  audio_filename='kippu.mp3'),
            
            Vocab(scene_id=scene2.id, word='改札口', kana='かいさつぐち', meaning='剪票口', 
                  sentence_basic='改札口はどこですか？', 
                  sentence_inter='改札口で友達と待ち合わせをしている。',
                  sentence_upper_inter='朝のラッシュ時の改札口は、前に進めないほど混雑している。',
                  sentence_advanced='最新の顔認証システムを備えた改札口が、一部の駅で導入され始めている。',
                  audio_filename='kaisatsuguchi.mp3'),
            
            Vocab(scene_id=scene3.id, word='お守り', kana='おまもり', meaning='御守', 
                  sentence_basic='お守りを買いました。', 
                  sentence_inter='神社で合格祈願のお守りを買った。',
                  sentence_upper_inter='祖母からもらったこのお守りは、私にとって何よりも大切なものだ。',
                  sentence_advanced='古来より、お守りには人々の切実な願いと祈りが込められている。',
                  audio_filename='omamori.mp3'),
            
            Vocab(scene_id=scene4.id, word='アニメ', kana='アニメ', meaning='動畫', 
                  sentence_basic='日本のアニメが好きです。', 
                  sentence_inter='休日は一日中アニメを見て過ごすことが多い。',
                  sentence_upper_inter='日本のアニメは国内のみならず、海外でも高く評価されている。',
                  sentence_advanced='精緻な作画と複雑な人間模様を描いたそのアニメは、社会現象を巻き起こした。',
                  audio_filename='anime.mp3'),
            
            Vocab(scene_id=scene5.id, word='コーヒー', kana='コーヒー', meaning='咖啡', 
                  sentence_basic='ホットコーヒーを一つください。', 
                  sentence_inter='毎朝、淹れたてのコーヒーを飲むのが日課だ。',
                  sentence_upper_inter='彼はコーヒーの豆の産地にまでこだわるほどのコーヒー好きだ。',
                  sentence_advanced='芳醇な香りと深いコクが特徴のこのコーヒーは、至福のひとときをもたらしてくれる。',
                  audio_filename='coffee.mp3')
        ]
        db.session.add_all(vocabs)

        # ==========================================
        # 3. 📝 建立程度判定測驗題庫 (全新擴充 30 題版)
        # ==========================================
        questions = [
            # --- 第一階段：超級新手 ---
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="「わたし」的漢字寫法是？", option_a="私", option_b="彼", option_c="君", option_d="僕", correct_answer="A"),
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="圖片中是「壽司」，請問它的日文平假名是？", option_a="さし", option_b="すし", option_c="せし", option_d="そし", correct_answer="B"),
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="「おはよう」的意思是？", option_a="謝謝", option_b="對不起", option_c="早安", option_d="再見", correct_answer="C"),
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="數字「5」的讀音是？", option_a="いち", option_b="さん", option_c="ご", option_d="なな", correct_answer="C"),
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="「パン（麵包）」的讀音是？", option_a="pan", option_b="pen", option_c="pin", option_d="pon", correct_answer="A"),
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="想要稱呼老師時，會用哪個平假名？", option_a="せいせい", option_b="せんせい", option_c="さんせい", option_d="しんせい", correct_answer="B"),
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="「水」的平假名寫法是？", option_a="みず", option_b="みち", option_c="みみ", option_d="みき", correct_answer="A"),
            
            # --- 第二階段：初級 (N5~N4) ---
            QuizQuestion(stage="第二階段：初級", level_tag="N5", question="あそこに白い（　）が止まっています。", option_a="くるま", option_b="かばん", option_c="つくえ", option_d="いす", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N4", question="この料理はとても（　）です。", option_a="しんせん", option_b="しんせつ", option_c="ていねい", option_d="にぎやか", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N5", question="毎日（　）で学校へ通っています。", option_a="でんしゃ (電車)", option_b="じかん (時間)", option_c="じしょ (辞書)", option_d="きょうしつ (教室)", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N5", question="心斎橋はとても（　）なところですね。", option_a="にぎやか", option_b="しずか", option_c="ひま", option_d="きれい", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N4", question="テストが終わって（　）しました。", option_a="安心 (あんしん)", option_b="注意 (ちゅうい)", option_c="準備 (じゅんび)", option_d="失敗 (しっぱい)", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N4", question="この地図はとても（　）やすいです。", option_a="見 (み)", option_b="書き (かき)", option_c="読み (よみ)", option_d="わかり", correct_answer="D"),
            QuizQuestion(stage="第二階段：初級", level_tag="N4", question="明日（　）があれば、買い物に行きましょう。", option_a="都合 (つごう)", option_b="具合 (ぐあい)", option_c="気分 (きぶん)", option_d="調子 (ちょうし)", correct_answer="A"),

            # --- 第三階段：中級 (N3) ---
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="台湾の夏は気温が高いだけでなく、とても（　）です。", option_a="むしあつい", option_b="ものたりない", option_c="うっとうしい", option_d="やかましい", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="大阪で２ヶ月間（　）する予定なので、交通パスを買おうと思っています。", option_a="たいざい", option_b="そんざい", option_c="じゅうたい", option_d="きたい", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="このアプリの（　）を改善する必要があります。", option_a="機能 (きのう)", option_b="器能 (きのう)", option_c="性能 (せいのう)", option_d="技能 (ぎのう)", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="異文化を（　）するために、大阪へ留学します。", option_a="体験 (たいけん)", option_b="實驗 (じっけん)", option_c="檢索 (けんさく)", option_d="練習 (れんしゅう)", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="毎日練習を（　）ことで、日本語が上手になります。", option_a="続ける (つづける)", option_b="始める (はじめる)", option_c="終わる (おわる)", option_d="忘れる (わすれる)", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="彼はいつも（　）に計画を立てます。", option_a="慎重 (しんちょう)", option_b="緊張 (きんちょう)", option_c="貴重 (きちょう)", option_d="重大 (じゅうだい)", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="予定を（　）しなければなりません。", option_a="変更 (へんこう)", option_b="更新 (こうしん)", option_c="整理 (せいり)", option_d="決定 (けってい)", correct_answer="A"),

            # --- 第四階段：高級 (N2~N1) ---
            QuizQuestion(stage="第四階段：高級", level_tag="N2", question="彼はとても（　）性格で、誰とでもすぐ仲良くなる。", option_a="おおまかな", option_b="おおらかな", option_c="おごそかな", option_d="おろかな", correct_answer="B"),
            QuizQuestion(stage="第四階段：高級", level_tag="N2", question="会議の資料を（　）読んでおいてください。", option_a="ざっと", option_b="そっと", option_c="じっと", option_d="ほっと", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="新しい事業を始めるにあたって、資金の（　）がついた。", option_a="目途 (めど)", option_b="目標 (もくひょう)", option_c="目印 (めじるし)", option_d="目先 (めさき)", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="長年の努力がようやく（　）、彼は金メダルを手にした。", option_a="報われて (むくわれて)", option_b="養われて (やしなわれて)", option_c="損なわれて (そこなわれて)", option_d="紛れて (まぎれて)", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N2", question="プログラミングの（　）を磨くために、日々努力している。", option_a="腕 (うで)", option_b="足 (あし)", option_c="指 (ゆび)", option_d="肩 (かた)", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N2", question="彼の意見は非常に（　）を得ている。", option_a="的 (まと)", option_b="芯 (しん)", option_c="節 (ふし)", option_d="脈 (みゃく)", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="この技術は今後、世界中に（　）していくことが予想される。", option_a="普及 (ふきゅう)", option_b="流布 (るふ)", option_c="伝染 (でんせん)", option_d="充満 (じゅうまん)", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="自分の信念を最後まで（　）通す。", option_a="貫き (つらぬき)", option_b="導き (みちびき)", option_c="凌ぎ (しのぎ)", option_d="仰ぎ (あおぎ)", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="細部にまで（　）抜かれたデザインは、多くの人を魅了する。", option_a="練り (ねり)", option_b="掘り (ほり)", option_c="絞り (しぼり)", option_d="削り (けずり)", correct_answer="A")
        ]
        db.session.add_all(questions)
        db.session.commit()

        # ==========================================
        # 4. 🌟 建立 VIP 測試帳號與他的新版徽章進度！
        # ==========================================
        print("👑 正在建立 VIP 測試帳號...")
        vip_email = '123456'
        vip_pw = generate_password_hash('123456') 
        vip_user = User(
            email=vip_email, 
            password_hash=vip_pw, 
            username="測試大師", 
            japanese_level='N3', # N3 交流無礙 (銀牌)
            j_pts=120, 
            streak_days=8,       # 連續 8 天 (銅牌)
            total_active_days=16, # 總共登入 16 天 (銀牌)
            total_scans=55,       # 總共拍照 55 次 (銅牌)
            
            # 關鍵：騙過無情的連勝重置系統！(請改成你們實際的日期欄位名稱)
            last_login_date=date.today() 
        )
        db.session.add(vip_user)
        db.session.commit()

        # 能力值
        vip_ability = UserAbility(
            user_id=vip_user.id, listening=0.8, speaking=0.6, reading=0.9, writing=0.5, culture=0.7
        )
        db.session.add(vip_ability)

        # 解鎖場景
        vip_scene1 = UserScene(user_id=vip_user.id, scene_id=scene1.id)
        vip_scene2 = UserScene(user_id=vip_user.id, scene_id=scene2.id)
        db.session.add_all([vip_scene1, vip_scene2])

        # 收藏單字 (這裡收了 3 個，所以單字大富翁目前是 0 級木牌)
        vip_vocab1 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[0].id) 
        vip_vocab2 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[1].id) 
        vip_vocab3 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[2].id) 
        db.session.add_all([vip_vocab1, vip_vocab2, vip_vocab3])
        
        db.session.commit()
        print("✅ 豪華版資料 (含全新 30 題測驗庫) 灌入完成！")
        print(f"👉 測試帳號: {vip_email}")
        print(f"👉 測試密碼: 123456")

if __name__ == '__main__':
    seed_data()