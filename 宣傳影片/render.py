"""把 video.html 逐幀錄成 MP4，並混入旁白與背景音樂。

  py render.py                  完整輸出 Snap_to_Learn_宣傳影片.mp4
  py render.py --preview 5 40   只截指定秒數的畫面到 build/preview/，檢查用
  py render.py --fps 24         降低幀率加快輸出
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

import imageio_ffmpeg
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).parent
BUILD = ROOT / "build"
OUT = ROOT / "Snap_to_Learn_宣傳影片.mp4"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


def prepare():
    cues = json.loads((BUILD / "cues.json").read_text(encoding="utf-8"))
    (BUILD / "cues.js").write_text("window.CUES=" + json.dumps(cues, ensure_ascii=False) + ";", encoding="utf-8")
    write_srt(cues)
    return cues


def starts(cues):
    """每段在整支影片中的起始秒數（長度由 tts.py 的 NARRATION 決定）。"""
    out, t = [], 0
    for seg in cues:
        out.append(t)
        t += seg["dur"]
    return out


def write_srt(cues):
    def ts(s):
        ms = int(round(s * 1000))
        return f"{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02},{ms % 1000:03}"
    lines, n = [], 1
    for s0, seg in zip(starts(cues), cues):
        for c in seg["cues"]:
            lines += [str(n), f"{ts(s0 + c['start'])} --> {ts(s0 + c['end'])}", c["text"], ""]
            n += 1
    (ROOT / "Snap_to_Learn_宣傳影片.srt").write_text("\n".join(lines), encoding="utf-8")


def open_page(p):
    browser = p.chromium.launch(channel="chrome")
    page = browser.new_page(viewport={"width": 1920, "height": 1080})
    page.add_init_script("window.__RENDER__=true")
    page.goto((ROOT / "video.html").as_uri())
    page.evaluate("document.fonts.ready")
    page.wait_for_timeout(300)
    return browser, page


def preview(times):
    out = BUILD / "preview"
    out.mkdir(exist_ok=True)
    with sync_playwright() as p:
        browser, page = open_page(p)
        for t in times:
            page.evaluate(f"seek({t})")
            page.screenshot(path=str(out / f"t{float(t):06.2f}.png"))
        browser.close()
    print("預覽輸出到", out)


def render_video(fps):
    silent = BUILD / "video_silent.mp4"
    with sync_playwright() as p:
        browser, page = open_page(p)
        total = page.evaluate("TOTAL")
        n = int(total * fps)
        ff = subprocess.Popen(
            [FFMPEG, "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(fps), "-c:v", "mjpeg", "-i", "-",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", str(silent)],
            stdin=subprocess.PIPE)
        t0 = time.time()
        for i in range(n):
            page.evaluate(f"seek({i / fps})")
            ff.stdin.write(page.screenshot(type="jpeg", quality=93))
            if i % (fps * 10) == 0:
                el = time.time() - t0
                eta = el / max(i, 1) * (n - i)
                print(f"  {i / fps:5.0f}s / {total}s   剩約 {eta / 60:4.1f} 分", flush=True)
        ff.stdin.close()
        ff.wait()
        browser.close()
    return silent


def mux(silent, cues):
    total = sum(seg["dur"] for seg in cues)
    inputs = ["-i", str(silent), "-i", str(BUILD / "bgm.wav")]
    parts = [(s0 + pt["at"], pt["file"]) for s0, seg in zip(starts(cues), cues) for pt in seg["parts"]]
    for _, f in parts:
        inputs += ["-i", str(BUILD / f)]
    fl = []
    for k, (at, _) in enumerate(parts):
        ms = int(at * 1000)
        fl.append(f"[{k + 2}:a]aresample=44100,aformat=channel_layouts=mono,adelay={ms}|{ms}[v{k}]")
    fl.append("".join(f"[v{k}]" for k in range(len(parts))) + f"amix=inputs={len(parts)}:normalize=0,volume=1.25,apad=whole_dur={total},asplit=2[voice][sc]")
    fl.append("[1:a]aresample=44100,aformat=channel_layouts=mono,volume=0.32[bg]")
    fl.append("[bg][sc]sidechaincompress=threshold=0.02:ratio=6:attack=20:release=450[duck]")
    fl.append("[duck][voice]amix=inputs=2:normalize=0,alimiter=limit=0.95,aformat=channel_layouts=stereo[a]")
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *inputs, "-filter_complex", ";".join(fl),
                    "-map", "0:v", "-map", "[a]", "-vf", "scale=out_range=tv,format=yuv420p", "-color_range", "tv",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-c:a", "aac", "-b:a", "192k", "-t", str(total), str(OUT)],
                   check=True)
    print("完成：", OUT)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", nargs="*", type=float)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--audio-only", action="store_true", help="只重混音軌（畫面沿用上次）")
    a = ap.parse_args()
    cues = prepare()
    if a.preview is not None:
        preview(a.preview)
        sys.exit()
    silent = BUILD / "video_silent.mp4" if a.audio_only else render_video(a.fps)
    mux(silent, cues)
