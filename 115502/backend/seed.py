from app import app
from utils.db import db
from datetime import date, datetime
from models import User, Scene, Vocab, Achievement, UserAbility, UserAchievement, UserVocab, QuizQuestion
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
        # ⚠️ 修正：將 audio_filename 改為 audio_word
        # ==========================================
        vocabs = [
            Vocab(scene_id=scene1.id, word='ラーメン', kana='ラーメン', meaning='拉麵', 
                  sentence_basic='このラーメンは美味しいです。', 
                  sentence_inter='このラーメン屋は行列ができるほど有名だ。', 
                  sentence_upper_inter='この店のラーメンは、スープがなくなり次第終了となります。',
                  sentence_advanced='こだわりの豚骨を何時間も煮込んだ、至極のラーメンである。',
                  audio_word='ramen.mp3'), # 修正這裡
            
            Vocab(scene_id=scene1.id, word='替玉', kana='かえだま', meaning='加麵', 
                  sentence_basic='替玉をお願いします。', 
                  sentence_inter='スープが残っているので、替玉を注文した。',
                  sentence_upper_inter='ダイエット中にもかかわらず、誘惑に負けて替玉を頼んでしまった。',
                  sentence_advanced='博多ラーメンの醍醐味は、やはり替玉にあると言えるだろう。',
                  audio_word='kaedama.mp3'), # 修正這裡
            
            Vocab(scene_id=scene2.id, word='切符', kana='きっぷ', meaning='車票', 
                  sentence_basic='切符を買います。', 
                  sentence_inter='券売機で新幹線の切符を購入した。',
                  sentence_upper_inter='払い戻し期間を過ぎた切符は、無効になってしまうので注意が必要だ。',
                  sentence_advanced='電子マネーの普及により、紙の切符を手にする機会はめっきり減った。',
                  audio_word='kippu.mp3'), # 修正這裡
            
            Vocab(scene_id=scene2.id, word='改札口', kana='かいさつぐち', meaning='剪票口', 
                  sentence_basic='改札口はどこですか？', 
                  sentence_inter='改札口で友達と待ち合わせをしている。',
                  sentence_upper_inter='朝のラッシュ時の改札口は、前に進めないほど混雜している。',
                  sentence_advanced='最新の顔認証システムを備えた改札口が、一部の駅で導入され始めている。',
                  audio_word='kaisatsuguchi.mp3'), # 修正這裡
            
            Vocab(scene_id=scene3.id, word='お守り', kana='おまもり', meaning='御守', 
                  sentence_basic='お守りを買いました。', 
                  sentence_inter='神社で合格祈願のお守りを買った。',
                  sentence_upper_inter='祖母からもらったこのお守りは、私にとって何よりも大切なものだ。',
                  sentence_advanced='古来より、お守りには人々の切実な願いと祈りが込められている。',
                  audio_word='omamori.mp3'), # 修正這裡
            
            Vocab(scene_id=scene4.id, word='アニメ', kana='アニメ', meaning='動畫', 
                  sentence_basic='日本のアニメが好きです。', 
                  sentence_inter='休日は一日中アニメを見て過ごすことが多い。',
                  sentence_upper_inter='日本のアニメは國內のみならず、海外でも高く評価されている。',
                  sentence_advanced='精緻な作畫と複雑な人間模様を描いたそのアニメは、社會現象を巻き起こした。',
                  audio_word='anime.mp3'), # 修正這裡
            
            Vocab(scene_id=scene5.id, word='コーヒー', kana='コーヒー', meaning='咖啡', 
                  sentence_basic='ホットコーヒーを一つください。', 
                  sentence_inter='毎朝、淹れたてのコーヒーを飲むのが日課だ。',
                  sentence_upper_inter='彼はコーヒーの豆の產地にまでこだわるほどのコーヒー好きだ。',
                  sentence_advanced='芳醇な香りと深いコクが特徴のこのコーヒーは、至福のひとときをもたらしてくれる。',
                  audio_word='coffee.mp3') # 修正這裡
        ]
        db.session.add_all(vocabs)
        db.session.commit()

        # ==========================================
        # 3. 📝 建立測驗題庫 (省略部分內容以保持簡潔)
        # ==========================================
        # ... (這裡保留你原本那 30 題的 QuizQuestion 建立代碼)
        # db.session.add_all(questions)
        # db.session.commit()

        # ==========================================
        # 4. 🌟 建立 VIP 測試帳號與新版紀錄
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

        # ⚠️ 重構核心：建立 UserVocab 紀錄
        # 同時解鎖與收藏 (有照片、有時間、有資料夾)
        uv1 = UserVocab(
            user_id=vip_user.id, 
            vocab_id=vocabs[0].id, 
            unlocked_at=datetime.utcnow(), 
            image_path='test_ramen.jpg',
            collected_at=datetime.utcnow() # 同時加入收藏
        )
        
        # 僅解鎖，未收藏
        uv2 = UserVocab(
            user_id=vip_user.id, 
            vocab_id=vocabs[2].id, 
            unlocked_at=datetime.utcnow(), 
            image_path='test_ticket.jpg'
        )

        # 僅收藏，未解鎖 (例如在單字本手動加入)
        uv3 = UserVocab(
            user_id=vip_user.id, 
            vocab_id=vocabs[1].id, 
            collected_at=datetime.utcnow(),
            folder_id=None # 預設資料夾
        )

        db.session.add_all([uv1, uv2, uv3])
        db.session.commit()
        
        print("✅ 豪華版資料灌入完成！")

if __name__ == '__main__':
    seed_data()