"""替後台錄影加上旁白：依 講稿.md 的時間表，每句用 edge-tts 產生音檔，放到對應秒數，
再與背景音樂混音，輸出 build/admin_narrated.mp4（畫面不動，只加聲音）。

  py -3 narrate_admin.py
"""
import asyncio
import re
import subprocess
from pathlib import Path

import edge_tts
import imageio_ffmpeg

HERE = Path(__file__).parent
ROOT = HERE.parent
BUILD = HERE / "build"
VIDEO = HERE / "管理者與老師後台操作.mp4"
SCRIPT = HERE / "講稿.md"
BGM = ROOT / "build" / "bgm.wav"
OUT = BUILD / "admin_narrated.mp4"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
VOICE = "zh-TW-HsiaoChenNeural"
RATE = "+2%"
TOTAL = 141.0  # 2:21


def to_sec(t):
    m, s = t.split(":")
    return int(m) * 60 + int(s)


def read_rows():
    rows = []
    pat = re.compile(r"^\|\s*(\d+:\d+)\s*[–-]\s*(\d+:\d+)\s*\|[^|]*\|\s*(.+?)\s*\|\s*$")
    for line in SCRIPT.read_text(encoding="utf-8").splitlines():
        m = pat.match(line)
        if m:
            rows.append((to_sec(m.group(1)), to_sec(m.group(2)), m.group(3)))
    return rows


def duration(path):
    out = subprocess.run([FFMPEG, "-i", str(path)], capture_output=True, text=True, encoding="utf-8", errors="replace").stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", out)
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))


async def synth(text, path):
    await edge_tts.Communicate(text, VOICE, rate=RATE).save(str(path))


def main():
    BUILD.mkdir(exist_ok=True)
    rows = read_rows()
    print(f"讀到 {len(rows)} 句講稿")
    inputs, filters, labels = [], [], []
    for i, (start, end, text) in enumerate(rows):
        mp3 = BUILD / f"admin_{i:02d}.mp3"
        asyncio.run(synth(text, mp3))
        d = duration(mp3)
        slot = end - start
        tempo = 1.0
        if d > slot - 0.2:
            tempo = min(1.25, d / (slot - 0.2))
        if d / tempo > slot + 0.5:
            print(f"警告：第 {i+1} 句 {d:.1f}s 超出段長 {slot}s，請縮短講稿")
        inputs += ["-i", str(mp3)]
        delay = int(start * 1000)
        af = f"[{i+1}:a]" + (f"atempo={tempo:.3f}," if tempo > 1.0 else "") + f"adelay={delay}|{delay},volume=1.6[n{i}]"
        filters.append(af)
        labels.append(f"[n{i}]")
        print(f"{start:>4}s  {d:5.1f}s  tempo {tempo:.2f}  {text[:24]}")
    n = len(rows)
    filters.append("".join(labels) + f"amix=inputs={n}:normalize=0:duration=longest[narr]")
    filters.append(f"[{n+1}:a]atrim=0:{TOTAL},volume=0.10[bgm]")
    filters.append("[narr][bgm]amix=inputs=2:normalize=0:duration=first[aout]")
    filters.append(
        f"[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,"
        f"pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x2F5E33,fps=30[vout]"
    )
    cmd = [FFMPEG, "-y", "-i", str(VIDEO), *inputs, "-i", str(BGM),
           "-filter_complex", ";".join(filters),
           "-map", "[vout]", "-map", "[aout]",
           "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "192k", "-t", str(TOTAL), str(OUT)]
    subprocess.run(cmd, check=True)
    print("輸出", OUT)


if __name__ == "__main__":
    main()
