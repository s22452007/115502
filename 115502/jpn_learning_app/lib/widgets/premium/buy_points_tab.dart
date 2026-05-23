import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/premium/point_checkout_screen.dart';

class BuyPointsTab extends StatefulWidget {
  const BuyPointsTab({Key? key}) : super(key: key);
  @override
  State<BuyPointsTab> createState() => _BuyPointsTabState();
}

class _BuyPointsTabState extends State<BuyPointsTab> {
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingPkgs = true;
  bool _isLoadingTxns = true;

  static const Color _textDark = Color(0xFF333333);
  static const Color _subText = Color(0xFF7A7A7A);
  static const Color _green = Color(0xFF5F8F5B);
  static const Color _lightGreen = Color(0xFFE8F0DD);

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _loadTransactions();
  }

  Future<void> _loadPackages() async {
    final res = await ApiClient.getPointPackages();
    if (!mounted) return;
    setState(() {
      _isLoadingPkgs = false;
      if (res.containsKey('packages')) {
        _packages = List<Map<String, dynamic>>.from(res['packages']);
      }
    });
  }

  Future<void> _loadTransactions() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoadingTxns = false);
      return;
    }
    
    final res = await ApiClient.getTransactions(userId);
    if (!mounted) return;
    setState(() {
      _isLoadingTxns = false;
      if (res.containsKey('transactions')) {
        _transactions = List<Map<String, dynamic>>.from(res['transactions']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final jPts = context.watch<UserProvider>().jPts;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 💰 錢包區塊
        _buildWalletCard(jPts),
        const SizedBox(height: 24),

        // 🛒 儲值方案區塊
        const Text('選擇儲值方案', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
        const SizedBox(height: 12),
        if (_isLoadingPkgs) 
          const Center(child: CircularProgressIndicator())
        else 
          ..._packages.map((pkg) => _buildPackageCard(context, pkg)),
        
        const SizedBox(height: 24),

        // 📜 交易紀錄區塊
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('交易紀錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: _subText),
              onPressed: () {
                setState(() => _isLoadingTxns = true);
                _loadTransactions();
              },
            )
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingTxns)
          const Center(child: CircularProgressIndicator())
        else if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: const Text('尚無交易紀錄', style: TextStyle(color: _subText)),
          )
        else
          ..._transactions.map((txn) => _buildTransactionCard(txn)),
      ],
    );
  }

  Widget _buildWalletCard(int pts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFF7FAF2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD4E1C8))),
      child: Row(
        children: [
          Container(width: 50, height: 50, decoration: const BoxDecoration(color: _lightGreen, shape: BoxShape.circle), child: const Icon(Icons.monetization_on_outlined, color: _green, size: 30)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('目前點數', style: TextStyle(fontSize: 14, color: _subText)),
              Text('$pts J-Pts', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _textDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, Map<String, dynamic> pkg) {
    final pts = (pkg['points'] as num).toInt();
    final price = (pkg['price'] as num).toInt();
    final tag = pkg['tag'] as String? ?? '';
    final name = pkg['name'] as String? ?? '$pts Points';

    // 計算每點價格和標籤
    final double pricePerPoint = price / pts;
    final String pricePerPointText = '每點約 NT\$${pricePerPoint.toStringAsFixed(2)}';
    final String badgeText = tag.isEmpty ? _getDefaultBadge(pts) : tag;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          const Icon(Icons.generating_tokens, color: Color(0xFFF0B84B), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$pts J-Pts', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (badgeText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeText == '最划算' ? const Color(0xFFFFB84D) : const Color(0xFFF0B84B),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Text(badgeText, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))
                      ),
                    ]
                  ],
                ),
                Text(name, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(pricePerPointText, style: const TextStyle(fontSize: 12, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PointCheckoutScreen(title: name, points: pts, price: price, badge: badgeText, subtitle: pkg['description']))),
            child: Text('NT\$$price', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  String _getDefaultBadge(int pts) {
    if (pts >= 370) return '最划算 ★'; // 大包
    if (pts >= 130) return '熱門';    // 中包
    return '';                        // 入門
  }

  // 📜 交易紀錄卡片 UI
  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    final type = txn['transaction_type'] ?? 'purchase';
    final pts = txn['points'] as int? ?? 0;
    final isSpend = type == 'spend';
    final rawFeature = txn['related_feature'] as String?;

    // 格式化日期
    String formattedDate = txn['created_at'] ?? '';
    if (formattedDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(formattedDate);
        formattedDate = '${formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    
    // 把英文代號轉換成漂亮的中文名稱
    String getFeatureName(String? featureId) {
      switch (featureId) {
        case 'photo_extra':
          return '拍照辨識加購';
        case 'ai_extra':
          return 'AI 對話加購';
        case 'vocab_expand':
          return '單字收藏擴充';
        case 'vocab_expand_premium':
          return '單字收藏擴充 (訂閱優惠)';
        case 'group_deposit':
          return '學習小組押金';
        default:
          return featureId ?? '未知功能';
      }
    }
    
    // 設定不同類型的圖示、顏色與標題
    final baseLabel = transactionTypeLabels[type] ?? type;
    IconData icon;
    Color iconColor;
    Color bgColor;
    String titleText;

    switch (type) {
      case 'spend':
        icon = Icons.remove_circle_outline;
        iconColor = Colors.red;
        bgColor = Colors.red.shade50;
        titleText = '$baseLabel：${getFeatureName(rawFeature)}';
        break;
      case 'subscription_grant':
        icon = Icons.star;
        iconColor = const Color(0xFFC6B13B);
        bgColor = const Color(0xFFFFF8E1);
        titleText = baseLabel;
        break;
      case 'reward':
        icon = Icons.change_history;
        iconColor = Colors.blue;
        bgColor = Colors.blue.shade50;
        titleText = baseLabel;
        break;
      case 'purchase':
      default:
        icon = Icons.add_circle_outline;
        iconColor = _green;
        bgColor = _lightGreen;
        titleText = '$baseLabel (${txn['payment_method'] ?? '未知'})';
        break;
    }

    final ptsLabel = pts > 0 && !isSpend ? '+$pts' : '$pts';
    final ptsColor = isSpend ? Colors.red : _green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(formattedDate, style: const TextStyle(fontSize: 12, color: _subText)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$ptsLabel J-Pts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ptsColor)),
              if (txn['price'] != null && txn['price'] > 0)
                Text('NT\$${txn['price']}', style: const TextStyle(fontSize: 12, color: _subText)),
            ],
          )
        ],
      ),
    );
  }
}