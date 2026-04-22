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
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in.");

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception("User not found.");

        transaction.update(userRef, {
          'diamondBalance': FieldValue.increment(amount),
        });

        // Add Transaction Log
        final txRef = userRef.collection('transactions').doc();
        transaction.set(txRef, {
          'type': 'recharge',
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'description': "Diamonds Recharge (Simulation)",
          'status': 'completed',
        });
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> simulateBeansRecharge(int amount) async {
    state = const AsyncValue.loading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in.");

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception("User not found.");

        transaction.update(userRef, {
          'beansBalance': FieldValue.increment(amount),
        });

        // Add Transaction Log
        final txRef = userRef.collection('transactions').doc();
        transaction.set(txRef, {
          'type': 'beans_recharge',
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'description': "Beans Recharge (Simulation)",
          'status': 'completed',
        });
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final walletActionProvider = StateNotifierProvider<WalletNotifier, AsyncValue<void>>((ref) {
  return WalletNotifier(ref);
});
