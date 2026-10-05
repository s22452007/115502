"""拍照、對話作業的「AI 建議分數」。

建議分數只給老師參考：存在 AssignmentSubmission.ai_score / ai_feedback，
老師在批閱頁確認（按儲存）後才寫進 score、計入成績。AI 判斷不準也不會直接影響學生成績。

拍照作業（規則為主，AI 只判斷主題）：
    完成任務 60（達到最少單字數才交得出來，所以交了就有）
    符合主題 0～30（AI 判斷辨識出的單字跟老師指定主題的關聯；沒指定主題就給滿分）
    額外單字 0～10（超過最少單字數的部分，每多一個 +2）
對話作業（AI 依評分標準）：
    文法正確 40、自然流暢 20、任務完成 30、投入程度 10

評分在背景執行（繳交當下不讓學生等 AI），失敗就留空，老師照常自己給分。
"""
import json
import threading

from flask import current_app

from utils.db import db
from utils import gemini_client
from utils.ai_helper import JSON_CONFIG, parse_gemini_json

# 測試時改成同步執行
RUN_IN_BACKGROUND = True


def _clamp(value, top):
    try:
        v = int(round(float(value)))
    except (TypeError, ValueError):
        v = 0
    return max(0, min(top, v))


def _ask_ai(prompt):
    response = gemini_client.generate_content('tutor', prompt, config=JSON_CONFIG)
    data = parse_gemini_json(response.text)
    if not isinstance(data, dict):
        raise ValueError('AI 回傳格式不正確')
    return data


# ---------------------------------------------------------------- 拍照作業
def suggest_photo(assignment, photo):
    config = assignment.config or {}
    need = int(config.get('min_vocab_count') or 0)
    words = [pv.vocab.word for pv in (photo.photo_vocabs or []) if pv.vocab]
    got = len(words)
    theme = (config.get('theme') or '').strip()

    items = [{'label': '完成任務', 'score': 60, 'max': 60,
              'reason': f'辨識出 {got} 個單字，達到最少 {need} 個的要求'}]

    if theme:
        prompt = f'''
老師出了一份拍照學日文的作業，指定主題是「{theme}」。
學生拍的照片，AI 辨識出這些日文單字：{'、'.join(words) or '（無）'}
照片標題：{photo.custom_title or '（無）'}；學生描述的情境：{photo.context_description or '（無）'}

請判斷這張照片符不符合指定主題，給 0～30 分：
30 分＝大部分單字都明顯屬於這個主題；15 分＝部分相關；0 分＝跟主題無關。
reason 用一句繁體中文說明（30 字以內），直接寫給老師看。

請「嚴格」以下列 JSON 格式回傳，不可加上 markdown 標籤：
{{"score": 0, "reason": ""}}
'''
        data = _ask_ai(prompt)
        items.append({'label': '符合主題', 'score': _clamp(data.get('score'), 30), 'max': 30,
                      'reason': str(data.get('reason') or '').strip()})
    else:
        items.append({'label': '符合主題', 'score': 30, 'max': 30, 'reason': '老師沒有指定主題'})

    extra = max(0, got - need)
    items.append({'label': '額外單字', 'score': min(10, extra * 2), 'max': 10,
                  'reason': f'比要求多辨識出 {extra} 個單字' if extra else '剛好達到要求的單字數'})

    total = sum(i['score'] for i in items)
    comment = '照片符合作業要求。' if total >= 85 else '照片與主題的關聯可以再加強。'
    return total, {'items': items, 'comment': comment}


# ---------------------------------------------------------------- 對話作業
CHAT_RUBRIC = [
    ('grammar', '文法正確', 40, '助詞、動詞變化等文法有沒有錯'),
    ('natural', '自然流暢', 20, '說法是否自然、符合情境的禮貌程度'),
    ('task', '任務完成', 30, '有沒有完成這個情境要做的事（例如真的點到餐、問到路）'),
    ('effort', '投入程度', 10, '句子長度與內容是否用心，不是只回一兩個字'),
]


