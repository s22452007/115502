import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jpn_learning_app/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationService - 久未登入提醒測試', () {
    test('預設讀取未登入提醒設定值', () async {
      final settings = await NotificationService.loadInactiveSettings();
      expect(settings['enabled'], true);
      expect(settings['days'], 3);
      expect(settings['hour'], 20);
      expect(settings['minute'], 0);
    });

    test('儲存與更新自訂未登入提醒設定', () async {
      await NotificationService.saveInactiveSettings(
        enabled: false,
        days: 5,
        hour: 21,
        minute: 30,
      );

      final settings = await NotificationService.loadInactiveSettings();
      expect(settings['enabled'], false);
      expect(settings['days'], 5);
      expect(settings['hour'], 21);
      expect(settings['minute'], 30);
    });

    test('各天數文案內容生成正確性', () {
      final day1 = NotificationService.getInactiveNotificationContent(1);
      expect(day1.title, contains('今天還沒登入'));

      final day2 = NotificationService.getInactiveNotificationContent(2);
      expect(day2.title, contains('2 天'));

      final day3 = NotificationService.getInactiveNotificationContent(3);
      expect(day3.title, contains('3 天'));

      final day5 = NotificationService.getInactiveNotificationContent(5);
      expect(day5.title, contains('好幾天'));

      final day7 = NotificationService.getInactiveNotificationContent(7);
      expect(day7.title, contains('一週'));

      final progressive = NotificationService.getInactiveNotificationContent(0);
      expect(progressive.title, contains('漸進'));
      expect(progressive.body, contains('第 1 天、第 3 天、第 7 天'));

      final customDay = NotificationService.getInactiveNotificationContent(14);
      expect(customDay.title, contains('14 天'));
    });

    test('登入狀態設定與最後登入時間記錄', () async {
      final prefs = await SharedPreferences.getInstance();

      await NotificationService.recordLogin();
      expect(await NotificationService.getLoginStatus(), true);
      expect(prefs.getInt('notif_last_login_time'), isNotNull);

      final firstLoginTime = prefs.getInt('notif_last_login_time')!;
      expect(firstLoginTime, greaterThan(0));

      // 測試活躍更新
      await NotificationService.recordUserActive();
      final activeTime = prefs.getInt('notif_last_login_time')!;
      expect(activeTime, greaterThanOrEqualTo(firstLoginTime));

      // 測試登出清除登入狀態
      await NotificationService.setLoginStatus(false);
      expect(await NotificationService.getLoginStatus(), false);
    });
  });
}
