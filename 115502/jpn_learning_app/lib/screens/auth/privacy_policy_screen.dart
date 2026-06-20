import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隱私政策與服務條款'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F7F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Snap to Learn 隱私政策與服務條款',
                '最後更新：2026 年 6 月\n\n本應用程式（以下簡稱「本服務」）由 Snap to Learn 開發團隊提供。使用本服務前，請詳閱以下條款。'),
            _buildSection('一、收集的資料', [
              '電子郵件地址（用於帳號識別與登入）',
              '使用者名稱與頭像',
              '您拍攝並上傳的照片（僅用於即時辨識，辨識完成後不保留原始影像）',
              'AI 對話紀錄（用於學習進度追蹤）',
              '學習記錄、連續登入天數、點數等統計資料',
            ]),
            _buildSection('二、資料用途', [
              '提供日語學習辨識與 AI 對話服務',
              '儲存並顯示您的學習進度與成就',
              '計算連續登入天數與每日獎勵',
              '寄送帳號相關通知（如重置密碼）',
            ]),
            _buildSection('三、資料分享',
                '我們不會將您的個人資料出售、出租或分享給任何第三方，除非：\n\n• 依法律規定或政府機關要求\n• 為保護本服務、使用者或公眾安全所必要'),
            _buildSection('四、資料安全',
                '我們採取合理的技術與管理措施保護您的資料，包含加密儲存密碼等。雖然無法保證絕對安全，但我們將盡力維護資料安全。'),
            _buildSection('五、服務條款', [
              '本服務僅供個人學習使用，禁止用於商業目的',
              '不得上傳任何違法、侵權或不當內容',
              '我們保留在違反條款時暫停或終止帳號的權利',
              '本服務功能可能因版本更新而有所調整',
            ]),
            _buildSection('六、聯絡我們',
                '如對本隱私政策或服務條款有任何疑問，請聯繫：\n\nericyaya6610@gmail.com'),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, dynamic content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C3E50))),
          const SizedBox(height: 10),
          if (content is String)
            Text(content,
                style: const TextStyle(
                    fontSize: 14, color: Colors.black54, height: 1.7))
          else if (content is List<String>)
            ...content.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                          child: Text(item,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                  height: 1.6))),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}