import sys
import os
import json
import re
import random
from datetime import datetime
from flask import Blueprint, request, jsonify
from datetime import datetime, date

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from datetime import timedelta, timezone

from models import db, User, SentencePracticeRecord, PointTransaction, TransactionType
from utils import gemini_client
from utils.ai_helper import JSON_CONFIG, parse_gemini_json
from utils.group_helper import add_group_progress_and_check_reward
from utils.account_helper import is_payment_free, sentence_daily_limit, today_start_utc, has_unlimited_usage, uses_points

sentence_bp = Blueprint('sentence', __name__)

from services.store import ITEM_COSTS
PAID_SENTENCE_COST = ITEM_COSTS['sentence_extra']   # 超過每日免費次數後，每次造句的點數


def _today_start_utc():
    """台灣時間今天 00:00 換算成 UTC。

    created_at 存的是 UTC，原本拿伺服器本機的 00:00 去比，台灣早上 8 點前的造句
    會被算成「昨天」，每日免費次數就會失準。
    """
    tw = timezone(timedelta(hours=8))
    today_tw = datetime.now(tw).date()
    return datetime.combine(today_tw, datetime.min.time()) - timedelta(hours=8)

# ==========================================
# 📚 精選 N5-N1 文法題庫 (內建各3種變化例句)
# ==========================================
GRAMMAR_DB = {
    "N5": [
        {"grammar": "〜てください", "meaning": "請做... (要求)", "examples": ["ここに名前を書いてください。(請在這裡寫名字。)", "ちょっと待ってください。(請稍等一下。)", "明日、私の家に来てください。(明天請來我家。)"]},
        {"grammar": "〜てもいいですか", "meaning": "可以做...嗎？ (許可)", "examples": ["写真を撮ってもいいですか。(可以拍照嗎？)", "ここに座ってもいいですか。(可以坐在這裡嗎？)", "ペンを借りてもいいですか。(可以借用筆嗎？)"]},
        {"grammar": "〜はいけません", "meaning": "不可以... (禁止)", "examples": ["ここでタバコを吸ってはいけません。(不可以在這裡吸菸。)", "病院で走ってはいけません。(不可以在醫院奔跑。)", "お酒を飲んで運転してはいけません。(不可以酒駕。)"]},
        {"grammar": "〜のが好きです", "meaning": "喜歡做...", "examples": ["私は本を読むのが好きです。(我喜歡看書。)", "音楽を聴くのが好きです。(我喜歡聽音樂。)", "週末に料理を作るのが好きです。(我喜歡在週末做菜。)"]},
        {"grammar": "〜つもりです", "meaning": "打算做... (計畫)", "examples": ["来年、日本へ行くつもりです。(我打算明年去日本。)", "今日は早く寝るつもりです。(我打算今天早點睡。)", "将来、医者になるつもりです。(我打算將來當醫生。)"]},
        {"grammar": "〜たことがある", "meaning": "曾經做過... (經驗)", "examples": ["富士山に登ったことがあります。(我曾經爬過富士山。)", "寿司を食べたことがあります。(我吃過壽司。)", "日本のお祭りに行ったことがありますか。(你去過日本的祭典嗎？)"]},
        {"grammar": "〜たり、〜たりする", "meaning": "又...又... / 有時...有時...", "examples": ["休日は、映画を見たり、買い物をしたりします。(假日有時看電影，有時購物。)", "泣いたり笑ったりして、忙しい人ですね。(又哭又笑的，真是個忙碌的人呢。)", "本を読んだり、音楽を聴いたりして過ごします。(看看書、聽聽音樂來度過。)"]},
        {"grammar": "〜ないでください", "meaning": "請不要...", "examples": ["ここにゴミを捨てないでください。(請不要把垃圾丟在這裡。)", "心配しないでください。(請不要擔心。)", "教室で日本語以外を話さないでください。(請不要在教室說日文以外的語言。)"]},
        {"grammar": "〜より〜のほうが", "meaning": "比起...，...更... (比較)", "examples": ["肉より魚のほうが好きです。(比起肉，我更喜歡魚。)", "バスより電車のほうが速いです。(比起公車，電車更快。)", "昨日より今日のほうが暑いですね。(今天比昨天熱呢。)"]},
        {"grammar": "〜たくないです", "meaning": "不想做...", "examples": ["今日は何もしたくないです。(今天什麼都不想做。)", "あんな店にはもう行きたくないです。(不想再去那種店了。)", "野菜は食べたくないです。(我不想吃蔬菜。)"]}
    ],
    "N4": [
        {"grammar": "〜ば / なら", "meaning": "如果...的話 (條件)", "examples": ["安ければ、買います。(如果便宜的話我就買。)", "雨が降れば、試合は中止です。(如果下雨，比賽就取消。)", "温泉に行くなら、箱根がいいですよ。(如果要去溫泉，箱根很不錯喔。)"]},
        {"grammar": "〜ようにする", "meaning": "盡量做到... (努力達成)", "examples": ["毎日、野菜を食べるようにしています。(我盡量每天吃蔬菜。)", "遅刻しないようにしてください。(請盡量不要遲到。)", "日本語で話すようにしています。(我盡量用日文說話。)"]},
        {"grammar": "〜ために", "meaning": "為了... (目的)", "examples": ["家族のために、一生懸命働きます。(為了家人拼命工作。)", "日本へ行くために、貯金しています。(為了去日本正在存錢。)", "健康のために、毎日運動しています。(為了健康每天運動。)"]},
        {"grammar": "〜そうだ", "meaning": "看起來好像... (樣態)", "examples": ["このケーキは美味しそうですね。(這個蛋糕看起來很好吃呢。)", "雨が降りそうな空です。(看起來快下雨的天空。)", "彼はとても忙しそうです。(他看起來非常忙。)"]},
        {"grammar": "〜すぎる", "meaning": "太過於...", "examples": ["昨日、お酒を飲みすぎました。(昨天酒喝太多了。)", "この問題は難しすぎます。(這個問題太難了。)", "テレビの見すぎは目に悪いです。(看太多電視對眼睛不好。)"]},
        {"grammar": "〜てしまう", "meaning": "不小心... / ...完了 (遺憾/完成)", "examples": ["パスポートを忘れてしまいました。(不小心把護照忘記了。)", "ケーキを全部食べてしまった。(把蛋糕全部吃光了。)", "電車に傘を置き忘れてしまいました。(不小心把傘忘在電車上了。)"]},
        {"grammar": "〜ておく", "meaning": "事先準備...", "examples": ["友達が来る前に、部屋を掃除しておきます。(朋友來之前，先打掃好房間。)", "旅行の前に、ホテルを予約しておきました。(旅行前，事先預訂好飯店了。)", "この本はここに置いておいてください。(請把這本書先放在這裡。)"]},
        {"grammar": "〜てある", "meaning": "某狀態已經被維持著", "examples": ["壁にカレンダーが掛けてあります。(牆上掛著日曆。)", "窓が開けてあります。(窗戶是開著的。)", "机の上に本が置いてあります。(桌上放著書。)"]},
        {"grammar": "〜てみる", "meaning": "試試看...", "examples": ["この服を着てみてもいいですか。(可以試穿這件衣服嗎？)", "新しいレストランに行ってみましょう。(去新的餐廳試試看吧。)", "日本の納豆を食べてみたいです。(想試吃看看日本的納豆。)"]},
        {"grammar": "〜られる", "meaning": "被... (受身/被動態)", "examples": ["先生に褒められました。(被老師稱讚了。)", "泥棒に財布を盗まれました。(錢包被小偷盜走了。)", "母に日記を読まれてしまった。(被媽媽看了日記。)"]}
    ],
    "N3": [
        {"grammar": "〜うちに", "meaning": "趁著...的時候", "examples": ["日本にいるうちに、富士山に登りたい。(想趁著在日本的時候爬富士山。)", "スープが温かいうちに、飲んでください。(請趁湯還熱的時候喝。)", "若いうちに、いろいろな経験をしたほうがいい。(趁年輕時多累積不同經驗比較好。)"]},
        {"grammar": "〜おかげで", "meaning": "多虧了... (好結果)", "examples": ["先生のおかげで、試験に合格できました。(多虧了老師，我考試及格了。)", "薬を飲んだおかげで、熱が下がりました。(多虧吃了藥，燒退了。)", "友達が手伝ってくれたおかげで早く終わった。(多虧朋友幫忙才提早結束。)"]},
        {"grammar": "〜せいで", "meaning": "都怪... (壞結果)", "examples": ["バスが遅れたせいで、遅刻してしまった。(都怪公車誤點，害我遲到了。)", "食べ過ぎたせいで、お腹が痛いです。(都怪吃太多，現在肚子痛。)", "彼のせいで、計画がめちゃくちゃになった。(都怪他，計畫一塌糊塗。)"]},
        {"grammar": "〜かわりに", "meaning": "代替... / 作為交換", "examples": ["社長のかわりに、私が会議に出席します。(我代替社長出席會議。)", "手伝ってあげるかわりに、ご飯をおごってね。(作為幫忙的交換，你要請我吃飯喔。)", "日曜日に働くかわりに、月曜日休みます。(作為週日上班的交換，週一休息。)"]},
        {"grammar": "〜くせに", "meaning": "明明...卻... (帶有責備)", "examples": ["知っているくせに、教えてくれない。(明明知道卻不告訴我。)", "お金がないくせに、高いものを買う。(明明沒錢卻買昂貴的東西。)", "子供のくせに、生意気だ。(明明是個小孩卻很囂張。)"]},
        {"grammar": "〜たびに", "meaning": "每次...都...", "examples": ["この曲を聴くたびに、学生時代を思い出す。(每次聽這首歌，都會想起學生時代。)", "父は旅行のたびに、お土産を買ってきてくれる。(爸爸每次旅行都會買伴手禮回來。)", "会うたびに、彼女は綺麗になっていく。(每次見面，她都變得更漂亮。)"]},
        {"grammar": "〜ついでに", "meaning": "順便...", "examples": ["散歩のついでに、パンを買ってきて。(去散步的時候，順便買麵包回來。)", "郵便局へ行くついでに、銀行にも寄った。(去郵局的時候，順便繞去了銀行。)", "掃除のついでに、窓も拭きましょう。(打掃的時候，順便把窗戶也擦一擦吧。)"]},
        {"grammar": "〜最中に", "meaning": "正在...的時候", "examples": ["会議の最中に、携帯電話が鳴った。(正在開會的時候，手機響了。)", "シャワーを浴びている最中に、客が来た。(正在洗澡的時候，客人來了。)", "食事の最中に、大きな地震があった。(正在吃飯的時候，發生了大地震。)"]},
        {"grammar": "〜とおりに", "meaning": "按照... / 如同...", "examples": ["私が言うとおりに、書いてください。(請照著我說的寫。)", "説明書のとおりに、組み立てました。(按照說明書組裝了。)", "天気予報のとおりに、雨が降りました。(如同天氣預報說的，下雨了。)"]},
        {"grammar": "〜に違いない", "meaning": "一定是... (強烈推測)", "examples": ["夜遅くまで起きているから、眠いに違いない。(弄到這麼晚，一定很睏。)", "彼の話は嘘に違いない。(他說的話一定是謊言。)", "あんなに練習したんだから、優勝するに違いない。(練習了那麼多，一定會拿冠軍的。)"]}
    ],
    "N2": [
        {"grammar": "〜あげく", "meaning": "最後的結果是... (多為負面)", "examples": ["さんざん迷ったあげく、何も買わなかった。(猶豫了半天，最後什麼都沒買。)", "大喧嘩のあげく、二人は別れてしまった。(大吵一架後，兩人最後分手了。)", "待たされたあげく、チケットは売り切れだった。(被苦等了半天，結果票賣光了。)"]},
        {"grammar": "〜以上は", "meaning": "既然...就理所當然...", "examples": ["約束した以上は、守らなければならない。(既然答應了，就必須遵守。)", "学生である以上は、勉強が第一だ。(既然是學生，讀書就是第一要務。)", "引き受けた以上は、最後までやり遂げます。(既然接下了，就會貫徹到底。)"]},
        {"grammar": "〜一方だ", "meaning": "不斷地... (傾向發展)", "examples": ["日本の高齢化は進む一方だ。(日本的高齡化不斷在進展。)", "物価が上がる一方で、生活が苦しい。(物價不斷上漲，生活很苦。)", "彼の病気は悪化する一方だ。(他的病情不斷惡化。)"]},
        {"grammar": "〜かけだ", "meaning": "剛開始做... / 做到一半", "examples": ["テーブルの上に読みかけの本がある。(桌上有本看一半的書。)", "ご飯を食べかけた時、電話が鳴った。(剛開始吃飯時電話響了。)", "やりかけの仕事を終わらせてから帰ります。(把做一半的工作做完再回家。)"]},
        {"grammar": "〜がちだ", "meaning": "容易... / 往往會... (負面傾向)", "examples": ["最近、彼は授業を休みがちだ。(最近他很容易缺課。)", "冬は風邪を引きがちなので注意してください。(冬天容易感冒請多注意。)", "あの人は約束を忘れがちです。(那個人往往會忘記約定。)"]},
        {"grammar": "〜かねない", "meaning": "很有可能會... (擔心壞事發生)", "examples": ["そんなスピードで運転したら、事故を起こしかねない。(開那種速度的話，很有可能會發生事故。)", "彼の性格なら、そんなひどいことも言いかねない。(以他的個性，很有可能會說出那麼過分的話。)", "睡眠不足は大きなミスを招きかねない。(睡眠不足很有可能會招致大失誤。)"]},
        {"grammar": "〜気味（ぎみ）", "meaning": "有點...的感覺 / 傾向", "examples": ["最近、少し太り気味なので運動をしている。(最近覺得有點發胖傾向，所以在運動。)", "今日は少し風邪気味で、頭が痛い。(今天有點感冒的感覺，頭痛。)", "新入社員は緊張気味に挨拶をした。(新進員工帶著點緊張感打了招呼。)"]},
        {"grammar": "〜次第（しだい）", "meaning": "一...就馬上...", "examples": ["詳しいことが分かり次第、ご連絡します。(一知道詳細情況，就馬上聯絡您。)", "部屋の掃除が終わり次第、出かけましょう。(房間一打掃完，就出門吧。)", "社長が戻り次第、会議を始めます。(社長一回來，就馬上開會。)"]},
        {"grammar": "〜っこない", "meaning": "絕對不可能...", "examples": ["こんな難しい本、一日で読み終わりっこないよ。(這麼難的書，一天絕對不可能看完啦。)", "彼が私の気持ちなんて、分かりっこない。(他絕對不可能懂我的心情。)", "宝くじなんて当たりっこないよ。(彩券這種東西絕對不可能中的啦。)"]},
        {"grammar": "〜に決まっている", "meaning": "一定是... / 當然是...", "examples": ["あんなに勉強しなかったんだから、落ちるに決まっている。(都沒念書，當然一定會落榜。)", "彼が言っていることは嘘に決まっている。(他說的話一定是謊言。)", "そんな薄着では、寒いに決まっています。(穿那麼少，當然一定很冷。)"]}
    ],
    "N1": [
        {"grammar": "〜あっての", "meaning": "正因為有...才成立", "examples": ["お客様あっての商売ですから、感謝を忘れません。(正因為有顧客才有這門生意，絕不忘記感謝。)", "健康あっての人生だ。無理をしてはいけない。(正因為有健康才有的人生。不能勉強。)", "家族の支えあっての成功だった。(這成功是建立在有家人的支持上的。)"]},
        {"grammar": "〜いかんだ", "meaning": "取決於...", "examples": ["試合の結果は、明日の天気いかんだ。(比賽結果取決於明天的天氣。)", "採用されるかどうかは、面接での態度いかんだ。(是否被錄用取決於面試時的態度。)", "あなたの努力いかんで、夢は実現できる。(取決於你的努力，夢想是能實現的。)"]},
        {"grammar": "〜が早いか", "meaning": "一...就立刻... (極快)", "examples": ["チャイムが鳴るが早いか、生徒たちは教室を飛び出した。(鐘聲一響，學生們就立刻衝出教室。)", "彼はベッドに入るが早いか、いびきをかき始めた。(他一上床就立刻開始打呼。)", "社長は会社に着くが早いか、会議を始めた。(社長一到公司就立刻開始開會。)"]},
        {"grammar": "〜ごとく", "meaning": "就像...一樣", "examples": ["滝のごとく汗が流れ落ちた。(汗水如瀑布般流下。)", "烈火のごとく怒った。(氣得像烈火一樣。)", "彼は何もなかったかのごとく振る舞っている。(他表現得好像什麼都沒發生過一樣。)"]},
        {"grammar": "〜そばから", "meaning": "剛...就立刻... (反覆發生)", "examples": ["聞いたそばから忘れてしまう。(剛聽到就立刻忘記了。)", "片付けるそばから、子供がおもちゃを散らかす。(剛整理好，小孩就立刻把玩具弄亂。)", "教わるそばからミスをする。(剛學會就立刻犯錯。)"]},
        {"grammar": "〜ただならぬ", "meaning": "非同尋常的...", "examples": ["二人の間に、ただならぬ雰囲気が漂っていた。(兩人之間瀰漫著非同尋常的氣氛。)", "その事件には、ただならぬ背景があるようだ。(那起事件似乎有著不尋常的背景。)", "彼女の才能はただならぬものがある。(她的才華絕非常人。)"]},
        {"grammar": "〜たりとも", "meaning": "即使是一...也絕對不... (強調)", "examples": ["一秒たりとも無駄にはできない。(即使是一秒鐘也絕對不能浪費。)", "一滴たりとも水を飲んではいけない。(即使是一滴水也絕對不能喝。)", "敵には一歩たりとも譲らない。(對敵人絕對不讓步哪怕是一步。)"]},
        {"grammar": "〜てからというもの", "meaning": "自從...之後，就發生了很大的變化", "examples": ["新しいパソコンを買ってからというもの、仕事がずっと早くなった。(自從買了新電腦之後，工作變得快多了。)", "彼に会ってからというもの、毎日が楽しくて仕方がない。(自從遇見他之後，每天都開心得不得了。)", "タバコを辞めてからというもの、ご飯が美味しい。(自從戒菸之後，飯變得很好吃。)"]},
        {"grammar": "〜であれ", "meaning": "無論是...還是... / 就算是...", "examples": ["晴天であれ雨天であれ、試合は決行する。(無論是晴天還是雨天，比賽都會照常舉行。)", "相手が誰であれ、ルールは守らなければならない。(不管是誰，都必須遵守規則。)", "どんな理由であれ、遅刻は許されない。(無論什麼理由，都不允許遲到。)"]},
        {"grammar": "〜と相まって", "meaning": "與...相結合 / 加上...", "examples": ["美しい景色と相まって、素晴らしい旅行になった。(再加上美麗的風景，成了一趟美好的旅行。)", "彼の努力は運と相まって、大きな成功を生んだ。(他的努力加上運氣，造就了巨大的成功。)", "現代のデザインと伝統的な技術とが相まって、新しい製品が生まれた。(現代設計與傳統技術相結合，誕生了新產品。)"]}
    ]
}

