"""文章的讀音（振假名）標記：<ruby>漢字<rt>かんじ</rt></ruby>。

後台新增文章時，管理者原本要自己一個一個包 ruby 標籤，很難寫。
add_ruby() 請 AI 幫全文的漢字加上讀音，並檢查 AI 只加了標記、沒有改動原文：
把標記拿掉後必須跟原文一字不差，不然就不採用，避免 AI 順手「修正」文章內容。
"""
import re

from utils import gemini_client
from utils.ai_helper import JSON_CONFIG, parse_gemini_json

_KANJI = re.compile(r'[一-鿿㐀-䶿々〆ヶ]')


class RubyError(Exception):
    """自動標註／翻譯失敗（訊息可以直接顯示給管理者）"""


def strip_ruby(text):
    """拿掉讀音標記，只留下原文：<ruby>漢字<rt>かんじ</rt></ruby> → 漢字"""
    text = re.sub(r'<rt>.*?</rt>', '', text or '', flags=re.DOTALL)
    text = re.sub(r'<rp>.*?</rp>', '', text, flags=re.DOTALL)
    return re.sub(r'</?ruby>', '', text)


def _well_formed(text):
    """每個 <ruby> 都要成對，而且裡面剛好一組 <rt>…</rt>"""
    blocks = re.findall(r'<ruby>(.*?)</ruby>', text, flags=re.DOTALL)
    if text.count('<ruby>') != len(blocks) or text.count('</ruby>') != len(blocks):
        return False
    for b in blocks:
        m = re.fullmatch(r'([^<]+)<rt>([^<]+)</rt>', b)
        if not m:
            return False
    # 標記外面不能有落單的 <rt>
    outside = re.sub(r'<ruby>.*?</ruby>', '', text, flags=re.DOTALL)
    return '<rt>' not in outside and '</rt>' not in outside


def _build_prompt(plain):
    return f'''
請在下面這段日文中，替「每一個含有漢字的詞」加上讀音標記，格式是 <ruby>漢字<rt>平假名讀音</rt></ruby>。
規則：
1. 只能加標記。原文其他任何字（標點、空白、換行、平假名、片假名、英數字）都不能修改、不能增加、不能刪除。
2. 讀音一律用平假名，並依文意判斷正確讀法（例如 今日→きょう、一人→ひとり、日本→にほん）。
3. 送假名（漢字後面的平假名）不要包進標記：食べます → <ruby>食<rt>た</rt></ruby>べます。
4. 片假名、平假名、數字、英文都不要加標記。
5. 一個詞可以整個包起來（例如 <ruby>毎日<rt>まいにち</rt></ruby>），不必一字一字拆開。

請「嚴格」以下列 JSON 格式回傳，不可加上 markdown 標籤：
{{"content": "加好讀音標記的全文"}}

原文：
{plain}
'''


def add_ruby(text):
    """回傳 (加好標記的全文, 標了幾個詞)。原文已經有標記的話會先拿掉、整篇重新標註。"""
    plain = strip_ruby(text).strip()
    if not plain:
        raise RubyError('請先輸入日文內容')
    if not _KANJI.search(plain):
        return plain, 0  # 沒有漢字，不用標

    try:
        response = gemini_client.generate_content('article', _build_prompt(plain), config=JSON_CONFIG)
        data = parse_gemini_json(response.text)
    except gemini_client.GeminiQuotaExhausted as e:
        raise RubyError(str(e))
    except Exception as e:
        print(f'⚠️ 自動標註讀音失敗：{e}')
        raise RubyError('AI 暫時無法標註，請稍後再試一次')

    content = (data or {}).get('content') if isinstance(data, dict) else None
    content = (content or '').strip()
    if not content or not _well_formed(content):
        raise RubyError('AI 回傳的格式不正確，請再試一次')
    if strip_ruby(content) != plain:
        raise RubyError('AI 改動了原文內容，結果沒有採用，請再試一次')
    return content, content.count('<ruby>')


def translate_to_zh(text):
    """把文章（可以含讀音標記）翻成繁體中文，給後台「自動產生中文翻譯」用。"""
    plain = strip_ruby(text).strip()
    if not plain:
        raise RubyError('請先輸入日文內容')
    prompt = f'''
請把下面這段日文翻譯成台灣慣用的繁體中文，給日語學習者對照閱讀用。
規則：
1. 意思要忠實、語句通順自然，不要加入原文沒有的內容，也不要加註解或說明。
2. 保留原文的段落與換行。
3. 人名、地名照常見譯法。

請「嚴格」以下列 JSON 格式回傳，不可加上 markdown 標籤：
{{"translation": "中文翻譯全文"}}

原文：
{plain}
'''
    try:
        response = gemini_client.generate_content('article', prompt, config=JSON_CONFIG)
        data = parse_gemini_json(response.text)
    except gemini_client.GeminiQuotaExhausted as e:
        raise RubyError(str(e))
    except Exception as e:
        print(f'⚠️ 自動翻譯失敗：{e}')
        raise RubyError('AI 暫時無法翻譯，請稍後再試一次')
    translation = ((data or {}).get('translation') if isinstance(data, dict) else '') or ''
    translation = str(translation).strip()
    if not translation:
        raise RubyError('AI 沒有回傳翻譯，請再試一次')
    return translation


