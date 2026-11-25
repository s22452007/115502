"""把 phone_real.html 逐幀錄成無聲 MP4（直式 1000×2000）。

  py -3 render_real.py                 輸出 ../Snap_to_Learn_手機畫面.mp4
  py -3 render_real.py --preview 3 20 60   只截圖到 preview/
"""
import argparse
import subprocess
import time
from pathlib import Path

import imageio_ffmpeg
from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent
OUT = HERE.parent / "Snap_to_Learn_手機畫面.mp4"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


def open_page(p):
    browser = p.chromium.launch(channel="chrome")
    page = browser.new_page(viewport={"width": 500, "height": 1000}, device_scale_factor=2)
    page.goto((HERE / "phone_real.html").as_uri())
    page.evaluate("window.READY")
    page.wait_for_timeout(300)
    return browser, page


def preview(times):
    out = HERE / "preview"
    out.mkdir(exist_ok=True)
    with sync_playwright() as p:
        browser, page = open_page(p)
        for t in times:
            page.evaluate(f"seek({t})")
            page.screenshot(path=str(out / f"t{t:06.2f}.png"))
        browser.close()
    print("預覽輸出到", out)


def render(fps):
    with sync_playwright() as p:
        browser, page = open_page(p)
        total = page.evaluate("TOTAL")
        n = int(total * fps)
        ff = subprocess.Popen(
            [FFMPEG, "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(fps), "-c:v", "mjpeg", "-i", "-",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18",
             "-vf", "scale=out_range=tv,format=yuv420p", "-color_range", "tv", "-movflags", "+faststart", str(OUT)],
            stdin=subprocess.PIPE)
        t0 = time.time()
        for i in range(n):
            page.evaluate(f"seek({i / fps})")
            ff.stdin.write(page.screenshot(type="jpeg", quality=92))
            if i % (fps * 10) == 0:
                eta = (time.time() - t0) / max(i, 1) * (n - i)
                print(f"  {i / fps:5.0f}s / {total:.0f}s   剩約 {eta / 60:4.1f} 分", flush=True)
        ff.stdin.close()
        ff.wait()
        browser.close()
    print("完成：", OUT)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", nargs="*", type=float)
    ap.add_argument("--fps", type=int, default=30)
    a = ap.parse_args()
    if a.preview is not None:
        preview(a.preview)
    else:
        render(a.fps)