# ==========================================
# 🌟 1. 獲取造句題目 API (加入資料庫防呆)
# ==========================================
@sentence_bp.route('/get_task', methods=['GET'])
def get_task():
    user_id = request.args.get('user_id', type=int)
    if not user_id: return jsonify({"error": "缺少 user_id"}), 400
        
    user = User.query.get(user_id)
    level = user.japanese_level if user and user.japanese_level else 'N3'
    if level not in GRAMMAR_DB: level = 'N3'
        
    selected_task = random.choice(GRAMMAR_DB[level])
    
    # 🌟 防呆機制：如果資料庫表格還沒建好，攔截錯誤，不要讓整個畫面空白
    today_count = 0
    try:
        today_count = SentencePracticeRecord.query.filter(
            SentencePracticeRecord.user_id == user_id,
            SentencePracticeRecord.created_at >= _today_start_utc()
        ).count()
    except Exception as e:
        print(f"⚠️ 無法計算今日次數 (可能尚未更新資料庫): {e}")
        # 出錯了也沒關係，先預設次數為 0
        today_count = 0
    
    return jsonify({
        "status": "success", 
        "data": selected_task,
        "level": level,
        "today_count": today_count,
        # 每日免費批改次數：免費版 3、Premium 10，教育版不限（App 依這兩個欄位顯示剩餘次數）
        "daily_limit": sentence_daily_limit(user) if user else 3,
        "unlimited": has_unlimited_usage(user),
    }), 200


