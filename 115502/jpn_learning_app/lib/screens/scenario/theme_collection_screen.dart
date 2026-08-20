import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/scenario/scenario_detail_screen.dart';
import 'package:jpn_learning_app/screens/scenario/camera_screen.dart';
import 'package:jpn_learning_app/screens/scenario/theme_collection_intro_screen.dart';

/// 主題名稱 -> icon（對應後端 THEME_DEFS 的 icon_name）
const Map<String, IconData> _themeIcons = {
  'restaurant': Icons.restaurant,
  'storefront': Icons.storefront,
  'train': Icons.train,
  'signpost': Icons.signpost,
  'home': Icons.home,
  'school': Icons.school,
  'shopping_bag': Icons.shopping_bag,
  'park': Icons.park,
  'category': Icons.category,
};

IconData _iconFor(String? name) => _themeIcons[name] ?? Icons.category;

/// 把後端回傳的圖片路徑轉成可載入的完整網址
String? _photoUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  final host = ApiClient.baseUrl.replaceAll('/api', '');
  return '$host/static/photos/${path.split('/').last}';
}

/// 主題收集冊：把拍過的照片依生活情境主題聚合成一本本收集冊
class ThemeCollectionScreen extends StatefulWidget {
  const ThemeCollectionScreen({Key? key}) : super(key: key);

  @override
  State<ThemeCollectionScreen> createState() => _ThemeCollectionScreenState();
}

class _ThemeCollectionScreenState extends State<ThemeCollectionScreen> {
  /// 記住使用者看過引導了沒（改文案時把版本號往上加就會重新出現一次）
  static const String _introSeenKey = 'theme_collection_intro_seen_v1';

  Key _futureKey = UniqueKey();

  void _reload() => setState(() => _futureKey = UniqueKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  /// 第一次進收集冊時自動帶出引導，之後不再打擾
  Future<void> _maybeShowIntro() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_introSeenKey) ?? false) return;
    await prefs.setBool(_introSeenKey, true);
    if (!mounted) return;
    await _openIntro(isFirstTime: true);
  }

  Future<void> _openIntro({bool isFirstTime = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThemeCollectionIntroScreen(isFirstTime: isFirstTime),
      ),
    );
    if (mounted) _reload(); // 從引導直接去拍照的話，回來要看到新的冊子
  }

  void _goCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    ).then((_) {
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;

    return SubPageTemplate(
      title: '主題收集冊',
      actions: [
        IconButton(
          tooltip: '這是什麼？',
          icon: const Icon(Icons.help_outline),
          onPressed: () => _openIntro(),
        ),
      ],
      body: userId == null
          ? const Center(
              child: Text('請先登入才能查看收集冊喔！',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
            )
          : FutureBuilder<List<dynamic>>(
              key: _futureKey,
              future: ApiClient.getThemes(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('載入失敗：\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }

                final themes = snapshot.data ?? [];
                if (themes.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: themes.length,
                  itemBuilder: (context, index) =>
                      _ThemeCard(theme: themes[index], onReturn: _reload),
                );
              },
            ),
    );
  }

  /// 一本冊子都還沒有時：說清楚這頁在幹嘛、標明免費，並給一個明確的下一步
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '你的收集冊還是空的',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '拍一張生活中的照片，系統會辨識出裡面的日文單字，\n並自動幫你開出第一本主題收集冊。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.7, color: AppColors.textGrey),
            ),
            const SizedBox(height: 20),
            const Text(
              '拍照解鎖單字不用花點數',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: _goCamera,
                child: const Text(
                  '去拍第一張',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openIntro(),
              child: const Text(
                '主題收集冊是什麼？',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 單一主題卡：以拍過的照片當封面，疊上完成度
class _ThemeCard extends StatelessWidget {
  final dynamic theme;
  final VoidCallback onReturn;

  const _ThemeCard({required this.theme, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final name = theme['name'] ?? '未分類';
    final int photoCount = theme['photo_count'] ?? 0;
    final int unlocked = theme['unlocked_count'] ?? 0;
    final int target = theme['target_count'] ?? 20;
    final double progress = (theme['progress'] ?? 0.0).toDouble();
    final coverUrl = _photoUrl(theme['cover_image']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ThemeDetailScreen(
              sceneId: theme['scene_id'] ?? 0,
              themeName: name,
            ),
          ),
        ).then((_) => onReturn());
      },
      child: Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.primaryLighter,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 封面照片（無照片時退回主題色底 + 圖示）
            if (coverUrl != null)
              Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackCover(name),
              )
            else
              _fallbackCover(name),

            // 底部漸層，讓白字清楚
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.72),
                  ],
                  stops: const [0.35, 0.6, 1.0],
                ),
              ),
            ),

            // 內容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 右上角主題圖示徽記
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_iconFor(theme['icon_name']),
                          size: 20, color: AppColors.primary),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 完成度進度條
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.35),
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.secondary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '已解鎖 $unlocked / $target 個單字 · $photoCount 張探索照',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackCover(String name) => Container(
        color: AppColors.primaryLighter,
        alignment: Alignment.center,
        child: Icon(_iconFor(theme['icon_name']),
            size: 64, color: Colors.white.withOpacity(0.8)),
      );
}

/// 主題細節：上方單字牆（已解鎖 vs 剪影）+ 下方探索照列表
class ThemeDetailScreen extends StatefulWidget {
  final int sceneId;
  final String themeName;

