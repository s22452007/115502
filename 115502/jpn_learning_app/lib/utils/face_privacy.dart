import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class FacePrivacyResult {
  final String imagePath;
  final int faceCount;

  const FacePrivacyResult({required this.imagePath, required this.faceCount});
}

/// 偵測照片中的人臉，若有偵測到就打上馬賽克後另存新檔。
/// 沒有偵測到臉時，直接回傳原始路徑（不重新編碼，避免不必要的畫質耗損）。
Future<FacePrivacyResult> detectAndBlurFaces(String sourcePath) async {
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );

  List<Face> faces;
  try {
    faces = await faceDetector.processImage(InputImage.fromFilePath(sourcePath));
  } finally {
    await faceDetector.close();
  }

  if (faces.isEmpty) {
    return FacePrivacyResult(imagePath: sourcePath, faceCount: 0);
  }

  final bytes = await File(sourcePath).readAsBytes();
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return FacePrivacyResult(imagePath: sourcePath, faceCount: faces.length);
  }
  // ML Kit 回傳的座標是「視覺上正的」座標系，圖片像素本身也要先轉正才能對上
  decoded = img.bakeOrientation(decoded);

  for (final face in faces) {
    final box = face.boundingBox;
    // 偵測框稍微放大一點，避免臉的邊緣（瀏海、耳朵）沒被糊到
    final padX = box.width * 0.15;
    final padY = box.height * 0.2;
    final x = (box.left - padX).clamp(0, decoded.width - 1).toInt();
    final y = (box.top - padY).clamp(0, decoded.height - 1).toInt();
    final w = (box.width + padX * 2).clamp(1, decoded.width - x).toInt();
    final h = (box.height + padY * 2).clamp(1, decoded.height - y).toInt();
    if (w <= 0 || h <= 0) continue;

    final region = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    final pixelSize = (w / 8).clamp(6, 30).toInt();
    final pixelated = img.pixelate(region, size: pixelSize);
    img.compositeImage(decoded, pixelated, dstX: x, dstY: y);
  }

  final dir = await getTemporaryDirectory();
  final outPath =
      '${dir.path}/face_blurred_${DateTime.now().microsecondsSinceEpoch}.jpg';
  await File(outPath).writeAsBytes(img.encodeJpg(decoded, quality: 90));

  return FacePrivacyResult(imagePath: outPath, faceCount: faces.length);
}
