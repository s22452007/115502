import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' as math;

/// LogisticRegressionMNIST 負責載入手寫數字辨識的模型權重，並進行預測
class LogisticRegressionMNIST {
  late List<List<double>> W; // 權重矩陣 W，大きさ 10 x 784（10 個類別，每個784維權重）
  late List<double> b;       // 偏差向量 b，長度 10

  /// 從 assets/model/mnist_logreg.json 載入模型權重
  Future<void> loadModel() async {
    final jsonStr = await rootBundle.loadString('assets/model/mnist_logreg.json');
    final data = json.decode(jsonStr);

    // 解析 JSON 內容為二維 List<double> 與 List<double>
    W = (data['W'] as List<dynamic>)
        .map<List<double>>((row) =>
            (row as List<dynamic>).map<double>((e) => (e as num).toDouble()).toList()
        )
        .toList();

    b = (data['b'] as List<dynamic>)
        .map<double>((e) => (e as num).toDouble())
        .toList();
  }

  /// 預測函數：輸入 x 為長度784的雙精度數組（各值介於0~1），回傳預測的數字類別 0~9
  int predict(List<double> x) {
    final logits = List<double>.filled(10, 0.0);  // 用來存放每個數字類別的得分 z值

    // 計算 z = W * x + b
    for (int c = 0; c < 10; c++) {
      double sum = b[c];       // 先加上該類別的偏差項 b_c
      final wRow = W[c];       // 取出第 c 類別對應的權重列向量
      for (int i = 0; i < 784; i++) {
        sum += wRow[i] * x[i]; // 累加權重 * 像素值
      }
      logits[c] = sum;         // 得到第 c 類別的 logit（尚未 softmax 的分數）
    }

    // Softmax 前的數值穩定處理：減去最大值，防止指數溢位
    final maxLogit = logits.reduce(math.max);
    double expSum = 0.0;
    final exps = List<double>.filled(10, 0.0);
    for (int c = 0; c < 10; c++) {
      final v = math.exp(logits[c] - maxLogit);
      exps[c] = v;
      expSum += v;
    }

    // 計算 softmax 機率並找出最大機率的類別
    int bestClass = 0;
    double bestProb = -1.0;
    for (int c = 0; c < 10; c++) {
      final p = exps[c] / expSum;    // 第 c 類的機率
      if (p > bestProb) {
        bestProb = p;
        bestClass = c;
      }
    }

    return bestClass;
  }
}
