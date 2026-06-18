import random
from datetime import date
from flask import Blueprint, request, jsonify
from utils.db import db
from models import User, PointTransaction, TransactionType

daily_reward_bp = Blueprint('daily_reward', __name__)


def _ensure_today(user):
    """若跨日，重置每日任務狀態。"""
    today = date.today()
    if getattr(user, 'daily_task_date', None) != today:
        user.daily_task_date = today
        user.daily_task_photo = False
        user.daily_task_ai = False
        user.daily_reward_claimed = False


def _reward_range(streak_days):
    if streak_days >= 30:
        return 50, 80, 1   # pts_min, pts_max, bonus_photo
    if streak_days >= 7:
        return 30, 50, 0
    return 10, 30, 0


@daily_reward_bp.route('/status', methods=['GET'])
def get_status():
    user_id = request.args.get('user_id', type=int)
    if not user_id:
        return jsonify({'error': '缺少 user_id'}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': '找不到使用者'}), 404

    _ensure_today(user)
    db.session.commit()

    streak = user.streak_days or 1
    pts_min, pts_max, bonus_photo = _reward_range(streak)
    photo_done = bool(user.daily_task_photo)
    ai_done = bool(user.daily_task_ai)
    claimed = bool(user.daily_reward_claimed)

    return jsonify({
        'photo_done': photo_done,
        'ai_done': ai_done,
        'all_done': photo_done and ai_done,
        'claimed': claimed,
        'can_claim': photo_done and ai_done and not claimed,
        'streak_days': streak,
        'reward_preview': {
            'pts_min': pts_min,
            'pts_max': pts_max,
            'bonus_photo': bonus_photo,
        },
    }), 200


@daily_reward_bp.route('/claim', methods=['POST'])
def claim_reward():
    data = request.get_json()
    user_id = data.get('user_id')
    if not user_id:
        return jsonify({'error': '缺少 user_id'}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': '找不到使用者'}), 404

    _ensure_today(user)

    if not (user.daily_task_photo and user.daily_task_ai):
        return jsonify({'error': '今日任務尚未完成'}), 400

    if user.daily_reward_claimed:
        return jsonify({'error': '今日獎勵已領取'}), 400

    streak = user.streak_days or 1
    pts_min, pts_max, bonus_photo = _reward_range(streak)
    pts = random.randint(pts_min, pts_max)

    user.j_pts = (user.j_pts or 0) + pts
    if bonus_photo:
        user.photo_extra_count = (user.photo_extra_count or 0) + bonus_photo
    user.daily_reward_claimed = True

    db.session.add(PointTransaction(
        user_id=user.id,
        points=pts,
        price=0,
        transaction_type=TransactionType.REWARD,
        related_feature='daily_task_reward',
    ))
    db.session.commit()

    return jsonify({
        'message': '獎勵領取成功！',
        'pts_earned': pts,
        'bonus_photo': bonus_photo,
        'j_pts': user.j_pts,
        'streak_days': streak,
    }), 200
