import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jpn_learning_app/utils/password_policy.dart';
import 'package:jpn_learning_app/widgets/common/password_strength_meter.dart';

void main() {
  group('強度判斷（與後端同一套規則）', () {
    final cases = <String, PasswordLevel>{
      'abc123': PasswordLevel.tooShort,
      'abcdefgh': PasswordLevel.weak,
      'zzpqmwkr': PasswordLevel.weak,
      '12345678': PasswordLevel.weak,
      'password': PasswordLevel.weak,
      'aaaaaaa1': PasswordLevel.weak,
      'snap2026go': PasswordLevel.medium,
      'Tokyo2026rain': PasswordLevel.strong,
      'This[ji32k7ru8^)': PasswordLevel.strong,
    };
    cases.forEach((pw, want) {
      test('$pw → $want', () => expect(PasswordPolicy.evaluate(pw).level, want));
    });

    test('包含帳號名稱算弱', () {
      expect(PasswordPolicy.evaluate('kenji2026', account: 'kenji@test.com').level, PasswordLevel.weak);
    });
  });

  group('能不能用', () {
    test('7 碼擋下', () => expect(PasswordPolicy.validate('abc1234'), isNotNull));
    test('一般使用者 8 碼弱密碼可以', () => expect(PasswordPolicy.validate('abcdefgh'), isNull));
    test('學生／老師弱密碼擋下', () => expect(PasswordPolicy.validate('abcdefgh', requireMedium: true), isNotNull));
    test('學生／老師中強度可以', () => expect(PasswordPolicy.validate('snap2026go', requireMedium: true), isNull));
  });

  testWidgets('強度條會隨輸入更新', (tester) async {
    final ctrl = TextEditingController();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PasswordStrengthMeter(controller: ctrl))));

    expect(find.textContaining('強度'), findsNothing);   // 還沒輸入不顯示

    ctrl.text = 'abc';
    await tester.pump();
    expect(find.text('強度：太短'), findsOneWidget);
    expect(find.text('密碼至少需要 8 個字元'), findsOneWidget);

    ctrl.text = 'snap2026go';
    await tester.pump();
    expect(find.text('強度：中'), findsOneWidget);

    ctrl.text = 'Tokyo2026rain';
    await tester.pump();
    expect(find.text('強度：強'), findsOneWidget);
  });

  testWidgets('學生帳號弱密碼會提示至少要中', (tester) async {
    final ctrl = TextEditingController(text: 'abcdefgh');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PasswordStrengthMeter(controller: ctrl, requireMedium: true))));
    expect(find.text('強度：弱'), findsOneWidget);
    expect(find.text('這個帳號的密碼強度至少需要「中」'), findsOneWidget);
  });
}
