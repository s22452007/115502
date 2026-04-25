/// 共用 Helper 工具
class AppHelpers {
  /// 將日語等級代碼轉換成顯示文字（含 Emoji）
  /// - N1: 日語大師 🎓
  /// - N2: 商務菁英 💼
  /// - N3: 交流無礙 🗣️
  /// - N4: 生活達人 🚶
  /// - N5: 日語新手 🌱
  static String getDisplayLevel(String? dbLevel) {
    if (dbLevel == null || dbLevel.isEmpty) return '尚未設定等級 🌱';
    switch (dbLevel) {
      case 'N1':
        return '日語大師 🎓';
      case 'N2':
        return '商務菁英 💼';
      case 'N3':
        return '交流無礙 🗣️';
      case 'N4':
        return '生活達人 🚶';
      case 'N5':
      default:
        return '日語新手 🌱';
    }
  }
