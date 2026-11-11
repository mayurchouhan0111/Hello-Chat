import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // 1. Phone Auth
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // 2. Email Login/Register
  Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> loginWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // 3. Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // 4. Facebook Sign In
  Future<UserCredential?> signInWithFacebook() async {
    final LoginResult result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.success) {
      final AuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.token);
      return await _auth.signInWithCredential(credential);
    }
    return null;
  }

  // 4. Sign in with Credential (used for Phone & Social)
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  // 5. Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // 6. Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint("Firebase SignOut Error: $e");
    }
    
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }

  // 7. Update Password (must be logged in)
  Future<void> updatePassword(String newPassword) async {
    await setupPasswordForUser(newPassword);
  }

  // 8. Phone normalizer & phone-to-email utility
  static String normalizePhone(String phone, {String countryCode = '880'}) {
    String clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.startsWith('+')) {
      return clean;
    }
    // Strip leading zeros (e.g., 01712345678 -> 1712345678)
    clean = clean.replaceFirst(RegExp(r'^0+'), '');
    final code = countryCode.replaceAll('+', '');
    // If number already contains the country code digits without '+'
    if (clean.startsWith(code) && clean.length > code.length + 6) {
      return '+$clean';
    }
    return '+$code$clean';
  }

  static String phoneToEmail(String phone) {
    final clean = normalizePhone(phone);
    return '$clean@phone.hellochat.app';
  }

  // 9. Login with Phone and Password (no OTP needed for returning users)
  Future<UserCredential> loginWithPhonePassword(String phone, String password) async {
    final email = phoneToEmail(phone);
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // 10. Securely link or set password for current user
  Future<void> setupPasswordForUser(String password, {String? phone}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No authenticated user");

    final targetPhone = (phone != null && phone.isNotEmpty) ? phone : user.phoneNumber;
    if (targetPhone != null && targetPhone.isNotEmpty) {
      final email = phoneToEmail(targetPhone);
      try {
        final credential = EmailAuthProvider.credential(email: email, password: password);
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') {
          await user.updatePassword(password);
        } else if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          try {
            await user.updatePassword(password);
          } catch (_) {
            rethrow;
          }
        } else {
          try {
            await user.updatePassword(password);
          } catch (_) {
            rethrow;
          }
        }
      } catch (_) {
        await user.updatePassword(password);
      }
      try {
        await _db.collection('users').doc(user.uid).set({
          'hasPassword': true,
          'phoneEmail': email,
          'phoneNumber': normalizePhone(targetPhone),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (dbErr) {
        debugPrint("Error writing hasPassword flag to firestore: $dbErr");
      }
    } else {
      await user.updatePassword(password);
      try {
        await _db.collection('users').doc(user.uid).set({
          'hasPassword': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}
