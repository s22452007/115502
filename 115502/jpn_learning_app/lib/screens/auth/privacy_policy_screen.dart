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
                '最後更新：2026 年 10 月\n\n本應用程式（以下簡稱「本服務」）由 Snap to Learn 開發團隊提供，包含一般版與校園教育版。使用本服務前，請詳閱以下條款；登入即表示您已閱讀並同意。'),
            _buildSection('一、收集的資料', [
              '帳號資料：電子郵件地址、使用者名稱與頭像；使用 Google 登入時，會取得您 Google 帳號的 Email 與顯示名稱',
              '照片：您拍攝並上傳辨識的照片，以及拍照時填寫的情境描述',
              '學習紀錄：單字圖鑑、AI 對話、造句與文章練習、測驗作答、連續登入天數與成就',
              '點數與訂閱：點數增減、購買與訂閱紀錄（本服務不儲存完整的信用卡資訊）',
              '校園教育版：所屬班級、作業繳交內容與成績',
              '其他：意見回饋內容、用於推播通知的裝置識別碼',
            ]),
            _buildSection('二、照片的處理方式', [
              '照片上傳前，App 會在您的手機上自動偵測人臉、證件、卡號、電話與地址，偵測到的區域會先打上馬賽克，這個步驟不會把照片傳出手機',
              '上傳後的照片會保存在本服務的伺服器，作為單字圖鑑與場景收集的照片',
              '若 AI 判定照片含不當內容，或辨識失敗，該照片會立即刪除，不會保存',
              '為維護內容安全，系統管理員可檢視並刪除違規照片',
            ]),
            _buildSection('三、資料用途', [
              '提供拍照辨識單字、AI 對話與練習批改等學習功能',
              '儲存並顯示您的學習進度、成就與點數',
              '處理點數購買與訂閱',
              '校園教育版：提供老師批改作業、計算成績與班級學習報表',
              '寄送帳號相關通知（如重設密碼）及作業、公告等推播通知',
            ]),
            _buildSection('四、第三方服務',
                '我們不會出售或出租您的個人資料。為提供服務，以下資料會交由第三方處理：\n\n• Google Gemini：分析您上傳的照片，以及 AI 對話、造句與文章練習的文字內容\n• Google Firebase：Google 帳號登入與手機推播通知\n\n除上述情形外，僅在依法律規定或政府機關要求，或為保護本服務、使用者或公眾安全所必要時，才會提供您的資料。'),
            _buildSection('五、校園教育版',
                '學生選擇學校後用學校配發的 Google 帳號登入，第一次登入會自動建立帳號，再輸入老師給的班級代碼加入班級；沒有學校 Google 帳號的學生，可使用老師建立的學號帳號登入。老師可以看到班上學生的作業繳交內容、成績與學習紀錄，用於教學與評分。教育版帳號無法在 App 內自行刪除，如需刪除請聯繫老師或系統管理員。'),
            _buildSection('六、資料安全與刪除',
                '我們採取合理的技術與管理措施保護您的資料，包含密碼加密儲存等。雖然無法保證絕對安全，但我們將盡力維護資料安全。\n\n一般版使用者可隨時在「系統設定 → 刪除帳號」永久刪除帳號，照片、學習紀錄、點數紀錄、對話與意見回饋等資料會一併刪除，且無法復原。'),
            _buildSection('七、付費訂閱與點數', [
              '訂閱方案分為月繳與年繳，新用戶可享 7 天免費試用',
              '您可隨時在「訂閱管理」取消訂閱',
              '點數僅限於本服務內使用，不可兌換現金或轉讓給其他帳號',
            ]),
            _buildSection('八、使用規範', [
              '本服務僅供個人學習與教學使用，禁止用於商業目的',
              '不得上傳任何違法、侵權、色情暴力或侵害他人隱私的內容',
              '違反條款時，我們保留暫停或終止帳號的權利',
              '本服務功能可能因版本更新而調整，條款如有重大變更將於 App 內公告',
            ]),
            _buildSection('九、聯絡我們',
                '如對本隱私政策或服務條款有任何疑問，或需要行使查詢、更正、刪除個人資料的權利，請透過以下方式與我們聯繫：\n\n• 客服信箱：snaptolearn.service@gmail.com\n• App 內「意見回饋」功能'),
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