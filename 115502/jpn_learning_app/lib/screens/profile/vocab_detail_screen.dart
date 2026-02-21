import 'package:flutter/material.dart';
import 'package:jpn_learning_app_new/utils/constants.dart';

class VocabDetailScreen extends StatelessWidget {
  const VocabDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                child: Image.network('https://picsum.photos/400/220', height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('拉麵 ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text('ラーメン', style: TextStyle(fontSize: 18, color: AppColors.textGrey)),
                      const SizedBox(width: 8),
                      Icon(Icons.volume_up, color: AppColors.primary),
                    ]),
                    const SizedBox(height: 12),
                    const Text('解釋：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('日本拉麵於其豐富多變的湯頭、搭配性強的麵條，以及叉燒、海苔、蔥花等豐富配料，形成了「湯、麵、醬、油、配料」五大元素的巧妙組合。', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
