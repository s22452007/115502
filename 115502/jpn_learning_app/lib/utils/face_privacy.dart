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
  final int idCount;
  final int phoneCount;
  final int addressCount;

  const PrivacyGuardResult({
    required this.imagePath,
    required this.faceCount,
    required this.cardCount,
    required this.idCount,
    required this.phoneCount,
    required this.addressCount,
  });

  bool get hasSensitiveContent =>
      faceCount > 0 || cardCount > 0 || idCount > 0 || phoneCount > 0 || addressCount > 0;
}

// ==========================================
// 信用卡卡號（格式規則 + Luhn 檢查碼）
// ==========================================

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

bool _containsValidCardNumber(String text) {
  for (final match in _cardLikeDigits.allMatches(text)) {
    final digits = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 13 && digits.length <= 19 && _passesLuhnCheck(digits)) {
      return true;
    }
  }
  return false;
}

// ==========================================
// 台灣身分證字號（格式規則 + 檢查碼公式）
// ==========================================

const _idLetterCode = {
  'A': 10, 'B': 11, 'C': 12, 'D': 13, 'E': 14, 'F': 15, 'G': 16, 'H': 17,
  'I': 34, 'J': 18, 'K': 19, 'L': 20, 'M': 21, 'N': 22, 'O': 35, 'P': 23,
  'Q': 24, 'R': 25, 'S': 26, 'T': 27, 'U': 28, 'V': 29, 'W': 32, 'X': 30,
  'Y': 31, 'Z': 33,
};
const _idWeights = [1, 9, 8, 7, 6, 5, 4, 3, 2, 1, 1];

bool _isValidTwId(String id) {
  if (id.length != 10) return false;
  final code = _idLetterCode[id[0].toUpperCase()];
  final rest = id.substring(1);
  if (code == null || !RegExp(r'^[0-9]{9}$').hasMatch(rest)) return false;

  final digits = [code ~/ 10, code % 10, ...rest.split('').map(int.parse)];
  int sum = 0;
  for (int i = 0; i < 11; i++) {
    sum += digits[i] * _idWeights[i];
  }
  return sum % 10 == 0;
}

final _idLikePattern = RegExp(r'[A-Za-z][0-9]{9}');

bool _containsValidTwId(String text) {
  final compact = text.replaceAll(' ', '');
  for (final match in _idLikePattern.allMatches(compact)) {
    if (_isValidTwId(match.group(0)!)) return true;
  }
  return false;
}

// ==========================================
// 電話號碼（格式規則，沒有檢查碼可驗證）
// ==========================================

final _phonePattern = RegExp(
  r'09\d{2}[- ]?\d{3}[- ]?\d{3}|0[2-8][- ]?\d{3,4}[- ]?\d{4}',
);

bool _containsPhoneNumber(String text) => _phonePattern.hasMatch(text);

// ==========================================
// 地址（關鍵字 + 需含數字，準確度最低，僅供參考）
// ==========================================

const _addressKeywords = ['區', '路', '街', '巷', '弄', '號', '樓'];

bool _looksLikeAddress(String text) {
  if (!RegExp(r'[0-9]').hasMatch(text)) return false;
  return _addressKeywords.any((k) => text.contains(k));
}

// ==========================================
// 打馬賽克
// ==========================================

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

/// 掃過每個文字區塊/文字行，符合 [test] 的話把它的框收進 [boxes]。
/// 區塊整體符合就不用再逐行檢查（避免同一塊被糊兩次沒意義的重疊）。
void _collectMatches(RecognizedText recognizedText, bool Function(String) test, List<Rect> boxes) {
  for (final block in recognizedText.blocks) {
    if (test(block.text)) {
      boxes.add(block.boundingBox);
      continue;
    }
    for (final line in block.lines) {
      if (test(line.text)) {
        boxes.add(line.boundingBox);
      }
    }
  }
}

/// 偵測照片中的人臉、信用卡卡號、身分證字號、電話號碼、疑似地址，
/// 有偵測到的都會打上馬賽克後另存新檔。
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
  final idBoxes = <Rect>[];
  final phoneBoxes = <Rect>[];
  final addressBoxes = <Rect>[];
  _collectMatches(recognizedText, _containsValidCardNumber, cardBoxes);
  _collectMatches(recognizedText, _containsValidTwId, idBoxes);
  _collectMatches(recognizedText, _containsPhoneNumber, phoneBoxes);
  _collectMatches(recognizedText, _looksLikeAddress, addressBoxes);

  if (faces.isEmpty &&
      cardBoxes.isEmpty &&
      idBoxes.isEmpty &&
      phoneBoxes.isEmpty &&
      addressBoxes.isEmpty) {
    return PrivacyGuardResult(
      imagePath: sourcePath,
      faceCount: 0,
      cardCount: 0,
      idCount: 0,
      phoneCount: 0,
      addressCount: 0,
    );
  }

  final bytes = await File(sourcePath).readAsBytes();
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return PrivacyGuardResult(
      imagePath: sourcePath,
      faceCount: faces.length,
      cardCount: cardBoxes.length,
      idCount: idBoxes.length,
      phoneCount: phoneBoxes.length,
      addressCount: addressBoxes.length,
    );
  }
  // ML Kit 回傳的座標是「視覺上正的」座標系，圖片像素本身也要先轉正才能對上
  decoded = img.bakeOrientation(decoded);

  for (final face in faces) {
    // 臉的邊緣（瀏海、耳朵）容易被偵測框漏掉，多留一點空間
    _blurRegion(decoded, face.boundingBox, padRatioX: 0.15, padRatioY: 0.2);
  }
  for (final box in [...cardBoxes, ...idBoxes, ...phoneBoxes, ...addressBoxes]) {
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
    idCount: idBoxes.length,
    phoneCount: phoneBoxes.length,
    addressCount: addressBoxes.length,
  );
}
