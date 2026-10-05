import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/models/article_model.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/article/article_detail_screen.dart';

const _content = '<ruby>私<rt>わたし</rt></ruby>は<ruby>毎日<rt>まいにち</rt></ruby>、パンを<ruby>食<rt>た</rt></ruby>べます。'
    'そして、コーヒーを<ruby>飲<rt>の</rt></ruby>みます。<ruby>朝<rt>あさ</rt></ruby>ごはんはとても<ruby>大切<rt>たいせつ</rt></ruby>です。';

Widget _app({bool showFurigana = true}) {
  return ChangeNotifierProvider(
    create: (_) => UserProvider(),
    child: MaterialApp(
      home: ArticleDetailScreen(
        article: Article(
          id: 1,
          theme: '日常生活',
          title: '毎日の朝ごはん',
          level: 'N5',
          content: _content,
          translation: '我每天吃麵包。',
          grammarPoints: const {
            'vocabularies': [
              {'word': '毎日', 'reading': 'まいにち', 'meaning': '每天'},
              {'word': '大切', 'reading': 'たいせつ', 'meaning': '重要'},
            ]
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('點綠色的字打開字典，顯示中文解釋與文章原句', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('點擊綠色的字，可以查看解釋並加入單字本'), findsOneWidget);

    await tester.tap(find.text('大切'));
    await tester.pumpAndSettle();

    expect(find.text('單字字典'), findsOneWidget);
    expect(find.text('重要'), findsOneWidget);
    expect(find.text('文章原句'), findsOneWidget);
    // 原句是「朝ごはんはとても大切です。」，用 RichText 把「大切」標綠色
    final sentence = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == '朝ごはんはとても大切です。');
    expect(sentence, findsOneWidget);
  });

  testWidgets('關掉假名後綠色的字仍然可以點', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.text('毎日'));
    await tester.pumpAndSettle();
    expect(find.text('單字字典'), findsOneWidget);
    expect(find.text('每天'), findsOneWidget);
  });
}
