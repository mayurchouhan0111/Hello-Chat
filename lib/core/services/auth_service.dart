import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  static String normalizePhone(String phone, {String? countryCode}) {
    String clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.startsWith('+')) {
      return clean;
    }
    // Strip leading zeros (e.g., 01712345678 -> 1712345678)
    clean = clean.replaceFirst(RegExp(r'^0+'), '');

    // Recognize complete international numbers before applying a local default.
    if ((clean.length == 13 && clean.startsWith('8801')) ||
        (clean.length == 12 && clean.startsWith('91'))) {
      return '+$clean';
    }

    // Smart country code resolution:
    String resolvedCode;
    if (countryCode != null && countryCode.isNotEmpty) {
      resolvedCode = countryCode.replaceAll('+', '');
    } else {
      // 10 digits starting with 6, 7, 8, 9 is an Indian mobile number
      if (clean.length == 10 && RegExp(r'^[6-9]').hasMatch(clean)) {
        resolvedCode = '91';
      } else if (clean.length == 10 && clean.startsWith('1')) {
        resolvedCode = '880';
      } else {
        resolvedCode = '91'; // Project primary region default
      }
    }

    // If number already contains the country code digits without '+'
    if (clean.startsWith(resolvedCode) && clean.length > resolvedCode.length + 6) {
      return '+$clean';
    }
    return '+$resolvedCode$clean';
  }

  static String phoneToEmail(String phone, {String? countryCode}) {
    final clean = normalizePhone(phone, countryCode: countryCode);
    return '$clean@phone.hellochat.app';
  }

  // 9. Login with Phone and Password (no OTP needed for returning users)
  Future<UserCredential> loginWithPhonePassword(String phone, String password) async {
    final email = phoneToEmail(phone);
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // 10. Securely set password: server-side consolidation ensures the password ALWAYS
  // lands on the one account that owns the phone identity, so phone+password login
  // can never open a different (possibly empty) account.
  Future<void> setupPasswordForUser(String password, {String? phone}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No authenticated user");

    final targetPhone = (phone != null && phone.isNotEmpty) ? phone : user.phoneNumber;
    if (targetPhone == null || targetPhone.isEmpty) {
      // Email-only account: password attaches to the currently signed-in account.
      await user.updatePassword(password);
      try {
        await _db.collection('users').doc(user.uid).set({
          'hasPassword': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
      return;
    }

    final normalizedPhone = normalizePhone(targetPhone);
    final callable = FirebaseFunctions.instance.httpsCallable('ensurePhonePassword');
    final result = await callable.call({
      'phone': normalizedPhone,
      'password': password,
    });
    final data = (result.data as Map?)?.cast<String, dynamic>() ?? const {};
    final survivorUid = data['uid'] as String?;
    final survivorEmail = (data['email'] as String?) ?? phoneToEmail(normalizedPhone);

    // If our session was on a duplicate identity that got consolidated away,
    // re-authenticate into the surviving account with the brand-new credentials.
    if (survivorUid != null && survivorUid != user.uid) {
      await _auth.signOut();
      await _auth.signInWithEmailAndPassword(email: survivorEmail, password: password);
    }
  }
}
