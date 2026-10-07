import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:jpn_learning_app/providers/user_provider.dart';
import 'package:jpn_learning_app/services/notification_service.dart';
import 'package:jpn_learning_app/utils/api_client.dart';
import 'package:jpn_learning_app/screens/edu/assignment_detail_screen.dart';
import 'package:jpn_learning_app/screens/edu/classroom_announcement_screen.dart';

/// 手機推播（Firebase Cloud Messaging）：老師發公告、出作業、批改完成時，後端推到學生手機；
/// 學習小組成員按「提醒隊友」時推給同組隊友。
///
/// - 使用者登入後 [register]，把這支手機的 token 交給後端；登出時 [unregister]
/// - App 在背景或關閉時，通知由系統直接顯示；App 開著時系統不會跳，改用本機通知顯示
/// - 點通知打開對應的作業或公告。App 不會記住登入，從關閉狀態點進來會先到登入頁，
///   所以先記下來，登入進首頁後由 [openPending] 再打開
/// - 後端沒設定推播金鑰時不會送，這裡照常運作，只是收不到
class PushService {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static Map<String, dynamic>? _pending;
  static int? _registeredUserId;
  static String? _registeredToken;

  /// App 啟動時呼叫一次（main.dart，在 runApp 之前）
  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (kIsWeb) return;
    _navigatorKey = navigatorKey;
    // 本機通知（作業截止提醒、App 開著時收到的推播）被點的時候
    NotificationService.onTapPayload = (payload) {
      final data = _decode(payload);
      if (data != null) _open(data);
    };
    try {
      FirebaseMessaging.onMessage.listen(_showWhileOpen);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        final uid = _registeredUserId;
        if (uid != null) _send(uid, token);
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pending = Map<String, dynamic>.from(initial.data);
    } catch (e) {
      debugPrint('推播初始化失敗（不影響其他功能）: $e');
    }
    _pending ??= _decode(await NotificationService.launchPayload());
  }

  /// 學生登入後呼叫（首頁載入時）。同一個帳號、同一支手機登記過就不再送
  static Future<void> register(int userId) async {
    if (kIsWeb) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      if (_registeredUserId == userId && _registeredToken == token) return;
      await _send(userId, token);
    } catch (e) {
      // 沒有 Google Play 服務的模擬器會走到這裡
      debugPrint('推播註冊失敗（不影響其他功能）: $e');
    }
  }

  /// 登出時呼叫：請後端別再推到這支手機（只清這支手機，不影響同帳號在別支手機的登入）
  static Future<void> unregister(int userId) async {
    if (kIsWeb) return;
    final token = _registeredToken;
    _registeredUserId = null;
    _registeredToken = null;
    _pending = null;
    if (token == null) return;
    await ApiClient.registerPushToken(userId: userId, token: token, logout: true);
  }

  /// 首頁載入完呼叫：從通知點進來、當時還沒登入的，現在打開
  static void openPending() {
    final data = _pending;
    if (data == null) return;
    _pending = null;
    _navigate(data);
  }

  static Future<void> _send(int userId, String token) async {
    final ok = await ApiClient.registerPushToken(userId: userId, token: token);
    if (ok) {
      _registeredUserId = userId;
      _registeredToken = token;
    }
  }

  static void _showWhileOpen(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    NotificationService.showClassroomNotification(
      title: n.title ?? '',
      body: n.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  static void _open(Map<String, dynamic> data) {
    final context = _navigatorKey?.currentContext;
    final loggedIn = context != null && context.read<UserProvider>().userId != null;
    if (!loggedIn) {
      _pending = data;
      return;
    }
    _navigate(data);
  }

  /// data 由後端 utils/push.py 決定：type 是 assignment（新作業、批改完成、截止提醒）或 announcement
  static void _navigate(Map<String, dynamic> data) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    switch (data['type']?.toString()) {
      case 'assignment':
        final id = int.tryParse('${data['assignment_id']}');
        if (id == null) return;
        nav.push(MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignmentId: id)));
        break;
      case 'announcement':
        final id = int.tryParse('${data['classroom_id']}');
        if (id == null) return;
        nav.push(MaterialPageRoute(
          builder: (_) => ClassroomAnnouncementScreen(
            classroomId: id,
            classroomName: data['classroom_name']?.toString() ?? '班級公告',
          ),
        ));
        break;
    }
  }

  static Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final v = jsonDecode(payload);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null; // 每日學習提醒等其他通知沒有 JSON payload
    }
  }
}
