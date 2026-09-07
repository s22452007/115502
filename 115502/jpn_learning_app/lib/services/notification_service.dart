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

  // ==========================================
  // 🔔 通知 ID 分類
  // ==========================================
  /// 1. 每日個人常規學習提醒（對照使用者設定的學習時間）
  static const int idDaily = 1;
  /// 2. 晚間「最後機會」提醒（當天快過渡尚未完成時搶救連續紀錄）
  static const int idLastChance = 4;
  /// 3. 每週 2-3 次社交/排行榜通知
  static const int idSocialWed = 31; // 週三週間動態
  static const int idSocialFri = 32; // 週五週末挑戰
  static const int idSocialSun = 33; // 週日結算倒數
  /// 4. 斷記錄 / 久未登入提醒
  static const int idInactive = 10;
  static const int idInactiveDay1 = 11;
  static const int idInactiveDay3 = 13;
  static const int idInactiveDay7 = 17;

  // 相容性保留 ID
  static const int idReview = 2;
  static const int idStreak = 3;

  // ==========================================
  // 🔑 SharedPreferences 鍵名
  // ==========================================
  // 常規每日學習提醒
  static const _keyDaily = 'notif_daily';
  static const _keyDailyHour = 'notif_daily_hour';
  static const _keyDailyMinute = 'notif_daily_minute';

  // 晚間最後機會提醒
  static const _keyLastChance = 'notif_last_chance';
  static const _keyLastChanceHour = 'notif_last_chance_hour';
  static const _keyLastChanceMinute = 'notif_last_chance_minute';

  // 每週社交/排行榜通知（2-3次/週）
  static const _keySocial = 'notif_social';

  // 久未登入提醒（戲劇化整活）
  static const _keyInactive = 'notif_inactive';
  static const _keyInactiveDays = 'notif_inactive_days';
  static const _keyInactiveHour = 'notif_inactive_hour';
  static const _keyInactiveMinute = 'notif_inactive_minute';

  // 學習與狀態追蹤鍵
  static const _keyLastLoginTime = 'notif_last_login_time';
  static const _keyLastCompletedDate = 'notif_last_completed_date'; // yyyy-MM-dd
  static const _keyIsLoggedIn = 'notif_is_logged_in';

  // ==========================================
  // 🚀 初始化
  // ==========================================
  static Future<void> init() async {
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

  // ==========================================
  // ⚙️ 設定讀取與儲存
  // ==========================================

  /// 讀取通知開關設定（包含向後相容欄位）
  static Future<Map<String, bool>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final daily = prefs.getBool(_keyDaily) ?? true;
    final lastChance =
        prefs.getBool(_keyLastChance) ?? prefs.getBool('notif_streak') ?? true;
    final social =
        prefs.getBool(_keySocial) ?? prefs.getBool('notif_friend') ?? true;

    return {
      'daily': daily,
      'last_chance': lastChance,
      'social': social,
      // 向後相容別名
      'review': prefs.getBool('notif_review') ?? false,
      'streak': lastChance,
      'friend': social,
    };
  }

  /// 讀取排程時間（預設：每日 08:00，晚間最後機會 21:30）
  static Future<Map<String, int>> loadTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'daily_hour': prefs.getInt(_keyDailyHour) ?? 8,
      'daily_minute': prefs.getInt(_keyDailyMinute) ?? 0,
      'last_chance_hour': prefs.getInt(_keyLastChanceHour) ?? 21,
      'last_chance_minute': prefs.getInt(_keyLastChanceMinute) ?? 30,
      // 向後相容別名
      'review_hour': prefs.getInt('notif_review_hour') ?? 19,
      'review_minute': prefs.getInt('notif_review_minute') ?? 0,
    };
  }

  /// 讀取未登入提醒設定
  static Future<Map<String, dynamic>> loadInactiveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_keyInactive) ?? true,
      'days': prefs.getInt(_keyInactiveDays) ?? 3,
      'hour': prefs.getInt(_keyInactiveHour) ?? 20,
      'minute': prefs.getInt(_keyInactiveMinute) ?? 0,
    };
  }

  /// 儲存開關設定並重新排程
  static Future<void> saveSettings({
    required bool daily,
    bool? lastChance,
    bool? social,
    // 向後相容參數
    bool? review,
    bool? streak,
    bool? friend,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final actualLastChance = lastChance ?? streak ?? true;
    final actualSocial = social ?? friend ?? true;

    await prefs.setBool(_keyDaily, daily);
    await prefs.setBool(_keyLastChance, actualLastChance);
    await prefs.setBool(_keySocial, actualSocial);

    // 同步儲存相容性鍵
    if (review != null) await prefs.setBool('notif_review', review);
    await prefs.setBool('notif_streak', actualLastChance);
    await prefs.setBool('notif_friend', actualSocial);

    await rescheduleAll();
  }

  /// 儲存常規與最後機會時間並重新排程
  static Future<void> saveTimes({
    required int dailyHour,
    required int dailyMinute,
    int? lastChanceHour,
    int? lastChanceMinute,
    // 向後相容參數
    int? reviewHour,
    int? reviewMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyHour, dailyHour);
    await prefs.setInt(_keyDailyMinute, dailyMinute);

    final lHour = lastChanceHour ?? reviewHour ?? 21;
    final lMin = lastChanceMinute ?? reviewMinute ?? 30;
    await prefs.setInt(_keyLastChanceHour, lHour);
    await prefs.setInt(_keyLastChanceMinute, lMin);

    await rescheduleAll();
  }

  /// 儲存未登入提醒設定並重新排程
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

  // ==========================================
  // 📱 使用者狀態追蹤
  // ==========================================

  /// 讀取登入狀態
  static Future<bool> getLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// 更新登入狀態，並重新排程通知
  static Future<void> setLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, isLoggedIn);
    if (isLoggedIn) {
      await prefs.setInt(
        _keyLastLoginTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    await rescheduleAll();
  }

  /// 使用者登入成功時呼叫
  static Future<void> recordLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setInt(
      _keyLastLoginTime,
      DateTime.now().millisecondsSinceEpoch,
    );
    await rescheduleAll();
  }

  /// 使用者活躍/開啟 App 時呼叫（推延未登入提醒）
  static Future<void> recordUserActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyLastLoginTime,
      DateTime.now().millisecondsSinceEpoch,
    );
    await rescheduleAll();
  }

  /// 當日學習已完成時呼叫（例如拍照掃描或單字練習完成）
  /// - 記錄今日已完成
  /// - 自動取消今日尚未發出的常規提醒與晚間最後機會提醒
  static Future<void> recordDailyStudyCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastCompletedDate, _getTodayStr());
    await prefs.setInt(
      _keyLastLoginTime,
      DateTime.now().millisecondsSinceEpoch,
    );

    // 取消當日提醒，避免已學習後重複打擾
    await cancelDailyForToday();
    await cancelLastChanceForToday();
  }

  /// 檢查今天是否已經完成學習
  static Future<bool> isTodayCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final completedDate = prefs.getString(_keyLastCompletedDate);
    return completedDate == _getTodayStr();
  }

  static String _getTodayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 使用者今天已學習 → 若每日提醒還沒發，就取消今天、改排明天
  static Future<void> cancelDailyForToday() async {
    if (kIsWeb) return;

    try {
      final settings = await loadSettings();
      if (!(settings['daily'] ?? true)) return;

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
          '📚 每日學習時間到了！',
          '花 3 分鐘拍張照片學新單字，維持學習手感吧！',
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
    } catch (e) {
      debugPrint('延後常規通知失敗: $e');
    }
  }

  /// 取消今晚的「最後機會」提醒（今日已完成學習）
  static Future<void> cancelLastChanceForToday() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(idLastChance);
    } catch (e) {
      debugPrint('取消最後機會提醒失敗: $e');
    }
  }

  // ==========================================
  // 🎭 久未登入召回文案（3-7天啟動《戲劇化整活》）
  // ==========================================

  /// 根據未登入天數取得對應的通知文案
  /// - 1~2 天：溫和鼓勵、善意提醒保持手感
  /// - 3~7 天：《戲劇化整活》登場！情緒勒索、幽默懸疑、Duolingo 風格搞笑召回
  /// - > 7 天：溫暖隨時回歸，無壓力重啟
  static NotificationContent getInactiveNotificationContent(int days) {
    switch (days) {
      case 1:
        return const NotificationContent(
          title: '✨ 今天還沒登入學習喔！',
          body: '每天花 3 分鐘拍張照片學單字，維持學習手感吧！',
        );
      case 2:
        return const NotificationContent(
          title: '⏳ 已經 2 天沒登入了',
          body: '趁著單字記憶猶新，快回來複習一下保持節奏～',
        );
      // ── 3-7 天：《戲劇化整活》文案 ──
      case 3:
        return const NotificationContent(
          title: '🦉 你已經 3 天沒理我了...',
          body: '課本上的五十音都要哭了 😭 連勝紀錄正在發抖，快點開 App 安慰它！',
        );
      case 4:
        return const NotificationContent(
          title: '👀 尋人啟事：失蹤的日語學習者',
          body: '失蹤者最後一次被看見是在 4 天前... 你的單字庫很想念你，快回來確認它還健在！',
        );
      case 5:
        return const NotificationContent(
          title: '🎭 難道... 說好學日文只是一場夢？',
          body: '已經 5 天了！快打開 App 拍張照片，向世界證明你還沒放棄！',
        );
      case 6:
        return const NotificationContent(
          title: '🧎‍♂️ 請給我一個機會解釋！',
          body: '日語文法雖然有點難，但真的很好玩！再給我 3 分鐘，我們重新開始好嗎？',
        );
      case 7:
        return const NotificationContent(
          title: '💔 整整一週了... 終究是錯付了嗎',
          body: '連勝紀錄已經在天堂安息了 🪦 但你的日語還有救！今天就重燃希望，隨手拍張照出發吧！',
        );
      case 0:
        return const NotificationContent(
          title: '📈 漸進式多階段提醒',
          body: '未登入第 1-2 天溫和提醒，第 3-7 天開啟戲劇化整活召回！',
        );
      default:
        if (days > 7) {
          return NotificationContent(
            title: '🌱 隨時歡迎回來，日語一直在這裡等你',
            body: '已經 $days 天沒登入了，重新開始完全沒有壓力，今天隨手拍一張照片重新出發！',
          );
        }
        return NotificationContent(
          title: '📖 已經 $days 天沒登入學習了',
          body: '今天花一點點時間回來看看新單字，重啟你的學習節奏吧！',
        );
    }
  }

  // ==========================================
  // ⏰ 重新排程所有通知
  // ==========================================
  static Future<void> rescheduleAll() async {
    final settingsMap = await loadSettings();
    final timesMap = await loadTimes();
    final isLoggedIn = await getLoginStatus();
    final inactiveMap = await loadInactiveSettings();
    final isCompleted = await isTodayCompleted();

    await _reschedule(
      daily: settingsMap['daily'] ?? true,
      dailyHour: timesMap['daily_hour'] ?? 8,
      dailyMinute: timesMap['daily_minute'] ?? 0,
      lastChance: settingsMap['last_chance'] ?? true,
      lastChanceHour: timesMap['last_chance_hour'] ?? 21,
      lastChanceMinute: timesMap['last_chance_minute'] ?? 30,
      social: settingsMap['social'] ?? true,
      isLoggedIn: isLoggedIn,
      isCompletedToday: isCompleted,
      inactiveEnabled: inactiveMap['enabled'] as bool? ?? true,
      inactiveDays: inactiveMap['days'] as int? ?? 3,
      inactiveHour: inactiveMap['hour'] as int? ?? 20,
      inactiveMinute: inactiveMap['minute'] as int? ?? 0,
    );
  }

  static Future<void> _reschedule({
    required bool daily,
    required int dailyHour,
    required int dailyMinute,
    required bool lastChance,
    required int lastChanceHour,
    required int lastChanceMinute,
    required bool social,
    required bool isLoggedIn,
    required bool isCompletedToday,
    bool inactiveEnabled = true,
    int inactiveDays = 3,
    int inactiveHour = 20,
    int inactiveMinute = 0,
  }) async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();

    try {
      await _plugin.cancelAll();

      // 1. 每天 1 則常規學習提醒（對照使用者自訂的學習時間）
      if (daily) {
        await _scheduleDailyAt(
          id: idDaily,
          title: '📚 每日學習時間到了！',
          body: '花 3 分鐘拍張照片學新單字，維持學習手感吧！',
          hour: dailyHour,
          minute: dailyMinute,
        );
      }

      // 2. 若當天快過渡尚未完成，晚間加 1 則「最後機會」提醒
      if (lastChance && !isCompletedToday) {
        await _scheduleLastChance(
          hour: lastChanceHour,
          minute: lastChanceMinute,
        );
      }

      // 3. 每週 2-3 次社交/排行榜類通知（不要天天發）
      if (social) {
        await _scheduleWeeklySocial();
      }

      // 4. 斷記錄超過 3-7 天《戲劇化整活》文案
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

  // ==========================================
  // 🕒 各類通知底層排程實作
  // ==========================================

  /// 排程每日定時提醒
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

  /// 排程晚間「最後機會」提醒（當天快過渡且尚未完成時）
  static Future<void> _scheduleLastChance({
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
      idLastChance,
      '⏳【最後機會】今天只剩最後幾小時！',
      '你的連續學習紀錄即將中斷！花 1 分鐘拍張照片或複習，立即保住連勝火苗 🔥',
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

  /// 每週 2-3 次社交/排行榜提醒（週三、週五、週日）
  static Future<void> _scheduleWeeklySocial() async {
    // 週三 19:30 (週間好友學習動態)
    await _scheduleWeeklyAt(
      id: idSocialWed,
      dayOfWeek: DateTime.wednesday,
      hour: 19,
      minute: 30,
      title: '👥 好友學習動態',
      body: '大家都在努力累積單字！快來看看好友今天的最新進度吧～',
    );

    // 週五 19:30 (週末排行榜爭奪預熱)
    await _scheduleWeeklyAt(
      id: idSocialFri,
      dayOfWeek: DateTime.friday,
      hour: 19,
      minute: 30,
      title: '⚔️ 排行榜爭奪戰開打！',
      body: '距離本週排行結算只剩 2 天，你的排名可能正在被悄悄超越！',
    );

    // 週日 20:00 (週排行榜結算倒數衝刺)
    await _scheduleWeeklyAt(
      id: idSocialSun,
      dayOfWeek: DateTime.sunday,
      hour: 20,
      minute: 0,
      title: '🏆 本週排行榜結算倒數！',
      body: '本週即將結算！快把握最後機會為個人與小組衝刺最高榮譽！',
    );
  }

  /// 排程特定星期幾與時間的每週循環通知
  static Future<void> _scheduleWeeklyAt({
    required int id,
    required int dayOfWeek,
    required int hour,
    required int minute,
    required String title,
    required String body,
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

    while (scheduled.weekday != dayOfWeek || scheduled.isBefore(now)) {
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
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// 排程久未登入提醒（支援指定天數與 1/3/7 漸進式整活召回）
  static Future<void> _scheduleInactiveNotification({
    required int days,
    required int hour,
    required int minute,
    required SharedPreferences prefs,
  }) async {
    final lastLoginMs =
        prefs.getInt(_keyLastLoginTime) ?? DateTime.now().millisecondsSinceEpoch;
    final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMs);
    final nowTz = tz.TZDateTime.now(tz.local);

    // 若選擇 0，代表漸進式提醒（第 1 天溫和、第 3 天整活、第 7 天戲劇化）
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

  /// 計算排程目標時間
  static tz.TZDateTime? _calculateTargetDate({
    required DateTime baseDate,
    required int daysOffset,
    required int hour,
    required int minute,
    required tz.TZDateTime now,
  }) {
    final baseTz = tz.TZDateTime.from(baseDate, tz.local);
    final targetDay = baseTz.add(Duration(days: daysOffset));
    var scheduled = tz.TZDateTime(
      tz.local,
      targetDay.year,
      targetDay.month,
      targetDay.day,
      hour,
      minute,
    );

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
    );
  }
}
