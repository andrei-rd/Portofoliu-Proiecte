import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'database_service.dart';
import '../utils/firebase_error_handler.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final DatabaseService _db;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    DatabaseService? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          serverClientId: '208306661715-mtm238hkdrh5qs37dg4qdo7sdfcfhrpq.apps.googleusercontent.com',
        ),
        _db = db ?? DatabaseService();

  // Auth state stream
  Stream<User?> get userStatus => _auth.authStateChanges();

  // Register with email & password
  Future<User?> registerWithEmailPassword(
      String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await _db.saveUserData(
          uid: user.uid,
          email: email,
          displayName: name,
        );
      }
      return user;
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      if (kDebugMode) {
        print("Auth Error (Register): ${appException.code}");
      }
      throw appException;
    }
  }

  // Sign in with email & password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      if (kDebugMode) {
        print("Auth Error (Login): ${appException.code}");
      }
      throw appException;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        await _db.saveUserData(
          uid: user.uid,
          email: user.email ?? "",
          displayName: user.displayName,
          photoURL: user.photoURL,
        );
      }
      return user;
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      if (kDebugMode) {
        print("Auth Error (Google): ${appException.code} - ${appException.message}");
      }
      throw appException;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print("Auth Error (Logout): ${e.toString()}");
      }
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      if (kDebugMode) {
        print("Auth Error (Reset): ${appException.code}");
      }
      throw appException;
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw FirebaseErrorHandler.handle(e);
    }
  }

  // Phone Verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    // Dezactivăm setările de test pentru a permite SMS-uri REALE
    // Notă: În Debug mode, Firebase va folosi reCAPTCHA (browser) dacă nu e în Play Store
    await _auth.setSettings(appVerificationDisabledForTesting: false);

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> linkPhoneNumber(PhoneAuthCredential credential) async {
    try {
      await _auth.currentUser?.linkWithCredential(credential);
    } catch (e) {
      throw FirebaseErrorHandler.handle(e);
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      throw appException;
    }
  }

  // Reauthenticate user
  Future<void> reauthenticate(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      throw appException;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } catch (e) {
      final appException = FirebaseErrorHandler.handle(e);
      throw appException;
    }
  }
}
