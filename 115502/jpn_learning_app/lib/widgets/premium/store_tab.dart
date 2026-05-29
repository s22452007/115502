import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';

class StoreTab extends StatefulWidget { 
  const StoreTab({Key? key}) : super(key: key); 
  @override 
  State<StoreTab> createState() => _StoreTabState(); 
}

class _StoreTabState extends State<StoreTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  // 🌟 統一的扁平化配色設定
  static const Color _textDark = Color(0xFF2C3E50);
  static const Color _subText = Color(0xFF8E9AAB);

  @override
  void initState() { super.initState(); _loadItems(); }

  Future<void> _loadItems() async {
    final res = await ApiClient.getStoreItems();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.containsKey('items')) _items = List<Map<String, dynamic>>.from(res['items']);
    });
  }

  // 🌟 扁平化確認對話框 (大圓角、零陰影)
  void _showConfirmPurchaseDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('確認兌換', style: TextStyle(fontWeight: FontWeight.w900, color: _textDark)),
        content: Text('確定要花費 ${item['cost']} J-Pts\n兌換「${item['name']}」嗎？', style: const TextStyle(fontSize: 15, height: 1.5, color: _textDark, fontWeight: FontWeight.w600)),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('取消', style: TextStyle(color: _subText, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executePurchase(item);
            },
            child: const Text('確定兌換', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executePurchase(Map<String, dynamic> item) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    final cost = (item['cost'] as num).toInt();
    final userPts = context.read<UserProvider>().jPts;

    if (userPts < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('點數不足喔！請先儲值', style: TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final res = await ApiClient.spendPoints(userId: userId, points: cost, feature: item['id']);
      if (!mounted) return;
      Navigator.pop(context); // 關閉 Loading

      if (res.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'], style: const TextStyle(fontWeight: FontWeight.bold)), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      } else {
        final newPts = (res['total_points'] as num?)?.toInt() ?? userPts - cost;
        context.read<UserProvider>().setJPts(newPts);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('兌換成功！${item['description']}', style: const TextStyle(fontWeight: FontWeight.bold)), 
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('網路連線失敗，請稍後再試', style: TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )
      );
    }
  }

  List<Map<String, dynamic>> _filterItems(bool isPremium) {
    return _items.where((item) {
      final id = item['id'] as String;
      if (id == 'vocab_expand_premium') return isPremium;
      if (id == 'vocab_expand') return !isPremium;
      return true;
    }).toList();
  }

  // 🌟 將圖示微調為帶有圓角的質感 Icon
  IconData _iconFor(String id) {
    switch (id) {
      case 'photo_extra': return Icons.camera_alt_rounded;
      case 'ai_extra': return Icons.smart_toy_rounded;
      case 'group_deposit': return Icons.groups_rounded;
      default: return Icons.bookmark_add_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final jPts = user.jPts;
    final isPremium = user.isPremium;
    final displayItems = _filterItems(isPremium);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── 🌟 錢包區塊 (與儲值點數分頁完全同款) ──
        _buildWalletBanner(jPts),
        const SizedBox(height: 24),
        
        if (_isLoading) 
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else 
          ...displayItems.map((item) => _buildStoreItemCard(item)),
      ],
    );
  }

  // 💰 點數餘額卡片 (純綠底色，與 BuyPointsTab 完美鏡像)
  Widget _buildWalletBanner(int pts) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary, 
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('目前可用點數', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$pts J-Pts', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  // 🛍️ 商品項目卡片 (純白底色，移除外框線)
  Widget _buildStoreItemCard(Map<String, dynamic> item) {
    final String itemId = item['id'] as String;
    final String cost = item['cost'].toString();
    final bool isDiscounted = (itemId == 'vocab_expand_premium');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(_iconFor(itemId), color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
                const SizedBox(height: 4),
                Text(item['description'], style: const TextStyle(fontSize: 12, color: _subText, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 如果是會員打折商品，顯示亮橘色的原價刪除線
              if (isDiscounted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Text(
                    '50 點', 
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFFFF7043).withOpacity(0.8),
                      decoration: TextDecoration.lineThrough, 
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  // 打折商品使用扁平橘色，普通商品使用淡綠底色
                  backgroundColor: isDiscounted ? const Color(0xFFFF7043) : AppColors.primary.withOpacity(0.1), 
                  elevation: 0, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                ),
                onPressed: () => _showConfirmPurchaseDialog(item),
                child: Text(
                  '$cost 點', 
                  style: TextStyle(
                    color: isDiscounted ? Colors.white : AppColors.primary, 
                    fontWeight: FontWeight.w900,
                    fontSize: 14
                  )
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}