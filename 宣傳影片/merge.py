"""把 App 宣傳影片與後台操作影片（已加旁白）接成一支系統簡介影片。

先跑：py -3 render.py、py -3 後台錄影/narrate_admin.py
再跑：py -3 merge.py  → Snap_to_Learn_系統簡介.mp4

順序：App 介紹 → 後台操作 → App 片尾卡（標語＋團隊資訊）。
片尾卡開始的秒數從 build/cues.json 算（最後一段第 3 句之前約 1.7 秒），旁白改了也會跟著動。
各段之間用 0.6 秒淡出淡入銜接。
"""
import json
import re
import subprocess
from pathlib import Path

import imageio_ffmpeg

ROOT = Path(__file__).parent
APP = ROOT / "Snap_to_Learn_宣傳影片.mp4"
ADMIN = ROOT / "後台錄影" / "build" / "admin_narrated.mp4"
OUT = ROOT / "Snap_to_Learn_系統簡介.mp4"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
FADE = 0.6


def duration(path):
    out = subprocess.run([FFMPEG, "-i", str(path)], capture_output=True,
                         text=True, encoding="utf-8", errors="replace").stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", out)
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))


def endcard_start():
    cues = json.loads((ROOT / "build" / "cues.json").read_text(encoding="utf-8"))
    last = cues[-1]
    # 手機退場在第 2、3 句之間約 90% 的位置（video.html s8 的 13.8 秒錨點）
    p1, p2 = last["parts"][1]["at"], last["parts"][2]["at"]
    local = p1 + (13.8 - 8.6) / (15.4 - 8.6) * (p2 - p1)
    return sum(c["dur"] for c in cues[:-1]) + local - 0.2


def main():
    a, b = duration(APP), duration(ADMIN)
    cut = endcard_start()
    norm = "scale=1920:1080,setsar=1,fps=30,format=yuv420p,settb=AVTB"
    anorm = "aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo"
    fc = ";".join([
        f"[0:v]split[va][vb]",
        f"[0:a]asplit[aa][ab]",
        f"[va]trim=0:{cut:.3f},setpts=PTS-STARTPTS,{norm}[v1]",
        f"[aa]atrim=0:{cut:.3f},asetpts=PTS-STARTPTS,{anorm}[a1]",
        f"[1:v]{norm}[v2]",
        f"[1:a]{anorm}[a2]",
        f"[vb]trim=start={cut:.3f},setpts=PTS-STARTPTS,{norm}[v3]",
        f"[ab]atrim=start={cut:.3f},asetpts=PTS-STARTPTS,{anorm}[a3]",
        f"[v1][v2]xfade=transition=fade:duration={FADE}:offset={cut - FADE:.3f}[v12]",
        f"[v12][v3]xfade=transition=fade:duration={FADE}:offset={cut + b - 2 * FADE:.3f}[v]",
        f"[a1][a2]acrossfade=d={FADE}[a12]",
        f"[a12][a3]acrossfade=d={FADE}[a]",
    ])
    subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
                    "-i", str(APP), "-i", str(ADMIN),
                    "-filter_complex", fc, "-map", "[v]", "-map", "[a]",
                    "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart",
                    str(OUT)], check=True)
    print(f"App {cut:.1f}s + 後台 {b:.1f}s + 片尾 {a - cut:.1f}s → {OUT.name} {duration(OUT):.1f}s")


if __name__ == "__main__":
    main()
