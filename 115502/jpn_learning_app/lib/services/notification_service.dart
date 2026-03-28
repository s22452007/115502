import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'jpn_learning_channel';
  static const _channelName = 'JPN Learning 通知';

  // 通知 ID
  static const int idDaily = 1;
  static const int idReview = 2;
  static const int idStreak = 3;

  // SharedPreferences keys
  static const _keyDaily = 'notif_daily';
  static const _keyReview = 'notif_review';
  static const _keyStreak = 'notif_streak';
  static const _keyFriend = 'notif_friend';

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // 請求通知權限
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // 讀取已儲存的設定
  static Future<Map<String, bool>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'daily': prefs.getBool(_keyDaily) ?? true,
      'review': prefs.getBool(_keyReview) ?? true,
      'streak': prefs.getBool(_keyStreak) ?? true,
      'friend': prefs.getBool(_keyFriend) ?? false,
    };
  }

  // 儲存設定並重新排程
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
    await _reschedule(daily: daily, review: review, streak: streak);
  }

  static Future<void> _reschedule({
    required bool daily,
    required bool review,
    required bool streak,
  }) async {
    await _plugin.cancelAll();

    if (daily) {
      await _scheduleDailyAt(
        id: idDaily,
        title: '📚 每日學習提醒',
        body: '今天還沒開始學日文，快來拍一張照片吧！',
        hour: 8,
        minute: 0,
      );
    }

    if (review) {
      await _scheduleDailyAt(
        id: idReview,
        title: '📝 單字複習提醒',
        body: '別忘了複習今天的單字，保持學習節奏！',
        hour: 19,
        minute: 0,
      );
    }

    if (streak) {
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
