import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1. 匯入工具與資料
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';

// 匯入剛剛抽出去的單字卡元件
import 'package:jpn_learning_app/widgets/scenario/vocab_card.dart';

class ScenarioDetailScreen extends StatefulWidget {
  final dynamic scene;

  const ScenarioDetailScreen({Key? key, required this.scene}) : super(key: key);

  @override
  State<ScenarioDetailScreen> createState() => _ScenarioDetailScreenState();
}

class _ScenarioDetailScreenState extends State<ScenarioDetailScreen> {
  Future<void> _showRenameDialog(
    BuildContext context,
    int photoId,
    String currentName,
  ) async {
    final TextEditingController titleController = TextEditingController(
      text: currentName,
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改照片名稱'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: '照片名稱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty && newTitle != currentName) {
                await ApiClient.renamePhoto(photoId, newTitle);
                if (mounted) {
                  setState(() {
                    widget.scene['scene_name'] = newTitle;
                  });
                }
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('確認修改', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          FutureBuilder<List<dynamic>>(
            future: ApiClient.getVocabsByPhoto(
              widget.scene['image_path'],
              userId!,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(child: Text("載入單字失敗")),
                  ),
                );
              }

              final vocabs = snapshot.data ?? [];
              return _buildVocabularyList(vocabs);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320.0,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.scene['photo_id'] != null)
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: '修改這張照片的名稱',
            onPressed: () {
              _showRenameDialog(
                context,
                widget.scene['photo_id'],
                widget.scene['scene_name'],
              );
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.scene['scene_name'], 
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
        background: widget.scene['image_path'] != null
            ? Image.network(
                widget.scene['image_path'].startsWith('http')
                    ? widget.scene['image_path']
                    : '${ApiClient.baseUrl.replaceAll('/api', '')}/static/photos/${widget.scene['image_path'].split('/').last}',
                fit: BoxFit.cover, 
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primaryLighter,
                  child: const Icon(Icons.broken_image, size: 80, color: Colors.white),
                ),
              )
            : Container(
                color: AppColors.primaryLighter,
                child: const Icon(Icons.camera_alt, size: 80, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildVocabularyList(List<dynamic> vocabs) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '在這個場景中識別出 ${vocabs.length} 個單字',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ...vocabs.map((vocab) => VocabCard(vocab: vocab)).toList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}