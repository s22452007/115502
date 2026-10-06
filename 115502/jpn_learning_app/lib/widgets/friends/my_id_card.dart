import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 好友 QR Code 的內容前綴，掃描端靠它判斷是不是本 App 的好友碼
const String kFriendQrPrefix = 'snaptolearn:friend:';

class MyIdCard extends StatelessWidget {
  final String myId;
  /// 好友 ID 還沒產生時為 false，不能複製也不能出示 QR Code
  final bool hasId;
  const MyIdCard({Key? key, required this.myId, this.hasId = true}) : super(key: key);

  void _showQrDialog(BuildContext context, Color darkGreen) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('我的好友 QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              QrImageView(
                data: '$kFriendQrPrefix$myId',
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: darkGreen),
                dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: darkGreen),
              ),
              const SizedBox(height: 12),
              Text(myId, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: darkGreen)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('關閉', style: TextStyle(color: darkGreen)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color darkGreen = const Color(0xFF4A7A4D);
    final Color lightGreen = const Color(0xFFBFE1C3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGreen.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightGreen),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('我的專屬 ID', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(myId, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: darkGreen)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.black54),
                onPressed: hasId
                    ? () async {
                        await Clipboard.setData(ClipboardData(text: myId));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID 已複製到剪貼簿！📋'), behavior: SnackBarBehavior.floating));
                      }
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.qr_code, color: hasId ? darkGreen : Colors.black26),
                onPressed: hasId ? () => _showQrDialog(context, darkGreen) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
