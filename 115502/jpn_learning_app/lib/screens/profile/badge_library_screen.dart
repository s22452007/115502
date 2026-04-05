import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/badge_model.dart'; 
import '../../providers/user_provider.dart';

class BadgeLibraryScreen extends StatelessWidget {
  BadgeLibraryScreen({Key? key}) : super(key: key);

  // 系統中所有的徽章定義清單 
  final List<BadgeModel> allBadges = [
    // 1. 場景探索類
    BadgeModel(id: 'food_01', title: '美食導航員', description: '成功辨識 10 種不同的日本料理。', lockedHint: '快去拍下眼前的日式美食，解鎖此徽章！', icon: Icons.restaurant, category: '場景探索'),
    BadgeModel(id: 'ramen_01', title: '拉麵大師', description: '累計辨識 5 種不同流派的拉麵場景。', lockedHint: '再收集幾種拉麵，你就能成為真正的拉麵職人！', icon: Icons.ramen_dining, category: '場景探索'),
    BadgeModel(id: 'traffic_01', title: '交通達人', description: '在「車站」或「機場」分類下，累計完成 10 次場景辨識。', lockedHint: '在旅途移動中也能學習！去車站拍張照片吧。', icon: Icons.train, category: '場景探索'),
    BadgeModel(id: 'dessert_01', title: '甜點控', description: '成功辨識 5 種和菓子或日式甜點。', lockedHint: '吃甜點前別忘了先拍照學習喔！', icon: Icons.cake, category: '場景探索'),
    BadgeModel(id: 'shop_01', title: '購物狂', description: '在「藥妝店」或「超市」場景完成 10 次辨識。', lockedHint: '準備好血拼了嗎？去商店街尋找目標吧！', icon: Icons.shopping_bag, category: '場景探索'),
    BadgeModel(id: 'sightseeing_01', title: '景點打卡王', description: '辨識 5 個著名景點或神社寺廟。', lockedHint: '出外踏青，開啟相機記錄你的足跡！', icon: Icons.camera_alt, category: '場景探索'),
    BadgeModel(id: 'street_01', title: '街頭觀察家', description: '辨識販賣機、郵筒等 10 種日本街頭常見事物。', lockedHint: '日本的街頭藏著許多驚喜，仔細觀察並拍下來！', icon: Icons.storefront, category: '場景探索'),
    BadgeModel(id: 'night_01', title: '深夜食堂', description: '在晚上 10 點後，辨識「居酒屋」場景並完成學習。', lockedHint: '深夜的學習更有感，去居酒屋小試身手吧！', icon: Icons.nightlife, category: '場景探索'),

    // 2. 學習成就類
    BadgeModel(id: 'novice_01', title: '初試啼聲', description: '完成註冊後的第一場程度快速測驗。', lockedHint: '先了解自己的日文實力，踏出學習的第一步！', icon: Icons.assignment_turned_in, category: '學習成就'),
    BadgeModel(id: 'all_rounder_01', title: '全能學習者', description: '能力雷達圖的五項指標皆達到 Lv.3 以上。', lockedHint: '不要偏廢！平衡提升你的五向能力值。', icon: Icons.military_tech, category: '學習成就'),
    BadgeModel(id: 'vocab_01', title: '字典絕緣體', description: '累計透過拍照學習超過 50 個新單字。', lockedHint: '多拍多學，將你的大腦變成最強字典！', icon: Icons.translate, category: '學習成就'),
    BadgeModel(id: 'speaking_01', title: '道地口語家', description: '在「情境角色扮演」中，獲得 3 次 AI 自然度評分 90% 以上。', lockedHint: '調整發音與用詞，挑戰最道地的日語表達！', icon: Icons.record_voice_over, category: '學習成就'),
    BadgeModel(id: 'grammar_01', title: '語法通', description: '完整閱讀 20 則「語法小教室」內容，掌握禮貌用語。', lockedHint: '深入了解日文背後的文化邏輯，就在語法小教室。', icon: Icons.menu_book, category: '學習成就'),
    BadgeModel(id: 'listening_01', title: '順風耳', description: '在無字幕提示下，成功完成 5 次情境對話。', lockedHint: '試著閉上眼睛聽，考驗你的日語聽力！', icon: Icons.hearing, category: '學習成就'),
    BadgeModel(id: 'culture_01', title: '文化探險家', description: '解鎖並閱讀 10 個日本文化豆知識。', lockedHint: '語言的背後是文化，去發掘更多日本的小知識吧！', icon: Icons.temple_buddhist, category: '學習成就'),
    BadgeModel(id: 'perfect_rp_01', title: '完美對話', description: '在一次角色扮演中，完全沒有使用翻譯或提示功能。', lockedHint: '挑戰自己，來一場全日文的真實對決！', icon: Icons.chat_bubble, category: '學習成就'),

    // 3. 社群與互動類
    BadgeModel(id: 'leader_01', title: '小組領頭羊', description: '在學習小組中，率先完成每日共同目標。', lockedHint: '成為團隊的榜樣，衝刺每日任務！', icon: Icons.flag, category: '社群互動'),
    BadgeModel(id: 'teammate_01', title: '榮譽隊友', description: '使用「提醒隊友」功能，且隊友隨後成功完成任務。', lockedHint: '一個人走得快，一群人走得遠，快去關心你的隊友！', icon: Icons.group_add, category: '社群互動'),
    BadgeModel(id: 'question_01', title: '問答模範生', description: '針對拍照場景，向真人導師或 AI 發問累計 5 次。', lockedHint: '有疑問就發問！善用提問功能解決學習痛點。', icon: Icons.question_answer, category: '社群互動'),
    BadgeModel(id: 'rank_01', title: '榜上有名', description: '在任一週的「學習排行榜」中進入前 10 名。', lockedHint: '努力累積 Points，在排行榜上留下你的名字！', icon: Icons.emoji_events, category: '社群互動'),
    BadgeModel(id: 'social_01', title: '呼朋引伴', description: '成功邀請 1 位好友加入 App 並成為好友。', lockedHint: '獨樂樂不如眾樂樂，邀請朋友一起來學日文！', icon: Icons.share, category: '社群互動'),

    // 4. 遊戲化激勵與習慣類
    BadgeModel(id: 'streak_07', title: '毅力獎章', description: '達成連續 7 天登入並完成至少一個學習任務。', lockedHint: '持之以恆是學習的關鍵，保持你的連勝紀錄！', icon: Icons.local_fire_department, category: '遊戲與習慣'),
    BadgeModel(id: 'streak_30', title: '學習狂熱者', description: '達成連續 30 天登入學習的驚人紀錄！', lockedHint: '挑戰 30 天不間斷，讓日文成為你的生活習慣。', icon: Icons.whatshot, category: '遊戲與習慣'),
    BadgeModel(id: 'collection_01', title: '場景收集控', description: '在「照片收藏夾」中，解鎖所有 8 種預設場景。', lockedHint: '你的日語地圖還缺幾塊？快去探索新場景！', icon: Icons.photo_album, category: '遊戲與習慣'),
    BadgeModel(id: 'early_bird_01', title: '早鳥先飛', description: '在早上 7 點前完成一次學習任務。', lockedHint: '一日之計在於晨，早起學個日文吧！', icon: Icons.wb_sunny, category: '遊戲與習慣'),
    BadgeModel(id: 'premium_01', title: '資深學員', description: '升級訂閱 Premium 方案或單次購買超過 3000 點。', lockedHint: '解鎖無限次 AI 對話功能，讓學習不中斷！', icon: Icons.workspace_premium, category: '遊戲與習慣'),
  ];

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final unlockedCount = userProvider.unlockedBadgeIds.length;
    final totalBadges = allBadges.length;
    final progress = totalBadges == 0 ? 0.0 : unlockedCount / totalBadges;

