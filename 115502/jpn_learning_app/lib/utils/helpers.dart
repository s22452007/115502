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
