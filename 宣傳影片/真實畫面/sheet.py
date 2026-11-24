"""把某流程的截圖排成一張縮圖：py -3 sheet.py 流程 [輸出路徑]"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
d = Path(__file__).parent / "shots" / sys.argv[1]
fs = sorted(d.glob("*.png"))
w, h = 260, 564
s = Image.new("RGB", (w * len(fs), h + 24), "white")
dr = ImageDraw.Draw(s)
for i, f in enumerate(fs):
    s.paste(Image.open(f).convert("RGB").resize((w, h)), (i * w, 24))
    dr.text((i * w + 4, 4), f.stem[:30], fill="black")
out = sys.argv[2] if len(sys.argv) > 2 else str(d.parent / f"_{sys.argv[1]}.png")
s.save(out); print(out)
