import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:jpn_learning_app/utils/constants.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (cameras.isNotEmpty) {
      _initCamera(cameras[_currentCameraIndex]);
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalyzingScreen(imagePath: photo.path),
        ),
      );
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
    }
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
                      Icons.photo_library, // 或者你原本用的相簿圖示
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () async {
                      // 1. 召喚相簿挑選器
                      final ImagePicker picker = ImagePicker();
                      final XFile? pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                      );

                      // 2. 如果使用者有選照片（沒按取消）
                      if (pickedFile != null) {
                        if (!context.mounted) return;

                        // 3. 帶著照片跳轉到辨識頁 (走原本的流程)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AnalyzingScreen(imagePath: pickedFile.path),
                          ),
                        );
                      }
                    },
                  ),

                  // 📷 2. 中間的拍照按鈕 (綠色大圓圈)
                  GestureDetector(
                    onTap: _takePicture,
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
        ],
      ),
    );
  }
}
