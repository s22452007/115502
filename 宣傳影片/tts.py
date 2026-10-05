"""產生旁白 mp3 與字幕時間軸（build/seg*.mp3、build/cues.json），並依旁白長度排出每段的秒數。

改旁白：改下面 NARRATION 後重跑  py tts.py  再  py render.py
自己錄音：把錄好的檔案放在 錄音/seg0_0.mp3、錄音/seg0_1.mp3 …（檔名對照 build/台詞表.txt），
         重跑 py tts.py 就會改用你的錄音，畫面與字幕自動配合錄音長度。
"""
import asyncio
import json
import re
import shutil
import subprocess
from pathlib import Path

import imageio_ffmpeg

from prosody import synth_phrased

VOICE = "zh-TW-HsiaoChenNeural"
RATE = "+2%"
STYLE = "lively"   # 語調：normal 平穩、lively 活潑（見 prosody.py）
ROOT = Path(__file__).parent
BUILD = ROOT / "build"
REC = ROOT / "錄音"
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

# 每段：(念完後停留秒數, [(與上一句的間隔秒數, 句子), ...])
# 第一句的間隔就是開場後幾秒開始念。間隔長的地方是留給畫面動作（例如金幣噴出）
NARRATION = [
    (3.2, []),   # 片頭：Logo 與標語，不念旁白
    (2.4, [(0.5, "想學日文卻看不懂？打開相機，隨拍隨翻！"),
           (0.5, "系統瞬間解析日文，為你建立專屬單字卡，照片中的個人資訊也會自動打碼保護。"),
           (0.6, "一鍵加入收藏夾，打造你獨一無二的「單詞牆」，集滿主題收集冊，生活隨處都是教材。")]),
    (1.5, [(0.5, "不敢開口說日文？讓 AI 成為你的專屬語伴！"),
           (1.0, "內建豐富真實情境，支援多輪即時語音對答。不怕犯錯，隨時隨地累積實戰口語經驗。")]),
    (2.6, [(0.5, "寫作與文法，系統幫你嚴格把關。「AI 造句批改」宛如貼身家教，精準揪出文法盲點；"),
           (1.6, "還有疑問？「AI 家教」隨時為你解答。")]),
    (2.2, [(0.5, "「閱讀模組」提供進階文章，"),
           (0.8, "AI 逐字聆聽你的朗讀並即時評分，精準指出唸錯的地方，聽說讀寫全面提升。")]),
    (1.6, [(0.5, "不確定自己的程度？「程度測驗」快速為你分級；"),
           (0.5, "實力提升後，挑戰「升級測驗」，一步步邁向更高等級。")]),
    (2.2, [(0.5, "一個人學太孤單？加入「學習小組」！與好友組隊挑戰排行榜，"),
           (1.6, "或加入老師的線上班級，直接接收派發作業，凝聚學習動力。")]),
    (2.2, [(0.5, "校園教育版支援學校 Google 帳號一鍵登入，輸入班級代碼即可加入班級；"),
           (0.8, "老師透過網頁後台建立班級，派發造句、閱讀、拍照與情境對話作業，全班成績與繳交率一目了然。")]),
    (2.6, [(0.5, "學習也能像打怪升級！完成「每日任務」賺取點數，"),
           (2.2, "不斷挑戰自我，點亮專屬你的「成就徽章牆」，見證每一個學習里程碑。")]),
    (3.4, [(0.5, "想解鎖更多進階功能？系統採用 J-pts 點數機制，按需兌換學習額度。"),
           (1.2, "強烈推薦升級「Premium 訂閱」，享受最高規格的無限暢學體驗！"),
           (2.2, "Snap to Learn，讓生活中的每一刻，都成為學習日語的起點。")]),
]

# 字幕在這些標點斷行；顯示時去掉句尾的 ，。；
BREAK = "，。！？；"
STRIP = "，。；"
MAX_CHARS = 20


def split_chunks(text):
    parts, buf = [], ""
    for ch in text:
        buf += ch
        if ch in BREAK:
            parts.append(buf)
            buf = ""
    if buf.strip():
        parts.append(buf)
    out = []
    for p in parts:
        core = p.rstrip(BREAK)
        if len(core) > MAX_CHARS:
            mid = len(core) // 2
            # 不要切在英文單字中間（例如 Google）
            while mid < len(core) - 1 and core[mid - 1].isascii() and core[mid - 1].isalnum() and core[mid].isascii() and core[mid].isalnum():
                mid += 1
            out += [p[:mid], p[mid:]]
        else:
            out.append(p)
    return out


def norm(s):
    return re.sub(r"[^\w]", "", s).lower()


def align(text, words, dur):
    """把 TTS 的字詞時間分配給每一行字幕。"""
    cues, wi = [], 0
    for chunk in split_chunks(text):
        need = len(norm(chunk))
        if need == 0:
            continue
        got, start, end = 0, None, None
        while wi < len(words) and got < need:
            s, e, w = words[wi]
            start = s if start is None else start
            end = e
            got += len(norm(w))
            wi += 1
        if start is not None:
            cues.append({"start": start, "end": end, "text": chunk.strip().rstrip(STRIP)})
    for a, b in zip(cues, cues[1:]):
        a["end"] = b["start"]
    if cues:
        cues[-1]["end"] = dur + 0.4
    return cues


def media_len(path):
    err = subprocess.run([FFMPEG, "-i", str(path)], capture_output=True, text=True, errors="ignore").stderr
    h, m, s = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err).groups()
    return int(h) * 3600 + int(m) * 60 + float(s)


async def main():
    BUILD.mkdir(exist_ok=True)
    out, script = [], []
    for i, (tail, parts) in enumerate(NARRATION):
        seg, t = {"parts": [], "cues": []}, 0.0
        for j, (gap, text) in enumerate(parts):
            name = f"seg{i}_{j}"
            words, dur = await synth_phrased(text, VOICE, RATE, BUILD / f"{name}.mp3", STYLE)
            cues = align(text, words, dur)
            rec = REC / f"{name}.mp3"
            if rec.exists():
                # 用自己的錄音：字幕時間依錄音長度等比例縮放
                k = media_len(rec) / dur
                dur *= k
                cues = [{**c, "start": c["start"] * k, "end": c["end"] * k} for c in cues]
                shutil.copy(rec, BUILD / f"{name}.mp3")
            at = t + gap
            t = at + dur
            seg["parts"].append({"file": f"{name}.mp3", "at": round(at, 3), "duration": round(dur, 3)})
            seg["cues"] += [{**c, "start": round(c["start"] + at, 3), "end": round(c["end"] + at, 3)} for c in cues]
            script.append(f"{name}.mp3\t{dur:4.1f} 秒\t{text}")
            print(f"{name}: {at:5.1f}s → {t:5.1f}s{'  (錄音)' if rec.exists() else ''}")
        seg["dur"] = round(t + tail, 2)
        print(f"  第 {i + 1} 段共 {seg['dur']} 秒")
        out.append(seg)
    (BUILD / "cues.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    (BUILD / "台詞表.txt").write_text("\n".join(script), encoding="utf-8")
    print("總長", round(sum(s["dur"] for s in out), 1), "秒")


if __name__ == "__main__":
    asyncio.run(main())
