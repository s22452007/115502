from app import app
from utils.db import db
from datetime import date, datetime
from models import User, Scene, UserPhoto, UserPhotoVocab, Vocab, Achievement, UserAbility, UserAchievement, UserVocab, QuizQuestion
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
        # 2. 建立系統單字庫 (Vocab)
        # ==========================================
        vocabs = [
            Vocab(scene_id=scene1.id, word='ラーメン', kana='ラーメン', meaning='拉麵', 
                  sentence_basic='このラーメンは美味しいです。', 
                  sentence_inter='このラーメン屋は行列ができるほど有名だ。', 
                  sentence_upper_inter='この店のラーメンは、スープがなくなり次第終了となります。',
                  sentence_advanced='こだわりの豚骨を何時間も煮込んだ、至極のラーメンである。',
                  audio_word='ramen.mp3'),
            
            Vocab(scene_id=scene1.id, word='替玉', kana='かえだま', meaning='加麵', 
                  sentence_basic='替玉をお願いします。', 
                  sentence_inter='スープが残っているので、替玉を注文した。',
                  sentence_upper_inter='ダイエット中にもかかわらず、誘惑に負けて替玉を頼んでしまった。',
                  sentence_advanced='博多ラーメンの醍醐味は、やはり替玉にあると言えるだろう。',
                  audio_word='kaedama.mp3'),
            
            Vocab(scene_id=scene2.id, word='切符', kana='きっぷ', meaning='車票', 
                  sentence_basic='切符を買います。', 
                  sentence_inter='券売機で新幹線の切符を購入した。',
                  sentence_upper_inter='払い戻し期間を過ぎた切符は、無効になってしまうので注意が必要だ。',
                  sentence_advanced='電子マネーの普及により、紙の切符を手にする機会はめっきり減った。',
                  audio_word='kippu.mp3'),
            
            Vocab(scene_id=scene2.id, word='改札口', kana='かいさつぐち', meaning='剪票口', 
                  sentence_basic='改札口はどこですか？', 
                  sentence_inter='改札口で友達と待ち合わせをしている。',
                  sentence_upper_inter='朝のラッシュ時の改札口は、前に進めないほど混雜している。',
                  sentence_advanced='最新の顔認証システムを備えた改札口が、一部の駅で導入され始めている。',
                  audio_word='kaisatsuguchi.mp3'),
            
            Vocab(scene_id=scene3.id, word='お守り', kana='おまもり', meaning='御守', 
                  sentence_basic='お守りを買いました。', 
                  sentence_inter='神社で合格祈願のお守りを買った。',
                  sentence_upper_inter='祖母からもらったこのお守りは、私にとって何よりも大切なものだ。',
                  sentence_advanced='古来より、お守りには人々の切実な願いと祈りが込められている。',
                  audio_word='omamori.mp3'),
            
            Vocab(scene_id=scene4.id, word='アニメ', kana='アニメ', meaning='動畫', 
                  sentence_basic='日本のアニメが好きです。', 
                  sentence_inter='休日は一日中アニメを見て過ごすことが多い。',
                  sentence_upper_inter='日本のアニメは國內のみならず、海外でも高く評価されている。',
                  sentence_advanced='精緻な作畫と複雑な人間模様を描いたそのアニメは、社會現象を巻き起こした。',
                  audio_word='anime.mp3'),
            
            Vocab(scene_id=scene5.id, word='コーヒー', kana='コーヒー', meaning='咖啡', 
                  sentence_basic='ホットコーヒーを一つください。', 
                  sentence_inter='毎朝、淹れたてのコーヒーを飲むのが日課だ。',
                  sentence_upper_inter='彼はコーヒーの豆の產地にまでこだわるほどのコーヒー好きだ。',
                  sentence_advanced='芳醇な香りと深いコクが特徴のこのコーヒーは、至福のひとときをもたらしてくれる。',
                  audio_word='coffee.mp3')
        ]
        db.session.add_all(vocabs)
        db.session.commit()

        # ==========================================
        # 3. 📝 建立測驗題庫
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
            QuizQuestion(stage="第二階段：初級", level_tag="N5", question="毎日（　）で学校へ通っています。", option_a="でんしゃ", option_b="じかん", option_c="じしょ", option_d="きょうしつ", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N5", question="心斎橋はとても（　）なところですね。", option_a="にぎやか", option_b="しずか", option_c="ひま", option_d="きれい", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N4", question="テストが終わって（　）しました。", option_a="あんしん", option_b="ちゅうい", option_c="じゅんび", option_d="しっぱい", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N4", question="この地図はとても（　）やすいです。", option_a="み", option_b="かき", option_c="よみ", option_d="わかり", correct_answer="D"),
            QuizQuestion(stage="第二階段：初級", level_tag="N4", question="明日（　）があれば、買い物に行きましょう。", option_a="つごう", option_b="ぐあい", option_c="きぶん", option_d="ちょうし", correct_answer="A"),

            # --- 第三階段：中級 (N3) ---
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="台湾の夏は気温が高いだけでなく、とても（　）です。", option_a="むしあつい", option_b="ものたりない", option_c="うっとうしい", option_d="やかましい", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="大阪で２ヶ月間（　）する予定なので、交通パスを買おうと思っています。", option_a="たいざい", option_b="そんざい", option_c="じゅうたい", option_d="きたい", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="このアプリの（　）を改善する必要があります。", option_a="機能", option_b="器能", option_c="性能", option_d="技能", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="異文化を（　）するために、大阪へ留学します。", option_a="たいけん", option_b="じっけん", option_c="けんさく", option_d="れんしゅう", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="毎日練習を（　）ことで、日本語が上手になります。", option_a="つづける", option_b="はじめる", option_c="おわる", option_d="わすれる", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="彼はいつも（　）に計画を立てます。", option_a="しんちょう", option_b="きんちょう", option_c="きちょう", option_d="じゅうだい", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="予定を（　）しなければなりません。", option_a="へんこう", option_b="こうしん", option_c="せいり", option_d="けってい", correct_answer="A"),

            # --- 第四階段：高級 (N2~N1) ---
            QuizQuestion(stage="第四階段：高級", level_tag="N2", question="彼はとても（　）性格で、誰とでもすぐ仲良くなる。", option_a="おおまかな", option_b="おおらかな", option_c="おごそかな", option_d="おろかな", correct_answer="B"),
            QuizQuestion(stage="第四階段：高級", level_tag="N2", question="会議の資料を（　）読んでおいてください。", option_a="ざっと", option_b="そっと", option_c="じっと", option_d="ほっと", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="新しい事業を始めるにあたって、資金の（　）がついた。", option_a="めど", option_b="もくひょう", option_c="めじるし", option_d="めさき", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="長年の努力がようやく（　）、彼は金メダルを手にした。", option_a="むくわれて", option_b="やしなわれて", option_c="そこなわれて", option_d="まぎれて", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N2", question="プログラミングの（　）を磨くために、日々努力している。", option_a="うで", option_b="あし", option_c="ゆび", option_d="かた", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N2", question="彼の意見は非常に（　）を得ている。", option_a="まと", option_b="しん", option_c="ふし", option_d="みゃく", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="この技術は今後、世界中に（　）していくことが予想される。", option_a="ふきゅう", option_b="るふ", option_c="でんせん", option_d="じゅうまん", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="自分の信念を最後まで（　）通す。", option_a="つらぬき", option_b="みちびき", option_c="しのぎ", option_d="あおぎ", correct_answer="A"),
            QuizQuestion(stage="第四階段：高級", level_tag="N1", question="細部にまで（　）抜かれたデザインは、多くの人を魅了する。", option_a="ねり", option_b="ほり", option_c="しぼり", option_d="けずり", correct_answer="A")
        ]
        db.session.add_all(questions)
        db.session.commit()

        # ==========================================
        # 4. 建立 VIP 測試帳號與新版紀錄
        # ==========================================
        print("👑 正在建立 VIP 測試帳號...")
        vip_user = User(
            email='123456', 
            password_hash=generate_password_hash('123456'), 
            username="測試大師", 
            japanese_level='N3',
            j_pts=120, 
            streak_days=8, 
            total_active_days=16, 
            total_scans=55, 
            last_login_date=date.today() 
        )
        db.session.add(vip_user)
        db.session.commit()

        # 能力值
        db.session.add(UserAbility(user_id=vip_user.id, listening=0.8, speaking=0.6, reading=0.9, writing=0.5, culture=0.7))

        # ==========================================
        # 🌟 新架構假資料：模擬拍照與收藏
        # ==========================================
        from datetime import timedelta
        current_time = datetime.utcnow()

        # --- 事件 1: 拍了拉麵照片 (新宿) ---
        photo1 = UserPhoto(
            user_id=vip_user.id,
            scene_id=scene1.id,
            image_path='test_ramen.jpg',
            custom_title='我在新宿吃的第一碗一蘭拉麵🍜',
            created_at=current_time - timedelta(days=2) # 假裝是兩天前拍的
        )
        db.session.add(photo1)
        db.session.flush() # 先 flush 拿到 photo1.id

        # 在這張照片裡辨識出「拉麵」跟「加麵」
        pv1 = UserPhotoVocab(photo_id=photo1.id, vocab_id=vocabs[0].id) # ラーメン
        pv2 = UserPhotoVocab(photo_id=photo1.id, vocab_id=vocabs[1].id) # 替玉
        db.session.add_all([pv1, pv2])

        # 玩家同時把這兩個字加入了收藏 (圖鑑打勾 + 星星)
        uv1 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[0].id, collected_at=current_time)
        uv2 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[1].id, collected_at=current_time)
        db.session.add_all([uv1, uv2])

        # --- 事件 2: 拍了車票照片 ---
        photo2 = UserPhoto(
            user_id=vip_user.id,
            scene_id=scene2.id,
            image_path='test_ticket.jpg',
            custom_title='準備搭新幹線回程囉🚉',
            created_at=current_time - timedelta(days=1) # 假裝是一天前拍的
        )
        db.session.add(photo2)
        db.session.flush()

        # 在這張照片裡辨識出「車票」
        pv3 = UserPhotoVocab(photo_id=photo2.id, vocab_id=vocabs[2].id) # 切符
        db.session.add(pv3)

        # 玩家只有解鎖，沒有收藏車票 (圖鑑打勾，但沒星星)
        uv3 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[2].id, collected_at=None)
        db.session.add(uv3)

        # --- 事件 3: 🌟 淺草吃拉麵 (重複出現的單字) ---
        photo3 = UserPhoto(
            user_id=vip_user.id,
            scene_id=scene1.id,
            # 這裡為了測試，你可以先共用同一張照片，或換成 test_ramen2.jpg 如果你有這張圖
            image_path='test_ramen.jpg', 
            custom_title='逛完淺草寺肚子餓了來吃拉麵🏮',
            created_at=current_time # 假裝是今天拍的
        )
        db.session.add(photo3)
        db.session.flush()

        # 在淺草的照片裡，再次辨識出「拉麵」跟「加麵」
        # 新架構允許照片明細無限增加，完全不會報錯！
        pv4 = UserPhotoVocab(photo_id=photo3.id, vocab_id=vocabs[0].id) # ラーメン
        pv5 = UserPhotoVocab(photo_id=photo3.id, vocab_id=vocabs[1].id) # 替玉
        db.session.add_all([pv4, pv5])

        # 🛑 注意：我們「不」能在這裡再寫入 UserVocab 了！
        # 因為 UserVocab 是全域圖鑑，這兩個字在「事件 1」就已經建檔收藏了。
        # 再寫入會觸發 UniqueConstraint 錯誤。
        # 這就是新架構完美發揮作用的地方：圖鑑狀態被保護了！

        db.session.commit()
        
        print("✅ 豪華版資料灌入完成！")

if __name__ == '__main__':
    seed_data()