// 將之前使用的圖像分析AI註解起來
// 將之前使用的圖像分析AI註解起來
// import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class AiService {
  /// 透過 Google ML Kit 進行本地分析 (已註解停用，改由後端 MediaPipe 處理)
  Future<Map<String, dynamic>?> analyzeScene(String imagePath) async {
    return null;
    /*
    try {
      // 網頁版不支援 Google ML Kit 原生套件，採用模擬資料讓開發者可以預覽 UI
      if (kIsWeb) {
        print('Web 平台不支援 Google ML Kit，回傳模擬資料預覽 UI...');
        await Future.delayed(const Duration(seconds: 2)); // 模擬分析時間
        return {
          "success": true,
          "result": {
            "labels": ["Apple (Web Mock)", "Fruit (Mock)"],
            "text": "これはウェブ版のテストです (This is a web mock)",
          },
        };
      }

      // Android / iOS 實際執行 ML Kit
      final inputImage = InputImage.fromFilePath(imagePath);

      // 1. 物件偵測 (Image Labeling)
      final labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.6),
      );
      final List<ImageLabel> labels = await labeler.processImage(inputImage);
      await labeler.close();

      // 2. 文字辨識 (輔助)
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.japanese,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();

      List<String> detectedObjects = labels.map((l) => l.label).toList();
      String detectedText = recognizedText.text;

      // 暫時將英文單字回傳，之後可替換為翻譯邏輯
      return {
        "success": true,
        "result": {"labels": detectedObjects, "text": detectedText},
      };
    } catch (e, stacktrace) {
      print('AiService 解析失敗: $e');
      print(stacktrace);
      throw Exception('無法進行 AI 分析 (錯誤: $e)');
    }
    */
  }
}
