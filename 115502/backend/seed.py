from app import app
from utils.db import db
from models import User, Scene, Vocab, Achievement, UserAbility, UserAchievement, UserScene
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
            Vocab(scene_id=scene1.id, word='ラーメン', kana='ラーメン', meaning='拉麵'),
            Vocab(scene_id=scene1.id, word='替玉', kana='かえだま', meaning='加麵'),
            Vocab(scene_id=scene2.id, word='切符', kana='きっぷ', meaning='車票'),
            Vocab(scene_id=scene2.id, word='改札口', kana='かいさつぐち', meaning='剪票口'),
            Vocab(scene_id=scene3.id, word='お守り', kana='おまもり', meaning='御守'),
            Vocab(scene_id=scene4.id, word='アニメ', kana='アニメ', meaning='動畫'),
            Vocab(scene_id=scene5.id, word='コーヒー', kana='コーヒー', meaning='咖啡')
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
        db.session.commit()

        # ==========================================
        # 4. 🌟 建立 VIP 測試帳號與他的進度！
        # ==========================================
        print("👑 正在建立 VIP 測試帳號...")
        vip_email = '11156015@ntub.edu.tw'
        vip_pw = generate_password_hash('123456') # 密碼統一設為 123456 方便測試
        vip_user = User(email=vip_email, password_hash=vip_pw, japanese_level='N3', j_pts=120, streak_days=5)
        db.session.add(vip_user)
        db.session.commit()

        # 幫 VIP 帳號建立「能力值」(數值完美對應你先前的雷達圖設計)
        vip_ability = UserAbility(
            user_id=vip_user.id,
            listening=0.8,
            speaking=0.6,
            reading=0.9,
            writing=0.5,
            culture=0.7
        )
        db.session.add(vip_ability)

        # 幫 VIP 帳號「解鎖徽章」 (讓他擁有前 3 個徽章，後 3 個未解鎖)
        vip_ach1 = UserAchievement(user_id=vip_user.id, achievement_id=ach1.id)
        vip_ach2 = UserAchievement(user_id=vip_user.id, achievement_id=ach2.id)
        vip_ach3 = UserAchievement(user_id=vip_user.id, achievement_id=ach3.id)
        db.session.add_all([vip_ach1, vip_ach2, vip_ach3])

        # 幫 VIP 帳號「解鎖場景」
        vip_scene1 = UserScene(user_id=vip_user.id, scene_id=scene1.id)
        vip_scene2 = UserScene(user_id=vip_user.id, scene_id=scene2.id)
        db.session.add_all([vip_scene1, vip_scene2])

        db.session.commit()
        print("✅ 豪華版資料灌入完成！")
        print(f"👉 測試帳號: {vip_email}")
        print(f"👉 測試密碼: 123456")

if __name__ == '__main__':
    seed_data()