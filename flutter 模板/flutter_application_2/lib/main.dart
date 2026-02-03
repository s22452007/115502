import 'package:flutter/material.dart';
import 'model/logistic_regression_mnist.dart'; // 匯入 MNIST 數字辨識模型
import 'model/cat_dog_classifier.dart';        // 匯入貓狗分類模型
import 'pages/login_page.dart';                // 匯入登錄頁面

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 載入兩個模型
  final mnistModel = LogisticRegressionMNIST();
  final catDogModel = CatDogClassifier();
  
  // 並行載入兩個模型以提升啟動速度
  await Future.wait([
    mnistModel.loadModel(),
    catDogModel.loadModel(),
  ]);
  
  runApp(MyApp(
    mnistModel: mnistModel,
    catDogModel: catDogModel,
  ));
}

class MyApp extends StatelessWidget {
  final LogisticRegressionMNIST mnistModel;
  final CatDogClassifier catDogModel;
  
  const MyApp({
    super.key,
    required this.mnistModel,
    required this.catDogModel,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 圖片辨識系統',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: LoginPage(
        mnistModel: mnistModel,
        catDogModel: catDogModel,
      ),  // 登錄頁面作為首頁
      debugShowCheckedModeBanner: false,
    );
  }
}
