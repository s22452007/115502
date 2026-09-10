import 'package:flutter/material.dart';
import 'package:jpn_learning_app/screens/auth/edu_login_screen.dart';
import 'package:jpn_learning_app/screens/auth/splash_screen.dart';
import 'package:jpn_learning_app/utils/constants.dart'; // 請確認你的 AppColors 路徑

class IntroScreen extends StatelessWidget {
  final bool isEdu;

  const IntroScreen({Key? key, required this.isEdu}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeColor = isEdu ? const Color(0xFF4A90E2) : AppColors.primary;
    final bgColor = isEdu ? const Color(0xFFF4F9FF) : const Color(0xFFF4FFF8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 內容可滑動區域
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 主視覺 Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(
                        bottom: BorderSide(color: themeColor.withOpacity(0.1), width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: themeColor.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Icon(
                            isEdu ? Icons.domain_verification_rounded : Icons.rocket_launch_rounded,
                            color: themeColor,
                            size: 56,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isEdu ? '校園數位賦能方案' : '個人化沉浸學習',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isEdu 
                              ? '無縫整合教學進度，打造高互動的日語學習生態系' 
                              : '打破時空限制，你的 24 小時專屬 AI 日語口說教練',
                          style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  // 解決方案優勢區塊
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '解決方案優勢',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 24),

                        if (isEdu) ...[
                          _buildZuvioFeatureItem(
                            icon: Icons.dashboard_customize_outlined,
                            tag: '教學管理',
                            title: '教學數據可視化',
                            desc: '教師可透過專屬後台，即時掌握全班的口說與造句練習數據，精準定位學生的學習盲點，大幅降低批改負擔。',
                            themeColor: themeColor,
                          ),
                          _buildZuvioFeatureItem(
                            icon: Icons.assignment_turned_in_outlined,
                            tag: '任務派發',
                            title: '無縫對接課程進度',
                            desc: '教師能一鍵派發指定文法（如 N3 句型）與單字任務，學生透過 App 直接進行情境演練，實現翻轉課堂。',
                            themeColor: themeColor,
                          ),
                          _buildZuvioFeatureItem(
                            icon: Icons.diversity_3_outlined,
                            tag: '同儕互動',
                            title: '點數激勵與小組共學',
                            desc: '導入分組闖關機制，將個人造句進度轉化為團隊積分，有效解決傳統語言學習動機低落的問題。',
                            themeColor: themeColor,
                          ),
                        ] else ...[
                          _buildZuvioFeatureItem(
                            icon: Icons.record_voice_over_outlined,
                            tag: '隨時開口',
                            title: '沉浸式情境模擬',
                            desc: '告別死背課文！提供超過數十種真實生活場景，隨時隨地與 AI 展開自然流暢的日語對話。',
                            themeColor: themeColor,
                          ),
                          _buildZuvioFeatureItem(
                            icon: Icons.gpp_good_outlined,
                            tag: '智能批改',
                            title: '零死角文法教練',
                            desc: '嚴格把關每一句話，精準揪出助詞、動詞變形與發音錯誤，並即時給予最道地的修正建議。',
                            themeColor: themeColor,
                          ),
                          _buildZuvioFeatureItem(
                            icon: Icons.center_focus_strong_outlined,
                            tag: '影像辨識',
                            title: 'Snap! 隨手拍隨手學',
                            desc: '結合領先的 AI 影像辨識技術，看到什麼拍什麼，秒速轉換為專屬日語單字卡，學習素材無限延伸。',
                            themeColor: themeColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部懸浮 CTA (Call To Action) 按鈕
          Container(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, -8),
                )
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  // 點擊後跳轉至對應登入頁（若此頁是 push 進來的，也可以選擇先 pop 再跳轉）
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => isEdu ? const EduLoginScreen() : const SplashScreen(),
                    ),
                  );
                },
                child: const Text(
                  '了解，馬上登入',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 獨立的特色項目元件
  Widget _buildZuvioFeatureItem({
    required IconData icon,
    required String tag,
    required String title,
    required String desc,
    required Color themeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側精緻 Icon 容器
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, color: themeColor, size: 28),
          ),
          const SizedBox(width: 20),
          
          // 右側介紹文案
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}