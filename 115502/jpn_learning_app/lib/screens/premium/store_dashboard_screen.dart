import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/widgets/premium/premium_tab.dart';
import 'package:jpn_learning_app/widgets/premium/buy_points_tab.dart';
import 'package:jpn_learning_app/widgets/premium/store_tab.dart';

class StoreDashboardScreen extends StatefulWidget {
  final int initialIndex;
  
  const StoreDashboardScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 🌟 扁平化配色常量
  static const Color _bgColor = Color(0xFFF4F7F5);
  static const Color _textColor = Color(0xFF2C3E50);
  static const Color _subTextColor = Color(0xFF8E9AAB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // 移除陰影
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '商城與會員中心',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        // 🌟 扁平化 TabBar 設計
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary, // 使用專案主色綠
              unselectedLabelColor: _subTextColor,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'Premium'),
                Tab(text: '儲值點數'),
                Tab(text: '點數兌換'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PremiumTab(),
          BuyPointsTab(),
          StoreTab(),
        ],
      ),
    );
  }
}