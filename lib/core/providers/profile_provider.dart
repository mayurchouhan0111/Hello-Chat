import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

final userProfileProvider = StreamProvider.family<dynamic, String>((ref, uid) {
  return ref.watch(profileServiceProvider).getProfileStream(uid);
});

final currentUserProfileProvider = StreamProvider<dynamic>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(profileServiceProvider).getProfileStream(uid);
});

final followersStreamProvider = StreamProvider.family<List<String>, String>((ref, uid) {
  return ref.watch(profileServiceProvider).getFollowersStream(uid);
});

final followingStreamProvider = StreamProvider.family<List<String>, String>((ref, uid) {
  return ref.watch(profileServiceProvider).getFollowingStream(uid);
});

final momentsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(profileServiceProvider).getMomentsStream();
});

final userMediaStoreProvider = StreamProvider.family<List<Map<String, dynamic>>, ({String uid, String? tag})>((ref, arg) {
  return ref.watch(profileServiceProvider).getUserMediaStream(arg.uid, tag: arg.tag);
});

final isMediaLikedProvider = StreamProvider.family<bool, ({String ownerUid, String mediaId, String likerUid})>((ref, arg) {
  return FirebaseFirestore.instance
    .collection('users')
    .doc(arg.ownerUid)
    .collection('media')
    .doc(arg.mediaId)
    .collection('likes')
    .doc(arg.likerUid)
    .snapshots()
    .map((snapshot) => snapshot.exists);
});

final commentsStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, ({String ownerUid, String mediaId})>((ref, arg) {
  return ref.watch(profileServiceProvider).getCommentsStream(arg.ownerUid, arg.mediaId);
});

final mediaStreamProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, mediaId) {
  return ref.watch(profileServiceProvider).getMomentStream(mediaId);
});
