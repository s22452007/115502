# -*- coding: utf-8 -*-
"""
清理 T04 vocab 重複單字的一次性維護腳本。

邏輯：
1. 先備份整個資料庫到 instance/jlens_backup_<時間>.db
2. 找出重複單字（word + kana 相同），保留 id 最小（最早）的一筆
3. user_photo_vocab / user_vocab 指向重複單字的紀錄改指向保留那筆
   - user_vocab 有 (user_id, vocab_id) 唯一限制：
     若使用者同時擁有「保留筆」與「重複筆」的紀錄則合併
     （收藏狀態擇優保留，重複紀錄刪除）
4. 刪除重複的 vocab

可重複執行（idempotent）：沒有重複時不做任何事。
"""
import sqlite3
import os
import shutil
from datetime import datetime

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
db_path = os.path.join(BASE_DIR, 'instance', 'jlens.db')

# ==========================================
# 1. 備份資料庫
# ==========================================
backup_path = os.path.join(
    BASE_DIR, 'instance',
    f"jlens_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
)
shutil.copy2(db_path, backup_path)
print(f"✅ 已備份資料庫 → {backup_path}")

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# ==========================================
# 2. 找出重複單字（word + kana 相同），保留最早（id 最小）
# ==========================================
dup_groups = cursor.execute("""
    SELECT word, kana, MIN(id) AS keep_id, COUNT(*) AS cnt
    FROM vocab
    GROUP BY word, kana
    HAVING COUNT(*) > 1
""").fetchall()

total_deleted = 0
total_pv_repointed = 0
total_uv_repointed = 0
total_uv_merged = 0

for word, kana, keep_id, cnt in dup_groups:
    dup_ids = [r[0] for r in cursor.execute(
        "SELECT id FROM vocab WHERE word = ? AND kana = ? AND id != ?",
        (word, kana, keep_id)
    ).fetchall()]
    placeholders = ','.join('?' * len(dup_ids))

    # ── 3a. user_photo_vocab：直接改指向保留筆（無唯一限制，安全）
    cursor.execute(
        f"UPDATE user_photo_vocab SET vocab_id = ? WHERE vocab_id IN ({placeholders})",
        [keep_id] + dup_ids
    )
    total_pv_repointed += cursor.rowcount

    # ── 3b. user_vocab：有 (user_id, vocab_id) 唯一限制，需逐筆處理
    uv_rows = cursor.execute(
        f"SELECT id, user_id, collected_at, folder_id FROM user_vocab WHERE vocab_id IN ({placeholders})",
        dup_ids
    ).fetchall()
    for uv_id, user_id, collected_at, folder_id in uv_rows:
        existing = cursor.execute(
            "SELECT id, collected_at, folder_id FROM user_vocab WHERE user_id = ? AND vocab_id = ?",
            (user_id, keep_id)
        ).fetchone()
        if existing:
            # 使用者同時有保留筆紀錄 → 合併：收藏狀態擇優保留，刪除重複紀錄
            ex_id, ex_collected, ex_folder = existing
            if ex_collected is None and collected_at is not None:
                cursor.execute(
                    "UPDATE user_vocab SET collected_at = ?, folder_id = ? WHERE id = ?",
                    (collected_at, folder_id, ex_id)
                )
            cursor.execute("DELETE FROM user_vocab WHERE id = ?", (uv_id,))
            total_uv_merged += 1
        else:
            cursor.execute(
                "UPDATE user_vocab SET vocab_id = ? WHERE id = ?",
                (keep_id, uv_id)
            )
            total_uv_repointed += 1

    # ── 4. 刪除重複的 vocab
    cursor.execute(f"DELETE FROM vocab WHERE id IN ({placeholders})", dup_ids)
    total_deleted += len(dup_ids)
    print(f"  「{word}（{kana}）」共 {cnt} 筆 → 保留 id={keep_id}，刪除 {len(dup_ids)} 筆")

conn.commit()

# ==========================================
# 5. 結果報告與驗證
# ==========================================
remain = cursor.execute("""
    SELECT COUNT(*) FROM (
        SELECT 1 FROM vocab GROUP BY word, kana HAVING COUNT(*) > 1
    )
""").fetchone()[0]
vocab_total = cursor.execute("SELECT COUNT(*) FROM vocab").fetchone()[0]
conn.close()

print("")
print("========== 清理完成 ==========")
print(f"重複單字組數：{len(dup_groups)} 組")
print(f"刪除重複 vocab：{total_deleted} 筆")
print(f"user_photo_vocab 重新指向：{total_pv_repointed} 筆")
print(f"user_vocab 重新指向：{total_uv_repointed} 筆／合併刪除：{total_uv_merged} 筆")
print(f"清理後 vocab 總數：{vocab_total} 筆，剩餘重複組數：{remain}（應為 0）")
