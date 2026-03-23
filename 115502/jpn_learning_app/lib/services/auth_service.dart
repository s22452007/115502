import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: 用 Firebase popup
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // 這兩行可留可不留，只是示範
      googleProvider.addScope('email');
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
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