  const ThemeDetailScreen({
    Key? key,
    required this.sceneId,
    required this.themeName,
  }) : super(key: key);

  @override
  State<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends State<ThemeDetailScreen> {
  Key _futureKey = UniqueKey();

  void _reload() => setState(() => _futureKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;

    return SubPageTemplate(
      title: widget.themeName,
      body: userId == null
          ? const Center(child: Text('請先登入'))
          : ListView(
              key: _futureKey,
              padding: const EdgeInsets.all(16),
              children: [
                // 1. 單字牆
                _VocabWall(userId: userId, sceneId: widget.sceneId),
                const SizedBox(height: 28),
                // 2. 探索照
                const Text('探索照',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark)),
                const SizedBox(height: 12),
                _buildPhotoList(userId),
              ],
            ),
    );
  }

  Widget _buildPhotoList(int userId) {
    return FutureBuilder<List<dynamic>>(
      future: ApiClient.getUnlockedScenes(userId, limit: 999),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final all = snapshot.data ?? [];
        final photos =
            all.where((p) => (p['scene_id'] ?? 0) == widget.sceneId).toList();

        if (photos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: Text('這個主題還沒有照片',
                    style: TextStyle(color: Colors.grey, fontSize: 15))),
          );
        }

        return Column(
          children: photos.map<Widget>((photo) {
            final coverUrl = _photoUrl(photo['image_path']);
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScenarioDetailScreen(scene: photo),
                  ),
                ).then((_) => _reload());
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: coverUrl != null
                            ? Image.network(coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, s) => Container(
                                      color: const Color(0xFFF0F0F0),
                                      child: const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey),
                                    ))
                            : Container(
                                color: const Color(0xFFF0F0F0),
                                child: const Icon(Icons.image,
                                    color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            photo['scene_name'] ?? '未命名照片',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '解鎖 ${photo['vocab_count'] ?? 0} 個單字 · ${photo['unlocked_at'] ?? ''}',
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// 單字牆：已解鎖的字正常顯示，未解鎖的以「？」剪影佔位
class _VocabWall extends StatelessWidget {
  final int userId;
  final int sceneId;

  const _VocabWall({required this.userId, required this.sceneId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiClient.getThemeVocabs(userId, sceneId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final data = snapshot.data ?? {};
        final vocabs = (data['vocabs'] as List?) ?? [];
        final total = data['total'] ?? vocabs.length;
        final unlocked = data['unlocked'] ?? 0;

        if (total == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('拍照探索這個主題，開始點亮單字牆吧！',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
            ),
          );
        }

        final double progress = total > 0 ? unlocked / total : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('單字牆',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark)),
                const SizedBox(width: 10),
                Text('$unlocked / $total',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.borderLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '灰色的「？」是還沒發現的字，拍到就會免費點亮',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: vocabs.map<Widget>((v) {
                final isUnlocked = v['is_unlocked'] == true;
                return isUnlocked
                    ? _UnlockedChip(vocab: v)
                    : _LockedChip(hintLen: (v['hint_len'] ?? 2));
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

/// 已解鎖單字：顯示單字 + 假名，可點擊看解釋與發音
class _UnlockedChip extends StatelessWidget {
  final dynamic vocab;
  const _UnlockedChip({required this.vocab});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showVocabSheet(context, vocab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGreen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vocab['word'] ?? '',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(vocab['kana'] ?? '',
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}

/// 未解鎖單字：剪影佔位，用「？」與長度提示製造收集動力。
/// 刻意不用鎖頭圖示 —— 鎖頭會讓人以為要付費才能解鎖，實際上拍到就免費開。
class _LockedChip extends StatelessWidget {
  final int hintLen;
  const _LockedChip({required this.hintLen});

  @override
  Widget build(BuildContext context) {
    // 依假名長度給個約略寬度，暗示這個字的份量
    final int len = hintLen.clamp(1, 6);
    final width = len * 14.0 + 24;
    return GestureDetector(
      onTap: () => _showLockedHint(context),
      child: Container(
        width: width,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        // 用問號的數量暗示這個字有幾個音，讓人想去把它拍出來
        child: Text(
          '？' * len,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

/// 點未解鎖的字時，直接說明「怎麼開、要不要錢」
void _showLockedHint(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '這個字還沒被你發現',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '拍到含有這個字的照片，它就會自動點亮 —— 不需要花點數，也不用先買什麼。',
            style: TextStyle(fontSize: 15, height: 1.7, color: AppColors.textDark),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                );
              },
              child: const Text(
                '去拍照',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 點已解鎖單字時彈出的解釋 + 發音表單
void _showVocabSheet(BuildContext context, dynamic vocab) {
  final tts = FlutterTts();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(vocab['word'] ?? '',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: AppColors.primary),
                  onPressed: () async {
                    await tts.setLanguage('ja-JP');
                    await tts.speak(vocab['kana'] ?? vocab['word'] ?? '');
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(vocab['kana'] ?? '',
                style: const TextStyle(fontSize: 15, color: AppColors.textGrey)),
            const SizedBox(height: 12),
            Text(vocab['meaning'] ?? '',
                style: const TextStyle(fontSize: 16, color: AppColors.textDark)),
          ],
        ),
      );
    },
  );
}
