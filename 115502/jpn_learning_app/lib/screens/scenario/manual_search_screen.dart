import 'dart:typed_data' show Uint8List;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/utils/constants.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/utils/sub_page_template.dart';
import 'package:jpn_learning_app/screens/scenario/roleplay_screen.dart';

class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({Key? key}) : super(key: key);

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _scenes = [];

  // 角色清單資料：預設老師＋自訂角色都由後端提供，這裡只是載入前的預設值；
  // 使用者自訂的角色會加在後面
  List<Map<String, dynamic>> _characters = [
    {
      'id': 'default_teacher',
      'name': '預設老師',
      'role': '親切耐心，標準日語',
      'origin': '東京',
      'age': '30',
      'gender': '女',
      'personality': '溫柔、有耐心、發音標準',
      'special_traits': '專業的日語教師，會糾正文法錯誤',
      'cost': 0,
      'owned': true,
    },
  ];

  // 預設選中的角色
  String _selectedCharacterName = '預設老師';

  // 腔調：每新增一個自訂角色可以解鎖一種（選了不能換）；null 代表標準語
  bool _ownsCharacter = false; // 新增過自訂角色才能用男聲
  Set<int> _unlockedDialectIds = {};
  int _freeDialectSlots = 0; // 買了角色但還沒選腔調的名額
  List<Map<String, dynamic>> _dialects = [];
  int? _selectedDialectId;
  String _voiceGender = 'female';
  int _customCost = 200; // 新增一個自訂角色的點數（以後端回傳為準）

  // 試聽：音檔是後端事先產生好的，抓過的存在記憶體裡不重複下載
  final AudioPlayer _previewPlayer = AudioPlayer();
  final Map<String, Uint8List> _previewCache = {};
  String? _previewingPath;
  int _previewTicket = 0; // 最新一次按試聽的號碼
  int _playingTicket = 0; // 目前播放器裡那一段是哪一次按的

  @override
  void initState() {
    super.initState();
    _loadScenes();
    _loadCharacters();
    _loadDialects();
    _previewPlayer.onPlayerComplete.listen((_) {
      // 舊的那一段播完（或被停掉）的通知比較晚到時，不要把剛按的新試聽圖示清掉
      if (mounted && _playingTicket == _previewTicket) {
        setState(() => _previewingPath = null);
      }
    });
  }

  Future<void> _loadScenes() async {
    final scenes = await ApiClient.getScenes(quickSelect: true);
    if (!mounted) return;
    setState(() => _scenes = scenes);
  }

  Future<void> _loadCharacters() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    final res = await ApiClient.getCharacters(userId);
    if (!mounted || !res.containsKey('characters')) return;
    setState(() {
      // 預設老師在前、自己花點數新增的自訂角色在後
      _characters = [
        ...List<Map<String, dynamic>>.from(res['characters']),
        ...List<Map<String, dynamic>>.from(res['custom_characters'] ?? []),
      ];
      _customCost =
          (res['custom_character_cost'] as num?)?.toInt() ?? _customCost;
      if (!_characters.any((c) => c['name'] == _selectedCharacterName)) {
        _selectedCharacterName = '預設老師';
      }
      _ownsCharacter = res['dialect_unlocked'] == true;
      _unlockedDialectIds = {
        for (final id in (res['unlocked_dialect_ids'] as List? ?? []))
          (id as num).toInt(),
      };
      _freeDialectSlots = (res['free_dialect_slots'] as num?)?.toInt() ?? 0;
      if (!_unlockedDialectIds.contains(_selectedDialectId)) {
        _selectedDialectId = null;
      }
    });
  }

  Future<void> _loadDialects() async {
    final dialects = await ApiClient.getDialects();
    if (!mounted) return;
    setState(() => _dialects = dialects);
  }

  // 下載試聽音檔。連線偶爾會在傳到一半時被後端關掉
  //（Connection closed while receiving data），重新連一次通常就好，所以失敗會自動再試。
  Future<Uint8List> _downloadPreview(String path) async {
    final url = Uri.parse('${ApiClient.baseUrl.replaceAll('/api', '')}$path');
    const maxAttempts = 3;
    for (var attempt = 1; ; attempt++) {
      try {
        final res = await ApiClient.client.get(url);
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        return res.bodyBytes;
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;
        debugPrint('[試聽] $path 第 $attempt 次下載失敗，重試中: $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  // 按一下試聽，再按一下（或按別的）就停止
  Future<void> _togglePreview(String path) async {
    final wasPlaying = _previewingPath == path;
    // 每按一次發一張新號碼牌：連續按不同列時，只有最後按的那一次算數
    final ticket = ++_previewTicket;
    // 先更新畫面再去停舊的、抓新的，按下去圖示就會馬上跳到這一列
    setState(() => _previewingPath = wasPlaying ? null : path);
    try {
      await _previewPlayer.stop();
      if (wasPlaying || !mounted || ticket != _previewTicket) return;
      var bytes = _previewCache[path];
      if (bytes == null) {
        bytes = await _downloadPreview(path);
        _previewCache[path] = bytes;
      }
      // 下載期間使用者可能已經按了別的
      if (!mounted || ticket != _previewTicket) return;
      _playingTicket = ticket;
      await _previewPlayer.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('[試聽] $path 失敗: ${e.runtimeType} → $e');
      // 已經改按別的試聽（或按了停止）時，被中斷的這一次不算失敗
      if (!mounted || ticket != _previewTicket) return;
      setState(() => _previewingPath = null);
      _showSnack('試聽播放失敗，請稍後再試', isError: true);
    }
  }

  void _selectVoiceGender(String gender) {
    _previewTicket++;
    _previewPlayer.stop();
    setState(() {
      _voiceGender = gender;
      _previewingPath = null;
    });
  }

  // 還沒解鎖的付費腔調
  List<Map<String, dynamic>> get _lockedDialects => _dialects
      .where(
        (d) =>
            d['jp_name'] != '標準語' &&
            !_unlockedDialectIds.contains((d['id'] as num).toInt()),
      )
      .toList();

  // 點到鎖住的腔調：有名額就確認後解鎖，沒有就提示要買角色
  Future<void> _onLockedDialectTap(Map<String, dynamic> d) async {
    if (_freeDialectSlots <= 0) {
      _showSnack('新增自訂角色可以解鎖一種腔調');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '解鎖「${d['name']}」',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '會用掉一個腔調名額，選了之後不能換成別的腔調。',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('再想想', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '確定解鎖',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    final dialectId = (d['id'] as num).toInt();
    final res = await ApiClient.chooseDialect(
      userId: userId,
      dialectId: dialectId,
    );
    if (!mounted) return;
    if (res.containsKey('error')) {
      _showSnack(res['error'].toString(), isError: true);
      return;
    }
    _showSnack('已解鎖「${d['name']}」');
    await _loadCharacters();
    if (mounted) setState(() => _selectedDialectId = dialectId);
  }

  // 腔調與男女聲：每一列可以試聽；標準語免費，其他要用買角色的名額解鎖
  List<Widget> _buildDialectSection() {
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              '腔調與聲音',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
          ),
          for (final g in const [
            ['female', '女聲'],
            ['male', '男聲'],
          ])
            Padding(
              padding: const EdgeInsets.only(left: 8),
              // 沒解鎖時還是可以切換來試聽，但對話用的是基本語音
              child: ChoiceChip(
                avatar: _ownsCharacter
                    ? null
                    : Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: _voiceGender == g[0]
                            ? Colors.white
                            : Colors.grey,
                      ),
                label: Text(g[1]),
                selected: _voiceGender == g[0],
                showCheckmark: false,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: _voiceGender == g[0]
                      ? Colors.white
                      : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => _selectVoiceGender(g[0]),
              ),
            ),
        ],
      ),
      if (_freeDialectSlots > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '還有 $_freeDialectSlots 個腔調名額，選了不能換',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
      const SizedBox(height: 12),
      ..._dialects.map(_buildDialectRow),
    ];
  }

  Widget _buildDialectRow(Map<String, dynamic> d) {
    final isStandard = d['jp_name'] == '標準語';
    final int? value = isStandard ? null : (d['id'] as num).toInt();
    final selectable = isStandard || _unlockedDialectIds.contains(value);
    final isSelected = _selectedDialectId == value;
    final samplePath = (d['samples'] as Map?)?[_voiceGender] as String?;
    final isPlaying = samplePath != null && _previewingPath == samplePath;

    return GestureDetector(
      onTap: () {
        if (selectable) {
          setState(() => _selectedDialectId = value);
        } else {
          _onLockedDialectTap(d);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(left: 16, right: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            // 正在試聽的那一列也加粗外框，一眼看得出現在播的是哪一個
            color: isSelected || isPlaying
                ? AppColors.primary
                : Colors.grey.shade300,
            width: isSelected || isPlaying ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: isStandard ? '標準語' : d['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: selectable ? AppColors.textDark : Colors.grey,
                  ),
                  children: [
                    TextSpan(
                      text: '　${d['region']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isStandard)
              const Text(
                '免費',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else if (!selectable) ...[
              const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 2),
              const Text(
                '付費',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            IconButton(
              tooltip: '試聽',
              icon: Icon(
                isPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
              ),
              color: AppColors.primary,
              // 沒有音檔時也要接住這次點擊，不然會穿透到整列，變成跳出解鎖視窗
              onPressed: samplePath == null
                  ? () => _showSnack('這個試聽音檔還沒準備好', isError: true)
                  : () {
                      // 能選的列，按試聽就順便選起來（鎖住的列只試聽）
                      if (selectable && !isPlaying) {
                        setState(() => _selectedDialectId = value);
                      }
                      _togglePreview(samplePath);
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppColors.primary,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  void _submitScenario() {
    if (_searchController.text.trim().isEmpty) return;

    final selectedTopic = _searchController.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleplayScreen(
          topicTitle: selectedTopic,
          characterName: _selectedCharacterName,
          dialectId: _unlockedDialectIds.contains(_selectedDialectId)
              ? _selectedDialectId
              : null,
          voiceGender: _ownsCharacter ? _voiceGender : 'female',
        ),
      ),
    );
  }

  // 新增角色彈窗：輸入框的 controller 由彈窗自己管理（見檔案最下面的 _AddCharacterDialog）
  // 要花點數，送出後在彈窗裡等後端結果，失敗（點數不足、重名）就留在彈窗讓使用者改
  Future<void> _showAddCharacterDialog(BuildContext context) async {
    final user = context.read<UserProvider>();
    final userId = user.userId;
    if (userId == null) return;
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddCharacterDialog(
        cost: _customCost,
        dialects: _lockedDialects,
        voiceGender: _voiceGender,
        onPreview: _togglePreview,
        onSubmit: (fields) async {
          if (user.jPts < _customCost) {
            return {'error': '點數不足喔！需要 $_customCost 點，請先儲值'};
          }
          return ApiClient.createCustomCharacter(
            userId: userId,
            fields: fields,
          );
        },
      ),
    );
    // 視窗關掉時，裡面按的試聽也一起停
    _previewTicket++;
    _previewPlayer.stop();
    if (mounted) setState(() => _previewingPath = null);
    if (created == null || !mounted) return;
    user.setJPts(
      (created['total_points'] as num?)?.toInt() ?? user.jPts - _customCost,
    );
    _showSnack(created['message']?.toString() ?? '新增成功！');
    await _loadCharacters();
    if (!mounted) return;
    final name = (created['character'] as Map?)?['name'];
    final unlocked = (created['unlocked_dialect_ids'] as List? ?? []).map(
      (e) => (e as num).toInt(),
    );
    setState(() {
      if (name != null) _selectedCharacterName = name;
      // 新增時順便解鎖的腔調直接選起來
      final picked = int.tryParse('${created['_picked_dialect_id'] ?? ''}');
      if (picked != null && unlocked.contains(picked)) {
        _selectedDialectId = picked;
      }
    });
  }

  // 長按自訂角色：刪除（不退點數）
  Future<void> _confirmDeleteCustom(Map<String, dynamic> char) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('刪除「${char['name']}」？'),
        content: const Text('刪除後無法復原，也不會退還點數。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;
    final res = await ApiClient.deleteCustomCharacter(
      userId: userId,
      customId: (char['custom_id'] as num).toInt(),
    );
    if (!mounted) return;
    if (res.containsKey('error')) {
      _showSnack(res['error'].toString(), isError: true);
      return;
    }
    _showSnack(res['message']?.toString() ?? '已刪除');
    await _loadCharacters();
  }

  @override
  Widget build(BuildContext context) {
    return SubPageTemplate(
      title: '手動建立情境',
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '想練習什麼樣的對話呢？',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '輸入您想模擬的情境或主題，AI 將為您量身打造專屬的日語課程！',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextField(
                        controller: _searchController,
                        maxLength: 20,
                        onChanged: (value) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '例如：在便利商店買咖啡...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.primary,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        '快速選擇主題',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Wrap(
                        spacing: 10,
                        runSpacing: 12,
                        children: _scenes.map((scene) {
                          final int? codepoint =
                              scene['icon_codepoint'] as int?;
                          final String text = scene['name'] as String;

                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _searchController.text = text;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    codepoint != null
                                        ? IconData(
                                            codepoint,
                                            fontFamily: 'MaterialIcons',
                                          )
                                        : Icons.category,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        '選擇對話對象',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(right: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _characters.length,
                          itemBuilder: (context, index) {
                            // 渲染一般角色卡片
                            final char = _characters[index];
                            final isSelected =
                                _selectedCharacterName == char['name'];

                            return GestureDetector(
                              onLongPress: char['custom_id'] == null
                                  ? null
                                  : () => _confirmDeleteCustom(char),
                              onTap: () => setState(
                                () => _selectedCharacterName = char['name'],
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      char['name'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      char['role'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white70
                                            : Colors.black54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 自訂角色按鈕放在角色列下面，角色變多也不用滑到最右邊才找得到
                      GestureDetector(
                        onTap: () => _showAddCharacterDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '自訂角色',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      ..._buildDialectSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _searchController.text.trim().isEmpty
                      ? null
                      : _submitScenario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.9),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: _searchController.text.trim().isEmpty ? 0 : 2,
                  ),
                  child: Text(
                    '開始生成情境',
                    style: TextStyle(
                      color: _searchController.text.trim().isEmpty
                          ? Colors.grey.shade500
                          : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 新增自訂角色的彈窗。
/// controller 要跟著彈窗的 State 一起釋放：以前是 showDialog 一結束就 dispose，
/// 但彈窗關閉動畫還在跑、輸入框還會重畫，用到已釋放的 controller 就整個畫面變紅。
class _AddCharacterDialog extends StatefulWidget {
  const _AddCharacterDialog({
    required this.cost,
    required this.dialects,
    required this.voiceGender,
    required this.onPreview,
    required this.onSubmit,
  });

  /// 新增一個自訂角色要花的點數
  final int cost;

  /// 還沒解鎖、可以附贈的腔調（含試聽音檔）
  final List<Map<String, dynamic>> dialects;
  final String voiceGender;
  final Future<void> Function(String path) onPreview;

  /// 送出六個欄位，回傳後端結果；有 'error' 就留在彈窗顯示，成功就把結果帶回去
  final Future<Map<String, dynamic>> Function(Map<String, String> fields)
  onSubmit;

  @override
  State<_AddCharacterDialog> createState() => _AddCharacterDialogState();
}

class _AddCharacterDialogState extends State<_AddCharacterDialog> {
  final nameCtrl = TextEditingController();
  final originCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final genderCtrl = TextEditingController();
  final personalityCtrl = TextEditingController();
  final traitsCtrl = TextEditingController();
  bool _attemptedSubmit = false;
  bool _submitting = false;
  String? _submitError;
  int? _dialectId; // null = 之後再選

  Future<void> _submit() async {
    setState(() {
      _attemptedSubmit = true;
      _submitError = null;
    });
    final hasMissingFields = [
      nameCtrl,
      originCtrl,
      ageCtrl,
      genderCtrl,
      personalityCtrl,
      traitsCtrl,
    ].any((controller) => controller.text.trim().isEmpty);
    if (hasMissingFields) return;

    setState(() => _submitting = true);
    final res = await widget.onSubmit({
      'name': nameCtrl.text.trim(),
      'origin': originCtrl.text.trim(),
      'age': ageCtrl.text.trim(),
      'gender': genderCtrl.text.trim(),
      'personality': personalityCtrl.text.trim(),
      'special_traits': traitsCtrl.text.trim(),
      if (_dialectId != null) 'dialect_id': '$_dialectId',
    });
    if (!mounted) return;
    if (res.containsKey('error')) {
      setState(() {
        _submitting = false;
        _submitError = res['error'].toString();
      });
      return;
    }
    Navigator.pop(context, {...res, '_picked_dialect_id': _dialectId});
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    originCtrl.dispose();
    ageCtrl.dispose();
    genderCtrl.dispose();
    personalityCtrl.dispose();
    traitsCtrl.dispose();
    super.dispose();
  }

  // 範例角色：當作每一格的灰字提示，也可以按「帶入範例」直接填進去再改
  static const _example = {
    '姓名': '佐藤 美咲',
    '出身地': '大阪',
    '年紀': '25',
    '性別': '女',
    '個性': '開朗健談、愛開玩笑',
    '特殊設定': '章魚燒店的店員，喜歡推薦當地美食',
  };

  void _fillExample() {
    setState(() {
      nameCtrl.text = _example['姓名']!;
      originCtrl.text = _example['出身地']!;
      ageCtrl.text = _example['年紀']!;
      genderCtrl.text = _example['性別']!;
      personalityCtrl.text = _example['個性']!;
      traitsCtrl.text = _example['特殊設定']!;
    });
  }

  InputDecoration requiredDecoration(
    String label,
    TextEditingController controller,
  ) {
    final isMissing = _attemptedSubmit && controller.text.trim().isEmpty;
    final color = isMissing ? Colors.red : AppColors.primary;

    return InputDecoration(
      labelText: '$label *',
      hintText: '例如：${_example[label]}',
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(color: isMissing ? Colors.red : null),
      errorText: isMissing ? '此欄位為必填' : null,
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: isMissing ? Colors.red : Colors.grey),
      ),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: color)),
    );
  }

  Widget _dialectOption(int? id, String label, String? samplePath) {
    final selected = _dialectId == id;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => _dialectId = id),
            ),
          ),
        ),
        if (samplePath != null)
          IconButton(
            tooltip: '試聽',
            icon: const Icon(Icons.play_circle_outline),
            color: AppColors.primary,
            onPressed: () => widget.onPreview(samplePath),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Expanded(
            child: Text(
              '新增對話角色',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text('必填', style: TextStyle(color: Colors.red, fontSize: 14)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _fillExample,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('不知道怎麼填？帶入範例'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            TextField(
              controller: nameCtrl,
              decoration: requiredDecoration('姓名', nameCtrl),
              onChanged: (_) => setState(() {}),
              cursorColor: AppColors.primary,
            ),
            TextField(
              controller: originCtrl,
              decoration: requiredDecoration('出身地', originCtrl),
              onChanged: (_) => setState(() {}),
              cursorColor: AppColors.primary,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ageCtrl,
                    decoration: requiredDecoration('年紀', ageCtrl),
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    cursorColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: genderCtrl,
                    decoration: requiredDecoration('性別', genderCtrl),
                    onChanged: (_) => setState(() {}),
                    cursorColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            TextField(
              controller: personalityCtrl,
              decoration: requiredDecoration('個性', personalityCtrl),
              onChanged: (_) => setState(() {}),
              cursorColor: AppColors.primary,
            ),
            TextField(
              controller: traitsCtrl,
              decoration: requiredDecoration('特殊設定', traitsCtrl),
              onChanged: (_) => setState(() {}),
              maxLines: 2,
              cursorColor: AppColors.primary,
            ),
            if (widget.dialects.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '附贈腔調（選了不能換）',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              _dialectOption(null, '之後再選', null),
              for (final d in widget.dialects)
                _dialectOption(
                  (d['id'] as num).toInt(),
                  d['name'] as String,
                  (d['samples'] as Map?)?[widget.voiceGender] as String?,
                ),
            ],
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _submitError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  '花 ${widget.cost} 點新增',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
