from app import app
from utils.db import db
from models import User, Scene, Vocab, UserScene, UserVocab
from datetime import datetime, timedelta

def seed_data():
    with app.app_context():
        print("🌱 開始植入測試種子資料...")

        # 1. 確保至少有一個測試使用者
        user = User.query.first()
        if not user:
            print("👤 找不到使用者，建立測試帳號 test@example.com")
            user = User(
                email="test@example.com", 
                password_hash="fake_hash", 
                username="測試員",
                daily_scans=2,
                j_pts=150
            )
            db.session.add(user)
            db.session.commit()
        
        user_id = user.id

        # 2. 清空舊的測試資料 (避免重複執行塞入太多一樣的資料)
        UserVocab.query.filter_by(user_id=user_id).delete()
        UserScene.query.filter_by(user_id=user_id).delete()
        # 清空系統預設場景與單字
        Vocab.query.delete()
        Scene.query.delete()
        db.session.commit()

        # 3. 建立場景 (對應你的畫面截圖)
        scene_ramen = Scene(name="一蘭拉麵店", icon_name="ramen_dining")
        scene_station = Scene(name="新宿車站", icon_name="train")
        scene_temple = Scene(name="淺草寺", icon_name="temple_buddhist")
        
        db.session.add_all([scene_ramen, scene_station, scene_temple])
        db.session.commit() # 先 commit 讓場景產生 ID

        # 4. 建立系統單字庫
        vocabs = [
            # 拉麵店單字
            Vocab(scene_id=scene_ramen.id, word="ラーメン", kana="ラーメン", meaning="拉麵", example_sentence="このラーメンは美味しいです。"),
            Vocab(scene_id=scene_ramen.id, word="替玉", kana="かえだま", meaning="加麵", example_sentence="替玉をお願いします。"),
            Vocab(scene_id=scene_ramen.id, word="豚骨", kana="とんこつ", meaning="豬骨湯底", example_sentence="豚骨スープが濃厚です。"),
            
            # 車站單字
            Vocab(scene_id=scene_station.id, word="駅", kana="えき", meaning="車站", example_sentence="新宿駅はどこですか？"),
            Vocab(scene_id=scene_station.id, word="電車", kana="でんしゃ", meaning="電車", example_sentence="電車に乗ります。"),
            Vocab(scene_id=scene_station.id, word="乗り場", kana="のりば", meaning="乘車處", example_sentence="バス乗り場はあそこです。"),
            
            # 淺草寺單字
            Vocab(scene_id=scene_temple.id, word="お寺", kana="おてら", meaning="寺廟", example_sentence="お寺でお参りします。"),
            Vocab(scene_id=scene_temple.id, word="おみくじ", kana="おみくじ", meaning="神籤", example_sentence="おみくじを引きました。"),
        ]
        db.session.add_all(vocabs)
        db.session.commit()

        # 5. 模擬使用者「已解鎖」這些場景 (把日期往前推幾天，讓畫面看起來更真實)
        us1 = UserScene(user_id=user_id, scene_id=scene_ramen.id, unlocked_at=datetime.utcnow() - timedelta(days=2))
        us2 = UserScene(user_id=user_id, scene_id=scene_station.id, unlocked_at=datetime.utcnow() - timedelta(days=1))
        us3 = UserScene(user_id=user_id, scene_id=scene_temple.id, unlocked_at=datetime.utcnow())
        db.session.add_all([us1, us2, us3])

        # 6. 模擬使用者「已打勾/已收藏」部分單字
        # 假設他解鎖了拉麵店的 1 個字，跟車站的 3 個字
        uv1 = UserVocab(user_id=user_id, vocab_id=vocabs[0].id) # ラーメン
        uv2 = UserVocab(user_id=user_id, vocab_id=vocabs[3].id) # 駅
        uv3 = UserVocab(user_id=user_id, vocab_id=vocabs[4].id) # 電車
        uv4 = UserVocab(user_id=user_id, vocab_id=vocabs[5].id) # 乗り場
        db.session.add_all([uv1, uv2, uv3, uv4])

        db.session.commit()
        print("✅ 測試資料植入完成！現在可以打開 App 測試了！")

if __name__ == '__main__':
    seed_data()