# 讀音標記的兩種寫法：[漢字|かな]、漢字[かな]（AI 偶爾會用第二種），
# 再加上 AI 自己加的強調框 [リード]（沒有讀音，只去掉括號）
_RUBY_PATTERN = re.compile(
    r'\[([^|\]]+)\|[^\]]+\]|([一-鿿㐀-䶿々]+)\[[぀-ヿ]+\]|\[([^|\[\]]+)\]')


def _normalize_feedback(result):
    """整理 AI 批改結果，讓 App 能穩定分區顯示，也讓存進資料庫的內容維持純文字。

    - corrections 只留格式完整的前 5 筆
    - corrected_sentence 去掉讀音標記（歷史紀錄、老師後台都直接顯示這欄）
    - corrected_ruby 沒給就用 corrected_sentence
    - strict_feedback（存成 ai_feedback）由 corrections 組成條列文字，舊畫面照樣看得懂
    """
    if not isinstance(result, dict):
        raise ValueError("AI 回傳格式錯誤")
    corrections = []
    for c in result.get('corrections') or []:
        if isinstance(c, dict) and c.get('original') and c.get('corrected'):
            corrections.append({k: str(c.get(k) or '').strip() for k in ('original', 'corrected', 'reason')})
    corrections = corrections[:5]
    result['corrections'] = corrections

    ruby = str(result.get('corrected_ruby') or result.get('corrected_sentence') or '').strip()
    result['corrected_ruby'] = ruby
    result['corrected_sentence'] = _RUBY_PATTERN.sub(
        lambda m: m.group(1) or m.group(2) or m.group(3), str(result.get('corrected_sentence') or ruby)).strip()

    if corrections:
        result['strict_feedback'] = '\n'.join(
            f"{i}. {c['original']} → {c['corrected']}" + (f"：{c['reason']}" if c['reason'] else '')
            for i, c in enumerate(corrections, 1))
    elif not result.get('strict_feedback'):
        result['strict_feedback'] = str(result.get('summary') or '').strip()
    return result


