from datetime import datetime, timedelta
from utils.db import db
from models import UserSubscription, PointTransaction, Notification, TransactionType


def get_subscription_status(subscription):
    """
    動態計算訂閱狀態，不依賴資料庫欄位
    回傳值：'trial' | 'active' | 'cancelled' | 'expired'
    """
    now = datetime.utcnow()

    if subscription.end_date < now:
        return 'expired'
    if subscription.billing_cycle == 'trial':
        return 'trial'
    if not subscription.auto_renew:
        return 'cancelled'
    return 'active'


def check_and_expire_subscription(user):
    """
    統一過期判斷邏輯（修正1）。
    在 GET /status、feature_guard、登入時呼叫，確保訂閱狀態與 user 欄位同步。
    """
    now = datetime.utcnow()

    sub = (UserSubscription.query
           .filter(UserSubscription.user_id == user.id,
                   UserSubscription.start_date <= now)
           .order_by(UserSubscription.created_at.desc())
           .first())

    if not sub:
        return

    # 試用到期前通知（修正6）：不論是否到期都要檢查
    _check_trial_notice(user, sub, now)

    if sub.end_date >= now:
        return  # 尚未到期，不需要處理

    # ── 以下皆為已到期的情況，用 billing_cycle / auto_renew 判斷原始狀態 ──

    if sub.billing_cycle == 'trial':
        # 原本是試用中
        pending = (UserSubscription.query
                   .filter(UserSubscription.user_id == user.id,
                           UserSubscription.start_date > now,
                           UserSubscription.auto_renew == True)
                   .first())

        if pending and pending.payment_status == 'paid':
            _activate_pending_upgrade(user, sub, pending, now)
        else:
            user.is_premium = False
            user.auto_renew = False
            if pending and pending.payment_status != 'paid':
                db.session.delete(pending)
            elif sub.auto_renew:
                _convert_trial_to_paid(user, sub, now)

    elif not sub.auto_renew:
        # 原本是已取消
        pending = (UserSubscription.query
                   .filter(UserSubscription.user_id == user.id,
                           UserSubscription.start_date > now,
                           UserSubscription.auto_renew == True)
                   .first())
        if pending and pending.payment_status == 'paid':
            _activate_pending_upgrade(user, sub, pending, now)
        else:
            user.is_premium = False
            user.auto_renew = False

    else:
        # 原本是 active（auto_renew=True, billing_cycle != 'trial'）
        pending = (UserSubscription.query
                   .filter(UserSubscription.user_id == user.id,
                           UserSubscription.start_date > now,
                           UserSubscription.auto_renew == True)
                   .first())
        if pending and pending.payment_status == 'paid':
            _activate_pending_upgrade(user, sub, pending, now)
        elif pending and pending.payment_status != 'paid':
            user.is_premium = False
            user.auto_renew = False
        elif sub.auto_renew:
            _try_renew(user, sub, now)
        else:
            user.is_premium = False
            user.auto_renew = False

    db.session.commit()


def _try_renew(user, sub, now):
    """模擬扣款並續訂。若有排程年繳升級則優先啟用，否則依原週期續訂。"""
    payment_success = True  # TODO: 串接真實金流後替換此邏輯

    if not payment_success:
        user.is_premium = False
        return

    # 若有排程中的年繳升級，優先啟用
    pending = (UserSubscription.query
               .filter(UserSubscription.user_id == user.id,
                       UserSubscription.start_date > now,
                       UserSubscription.auto_renew == True)
               .first())
    if pending:
        pending.start_date = now
        pending.end_date = now + timedelta(days=365)

        plan = pending.plan
        grant = 0
        if plan is not None:
            grant = getattr(plan, 'points_grant_yearly', None)
            if grant is None:
                grant = getattr(plan, 'points_grant', 0)
            grant = grant or 0
        if grant > 0:
            user.j_pts += grant
            db.session.add(PointTransaction(
                user_id=user.id,
                points=grant,
                price=0,
                payment_method='auto_renewal',
                transaction_type=TransactionType.SUBSCRIPTION_GRANT,
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
    sub.start_date = now

    plan = sub.plan
    grant = 0
    if plan is not None:
        if sub.billing_cycle == 'yearly':
            grant = getattr(plan, 'points_grant_yearly', None)
        else:
            grant = getattr(plan, 'points_grant_monthly', None)
        if grant is None:
            grant = getattr(plan, 'points_grant', 0)
        grant = grant or 0
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


def _activate_pending_upgrade(user, sub, pending, now):
    """將排程年繳升級啟用，並在到期後開始新的年繳訂閱。
    注意：贈點已在排程建立時（付款時）立即發放，此處不再重複贈點。
    """
    start_date = pending.start_date
    if start_date > now:
        start_date = now
    pending.start_date = start_date
    pending.end_date = start_date + timedelta(days=365)

    user.is_premium = True
    user.subscription_end_date = pending.end_date
    user.auto_renew = True


def _convert_trial_to_paid(user, sub, now):
    """試用到期且 auto_renew=True，自動建立正式月訂閱並贈點。"""
    plan = sub.plan
    if plan is None:
        return
    new_end = now + timedelta(days=30)
    new_sub = UserSubscription(
        user_id=user.id,
        plan_id=plan.id,
        billing_cycle='monthly',
        start_date=now,
        end_date=new_end,
        auto_renew=True,
        payment_method='auto_convert',
    )
    db.session.add(new_sub)

    grant = 0
    if plan is not None:
        grant = getattr(plan, 'points_grant_monthly', None)
        if grant is None:
            grant = getattr(plan, 'points_grant', 0)
        grant = grant or 0
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
    if get_subscription_status(sub) != 'trial':
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
