import 'package:flutter/material.dart';

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

  static const Color _darkGreen = Color(0xFF5F8F5B);
  static const Color _bg = Color(0xFFF8F9FA);

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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '商城與會員中心',
          style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _darkGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _darkGreen,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: '👑 Premium'),
            Tab(text: '💰 儲值點數'),
            Tab(text: '🛍️ 點數兌換'),
          ],
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