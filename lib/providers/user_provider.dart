import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/user_model.dart';
import '../core/models/media_model.dart';
import '../core/providers/auth_provider.dart';
export '../core/providers/auth_provider.dart';

// 1. Current User Stream Provider (Live Firestore updates for current logged-in user)
final currentUserStreamProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) {
        if (!snap.exists) return null;
        return UserModel.fromMap(snap.data()!);
      });
});

// 3. User Notifier and StateProvider (For manual control/caching if needed)
class UserNotifier extends StateNotifier<UserModel?> {
  UserNotifier(this.ref) : super(null) {
    // Sync with the stream automatically
    ref.listen(currentUserStreamProvider, (previous, next) {
      if (next.hasValue) {
        state = next.value;
      }
    });
  }

  final Ref ref;

  void forceRefresh() {
    ref.invalidate(currentUserStreamProvider);
  }

  void updateLocal(UserModel user) {
    state = user;
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserModel?>((ref) {
  return UserNotifier(ref);
});

// 4. Family Provider for Moments (Live subcollection stream)
final momentsProvider = StreamProvider.family.autoDispose<List<MediaModel>, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('media')
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => MediaModel.fromMap(doc.data())).toList());
});

// 5. Global Moments Provider
final globalMomentsProvider = StreamProvider.autoDispose<List<MediaModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('moments')
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => MediaModel.fromMap(doc.data())).toList());
});
