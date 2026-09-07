import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jpn_learning_app/widgets/common/staged_progress_overlay.dart';

void main() {
  Widget wrap() => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: const [
              StagedProgressOverlay(
                stages: [
                  ProgressStage(icon: Icons.send_rounded, label: '第一階段', seconds: 2),
                  ProgressStage(icon: Icons.spellcheck_rounded, label: '第二階段', seconds: 3),
                  ProgressStage(icon: Icons.grading_rounded, label: '最後階段', seconds: 999),
                ],
                reassureText: '安心提示',
                reassureAfterSeconds: 10,
              ),
            ],
          ),
        ),
      );

  testWidgets('所有階段都會列出，且會依時間推進', (tester) async {
    await tester.pumpWidget(wrap());

    // 每個階段的文字都要在清單裡；第一階段同時是標題，所以出現兩次
    expect(find.text('第一階段'), findsNWidgets(2));
    expect(find.text('第二階段'), findsOneWidget);
    expect(find.text('最後階段'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    // 2 秒後前進到第二階段，第一階段變成打勾
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('第二階段'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // 再 3 秒到最後階段，前兩個都打勾
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('最後階段'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });

  testWidgets('最後階段會停住等結果，不會自己跑完', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('最後階段'), findsNWidgets(2));

    // 再等很久仍停在最後階段（打勾數維持 2，不會變 3）
    await tester.pump(const Duration(seconds: 60));
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.text('最後階段'), findsNWidgets(2));
  });

  testWidgets('等太久才顯示安心提示', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('安心提示'), findsNothing);

    await tester.pump(const Duration(seconds: 11));
    expect(find.text('安心提示'), findsOneWidget);
  });
}
