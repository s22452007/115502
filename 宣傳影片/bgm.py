"""合成跟影片等長的背景音樂 build/bgm.wav（純 Python，無版權問題）。

想換成自己的音樂：把檔案放在 build/bgm.wav（或改 render.py 裡的 BGM 路徑）即可。
"""
import math
import random
import struct
import wave
from array import array
from pathlib import Path

SR = 22050
BPM = 96
import json
LEN = float(sum(seg["dur"] for seg in json.loads((Path(__file__).parent / "build" / "cues.json").read_text(encoding="utf-8"))))  # 跟影片一樣長
BEAT = 60 / BPM
BAR = BEAT * 4
OUT = Path(__file__).parent / "build" / "bgm.wav"

# C - G - Am - F（MIDI 音高）
CHORDS = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]]
ARP = [0, 1, 2, 1, 2, 0, 1, 2]

buf = array("f", [0.0]) * int(SR * LEN)
rng = random.Random(3)


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def add(start, dur, fn, gain):
    i0 = int(start * SR)
    n = min(int(dur * SR), len(buf) - i0)
    for k in range(n):
        buf[i0 + k] += gain * fn(k / SR)


def pluck(f, decay=3.2):
    w = 2 * math.pi * f
    return lambda t: (math.sin(w * t) + 0.3 * math.sin(2 * w * t)) * math.exp(-decay * t) * min(1, t * 200)


def pad(f, dur):
    w = 2 * math.pi * f
    def g(t):
        env = min(1, t / 0.6) * min(1, (dur - t) / 0.8)
        return env * (math.sin(w * t) + 0.25 * math.sin(2 * w * t + 0.4 * math.sin(1.7 * t)))
    return g


def kick(t):
    f = 50 + 70 * math.exp(-t * 30)
    return math.sin(2 * math.pi * f * t) * math.exp(-t * 14)


def hat(t):
    return (rng.random() * 2 - 1) * math.exp(-t * 60)


bars = int(LEN / BAR) + 1
for b in range(bars):
    t0 = b * BAR
    ch = CHORDS[b % 4]
    for m in ch:
        add(t0, BAR, pad(hz(m), BAR), 0.045)
    add(t0, BEAT * 1.9, pluck(hz(ch[0] - 12), 2.0), 0.16)
    add(t0 + BEAT * 2, BEAT * 1.9, pluck(hz(ch[0] - 12), 2.0), 0.13)
    for k, idx in enumerate(ARP):
        add(t0 + k * BEAT / 2, 0.7, pluck(hz(ch[idx] + 12)), 0.05 if k % 2 else 0.065)
    for k in (0, 2):
        add(t0 + k * BEAT, 0.3, kick, 0.32)
    for k in range(4):
        add(t0 + k * BEAT + BEAT / 2, 0.08, hat, 0.03)

peak = max(abs(x) for x in buf) or 1
OUT.parent.mkdir(exist_ok=True)
with wave.open(str(OUT), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    frames = bytearray()
    for i, x in enumerate(buf):
        t = i / SR
        fade = min(1, t / 2.0, (LEN - t) / 4.0)
        frames += struct.pack("<h", int(max(-1, min(1, x / peak * 0.9 * fade)) * 32767))
    w.writeframes(bytes(frames))
print("bgm.wav", LEN, "s")
