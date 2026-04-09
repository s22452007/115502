// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/main.dart';
import 'package:flutter_application_2/model/logistic_regression_mnist.dart';
import 'package:flutter_application_2/model/cat_dog_classifier.dart';

void main() {
  testWidgets('應用程式啟動測試', (WidgetTester tester) async {
    // 創建測試用的模型實例（使用隨機權重）
    final mnistModel = LogisticRegressionMNIST();
    final catDogModel = CatDogClassifier();

    // 建構並渲染應用
    await tester.pumpWidget(MyApp(
      mnistModel: mnistModel,
      catDogModel: catDogModel,
    ));

    // 等待一幀完成渲染
    await tester.pumpAndSettle();

    // 驗證登錄頁面元素
    expect(find.text('AI 圖片辨識系統'), findsOneWidget);
    expect(find.text('請登錄以開始使用'), findsOneWidget);
  });
}
