import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as imgLib;
import '../model/cat_dog_classifier.dart'; // 匯入貓狗分類模型

class CatDogPage extends StatefulWidget {
  final CatDogClassifier model; // 模型實例，由外部傳入本頁面
  const CatDogPage({super.key, required this.model});

  @override
  State<CatDogPage> createState() => _CatDogPageState();
}

class _CatDogPageState extends State<CatDogPage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes; // 圖片字節數據（支援所有平台）
  String? _prediction;    // 模型預測結果（"這是貓" 或 "這是狗"）
  bool _isProcessing = false; // 是否正在處理中

  /// 從相機拍照
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800, // 限制最大寬度，加速處理
        maxHeight: 800,
      );
      if (photo == null) return;  // 使用者取消拍照
      
      final bytes = await photo.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _prediction = null;      // 清除舊的預測結果
      });
    } catch (e) {
      _showError('拍照失敗: $e');
    }
  }

  /// 從相簿選擇圖片
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // 限制最大寬度，加速處理
        maxHeight: 800,
      );
      if (image == null) return;  // 使用者取消選擇
      
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _prediction = null;      // 清除舊的預測結果
      });
    } catch (e) {
      _showError('選擇圖片失敗: $e');
    }
  }

  /// 影像前處理 + 模型預測
  Future<void> _processImage() async {
    if (_imageBytes == null) {
      _showError('請先選擇或拍攝圖片');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. 解碼圖片
      imgLib.Image? src = imgLib.decodeImage(_imageBytes!);
      if (src == null) {
        throw Exception('無法讀取圖片');
      }

      // 2. 調整圖片大小為 64x64（貓狗分類常用尺寸）
      // 可根據實際模型需求調整
      const targetSize = 64;
      imgLib.Image resized = imgLib.copyResize(
        src,
        width: targetSize,
        height: targetSize,
        interpolation: imgLib.Interpolation.linear,
      );

      // 3. 提取 RGB 特徵並標準化到 [0, 1] 範圍
      final vector = <double>[];
      for (int y = 0; y < targetSize; y++) {
        for (int x = 0; x < targetSize; x++) {
          final pixel = resized.getPixel(x, y);
          // 提取 RGB 三個通道
          vector.add(pixel.r / 255.0);  // Red channel
          vector.add(pixel.g / 255.0);  // Green channel
          vector.add(pixel.b / 255.0);  // Blue channel
        }
      }

      debugPrint('圖片前處理完成: 特徵向量長度=${vector.length} (預期: ${targetSize * targetSize * 3})');

      // 4. 使用模型進行預測
      final pred = widget.model.predict(vector);

      setState(() {
        _prediction = pred;   // 儲存預測結果
        _isProcessing = false;
      });

      debugPrint('預測結果: $pred');
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('處理圖片失敗: $e');
      debugPrint('圖片處理錯誤: $e');
    }
  }

  /// 顯示錯誤訊息
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 重置狀態
  void _reset() {
    setState(() {
      _imageBytes = null;
      _prediction = null;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐱 貓狗圖片識別 🐶'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_imageBytes != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重置',
              onPressed: _reset,
            ),
        ],
      ),
      body: Column(
        children: [
          // 上方顯示選擇的照片或提示文字
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey[100],
              child: _imageBytes == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pets,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '請選擇或拍攝一張貓狗照片',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                        ),
                        if (_isProcessing)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          // 若已有預測結果，顯示在圖像下方
          if (_prediction != null && !_isProcessing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple[400]!, Colors.deepPurple[600]!],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _prediction!.split('(')[0].trim(), // 只顯示主要結果
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_prediction!.contains('信心度'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _prediction!.split('(')[1].replaceAll(')', ''),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // 下方操作按鈕
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拍照 + 相簿按鈕
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('拍照'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('相簿'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 辨識按鈕
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_imageBytes != null && !_isProcessing)
                        ? _processImage
                        : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.psychology),
                    label: Text(_isProcessing ? '辨識中...' : '開始辨識'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
