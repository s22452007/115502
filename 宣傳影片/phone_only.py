"""只錄手機本體：隱藏左側標題、旁邊小卡、字幕與片頭片尾，裁成手機範圍、無聲。

  py -3 phone_only.py              輸出 Snap_to_Learn_手機畫面.mp4
  py -3 phone_only.py --preview 12 60 100   只截圖到 build/preview_phone/

影片在手機退場（片尾卡出現）前結束；長度跟著 build/cues.json 走。
"""
import argparse
import subprocess
import time

from playwright.sync_api import sync_playwright

from merge import endcard_start
from render import BUILD, FFMPEG, ROOT, prepare

OUT = ROOT / "Snap_to_Learn_手機畫面.mp4"
# 手機外框 left 1190 top 62 寬 420 高 868，四周留 40px 放陰影
CLIP = {"x": 1150, "y": 30, "width": 500, "height": 940}
START = 2.3
SCALE = 2  # 2 倍解析度 → 1000×1880
HIDE_CSS = """
#stage{background:#F5F5F0 !important}
.scene > :not(.scr){visibility:hidden !important}
#cap,#bgk,#nav{display:none !important}
"""


def open_page(p):
    browser = p.chromium.launch(channel="chrome")
    page = browser.new_page(viewport={"width": 1920, "height": 1080}, device_scale_factor=SCALE)
    page.add_init_script("window.__RENDER__=true")
    page.goto((ROOT / "video.html").as_uri())
    page.add_style_tag(content=HIDE_CSS)
    page.evaluate("document.fonts.ready")
    page.wait_for_timeout(300)
    return browser, page


def preview(times):
    out = BUILD / "preview_phone"
    out.mkdir(exist_ok=True)
    with sync_playwright() as p:
        browser, page = open_page(p)
        for t in times:
            page.evaluate(f"seek({t})")
            page.screenshot(path=str(out / f"t{float(t):06.2f}.png"), clip=CLIP)
        browser.close()
    print("預覽輸出到", out)


def render(fps):
    total = endcard_start()
    n = int(total * fps)
    with sync_playwright() as p:
        browser, page = open_page(p)
        ff = subprocess.Popen(
            [FFMPEG, "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(fps), "-c:v", "mjpeg", "-i", "-",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-vf", "scale=out_range=tv,format=yuv420p", "-color_range", "tv",
             "-movflags", "+faststart", str(OUT)],
            stdin=subprocess.PIPE)
        t0 = time.time()
        for i in range(int(START * fps), n):  # 片頭前 2.3 秒手機還沒出現，跳過
            page.evaluate(f"seek({i / fps})")
            ff.stdin.write(page.screenshot(type="jpeg", quality=93, clip=CLIP))
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
    prepare()
    if a.preview is not None:
        preview(a.preview)
    else:
        render(a.fps)
