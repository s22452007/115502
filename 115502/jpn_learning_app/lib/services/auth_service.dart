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

  /// [hostedDomain]：校園教育版選好學校後傳學校網域，網頁版的 Google 帳號選單只列這個網域的帳號。
  /// 手機版的 GoogleSignIn 只能初始化一次、不能每次換網域，所以不篩；真正擋人靠後端檢查 Email 網域。
  Future<UserCredential> signInWithGoogle({String? hostedDomain}) async {
    if (kIsWeb) {
      // Web: 用 Firebase popup
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      googleProvider.addScope('email');
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        if (hostedDomain != null && hostedDomain.isNotEmpty) 'hd': hostedDomain,
      });

      return await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } else {
      // Android / iOS
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
  }

  Future<void> signOutGoogle() async {
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
    await FirebaseAuth.instance.signOut();
  }
}


