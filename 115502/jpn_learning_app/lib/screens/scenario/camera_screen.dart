import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/screens/scenario/analyzing_screen.dart';
import 'package:jpn_learning_app/screens/scenario/manual_search_screen.dart';
import 'package:jpn_learning_app/main.dart'; // import cameras

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  int _currentCameraIndex = 0;

  // 使用量顯示
  int _photoCountToday = 0;
  int _photoExtraCount = 0;
  int _photoDailyLimit = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (cameras.isNotEmpty) {
      _initCamera(cameras[_currentCameraIndex]);
    }
    _loadUsageStatus();
  }

  Future<void> _loadUsageStatus() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    final res = await ApiClient.getUsageStatus(userId);
    if (!mounted) return;
    final provider = context.read<UserProvider>();
    setState(() {
      _photoDailyLimit = provider.isPremium ? 20 : 3;
      _photoCountToday = (res['photo_count_today'] as num?)?.toInt() ?? 0;
      _photoExtraCount = (res['photo_extra_count'] as num?)?.toInt() ?? 0;
    });
    provider.setUsageStatus(
      photoCountToday: _photoCountToday,
      photoExtraCount: _photoExtraCount,
      aiCountToday: (res['ai_count_today'] as num?)?.toInt() ?? 0,
      aiExtraCount: (res['ai_extra_count'] as num?)?.toInt() ?? 0,
      vocabSlot: (res['vocab_slot'] as num?)?.toInt() ?? 50,
    );
  }

  // 拍照前先打 API 確認次數，成功才繼續
  Future<void> _checkAndProceedWithPhoto(String imagePath) async {
    final provider = context.read<UserProvider>();
    final userId = provider.userId;
    if (userId == null) {
      await _showNamingDialogAndProceed(imagePath);
      return;
    }

    final res = await ApiClient.incrementScan(userId);
    if (!mounted) return;

    final status = (res['_status'] as num?)?.toInt() ?? 200;
    if (status == 403) {
      final used = (res['daily_scans'] as num?)?.toInt() ?? _photoCountToday;
      final limit = (res['daily_limit'] as num?)?.toInt() ?? _photoDailyLimit;
      _showQuotaExceededDialog(imagePath, used, limit);
    } else {
      setState(() {
        _photoCountToday = (res['daily_scans'] as num?)?.toInt() ?? _photoCountToday + 1;
        _photoExtraCount = (res['extra_count'] as num?)?.toInt() ?? _photoExtraCount;
      });
      provider.updatePhotoUsage(countToday: _photoCountToday, extraCount: _photoExtraCount);
      await _showNamingDialogAndProceed(imagePath);
    }
  }

  void _showQuotaExceededDialog(String imagePath, int used, int limit) {
    final provider = context.read<UserProvider>();
    final jPts = provider.jPts;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('今日拍照次數已用完', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已使用 $used / $limit 次', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            const Text('花 30 點加購 +5 次（永久有效）', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text('目前點數：$jPts J-Pts',
                style: TextStyle(fontSize: 13, color: jPts >= 30 ? Colors.grey : Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5F8F5B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: jPts < 30
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await _buyExtraAndProceed(imagePath, 'photo_extra');
                  },
            child: const Text('加購次數', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _buyExtraAndProceed(String imagePath, String feature) async {
    final provider = context.read<UserProvider>();
    final userId = provider.userId;
    if (userId == null) return;

    final buyRes = await ApiClient.spendPoints(userId: userId, points: 30, feature: feature);
    if (!mounted) return;

    if ((buyRes['_status'] as num?)?.toInt() != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(buyRes['error'] ?? '購買失敗')),
      );
      return;
    }

    if (buyRes['total_points'] != null) {
      provider.setJPts((buyRes['total_points'] as num).toInt());
    }

    // 購買成功後重新嘗試
    final scanRes = await ApiClient.incrementScan(userId);
    if (!mounted) return;

    if ((scanRes['_status'] as num?)?.toInt() == 200) {
      setState(() {
        _photoCountToday = (scanRes['daily_scans'] as num?)?.toInt() ?? _photoCountToday + 1;
        _photoExtraCount = (scanRes['extra_count'] as num?)?.toInt() ?? _photoExtraCount;
      });
      provider.updatePhotoUsage(countToday: _photoCountToday, extraCount: _photoExtraCount);
      await _showNamingDialogAndProceed(imagePath);
    }
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    final previousController = _controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousController?.dispose();

    if (mounted) {
      setState(() {
        _controller = cameraController;
      });
    }

    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = _controller!.value.isInitialized;
      });
    }
  }

  void _flipCamera() {
    if (cameras.length < 2) return; // 如果只有一個鏡頭就不翻轉
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
    _initCamera(cameras[_currentCameraIndex]);
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (_controller!.value.isTakingPicture) {
      return;
    }

    try {
      final XFile photo = await _controller!.takePicture();
      if (!mounted) return;

      await _showNamingDialogAndProceed(photo.path);
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
    }
  }

  Future<void> _showNamingDialogAndProceed(String imagePath) async {
    final TextEditingController nameController = TextEditingController();
    final String? customName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('為這張照片命名（選填）'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: '例如：我的書桌',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, null);
              },
              child: const Text('跳過', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, nameController.text.trim());
              },
              child: const Text('確定', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalyzingScreen(
          imagePath: imagePath,
          customTitle: customName != null && customName.isNotEmpty ? customName : null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 真正的相機預覽區
          if (_isCameraInitialized)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // 返回按鈕
          Positioned(
            top: 48,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // 手動搜尋入口
          Positioned(
            top: 48,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 28),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
              ),
            ),
          ),

          // 1. 新增：頂部中央的「次數顯示條」
          Positioned(
            top: 54, // 對齊左右的按鈕
            left: 60,
            right: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '今日拍照：$_photoCountToday / $_photoDailyLimit次' + 
                (_photoExtraCount > 0 ? ' (+$_photoExtraCount次備用)' : ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          // 中央提示框
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '試著拍看周遭造的任何東西！',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '（Try snapping anything！）',
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ),

          // 底部控制區
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 🖼️ 1. 左邊的相簿按鈕
                  IconButton(
                    icon: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                      );

                      if (pickedFile != null) {
                        if (!context.mounted) return;
                        // 2. 改為呼叫會檢查次數的函式
                        await _checkAndProceedWithPhoto(pickedFile.path);
                      }
                    },
                  ),

                  // 📷 2. 中間的拍照按鈕 (綠色大圓圈)
                  GestureDetector(
                    onTap: () async {
                      // 3. 先真正的拍照，拿到檔案路徑後，再丟去檢查次數
                      if (_controller == null || !_controller!.value.isInitialized) return;
                      if (_controller!.value.isTakingPicture) return;

                      try {
                        final XFile photo = await _controller!.takePicture();
                        if (!mounted) return;
                        // 4. 改為呼叫會檢查次數的函式
                        await _checkAndProceedWithPhoto(photo.path);
                      } on CameraException catch (e) {
                        debugPrint('拍照發生錯誤: $e');
                      }
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),

                  // 🔄 3. 右邊的翻轉鏡頭按鈕
                  IconButton(
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: _flipCamera,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
