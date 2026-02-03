import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as imgLib;
import '../model/logistic_regression_mnist.dart'; // 匯入模型類別

class CameraDigitPage extends StatefulWidget {
  final LogisticRegressionMNIST model; // 模型實例，由外部傳入本頁面
  const CameraDigitPage({super.key, required this.model});

  @override
  State<CameraDigitPage> createState() => _CameraDigitPageState();
}

class _CameraDigitPageState extends State<CameraDigitPage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes; // 圖片字節數據（支援所有平台）
  int? _prediction;       // 模型預測結果（0~9）

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;  // 使用者可能取消拍照
    final bytes = await photo.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _prediction = null;      // 每次重新拍照時清除舊的預測結果
    });
  }

  /// 從相簿選擇圖片
  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;  // 使用者可能取消選擇
    final bytes = await image.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _prediction = null;      // 每次重新選擇時清除舊的預測結果
    });
  }

  /// 影像前處理 + 模型預測
  Future<void> _processImage() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇或拍攝圖片')),
      );
      return;
    }

    try {
      // 1. 讀取影像檔至記憶體
      imgLib.Image? src = imgLib.decodeImage(_imageBytes!);
      if (src == null) {
        throw Exception('無法讀取圖片');
      }

      // 2. 將圖片轉為灰階
      src = imgLib.grayscale(src);

      // 3. 先將圖片縮小，將寬度調整為 200px（等比例縮放），加速後續處理
      src = imgLib.copyResize(src, width: 200);

      // 4. 找出前景範圍：定義閾值，灰度值低於 threshold 視為「黑色筆跡」
      const threshold = 180; // 固定閾值，可依需要調整
      int minX = src.width, maxX = 0;
      int minY = src.height, maxY = 0;
      for (int y = 0; y < src.height; y++) {
        for (int x = 0; x < src.width; x++) {
          final p = src.getPixel(x, y);
          // 使用 r 通道作為灰階值（因為已經是灰階圖）
          final l = p.r.toInt();
          if (l < threshold) {                // 若亮度低於閾值，判定為前景（黑色）
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      // 5. 如未找到任何前景點，則以圖像中心附近區域作為預設前景區
      if (minX > maxX || minY > maxY) {
        final cx = src.width ~/ 2;
        final cy = src.height ~/ 2;
        minX = (cx - 50).clamp(0, src.width - 1);
        maxX = (cx + 50).clamp(0, src.width - 1);
        minY = (cy - 50).clamp(0, src.height - 1);
        maxY = (cy + 50).clamp(0, src.height - 1);
      }

      // 6. 裁剪 Crop：取出偵測到的前景區域
      final cropWidth = (maxX - minX + 1).clamp(1, src.width - minX);
      final cropHeight = (maxY - minY + 1).clamp(1, src.height - minY);
      final crop = imgLib.copyCrop(
        src,
        x: minX,
        y: minY,
        width: cropWidth,
        height: cropHeight,
      );

      // 7. 調整大小：將裁切結果縮放為 28x28
      final mnist = imgLib.copyResize(crop, width: 28, height: 28);

      // 8. 攤平成 784 維向量並標準化：黑色像素轉為較大值 (1)，白色為0
      final vector = <double>[];
      for (int y = 0; y < 28; y++) {
        for (int x = 0; x < 28; x++) {
          final p = mnist.getPixel(x, y);
          // 使用 r 通道作為灰階值
          final l = p.r.toDouble();
          vector.add((255 - l) / 255);  // 亮度取反 (黑色變成接近1.0，白色變0)
        }
      }

      // 9. 使用 logistic regression 模型進行預測
      final pred = widget.model.predict(vector);

      setState(() {
        _prediction = pred;   // 將預測結果保存，觸發介面重繪顯示
      });

      debugPrint("前處理完成，vector length=${vector.length}，預測=$pred");
    } catch (e) {
      debugPrint('處理圖片時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('處理圖片失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('相機手寫數字辨識')),
      body: Column(
        children: [
          // 上方顯示拍攝的照片或提示文字
          Expanded(
            child: Center(
              child: _imageBytes == null
                  ? const Text('尚未拍照')            // 還沒有照片時顯示提示
                  : Image.memory(_imageBytes!),      // 使用 Image.memory 支援 Web 平台
            ),
          ),
          // 若已有預測結果，顯示在圖像下方
          if (_prediction != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '預測結果：$_prediction',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          // 下方放置三個按鈕：拍照、相簿 和 辨識
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照'),
              ),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('相簿'),
              ),
              ElevatedButton(
                onPressed: _processImage,
                child: const Text('辨識'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
