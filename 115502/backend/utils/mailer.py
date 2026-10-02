"""寄送 Email（目前用於忘記密碼的驗證碼）。

設定放在 .env：
    SMTP_USER   寄件用的 Gmail 帳號
    SMTP_PASS   該帳號的「應用程式密碼」（不是登入密碼）
    SMTP_HOST   預設 smtp.gmail.com
    SMTP_PORT   預設 465（SSL）
"""
import os
import smtplib
from email.message import EmailMessage
from email.utils import formataddr

from dotenv import load_dotenv

# 自己讀一次 backend/.env，不依賴其他模組先載入（已經設定的環境變數不覆蓋，Docker 注入的值優先）
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env'))


class MailNotConfigured(Exception):
    """還沒設定寄信帳號"""


def is_configured():
    return bool(os.getenv('SMTP_USER') and os.getenv('SMTP_PASS'))


def send_mail(to, subject, body):
    """寄出純文字信件；沒有設定寄信帳號時丟出 MailNotConfigured，寄送失敗時丟出原本的例外。"""
    user = os.getenv('SMTP_USER')
    password = os.getenv('SMTP_PASS')
    if not user or not password:
        raise MailNotConfigured('寄信服務尚未設定')

    msg = EmailMessage()
    msg['Subject'] = subject
    msg['From'] = formataddr(('SNAP TO LEARN', user))
    msg['To'] = to
    msg.set_content(body)

    host = os.getenv('SMTP_HOST', 'smtp.gmail.com')
    port = int(os.getenv('SMTP_PORT', '465'))
    with smtplib.SMTP_SSL(host, port, timeout=15) as smtp:
        smtp.login(user, password)
        smtp.send_message(msg)
