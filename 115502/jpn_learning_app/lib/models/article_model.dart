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
  // 🌟 由後台設定：是否為免費文章、解鎖所需的 J-pts
  final bool isFree;
  final int unlockCost;

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
    this.isFree = false,
    this.unlockCost = 50,
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
      isFree: json['is_free'] ?? false,
      // 後台可為每篇文章設定不同價格，舊資料沒帶就用預設 50 點
      unlockCost: json['unlock_cost'] ?? 50,
    );
  }
}