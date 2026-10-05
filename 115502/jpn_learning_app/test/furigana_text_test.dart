import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jpn_learning_app/widgets/common/furigana_text.dart';

void main() {
  const sentence = '[犬|いぬ]に[リード]をつけて、新[あたら]しい[靴|くつ]で散歩に行きました。';

  test('朗讀用的文字會去掉讀音標記與強調框', () {
    expect(FuriganaText.cleanFuriganaForTts(sentence), '犬にリードをつけて、新しい靴で散歩に行きました。');
  });

  testWidgets('AI 加的強調框 [リード] 不會把方括號顯示出來，讀音照常標在漢字上方', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FuriganaText(text: sentence))));

    final shown = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join();
    expect(shown.contains('['), isFalse);
    expect(shown.contains(']'), isFalse);
    expect(find.text('いぬ'), findsOneWidget); // 讀音
    expect(find.text('犬'), findsOneWidget);
    expect(find.text('あたら'), findsOneWidget);
    expect(find.text('リ'), findsOneWidget); // リード 照一般文字逐字排版
  });
}
