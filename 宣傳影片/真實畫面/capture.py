"""從本機真實 App（Flutter Web）截圖，給手機畫面影片用。

需要先開：後端（DB 副本）port 5050、Web 版靜態伺服器 port 8099。
  py -3 capture.py 流程名稱 [流程名稱...]     例：py -3 capture.py home camera
每個流程從登入後的首頁開始，截圖存到 shots/<流程>/NN_名稱.png，
同時把畫面上可點的文字標籤存成 .txt，方便找下一步要點什麼。
"""
import json
import os
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent
SHOTS = HERE / "shots"
# Chrome 的假鏡頭／麥克風檔案路徑不能有中文，複製到 ASCII 路徑
FAKE = Path(os.environ.get("FAKE_DIR", r"C:/Users/user/AppData/Local/Temp/claude/ae7afe7d6e48eaea/89b4f621-5dfe-4bb7-88d7-ae001e5ae2b4/scratchpad/fake"))
URL = "http://localhost:8099/"
W, H, DPR = 393, 852, 3
EMAIL = os.environ.get("DEMO_EMAIL", "tester@example.com")
PASSWORD = os.environ["DEMO_PASSWORD"]


class App:
    def __init__(self, page, name):
        self.page, self.dir, self.n = page, SHOTS / name, 0
        self.dir.mkdir(parents=True, exist_ok=True)
        for f in self.dir.glob("*"):
            f.unlink()

    def wait(self, s=1.0):
        self.page.wait_for_timeout(int(s * 1000))

    def semantics(self):
        try:
            if self.page.locator("flt-semantics").count() > 3:
                return
            ph = self.page.locator("flt-semantics-placeholder")
            if ph.count():
                ph.dispatch_event("click")
            self.wait(0.5)
        except Exception:
            pass

    def labels(self):
        return self.page.evaluate("""() => [...document.querySelectorAll('flt-semantics')]
          .map(e => {const r=e.getBoundingClientRect();
            const t=(e.getAttribute('aria-label')||'').trim() || [...e.childNodes].filter(n=>n.nodeType===3).map(n=>n.textContent).join('').trim();
            return t && r.width>0 ? `${t.replace(/\\n/g,' / ').slice(0,60)}  @${Math.round(r.x+r.width/2)},${Math.round(r.y+r.height/2)}  role=${e.getAttribute('role')||''}` : null})
          .filter(Boolean)""")

    def shot(self, name):
        self.n += 1
        base = self.dir / f"{self.n:02d}_{name}"
        self.page.screenshot(path=str(base.with_suffix(".png")))
        self.semantics()
        base.with_suffix(".txt").write_text("\n".join(self.labels()), encoding="utf-8")
        print("  截圖", base.name)

    def tap(self, x, y, wait=1.2):
        self.page.mouse.click(x, y)
        self.wait(wait)

    def click(self, text, wait=1.5, exact=False, nth=0):
        """點語意標籤含有 text 的元素（Flutter Web 開了無障礙樹才找得到）。"""
        self.semantics()
        box = self.page.evaluate("""([t, exact, nth]) => {
            const els=[...document.querySelectorAll('flt-semantics')].filter(e=>{
              const l=(e.getAttribute('aria-label')||'') || [...e.childNodes].filter(n=>n.nodeType===3).map(n=>n.textContent).join('');
              const r=e.getBoundingClientRect(); return r.width>0 && (exact ? l.trim()===t : l.includes(t));});
            els.sort((a,b)=>a.getBoundingClientRect().width*a.getBoundingClientRect().height-b.getBoundingClientRect().width*b.getBoundingClientRect().height);
            const e=els[nth]; if(!e) return null; const r=e.getBoundingClientRect();
            return [r.x+r.width/2, r.y+r.height/2];}""", [text, exact, nth])
        if not box:
            raise RuntimeError(f"找不到「{text}」")
        self.tap(*box, wait=wait)

    def type(self, text, wait=0.5):
        self.page.keyboard.type(text, delay=40)
        self.wait(wait)

    def scroll(self, dy, x=196, y=500, wait=0.8):
        self.page.mouse.move(x, y)
        self.page.mouse.wheel(0, dy)
        self.wait(wait)

    def back(self, wait=1.2):
        self.page.go_back()
        self.wait(wait)


def login(page):
    page.goto(URL)
    page.wait_for_timeout(5000)
    app = App(page, "_login")
    app.shot("welcome")
    app.click("登入", wait=4)  # 一般自主學習卡片的「登入」（第一個）
    app.shot("after_login_btn")
    try:
        app.click("Skip", wait=1.5)
    except Exception:
        pass
    app.shot("login_form")
    app.tap(197, 450, 0.6)  # 電子郵件欄
    app.type(EMAIL)
    app.tap(180, 522, 0.6)  # 密碼欄
    app.type(PASSWORD)
    app.click("登入", exact=True, wait=0.5)
    page.wait_for_timeout(8000)  # 等「登入成功」提示消失
    for _ in range(3):  # 關掉登入後可能跳出的彈窗
        try:
            app.click("關閉", wait=0.8)
        except Exception:
            break


def login_edu(page):
    """教育版：學號密碼登入（測試學生 student01@test.com）。"""
    page.goto(URL)
    page.wait_for_timeout(5000)
    app = App(page, "_login_edu")
    app.tap(283, 801, 4)  # 校園教育版「登入」
    try:
        app.click("Skip", wait=1.5)
    except Exception:
        pass
    app.shot("edu_login")
    app.click("用老師給的帳號登入", wait=1.5)
    app.shot("edu_form")
    app.tap(197, 571, 0.6)
    app.type(os.environ.get("EDU_ACCOUNT", "student01@test.com"))
    app.tap(180, 639, 0.6)
    app.type(PASSWORD)
    app.click("登入", exact=True, wait=0.5)
    page.wait_for_timeout(8000)
    for _ in range(3):
        try:
            app.click("關閉", wait=0.8)
        except Exception:
            break


def run(flows):
    import flows as F
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome", args=[
            "--use-fake-ui-for-media-stream", "--use-fake-device-for-media-stream",
            f"--use-file-for-fake-video-capture={FAKE / os.environ.get('FAKE_VIDEO', 'apple.y4m')}",
            f"--use-file-for-fake-audio-capture={FAKE / 'read.wav'}",
        ])
        for name in flows:
            ctx = browser.new_context(viewport={"width": W, "height": H}, device_scale_factor=DPR,
                                      is_mobile=True, has_touch=False,
                                      permissions=["camera", "microphone"])
            page = ctx.new_page()
            print("流程", name)
            if name.startswith("edu"):
                login_edu(page)
            else:
                login(page)
            app = App(page, name)
            try:
                getattr(F, name)(app)
            except Exception as e:
                print("  失敗：", e)
                app.shot("ERROR")
            ctx.close()
        browser.close()


if __name__ == "__main__":
    run(sys.argv[1:])
