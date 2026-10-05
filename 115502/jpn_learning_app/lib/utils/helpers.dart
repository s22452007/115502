/// 共用 Helper 工具
class AppHelpers {
  /// 等級稱號（純文字，不含 Emoji）。
  /// 對使用者一律顯示稱號，不顯示 N5/N1 這類代碼，避免有人覺得等級低而卻步。
  /// 這是全 App 稱號的唯一來源，需要調整名稱時只改這裡。
  static String getLevelTitle(String? level) {
    switch ((level ?? '').toUpperCase().trim()) {
      case 'N5':
        return '新手上路';
      case 'N4':
        return '生活達人';
      case 'N3':
        return '交流無礙';
      case 'N2':
        return '商務菁英';
      case 'N1':
        return '日語大師';
      default:
        return '尚未認證';
    }
  }

  /// 內容難度（文章、題目等）的顯示文字：入門／初級／中級／中高級／高級。
  /// N5～N1 只是系統內部的參考分級，不代表真正的日語檢定程度，所以畫面上不直接顯示代碼。
  /// 跟後台、老師端用同一套名稱（backend/utils/level_names.py）。
  static String getDifficultyLabel(String? level) {
    switch ((level ?? '').toUpperCase().trim()) {
      case 'N5':
        return '入門';
      case 'N4':
        return '初級';
      case 'N3':
        return '中級';
      case 'N2':
        return '中高級';
      case 'N1':
        return '高級';
      default:
        return level ?? '';
    }
  }

  /// 將日語等級代碼轉換成顯示文字（含 Emoji），稱號一樣取自 [getLevelTitle]
  /// - N1: 日語大師 🎓
  /// - N2: 商務菁英 💼
  /// - N3: 交流無礙 🗣️
  /// - N4: 生活達人 🚶
  /// - N5: 新手上路 🌱
  static String getDisplayLevel(String? dbLevel) {
    if (dbLevel == null || dbLevel.isEmpty) return '尚未設定等級 🌱';
    const emoji = {'N1': '🎓', 'N2': '💼', 'N3': '🗣️', 'N4': '🚶', 'N5': '🌱'};
    final code = dbLevel.toUpperCase().trim();
    return '${getLevelTitle(code)} ${emoji[code] ?? '🌱'}';
  }

  /// 根據字串 Hash 計算固定的顏色代碼
  /// 相同的字串輸入會返回相同的顏色，確保展示的一致性
  /// 返回格式為 6 位的十六進制顏色代碼（例如：'E57373'）
  static String getFixedColor(String hashString) {
    final List<String> colors = [
      'E57373',
      'F06292',
      'BA68C8',
      '9575CD',
      '7986CB',
      '64B5F6',
      '4DD0E1',
      '4DB6AC',
      '81C784',
      'AED581',
      'FFB74D',
      'FF8A65',
    ];
    int hash = 0;
    for (int i = 0; i < hashString.length; i++) {
      hash = (hash * 31 + hashString.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return colors[hash % colors.length];
  }
}
