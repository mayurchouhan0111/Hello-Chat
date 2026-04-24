import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/reseller_service.dart';

// Provides the transaction history for a specific reseller
final resellerHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(resellerServiceProvider).getResellerHistory(uid);
});

// Provides the list of available diamond packages for resellers
final resellerPackagesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(resellerServiceProvider).getResellerPackages();
});
