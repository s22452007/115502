"""N5～N1 只是系統內部的參考分級，不代表真正的日語檢定程度，畫面上一律不直接顯示代碼。

- 內容難度（文章、測驗題、造句題）：入門／初級／中級／中高級／高級
- 使用者程度：跟 App 一樣用稱號（新手上路…日語大師）

資料庫與程式判斷仍然存 N5～N1，只有顯示時經過這裡轉換。
"""

LEVEL_LABELS = {'N5': '入門', 'N4': '初級', 'N3': '中級', 'N2': '中高級', 'N1': '高級'}
LEVEL_TITLES = {'N5': '新手上路', 'N4': '生活達人', 'N3': '交流無礙', 'N2': '商務菁英', 'N1': '日語大師'}


def level_label(code):
    """內容難度的顯示名稱；不是 N5～N1 的（例如「超級新手」）照原樣顯示"""
    if code is None:
        return ''
    return LEVEL_LABELS.get(str(code).strip().upper(), str(code))


def level_title(code):
    """使用者程度的稱號；還沒設定程度就顯示「尚未設定」"""
    if not code:
        return '尚未設定'
    return LEVEL_TITLES.get(str(code).strip().upper(), str(code))
