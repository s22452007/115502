import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    await _googleSignIn.initialize();
    _initialized = true;
  }

  static Future<UserCredential> signInWithGoogle() async {
    await _ensureInitialized();

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return FirebaseAuth.instance.signInWithPopup(provider);
    }

    if (!_googleSignIn.supportsAuthenticate()) {
      throw FirebaseAuthException(
        code: 'google-sign-in-not-supported',
        message: '目前平台不支援 Google 登入',
      );
    }

    final GoogleSignInAccount googleUser =
        await _googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();

    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}