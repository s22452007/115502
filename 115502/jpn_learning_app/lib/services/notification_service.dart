import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart'; // 為了使用 kIsWeb

class NotificationContent {
  final String title;
  final String body;

  const NotificationContent({required this.title, required this.body});
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'jpn_learning_channel';
  static const _channelName = 'Snap to Learn 通知';

  // 通知 ID
  static const int idDaily = 1;
  static const int idReview = 2;
  static const int idStreak = 3;
  static const int idInactive = 10;
  static const int idInactiveDay1 = 11;
  static const int idInactiveDay3 = 12;
  static const int idInactiveDay7 = 13;

  // SharedPreferences keys — on/off toggles
  static const _keyDaily = 'notif_daily';
  static const _keyReview = 'notif_review';
  static const _keyStreak = 'notif_streak';
  static const _keyFriend = 'notif_friend';
  static const _keyIsLoggedIn = 'notif_is_logged_in';

  // SharedPreferences keys — custom times
  static const _keyDailyHour = 'notif_daily_hour';
  static const _keyDailyMinute = 'notif_daily_minute';
  static const _keyReviewHour = 'notif_review_hour';
  static const _keyReviewMinute = 'notif_review_minute';

  // SharedPreferences keys — inactive notification
  static const _keyInactive = 'notif_inactive';
  static const _keyInactiveDays = 'notif_inactive_days';
  static const _keyInactiveHour = 'notif_inactive_hour';
  static const _keyInactiveMinute = 'notif_inactive_minute';
  static const _keyLastLoginTime = 'notif_last_login_time';

