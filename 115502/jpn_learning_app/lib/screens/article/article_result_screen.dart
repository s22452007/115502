import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class ArticleResultScreen extends StatelessWidget {
  final Map<String, dynamic> resultData;

  const ArticleResultScreen({Key? key, required this.resultData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 解析評估數據
    final int score = (resultData['score'] is String) ? int.parse(resultData['score']) : (resultData['score'] as int? ?? 0);
    final String completionRate = resultData['completion_rate'] ?? "0%";
    final String overallFeedback = resultData['overall_feedback'] ?? "分析完成，請持續保持練習。";
    final List<dynamic> mistakes = resultData['mistakes'] ?? [];

    // 🌟 嚴格同步主頁 (HomeScreen) 的色彩與文字系統
    const Color textColor = Color(0xFF2C3E50); 
    const Color subTextColor = Color(0xFF8E9AAB);
    const Color flatCanvasColor = Color(0xFFF4F7F5);

    // 依分數決定狀態色彩 (綠、橘、紅)
    Color statusColor = AppColors.primary;
    if (score < 60) {
      statusColor = const Color(0xFFE74C3C); 
    } else if (score < 80) {
      statusColor = Colors.orange; 
    }

    // 嚴格同步主頁的輕盈卡片陰影
    final cardShadow = [
      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
    ];

    return Scaffold(
      backgroundColor: flatCanvasColor,
      appBar: AppBar(
        backgroundColor: flatCanvasColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false, // 隱藏預設返回
        title: const Text(
          '發音評估報告',
          style: TextStyle(fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('綜合評估', textColor),
            
            // 1. 分數大卡片 (同步主頁「打卡日曆」的設計：Radius 30, 內部大留白)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: cardShadow,
              ),
              child: Row(
                children: [
                  // 左側：分數圓環
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 8,
                            backgroundColor: flatCanvasColor,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                        Text(
                          '$score',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: statusColor, height: 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  
                  // 右側：數據文字
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('完成度', style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          completionRate,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            score >= 80 ? '表現優異' : (score >= 60 ? '繼續保持' : '需要加強'),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 35),

            // 2. 評語卡片 (同步主頁「文章練習」卡片的設計：Radius 20, 獨立 Icon Box)
            _buildSectionHeader('導師評語', textColor),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: cardShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 同步主頁的 Icon Box 設計 (圓角 15, 透明度 0.1)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      overallFeedback,
                      style: const TextStyle(fontSize: 15, height: 1.6, color: textColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // 3. 錯誤列表 (同樣使用 Radius 20 卡片與 Icon Box 設計)
            _buildSectionHeader('待改善細節', textColor),
            if (mistakes.isNotEmpty) ...[
              ...mistakes.map((m) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: cardShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.error_outline_rounded, color: Color(0xFFE74C3C), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          m.toString(),
                          style: const TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w600, height: 1.6),
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '發音極為標準，未偵測到明顯瑕疵。',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 40),
            
            // 4. 返回按鈕 (維持主頁風格，無陰影，圓角 16)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '完成練習',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 🌟 完全拷貝主頁 `_buildSectionHeader` 的排版規格
  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5),
      ),
    );
  }
}