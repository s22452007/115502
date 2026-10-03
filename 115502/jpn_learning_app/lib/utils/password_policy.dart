/// 密碼強度規則（與後端 backend/utils/password_policy.py 為同一套，改這裡時兩邊要一起改）。
///
/// 規則：
///   - 少於 8 個字元：一律不能使用
///   - 一般使用者自行設定：8 個字元以上即可，強度只是參考
///   - 校園教育版學生與老師帳號：至少要「中」
enum PasswordLevel { tooShort, weak, medium, strong }

class PasswordCheck {
  final String label;
  final bool ok;
  const PasswordCheck(this.label, this.ok);
}

class PasswordEvaluation {
  final PasswordLevel level;
  final List<PasswordCheck> checks;
  const PasswordEvaluation(this.level, this.checks);

  String get label => const {
        PasswordLevel.tooShort: '太短',
        PasswordLevel.weak: '弱',
        PasswordLevel.medium: '中',
        PasswordLevel.strong: '強',
      }[level]!;
}

class PasswordPolicy {
  static const int minLength = 8;
  static const int strongLength = 12;

  static const Set<String> _common = {
    '12345678', '123456789', '1234567890', '87654321', '11111111', '00000000',
    '88888888', '66666666', '12341234', '11223344', '123123123', '147258369',
    'password', 'password1', 'password123', 'passw0rd', 'p@ssw0rd', 'p@ssword',
    'qwertyui', 'qwerty123', 'qwertyuiop', '1qaz2wsx', 'qazwsxedc', '1q2w3e4r',
    'asdfghjk', 'zxcvbnm1', 'iloveyou', 'abcd1234', 'abc12345', 'aa123456',
    'admin123', 'administrator', 'welcome1', 'letmein1', 'sunshine', 'princess',
    'football', 'baseball', 'superman', 'trustno1', 'whatever', 'dragon12',
    'snaptolearn', 'jlens123', 'teacher123', 'student123', 'guest123',
  };

  static const List<String> _sequences = [
    '01234567890123456789',
    'abcdefghijklmnopqrstuvwxyz',
    'qwertyuiopasdfghjklzxcvbnm',
    'qwertyuiop', 'asdfghjkl', 'zxcvbnm',
    '1qaz2wsx3edc4rfv5tgb', 'qazwsxedcrfvtgb',
  ];

  static int _charClasses(String pw) {
    var kinds = 0;
    if (RegExp(r'[a-z]').hasMatch(pw)) kinds++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) kinds++;
    if (RegExp(r'[0-9]').hasMatch(pw)) kinds++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(pw)) kinds++;
    return kinds;
  }

  static bool _isSequenceOrRepeat(String pw) {
    final s = pw.toLowerCase();
    if (s.split('').toSet().length <= 2) return true;
    for (final seq in _sequences) {
      final reversed = seq.split('').reversed.join();
      if (seq.contains(s) || reversed.contains(s)) return true;
    }
    return false;
  }

  static String _accountKey(String? account) {
    if (account == null) return '';
    final key = account.split('@').first.trim().toLowerCase();
    return key.length >= 3 ? key : '';
  }

  static PasswordEvaluation evaluate(String pw, {String? account}) {
    final key = _accountKey(account);
    final lowered = pw.toLowerCase();
    final common = _common.contains(lowered);
    final sequence = pw.isNotEmpty && _isSequenceOrRepeat(pw);
    final hasAccount = key.isNotEmpty && lowered.contains(key);
    final kinds = _charClasses(pw);

    final PasswordLevel level;
    if (pw.length < minLength) {
      level = PasswordLevel.tooShort;
    } else if (common || sequence || hasAccount || kinds < 2) {
      level = PasswordLevel.weak;
    } else if (pw.length >= strongLength && kinds >= 3) {
      level = PasswordLevel.strong;
    } else {
      level = PasswordLevel.medium;
    }

    return PasswordEvaluation(level, [
      PasswordCheck('至少 $minLength 個字元', pw.length >= minLength),
      PasswordCheck('包含兩種以上字元（大寫、小寫、數字、符號）', kinds >= 2),
      PasswordCheck('不是常見密碼或連續字元', pw.isNotEmpty && !(common || sequence)),
      PasswordCheck('不包含帳號名稱', !hasAccount),
      PasswordCheck('$strongLength 個字元以上更安全', pw.length >= strongLength),
    ]);
  }

  /// 可以用回傳 null，不行回傳要顯示的錯誤訊息（與後端 validate 相同）
  static String? validate(String pw, {String? account, bool requireMedium = false}) {
    final r = evaluate(pw, account: account);
    if (r.level == PasswordLevel.tooShort) return '密碼至少需要 $minLength 個字元';
    if (requireMedium && r.level == PasswordLevel.weak) {
      if (!r.checks[3].ok) return '密碼不能包含帳號名稱';
      if (!r.checks[2].ok) return '密碼太容易被猜到（常見密碼或連續字元），請換一組';
      return '密碼強度不足，請混合使用英文、數字或符號等兩種以上字元';
    }
    return null;
  }
}
