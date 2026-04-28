import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/services/profile_service.dart';
import 'package:hello_chat/core/models/transaction_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

final userProfileProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(profileServiceProvider).getProfileStream(uid);
});

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
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
final transactionStreamProvider = StreamProvider<List<WalletTransaction>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => WalletTransaction.fromMap(doc.data(), doc.id))
          .toList());
});

final cpInvitesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(profileServiceProvider).getCPInvitesStream(uid);
});

final warehouseItemsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, category) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(profileServiceProvider).getWarehouseItemsStream(uid, category);
});

final prestigeItemsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(profileServiceProvider).getPrestigeItemsStream();
});

final friendsStreamProvider = StreamProvider.family<List<String>, String>((ref, uid) {
  return ref.watch(profileServiceProvider).getFriendsStream(uid);
});

final familyRoomsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, familyId) {
  return ref.watch(profileServiceProvider).getFamilyRoomsStream(familyId);
});

final topContributorsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, targetUid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(targetUid)
      .collection('contributors')
      .orderBy('amount', descending: true)
      .limit(3)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => ({...doc.data(), 'uid': doc.id})).toList());
});
