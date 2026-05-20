from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from utils.db import db
from models import User, UserSubscription, SubscriptionPlan, PointTransaction
from utils.subscription_helper import check_and_expire_subscription

subscription_bp = Blueprint('subscription', __name__)


# ─── DFD 5.8 ── 取得訂閱方案清單 ────────────────────────────────────────────
@subscription_bp.route('/plans', methods=['GET'])
def get_plans():
    plans = SubscriptionPlan.query.filter_by(is_active=True).all()
    return jsonify({
        'plans': [{
            'id': p.id,
            'name': p.name,
            'price_monthly': p.price_monthly,
            'price_yearly': p.price_yearly,
            'features': p.features_json or [],
            'points_grant': p.points_grant,
            'points_grant_monthly': getattr(p, 'points_grant_monthly', p.points_grant),
            'points_grant_yearly': getattr(p, 'points_grant_yearly', p.points_grant),
        } for p in plans]
    }), 200


# ─── DFD 5.7 + lazy 5.10 ── 查詢訂閱狀態 ───────────────────────────────────
@subscription_bp.route('/status/<int:user_id>', methods=['GET'])
def get_status(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': '找不到使用者'}), 404

    sub = (UserSubscription.query
           .filter_by(user_id=user_id)
           .order_by(UserSubscription.created_at.desc())
           .first())

    if not sub:
        return jsonify({
            'is_premium': False,
            'trial_used': bool(getattr(user, 'trial_used', False)),
            'subscription': None,
            'pending_upgrade': None,
        }), 200

    check_and_expire_subscription(user)

    # 重新查詢以取得最新狀態（check_and_expire 可能建立新訂閱）
    sub = (UserSubscription.query
           .filter_by(user_id=user_id)
           .filter(UserSubscription.status.in_(['active', 'trial', 'cancelled']))
           .order_by(UserSubscription.created_at.desc())
           .first())

    pending = (UserSubscription.query
               .filter_by(user_id=user_id, status='pending')
               .first())

    return jsonify({
        'is_premium': user.is_premium,
        'trial_used': bool(getattr(user, 'trial_used', False)),
        'subscription': {
            'id': sub.id,
            'plan_name': sub.plan.name,
            'billing_cycle': sub.billing_cycle,
            'start_date': sub.start_date.isoformat(),
            'end_date': sub.end_date.isoformat(),
            'auto_renew': sub.auto_renew,
            'status': sub.status,
        } if sub else None,
        'pending_upgrade': {
            'scheduled_start': pending.start_date.isoformat(),
            'billing_cycle': pending.billing_cycle,
        } if pending else None,
    }), 200


@subscription_bp.route('/subscribe', methods=['POST'])
def subscribe():
    data = request.get_json()
    user_id = data.get('user_id')
    plan_id = data.get('plan_id')
    billing_cycle = data.get('billing_cycle', 'monthly')
    payment_method = data.get('payment_method', 'unknown')

    if not user_id or not plan_id:
        return jsonify({'error': '缺少必要參數'}), 400

    user = User.query.get(user_id)
    plan = SubscriptionPlan.query.get(plan_id)
    if not user or not plan:
        return jsonify({'error': '使用者或方案不存在'}), 404

    now = datetime.utcnow()
    # 設定試用期：月繳=7天試用，年繳=立即啟用
    is_trial = (billing_cycle == 'monthly')
    end_date = now + (timedelta(days=7) if is_trial else timedelta(days=365))
    
    # 狀態判斷：試用為 'trial'，年繳直接為 'active'
    sub_status = 'trial' if is_trial else 'active'

    # 將所有舊的 active/trial 訂閱標為 cancelled，避免重疊
    old_subs = (UserSubscription.query
                .filter_by(user_id=user_id)
                .filter(UserSubscription.status.in_(['active', 'trial']))
                .all())
    for old_sub in old_subs:
        old_sub.status = 'cancelled'

    new_sub = UserSubscription(
        user_id=user_id,
        plan_id=plan_id,
        billing_cycle=billing_cycle,
        start_date=now,
        end_date=end_date,
        auto_renew=True,
        status=sub_status,
        payment_method=payment_method,
    )
    db.session.add(new_sub)

    # 贈點邏輯：只有在正式訂閱 (active) 時才發送點數
    pts_to_grant = (getattr(plan, 'points_grant_yearly', plan.points_grant) 
                    if billing_cycle == 'yearly' 
                    else getattr(plan, 'points_grant_monthly', plan.points_grant))

    if pts_to_grant > 0 and sub_status == 'active':
        user.j_pts += pts_to_grant
        db.session.add(PointTransaction(
            user_id=user_id,
            points=pts_to_grant,
            price=0,
            payment_method=payment_method,
            transaction_type='subscription_grant',
            related_feature='new_subscription',
        ))

    user.is_premium = True
    user.subscription_end_date = end_date
    user.auto_renew = True
    db.session.commit()

    return jsonify({
        'message': '訂閱成功！' + ('（享 7 天試用）' if is_trial else ''),
        'is_premium': True,
        'end_date': end_date.isoformat(),
        'points_granted': pts_to_grant if sub_status == 'active' else 0, # 如果是試用，告知沒送點
        'total_points': user.j_pts,
        'status': sub_status
    }), 200

# ─── DFD 5.11 ── 取消訂閱（保留效期到到期日）────────────────────────────────
@subscription_bp.route('/cancel/<int:user_id>', methods=['POST'])
def cancel_subscription(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': '找不到使用者'}), 404

    # 篩選條件改為只要是 active 或 trial 都可以取消
    sub = (UserSubscription.query
           .filter(UserSubscription.user_id == user_id, 
                   UserSubscription.status.in_(['active', 'trial']))
           .order_by(UserSubscription.created_at.desc())
           .first())

    if not sub:
        return jsonify({'error': '找不到有效訂閱'}), 404

    sub.auto_renew = False
    sub.status = 'cancelled'
    user.auto_renew = False
    # is_premium 保持不動，等 end_date 到期後由 check_and_expire_subscription 處理

    db.session.commit()

    return jsonify({
        'message': f'已取消自動續訂，訂閱效期至 {sub.end_date.strftime("%Y-%m-%d")}',
        'end_date': sub.end_date.isoformat(),
        'status': 'cancelled',
    }), 200


# ─── 排程升級：月繳 → 年繳（到期後自動切換）────────────────────────────────
@subscription_bp.route('/schedule_upgrade', methods=['POST'])
def schedule_upgrade():
    data = request.get_json()
    user_id = data.get('user_id')
    payment_method = data.get('payment_method', 'scheduled')

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': '找不到使用者'}), 404

    current_sub = (UserSubscription.query
                   .filter_by(user_id=user_id)
                   .filter(UserSubscription.status.in_(['active', 'trial']))
                   .order_by(UserSubscription.created_at.desc())
                   .first())
    if not current_sub:
        return jsonify({'error': '找不到有效訂閱'}), 404

    if current_sub.billing_cycle == 'yearly':
        return jsonify({'error': '已是年繳方案'}), 400

    existing_pending = (UserSubscription.query
                        .filter_by(user_id=user_id, status='pending')
                        .first())
    if existing_pending:
        return jsonify({'error': '已有排程升級'}), 400

    yearly_plan = (SubscriptionPlan.query
                   .filter_by(is_active=True, billing_cycle='yearly')
                   .first())
    if not yearly_plan:
        return jsonify({'error': '找不到年訂閱方案'}), 500

    pending_sub = UserSubscription(
        user_id=user_id,
        plan_id=yearly_plan.id,
        billing_cycle='yearly',
        start_date=current_sub.end_date,
        end_date=current_sub.end_date + timedelta(days=365),
        auto_renew=True,
        status='pending',
        payment_method=payment_method,
    )
    db.session.add(pending_sub)
    db.session.commit()

    return jsonify({
        'message': '已排程升級至年繳，將於現有訂閱到期後自動切換',
        'scheduled_start': current_sub.end_date.isoformat(),
    }), 200


@subscription_bp.route('/schedule_upgrade/<int:user_id>', methods=['DELETE'])
def cancel_schedule_upgrade(user_id):
    pending = (UserSubscription.query
               .filter_by(user_id=user_id, status='pending')
               .first())
    if not pending:
        return jsonify({'error': '找不到排程升級'}), 404

    db.session.delete(pending)
    db.session.commit()

    return jsonify({'message': '已取消排程升級'}), 200


# ─── DFD 5.9 ── 啟用 7 天免費試用 ──────────────────────────────────────────
@subscription_bp.route('/trial', methods=['POST'])
def start_trial():
    data = request.get_json()
    user_id = data.get('user_id')
    payment_method = data.get('payment_method', 'trial')

    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': '找不到使用者'}), 404

    if user.trial_used:
        return jsonify({'error': '您已使用過免費試用'}), 400

    existing = (UserSubscription.query
                .filter_by(user_id=user_id)
                .filter(UserSubscription.status.in_(['active', 'trial']))
                .first())
    if existing:
        return jsonify({'error': '已有訂閱中，無法再次啟用試用'}), 400

    # 優先取月訂閱方案
    plan = (SubscriptionPlan.query
            .filter_by(is_active=True, billing_cycle='monthly')
            .first()
            or SubscriptionPlan.query.filter_by(is_active=True).first())
    if not plan:
        return jsonify({'error': '找不到訂閱方案'}), 500

    now = datetime.utcnow()
    end_date = now + timedelta(days=7)

    new_sub = UserSubscription(
        user_id=user_id,
        plan_id=plan.id,
        billing_cycle='trial',
        start_date=now,
        end_date=end_date,
        auto_renew=True,
        status='trial',
        payment_method=payment_method,
    )
    db.session.add(new_sub)

    user.is_premium = True
    user.trial_used = True
    user.subscription_end_date = end_date
    user.auto_renew = True

    db.session.commit()

    return jsonify({
        'message': '免費試用已啟用（7 天）',
        'end_date': end_date.isoformat(),
        'is_premium': True,
    }), 200
