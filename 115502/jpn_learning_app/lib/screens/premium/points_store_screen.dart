import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/api_client.dart';

class PointsStoreScreen extends StatefulWidget {
  const PointsStoreScreen({super.key});

  @override
  State<PointsStoreScreen> createState() => _PointsStoreScreenState();
}

class _PointsStoreScreenState extends State<PointsStoreScreen> {
  static const Color _textDark  = Color(0xFF333333);
  static const Color _subText   = Color(0xFF7A7A7A);
  static const Color _green     = Color(0xFF5F8F5B);
  static const Color _lightGreen = Color(0xFFE8F0DD);
  static const Color _borderGreen = Color(0xFFD4E1C8);
  static const Color _blue      = Color(0xFF3B69CC);
  static const Color _lightBlue = Color(0xFFDDE8FF);

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final res = await ApiClient.getStoreItems();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.containsKey('items')) {
        _items = List<Map<String, dynamic>>.from(res['items']);
      }
    });
  }

  Future<void> _purchase(Map<String, dynamic> item) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final featureId = item['id'] as String;
    final cost = (item['cost'] as num).toInt();
    final userPts = context.read<UserProvider>().jPts;

    if (userPts < cost) {
      _showSnack('點數不足（需要 $cost 點，目前 $userPts 點）', isError: true);
      return;
    }

    setState(() => _loading.add(featureId));

    final res = await ApiClient.spendPoints(
      userId: userId,
      points: cost,
      feature: featureId,
    );

    if (!mounted) return;
    setState(() => _loading.remove(featureId));

    if (res.containsKey('error')) {
      _showSnack(res['error'], isError: true);
    } else {
      final newPts = (res['total_points'] as num?)?.toInt() ?? userPts - cost;
      context.read<UserProvider>().setJPts(newPts);
      final effect = res['effect'] as String? ?? item['description'] as String;
      _showSnack('✓ 兌換成功！$effect');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : _green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final jPts = context.watch<UserProvider>().jPts;

    final daily = _items.where((i) => i['category'] == 'daily').toList();
    final permanent = _items.where((i) => i['category'] == 'permanent').toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'J-Pts 商店',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textDark),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('用點數兌換加購次數或永久擴充功能', style: const TextStyle(fontSize: 14, color: _subText)),
            ),

            const SizedBox(height: 16),

            // Balance card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderGreen),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: _lightGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.monetization_on_outlined, color: _green, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('目前點數', style: TextStyle(fontSize: 12, color: _subText)),
                        Text('$jPts J-Pts', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textDark)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        if (daily.isNotEmpty) ...[
                          _sectionTitle('每日加購（限時道具）'),
                          const SizedBox(height: 10),
                          ...daily.map((item) => _StoreItemCard(
                                item: item,
                                isLoading: _loading.contains(item['id']),
                                onTap: () => _purchase(item),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (permanent.isNotEmpty) ...[
                          _sectionTitle('永久擴充'),
                          const SizedBox(height: 10),
                          ...permanent.map((item) => _StoreItemCard(
                                item: item,
                                isLoading: _loading.contains(item['id']),
                                onTap: () => _purchase(item),
                              )),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _lightBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, size: 18, color: _blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '每日加購道具於購買當日或指定天數後失效。'
                                  '學習小組達成獎勵也可獲得限時道具，訂閱 Premium 享每月 1000 點贈送。',
                                  style: TextStyle(fontSize: 12, color: _blue, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark),
      );
}

class _StoreItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLoading;
  final VoidCallback onTap;

  const _StoreItemCard({
    required this.item,
    required this.isLoading,
    required this.onTap,
  });

  static const Color _textDark   = Color(0xFF333333);
  static const Color _subText    = Color(0xFF7A7A7A);
  static const Color _green      = Color(0xFF8FB98B);
  static const Color _darkGreen  = Color(0xFF5F8F5B);
  static const Color _lightGreen = Color(0xFFE8F0DD);
  static const Color _borderGreen = Color(0xFFD4E1C8);
  static const Color _gold       = Color(0xFFF0B84B);

  static const Map<String, IconData> _icons = {
    'camera_alt':    Icons.camera_alt_outlined,
    'smart_toy':     Icons.smart_toy_outlined,
    'bookmark_add':  Icons.bookmark_add_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final iconName = item['icon'] as String? ?? 'bookmark_add';
    final icon = _icons[iconName] ?? Icons.star_outline;
    final cost = (item['cost'] as num).toInt();
    final unit = item['unit'] as String? ?? '';
    final isPermanent = item['category'] == 'permanent';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGreen),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _darkGreen, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item['name'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textDark)),
                    const SizedBox(width: 6),
                    if (isPermanent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(8)),
                        child: const Text('永久', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(item['description'] as String, style: const TextStyle(fontSize: 12, color: _subText)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(unit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _darkGreen)),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: isLoading
                    ? const SizedBox(width: 34, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    : ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('$cost 點', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
