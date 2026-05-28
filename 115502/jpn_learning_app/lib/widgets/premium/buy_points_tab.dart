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

  // 🌟 統一的扁平化配色
  static const Color _textDark = Color(0xFF2C3E50);
  static const Color _subText = Color(0xFF8E9AAB);

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
        // ── 🌟 錢包區塊 (扁平化高對比卡片) ──
        _buildWalletCard(jPts),
        const SizedBox(height: 32),

        // ── 🌟 儲值方案區塊 ──
        Row(
          children: [
            const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            const Text('選擇儲值方案', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingPkgs) 
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else 
          ..._packages.map((pkg) => _buildPackageCard(context, pkg)),
        
        const SizedBox(height: 32),

        // ── 🌟 交易紀錄區塊 ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Text('交易紀錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22, color: _subText),
              onPressed: () {
                setState(() => _isLoadingTxns = true);
                _loadTransactions();
              },
            )
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingTxns)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: const Text('尚無交易紀錄', style: TextStyle(color: _subText, fontWeight: FontWeight.w600)),
          )
        else
          ..._transactions.map((txn) => _buildTransactionCard(txn)),
      ],
    );
  }

  // 💰 錢包卡片 (純綠底色，移除邊框)
  Widget _buildWalletCard(int pts) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary, 
        borderRadius: BorderRadius.circular(28)
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56, 
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), 
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 30)
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('目前可用點數', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$pts J-Pts', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  // 🛒 儲值方案卡片 (純白底色，移除邊框)
  Widget _buildPackageCard(BuildContext context, Map<String, dynamic> pkg) {
    final pts = (pkg['points'] as num).toInt();
    final price = (pkg['price'] as num).toInt();
    final tag = pkg['tag'] as String? ?? '';
    final name = pkg['name'] as String? ?? '$pts Points';

    final double pricePerPoint = price / pts;
    final String pricePerPointText = '每點約 NT\$${pricePerPoint.toStringAsFixed(2)}';
    final String badgeText = tag.isEmpty ? _getDefaultBadge(pts) : tag;

    // 扁平化按鈕顏色
    final isBestValue = badgeText.contains('最划算');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.monetization_on_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$pts J-Pts', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
                    if (badgeText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isBestValue ? const Color(0xFFFF7043) : AppColors.primary,
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Text(badgeText, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontSize: 13, color: _subText, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(pricePerPointText, style: TextStyle(fontSize: 12, color: _textDark.withOpacity(0.5), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBestValue ? const Color(0xFFFF7043) : AppColors.primary.withOpacity(0.1), 
              elevation: 0, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PointCheckoutScreen(title: name, points: pts, price: price, badge: badgeText, subtitle: pkg['description']))),
            child: Text(
              'NT\$$price', 
              style: TextStyle(
                color: isBestValue ? Colors.white : AppColors.primary, 
                fontWeight: FontWeight.w900,
                fontSize: 15
              )
            ),
          )
        ],
      ),
    );
  }

  String _getDefaultBadge(int pts) {
    if (pts >= 370) return '最划算'; 
    if (pts >= 130) return '熱門';  
    return '';                    
  }

  // 📜 交易紀錄卡片 (純白底色，色塊分類)
  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    final type = txn['transaction_type'] ?? 'purchase';
    final pts = txn['points'] as int? ?? 0;
    final isSpend = type == 'spend';
    final rawFeature = txn['related_feature'] as String?;

    String formattedDate = txn['created_at'] ?? '';
    if (formattedDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(formattedDate);
        formattedDate = '${formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    
    String getFeatureName(String? featureId) {
      switch (featureId) {
        case 'photo_extra': return '拍照辨識加購';
        case 'ai_extra': return 'AI 對話加購';
        case 'vocab_expand': return '單字收藏擴充';
        case 'vocab_expand_premium': return '單字收藏擴充 (會員優惠)';
        case 'group_deposit': return '學習小組押金';
        default: return featureId ?? '未知功能';
      }
    }
    
    final baseLabel = transactionTypeLabels[type] ?? type;
    IconData icon;
    Color iconColor;
    Color bgColor;
    String titleText;

    switch (type) {
      case 'spend':
        icon = Icons.remove_circle_rounded;
        iconColor = const Color(0xFFE53935);
        bgColor = const Color(0xFFFFF0EC);
        titleText = '$baseLabel：${getFeatureName(rawFeature)}';
        break;
      case 'subscription_grant':
        icon = Icons.stars_rounded;
        iconColor = const Color(0xFFF57F17);
        bgColor = const Color(0xFFFFF8E1);
        titleText = baseLabel;
        break;
      case 'reward':
        icon = Icons.auto_awesome_rounded;
        iconColor = const Color(0xFF1E88E5);
        bgColor = const Color(0xFFE3F2FD);
        titleText = baseLabel;
        break;
      case 'purchase':
      default:
        icon = Icons.add_circle_rounded;
        iconColor = AppColors.primary;
        bgColor = AppColors.primary.withOpacity(0.12);
        titleText = '$baseLabel (${txn['payment_method'] ?? '未知'})';
        break;
    }

    final ptsLabel = pts > 0 && !isSpend ? '+$pts' : '$pts';
    final ptsColor = isSpend ? const Color(0xFFE53935) : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(formattedDate, style: const TextStyle(fontSize: 12, color: _subText, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$ptsLabel J-Pts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ptsColor)),
              if (txn['price'] != null && txn['price'] > 0) ...[
                const SizedBox(height: 2),
                Text('NT\$${txn['price']}', style: const TextStyle(fontSize: 12, color: _subText, fontWeight: FontWeight.w600)),
              ]
            ],
          )
        ],
      ),
    );
  }
}