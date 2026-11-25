"""截目前網頁後台（admin_app.py，DB 副本）的真實畫面，給大螢幕版的後台段落用。

需要先開 admin-demo（port 5001，DATABASE_URL 指到 DB 副本）。
  DEMO_PASSWORD=... py -3 capture_admin.py   → shots/admin/*.png
"""
import os
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).parent
OUT = HERE / "shots" / "admin"
BASE = "http://localhost:5001"
PW = os.environ["DEMO_PASSWORD"]
W, H = 1440, 810


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for f in OUT.glob("*.png"):
        f.unlink()
    with sync_playwright() as p:
        b = p.chromium.launch(channel="chrome")
        pg = b.new_page(viewport={"width": W, "height": H}, device_scale_factor=1.5, locale="zh-TW")
        shot = lambda name: (pg.wait_for_timeout(900), pg.screenshot(path=str(OUT / f"{name}.png")), print("截圖", name))

        # 管理者
        pg.goto(BASE + "/login"); pg.wait_for_load_state("load")
        shot("01_login")
        pg.fill('input[name="username"]', "11156047")
        pg.fill("#adminPassword", PW)
        pg.click('form:has(#adminPassword) button[type="submit"]'); pg.wait_for_load_state("load")
        shot("02_dashboard")
        pg.mouse.wheel(0, 500); shot("03_dashboard_2")
        pg.click('a:has-text("登出系統")'); pg.wait_for_load_state("load")

        # 老師
        pg.click('button.login-tab[data-target="teacher"]'); pg.wait_for_timeout(400)
        pg.fill('#form-teacher input[name="email"]', "test_teacher_01@teacher.edu.tw")
        pg.fill('#form-teacher input[name="password"]', PW)
        pg.click('#form-teacher button[type="submit"]'); pg.wait_for_load_state("load")
        shot("04_classes")
        pg.click('[data-bs-target="#createClassModal"], button:has-text("建立新班級"), a:has-text("建立新班級")')
        shot("05_create_class")
        pg.keyboard.press("Escape"); pg.wait_for_timeout(400)
        pg.goto(BASE + "/teacher/classroom/3/gradebook"); pg.wait_for_load_state("load")
        shot("06_gradebook")
        pg.click('[data-bs-target="#gradeConfigModal"], button:has-text("計分方式")')
        shot("07_grade_config")
        pg.keyboard.press("Escape"); pg.wait_for_timeout(400)
        pg.goto(BASE + "/teacher/classroom/3/student/28/report"); pg.wait_for_load_state("load")
        shot("08_student_report")
        b.close()


if __name__ == "__main__":
    main()
