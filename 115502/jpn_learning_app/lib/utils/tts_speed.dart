import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jpn_learning_app/utils/constants.dart';

/// 語音慢速播放設定：AI 對話與單字卡共用，存在本機。
///
/// 慢速用 0.75 倍：0.5 倍整句拖太長、變速後音質也會糊掉。
class TtsSpeed {
  static const double slowRate = 0.75;
  static const String _prefKey = 'tts_slow';

  static final ValueNotifier<bool> slow = ValueNotifier(false);
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    slow.value = prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> toggle() async {
    slow.value = !slow.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, slow.value);
  }

  /// audioplayers 的播放倍率（1.0 為正常）
  static double get playbackRate => slow.value ? slowRate : 1.0;

  /// flutter_tts 的語速：手機端 0.5 才是正常速度（Android 外掛會再乘 2，
  /// iOS 預設也是 0.5），網頁版則是 1.0 為正常。
  static Future<void> applyTo(FlutterTts tts) async {
    final normal = kIsWeb ? 1.0 : 0.5;
    await tts.setSpeechRate(normal * playbackRate);
  }
}

/// 切換 1x / 0.75x 的小按鈕
class TtsSpeedChip extends StatelessWidget {
  const TtsSpeedChip({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsSpeed.slow,
      builder: (context, slow, _) => GestureDetector(
        onTap: TtsSpeed.toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: slow ? AppColors.primaryLighter : null,
            border: Border.all(
              color: slow ? AppColors.primary : Colors.grey.shade400,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            slow ? '0.75x' : '1x',
            style: TextStyle(
              color: slow ? AppColors.primary : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
