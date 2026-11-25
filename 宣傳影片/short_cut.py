"""大螢幕用的 3 分鐘版：App 介紹（完整）→ 後台段落，最後淡出（不放片尾卡）。

  先跑 py -3 真實畫面/render_admin_segment.py（用目前後台的真實截圖做的後台段落）
  再跑 py -3 short_cut.py  → Snap_to_Learn_大螢幕版.mp4
App 功能優先；後台段落放不下時，把 USE_ADMIN 改成 False 就只剩 App。
"""
import re
import subprocess
from pathlib import Path

import imageio_ffmpeg

from merge import endcard_start

ROOT = Path(__file__).parent
APP = ROOT / "Snap_to_Learn_宣傳影片.mp4"
ADMIN = ROOT / "build" / "admin_segment.mp4"
USE_ADMIN = True
ENDCARD = False  # 片尾卡（標語＋團隊名單）；使用者不要
FADE_OUT = 1.2
OUT = ROOT / "Snap_to_Learn_大螢幕版.mp4"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
FADE = 0.5
LIMIT = 180.0



def duration(path):
    out = subprocess.run([FFMPEG, "-i", str(path)], capture_output=True,
                         text=True, encoding="utf-8", errors="replace").stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", out)
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))


def main():
    cut = endcard_start()
    app_len = duration(APP)
    # (輸入編號, 起, 迄)
    parts = [(0, 0, cut)] + ([(1, 0, duration(ADMIN))] if USE_ADMIN else []) + ([(0, cut, app_len)] if ENDCARD else [])
    norm = "scale=1920:1080,setsar=1,fps=30,format=yuv420p,settb=AVTB"
    anorm = "aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo"
    fc, vlab, alab = [], [], []
    for k, (src, a, b) in enumerate(parts):
        fc.append(f"[{src}:v]trim={a:.3f}:{b:.3f},setpts=PTS-STARTPTS,{norm}[v{k}]")
        fc.append(f"[{src}:a]atrim={a:.3f}:{b:.3f},asetpts=PTS-STARTPTS,{anorm}[a{k}]")
    lens = [b - a for _, a, b in parts]
    offset, v, au = 0.0, "v0", "a0"
    for k in range(1, len(parts)):
        offset += lens[k - 1] - FADE
        fc.append(f"[{v}][v{k}]xfade=transition=fade:duration={FADE}:offset={offset:.3f}[vx{k}]")
        fc.append(f"[{au}][a{k}]acrossfade=d={FADE}[ax{k}]")
        v, au = f"vx{k}", f"ax{k}"
    total = sum(lens) - FADE * (len(parts) - 1)
    st = total - FADE_OUT  # 結尾淡出到黑、聲音淡出
    fc.append(f"[{v}]fade=t=out:st={st:.3f}:d={FADE_OUT}[vend]")
    fc.append(f"[{au}]afade=t=out:st={st:.3f}:d={FADE_OUT}[aend]")
    v, au = "vend", "aend"
    print(f"預計長度 {total:.1f} 秒（{int(total // 60)}:{total % 60:04.1f}）")
    if total > LIMIT:
        raise SystemExit("超過 3 分鐘：縮短後台段落，或把 USE_ADMIN 改成 False")
    subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", str(APP), "-i", str(ADMIN),
                    "-filter_complex", ";".join(fc), "-map", f"[{v}]", "-map", f"[{au}]",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(OUT)], check=True)
    print(f"完成 {OUT.name}：{duration(OUT):.1f} 秒")


if __name__ == "__main__":
    main()
