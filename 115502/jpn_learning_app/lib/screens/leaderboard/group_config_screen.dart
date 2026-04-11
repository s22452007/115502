import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'invite_group_members_screen.dart'; // 準備跳轉到邀請頁面

class GroupConfigScreen extends StatefulWidget {
  const GroupConfigScreen({Key? key}) : super(key: key);

  @override
  State<GroupConfigScreen> createState() => _GroupConfigScreenState();
}

class _GroupConfigScreenState extends State<GroupConfigScreen> {
  final TextEditingController _nameController = TextEditingController();

  // 預設選擇的目標類型與數值
  String _selectedTaskType = 'scans'; // scans:拍照, points:點數, logins:登入
  int _selectedTarget = 30; // 預設為標準難度 30

  // 顏色設定 (延續你們的風格)
  final Color _textColor = const Color(0xFF333333);
  final Color _subTextColor = const Color(0xFF888888);
  final Color _cardColor = const Color(0xFFF9F9F9);

  //  根據選擇的目標，動態回傳難度數值跟單位
  Map<String, dynamic> _getDifficultyConfig() {
    if (_selectedTaskType == 'points') {
      return {'unit': '點', 'easy': 500, 'normal': 1000, 'hard': 2000};
    } else if (_selectedTaskType == 'logins') {
      return {'unit': '天', 'easy': 15, 'normal': 25, 'hard': 35};
    } else {
      // 預設 scans (探索新場景)
      return {'unit': '次', 'easy': 15, 'normal': 30, 'hard': 50};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先為小組取個響亮的名稱喔！')));
      return;
    }

    //  跳轉到原有的邀請畫面，並把設定好的資料傳過去
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InviteGroupMembersScreen(
          newGroupName: groupName,
          goalType: _selectedTaskType,
          goalTarget: _selectedTarget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 在畫面的最開始，先抓出當前應該顯示的難度設定
    final config = _getDifficultyConfig();
    final String unit = config['unit'];
    final int easyVal = config['easy'];
    final int normalVal = config['normal'];
    final int hardVal = config['hard'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '建立學習小組 (1/2)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 區塊 1：小組名稱 ---
            Text(
              '🏷️ 小組名稱',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '例如：JLPT N3 衝刺班',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: _cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // --- 區塊 2：任務類型 ---
            Text(
              '🎯 本週共同目標',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '決定你們小組這週要一起完成什麼任務',
              style: TextStyle(fontSize: 14, color: _subTextColor),
            ),
            const SizedBox(height: 16),
            _buildTaskTypeOption(
              icon: Icons.camera_alt,
              title: '探索新場景',
              subtitle: '計算全體成員拍照分析的總次數',
              value: 'scans',
            ),
            const SizedBox(height: 12),
            _buildTaskTypeOption(
              icon: Icons.monetization_on,
              title: '累積學習點數',
              subtitle: '計算全體成員獲得的 J-Pts 總和',
              value: 'points',
            ),
            const SizedBox(height: 12),
            _buildTaskTypeOption(
              icon: Icons.calendar_month,
              title: '全體共同打卡',
              subtitle: '計算全體成員每日登入的總天數',
              value: 'logins',
            ),
            const SizedBox(height: 32),

            // --- 區塊 3：動態目標難度 ---
            Text(
              '🔥 目標難度 (以滿編 5 人計算)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // 把動態算出的數值跟單位傳給按鈕
                Expanded(
                  child: _buildDifficultyButton(
                    '輕鬆',
                    easyVal,
                    unit,
                    const Color(0XFFC6DB76)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDifficultyButton(
                    '標準',
                    normalVal,
                    unit,
                    const Color(0XFFFFD568),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDifficultyButton(
                    '爆肝',
                    hardVal,
                    unit,
                    const Color(0XFFFFAFAB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              onPressed: _goToNextStep,
              child: const Text(
                '下一步：邀請好友',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 建立任務類型的選項卡片
  Widget _buildTaskTypeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = _selectedTaskType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTaskType = value; // 切換目標

          final newConfig = _getDifficultyConfig();
          _selectedTarget = newConfig['normal'];
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLighter : _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? AppColors.primary : _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.8)
                          : _subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // 🌟 升級版按鈕：接收 unit (單位)
  Widget _buildDifficultyButton(
    String label,
    int value,
    String unit,
    Color color,
  ) {
    final isSelected = _selectedTarget == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTarget = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? Colors.white : _textColor,
              ),
            ),
            const SizedBox(height: 4),
            // 🌟 這裡把 $value 和 $unit 拼在一起顯示！
            Text(
              '$value $unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : _subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