# 選用單字加分：每用到一個選用的單字 +10 點，最多算 3 個（+30）。
# 原本寫在 AI 計分規則裡（基礎 60 分、每個單字 +10），但 AI 遇到好句子一律給 100，
# 有沒有用單字分數都一樣；現在改成 AI 分數只看文法，單字另外加在獎勵點數上。
VOCAB_BONUS_EACH = 10
VOCAB_BONUS_MAX_WORDS = 3


def _used_vocabs(sentence, selected, ai_used):
    """選用的單字實際有用到哪些：原形直接出現在句子裡，或 AI 判斷用到了它的變化形
    （例如選「食べる」寫「食べました」）。只承認使用者自己選的字，AI 多報的不算。"""
    ai = {str(w).strip() for w in (ai_used or []) if isinstance(w, str)}
    used = []
    for w in selected or []:
        w = str(w).strip()
        if w and w not in used and (w in (sentence or '') or w in ai):
            used.append(w)
    return used


# ==========================================
# 🌟 2. 極度嚴格的 AI 批改與結算 API (防彈升級版)
# ==========================================
@sentence_bp.route('/evaluate', methods=['POST'])
def evaluate_sentence():
    data = request.get_json()
    user_id = data.get('user_id')
    grammar_point = data.get('grammar_point')
    selected_vocabs = data.get('selected_vocabs', [])
    user_sentence = data.get('user_sentence')
    pay_with_points = data.get('pay_with_points', False) 

    if not all([user_id, grammar_point, user_sentence]):
        return jsonify({"error": "缺少必要參數"}), 400

    user = User.query.get(user_id)
    
    # 🌟 防呆 1：安全檢查今日次數 (如果出錯就不阻擋)
    if not user:
        return jsonify({"error": "找不到此使用者"}), 404

    today_count = 0
    try:
        today_count = SentencePracticeRecord.query.filter(
            SentencePracticeRecord.user_id == user_id,
            SentencePracticeRecord.created_at >= _today_start_utc()
        ).count()
    except Exception as e:
        print(f"⚠️ 無法計算今日次數，跳過檢查: {e}")

    # 檢查免費次數與扣點機制。教育版學生完全跳過：不限次數也不扣點。
    paid = False
    daily_limit = sentence_daily_limit(user)
    if today_count >= daily_limit and not is_payment_free(user):
        if not pay_with_points:
            return jsonify({"status": "quota_exceeded", "error": "今日免費次數已用盡",
                            "daily_limit": daily_limit}), 400
        if (user.j_pts or 0) < PAID_SENTENCE_COST:
            return jsonify({"status": "insufficient_points", "error": "點數不足"}), 400

        # 確定支付，先扣點（避免同時送出好幾次都只檢查到同一份餘額），AI 批改失敗再退回。
        # 扣點要記交易紀錄，App 的交易紀錄才查得到這筆消費。
        user.j_pts -= PAID_SENTENCE_COST
        db.session.add(PointTransaction(
            user_id=user.id,
            points=-PAID_SENTENCE_COST,
            price=0,
            payment_method='points',
            transaction_type=TransactionType.SPEND,
            related_feature='sentence_extra',
        ))
        db.session.commit()
        paid = True

    level = user.japanese_level if user and user.japanese_level else 'N3'
    
    # 改走新版 SDK（gemini_client.generate_content）：金鑰與備援模型自動切換、塞車自動重試，
    # 與拍照辨識、AI 對話一致；舊版 google.generativeai 已停止維護且沒有備援。
    def _analyze():
        vocab_str = ", ".join(selected_vocabs) if selected_vocabs else "未選用單字"
        
        prompt = f"""
        你是一位極度嚴格的日語文法老師。
        【指定文法】：{grammar_point}
        【指定單字】：{vocab_str}
        【學生的造句】：{user_sentence}

        計分(滿分100)：只看文法與自然度，從 100 分開始扣：助詞錯扣5分，變形錯扣10分，語意不通扣20分。
        未正確使用「指定文法」直接不及格（59 分以下）。指定單字有沒有用到不影響分數（系統另外加點）。
        used_vocabs：列出【指定單字】中，句子裡真的有用到的（含動詞、形容詞的變化形），照抄指定單字的寫法；沒用到就給空陣列。
        
        App 會把結果拆成「總評、修改建議、參考句子」分區顯示，每個欄位只放該放的內容：
        - summary：一句總評（30 字以內），不要在這裡重複解釋錯誤。
        - corrections：每一個要改的地方一筆（最多 5 筆，完全正確就給空陣列）：
            original 是學生句子中要改的那一小段（照抄，不加讀音標記）、
            corrected 是改成的寫法（不加讀音標記）、
            reason 用一句話說明錯在哪（30 字以內，例如「助詞錯誤：表示地點要用で」）。
        - corrected_sentence：修正後的完整句子，純文字，不加讀音標記。
        - corrected_ruby：同一句，但漢字一律用 [漢字|平假名] 標記讀音，例如 [犬|いぬ]に、[新|あたら]しい。
          方括號只能用來標讀音，片假名、平假名和指定單字都不要加方括號（不要寫成 [リード]）。
        - translation：修正後句子的繁體中文翻譯。
        所有說明用繁體中文，不要夾雜英文術語，不要用 markdown 符號。
        請以純 JSON 格式回傳（絕對不可加 Markdown 標籤）：
        {{
            "score": 85,
            "is_grammar_correct": false,
            "used_vocabs": ["公園"],
            "summary": "有用到指定文法，助詞再注意一下就更好了。",
            "corrections": [
                {{"original": "公園に", "corrected": "公園で", "reason": "助詞錯誤：表示動作地點要用で"}}
            ],
            "corrected_sentence": "公園で友達と遊びました。",
            "corrected_ruby": "[公園|こうえん]で[友達|ともだち]と[遊|あそ]びました。",
            "translation": "在公園和朋友玩了。"
        }}
        """
        response = gemini_client.generate_content('article', prompt, config=JSON_CONFIG)
        match = re.search(r'\{.*\}', response.text or '', re.DOTALL)
        if match: return parse_gemini_json(match.group(0))
        raise ValueError("AI 回傳格式錯誤")

    try:
        # 交由 Gemini 批改
        result = _normalize_feedback(_analyze())
        score = result.get('score', 0)
        base_points = 50 if score >= 90 else (30 if score >= 80 else (10 if score >= 60 else 5))
        # 單字加分：及格（60 分以上）才給，避免把單字硬塞進不通的句子來拿點數
        used = _used_vocabs(user_sentence, selected_vocabs, result.get('used_vocabs'))
        vocab_bonus = VOCAB_BONUS_EACH * min(len(used), VOCAB_BONUS_MAX_WORDS) if score >= 60 else 0
        points_earned = base_points + vocab_bonus
        # 校園教育版學生沒有點數：批改照常、不發獎勵，紀錄直接標成已領取（歷史頁不會出現「領取」）
        if not uses_points(user):
            base_points = vocab_bonus = points_earned = 0
        result['used_vocabs'] = used
        result['unused_vocabs'] = [w for w in (selected_vocabs or []) if w not in used]
        result['base_points'] = base_points
        result['vocab_bonus'] = vocab_bonus

        # 🌟 防呆 2：安全寫入資料庫
        record_id = None
        try:
            new_record = SentencePracticeRecord(
                user_id=user_id,
                grammar_point=grammar_point,
                selected_vocabs=selected_vocabs,
                user_sentence=user_sentence,
                corrected_sentence=result.get('corrected_sentence', ''),
                ai_feedback=result.get('strict_feedback', ''),
                score=score,
                points_earned=points_earned,
                is_claimed=not uses_points(user)
            )
            db.session.add(new_record)
            db.session.commit()
            record_id = new_record.id
        except Exception as e:
            db.session.rollback()
            print(f"⚠️ 歷史紀錄寫入資料庫失敗 (表格可能未建立): {e}")
            # 💡 即使沒存入資料庫，依然會回傳批改結果給畫面，不讓前端卡死

        # 📊 更新小組造句進度（若使用者所在小組的目標是 'sentences'）
        try:
            add_group_progress_and_check_reward(user_id, 'sentences', 1)
        except Exception as ge:
            print(f"⚠️ 更新小組造句進度失敗（不影響批改結果）：{ge}")

        result['points_earned'] = points_earned
        result['record_id'] = record_id  # 作業繳交用的作答紀錄 id（寫入失敗時為 None）

        # 從作業進來的造句：批改完直接繳交。繳交失敗（例如沒用到指定單字）
        # 不影響批改結果本身，只在 assignment_result 裡說明原因。
        from services.student_assignment import auto_submit
        assignment_result = auto_submit(user_id, data.get('assignment_id'), record_id)
        if assignment_result is not None:
            result['assignment_result'] = assignment_result

        result['status'] = 'success'
        return jsonify(result), 200
    except Exception as e:
        db.session.rollback()
        if paid:
            # AI 沒批改成功，付費的點數要還給使用者
            try:
                user.j_pts = (user.j_pts or 0) + PAID_SENTENCE_COST
                db.session.add(PointTransaction(
                    user_id=user.id,
                    points=PAID_SENTENCE_COST,
                    price=0,
                    payment_method='points',
                    transaction_type=TransactionType.REWARD,
                    related_feature='sentence_extra_refund',
                ))
                db.session.commit()
            except Exception as re_err:
                db.session.rollback()
                print(f"⚠️ 退還造句點數失敗：{re_err}")
        return jsonify({"error": str(e)}), 500


