import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static bool _googleInitialized = false;

  static const _webClientId =
      '287078122278-cg12o15ki1762dsntie91mdphvrerf71.apps.googleusercontent.com';

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _webClientId,
    );
    _googleInitialized = true;
  }

  /// [hostedDomain]：校園教育版選好學校後傳學校網域，網頁版的 Google 帳號選單只列這個網域的帳號；真正擋人靠後端檢查 Email 網域。
  /// [schoolAccount]：學校 Workspace 帳號存在手機上的登入狀態會過期，手機帳號選單會失敗（[16] Account reauth failed），
  /// 這時改走 Firebase 瀏覽器登入，讓學生在 Google 頁面上重新輸入密碼／兩步驟驗證。
  Future<UserCredential> signInWithGoogle({
    String? hostedDomain,
    bool schoolAccount = false,
  }) async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.setCustomParameters({
      'prompt': 'select_account',
      if (hostedDomain != null && hostedDomain.isNotEmpty) 'hd': hostedDomain,
    });

    if (kIsWeb) {
      return await FirebaseAuth.instance.signInWithPopup(googleProvider);
    }

    // Android / iOS
    try {
      return await _signInWithDeviceAccount();
    } on GoogleSignInException catch (e) {
      final needsReauth = (e.description ?? '').toLowerCase().contains('reauth');
      // 一般版、或使用者自己按取消，照原本丟出去
      if (!schoolAccount || !needsReauth) rethrow;
    }
    return await FirebaseAuth.instance.signInWithProvider(googleProvider);
  }

  Future<UserCredential> _signInWithDeviceAccount() async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOutGoogle() async {
    if (!kIsWeb) {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    }
    await FirebaseAuth.instance.signOut();
  }
}


