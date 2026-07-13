// 檔案位置: lib/models/article_model.dart

class Article {
  final int id;
  final String theme;
  final String title;
  final String level;
  final String content;
  final String translation;
  final Map<String, dynamic>? grammarPoints;

  Article({
    required this.id,
    required this.theme,
    required this.title,
    required this.level,
    required this.content,
    required this.translation,
    this.grammarPoints,
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
    );
  }
}