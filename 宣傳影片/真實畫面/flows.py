"""每個功能的操作流程（從登入後的首頁開始）。"""


def home(a):
    a.wait(5)  # 等登入成功提示消失
    a.shot("home")
    a.scroll(700)
    a.shot("home_2")
    a.scroll(900)
    a.shot("home_3")


def explore_tabs(a):
    for t in ["相機", "搜尋", "紀錄", "個人"]:
        a.click(t, exact=True, wait=2.5)
        a.shot(t)
        a.click("主頁", exact=True, wait=1.5)


def explore_menu(a):
    for t in ["單字探險", "學習小組", "商城與會員中心", "個人檔案"]:
        a.tap(20, 28, 1.2)
        a.click(t, exact=True, wait=2.5)
        a.shot(t)
        a.back(1.5)


def explore_practice(a):
    a.scroll(900)
    a.click("AI 造句挑戰", wait=2.5)
    a.shot("造句")
    a.back()
    a.scroll(900)
    a.click("閱讀文章", wait=2.5)
    a.shot("閱讀")


def camera(a):
    a.click("相機", exact=True, wait=2.5)
    a.shot("camera")
    with a.page.expect_file_chooser() as fc:
        a.tap(79, 784, 0.3)  # 相簿按鈕
    fc.value.set_files(str(__import__("pathlib").Path(__file__).parent / "desk.jpg"))
    a.wait(3)
    a.tap(197, 417, 0.5)  # 命名欄
    a.type("我的書桌")
    a.shot("name")
    a.click("確定", exact=True, wait=1.5)
    a.shot("context")
    a.click("跳過", exact=True, wait=1.0)
    for i in range(6):  # 分析中 → 結果
        a.shot(f"analyze{i}")
        a.wait(3)


def camera_result(a):
    """拍照結果往下滑、左右滑卡片（接在 camera 後面跑）。"""
    camera(a)
    a.scroll(500, y=600)
    a.shot("result_scroll")
    a.scroll(-500, y=600)
    a.page.mouse.move(330, 600); a.page.mouse.down(); a.page.mouse.move(60, 600, steps=12); a.page.mouse.up()
    a.wait(1.2)
    a.shot("result_card2")
    a.click("完成", exact=True, wait=2.5)
    a.shot("after_done")


def chat(a):
    a.click("相機", exact=True, wait=2.0)
    a.tap(24, 68, 1.5)  # 回首頁（相機左上返回）
    a.shot("home_back")


def manual_scene(a):
    a.click("搜尋", exact=True, wait=2.5)
    a.shot("search")
    a.click("一蘭拉麵", exact=True, wait=1.0)
    a.shot("picked")
    a.click("開始生成情境", exact=True, wait=3)
    for i in range(6):
        a.shot(f"gen{i}")
        a.wait(4)


def sentence(a):
    a.scroll(900)
    a.shot("scrolled")
    a.click("AI 造句挑戰", wait=3)
    a.shot("sentence")


def article(a):
    a.scroll(900)
    a.click("閱讀文章", wait=3)
    a.shot("list")


def records(a):
    a.click("紀錄", exact=True, wait=2.5)
    a.shot("records")


def profile(a):
    a.click("個人", exact=True, wait=2.5)
    a.shot("profile")
    a.scroll(700)
    a.shot("profile_2")
    a.scroll(900)
    a.shot("profile_3")


def menu(a):
    a.tap(20, 28, 1.2)
    a.shot("drawer")
    a.click("學習小組", exact=True, wait=3)
    a.shot("group")
    a.tap(24, 42, 1.5)
    a.tap(20, 28, 1.2)
    a.click("商城與會員中心", exact=True, wait=3)
    a.shot("store")
    a.scroll(700)
    a.shot("store_2")


def chat2(a):
    a.click("搜尋", exact=True, wait=2.5)
    a.click("一蘭拉麵", exact=True, wait=1.0)
    a.click("開始生成情境", exact=True, wait=6)
    a.shot("chat0")
    a.tap(211, 814, 0.8)
    a.type("すみません、ラーメンを一つください。")
    a.shot("typed")
    a.tap(357, 814, 1)
    for i in range(5):
        a.shot(f"reply{i}")
        a.wait(3)


def sentence2(a):
    a.scroll(1600)
    a.shot("scrolled")
    a.click("AI 造句挑戰", wait=3)
    a.shot("sentence")
    a.scroll(600)
    a.shot("sentence_2")


def article2(a):
    a.scroll(2500, wait=1.5)
    a.tap(197, 704, 3)  # 閱讀文章卡片
    a.shot("list")
    a.scroll(600)
    a.shot("list_2")


def store(a):
    a.tap(20, 28, 1.2)
    a.click("商城與會員中心", exact=True, wait=3)
    a.shot("store")
    a.scroll(700)
    a.shot("store_2")
    a.scroll(900)
    a.shot("store_3")


