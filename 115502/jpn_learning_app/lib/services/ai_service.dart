import 'package:jpn_learning_app/utils/api_client.dart';

class AiService {
  /// 將這張圖片上傳給後端 AI 分析 API
  /// 成功時回傳 Map，失敗時拋出 Exception 或是回傳 null / error map
  Future<Map<String, dynamic>?> analyzeScene(String imagePath) async {
    try {
      final result = await ApiClient.analyzeImage(imagePath);

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      // 回傳 API 分析結果，例如：
      // {
      //   "message": "圖片分析成功",
      //   "file_path": "/static/photos/xxx.png",
      //   "result": { "vocabs": [...], "sentences": [...] }
      // }
      return result;
    } catch (e) {
      print('AiService 解析失敗: $e');
      throw Exception('無法連線至 AI 伺服器');
    }
  }
}