def _clean_cell(value):
    """表單是「a | b | c」一行一筆，值裡面不能有直線或換行，不然會被切錯欄位"""
    return ' '.join(str(value or '').replace('|', '／').split())


def extract_points(text, level='N5'):
    """從文章挑出重點文法與重點單字，回傳 {'grammars': [...], 'vocabularies': [...]}。

    單字只保留真的出現在文章裡的（App 才能把它標成可點的綠色字），文法最多 4 個、單字最多 8 個。
    """
    plain = strip_ruby(text).strip()
    if not plain:
        raise RubyError('請先輸入日文內容')
    prompt = f'''
你是日文老師，請從下面這篇 {level} 程度的日文文章，挑出適合學習者學的重點。
規則：
1. 重點文法 2～4 個：expression 寫文法形式（例如「〜ています」），meaning 用繁體中文簡短說明用法，
   example 從文章裡挑一句用到這個文法的句子（照抄原文）。
2. 重點單字 3～8 個：word 必須是文章裡「一字不差」出現過的寫法，reading 寫平假名讀音，meaning 寫繁體中文意思。
   以文章裡的漢字詞（例如「毎日」「大切」）或片假名詞（例如「コーヒー」）為主，
   不要挑帶有活用語尾的動詞、形容詞（例如「食べます」「美味しい」），也不要挑助詞。
   優先挑跟 {level} 程度相符、對理解文章有幫助的詞。
3. 不要用 markdown 符號。

請「嚴格」以下列 JSON 格式回傳，不可加上 markdown 標籤：
{{"grammars": [{{"expression": "", "meaning": "", "example": ""}}],
  "vocabularies": [{{"word": "", "reading": "", "meaning": ""}}]}}

文章：
{plain}
'''
    try:
        response = gemini_client.generate_content('article', prompt, config=JSON_CONFIG)
        data = parse_gemini_json(response.text)
    except gemini_client.GeminiQuotaExhausted as e:
        raise RubyError(str(e))
    except Exception as e:
        print(f'⚠️ 自動產生重點失敗：{e}')
        raise RubyError('AI 暫時無法產生，請稍後再試一次')
    if not isinstance(data, dict):
        raise RubyError('AI 回傳的格式不正確，請再試一次')

    grammars = []
    for g in data.get('grammars') or []:
        if isinstance(g, dict) and g.get('expression'):
            grammars.append({k: _clean_cell(g.get(k)) for k in ('expression', 'meaning', 'example')})
    # App 只會把「整個被讀音標記包住的詞」或「標記外面的一般文字」標成綠色，
    # 例如 <ruby>食<rt>た</rt></ruby>べます 裡的「食べます」跨過標記，就標不到
    if '<ruby>' in (text or ''):
        bases = set(re.findall(r'<ruby>([^<]+)<rt>', text))
        # 把標記整段換成分隔符號，剩下的就是標記外面的一般文字（分隔符號避免前後文字黏成一個詞）
        outside = re.sub(r'<ruby>.*?</ruby>', '\u0000', text, flags=re.DOTALL)
        def highlightable(w):
            return w in bases or w in outside
    else:
        def highlightable(w):
            return w in plain

    vocabularies, seen = [], set()
    for v in data.get('vocabularies') or []:
        if not isinstance(v, dict):
            continue
        word = _clean_cell(v.get('word'))
        # 文章裡沒出現的字，App 沒辦法標綠色，就不採用
        if not word or word in seen or not highlightable(word):
            continue
        seen.add(word)
        reading = _clean_cell(v.get('reading'))
        if re.fullmatch(r'[゠-ヿー]+', word):
            reading = word  # 片假名詞本身就是讀音，不要改寫成平假名（パン → ぱん 很奇怪）
        vocabularies.append({'word': word, 'reading': reading, 'meaning': _clean_cell(v.get('meaning'))})
    if not grammars and not vocabularies:
        raise RubyError('AI 沒有挑出重點，請再試一次')
    return {'grammars': grammars[:4], 'vocabularies': vocabularies[:8]}
