"""逐短語合成：每個短語依標點給不同語調，再接上換氣停頓，減少整句一路平到底的 AI 感。"""
import asyncio
import io
import re
import subprocess
import wave

import edge_tts
import imageio_ffmpeg

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
SR = 24000

# 短語結尾標點 → (語速, 音高, 音量, 之後停頓秒數)
STYLE = {
    "？": ("-4%", "+12Hz", "+0%", 0.38),   # 問句：放慢、尾音上揚
    "！": ("+8%", "+6Hz", "+12%", 0.42),   # 驚嘆：加快、提高、大聲
    "。": ("+2%", "-4Hz", "+0%", 0.45),    # 句號：收尾下沉，停久一點換氣
    "；": ("+2%", "-2Hz", "+0%", 0.35),
    "，": ("+4%", "+2Hz", "+0%", 0.16),    # 逗號：短停頓、語氣往上接
    "、": ("+4%", "+0Hz", "+0%", 0.10),
}
DEFAULT = ("+3%", "+0Hz", "+0%", 0.3)

# 活潑版：整體更快更高、問句驚嘆起伏更大、停頓更短
LIVELY = {
    "？": ("+0%", "+26Hz", "+5%", 0.26),
    "！": ("+14%", "+20Hz", "+18%", 0.30),
    "。": ("+8%", "+6Hz", "+5%", 0.32),
    "；": ("+8%", "+8Hz", "+5%", 0.24),
    "，": ("+10%", "+12Hz", "+5%", 0.10),
    "、": ("+10%", "+10Hz", "+5%", 0.06),
}
LIVELY_DEFAULT = ("+9%", "+10Hz", "+5%", 0.2)
STYLES = {"normal": (STYLE, DEFAULT), "lively": (LIVELY, LIVELY_DEFAULT)}


def phrases(text):
    out = re.findall(r"[^，、；。！？]+[，、；。！？]?", text)
    return [p for p in (s.strip() for s in out) if p]


async def tts_pcm(text, voice, rate, pitch, volume, words):
    com = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch, volume=volume, boundary="WordBoundary")
    mp3 = bytearray()
    async for c in com.stream():
        if c["type"] == "audio":
            mp3 += c["data"]
        elif c["type"] == "WordBoundary":
            words.append((c["offset"] / 1e7, (c["offset"] + c["duration"]) / 1e7, c["text"]))
    pcm = subprocess.run([FFMPEG, "-loglevel", "error", "-i", "-", "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         input=bytes(mp3), capture_output=True, check=True).stdout
    return pcm


async def synth_phrased(text, voice, base_rate, out_path, style="normal"):
    """回傳 (字詞邊界清單, 總長秒數)；字詞時間已換算成整段音檔的時間。"""
    pcm_all, words_all, t = bytearray(), [], 0.0
    for ph in phrases(text):
        table, default = STYLES[style]
        rate, pitch, vol, pause = table.get(ph[-1], default)
        r = int(rate.rstrip("%")) + int(base_rate.rstrip("%"))
        words = []
        pcm = await tts_pcm(ph, voice, f"{r:+d}%", pitch, vol, words)
        if not words:
            continue
        # 去掉每段前後自帶的靜音，只留第一個字到最後一個字
        a = max(0, int((words[0][0] - 0.03) * SR)) * 2
        b = min(len(pcm), int((words[-1][1] + 0.08) * SR) * 2)
        shift = t - a / 2 / SR
        words_all += [(s + shift, e + shift, w) for s, e, w in words]
        pcm_all += pcm[a:b]
        t += (b - a) / 2 / SR
        gap = int(pause * SR) * 2
        pcm_all += b"\0" * gap
        t += pause
    # 去掉最後一段停頓
    pcm_all = pcm_all[: len(pcm_all) - gap]
    t -= pause
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(pcm_all))
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", "-", "-b:a", "160k", str(out_path)], input=buf.getvalue(), check=True)
    return words_all, round(t, 3)