def badges(a):
    a.click("個人", exact=True, wait=2.5)
    a.click("成就徽章", wait=3)
    a.shot("badges")
    a.scroll(700)
    a.shot("badges_2")


def upgrade(a):
    a.click("個人", exact=True, wait=2.5)
    a.scroll(2500, wait=1.5)
    a.tap(197, 680, 3)  # 挑戰升級測驗
    a.shot("upgrade")
    a.wait(3)
    a.shot("upgrade_2")


def upgrade2(a):
    a.click("個人", exact=True, wait=2.5)
    a.scroll(500, wait=2)
    a.click("挑戰升級測驗", wait=3)
    a.shot("upgrade")
    a.wait(3)
    a.shot("upgrade_2")


def sentence3(a):
    a.scroll(2500, wait=1.5)
    a.click("AI 造句挑戰", wait=3)
    a.scroll(600, wait=1.5)
    a.click("請輸入日文", wait=0.8)
    a.type("旅行に行くたびに、写真をたくさん撮ります。")
    a.shot("typed")
    a.click("送出給 AI 批改", wait=3)
    for i in range(5):
        a.shot(f"result{i}")
        a.wait(3)
    a.scroll(700)
    a.shot("result_scroll")


def article3(a):
    a.scroll(2500, wait=1.5)
    a.tap(197, 704, 3)
    a.click("日本の伝統的なお祭り", wait=3)
    a.shot("detail")
    a.scroll(800)
    a.shot("detail_2")
    a.scroll(1500)
    a.shot("detail_3")


def article_history(a):
    a.scroll(2500, wait=1.5)
    a.tap(197, 704, 3)
    a.tap(363, 42, 3)  # 右上歷史紀錄
    a.shot("history")
    a.tap(197, 160, 3)
    a.shot("history_item")
    a.scroll(700)
    a.shot("history_item_2")


def themes(a):
    a.tap(20, 28, 1.2)
    a.click("單字探險", exact=True, wait=3)
    a.click("主題收集冊", wait=3)
    a.shot("themes")
    a.tap(100, 300, 3)
    a.shot("theme_detail")


def photo_detail(a):
    a.tap(20, 28, 1.2)
    a.click("單字探險", exact=True, wait=3)
    a.click("逛完淺草寺", wait=3)
    a.shot("photo")
    a.scroll(600)
    a.shot("photo_2")


def live_camera(a):
    a.click("相機", exact=True, wait=4)
    a.shot("preview")
    a.tap(197, 784, 2)  # 快門
    a.shot("shot")
    for i in range(3):
        a.wait(1.5)
        a.shot(f"after{i}")


def reading(a):
    a.scroll(2500, wait=1.5)
    a.tap(197, 704, 3)
    a.click("日本の伝統的なお祭り", wait=3)
    a.click("按下開始朗讀", wait=1.5)
    a.shot("recording")
    a.wait(21)
    a.shot("recording_late")
    a.click("結束錄音", wait=2)
    for i in range(8):
        a.shot(f"eval{i}")
        a.wait(4)
    a.scroll(700)
    a.shot("eval_scroll")
    a.scroll(900)
    a.shot("eval_scroll2")


def upgrade3(a):
    a.click("個人", exact=True, wait=2.5)
    a.scroll(700, wait=1)
    a.scroll(900, wait=2)
    a.tap(197, 681, 3)
    a.shot("upgrade")
    a.click("開始測驗", exact=True, wait=4)
    a.shot("quiz")
    a.tap(197, 257, 1.5)
    a.shot("quiz_answer")
    a.click("下一題", exact=True, wait=1.5)
    a.shot("quiz_2")


def sentence4(a):
    a.scroll(2500, wait=1.5)
    a.click("AI 造句挑戰", wait=3)
    a.scroll(600, wait=1.5)
    a.tap(197, 704, 0.8)
    a.type("旅行に行くたびに、写真をたくさん撮ります。")
    a.shot("typed")
    a.click("送出給 AI 批改", wait=3)
    for i in range(5):
        a.shot(f"result{i}")
        a.wait(3)
    a.scroll(700)
    a.shot("result_scroll")


def themes2(a):
    a.tap(20, 28, 1.2)
    a.click("單字探險", exact=True, wait=3)
    a.click("主題收集冊", wait=3)
    a.click("先看看收集冊", wait=3)
    a.shot("themes")
    a.scroll(700)
    a.shot("themes_2")
    a.tap(100, 250, 3)
    a.shot("theme_detail")
def pick_option(a, i):
    """點一個選項（不選「我還沒學過這個」）；依題號輪流選第 1、2 個，看起來比較像真人作答。"""
    import re
    opts = []
    for l in a.labels():
        m = re.match(r"(.+?)  @(\d+),(\d+)  role=button", l)
        if m and int(m.group(3)) > 150 and "還沒學過" not in m.group(1) and m.group(1) not in ("下一題", "完成測驗"):
            opts.append((int(m.group(2)), int(m.group(3))))
    if opts:
        a.tap(*opts[min(i % 2, len(opts) - 1)], wait=1.0)


