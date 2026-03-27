import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';

enum RoomFilter { following, popular, recommended }

final roomFilterProvider = StateProvider<RoomFilter>((ref) => RoomFilter.popular);

final filteredRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final filter = ref.watch(roomFilterProvider);
  final db = FirebaseFirestore.instance;
  
  Query query = db.collection('rooms').where('status', isEqualTo: 'active');

  switch (filter) {
    case RoomFilter.popular:
      // Sort by viewers
      query = query.orderBy('currentUsersCount', descending: true);
      break;
    case RoomFilter.recommended:
      // Sort by newest for now
      query = query.orderBy('createdAt', descending: true);
      break;
    case RoomFilter.following:
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return const Stream.empty();
      
      return ref.watch(followingStreamProvider(uid)).when(
        data: (followingList) {
          if (followingList.isEmpty) return Stream.value([]);
          
          final limitedList = followingList.take(30).toList();
          return db.collection('rooms')
              .where('status', isEqualTo: 'active')
              .where('ownerUid', whereIn: limitedList)
              .snapshots()
              .map((snapshot) => snapshot.docs.map((doc) => RoomModel.fromMap(doc.data() as Map<String, dynamic>)).toList());
        },
        loading: () => const Stream.empty(),
        error: (e, __) => Stream.value([]),
      );
  }

  return query.snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => RoomModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  });
});