    // 🌟 將徽章按類型分組
    final groupedBadges = {
      '📍 場景探索': allBadges.where((badge) => badge.category == '場景探索').toList(),
      '📖 學習成就': allBadges.where((badge) => badge.category == '學習成就').toList(),
      '👥 社群與互動': allBadges.where((badge) => badge.category == '社群互動').toList(),
      '🔥 習慣與連勝': allBadges.where((badge) => badge.category == '遊戲與習慣').toList(),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('成就徽章庫', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.green[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 進度摘要大卡片
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text('總收集進度', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('$unlockedCount / $totalBadges 個解鎖', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green[800])),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green[500]!),
                          minHeight: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 動態生成徽章分類區塊
              ...groupedBadges.entries.map((entry) {
                final category = entry.key;
                final badges = entry.value;
                if (badges.isEmpty) return const SizedBox.shrink(); // 如果該分類沒東西就不畫

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    const SizedBox(height: 16),
                    // 徽章網格
                    Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      children: badges.map((badge) {
                        final isUnlocked = userProvider.isBadgeUnlocked(badge.id);
                        final unlockDate = userProvider.getBadgeUnlockDate(badge.id); 
                        final progressList = userProvider.getBadgeProgress(badge.id); 

                        return GestureDetector(
                          onTap: () => _showBadgeDialog(context, badge, isUnlocked, unlockDate, progressList),
                          child: _buildBadgeCard(context, badge, isUnlocked, progressList),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // 構建單個徽章卡片
  Widget _buildBadgeCard(BuildContext context, BadgeModel badge, bool isUnlocked, List<int> progressList) {
    final double cardWidth = (MediaQuery.of(context).size.width - 56) / 3; // 算好三等分寬度
    final progress = progressList.isEmpty ? 0 : 25; // 暫時給定一個假進度
    final nextMilestone = progressList.isEmpty ? 100 : progressList.firstWhere((p) => p > progress, orElse: () => progressList.last);

    return Container(
      width: cardWidth,
      height: 150,
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnlocked ? Colors.green.shade200 : Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 卡通圖像 (從網路抓佔位圖)
          Expanded(
            child: Center(
              child: ColorFiltered(
                colorFilter: isUnlocked
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                    : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                child: Image.network(
                  'https://ui-avatars.com/api/?name=${Uri.encodeComponent(badge.title)}&background=ffffff&color=4A7C59&size=128',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 徽章標題
          Text(
            badge.title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.black87 : Colors.grey[600]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // 進度標示
          isUnlocked
              ? const Text('已解鎖', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))
              : Text('$progress / $nextMilestone', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // 詳情彈窗
  void _showBadgeDialog(BuildContext context, BadgeModel badge, bool isUnlocked, String? unlockDate, List<int> progressList) {
    showDialog(
      context: context,
      builder: (context) {
        final progress = progressList.isEmpty ? 0 : 25; // 假進度

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 大徽章圖像
                SizedBox(
                  width: 120,
                  height: 120,
                  child: ColorFiltered(
                    colorFilter: isUnlocked
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                        : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                    child: Image.network(
                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(badge.title)}&background=E8F5E9&color=4A7C59&size=256',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 徽章標題和類別
                Text(badge.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(badge.category, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 16),
                
                // 解鎖日期
                if (isUnlocked && unlockDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)),
                    child: Text('於 $unlockDate 獲得！', style: TextStyle(fontSize: 13, color: Colors.green[800], fontWeight: FontWeight.bold)),
                  ),
                
                const SizedBox(height: 16),
                
                // 詳細說明
                Text(
                  isUnlocked ? badge.description : badge.lockedHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                ),
                const SizedBox(height: 24),
                
                // 里程碑進度條 
                if (progressList.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('進度里程碑：', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: progressList.map((p) {
                            final isReached = progress >= p || isUnlocked;
                            return Container(
                              width: 50,
                              height: 50,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isReached ? Colors.green[100] : Colors.grey[100],
                                shape: BoxShape.circle,
                                border: isReached ? Border.all(color: Colors.green[400]!, width: 2) : Border.all(color: Colors.transparent),
                              ),
                              child: Center(
                                child: Text(
                                  p.toString(),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isReached ? Colors.green[800] : Colors.grey[500]),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                const SizedBox(height: 24),
                
                // 按鈕
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (!isUnlocked) {
                        Provider.of<UserProvider>(context, listen: false).unlockBadge(badge.id);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 測試解鎖成功：${badge.title}'), backgroundColor: Colors.green[700]));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUnlocked ? Colors.green[700] : Colors.grey[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(isUnlocked ? '炫耀一下' : '前往任務 (點擊測試解鎖)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}