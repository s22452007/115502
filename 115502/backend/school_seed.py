"""校園教育版的預設學校清單（台灣大專院校）。

學生在 App 校園教育版登入頁搜尋學校時，打一個字就能找到，不用等第一位同學新增。
每間學校只登記主網域，並以「.」開頭代表連子網域一起認：
    .ntu.edu.tw → xxx@ntu.edu.tw、xxx@g.ntu.edu.tw 都算台大
學生信箱不在主網域底下的學校，super_admin 可以在後台「學校管理」頁修改。

upgrade_db.py 會呼叫 sync_school_seed()：只補資料庫裡還沒有的學校（名稱或網域重複就跳過），
不會覆蓋管理者改過的設定。
"""

# (學校名稱, 主網域)
SCHOOLS = [
    # 國立大學
    ('國立臺灣大學', 'ntu.edu.tw'),
    ('國立清華大學', 'nthu.edu.tw'),
    ('國立陽明交通大學', 'nycu.edu.tw'),
    ('國立成功大學', 'ncku.edu.tw'),
    ('國立政治大學', 'nccu.edu.tw'),
    ('國立中央大學', 'ncu.edu.tw'),
    ('國立中興大學', 'nchu.edu.tw'),
    ('國立中山大學', 'nsysu.edu.tw'),
    ('國立中正大學', 'ccu.edu.tw'),
    ('國立臺灣師範大學', 'ntnu.edu.tw'),
    ('國立臺北大學', 'ntpu.edu.tw'),
    ('國立臺灣海洋大學', 'ntou.edu.tw'),
    ('國立東華大學', 'ndhu.edu.tw'),
    ('國立暨南國際大學', 'ncnu.edu.tw'),
    ('國立嘉義大學', 'ncyu.edu.tw'),
    ('國立高雄大學', 'nuk.edu.tw'),
    ('國立宜蘭大學', 'niu.edu.tw'),
    ('國立聯合大學', 'nuu.edu.tw'),
    ('國立臺東大學', 'nttu.edu.tw'),
    ('國立金門大學', 'nqu.edu.tw'),
    ('國立臺南大學', 'nutn.edu.tw'),
    ('國立屏東大學', 'nptu.edu.tw'),
    ('國立彰化師範大學', 'ncue.edu.tw'),
    ('國立高雄師範大學', 'nknu.edu.tw'),
    ('國立臺北教育大學', 'ntue.edu.tw'),
    ('國立臺中教育大學', 'ntcu.edu.tw'),
    ('國立臺北藝術大學', 'tnua.edu.tw'),
    ('國立臺灣藝術大學', 'ntua.edu.tw'),
    ('國立臺南藝術大學', 'tnnua.edu.tw'),
    ('國立體育大學', 'ntsu.edu.tw'),
    ('國立臺北護理健康大學', 'ntunhs.edu.tw'),
    ('國立臺北商業大學', 'ntub.edu.tw'),
    ('國立空中大學', 'nou.edu.tw'),
    # 國立科技大學
    ('國立臺灣科技大學', 'ntust.edu.tw'),
    ('國立臺北科技大學', 'ntut.edu.tw'),
    ('國立高雄科技大學', 'nkust.edu.tw'),
    ('國立雲林科技大學', 'yuntech.edu.tw'),
    ('國立屏東科技大學', 'npust.edu.tw'),
    ('國立虎尾科技大學', 'nfu.edu.tw'),
    ('國立勤益科技大學', 'ncut.edu.tw'),
    ('國立臺中科技大學', 'nutc.edu.tw'),
    ('國立澎湖科技大學', 'npu.edu.tw'),
    ('國立高雄餐旅大學', 'nkuht.edu.tw'),
    # 私立大學
    ('輔仁大學', 'fju.edu.tw'),
    ('東吳大學', 'scu.edu.tw'),
    ('淡江大學', 'tku.edu.tw'),
    ('中原大學', 'cycu.edu.tw'),
    ('逢甲大學', 'fcu.edu.tw'),
    ('東海大學', 'thu.edu.tw'),
    ('靜宜大學', 'pu.edu.tw'),
    ('中國文化大學', 'pccu.edu.tw'),
    ('世新大學', 'shu.edu.tw'),
    ('銘傳大學', 'mcu.edu.tw'),
    ('實踐大學', 'usc.edu.tw'),
    ('元智大學', 'yzu.edu.tw'),
    ('長庚大學', 'cgu.edu.tw'),
    ('義守大學', 'isu.edu.tw'),
    ('高雄醫學大學', 'kmu.edu.tw'),
    ('中國醫藥大學', 'cmu.edu.tw'),
    ('臺北醫學大學', 'tmu.edu.tw'),
    ('中山醫學大學', 'csmu.edu.tw'),
    ('亞洲大學', 'asia.edu.tw'),
    ('大同大學', 'ttu.edu.tw'),
    ('華梵大學', 'hfu.edu.tw'),
    ('真理大學', 'au.edu.tw'),
    ('開南大學', 'knu.edu.tw'),
    ('南華大學', 'nhu.edu.tw'),
    ('長榮大學', 'cjcu.edu.tw'),
    ('大葉大學', 'dyu.edu.tw'),
    ('中華大學', 'chu.edu.tw'),
    ('玄奘大學', 'hcu.edu.tw'),
    ('佛光大學', 'fgu.edu.tw'),
    ('慈濟大學', 'tcu.edu.tw'),
    ('明道大學', 'mdu.edu.tw'),
    ('文藻外語大學', 'wzu.edu.tw'),
    # 私立科技大學
    ('朝陽科技大學', 'cyut.edu.tw'),
    ('南臺科技大學', 'stust.edu.tw'),
    ('崑山科技大學', 'ksu.edu.tw'),
    ('嘉南藥理大學', 'cnu.edu.tw'),
    ('龍華科技大學', 'lhu.edu.tw'),
    ('明志科技大學', 'mcut.edu.tw'),
    ('健行科技大學', 'uch.edu.tw'),
    ('正修科技大學', 'csu.edu.tw'),
    ('樹德科技大學', 'stu.edu.tw'),
    ('輔英科技大學', 'fy.edu.tw'),
    ('弘光科技大學', 'hk.edu.tw'),
    ('中臺科技大學', 'ctust.edu.tw'),
    ('嶺東科技大學', 'ltu.edu.tw'),
    ('僑光科技大學', 'ocu.edu.tw'),
    ('建國科技大學', 'ctu.edu.tw'),
    ('遠東科技大學', 'feu.edu.tw'),
    ('明新科技大學', 'must.edu.tw'),
    ('聖約翰科技大學', 'sju.edu.tw'),
    ('德明財經科技大學', 'takming.edu.tw'),
    ('景文科技大學', 'just.edu.tw'),
    ('醒吾科技大學', 'hwu.edu.tw'),
    ('致理科技大學', 'chihlee.edu.tw'),
    ('東南科技大學', 'tnu.edu.tw'),
    ('萬能科技大學', 'vnu.edu.tw'),
    ('元培醫事科技大學', 'ypu.edu.tw'),
    ('長庚科技大學', 'cgust.edu.tw'),
    ('吳鳳科技大學', 'wfu.edu.tw'),
    ('修平科技大學', 'hust.edu.tw'),
    ('美和科技大學', 'meiho.edu.tw'),
    ('大仁科技大學', 'tajen.edu.tw'),
    ('慈濟科技大學', 'tcust.edu.tw'),
    ('臺北城市科技大學', 'tpcu.edu.tw'),
]


