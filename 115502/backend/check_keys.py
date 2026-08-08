# -*- coding: utf-8 -*-
"""
API 金鑰設定檢查工具。

貼完金鑰到 .env 之後執行這支程式，可以確認：
  1. 每個 AI 功能各自找到幾把金鑰
  2. 金鑰是不是真的能用（實際呼叫一次 Gemini 測試）
  3. 備用金鑰有沒有跟主金鑰用到同一個帳號（那樣就沒有備用效果）

用法：
    cd backend
    python check_keys.py           # 只檢查設定，不呼叫 API
    python check_keys.py --test    # 額外實際測試每把金鑰能不能用（會消耗少量額度）

⚠️ 本程式只會顯示金鑰的前幾碼，不會印出完整金鑰。
"""
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from utils import gemini_client as gc  # noqa: E402


def mask(key):
    """只顯示前 8 碼，避免完整金鑰外流"""
    return f'{key[:8]}...（共 {len(key)} 碼）'


def main():
    do_test = '--test' in sys.argv

    print('=' * 56)
    print(' API 金鑰設定檢查')
    print('=' * 56)

    all_keys_seen = {}   # 金鑰 -> 使用它的功能清單
    problems = []

    for feature, label in gc.FEATURE_LABELS.items():
        keys = gc.get_keys(feature)
        print(f'\n【{label}】')

        if not keys:
            print('  ❌ 找不到任何金鑰！這個功能無法使用。')
            problems.append(f'{label}：完全沒有設定金鑰')
            continue

        for i, key in enumerate(keys):
            role = '主金鑰' if i == 0 else f'備用 {i}'
            print(f'  {role}：{mask(key)}')
            all_keys_seen.setdefault(key, []).append(label)

        if len(keys) == 1:
            print('  ⚠️ 只有一把金鑰，額度用完就沒有備援了')
            problems.append(f'{label}：沒有設定備用金鑰')

        # 檢查主金鑰與備用金鑰是不是同一把
        if len(keys) > 1 and keys[0] == keys[1]:
            print('  ⚠️ 主金鑰與備用金鑰相同，等於沒有備用！')
            problems.append(f'{label}：主/備用金鑰重複')

    # 檢查同一把金鑰是否被多個功能共用
    print('\n' + '-' * 56)
    shared = {k: v for k, v in all_keys_seen.items() if len(v) > 1}
    if shared:
        print('⚠️ 以下金鑰被多個功能共用，額度會互相排擠：')
        for key, features in shared.items():
            print(f'   {mask(key)} → {"、".join(features)}')
        problems.append('有金鑰被多個功能共用')
    else:
        print('✅ 每個功能都使用各自獨立的金鑰')

    # 實際測試每把金鑰
    if do_test:
        print('\n' + '=' * 56)
        print(' 實際連線測試（每把金鑰呼叫一次）')
        print('=' * 56)
        for key in all_keys_seen:
            用途 = '、'.join(all_keys_seen[key])
            try:
                from google import genai
                client = genai.Client(api_key=key)
                client.models.generate_content(
                    model=gc.DEFAULT_MODEL, contents='hi')
                print(f'  ✅ {mask(key)}  可正常使用（{用途}）')
            except Exception as e:
                if gc.is_quota_error(e):
                    print(f'  ⚠️ {mask(key)}  額度已用完（{用途}）')
                    problems.append(f'{用途} 的金鑰額度已用完')
                else:
                    print(f'  ❌ {mask(key)}  無法使用：{str(e)[:80]}')
                    problems.append(f'{用途} 的金鑰無效')
    else:
        print('\n💡 想確認金鑰是否真的能用，請執行：python check_keys.py --test')

    # 總結
    print('\n' + '=' * 56)
    if problems:
        print(' 需要注意的地方：')
        for p in problems:
            print(f'   • {p}')
        print('\n 提醒：備用金鑰請用「不同的 Google 帳號」申請，')
        print('       額度是綁帳號的，同帳號的金鑰額度共用。')
    else:
        print(' 🎉 設定完全正確，每個功能都有獨立的主金鑰與備用金鑰！')
    print('=' * 56)


if __name__ == '__main__':
    main()
