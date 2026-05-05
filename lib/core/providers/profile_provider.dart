import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/services/profile_service.dart';
import 'package:hello_chat/core/models/transaction_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/vip_provider.dart';

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

final adminFramesProvider = StreamProvider<Map<String, String>>((ref) {
  return FirebaseFirestore.instance
      .collection('system_configs')
      .doc('admin_frames')
      .snapshots()
      .map((snap) {
        final data = snap.data();
        if (data == null || data['frames'] == null) return {};
        return Map<String, String>.from(data['frames']);
      });
});

final warehouseItemsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, category) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return Stream.value([]);
  
  final vaultStream = ref.watch(profileServiceProvider).getWarehouseItemsStream(uid, category);
  
  // Inject special items (VIP, Admin, None)
  final userAsync = ref.watch(currentUserProfileProvider);
  final vipTiersAsync = ref.watch(vipTiersProvider);
  final adminFramesAsync = ref.watch(adminFramesProvider);
  
  return vaultStream.map((items) {
    final user = userAsync.value;
    if (user == null) return items;

    List<Map<String, dynamic>> specialItems = [];
    final adminFrames = adminFramesAsync.value ?? {};
    
    // 1. Always Inject "None" option (except for basic items if not needed)
    specialItems.add({
      'id': 'none',
      'name': 'Default ${category.toUpperCase()}',
      'type': 'Standard',
      'imageUrl': 'https://i.ibb.co/vz6G3H1/vip1-frame.png', 
      'category': category,
      'isEquipped': category == 'frame' ? user.profileFrame.isEmpty : 
                    (category == 'bubble' ? user.chatBubble.isEmpty : 
                    (category == 'mount' ? user.entryAnimation.isEmpty : false)),
      'expiryDate': 'Permanent'
    });

    // 2. Inject VIP Frame if category is 'frame'
    if (category == 'frame' && user.vipTier != 'none') {
      final tiers = vipTiersAsync.value;
      final myTier = tiers?.where((t) => t.tierId == user.vipTier || t.name == user.vipTier).firstOrNull;
      if (myTier != null && myTier.profileFrame.isNotEmpty) {
        specialItems.add({
          'id': 'vip_reward_frame', 
          'name': '${myTier.name} VIP Frame',
          'type': 'VIP Reward',
          'imageUrl': myTier.profileFrame,
          'category': 'frame',
          'isEquipped': user.profileFrame.isEmpty || user.profileFrame == myTier.profileFrame,
          'expiryDate': 'While VIP'
        });
      }
    }
    
    // 3. Inject Admin frames for 'frame' category (Using Network URLs)
    if (category == 'frame' && user.tags.isNotEmpty) {
      if (user.tags.contains('SuperAdmin') && adminFrames.containsKey('super-admin')) {
        specialItems.add({
          'id': 'official_superadmin_frame',
          'name': 'SuperAdmin Frame',
          'type': 'Official Staff',
          'imageUrl': adminFrames['super-admin']!,
          'category': 'frame',
          'isEquipped': user.profileFrame == adminFrames['super-admin'],
          'expiryDate': 'Permanent'
        });
      }
      if (user.tags.contains('Admin') && adminFrames.containsKey('admin')) {
        specialItems.add({
          'id': 'official_admin_frame',
          'name': 'Admin Frame',
          'type': 'Official Staff',
          'imageUrl': adminFrames['admin']!,
          'category': 'frame',
          'isEquipped': user.profileFrame == adminFrames['admin'],
          'expiryDate': 'Permanent'
        });
      }
      if (user.tags.contains('Reseller') && adminFrames.containsKey('reseller')) {
        specialItems.add({
          'id': 'official_reseller_frame',
          'name': 'Reseller Frame',
          'type': 'Official Partner',
          'imageUrl': adminFrames['reseller']!,
          'category': 'frame',
          'isEquipped': user.profileFrame == adminFrames['reseller'],
          'expiryDate': 'Permanent'
        });
      }
    }
    
    return [...specialItems, ...items];
  });
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
