import 'package:flutter/material.dart';

/// 懸浮在畫面底部的主要操作按鈕。
///
/// 用法：放進 Scaffold / SubPageTemplate 的 bottomNavigationBar，並把 extendBody 設成 true，
/// 內容就會從按鈕下方捲過去。可捲動的內容底部要留 [bodyBottomPadding] 的空間，
/// 最後一項才不會被按鈕蓋住（ListView 沒給 padding 會自動留；SingleChildScrollView 要自己給）。
class FloatingBottomBar extends StatelessWidget {
  const FloatingBottomBar({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.secondary,
  });

  /// 按鈕本體，會被撐成滿寬、[buttonHeight] 高
  final Widget child;

  /// 要跟按鈕的圓角一致，陰影才會貼著按鈕
  final double borderRadius;

  /// 主按鈕下方的次要動作（例如文字按鈕），高度固定 [secondaryHeight]
  final Widget? secondary;

  static const double horizontalMargin = 20;
  static const double topMargin = 12;

  /// 按鈕與系統導覽列的距離
  static const double bottomMargin = 16;
  static const double buttonHeight = 54;
  static const double secondaryHeight = 40;

  /// 整條佔的高度（不含系統底部安全區、不含次要動作）
  static const double height = topMargin + buttonHeight + bottomMargin;

  /// 可捲動內容要留的底部空間。
  /// 要傳畫面 build 的 context（Scaffold 外面那層），在 body 裡面拿會重複算。
  static double bodyBottomPadding(
    BuildContext context, {
    bool hasSecondary = false,
  }) =>
      height +
      (hasSecondary ? secondaryHeight : 0) +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        topMargin,
        horizontalMargin,
        bottomMargin + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: buttonHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          ),
          if (secondary != null)
            SizedBox(
              width: double.infinity,
              height: secondaryHeight,
              child: Center(child: secondary),
            ),
        ],
      ),
    );
  }
}
