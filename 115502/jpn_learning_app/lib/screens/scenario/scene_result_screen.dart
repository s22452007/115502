import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
// 與「我的單字探險」共用同一張單字卡（含 ⭐ 收藏、分級例句、情境例句）
import 'package:jpn_learning_app/widgets/scenario/vocab_card.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';

/// 拍照辨識結果頁：
/// 介面與「我的單字探險」詳細頁一致（照片大圖 + 單字卡列表），
/// 辨識結果已由後端自動存入單字探險，這裡讓使用者慢慢看，
/// 底部提供 [📷 再拍一張] 與 [✓ 完成] 兩個動作。
class SceneResultScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic>? analysisData;
  // 主題里程碑：這次拍照若跨過「過半/集滿」門檻，後端會帶回此資料；null 代表沒跨過
  final Map<String, dynamic>? milestone;

  const SceneResultScreen({
    Key? key,
    required this.imagePath,
    this.analysisData,
    this.milestone,
  }) : super(key: key);

  @override
  State<SceneResultScreen> createState() => _SceneResultScreenState();
}

class _SceneResultScreenState extends State<SceneResultScreen> {
  @override
  void initState() {
    super.initState();
    // 進頁後若有里程碑，等第一幀畫完再彈出一次性慶祝動畫
    if (widget.milestone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMilestoneCelebration(widget.milestone!);
      });
    }
  }

  void _showMilestoneCelebration(Map<String, dynamic> milestone) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '里程碑',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) => _MilestoneCelebration(milestone: milestone),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _vocabs {
    final raw = widget.analysisData?['vocabs'];
    if (raw is! List) return [];
    // VocabCard 需要 vocab_id / word / kana / meaning / context_sentence
    return raw
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .where((v) => v['vocab_id'] != null)
        .toList();
  }

  bool get _isNetworkImage =>
      kIsWeb ||
      widget.imagePath.startsWith('http') ||
      widget.imagePath.startsWith('blob:');

  ImageProvider get _imageProvider =>
      _isNetworkImage ? NetworkImage(widget.imagePath) : FileImage(File(widget.imagePath));

  void _openFullPhoto() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, _, _) => _FullPhotoViewer(imageProvider: _imageProvider),
      ),
    );
  }

  Widget _buildPhotoHeader() {
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: false, // 不給返回鍵，引導使用者走底部按鈕
      flexibleSpace: FlexibleSpaceBar(
        // 左右各留 20 的邊距，避免標題貼邊或被裁切
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16, end: 20),
        title: const Text(
          '辨識結果',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
        background: GestureDetector(
          onTap: _openFullPhoto,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _isNetworkImage
                  ? Image.network(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.primaryLighter,
                        child: const Icon(Icons.broken_image,
                            size: 80, color: Colors.white),
                      ),
                    )
                  : Image.file(File(widget.imagePath), fit: BoxFit.cover),
              // 右上角小提示：可點擊放大看完整照片
              Positioned(
                top: 48,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('點擊看完整照片',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVocabList() {
    final vocabs = _vocabs;
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vocabs.isEmpty
                        ? '未能辨識出單字，換個角度再拍一張吧！'
                        : '辨識出 ${vocabs.length} 個單字，已自動存入你的單字探險！',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...vocabs.map((vocab) => VocabCard(vocab: vocab)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // 底部固定按鈕列：[📷 再拍一張] [造句] [✓ 完成]
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 再拍一張：回到拍照畫面（相機頁還在堆疊下方，pop 即可）
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text(
                  '再拍一張',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  // 固定高度 + 內容置中，讓兩顆按鈕文字對齊
                  fixedSize: const Size.fromHeight(52),
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 完成：直接回主頁
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                icon: const Icon(Icons.check, size: 20),
                label: const Text(
                  '完成',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  // 固定高度 + 內容置中，讓兩顆按鈕文字對齊
                  fixedSize: const Size.fromHeight(52),
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 沿用共用子頁模板（與「單字探險」詳情頁一致）；
    // 照片大圖本身就是頁首，所以隱藏模板的 AppBar。
    return SubPageTemplate(
      title: '辨識結果',
      hideAppBar: true,
      bottomNavigationBar: _buildBottomBar(),
      body: CustomScrollView(
        slivers: [
          _buildPhotoHeader(),
          _buildVocabList(),
        ],
      ),
    );
  }
}

/// 全螢幕照片檢視：黑底、雙指縮放、可拖曳，顯示完整未裁切的照片。
class _FullPhotoViewer extends StatelessWidget {
  final ImageProvider imageProvider;

  const _FullPhotoViewer({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 點背景任一處即可關閉
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image(image: imageProvider, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 44,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 主題里程碑的一次性慶祝：卡片 + 灑落的彩帶，數秒後自動關閉（也可點擊關閉）。
class _MilestoneCelebration extends StatefulWidget {
  final Map<String, dynamic> milestone;
  const _MilestoneCelebration({required this.milestone});

  @override
  State<_MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<_MilestoneCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
    // 約 2.8 秒後自動關閉（若使用者沒先點掉）
    _autoClose = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _isComplete => widget.milestone['type'] == 'complete';

  @override
  Widget build(BuildContext context) {
    final theme = widget.milestone['theme_name']?.toString() ?? '主題';
    final unlocked = widget.milestone['unlocked'] ?? 0;
    final total = widget.milestone['total'] ?? 0;
    final accent = _isComplete ? AppColors.gold : AppColors.primary;
    final emoji = _isComplete ? '🏆' : '✨';
    final title = _isComplete ? '集滿整本收集冊！' : '收集過半！';

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 彩帶
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                painter: _ConfettiPainter(_controller.value, accent),
              ),
            ),
          ),
          // 卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  theme,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '已收集 $unlocked / $total 個單字',
                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 簡單的彩帶效果：一批彩色小方塊由上往下灑落並旋轉淡出。
class _ConfettiPainter extends CustomPainter {
  final double progress; // 0.0 ~ 1.0
  final Color accent;
  _ConfettiPainter(this.progress, this.accent);

  static final List<Color> _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.gold,
    const Color(0xFFE57373),
    const Color(0xFF64B5F6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const count = 28;
    for (int i = 0; i < count; i++) {
      final rnd = math.Random(i); // 固定種子 -> 每次形狀一致、不亂跳
      final startX = rnd.nextDouble() * size.width;
      final drift = (rnd.nextDouble() - 0.5) * 80;
      final delay = rnd.nextDouble() * 0.3;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = startX + drift * t;
      final y = -20 + (size.height + 40) * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final angle = t * (4 + rnd.nextDouble() * 4);

      final paint = Paint()
        ..color = _palette[i % _palette.length].withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final w = 6.0 + rnd.nextDouble() * 5;
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
