import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class StoreTab extends StatefulWidget { 
  const StoreTab({Key? key}) : super(key: key); 
  @override 
  State<StoreTab> createState() => _StoreTabState(); 
}

class _StoreTabState extends State<StoreTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

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

  void _showConfirmPurchaseDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('確認兌換', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('確定要花費 ${item['cost']} J-Pts\n兌換「${item['name']}」嗎？', style: const TextStyle(fontSize: 16, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5F8F5B)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('點數不足喔！請先儲值'), backgroundColor: Colors.redAccent));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF5F8F5B))),
    );

    try {
      final res = await ApiClient.spendPoints(userId: userId, points: cost, feature: item['id']);
      if (!mounted) return;
      Navigator.pop(context);

      if (res.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error']), backgroundColor: Colors.redAccent));
      } else {
        final newPts = (res['total_points'] as num?)?.toInt() ?? userPts - cost;
        context.read<UserProvider>().setJPts(newPts);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 兌換成功！${item['description']}'), backgroundColor: const Color(0xFF5F8F5B)));
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('網路連線失敗，請稍後再試'), backgroundColor: Colors.redAccent));
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

  IconData _iconFor(String id) {
    switch (id) {
      case 'photo_extra': return Icons.camera_alt;
      case 'ai_extra': return Icons.smart_toy;
      case 'group_deposit': return Icons.groups;
      default: return Icons.bookmark_add;
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
        _buildWalletBanner(jPts),
        const SizedBox(height: 24),
        if (_isLoading) const Center(child: CircularProgressIndicator())
        else ...displayItems.map((item) => _buildStoreItemCard(item)),
      ],
    );
  }

  Widget _buildWalletBanner(int pts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFB8C8F0))),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: Color(0xFF3B69CC), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('點數餘額', style: TextStyle(fontSize: 12, color: Color(0xFF3B69CC))),
                Text('$pts J-Pts', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3B69CC))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreItemCard(Map<String, dynamic> item) {
    final String itemId = item['id'] as String;
    final String cost = item['cost'].toString();
    
    //  判斷這是不是那個「打折商品」
    final bool isDiscounted = (itemId == 'vocab_expand_premium');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade300)
      ),
      child: Row(
        children: [
          Icon(_iconFor(itemId), color: const Color(0xFF8FB98B), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item['description'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          //  將原本只有一個按鈕的地方，包進 Column 裡面
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //  如果是打折商品，顯示紅色的刪除線原價
              if (isDiscounted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, right: 4),
                  child: Text(
                    '50 點', // 原價
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade300,
                      decoration: TextDecoration.lineThrough, // 刪除線
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F4FF), 
                  elevation: 0, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: () => _showConfirmPurchaseDialog(item),
                child: Text('$cost 點', style: const TextStyle(color: Color(0xFF3B69CC), fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }
}