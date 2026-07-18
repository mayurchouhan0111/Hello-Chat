import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/user_model.dart';
import '../core/models/transaction_model.dart';
import '../core/providers/auth_provider.dart';

// 1. Transactions Stream Provider
final walletTransactionsProvider = StreamProvider.autoDispose<List<WalletTransaction>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .orderBy('timestamp', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => WalletTransaction.fromMap(doc.data(), doc.id)).toList());
});

// 2. Wallet Balance Stream (extracted from user document)
final walletBalanceProvider = StreamProvider.autoDispose<Map<String, int>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value({'diamonds': 0, 'beans': 0});

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) {
        if (!snap.exists) return {'diamonds': 0, 'beans': 0};
        final data = snap.data()!;
        return {
          'diamonds': data['diamondBalance'] ?? 0,
          'beans': data['beansBalance'] ?? 0,
        };
      });
});

// 3. Wallet Repository/Notifier using Cloud Functions
class WalletNotifier extends StateNotifier<AsyncValue<void>> {
  WalletNotifier(this.ref) : super(const AsyncValue.data(null));
  final Ref ref;

  Future<void> simulateRecharge(int amount) async {
    throw Exception("Simulated recharges are disabled. Payments must be routed through verified, production-ready payment gateways.");
  }

  Future<void> simulateBeansRecharge(int amount) async {
    throw Exception("Simulated recharges are disabled. Payments must be routed through verified, production-ready payment gateways.");
  }
}

final walletActionProvider = StateNotifierProvider<WalletNotifier, AsyncValue<void>>((ref) {
  return WalletNotifier(ref);
});
