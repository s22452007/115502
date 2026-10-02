"""模擬付款開關。

本系統沒有串接真正的金流：購買點數、訂閱都是「模擬付款」，按下購買就直接加點／開通。
開發、校內展示時保持開啟；要開放給外部使用者時，在 .env 設 DEMO_PAYMENT=off，
購買點數與訂閱付款就會被擋下（免費試用不受影響）。
"""
import os

from flask import jsonify

PAYMENT_DISABLED_MESSAGE = '付款功能尚未開放'


def demo_payment_enabled():
    value = (os.getenv('DEMO_PAYMENT') or 'on').strip().lower()
    return value not in ('0', 'off', 'false', 'no')


def payment_disabled_response():
    """模擬付款關閉時回傳 403 回應，開啟時回傳 None"""
    if demo_payment_enabled():
        return None
    return jsonify({'error': PAYMENT_DISABLED_MESSAGE, 'payment_disabled': True}), 403
