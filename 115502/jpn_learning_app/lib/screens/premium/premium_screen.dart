import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/screens/premium/buy_points_screen.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upgrade to Premium',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 比較表格
              Table(
                border: TableBorder.all(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(8),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: AppColors.primaryLighter),
                    children: [
                      _Cell('Free Plan', bold: true),
                      _Cell('Premium Pro', bold: true, highlight: true),
                    ],
                  ),
                  TableRow(
                    children: [_Cell('使用十分鐘\n看一次廣告'), _Cell('無限使用\n無需看廣告')],
                  ),
                  TableRow(
                    children: [
                      _Cell('每天最多三次\n與AI機器人聊天'),
                      _Cell('無限次數\n與AI機器人聊天'),
                    ],
                  ),
                  TableRow(
                    children: [_Cell('每天最多三次\n上傳場景照片'), _Cell('無限次數\n上傳場景照片')],
                  ),
                  TableRow(children: [_Cell(''), _Cell('詳細分析學習結果')]),
                  TableRow(children: [_Cell(''), _Cell('每月贈 1000 Points')]),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PriceBtn(price: '\$490', period: '一個月', selected: true),
                  _PriceBtn(
                    price: '\$890',
                    period: '三個月',
                    original: '\$1,470',
                    selected: false,
                  ),
                  _PriceBtn(
                    price: '\$990',
                    period: '一年',
                    original: '\$5,880',
                    selected: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  '開始七天免費試用',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  side: BorderSide(color: AppColors.primary),
                ),
                child: const Text(
                  '選擇方案 立即訂閱',
                  style: TextStyle(color: AppColors.primary, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold, highlight;
  const _Cell(this.text, {this.bold = false, this.highlight = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
        color: highlight ? AppColors.primary : AppColors.textDark,
      ),
    ),
  );
}

class _PriceBtn extends StatelessWidget {
  final String price, period;
  final String? original;
  final bool selected;
  const _PriceBtn({
    required this.price,
    required this.period,
    this.original,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (original != null)
            Text(
              original!,
              style: TextStyle(
                decoration: TextDecoration.lineThrough,
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          Text(
            price,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: selected ? Colors.white : AppColors.textDark,
            ),
          ),
          Text(
            period,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white70 : AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}
