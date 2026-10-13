import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// 2. Wallet Balance Stream (extracted from user document with monotonic seq)
final walletBalanceProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value({'diamonds': 0, 'beans': 0, 'seq': 0});

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) {
        if (!snap.exists) return {'diamonds': 0, 'beans': 0, 'seq': 0};
        final data = snap.data()!;
        final diamonds = (data['diamondBalance'] as num?)?.toInt() ?? (data['diamonds'] as num?)?.toInt() ?? 0;
        final beans = (data['beansBalance'] as num?)?.toInt() ?? (data['beans'] as num?)?.toInt() ?? 0;
        final seq = (data['seq'] as num?)?.toInt() ?? 0;
        final lastTxnId = data['lastTxnId'] as String?;
        return {
          'diamonds': diamonds,
          'beans': beans,
          'seq': seq,
          'lastTxnId': lastTxnId,
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
