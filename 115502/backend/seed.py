from app import app
from utils.db import db
from models import User, Scene, Vocab, Achievement, UserAbility, UserAchievement, UserScene, UserVocab, QuizQuestion
from werkzeug.security import generate_password_hash

def seed_data():
    with app.app_context():
        print("🧹 正在清理舊資料，準備重建世界...")
        # 為了避免資料衝突，我們直接把所有資料表砍掉重練
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
            Vocab(scene_id=scene1.id, word='ラーメン', kana='ラーメン', meaning='拉麵', example_sentence='このラーメンは美味しいです。', audio_filename='ramen.mp3'),
            Vocab(scene_id=scene1.id, word='替玉', kana='かえだま', meaning='加麵', example_sentence='替玉をお願いします。', audio_filename='kaedama.mp3'),
            Vocab(scene_id=scene2.id, word='切符', kana='きっぷ', meaning='車票', example_sentence='切符を買います。', audio_filename='kippu.mp3'),
            Vocab(scene_id=scene2.id, word='改札口', kana='かいさつぐち', meaning='剪票口', example_sentence='改札口はどこですか？', audio_filename='kaisatsuguchi.mp3'),
            Vocab(scene_id=scene3.id, word='お守り', kana='おまもり', meaning='御守', example_sentence='お守りを買いました。', audio_filename='omamori.mp3'),
            Vocab(scene_id=scene4.id, word='アニメ', kana='アニメ', meaning='動畫', example_sentence='日本のアニメが好きです。', audio_filename='anime.mp3'),
            Vocab(scene_id=scene5.id, word='コーヒー', kana='コーヒー', meaning='咖啡', example_sentence='ホットコーヒーを一つください。', audio_filename='coffee.mp3')
        ]
        db.session.add_all(vocabs)

        # ==========================================
        # 3. 建立系統成就徽章總表 (Achievement)
        # ==========================================
        ach1 = Achievement(name='拉麵大師', description='在拉麵店場景收集 3 個單字')
        ach2 = Achievement(name='咖啡廳大師', description='在咖啡廳場景收集單字')
        ach3 = Achievement(name='文化', description='解鎖寺廟相關場景')
        ach4 = Achievement(name='交通達人', description='解鎖車站相關場景')
        ach5 = Achievement(name='御宅族', description='探索秋葉原場景')
        ach6 = Achievement(name='單字破百', description='總共收集 100 個單字')
        db.session.add_all([ach1, ach2, ach3, ach4, ach5, ach6])

        # ==========================================
        # 4. 📝 建立程度判定測驗題庫 (QuizQuestion)
        # ==========================================
        questions = [
            # 第一階段
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="「わたし」的漢字寫法是？", 
                         option_a="私", option_b="彼", option_c="君", option_d="僕", correct_answer="A"),
            QuizQuestion(stage="第一階段：超級新手", level_tag="超級新手", question="圖片中是「壽司」，請問它的日文平假名是？", 
                         option_a="さし", option_b="すし", option_c="せし", option_d="そし", correct_answer="B"),
            # 第二階段
            QuizQuestion(stage="第二階段：初級", level_tag="N5", question="あそこに白い（　）が止まっています。", 
                         option_a="くるま", option_b="かばん", option_c="つくえ", option_d="いす", correct_answer="A"),
            QuizQuestion(stage="第二階段：初級", level_tag="N4", question="この料理はとても（　）です。", 
                         option_a="しんせん", option_b="しんせつ", option_c="ていねい", option_d="にぎやか", correct_answer="A"),
            # 第三階段
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="台湾の夏は気温が高いだけでなく、とても（　）です。", 
                         option_a="むしあつい", option_b="ものたりない", option_c="うっとうしい", option_d="やかましい", correct_answer="A"),
            QuizQuestion(stage="第三階段：中級", level_tag="N3", question="大阪で２ヶ月間（　）する予定なので、交通パスを買おうと思っています。", 
                         option_a="たいざい", option_b="そんざい", option_c="じゅうたい", option_d="きたい", correct_answer="A"),
            # 第四階段
            QuizQuestion(stage="高級：書面語與進階辨析", level_tag="N2", question="彼はとても（　）性格で、誰とでもすぐ仲良くなる。", 
                         option_a="おおまかな", option_b="おおらかな", option_c="おごそかな", option_d="おろかな", correct_answer="B"),
            QuizQuestion(stage="高級：書面語與進階辨析", level_tag="N2", question="会議の資料を（　）読んでおいてください。", 
                         option_a="ざっと", option_b="そっと", option_c="じっと", option_d="ほっと", correct_answer="A"),
            QuizQuestion(stage="高級：書面語與進階辨析", level_tag="N1", question="新しい事業を始めるにあたって、資金の（　）がついた。", 
                         option_a="目途 (めど)", option_b="目標 (もくひょう)", option_c="目印 (めじるし)", option_d="目先 (めさき)", correct_answer="A"),
            QuizQuestion(stage="高級：書面語與進階辨析", level_tag="N1", question="長年の努力がようやく（　）、彼は金メダルを手にした。", 
                         option_a="報われて (むくわれて)", option_b="養われて (やしなわれて)", option_c="損なわれて (そこなわれて)", option_d="紛れて (まぎれて)", correct_answer="A"),
        ]
        db.session.add_all(questions)
        db.session.commit()

        # ==========================================
        # 5. 🌟 建立 VIP 測試帳號與他的進度！
        # ==========================================
        print("👑 正在建立 VIP 測試帳號...")
        vip_email = '123456'
        vip_pw = generate_password_hash('123456') 
        vip_user = User(email=vip_email, password_hash=vip_pw, username="測試大師", japanese_level='N3', j_pts=120, streak_days=5)
        db.session.add(vip_user)
        db.session.commit()

        # 能力值
        vip_ability = UserAbility(
            user_id=vip_user.id, listening=0.8, speaking=0.6, reading=0.9, writing=0.5, culture=0.7
        )
        db.session.add(vip_ability)

        # 解鎖徽章
        vip_ach1 = UserAchievement(user_id=vip_user.id, achievement_id=ach1.id)
        vip_ach2 = UserAchievement(user_id=vip_user.id, achievement_id=ach2.id)
        vip_ach3 = UserAchievement(user_id=vip_user.id, achievement_id=ach3.id)
        db.session.add_all([vip_ach1, vip_ach2, vip_ach3])

        # 解鎖場景
        vip_scene1 = UserScene(user_id=vip_user.id, scene_id=scene1.id)
        vip_scene2 = UserScene(user_id=vip_user.id, scene_id=scene2.id)
        db.session.add_all([vip_scene1, vip_scene2])

        # 收藏單字
        vip_vocab1 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[0].id) 
        vip_vocab2 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[1].id) 
        vip_vocab3 = UserVocab(user_id=vip_user.id, vocab_id=vocabs[2].id) 
        db.session.add_all([vip_vocab1, vip_vocab2, vip_vocab3])
        
        db.session.commit()
        print("✅ 豪華版資料 (含測驗題庫) 灌入完成！")
        print(f"👉 測試帳號: {vip_email}")
        print(f"👉 測試密碼: 123456")

if __name__ == '__main__':
    seed_data()