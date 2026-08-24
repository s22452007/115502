# -*- coding: utf-8 -*-
"""
AI 對話歷史紀錄 API。

一次進入對話畫面 = 一個「場次」(ChatSession)，
場次底下掛著一則則訊息 (ChatMessage)。
"""
from flask import Blueprint, request, jsonify
from datetime import datetime

from utils.db import db
from models import ChatSession, ChatMessage, Dialect

chat_history_bp = Blueprint('chat_history', __name__)


def _session_to_dict(s, preview=None):
    dialect_name = None
    if s.dialect_id:
        d = db.session.get(Dialect, s.dialect_id)
        dialect_name = d.name if d else None

    return {
        'session_id': s.id,
        'topic': s.topic,
        'character_name': s.character_name,
        'dialect_id': s.dialect_id,
        'dialect_name': dialect_name,
        'message_count': s.message_count or 0,
        'started_at': s.started_at.strftime('%Y.%m.%d %H:%M') if s.started_at else '',
        'last_message_at': s.last_message_at.strftime('%Y.%m.%d %H:%M') if s.last_message_at else '',
        'preview': preview,
    }


@chat_history_bp.route('/session', methods=['POST'])
def create_session():
    """建立一個新的對話場次（進入對話畫面時呼叫）"""
    data = request.get_json(silent=True) or request.form
    user_id = data.get('user_id')
    topic = (data.get('topic') or '').strip()

    if not user_id or not topic:
        return jsonify({'error': '缺少 user_id 或 topic'}), 400

    dialect_id = data.get('dialect_id')
    try:
        dialect_id = int(dialect_id) if dialect_id not in (None, '', 'null') else None
    except (TypeError, ValueError):
        dialect_id = None

    now = datetime.utcnow()
    s = ChatSession(
        user_id=int(user_id),
        topic=topic,
        character_name=(data.get('character_name') or '').strip() or None,
        dialect_id=dialect_id,
        message_count=0,
        started_at=now,
        last_message_at=now,
    )
    db.session.add(s)
    db.session.commit()

    return jsonify({'session_id': s.id}), 201


@chat_history_bp.route('/sessions', methods=['GET'])
def list_sessions():
    """取得使用者的對話紀錄清單（最新的排前面）"""
    user_id = request.args.get('user_id', type=int)
    if not user_id:
        return jsonify({'error': '缺少 user_id'}), 400

    sessions = (ChatSession.query
                .filter_by(user_id=user_id)
                .filter(ChatSession.message_count > 0)  # 沒聊過的空場次不顯示
                .order_by(ChatSession.last_message_at.desc())
                .all())

    results = []
    for s in sessions:
        # 取最後一則訊息當作預覽
        last_msg = (ChatMessage.query
                    .filter_by(session_id=s.id)
                    .order_by(ChatMessage.id.desc())
                    .first())
        preview = last_msg.content if last_msg else None
        if preview:
            preview = preview.split('\n')[0][:40]  # 只取第一行、限制長度
        results.append(_session_to_dict(s, preview))

    return jsonify({'sessions': results}), 200


@chat_history_bp.route('/session/<int:session_id>', methods=['GET'])
def get_session(session_id):
    """取得某場對話的完整訊息（供回顧與接續對話使用）"""
    s = db.session.get(ChatSession, session_id)
    if not s:
        return jsonify({'error': '找不到這場對話'}), 404

    messages = (ChatMessage.query
                .filter_by(session_id=session_id)
                .order_by(ChatMessage.id)
                .all())

    return jsonify({
        'session': _session_to_dict(s),
        'messages': [{
            'id': m.id,
            'role': m.role,
            'content': m.content,
            'created_at': m.created_at.strftime('%Y.%m.%d %H:%M') if m.created_at else '',
        } for m in messages],
    }), 200


@chat_history_bp.route('/session/<int:session_id>', methods=['DELETE'])
def delete_session(session_id):
    """刪除整場對話（訊息會一併刪除）"""
    s = db.session.get(ChatSession, session_id)
    if not s:
        return jsonify({'error': '找不到這場對話'}), 404

    db.session.delete(s)  # cascade 會一併刪掉底下的訊息
    db.session.commit()
    return jsonify({'message': '已刪除這場對話'}), 200


# ==========================================
# 給 /api/chat 使用的儲存工具
# ==========================================
def save_exchange(session_id, user_message, ai_reply):
    """
    儲存一次問答（使用者訊息 + AI 回覆）並更新場次統計。
    只有 AI 成功回覆時才會被呼叫，失敗的對話不會留下紀錄。
    """
    s = db.session.get(ChatSession, session_id)
    if not s:
        return False

    now = datetime.utcnow()
    db.session.add(ChatMessage(session_id=s.id, role='user',
                               content=user_message, created_at=now))
    db.session.add(ChatMessage(session_id=s.id, role='ai',
                               content=ai_reply, created_at=now))
    s.message_count = (s.message_count or 0) + 2
    s.last_message_at = now
    db.session.commit()
    return True
