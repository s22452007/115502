import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';
// 與「我的單字探險」共用同一張單字卡（含 ⭐ 收藏、分級例句、情境例句）
import 'package:jpn_learning_app/widgets/scenario/vocab_card.dart';

/// 拍照辨識結果頁：
/// 介面與「我的單字探險」詳細頁一致（照片大圖 + 單字卡列表），
/// 辨識結果已由後端自動存入單字探險，這裡讓使用者慢慢看，
/// 底部提供 [📷 再拍一張] 與 [✓ 完成] 兩個動作。
class SceneResultScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic>? analysisData;

  const SceneResultScreen({
    Key? key,
    required this.imagePath,
    this.analysisData,
  }) : super(key: key);

  @override
  State<SceneResultScreen> createState() => _SceneResultScreenState();
}

class _SceneResultScreenState extends State<SceneResultScreen> {
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

  // 底部固定按鈕列：[📷 再拍一張] [✓ 完成]
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _buildPhotoHeader(),
          _buildVocabList(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
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
