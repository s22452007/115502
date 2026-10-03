import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/password_policy.dart';

/// 密碼強度條＋檢查清單，放在密碼輸入框下方，輸入時即時更新。
///
/// [accountController] 有帶時會一併檢查「密碼不能包含帳號名稱」。
/// [requireMedium] 為 true 時，會標示「至少需要中」（學生與老師帳號）。
class PasswordStrengthMeter extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController? accountController;
  final String? account;
  final bool requireMedium;

  const PasswordStrengthMeter({
    super.key,
    required this.controller,
    this.accountController,
    this.account,
    this.requireMedium = false,
  });

  static const _colors = {
    PasswordLevel.tooShort: Color(0xFFE57373),
    PasswordLevel.weak: Color(0xFFEF8A3C),
    PasswordLevel.medium: Color(0xFFE2B33B),
    PasswordLevel.strong: Color(0xFF4E8B57),
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, ?accountController]),
      builder: (context, _) {
        final pw = controller.text;
        if (pw.isEmpty) return const SizedBox.shrink();

        final result = PasswordPolicy.evaluate(
          pw,
          account: accountController?.text ?? account,
        );
        final color = _colors[result.level]!;
        final filled = result.level.index + 1; // 太短 1 格、弱 2 格、中 3 格、強 4 格
        final notEnough = result.level == PasswordLevel.tooShort ||
            (requireMedium && result.level == PasswordLevel.weak);

        return Padding(
          padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: i < filled ? color : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    if (i < 3) const SizedBox(width: 4),
                  ],
                  const SizedBox(width: 10),
                  Text(
                    '強度：${result.label}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              if (notEnough)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    result.level == PasswordLevel.tooShort
                        ? '密碼至少需要 ${PasswordPolicy.minLength} 個字元'
                        : '這個帳號的密碼強度至少需要「中」',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFD9534F)),
                  ),
                ),
              const SizedBox(height: 6),
              for (final c in result.checks)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(
                        c.ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 14,
                        color: c.ok ? const Color(0xFF4E8B57) : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.ok ? Colors.black54 : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
