import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_provider.dart';

enum MomentFilter { square, following }

final momentFilterProvider = StateProvider<MomentFilter>((ref) => MomentFilter.square);

final followingMomentsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  final followingAsync = ref.watch(followingStreamProvider(uid));
  
  return followingAsync.when(
    data: (followingList) {
      if (followingList.isEmpty) return Stream.value([]);
      
      // Limit to 30 for Firestore whereIn limit
      final limitedList = followingList.take(30).toList();
      
      return FirebaseFirestore.instance.collection('moments')
          .where('userId', whereIn: limitedList)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    },
    loading: () => const Stream.empty(),
    error: (e, __) => Stream.value([]),
  );
});
