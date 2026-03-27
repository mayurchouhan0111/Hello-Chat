import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_provider.dart';

enum MomentFilter { square, following }

final momentFilterProvider = StateProvider<MomentFilter>((ref) => MomentFilter.square);

final filteredMomentsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final filter = ref.watch(momentFilterProvider);
  final db = FirebaseFirestore.instance;
  
  if (filter == MomentFilter.square) {
    return ref.watch(momentsStreamProvider.stream);
  }

  // Following tab
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  return ref.watch(followingStreamProvider(uid)).when(
    data: (followingList) {
      if (followingList.isEmpty) return Stream.value([]);
      
      // Limit to 30 for Firestore whereIn limit (actually 10/30 depending on SDK)
      final limitedList = followingList.take(30).toList();
      
      return db.collection('moments')
          .where('userId', whereIn: limitedList)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    },
    loading: () => const Stream.empty(),
    error: (e, __) => Stream.value([]),
  );
});
