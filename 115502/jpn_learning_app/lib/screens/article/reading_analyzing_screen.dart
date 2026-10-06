import 'package:flutter/material.dart';
import 'package:jpn_learning_app/widgets/common/analyzing_stage_view.dart';

/// 朗讀評分進行中的等待畫面，與拍照辨識的 AnalyzingScreen 同一套規格
/// （黑底、會呼吸的圖示、階段清單、等太久的安心提示）。
///
/// 只負責顯示，不打 API：錄音上傳、評分與成績結算都在 ArticleDetailScreen 執行，
/// 成功時用 pushReplacement 直接把這一頁換成評分報告，失敗則在這一頁上方跳出原因說明。
/// 評分中按返回鍵不會離開：結果回來時畫面已經不在，次數卻已經算掉了。
class ReadingAnalyzingScreen extends StatelessWidget {
  const ReadingAnalyzingScreen({Key? key}) : super(key: key);

  /// 順序對應後端 /articles/evaluate 與 /submit_score 的實際流程：
  /// 上傳錄音 → Gemini 轉錄 → Gemini 比對評分 → 存成績、結算點數
  static const List<AnalyzingStage> _stages = [
    AnalyzingStage(icon: Icons.cloud_upload_rounded, label: '正在上傳錄音…', seconds: 2),
    AnalyzingStage(icon: Icons.hearing_rounded, label: 'AI 正在聆聽你的朗讀…', seconds: 8),
    AnalyzingStage(icon: Icons.spellcheck_rounded, label: '正在比對原文並評分…', seconds: 10),
    AnalyzingStage(icon: Icons.assignment_turned_in_rounded, label: '正在整理評分報告與成績…', seconds: 999),
  ];

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: AnalyzingStageView(
          stages: _stages,
          slowHint: 'AI 正在仔細聽你的朗讀，請稍候…',
          slowerHint: '錄音比較長，AI 還在努力分析中…\n請再稍等一下',
        ),
      ),
    );
  }
}