# 預設學號格式：最多兩個英文字母＋至少 5 個數字，最後可以再帶一個字母
# （11156047、b09901001、s1101234、40947001s 都算）。純數字會把學號有英文字母的學校整間擋掉；
# 也不能放寬到任意英數字，老師的帳號（多半是英文名字）就是靠這個跟學生分開的。
DEFAULT_STUDENT_ID_PATTERN = r'^[A-Za-z]{0,2}\d{5,}[A-Za-z]?$'
OLD_DEFAULT_STUDENT_ID_PATTERN = r'^\d+$'


def upgrade_default_pattern(cursor):
    """還在用舊預設（純數字）的學校換成新預設，回傳改了幾間。管理者自己改過的不動。"""
    cursor.execute("UPDATE school SET student_id_pattern = ? WHERE student_id_pattern = ?",
                   (DEFAULT_STUDENT_ID_PATTERN, OLD_DEFAULT_STUDENT_ID_PATTERN))
    return cursor.rowcount


def sync_school_seed(cursor):
    """把預設學校補進 school 表，回傳新增幾間。已經有同名或同網域的學校就跳過。"""
    existing_names = {row[0] for row in cursor.execute("SELECT name FROM school").fetchall()}
    existing_domains = set()
    for (domains,) in cursor.execute("SELECT student_domains FROM school").fetchall():
        existing_domains.update(d.strip().lower().lstrip('.') for d in (domains or '').split(',') if d.strip())
    added = 0
    for name, domain in SCHOOLS:
        if name in existing_names or domain in existing_domains:
            continue
        cursor.execute(
            "INSERT INTO school (name, student_domains, student_id_pattern, is_active, created_at) "
            "VALUES (?, ?, ?, 1, CURRENT_TIMESTAMP)",
            (name, '.' + domain, DEFAULT_STUDENT_ID_PATTERN))
        existing_names.add(name)
        existing_domains.add(domain)
        added += 1
    return added
