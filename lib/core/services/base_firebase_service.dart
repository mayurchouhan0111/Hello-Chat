import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

mixin class BaseFirebaseService {
  // ⚡ Explicit region selection to avoid regional mismatches (matching backend)
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<dynamic> callFunction(String name, [Map<String, dynamic>? data]) async {
    // 🛡️ Debug Auth State
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('🛑 [BaseFirebaseService] Cannot call $name: User is not authenticated in Firebase Auth.');
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'You must be logged in to perform this action.',
      );
    }

    // 🔑 Diagnostic: Check if we can actually get a valid token
    try {
      final token = await user.getIdToken(true); // Force refresh to be sure
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ [BaseFirebaseService] User is logged in but ID Token is empty!');
      } else {
        debugPrint('✅ [BaseFirebaseService] ID Token refresh successful for ${user.uid.substring(0, 5)}...');
      }
    } catch (e) {
      debugPrint('🛑 [BaseFirebaseService] Failed to fetch ID Token: $e');
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call(data);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('🛑 Firebase Functions Error [$name]: [${e.code}] ${e.message}');
      debugPrint('   Details: ${e.details}');
      rethrow;
    } catch (e) {
      debugPrint('🛑 Unexpected Error calling function $name: $e');
      throw Exception("Failed to call function $name: $e");
    }
  }
}
