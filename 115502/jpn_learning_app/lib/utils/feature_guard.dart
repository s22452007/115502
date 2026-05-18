import 'package:jpn_learning_app/providers/user_provider.dart';

/// DFD 5.12 功能使用權限驗證（純本地判斷，無網路呼叫）。
///
/// 使用前請確認 UserProvider 已透過 getSubscriptionStatus 刷新過訂閱狀態。
class FeatureGuard {
  /// 是否為有效 Premium 使用者（isPremium 且訂閱未到期）。
  static bool isPremiumUser(UserProvider provider) {
    if (!provider.isPremium) return false;
    final endDate = provider.subscriptionEndDate;
    if (endDate == null) return false;
    return DateTime.tryParse(endDate)?.isAfter(DateTime.now()) ?? false;
  }

  /// 點數餘額是否足夠。
  static bool hasEnoughPoints(UserProvider provider, int requiredPoints) {
    return provider.jPts >= requiredPoints;
  }

  /// 是否可存取功能（Premium 免費 OR 點數足夠）。
  ///
  /// [requiredPoints] 為 0 表示只有 Premium 才能使用（不允許點數解鎖）。
  static bool canAccess(UserProvider provider, {int requiredPoints = 0}) {
    if (isPremiumUser(provider)) return true;
    if (requiredPoints > 0) return hasEnoughPoints(provider, requiredPoints);
    return false;
  }
}
