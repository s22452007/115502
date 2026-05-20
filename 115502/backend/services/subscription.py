from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from utils.db import db
from models import User, UserSubscription, SubscriptionPlan, PointTransaction

subscription_bp = Blueprint('subscription', __name__)


def _perform_lazy_renewal(user, subscription):
    """
    DFD 5.10 Lazy 自動續訂。
    每次呼叫 GET /status 時檢查：若已到期且 auto_renew=True，自動延展週期並贈點。
    """
    now = datetime.utcnow()
    if not subscription.auto_renew or subscription.end_date >= now:
        return False

    delta = timedelta(days=365) if subscription.billing_cycle == 'yearly' else timedelta(days=30)

    # 跨越多個週期時一次推到未來
    while subscription.end_date < now:
        subscription.end_date += delta

    subscription.status = 'active'
    subscription.start_date = now

    plan = subscription.plan
    if subscription.billing_cycle == 'yearly':
        grant = getattr(plan, 'points_grant_yearly', plan.points_grant)
    else:
        grant = getattr(plan, 'points_grant_monthly', plan.points_grant)
    if grant > 0:
        user.j_pts += grant
        db.session.add(PointTransaction(
            user_id=user.id,
            points=grant,
            price=0,
            payment_method='auto_renewal',
            transaction_type='subscription_grant',
            related_feature='subscription_renewal',
        ))

    user.is_premium = True
    user.subscription_end_date = subscription.end_date
    user.auto_renew = True
    db.session.commit()
    return True


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
        return jsonify({'is_premium': False, 'subscription': None}), 200

    _perform_lazy_renewal(user, sub)

    now = datetime.utcnow()
    if sub.end_date < now and sub.status == 'active':
        sub.status = 'expired'
        user.is_premium = False
        user.subscription_end_date = sub.end_date
        db.session.commit()

    return jsonify({
        'is_premium': user.is_premium,
        'subscription': {
            'id': sub.id,
            'plan_name': sub.plan.name,
            'billing_cycle': sub.billing_cycle,
            'start_date': sub.start_date.isoformat(),
            'end_date': sub.end_date.isoformat(),
            'auto_renew': sub.auto_renew,
            'status': sub.status,
        }
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

    # 將舊的 active 訂閱標為 cancelled
    old_sub = UserSubscription.query.filter_by(user_id=user_id, status='active').first()
    if old_sub:
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

    sub = (UserSubscription.query
           .filter_by(user_id=user_id, status='active')
           .order_by(UserSubscription.created_at.desc())
           .first())

    if not sub:
        return jsonify({'error': '找不到有效訂閱'}), 404

    sub.auto_renew = False
    sub.status = 'cancelled'
    user.auto_renew = False
    # is_premium 保持 True，直到 end_date 到期後由 lazy check 更新
    db.session.commit()

    return jsonify({
        'message': f'已取消自動續訂，訂閱效期至 {sub.end_date.strftime("%Y-%m-%d")}',
        'end_date': sub.end_date.isoformat(),
        'access_until': sub.end_date.isoformat(),
    }), 200
