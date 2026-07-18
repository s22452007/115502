import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PrivacyGuardResult {
  final String imagePath;
  final int faceCount;
  final int cardCount;

  const PrivacyGuardResult({
    required this.imagePath,
    required this.faceCount,
    required this.cardCount,
  });

  bool get hasSensitiveContent => faceCount > 0 || cardCount > 0;
}

/// 信用卡卡號的合法性檢查（Luhn 演算法，跟刷卡系統驗證卡號用的是同一套公式）
bool _passesLuhnCheck(String digits) {
  int sum = 0;
  bool doubleDigit = false;
  for (int i = digits.length - 1; i >= 0; i--) {
    int n = int.parse(digits[i]);
    if (doubleDigit) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    doubleDigit = !doubleDigit;
  }
  return sum % 10 == 0;
}

final _cardLikeDigits = RegExp(r'(?:\d[ -]?){13,19}');

/// 從一段文字裡找出「看起來像信用卡號、且通過 Luhn 檢查碼驗證」的片段
bool _containsValidCardNumber(String text) {
  for (final match in _cardLikeDigits.allMatches(text)) {
    final digits = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 13 && digits.length <= 19 && _passesLuhnCheck(digits)) {
      return true;
    }
  }
  return false;
}

void _blurRegion(img.Image image, Rect box, {double padRatioX = 0.1, double padRatioY = 0.1}) {
  final padX = box.width * padRatioX;
  final padY = box.height * padRatioY;
  final x = (box.left - padX).clamp(0, image.width - 1).toInt();
  final y = (box.top - padY).clamp(0, image.height - 1).toInt();
  final w = (box.width + padX * 2).clamp(1, image.width - x).toInt();
  final h = (box.height + padY * 2).clamp(1, image.height - y).toInt();
  if (w <= 0 || h <= 0) return;

  final region = img.copyCrop(image, x: x, y: y, width: w, height: h);
  final pixelSize = (w / 8).clamp(6, 30).toInt();
  final pixelated = img.pixelate(region, size: pixelSize);
  img.compositeImage(image, pixelated, dstX: x, dstY: y);
}

/// 偵測照片中的人臉與疑似信用卡卡號，兩者都會打上馬賽克後另存新檔。
/// 都沒偵測到時，直接回傳原始路徑（不重新編碼，避免不必要的畫質耗損）。
Future<PrivacyGuardResult> detectAndBlurSensitiveContent(String sourcePath) async {
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  List<Face> faces;
  RecognizedText recognizedText;
  try {
    final inputImage = InputImage.fromFilePath(sourcePath);
    faces = await faceDetector.processImage(inputImage);
    recognizedText = await textRecognizer.processImage(inputImage);
  } finally {
    await faceDetector.close();
    await textRecognizer.close();
  }

  final cardBoxes = <Rect>[];
  for (final block in recognizedText.blocks) {
    if (_containsValidCardNumber(block.text)) {
      cardBoxes.add(block.boundingBox);
      continue; // 整個區塊都糊掉了，不用再逐行檢查
    }
    for (final line in block.lines) {
      if (_containsValidCardNumber(line.text)) {
        cardBoxes.add(line.boundingBox);
      }
    }
  }

  if (faces.isEmpty && cardBoxes.isEmpty) {
    return PrivacyGuardResult(imagePath: sourcePath, faceCount: 0, cardCount: 0);
  }

  final bytes = await File(sourcePath).readAsBytes();
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return PrivacyGuardResult(
      imagePath: sourcePath,
      faceCount: faces.length,
      cardCount: cardBoxes.length,
    );
  }
  // ML Kit 回傳的座標是「視覺上正的」座標系，圖片像素本身也要先轉正才能對上
  decoded = img.bakeOrientation(decoded);

  for (final face in faces) {
    // 臉的邊緣（瀏海、耳朵）容易被偵測框漏掉，多留一點空間
    _blurRegion(decoded, face.boundingBox, padRatioX: 0.15, padRatioY: 0.2);
  }
  for (final box in cardBoxes) {
    _blurRegion(decoded, box, padRatioX: 0.1, padRatioY: 0.15);
  }

  final dir = await getTemporaryDirectory();
  final outPath =
      '${dir.path}/privacy_blurred_${DateTime.now().microsecondsSinceEpoch}.jpg';
  await File(outPath).writeAsBytes(img.encodeJpg(decoded, quality: 90));

  return PrivacyGuardResult(
    imagePath: outPath,
    faceCount: faces.length,
    cardCount: cardBoxes.length,
  );
}