  static Future<void> init() async {
    // 如果是網頁版，就直接跳過推播初始化！
    if (kIsWeb) {
      debugPrint('網頁版環境，跳過本地推播初始化。');
      return;
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // 請求通知權限
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // App 啟動時依照目前設定重新排程一次
    await rescheduleAll();
  }

  // 讀取已儲存的常規通知設定
  static Future<Map<String, bool>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'daily': prefs.getBool(_keyDaily) ?? true,
      'review': prefs.getBool(_keyReview) ?? true,
      'streak': prefs.getBool(_keyStreak) ?? true,
      'friend': prefs.getBool(_keyFriend) ?? false,
    };
  }

  // 讀取常規通知時間（預設值：每日 08:00，複習 19:00）
  static Future<Map<String, int>> loadTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'daily_hour': prefs.getInt(_keyDailyHour) ?? 8,
      'daily_minute': prefs.getInt(_keyDailyMinute) ?? 0,
      'review_hour': prefs.getInt(_keyReviewHour) ?? 19,
      'review_minute': prefs.getInt(_keyReviewMinute) ?? 0,
    };
  }

  // 讀取未登入提醒設定
  static Future<Map<String, dynamic>> loadInactiveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_keyInactive) ?? true,
      'days': prefs.getInt(_keyInactiveDays) ?? 3,
      'hour': prefs.getInt(_keyInactiveHour) ?? 20,
      'minute': prefs.getInt(_keyInactiveMinute) ?? 0,
    };
  }

  // 儲存未登入提醒設定並重新排程
  static Future<void> saveInactiveSettings({
    required bool enabled,
    required int days,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInactive, enabled);
    await prefs.setInt(_keyInactiveDays, days);
    await prefs.setInt(_keyInactiveHour, hour);
    await prefs.setInt(_keyInactiveMinute, minute);

    await rescheduleAll();
  }

  // 儲存常規通知時間並重新排程
  static Future<void> saveTimes({
    required int dailyHour,
    required int dailyMinute,
    required int reviewHour,
    required int reviewMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyHour, dailyHour);
    await prefs.setInt(_keyDailyMinute, dailyMinute);
    await prefs.setInt(_keyReviewHour, reviewHour);
    await prefs.setInt(_keyReviewMinute, reviewMinute);

    await rescheduleAll();
  }

  // 讀取登入狀態
  static Future<bool> getLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // 更新登入狀態，並重新排程通知
  static Future<void> setLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, isLoggedIn);
    if (isLoggedIn) {
      await prefs.setInt(_keyLastLoginTime, DateTime.now().millisecondsSinceEpoch);
    }
    await rescheduleAll();
  }

  // 使用者登入成功時呼叫
  static Future<void> recordLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setInt(_keyLastLoginTime, DateTime.now().millisecondsSinceEpoch);
    await rescheduleAll();
  }

  // 使用者活躍/開啟 App 時呼叫（推延未登入提醒）
  static Future<void> recordUserActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastLoginTime, DateTime.now().millisecondsSinceEpoch);
    await rescheduleAll();
  }

  // 儲存通知設定並重新排程
  static Future<void> saveSettings({
    required bool daily,
    required bool review,
    required bool streak,
    required bool friend,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDaily, daily);
    await prefs.setBool(_keyReview, review);
    await prefs.setBool(_keyStreak, streak);
    await prefs.setBool(_keyFriend, friend);

    await rescheduleAll();
  }

  /// 重新排程所有通知
  static Future<void> rescheduleAll() async {
    final settingsMap = await loadSettings();
    final isLoggedIn = await getLoginStatus();
    final inactiveMap = await loadInactiveSettings();

    await _reschedule(
      daily: settingsMap['daily'] ?? true,
      review: settingsMap['review'] ?? true,
      streak: settingsMap['streak'] ?? true,
      isLoggedIn: isLoggedIn,
      inactiveEnabled: inactiveMap['enabled'] as bool? ?? true,
      inactiveDays: inactiveMap['days'] as int? ?? 3,
      inactiveHour: inactiveMap['hour'] as int? ?? 20,
      inactiveMinute: inactiveMap['minute'] as int? ?? 0,
    );
  }

  /// 使用者今天已學習 → 若每日提醒還沒發，就取消今天、改排明天
  static Future<void> cancelDailyForToday() async {
    if (kIsWeb) return;

    final settings = await loadSettings();
    if (!(settings['daily'] ?? true)) return; // 通知已關，不處理

    final prefs = await SharedPreferences.getInstance();
    final dailyHour = prefs.getInt(_keyDailyHour) ?? 8;
    final dailyMinute = prefs.getInt(_keyDailyMinute) ?? 0;

    final now = tz.TZDateTime.now(tz.local);
    final todayNotif = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      dailyHour,
      dailyMinute,
    );

    // 通知時間還沒到 → 取消今天的，直接排到明天
    if (todayNotif.isAfter(now)) {
      await _plugin.cancel(idDaily);
      await _plugin.zonedSchedule(
        idDaily,
        '📚 每日學習提醒',
        '今天還沒開始學日文，快來拍一張照片吧！',
        todayNotif.add(const Duration(days: 1)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// 根據未登入天數取得對應的通知文案
  static NotificationContent getInactiveNotificationContent(int days) {
    switch (days) {
      case 1:
        return const NotificationContent(
          title: '✨ 今天還沒登入學習喔！',
          body: '每天花 3 分鐘拍張照片學單字，維持學習手感吧！',
        );
      case 2:
        return const NotificationContent(
          title: '⏳ 已經 2 天沒登入了！',
          body: '趁著單字記憶猶新，快回來複習一下吧！',
        );
      case 3:
        return const NotificationContent(
          title: '🔥 已經 3 天沒登入學習了！',
          body: '遺忘曲線正在發威！快登入 App 複習，別讓先前的努力中斷囉！',
        );
      case 5:
        return const NotificationContent(
          title: '🌟 好幾天沒見到你了！',
          body: '日語進度正在等著你，今天隨手拍一張照片開始學習吧！',
        );
      case 7:
        return const NotificationContent(
          title: '👋 已經一週沒登入了，我們很想你！',
          body: '隨時歡迎回來繼續日語學習旅程，今天就來開啟 App 吧！',
        );
      case 0:
        return const NotificationContent(
          title: '📈 漸進式多階段提醒',
          body: '未登入第 1 天、第 3 天、第 7 天將循序漸進提醒你回來學習。',
        );
      default:
        return NotificationContent(
          title: '📖 已經 $days 天沒登入日語學習了',
          body: '今天花一點點時間回來看看新單字，重啟你的學習節奏吧！',
        );
    }
  }

  static Future<void> _reschedule({
    required bool daily,
    required bool review,
    required bool streak,
    required bool isLoggedIn,
    bool inactiveEnabled = true,
    int inactiveDays = 3,
    int inactiveHour = 20,
    int inactiveMinute = 0,
  }) async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final dailyHour = prefs.getInt(_keyDailyHour) ?? 8;
    final dailyMinute = prefs.getInt(_keyDailyMinute) ?? 0;
    final reviewHour = prefs.getInt(_keyReviewHour) ?? 19;
    final reviewMinute = prefs.getInt(_keyReviewMinute) ?? 0;

    try {
      await _plugin.cancelAll();

      if (daily) {
        await _scheduleDailyAt(
          id: idDaily,
          title: '📚 每日學習提醒',
          body: '今天還沒開始學日文，快來拍一張照片吧！',
          hour: dailyHour,
          minute: dailyMinute,
        );
      }

      if (review) {
        await _scheduleDailyAt(
          id: idReview,
          title: '📝 單字複習提醒',
          body: '別忘了複習今天的單字，保持學習節奏！',
          hour: reviewHour,
          minute: reviewMinute,
        );
      }

      // 連續登入提醒
      if (streak && !isLoggedIn) {
        await _scheduleDailyAt(
          id: idStreak,
          title: '🔥 連續登入提醒',
          body: '今天還沒登入，快來維持你的連續學習紀錄！',
          hour: 21,
          minute: 0,
        );
      }

      // 久未登入提醒（依照未登入天數排程推播）
      if (inactiveEnabled) {
        await _scheduleInactiveNotification(
          days: inactiveDays,
          hour: inactiveHour,
          minute: inactiveMinute,
          prefs: prefs,
        );
      }
    } catch (e) {
      debugPrint('推播排程處理例外（可能是測試環境或權限未就緒）: $e');
    }
  }

  /// 排程久未登入提醒（只在未來指定天數到達時觸發一次，若期間有登入則會被推延）
  static Future<void> _scheduleInactiveNotification({
    required int days,
    required int hour,
    required int minute,
    required SharedPreferences prefs,
  }) async {
    final lastLoginMs = prefs.getInt(_keyLastLoginTime) ?? DateTime.now().millisecondsSinceEpoch;
    final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMs);
    final nowTz = tz.TZDateTime.now(tz.local);

    // 若選擇 0，代表漸進式提醒（第 1 天、第 3 天、第 7 天）
    if (days == 0) {
      final milestones = [
        (1, idInactiveDay1),
        (3, idInactiveDay3),
        (7, idInactiveDay7),
      ];

      for (final (milestoneDay, notifId) in milestones) {
        final content = getInactiveNotificationContent(milestoneDay);
        final scheduledDate = _calculateTargetDate(
          baseDate: lastLogin,
          daysOffset: milestoneDay,
          hour: hour,
          minute: minute,
          now: nowTz,
        );

        if (scheduledDate != null) {
          await _scheduleSingleInactive(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduledDate,
          );
        }
      }
    } else {
      // 單一天數門檻提醒
      final content = getInactiveNotificationContent(days);
      final scheduledDate = _calculateTargetDate(
        baseDate: lastLogin,
        daysOffset: days,
        hour: hour,
        minute: minute,
        now: nowTz,
      );

      if (scheduledDate != null) {
        await _scheduleSingleInactive(
          id: idInactive,
          title: content.title,
          body: content.body,
          scheduledDate: scheduledDate,
        );
      }
    }
  }

  /// 計算排程目標時間（若目標時間已在過去，則回傳 null 或依目前時間往後計算）
  static tz.TZDateTime? _calculateTargetDate({
    required DateTime baseDate,
    required int daysOffset,
    required int hour,
    required int minute,
    required tz.TZDateTime now,
  }) {
    final baseTz = tz.TZDateTime.from(baseDate, tz.local);
    // 目標日期 = 上次登入日 + 間隔天數
    final targetDay = baseTz.add(Duration(days: daysOffset));
    var scheduled = tz.TZDateTime(
      tz.local,
      targetDay.year,
      targetDay.month,
      targetDay.day,
      hour,
      minute,
    );

    // 如果目標時間已在過去（例如使用者很久以前登入，現在才開啟此功能）
    // 則安排在下一個最近的提醒時間（今天或明天的指定時間）
    if (scheduled.isBefore(now)) {
      var nextScheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (nextScheduled.isBefore(now)) {
        nextScheduled = nextScheduled.add(const Duration(days: 1));
      }
      return nextScheduled;
    }

    return scheduled;
  }

  static Future<void> _scheduleSingleInactive({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // 不設置 matchDateTimeComponents，僅在該日期時間觸發一次
    );
  }

  static Future<void> _scheduleDailyAt({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
