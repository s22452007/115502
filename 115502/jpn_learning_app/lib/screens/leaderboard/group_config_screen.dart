import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'invite_group_members_screen.dart'; 

import 'package:jpn_learning_app/widgets/study_group/task_type_card.dart';
import 'package:jpn_learning_app/widgets/study_group/difficulty_button.dart';

class GroupConfigScreen extends StatefulWidget {
  const GroupConfigScreen({Key? key}) : super(key: key);

  @override
  State<GroupConfigScreen> createState() => _GroupConfigScreenState();
}

class _GroupConfigScreenState extends State<GroupConfigScreen> {
  final TextEditingController _nameController = TextEditingController();

  String _selectedTaskType = 'scans'; 
  int _selectedTarget = 30; 

  final Color _textColor = const Color(0xFF333333);
  final Color _subTextColor = const Color(0xFF888888);
  final Color _cardColor = const Color(0xFFF9F9F9);

  Map<String, dynamic> _getDifficultyConfig() {
    if (_selectedTaskType == 'points') {
      return {'unit': '點', 'easy': 500, 'normal': 1000, 'hard': 2000};
    } else if (_selectedTaskType == 'logins') {
      return {'unit': '天', 'easy': 15, 'normal': 25, 'hard': 35};
    } else {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先為小組取個響亮的名稱喔！')));
      return;
    }

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

  void _handleTaskTypeChange(String newType) {
    setState(() {
      _selectedTaskType = newType;
      _selectedTarget = _getDifficultyConfig()['normal'];
    });
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('建立學習小組 (1/2)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 區塊 1：小組名稱 ---
            Text('🏷️ 小組名稱', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '例如：JLPT N3 衝刺班',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: _cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(height: 32),

            // --- 區塊 2：任務類型 ---
            Text('🎯 本週共同目標', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 8),
            Text('決定你們小組這週要一起完成什麼任務', style: TextStyle(fontSize: 14, color: _subTextColor)),
            const SizedBox(height: 16),
            
            // 🌟 使用抽離出來的積木
            TaskTypeCard(
              icon: Icons.camera_alt,
              title: '探索新場景',
              subtitle: '計算全體成員拍照分析的總次數',
              isSelected: _selectedTaskType == 'scans',
              onTap: () => _handleTaskTypeChange('scans'),
            ),
            const SizedBox(height: 12),
            TaskTypeCard(
              icon: Icons.calendar_month,
              title: '全體共同打卡',
              subtitle: '計算全體成員每日登入的總天數',
              isSelected: _selectedTaskType == 'logins',
              onTap: () => _handleTaskTypeChange('logins'),
            ),
            const SizedBox(height: 32),

            // --- 區塊 3：動態目標難度 ---
            Text('🔥 目標難度 (以滿編 5 人計算)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 16),
            Row(
              children: [
                // 🌟 使用抽離出來的積木
                Expanded(
                  child: DifficultyButton(
                    label: '輕鬆',
                    value: easyVal,
                    unit: unit,
                    activeColor: const Color(0XFFC6DB76),
                    isSelected: _selectedTarget == easyVal,
                    onTap: () => setState(() => _selectedTarget = easyVal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DifficultyButton(
                    label: '標準',
                    value: normalVal,
                    unit: unit,
                    activeColor: const Color(0XFFFFD568),
                    isSelected: _selectedTarget == normalVal,
                    onTap: () => setState(() => _selectedTarget = normalVal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DifficultyButton(
                    label: '爆肝',
                    value: hardVal,
                    unit: unit,
                    activeColor: const Color(0XFFFFAFAB),
                    isSelected: _selectedTarget == hardVal,
                    onTap: () => setState(() => _selectedTarget = hardVal),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              onPressed: _goToNextStep,
              child: const Text('下一步：邀請好友', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}