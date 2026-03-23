import 'package:flutter/material.dart';

// 🌟 1. 新增的單字物件結構
class VocabItem {
  final String word;
  final String kana;
  final String meaning;
  final String exampleSentence;

  VocabItem({
    required this.word,
    required this.kana,
    required this.meaning,
    required this.exampleSentence,
  });
}

// 🌟 2. 升級版的場景物件結構 (加上了 vocabularyList)
class ScenarioItem {
  final String title;
  final String date;
  final String? image;
  final List<VocabItem> vocabularyList; // 👈 就是少了這個！現在補上了！

  ScenarioItem({
    required this.title,
    required this.date,
    this.image,
    required this.vocabularyList,
  });
}

// 🌟 3. 測試用的假資料
class FavoritesDataProvider extends ChangeNotifier {
  static final List<ScenarioItem> allFavorites = [
    ScenarioItem(
      title: '一蘭拉麵店',
      date: '2023.10.27',
      image: 'assets/images/scenarios/ramen.png',
      vocabularyList: [
        VocabItem(
          word: 'ラーメン',
          kana: 'ラーメン',
          meaning: '拉麵',
          exampleSentence: 'このラーメンは美味しいです。',
        ),
        VocabItem(
          word: 'お会計',
          kana: 'おかいけい',
          meaning: '結帳',
          exampleSentence: 'お会計をお願いします。',
        ),
        VocabItem(
          word: 'メニュー',
          kana: 'メニュー',
          meaning: '菜單',
          exampleSentence: 'メニューを見せてください。',
        ),
      ],
    ),
    ScenarioItem(
      title: '新宿車站',
      date: '2023.10.28',
      image: 'assets/images/scenarios/station.png',
      vocabularyList: [
        VocabItem(
          word: '駅',
          kana: 'えき',
          meaning: '車站',
          exampleSentence: '新宿駅はどこですか？',
        ),
        VocabItem(
          word: '電車',
          kana: 'でんしゃ',
          meaning: '電車',
          exampleSentence: '電車に乗ります。',
        ),
        VocabItem(
          word: '乗り場',
          kana: 'のりば',
          meaning: '乘車處',
          exampleSentence: 'バスの乗り場はどこですか。',
        ),
      ],
    ),
    ScenarioItem(
      title: '淺草寺',
      date: '2023.10.29',
      image: 'assets/images/scenarios/temple.png',
      vocabularyList: [
        VocabItem(
          word: '寺',
          kana: 'てら',
          meaning: '寺廟',
          exampleSentence: '寺でお参りします。',
        ),
        VocabItem(
          word: 'お守り',
          kana: 'おまもり',
          meaning: '御守',
          exampleSentence: 'お守りを買います。',
        ),
      ],
    ),
  ];
}
