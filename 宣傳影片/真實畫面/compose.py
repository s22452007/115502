"""把真實 App 截圖排成手機畫面影片的時間軸。

  py -3 compose.py            複製選用的截圖到 選用/，產生 timeline.js（phone_real.html 會讀）
  py -3 render_real.py        錄成 ../Snap_to_Learn_手機畫面.mp4

每段長度對齊 ../build/cues.json 的旁白段落（跟原本的 App 宣傳影片同一條時間軸），
最後一段只放到 Premium 介紹結束（片尾卡之前）。
每一列：(截圖, 秒數, 進場方式, 離開前要點的位置)
  進場方式：push 從右邊推入（換頁）、fade 淡入（同一頁狀態改變）、scroll 往下捲、tab 切分頁、none
  點的位置：App 畫面座標（寬 393、高 852），會在換到下一張前 0.4 秒出現點擊圈
"""
import json
import shutil
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
SHOTS = HERE / "shots"
PICK = HERE / "選用"
CUES = HERE.parent / "build" / "cues.json"

# 每段：該段的截圖列表（秒數加總會被等比例縮放到旁白段落長度）
SEGMENTS = [
    # 0 片頭
    [("_login/01_welcome", 1, "none", None)],
    # 1 拍照辨識 → 單字卡 → 主題收集冊
    [("home/01_home", 2.0, "fade", (128, 787)),
     ("apple_camera/01_preview", 2.6, "push", (197, 784)),
     ("apple_camera/02_name", 1.8, "fade", (239, 479)),
     ("apple_camera/03_analyze0", 1.1, "fade", None),
     ("apple_camera/04_analyze1", 1.1, "fade", None),
     ("apple_camera/06_analyze3", 1.0, "fade", None),
     ("apple_camera/07_analyze4", 3.2, "fade", None),
     ("apple_camera/09_result_scroll", 2.5, "scroll", None),
     ("themes2/01_themes", 2.6, "push", (100, 250)),
     ("themes2/03_theme_detail", 3.0, "push", None)],
    # 2 AI 情境對話
    [("manual_scene/02_picked", 3.0, "push", (197, 777)),
     ("chat2/01_chat0", 2.0, "push", (211, 814)),
     ("chat2/02_typed", 2.5, "fade", (357, 814)),
     ("chat2/03_reply0", 2.0, "fade", None),
     ("chat2/04_reply1", 4.5, "fade", None)],
    # 3 AI 造句批改
    [("sentence5/01_sentence", 4.0, "push", None),
     ("sentence5/02_typed", 3.5, "scroll", (197, 799)),
     ("sentence5/03_result0", 7.6, "fade", None)],
    # 4 閱讀＋朗讀評分
    [("article2/01_list", 2.0, "push", (197, 305)),
     ("article3/01_detail", 2.6, "push", (197, 805)),
     ("reading/01_recording", 2.2, "fade", (197, 805)),
     ("reading/03_eval0", 1.3, "fade", None),
     ("reading/04_eval1", 3.5, "fade", None)],
    # 5 程度測驗、升級測驗
    [("edu/03_q0", 2.0, "push", None),
     ("edu/04_q0_pick", 1.6, "fade", None),
     ("edu/23_result0", 2.4, "push", None),
     ("upgrade3/01_upgrade", 2.4, "push", (243, 506)),
     ("upgrade3/03_quiz_answer", 2.9, "push", None)],
    # 6 學習小組、線上班級
    [("group/01_group", 3.4, "push", (197, 669)),
     ("group/02_create", 3.6, "push", None),
     ("edu_class/01_classrooms", 3.4, "push", (197, 137)),
     ("edu_class/02_class_assign", 4.0, "push", None)],
    # 7 校園教育版
    [("_login_edu/02_edu_form", 3.4, "push", None),
     ("edu_home/01_home", 3.2, "fade", None),
     ("edu_class/04_class_成績", 3.6, "push", (197, 412)),
     ("edu_class/05_assignment", 3.6, "push", None),
     ("edu_hw/01_hw", 3.4, "push", None)],
    # 8 每日任務、成就徽章
    [("home/02_home_2", 4.2, "push", (335, 787)),
     ("profile/01_profile", 3.4, "tab", (197, 740)),
     ("badges/01_badges", 4.0, "push", None),
     ("badges/02_badges_2", 3.6, "scroll", None)],
    # 9 商城、Premium（到片尾卡前）
    [("store2/03_exchange", 4.0, "push", (198, 80)),
     ("store2/02_topup", 3.0, "tab", (65, 80)),
     ("store2/01_premium", 3.0, "tab", None),
     ("store/02_store_2", 3.2, "scroll", None)],
]
LAST_SEG_END = 13.2  # 最後一段只用到這裡（之後是片尾卡）


def bar_color(img):
    r, g, b = img.convert("RGB").getpixel((img.width // 2, 2))
    return f"#{r:02x}{g:02x}{b:02x}", (0.299 * r + 0.587 * g + 0.114 * b) < 140


def main():
    cues = json.loads(CUES.read_text(encoding="utf-8"))
    PICK.mkdir(exist_ok=True)
    items, t = [], 0.0
    for si, seg in enumerate(SEGMENTS):
        target = LAST_SEG_END if si == len(SEGMENTS) - 1 else cues[si]["dur"]
        total = sum(s[1] for s in seg)
        for name, dur, trans, tap in seg:
            src = SHOTS / f"{name}.png"
            dst_name = name.replace("/", "__") + ".png"
            shutil.copy2(src, PICK / dst_name)
            color, dark = bar_color(Image.open(src))
            d = dur * target / total
            items.append({"src": f"選用/{dst_name}", "t": round(t, 3), "dur": round(d, 3),
                          "trans": trans, "tap": tap, "bar": color, "dark": dark})
            t += d
    (HERE / "timeline.js").write_text(
        "window.TIMELINE=" + json.dumps(items, ensure_ascii=False, indent=1) + ";\nwindow.TOTAL=" + str(round(t, 3)) + ";",
        encoding="utf-8")
    video_items = [dict(it, src="真實畫面/" + it["src"]) for it in items]
    (HERE / "timeline_video.js").write_text(
        "window.REAL_TL=" + json.dumps(video_items, ensure_ascii=False, indent=1) + ";", encoding="utf-8")
    print(f"{len(items)} 張截圖，共 {t:.1f} 秒")


if __name__ == "__main__":
    main()
