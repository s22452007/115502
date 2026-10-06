import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:jpn_learning_app/widgets/friends/my_id_card.dart';

/// 掃描好友 QR Code，掃到後 pop 回傳對方的好友 ID
class ScanFriendQrScreen extends StatefulWidget {
  const ScanFriendQrScreen({Key? key}) : super(key: key);

  @override
  State<ScanFriendQrScreen> createState() => _ScanFriendQrScreenState();
}

class _ScanFriendQrScreenState extends State<ScanFriendQrScreen> {
  final MobileScannerController _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _handled = false;
  DateTime? _lastInvalidHint;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      if (raw.startsWith(kFriendQrPrefix)) {
        final friendId = raw.substring(kFriendQrPrefix.length).trim();
        if (friendId.isEmpty) continue;
        _handled = true;
        Navigator.pop(context, friendId);
        return;
      }
    }
    // 掃到別的 QR Code：提示一次就好，不要每一幀都跳
    final now = DateTime.now();
    if (_lastInvalidHint == null || now.difference(_lastInvalidHint!) > const Duration(seconds: 3)) {
      _lastInvalidHint = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('這不是好友 QR Code'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('掃描好友 QR Code'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? '沒有相機權限，請到系統設定開啟'
                      : '相機無法啟動',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