def suggest_chat(assignment, topic, messages):
    """messages：[(role, 文字)]，role 是 'user'（學生）或其他（AI 角色）"""
    topic = (assignment.config or {}).get('topic') or topic or ''
    transcript = '\n'.join(f"{'學生' if role == 'user' else 'AI 角色'}：{text}" for role, text in messages)
    rubric = '\n'.join(f'- {key}（{label}，0～{top} 分）：{desc}' for key, label, top, desc in CHAT_RUBRIC)
    keys = ', '.join(f'"{key}": {{"score": 0, "reason": ""}}' for key, *_ in CHAT_RUBRIC)

    prompt = f'''
你是日文老師，請替學生的日文情境對話作業評分。只評「學生」說的話，AI 角色的話不用評。
情境主題：「{topic}」

評分標準：
{rubric}

每一項的 reason 用一句繁體中文說明（30 字以內），舉出學生句子裡具體的優點或錯誤。
comment 寫一句給老師看的總評（40 字以內）。不要用 markdown 符號。

請「嚴格」以下列 JSON 格式回傳，不可加上 markdown 標籤：
{{{keys}, "comment": ""}}

對話紀錄：
{transcript}
'''
    data = _ask_ai(prompt)
    items = []
    for key, label, top, _ in CHAT_RUBRIC:
        part = data.get(key) if isinstance(data.get(key), dict) else {}
        items.append({'label': label, 'score': _clamp(part.get('score'), top), 'max': top,
                      'reason': str(part.get('reason') or '').strip()})
    total = sum(i['score'] for i in items)
    return total, {'items': items, 'comment': str(data.get('comment') or '').strip()}


# ---------------------------------------------------------------- 產生並存檔
def generate_suggestion(submission_id):
    """算出這份繳交的 AI 建議分數並存檔；不是拍照、對話題，或找不到作答紀錄就略過。"""
    from models import (AssignmentSubmission, Assignment, TaskType, UserPhoto,
                        ChatSession, ChatMessage)
    from services.teacher_service import strip_furigana  # 對話內容去掉讀音標記再給 AI 看

    sub = AssignmentSubmission.query.get(submission_id)
    if sub is None or not sub.result_ref_id:
        return None
    assignment = Assignment.query.get(sub.assignment_id)
    if assignment is None:
        return None

    if assignment.task_type == TaskType.PHOTO:
        photo = UserPhoto.query.get(sub.result_ref_id)
        if photo is None:
            return None
        score, feedback = suggest_photo(assignment, photo)
    elif assignment.task_type == TaskType.CHAT:
        session = ChatSession.query.get(sub.result_ref_id)
        if session is None:
            return None
        messages = [(m.role, strip_furigana(m.content)) for m in
                    ChatMessage.query.filter_by(session_id=session.id)
                    .order_by(ChatMessage.created_at, ChatMessage.id).all()]
        score, feedback = suggest_chat(assignment, session.topic, messages)
    else:
        return None

    sub.ai_score = score
    sub.ai_feedback = feedback
    db.session.commit()
    return score


def _run(submission_id):
    try:
        score = generate_suggestion(submission_id)
        if score is not None:
            print(f'✅ 作業繳交 #{submission_id} 的 AI 建議分數：{score}')
    except Exception as e:
        db.session.rollback()
        # 建議分數只是參考，失敗就留空，老師照常自己給分
        print(f'⚠️ 作業繳交 #{submission_id} 的 AI 建議分數產生失敗：{e}')


def _run_in_thread(app, submission_id):
    with app.app_context():
        try:
            _run(submission_id)
        finally:
            db.session.remove()


def suggest_in_background(submission_id):
    """繳交後呼叫：在背景算 AI 建議分數（要在 request 裡呼叫才拿得到 app）。"""
    if RUN_IN_BACKGROUND:
        app = current_app._get_current_object()
        threading.Thread(target=_run_in_thread, args=(app, submission_id), daemon=True).start()
    else:
        _run(submission_id)
