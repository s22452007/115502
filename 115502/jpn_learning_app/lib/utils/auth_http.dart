import 'package:http/http.dart' as http;

/// 登入通行證（後端 utils/auth_token.py 簽發）。
///
/// 登入、註冊、Google 登入成功時後端會回傳 token，之後每次呼叫後端 API
/// 都要在 Authorization 標頭帶上，後端才知道「是誰在操作」，而且只能操作自己的資料。
/// App 關掉就要重新登入，所以通行證只放在記憶體，不存到手機。
class AuthSession {
  AuthSession._();

  static String? token;

  /// 通行證失效（過期、改了密碼、被停用）時要做的事，由 main.dart 設定：登出並回到歡迎畫面
  static void Function(String message)? onUnauthorized;

  static void clear() => token = null;
}

/// 會自動帶上通行證的連線工具。ApiClient 與各畫面直接呼叫後端時都用它（ApiClient.client）。
///
/// - 只有呼叫自家後端時才帶通行證，打其他網址（例如網頁版讀取本機圖片）不帶。
/// - 後端在通行證用超過一天時，會在回應標頭 X-Auth-Token 附上新的一張，這裡自動換上，
///   有在使用就不會過期。
/// - 後端回 401／被停用的 403 時，清掉通行證並通知 main.dart 回到登入畫面。
class AuthHttpClient extends http.BaseClient {
  /// [inner] 只有測試會傳入（模擬的連線），平常用預設的 http.Client
  AuthHttpClient(this._apiHost, {http.Client? inner}) : _inner = inner ?? http.Client();

  final String Function() _apiHost;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isOurApi = request.url.toString().startsWith(_apiHost());
    final sentToken = AuthSession.token;
    if (isOurApi && sentToken != null) {
      request.headers['Authorization'] = 'Bearer $sentToken';
    }

    final response = await _inner.send(request);

    if (isOurApi) {
      final renewed = response.headers['x-auth-token'];
      if (renewed != null && renewed.isNotEmpty) {
        AuthSession.token = renewed;
      }
      // 通行證被拒時通知 main.dart 登出。沒帶通行證卻收到 401 也要通知：App 以為已登入、
      // 記憶體裡卻沒有通行證（例如開發時 hot reload 前就登入了），否則每個畫面都只會一直載入失敗。
      // 尚未登入時由 main.dart 判斷，呼叫需要登入的 API 只會拿到錯誤，不跳畫面。
      // 等回應的期間如果已經重新登入、換了新通行證，這次的失敗就與現在的登入無關。
      final authFailed = response.statusCode == 401 ||
          (response.statusCode == 403 && response.headers['x-auth-error'] == 'suspended');
      if (authFailed && AuthSession.token == sentToken) {
        AuthSession.clear();
        AuthSession.onUnauthorized?.call(
          response.statusCode == 403 ? '此帳號已被停用，請聯繫客服' : '登入已失效，請重新登入',
        );
      }
    }
    return response;
  }

  @override
  void close() {
    // 整個 App 共用同一個連線，不在單次請求後關閉
  }
}
