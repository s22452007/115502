import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jpn_learning_app/main.dart';
import 'package:jpn_learning_app/providers/font_size_provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/auth/welcome_screen.dart';

void main() {
  // App 啟動冒煙測試：跟 main() 一樣在最外層包好 Provider，
  // 原本的範本測試直接 pumpWidget(JpnLearningApp)，找不到 UserProvider 一定失敗。
  testWidgets('App 啟動後顯示歡迎畫面', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => FontSizeProvider()),
        ],
        child: const JpnLearningApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
