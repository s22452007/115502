import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jpn_learning_app/utils/auth_http.dart';

void main() {
  const host = 'http://127.0.0.1:5050';
  late List<http.Request> sent;
  late List<String> kicked;

  /// 建立一個模擬後端：依 handler 回應，並記下每個送出的請求
  AuthHttpClient clientWith(http.Response Function(http.Request) handler) {
    return AuthHttpClient(() => host, inner: MockClient((req) async {
      sent.add(req);
      return handler(req);
    }));
  }

  setUp(() {
    sent = [];
    kicked = [];
    AuthSession.token = null;
    AuthSession.onUnauthorized = (msg) => kicked.add(msg);
  });

  group('登入通行證連線', () {
    test('呼叫自家後端時帶上通行證，打其他網址不帶', () async {
      AuthSession.token = 'T1';
      final client = clientWith((_) => http.Response('{}', 200));

      await client.get(Uri.parse('$host/api/user/profile_data/5'));
      await client.get(Uri.parse('https://example.com/image.jpg'));

      expect(sent[0].headers['Authorization'], 'Bearer T1');
      expect(sent[1].headers.containsKey('Authorization'), isFalse);
    });

    test('回應附上新的通行證時自動換上（有在使用就不會過期）', () async {
      AuthSession.token = 'OLD';
      final client = clientWith((_) => http.Response('{}', 200, headers: {'x-auth-token': 'NEW'}));

      await client.get(Uri.parse('$host/api/user/profile_data/5'));

      expect(AuthSession.token, 'NEW');
    });

    test('通行證失效（401）時清掉通行證並通知登出', () async {
      AuthSession.token = 'T1';
      final client = clientWith((_) => http.Response('{}', 401,
          headers: {'x-auth-error': 'token_revoked'}));

      await client.get(Uri.parse('$host/api/user/profile_data/5'));

      expect(AuthSession.token, isNull);
      expect(kicked, ['登入已失效，請重新登入']);
    });

    test('帳號被停用（403 suspended）時也會登出，一般的 403 不會', () async {
      AuthSession.token = 'T1';
      final forbidden = clientWith((_) => http.Response('{}', 403, headers: {'x-auth-error': 'forbidden'}));
      await forbidden.get(Uri.parse('$host/api/user/transactions/6'));
      expect(kicked, isEmpty);
      expect(AuthSession.token, 'T1');

      final suspended = clientWith((_) => http.Response('{}', 403, headers: {'x-auth-error': 'suspended'}));
      await suspended.get(Uri.parse('$host/api/user/profile_data/5'));
      expect(kicked, ['此帳號已被停用，請聯繫客服']);
      expect(AuthSession.token, isNull);
    });

    test('沒帶通行證收到 401 也會通知（是不是訪客由 main.dart 判斷，訪客不跳畫面）', () async {
      final client = clientWith((_) => http.Response('{}', 401));

      final res = await client.get(Uri.parse('$host/api/user/profile_data/5'));

      expect(res.statusCode, 401);
      expect(sent.single.headers.containsKey('Authorization'), isFalse);
      expect(kicked, ['登入已失效，請重新登入']);
    });

    test('等回應期間已經重新登入換了新通行證，舊請求的失敗不會把人登出', () async {
      AuthSession.token = 'OLD';
      final client = clientWith((_) {
        AuthSession.token = 'NEW';   // 模擬回應回來前使用者已重新登入
        return http.Response('{}', 401);
      });

      await client.get(Uri.parse('$host/api/user/profile_data/5'));

      expect(AuthSession.token, 'NEW');
      expect(kicked, isEmpty);
    });
  });
}
