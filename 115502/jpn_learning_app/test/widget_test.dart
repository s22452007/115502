import 'package:flutter_test/flutter_test.dart';
import 'package:jpn_learning_app_new/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JpnLearningApp());
  });
}