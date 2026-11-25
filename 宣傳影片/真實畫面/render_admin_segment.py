"""大螢幕版的後台段落：真實後台截圖（shots/admin）＋後台講稿的 3 句旁白＋字幕。

  py -3 render_admin_segment.py            → ../build/admin_segment.mp4
  py -3 render_admin_segment.py --preview 2 15 28
旁白音檔沿用 ../後台錄影/build/admin_XX.mp3（narrate_admin.py 依 講稿.md 產生）。
"""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

import imageio_ffmpeg
from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent
ROOT = HERE.parent
NARR = ROOT / "後台錄影" / "build"
OUT = ROOT / "build" / "admin_segment.mp4"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
ROLES = ["管理者", "老師"]
LEAD, GAP, TAIL = 0.6, 0.45, 1.8

# 每句：講稿第幾句的音檔、旁白文字、這句期間要切換的頁面 [(截圖, 網址, 角色, 這句開始後幾成時間切過來)]
LINES = [
    ("admin_01.mp3", "首頁是整個系統的總覽：使用者、訂閱、班級和文章數，還有最近 14 天的活躍趨勢，需要處理的事項直接點過去。",
     [("02_dashboard", "Snap to Learn 管理後台・首頁", 0, 0.0)]),
    ("admin_09.mp3", "每個班有一組班級代碼，學生在 App 輸入代碼就能加入；建立新班級只要填名稱和說明。",
     [("04_classes", "Snap to Learn 教師後台・我的班級", 1, 0.0), ("05_create_class", "Snap to Learn 教師後台・我的班級", 1, 0.55)]),
    ("admin_12.mp3", "成績總表是全班的成績矩陣；計分方式可以設作業、造句和測驗的比例與缺交處理，也能把成績匯出成表格檔。",
     [("06_gradebook", "Snap to Learn 教師後台・成績總表", 1, 0.0), ("07_grade_config", "Snap to Learn 教師後台・成績總表", 1, 0.45)]),
]


def duration(path):
    out = subprocess.run([FFMPEG, "-i", str(path)], capture_output=True, text=True, encoding="utf-8", errors="replace").stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", out)
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))


def chunks(text, limit=20):
    out, buf = [], ""
    for ch in text:
        buf += ch
        if ch in "，。！？；：" and len(buf) >= 4:
            out.append(buf); buf = ""
    if buf:
        out.append(buf)
    merged = []
    for c in out:  # 太短的併到前一段
        if merged and len(merged[-1]) + len(c) <= limit and len(c) < 8:
            merged[-1] += c
        else:
            merged.append(c)
    return [c.rstrip("，。；：") for c in merged]


def build():
    t, pages, caps, audio = LEAD, [], [], []
    for mp3, text, shots in LINES:
        d = duration(NARR / mp3)
        audio.append((t, NARR / mp3))
        for name, url, role, frac in shots:
            pages.append({"src": f"shots/admin/{name}.png", "url": url, "role": role, "t": round(t + frac * d if pages else 0, 3)})
        parts = chunks(text)
        total = sum(len(p) for p in parts)
        s = t
        for p in parts:
            e = s + d * len(p) / total
            caps.append({"start": round(s, 3), "end": round(e, 3), "text": p})
            s = e
        t += d + GAP
    total = t - GAP + TAIL
    for k, p in enumerate(pages):
        nxt = pages[k + 1]["t"] if k + 1 < len(pages) else total
        p["dur"] = round(nxt - p["t"], 3)
    (HERE / "admin_timeline.js").write_text(
        "window.ADMIN_TL=" + json.dumps({"pages": pages, "caps": caps, "roles": ROLES}, ensure_ascii=False) + ";\nwindow.TOTAL=" + str(round(total, 3)) + ";",
        encoding="utf-8")
    return total, audio


def open_page(p):
    b = p.chromium.launch(channel="chrome")
    pg = b.new_page(viewport={"width": 1920, "height": 1080})
    pg.goto((HERE / "admin_segment.html").as_uri())
    pg.evaluate("document.fonts.ready"); pg.evaluate("window.READY"); pg.wait_for_timeout(300)
    return b, pg


def render(total, audio, fps=30):
    silent = ROOT / "build" / "admin_segment_silent.mp4"
    with sync_playwright() as p:
        b, pg = open_page(p)
        n = int(total * fps)
        ff = subprocess.Popen([FFMPEG, "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(fps), "-c:v", "mjpeg", "-i", "-",
                               "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", str(silent)], stdin=subprocess.PIPE)
        t0 = time.time()
        for i in range(n):
            pg.evaluate(f"seek({i / fps})")
            ff.stdin.write(pg.screenshot(type="jpeg", quality=93))
            if i % (fps * 10) == 0:
                print(f"  {i / fps:4.0f}s / {total:.0f}s  {time.time() - t0:4.0f}s", flush=True)
        ff.stdin.close(); ff.wait(); b.close()
    inputs, fl = ["-i", str(silent), "-i", str(ROOT / "build" / "bgm.wav")], []
    for k, (at, f) in enumerate(audio):
        inputs += ["-i", str(f)]
        ms = int(at * 1000)
        fl.append(f"[{k + 2}:a]aresample=44100,aformat=channel_layouts=mono,adelay={ms}|{ms},volume=1.25[v{k}]")
    fl.append("".join(f"[v{k}]" for k in range(len(audio))) + f"amix=inputs={len(audio)}:normalize=0,apad=whole_dur={total}[voice]")
    # 背景音樂接 App 段之後的位置繼續放，音量和旁白期間被壓低時差不多
    fl.append(f"[1:a]atrim=start=40,asetpts=PTS-STARTPTS,aresample=44100,aformat=channel_layouts=mono,volume=0.12[bg]")
    fl.append("[bg][voice]amix=inputs=2:normalize=0:duration=longest,alimiter=limit=0.95,aformat=channel_layouts=stereo[a]")
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *inputs, "-filter_complex", ";".join(fl), "-map", "0:v", "-map", "[a]",
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-t", f"{total:.3f}", str(OUT)], check=True)
    print("完成", OUT, f"{total:.1f}s")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", nargs="*", type=float)
    a = ap.parse_args()
    total, audio = build()
    print(f"後台段落 {total:.1f} 秒")
    if a.preview is not None:
        out = HERE / "preview"; out.mkdir(exist_ok=True)
        with sync_playwright() as p:
            b, pg = open_page(p)
            for t in a.preview:
                pg.evaluate(f"seek({t})"); pg.screenshot(path=str(out / f"admin_{t:05.1f}.png"))
            b.close()
        print("預覽到", out)
    else:
        render(total, audio)
