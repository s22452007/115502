import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jpn_learning_app/services/notification_service.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
  });

  group('四階段推播通知策略測試', () {
    test('1. 每日常規學習提醒設定讀取與儲存', () async {
      // 預設值檢查
      final settings = await NotificationService.loadSettings();
      expect(settings['daily'], true);

      final times = await NotificationService.loadTimes();
      expect(times['daily_hour'], 8);
      expect(times['daily_minute'], 0);

      // 儲存自訂學習時間
      await NotificationService.saveTimes(
        dailyHour: 7,
        dailyMinute: 30,
      );
      final updatedTimes = await NotificationService.loadTimes();
      expect(updatedTimes['daily_hour'], 7);
      expect(updatedTimes['daily_minute'], 30);
    });

    test('2. 晚間「最後機會」提醒與當日學習完成機制', () async {
      // 預設晚間最後機會提醒為開啟且時間為 21:30
      final settings = await NotificationService.loadSettings();
      expect(settings['last_chance'], true);

      final times = await NotificationService.loadTimes();
      expect(times['last_chance_hour'], 21);
      expect(times['last_chance_minute'], 30);

      // 當天一開始尚未完成學習
      expect(await NotificationService.isTodayCompleted(), false);

      // 使用者完成當日學習（拍照掃描或單字打卡）
      await NotificationService.recordDailyStudyCompleted();
      expect(await NotificationService.isTodayCompleted(), true);
    });

    test('3. 每週 2-3 次社交/排行榜通知開關設定', () async {
      // 預設為開啟
      final settings = await NotificationService.loadSettings();
      expect(settings['social'], true);

      // 關閉社交通知
      await NotificationService.saveSettings(
        daily: true,
        lastChance: true,
        social: false,
      );
      final updated = await NotificationService.loadSettings();
      expect(updated['social'], false);
    });

    test('4. 斷記錄超過 3-7 天《戲劇化整活》文案驗證', () {
      // 第 1-2 天：溫和友善引導
      final day1 = NotificationService.getInactiveNotificationContent(1);
      expect(day1.title, contains('今天還沒登入'));
      expect(day1.body, contains('每天花 3 分鐘'));

      final day2 = NotificationService.getInactiveNotificationContent(2);
      expect(day2.title, contains('2 天'));
      expect(day2.body, contains('單字記憶猶新'));

      // 第 3~7 天：《戲劇化整活》情緒勒索與幽默搞笑召回
      final day3 = NotificationService.getInactiveNotificationContent(3);
      expect(day3.title, contains('3 天沒理我'));
      expect(day3.body, contains('五十音都要哭了'));

      final day4 = NotificationService.getInactiveNotificationContent(4);
      expect(day4.title, contains('尋人啟事'));
      expect(day4.body, contains('失蹤'));

      final day5 = NotificationService.getInactiveNotificationContent(5);
      expect(day5.title, contains('一場夢'));
      expect(day5.body, contains('5 天'));

      final day6 = NotificationService.getInactiveNotificationContent(6);
      expect(day6.title, contains('給我一個機會'));
      expect(day6.body, contains('重新開始'));

      final day7 = NotificationService.getInactiveNotificationContent(7);
      expect(day7.title, contains('錯付'));
      expect(day7.body, contains('天堂安息'));

      // 超過 7 天：溫和回歸
      final day10 = NotificationService.getInactiveNotificationContent(10);
      expect(day10.title, contains('隨時歡迎回來'));
      expect(day10.body, contains('沒有壓力'));

      // 漸進式描述
      final progressive = NotificationService.getInactiveNotificationContent(0);
      expect(progressive.title, contains('漸進'));
      expect(progressive.body, contains('第 3-7 天開啟戲劇化整活召回'));
    });

    test('登入與活躍狀態記錄', () async {
      final prefs = await SharedPreferences.getInstance();

      await NotificationService.recordLogin();
      expect(await NotificationService.getLoginStatus(), true);
      expect(prefs.getInt('notif_last_login_time'), isNotNull);

      final firstLoginTime = prefs.getInt('notif_last_login_time')!;
      expect(firstLoginTime, greaterThan(0));

      await NotificationService.recordUserActive();
      final activeTime = prefs.getInt('notif_last_login_time')!;
      expect(activeTime, greaterThanOrEqualTo(firstLoginTime));

      await NotificationService.setLoginStatus(false);
      expect(await NotificationService.getLoginStatus(), false);
    });
  });
}
