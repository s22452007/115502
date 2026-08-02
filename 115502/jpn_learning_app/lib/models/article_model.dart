// 檔案位置: lib/models/article_model.dart

class Article {
  final int id;
  final String theme;
  final String title;
  final String level;
  final String content;
  final String translation;
  final Map<String, dynamic>? grammarPoints;
  final bool isUnlocked;

  Article({
    required this.id,
    required this.theme,
    required this.title,
    required this.level,
    required this.content,
    required this.translation,
    this.grammarPoints,
    // 🌟 新增 2：加入建構子 (預設為 true，避免其他原本沒有上鎖機制的頁面報錯)
    this.isUnlocked = true, 
  
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] ?? 0,
      theme: json['theme'] ?? '',
      title: json['title'] ?? '',
      level: json['level'] ?? '',
      content: json['content'] ?? '',
      translation: json['translation'] ?? '',
      grammarPoints: json['grammar_points'],
// 🌟 新增 3：從後端 JSON 解析解鎖狀態 (若後端沒傳，預設為 true 自由閱讀)
      isUnlocked: json['is_unlocked'] ?? true, 
    );
  }
}