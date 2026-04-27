import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart'; // 為了使用 kIsWeb

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'jpn_learning_channel';
  static const _channelName = 'JPN Learning 通知';

  // 通知 ID
  static const int idDaily = 1;
  static const int idReview = 2;
  static const int idStreak = 3;

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
    final settingsMap = await loadSettings();
    final isLoggedIn = await getLoginStatus();

    await _reschedule(
      daily: settingsMap['daily'] ?? true,
      review: settingsMap['review'] ?? true,
      streak: settingsMap['streak'] ?? true,
      isLoggedIn: isLoggedIn,
    );
  }

  // 讀取已儲存的通知設定
  static Future<Map<String, bool>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'daily': prefs.getBool(_keyDaily) ?? true,
      'review': prefs.getBool(_keyReview) ?? true,
      'streak': prefs.getBool(_keyStreak) ?? true,
      'friend': prefs.getBool(_keyFriend) ?? false,
    };
  }

  // 讀取使用者設定的通知時間（預設值：每日 08:00，複習 19:00）
  static Future<Map<String, int>> loadTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'daily_hour': prefs.getInt(_keyDailyHour) ?? 8,
      'daily_minute': prefs.getInt(_keyDailyMinute) ?? 0,
      'review_hour': prefs.getInt(_keyReviewHour) ?? 19,
      'review_minute': prefs.getInt(_keyReviewMinute) ?? 0,
    };
  }

  // 儲存使用者設定的通知時間並重新排程
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

    final settingsMap = await loadSettings();
    final isLoggedIn = await getLoginStatus();
    await _reschedule(
      daily: settingsMap['daily'] ?? true,
      review: settingsMap['review'] ?? true,
      streak: settingsMap['streak'] ?? true,
      isLoggedIn: isLoggedIn,
    );
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

    final settingsMap = await loadSettings();

    await _reschedule(
      daily: settingsMap['daily'] ?? true,
      review: settingsMap['review'] ?? true,
      streak: settingsMap['streak'] ?? true,
      isLoggedIn: isLoggedIn,
    );
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

    final isLoggedIn = await getLoginStatus();

    await _reschedule(
      daily: daily,
      review: review,
      streak: streak,
      isLoggedIn: isLoggedIn,
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
        tz.local, now.year, now.month, now.day, dailyHour, dailyMinute);

    // 通知時間還沒到 → 取消今天的，直接排到明天
    if (todayNotif.isAfter(now)) {
      await _plugin.cancel(idDaily);
      await _plugin.zonedSchedule(
        idDaily,
        '📚 每日學習提醒',
        '今天還沒開始學日文，快來拍一張照片吧！',
        todayNotif.add(const Duration(days: 1)),
        NotificationDetails(
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
    // 通知時間已過 → 代表通知早已發出，不需要處理
  }

  static Future<void> _reschedule({
    required bool daily,
    required bool review,
    required bool streak,
    required bool isLoggedIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dailyHour = prefs.getInt(_keyDailyHour) ?? 8;
    final dailyMinute = prefs.getInt(_keyDailyMinute) ?? 0;
    final reviewHour = prefs.getInt(_keyReviewHour) ?? 19;
    final reviewMinute = prefs.getInt(_keyReviewMinute) ?? 0;

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

    // 只有「未登入」時，才排連續登入提醒
    if (streak && !isLoggedIn) {
      await _scheduleDailyAt(
        id: idStreak,
        title: '🔥 連續登入提醒',
        body: '今天還沒登入，快來維持你的連續學習紀錄！',
        hour: 21,
        minute: 0,
      );
    }
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
      NotificationDetails(
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