# ==========================================
# 🌟 3. 獲取造句歷史紀錄 API
# ==========================================
@sentence_bp.route('/history/<int:user_id>', methods=['GET'])
def get_history(user_id):
    records = SentencePracticeRecord.query.filter_by(user_id=user_id).order_by(SentencePracticeRecord.created_at.desc()).all()
    data = []
    for r in records:
        data.append({
            "id": r.id,
            "grammar_point": r.grammar_point,
            "user_sentence": r.user_sentence,
            "corrected_sentence": r.corrected_sentence,
            "ai_feedback": r.ai_feedback,
            "score": r.score,
            "points_earned": r.points_earned,
            "is_claimed": r.is_claimed,
            "date": r.created_at.strftime('%m-%d %H:%M')
        })
    return jsonify({"status": "success", "data": data}), 200


# ==========================================
# 🌟 4. 領取造句獎勵點數 API
# ==========================================
@sentence_bp.route('/claim', methods=['POST'])
def claim_points():
    data = request.get_json()
    record = SentencePracticeRecord.query.get(data.get('record_id'))
    user = User.query.get(data.get('user_id'))
    
    if not record or not user or record.is_claimed:
        return jsonify({"error": "無法領取或已領取過"}), 400
    # 只能領自己的紀錄，否則拿到別人的 record_id 就能把對方的點數領走
    if record.user_id != user.id:
        return jsonify({"error": "無法領取這筆紀錄"}), 403

    # 標記為已領取，並真正把點數加給玩家
    record.is_claimed = True
    user.j_pts = (user.j_pts or 0) + (record.points_earned or 0)
    # 獎勵也記一筆交易紀錄（跟每日任務、朗讀獎勵一樣）
    if record.points_earned:
        db.session.add(PointTransaction(
            user_id=user.id,
            points=record.points_earned,
            price=0,
            payment_method='sentence_reward',
            transaction_type=TransactionType.REWARD,
            related_feature='sentence_score_reward',
        ))
    db.session.commit()
    
    return jsonify({"status": "success", "total_points": user.j_pts}), 200