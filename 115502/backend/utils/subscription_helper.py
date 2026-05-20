from datetime import datetime, timedelta
from utils.db import db
from models import UserSubscription, PointTransaction, Notification


def check_and_expire_subscription(user):
    """
    統一過期判斷邏輯（修正1）。
    在 GET /status、feature_guard、登入時呼叫，確保訂閱狀態與 user 欄位同步。
    """
    now = datetime.utcnow()

    sub = (UserSubscription.query
           .filter_by(user_id=user.id)
           .order_by(UserSubscription.created_at.desc())
           .first())

    if not sub:
        return

    # 試用到期前通知（修正6）：不論是否到期都要檢查
    _check_trial_notice(user, sub, now)

    if sub.end_date >= now:
        return  # 尚未到期，不需要處理

    # ── 以下皆為已到期的情況 ──

    if sub.status == 'active':
        if sub.auto_renew:
            _try_renew(user, sub, now)
        else:
            sub.status = 'expired'
            user.is_premium = False

    elif sub.status == 'trial':
        sub.status = 'expired'
        user.is_premium = False
        if sub.auto_renew:
            # 試用到期且 auto_renew=True → 自動轉為正式月訂閱
            _convert_trial_to_paid(user, sub, now)

    elif sub.status == 'cancelled':
        # 已取消且到期 → 確保 is_premium 為 False
        user.is_premium = False

    db.session.commit()


def _try_renew(user, sub, now):
    """模擬扣款並續訂。若有排程年繳升級則優先啟用，否則依原週期續訂。"""
    payment_success = True  # TODO: 串接真實金流後替換此邏輯

    if not payment_success:
        sub.status = 'expired'
        user.is_premium = False
        return

    # 若有排程中的年繳升級，優先啟用
    pending = (UserSubscription.query
               .filter_by(user_id=user.id, status='pending')
               .first())
    if pending:
        sub.status = 'expired'
        pending.status = 'active'
        pending.start_date = now
        pending.end_date = now + timedelta(days=365)

        plan = pending.plan
        grant = getattr(plan, 'points_grant_yearly', plan.points_grant)
        if grant > 0:
            user.j_pts += grant
            db.session.add(PointTransaction(
                user_id=user.id,
                points=grant,
                price=0,
                payment_method='auto_renewal',
                transaction_type='subscription_grant',
                related_feature='subscription_upgraded_yearly',
            ))

        user.is_premium = True
        user.subscription_end_date = pending.end_date
        user.auto_renew = True
        return

    # 無排程升級：依原週期續訂
    delta = timedelta(days=365) if sub.billing_cycle == 'yearly' else timedelta(days=30)
    while sub.end_date < now:
        sub.end_date += delta
    sub.status = 'active'
    sub.start_date = now

    plan = sub.plan
    grant = (getattr(plan, 'points_grant_yearly', plan.points_grant)
             if sub.billing_cycle == 'yearly'
             else getattr(plan, 'points_grant_monthly', plan.points_grant))
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
    user.subscription_end_date = sub.end_date
    user.auto_renew = True


def _convert_trial_to_paid(user, sub, now):
    """試用到期且 auto_renew=True，自動建立正式月訂閱並贈點。"""
    plan = sub.plan
    new_end = now + timedelta(days=30)
    new_sub = UserSubscription(
        user_id=user.id,
        plan_id=plan.id,
        billing_cycle='monthly',
        start_date=now,
        end_date=new_end,
        auto_renew=True,
        status='active',
        payment_method='auto_convert',
    )
    db.session.add(new_sub)

    grant = getattr(plan, 'points_grant_monthly', plan.points_grant)
    if grant > 0:
        user.j_pts += grant
        db.session.add(PointTransaction(
            user_id=user.id,
            points=grant,
            price=0,
            payment_method='auto_convert',
            transaction_type='subscription_grant',
            related_feature='trial_converted',
        ))

    user.is_premium = True
    user.subscription_end_date = new_end
    user.auto_renew = True


def _check_trial_notice(user, sub, now):
    """若試用剩餘 24 小時內且尚未通知，寫入通知並標記已發送（修正6）。"""
    if sub.status != 'trial':
        return
    if getattr(user, 'trial_notice_sent', False):
        return
    time_left = (sub.end_date - now).total_seconds()
    if 0 < time_left <= 86400:  # 24 小時以內
        db.session.add(Notification(
            user_id=user.id,
            title='試用即將結束',
            body='您的免費試用明天結束，將自動開始收費NT$149/月，如不需要請提前取消。',
        ))
        user.trial_notice_sent = True
        db.session.commit()
