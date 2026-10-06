import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jpn_learning_app/screens/article/reading_analyzing_screen.dart';

/// 朗讀評分的等待畫面：與拍照辨識共用 AnalyzingStageView，
/// 確認階段會依時間推進、等太久會出現安心提示、返回鍵不會把畫面關掉。
void main() {
  testWidgets('階段提示依時間推進，等超過 15 秒出現安心提示', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReadingAnalyzingScreen()));

    // 一開始停在第一階段：標題與清單各一次；後面的階段只出現在清單裡
    expect(find.text('正在上傳錄音…'), findsNWidgets(2));
    expect(find.text('AI 正在聆聽你的朗讀…'), findsOneWidget);
    expect(find.text('AI 正在仔細聽你的朗讀，請稍候…'), findsNothing);

    // 2 秒後進入第二階段：標題換成聆聽
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    expect(find.text('AI 正在聆聽你的朗讀…'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // 第一階段打勾

    // 滿 15 秒出現安心提示；滿 30 秒換成第二句
    await tester.pump(const Duration(seconds: 13));
    expect(find.text('AI 正在仔細聽你的朗讀，請稍候…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    expect(find.textContaining('AI 還在努力分析中'), findsOneWidget);

    // 最後一個階段會停住等結果，不會跑出清單範圍
    expect(find.text('正在整理評分報告與成績…'), findsNWidgets(2));
  });

  testWidgets('評分進行中按返回鍵不會離開等待畫面', (tester) async {
    // 從一個文章頁的替身推進等待畫面（畫面有會一直跑的動畫，不能用 pumpAndSettle）
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.push(
              ctx, MaterialPageRoute(builder: (_) => const ReadingAnalyzingScreen())),
          child: const Text('開始評分'),
        ),
      ),
    ));
    await tester.tap(find.text('開始評分'));
    await tester.pump(); // 開始推進路徑
    await tester.pump(const Duration(seconds: 1)); // 等換頁動畫跑完
    expect(find.byType(ReadingAnalyzingScreen), findsOneWidget);

    // 系統返回鍵走的是 maybePop；PopScope(canPop: false) 會把它擋下
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ReadingAnalyzingScreen), findsOneWidget);
    expect(find.text('開始評分'), findsNothing);
  });
}
