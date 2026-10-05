# -*- coding: utf-8 -*-
"""
產生腔調試聽音檔（每種啟用中的腔調 × 女聲／男聲），存到 static/dialect_samples/。

用法：
    python generate_dialect_samples.py          # 只補還沒有的音檔
    python generate_dialect_samples.py --force  # 全部重新產生
    python generate_dialect_samples.py --force --only female  # 只重新產生女聲（或 male）

語音模型的免費額度很少，額度用完時會停下來，隔天再跑一次就會從缺的繼續補。
"""
import os
import sys

from flask import Flask

from models import db, Dialect
from services.dialect import SAMPLE_DIR, SAMPLE_VOICES, sample_url
from services.tts import synthesize_with_gemini

# 各腔調的試聽句子（沒列到的腔調用標準語那句）
SAMPLE_TEXTS = {
    '標準語': 'こんにちは！今日は一緒に日本語を練習しましょう。きっと楽しいですよ。',
    '関西弁': 'まいど！今日は一緒に日本語を練習しよか。めっちゃ楽しいで。',
    '博多弁': 'こんにちは！今日は一緒に日本語ば練習しようや。ばり楽しかよ。',
    '東北弁': 'こんにちは！今日は一緒に日本語を練習すっぺ。楽しいべ。',
    '沖縄弁': 'はいさい！今日は一緒に日本語を練習しようねー。楽しいさぁ。',
}

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def main():
    force = '--force' in sys.argv
    only = sys.argv[sys.argv.index('--only') + 1] if '--only' in sys.argv else None
    app = Flask(__name__)
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(_BASE_DIR, 'instance', 'jlens.db')
    db.init_app(app)
    os.makedirs(SAMPLE_DIR, exist_ok=True)

    missing = 0
    with app.app_context():
        for d in Dialect.query.filter_by(is_active=True).order_by(Dialect.id).all():
            text = SAMPLE_TEXTS.get(d.jp_name, SAMPLE_TEXTS['標準語'])
            for voice in SAMPLE_VOICES:
                if only and voice != only:
                    continue
                if not force and sample_url(d.id, voice):
                    print(f'✅ 已存在：{d.name} {voice}')
                    continue
                data, ext = synthesize_with_gemini(text, d.jp_name, voice), 'wav'
                if not data:
                    print(f'⚠️ 產生失敗（多半是額度用完，明天再跑一次）：{d.name} {voice}')
                    missing += 1
                    continue
                with open(os.path.join(SAMPLE_DIR, f'{d.id}_{voice}.{ext}'), 'wb') as f:
                    f.write(data)
                # 舊版標準語女聲是 gTTS 的 mp3，換成 AI 語音後把舊檔刪掉
                old_mp3 = os.path.join(SAMPLE_DIR, f'{d.id}_{voice}.mp3')
                if os.path.exists(old_mp3):
                    os.remove(old_mp3)
                print(f'🎧 已產生：{d.name} {voice}')

    print('全部完成！' if missing == 0 else f'還有 {missing} 個音檔沒產生。')


if __name__ == '__main__':
    main()
