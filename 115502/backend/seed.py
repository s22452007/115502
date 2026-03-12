from app import app
from utils.db import db
from models import Scene, Vocab, Achievement

def seed_data():
    # 使用 app_context 才能操作資料庫
    with app.app_context():
        # 清空舊的測試資料（避免重複執行產生一堆一樣的資料）
        db.session.query(Vocab).delete()
        db.session.query(Scene).delete()
        db.session.query(Achievement).delete()
        db.session.commit()

        print("🌱 開始種植預設資料...")

        # 1. 建立預設場景
        scene1 = Scene(name='一蘭拉麵店', icon_name='ramen_dining')
        scene2 = Scene(name='新宿車站', icon_name='train')
        scene3 = Scene(name='淺草寺', icon_name='temple_buddhist')
        db.session.add_all([scene1, scene2, scene3])
        db.session.commit() # 先 commit 才能拿到 scene 的 ID

        # 2. 建立每個場景對應的單字
        vocabs = [
            Vocab(scene_id=scene1.id, word='ラーメン', kana='ラーメン', meaning='拉麵'),
            Vocab(scene_id=scene1.id, word='替玉', kana='かえだま', meaning='加麵'),
            Vocab(scene_id=scene1.id, word='豚骨', kana='とんこつ', meaning='豬骨(湯頭)'),
            Vocab(scene_id=scene2.id, word='切符', kana='きっぷ', meaning='車票'),
            Vocab(scene_id=scene2.id, word='改札口', kana='かいさつぐち', meaning='剪票口'),
            Vocab(scene_id=scene3.id, word='お守り', kana='おまもり', meaning='御守/護身符')
        ]
        db.session.add_all(vocabs)

        # 3. 建立系統預設徽章
        ach1 = Achievement(name='拉麵大師', description='在拉麵店場景收集 3 個單字')
        ach2 = Achievement(name='交通達人', description='解鎖車站相關場景')
        ach3 = Achievement(name='文化體驗', description='解鎖寺廟相關場景')
        db.session.add_all([ach1, ach2, ach3])

        db.session.commit()
        print("✅ 預設資料 (場景、單字、徽章) 灌入完成！太棒了！")

if __name__ == '__main__':
    seed_data()