def edu(a):
    a.shot("level")
    a.click("我已經有基礎了", wait=1)
    a.shot("level_pick")
    a.click("開始體驗", exact=True, wait=3)
    for i in range(20):
        a.shot(f"q{i}")
        pick_option(a, i)
        a.shot(f"q{i}_pick")
        labels = " | ".join(a.labels())
        if "完成測驗" in labels:
            a.click("完成測驗", exact=True, wait=4)
            break
        a.click("下一題", exact=True, wait=1.5)
    for j in range(3):
        a.shot(f"result{j}")
        a.wait(2)


def edu_home(a):
    a.shot("home")
    a.scroll(700)
    a.shot("home_2")
    a.scroll(900)
    a.shot("home_3")


def edu_class(a):
    a.click("我的教室", exact=True, wait=3)
    a.shot("classrooms")
    a.click("日文（二）A 班", wait=3)
    a.shot("class_assign")
    for t in ["公告", "成績"]:
        try:
            a.click(t, exact=True, wait=2.5)
            a.shot(f"class_{t}")
        except Exception as e:
            print("  ", e)
    a.click("作業", exact=True, wait=2.5)
    a.click("閱讀理解", wait=3)
    a.shot("assignment")
    a.scroll(600)
    a.shot("assignment_2")


def edu_hw(a):
    a.click("我的作業", exact=True, wait=3)
    a.shot("hw")


def live_camera2(a):
    a.click("相機", exact=True, wait=4)
    a.shot("preview")
    a.tap(197, 784, 2)
    a.tap(197, 417, 0.5)
    a.type("我的書桌")
    a.shot("name")
    a.click("確定", exact=True, wait=1.5)
    a.click("跳過", exact=True, wait=0.8)
    for i in range(6):
        a.shot(f"analyze{i}")
        a.wait(2.5)
    a.scroll(500, y=600)
    a.shot("result_scroll")


def store2(a):
    a.tap(20, 28, 1.2)
    a.click("商城與會員中心", exact=True, wait=3)
    a.shot("premium")
    a.click("儲值點數", exact=True, wait=2.5)
    a.shot("topup")
    a.click("點數兌換", exact=True, wait=2.5)
    a.shot("exchange")
    a.scroll(600)
    a.shot("exchange_2")


def group(a):
    a.tap(20, 28, 1.2)
    a.click("學習小組", exact=True, wait=3)
    a.shot("group")
    a.click("建立小組並邀請好友", wait=3)
    a.shot("create")


# 每個 N3 文法配一句「用對文法但動詞變化有小錯」的句子，讓 AI 批改有東西可以抓
SENTENCES = {
    "〜うちに": "日本にいるうちに、たくさん旅行したいだ。",
    "〜おかげで": "友達のおかげで、宿題が早く終わるました。",
    "〜せいで": "雨のせいで、試合が中止になるました。",
    "〜かわりに": "母のかわりに、私が晩ご飯を作るました。",
    "〜くせに": "彼は知っているくせに、何も教えないでした。",
    "〜たびに": "日本へ行くたびに、ラーメンを食べるます。",
    "〜ついでに": "買い物のついでに、本屋に行くました。",
    "〜最中に": "授業の最中に、電話が鳴るました。",
    "〜とおりに": "先生が言ったとおりに、毎日練習するました。",
    "〜に違いない": "あの店はいつも人が多いから、おいしいに違いないです。",
}


def sentence5(a):
    import json
    grammar = {}

    def on_resp(r):
        if "/api/" in r.url and "sentence" in r.url:
            try:
                txt = json.dumps(r.json(), ensure_ascii=False)
            except Exception:
                return
            for g in SENTENCES:
                if g in txt and "g" not in grammar:
                    grammar["g"] = g
    a.page.on("response", on_resp)
    a.scroll(2500, wait=1.5)
    a.click("AI 造句挑戰", wait=3)
    g = grammar.get("g")
    print("   文法：", g)
    a.shot("sentence")
    a.scroll(600, wait=1.5)
    a.tap(197, 704, 0.8)
    a.type(SENTENCES.get(g, "日本へ行くたびに、ラーメンを食べるます。"))
    a.shot("typed")
    a.click("送出給 AI 批改", wait=3)
    for i in range(4):
        a.shot(f"result{i}")
        a.wait(3)


def apple_camera(a):
    """拍照辨識（假鏡頭畫面＝蘋果，見 apple_scene.png）。"""
    a.click("相機", exact=True, wait=4)
    a.shot("preview")
    a.tap(197, 784, 2)
    a.tap(197, 417, 0.5)
    a.type("早餐的蘋果")
    a.shot("name")
    a.click("確定", exact=True, wait=1.5)
    a.click("跳過", exact=True, wait=0.8)
    for i in range(6):
        a.shot(f"analyze{i}")
        a.wait(2.5)
    a.scroll(500, y=600)
    a.shot("result_scroll")
