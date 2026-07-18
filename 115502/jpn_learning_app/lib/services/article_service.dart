import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/models/article_model.dart';

class ArticleService {
  static Future<List<Article>> getDashboardArticles(int userId, String level) async {
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/articles/dashboard?user_id=$userId&level=$level');
      debugPrint('👉 正在請求文章 API: $url'); 
      
      final response = await http.get(url);
      debugPrint('✅ 文章 API 狀態碼: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // 🌟 關鍵修復：強制使用 UTF-8 解碼，避免日文與中文變成亂碼導致解析失敗！
        final String responseBody = utf8.decode(response.bodyBytes);
        
        final Map<String, dynamic> decodedData = jsonDecode(responseBody);
        
        if (decodedData['status'] == 'success') {
          final List data = decodedData['data'];
          return data.map((e) => Article.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('❌ 抓取文章失敗發生錯誤: $e');
      return [];
    }
  }
}