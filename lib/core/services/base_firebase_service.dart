import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

mixin class BaseFirebaseService {
  // ⚡ Using default instance to match other services and avoid App Check / regional mismatches
  FirebaseFunctions get _functions => FirebaseFunctions.instance;

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

    // 🔑 Diagnostic: Check if we can actually get a valid token (cached to prevent latency)
    if (kDebugMode) {
      try {
        final token = await user.getIdToken(false);
        if (token == null || token.isEmpty) {
          debugPrint('⚠️ [BaseFirebaseService] User is logged in but ID Token is empty!');
        }
      } catch (e) {
        debugPrint('🛑 [BaseFirebaseService] Failed to fetch ID Token: $e');
      }
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

  Map<String, dynamic> castMap(dynamic data) {
    if (data == null) return {};
    final map = data as Map;
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), castMap(value));
      } else if (value is List) {
        return MapEntry(key.toString(), value.map((e) => e is Map ? castMap(e) : e).toList());
      }
      return MapEntry(key.toString(), value);
    });
  }
}
