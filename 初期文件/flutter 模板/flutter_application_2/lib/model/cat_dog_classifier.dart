import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math' as math;

/// CatDogClassifier 負責載入貓狗圖片分類的模型權重，並進行預測
class CatDogClassifier {
  late List<List<double>> W; // 權重矩陣 W，大小 2 x N（2 個類別：貓和狗）
  late List<double> b;       // 偏差向量 b，長度 2
  int inputSize = 0;         // 輸入特徵維度

  final List<String> _classNames = ['貓', '狗'];

  /// 從 assets/model/cat_dog_model.json 載入模型權重
  Future<void> loadModel() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/model/cat_dog_model.json');
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

      // 取得輸入維度
      if (W.isNotEmpty) {
        inputSize = W[0].length;
      }

      print('模型載入成功: 輸入維度=$inputSize, 類別數=${_classNames.length}');
    } catch (e) {
      print('模型載入失敗: $e');
      // 如果載入失敗，使用隨機權重作為示範
      _initializeRandomWeights(12288); // 64x64x3 = 12288
    }
  }

  /// 初始化隨機權重（當沒有模型檔案時使用）
  void _initializeRandomWeights(int featureSize) {
    final random = math.Random(42);
    inputSize = featureSize;
    
    W = List.generate(2, (_) => 
      List.generate(featureSize, (_) => (random.nextDouble() - 0.5) * 0.01)
    );
    
    b = List.generate(2, (_) => 0.0);
    
    print('使用隨機權重初始化模型（示範用）');
  }

  /// 預測函數：輸入 x 為圖片特徵向量，回傳預測結果字串
  String predict(List<double> x) {
    if (x.length != inputSize && inputSize > 0) {
      // 如果輸入維度不匹配，進行適配
      if (x.length > inputSize) {
        x = x.sublist(0, inputSize);
      } else {
        x = [...x, ...List.filled(inputSize - x.length, 0.0)];
      }
    }

    final logits = List<double>.filled(2, 0.0);  // 用來存放每個類別的得分

    // 計算 z = W * x + b
    for (int c = 0; c < 2; c++) {
      double sum = b[c];       // 先加上該類別的偏差項 b_c
      final wRow = W[c];       // 取出第 c 類別對應的權重列向量
      final len = math.min(wRow.length, x.length);
      for (int i = 0; i < len; i++) {
        sum += wRow[i] * x[i]; // 累加權重 * 像素值
      }
      logits[c] = sum;         // 得到第 c 類別的 logit
    }

    // Softmax 計算機率
    final maxLogit = logits.reduce(math.max);
    double expSum = 0.0;
    final exps = List<double>.filled(2, 0.0);
    for (int c = 0; c < 2; c++) {
      final v = math.exp(logits[c] - maxLogit);
      exps[c] = v;
      expSum += v;
    }

    // 找出最大機率的類別
    int bestClass = 0;
    double bestProb = -1.0;
    for (int c = 0; c < 2; c++) {
      final p = exps[c] / expSum;
      if (p > bestProb) {
        bestProb = p;
        bestClass = c;
      }
    }

    final confidence = (bestProb * 100).toStringAsFixed(1);
    return '這是${_classNames[bestClass]} (信心度: $confidence%)';
  }

  /// 取得類別名稱列表
  List<String> get classNames => _classNames;
}
