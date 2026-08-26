# -*- coding: utf-8 -*-
"""開發測試用：直接把某個主題的官方單字標記成已解鎖，模擬「已經拍到這些字」。

為什麼需要這支：領取獎勵要先集滿（或過半）一個主題的官方單字，
正常途徑是拍到 AI 剛好辨識出那些字的照片，在模擬器裡幾乎測不出來。
這支腳本繞過拍照，直接寫 UserVocab，讓領獎與徽章的流程可以被驗證。

⚠️ 只給開發測試用，不要掛成 API、不要帶上正式環境。

用法（在 backend 目錄下執行）:
  python dev_unlock_theme.py                      列出使用者與主題現況
  python dev_unlock_theme.py 1 餐廳美食 half       解到剛好過半（測「收集過半」獎勵）
  python dev_unlock_theme.py 1 餐廳美食 all        全部解開（測「集滿」獎勵與徽章）
  python dev_unlock_theme.py 1 餐廳美食 5          指定解開幾個
  python dev_unlock_theme.py 1 餐廳美食 reset      還原：鎖回去、清掉領取紀錄與徽章
"""
import sys

from app import app
from utils.db import db
from models import (
    User, Scene, Vocab, UserVocab,
    Achievement, UserAchievement, PointTransaction,
)
from services.scenario import (
    OFFICIAL_SOURCE, THEME_DEFS, THEME_REWARDS,
    theme_badge_name, _reward_key, _theme_progress,
)


def _official_vocabs(scene_id):
    return (Vocab.query
            .filter_by(scene_id=scene_id, source=OFFICIAL_SOURCE)
            .order_by(Vocab.id).all())


def show_overview():
    """沒帶參數時：印出使用者清單與每個主題的進度，方便挑要測哪一個。"""
    users = User.query.order_by(User.id).all()
    print('\n=== 使用者 ===')
    for u in users:
        print(f'  id={u.id:<4} {u.username or "(未命名)":<12} {u.email}  J點={u.j_pts or 0}')

    print('\n=== 主題（官方字數）===')
    for t in THEME_DEFS:
        scene = Scene.query.filter_by(name=t['name']).first()
        if not scene:
            print(f'  {t["name"]:<8} 尚未建立場景')
            continue
        total = len(_official_vocabs(scene.id))
        line = f'  scene_id={scene.id:<4} {t["name"]:<8} 官方字 {total} 個'
        if users:
            unlocked, _ = _theme_progress(users[0].id, scene.id)
            line += f'（user {users[0].id} 已解鎖 {unlocked}）'
        print(line)
    print('\n用法：python dev_unlock_theme.py <user_id> <主題名稱> <half|all|數字|reset>\n')


def reset(user_id, scene):
    """把這個主題還原成沒碰過的狀態，好重測一次領獎流程。"""
    vocab_ids = [v.id for v in _official_vocabs(scene.id)]

    removed = 0
    if vocab_ids:
        removed = (UserVocab.query
                   .filter(UserVocab.user_id == user_id,
                           UserVocab.vocab_id.in_(vocab_ids))
                   .delete(synchronize_session=False))

    # 清掉領取憑證，這樣獎勵才會重新變成「可領取」
    keys = [_reward_key(scene.id, tier) for tier in THEME_REWARDS]
    claims = (PointTransaction.query
              .filter(PointTransaction.user_id == user_id,
                      PointTransaction.related_feature.in_(keys))
              .delete(synchronize_session=False))

    # 收回主題徽章
    badges = 0
    ach = Achievement.query.filter_by(name=theme_badge_name(scene.name)).first()
    if ach:
        badges = (UserAchievement.query
                  .filter_by(user_id=user_id, achievement_id=ach.id)
                  .delete(synchronize_session=False))

    db.session.commit()
    print(f'[還原] 鎖回 {removed} 個單字、清掉 {claims} 筆領取紀錄、收回 {badges} 枚徽章')
    print('      （已發出去的點數不會扣回，測試環境不影響判讀）')


def unlock(user_id, scene, how):
    vocabs = _official_vocabs(scene.id)
    total = len(vocabs)
    if total == 0:
        print(f'[錯誤] 「{scene.name}」沒有官方單字，先確認 seed_themes.py 有跑過')
        return

    if how == 'half':
        want = (total + 1) // 2          # 無條件進位，確保真的跨過 50%
    elif how == 'all':
        want = total
    else:
        try:
            want = max(0, min(int(how), total))
        except ValueError:
            print(f'[錯誤] 看不懂的數量：{how}（可用 half / all / 數字 / reset）')
            return

    added = 0
    for v in vocabs[:want]:
        exists = UserVocab.query.filter_by(user_id=user_id, vocab_id=v.id).first()
        if exists:
            continue
        # collected_at=None＝「已解鎖但沒收藏進資料夾」，跟拍照解鎖寫入的形狀一致
        db.session.add(UserVocab(user_id=user_id, vocab_id=v.id,
                                 collected_at=None, folder_id=None))
        added += 1
    db.session.commit()

    unlocked, total = _theme_progress(user_id, scene.id)
    ratio = unlocked / total if total else 0
    print(f'[完成] 「{scene.name}」新解鎖 {added} 個字 -> 目前 {unlocked}/{total}（{ratio:.0%}）')

    claimable = []
    if ratio >= 0.5:
        claimable.append('過半 +20 J點')
    if unlocked >= total:
        claimable.append('集滿 +100 J點・拍照+3・徽章')
    if claimable:
        print('       可領取：' + '、'.join(claimable))
        print('       去 App 的主題收集冊，卡片左上角會有金色「領取」')
    else:
        print('       還沒到門檻，再多解幾個字')


def main():
    args = sys.argv[1:]
    with app.app_context():
        if len(args) < 3:
            show_overview()
            return

        user_id_raw, theme_name, how = args[0], args[1], args[2]
        try:
            user_id = int(user_id_raw)
        except ValueError:
            print(f'[錯誤] user_id 要是數字：{user_id_raw}')
            return

        if not User.query.get(user_id):
            print(f'[錯誤] 找不到 user_id={user_id}，先跑一次不帶參數看有哪些使用者')
            return

        scene = Scene.query.filter_by(name=theme_name).first()
        if not scene:
            names = '、'.join(t['name'] for t in THEME_DEFS)
            print(f'[錯誤] 找不到主題「{theme_name}」。可用的有：{names}')
            return

        if how == 'reset':
            reset(user_id, scene)
        else:
            unlock(user_id, scene, how)


if __name__ == '__main__':
    main()
