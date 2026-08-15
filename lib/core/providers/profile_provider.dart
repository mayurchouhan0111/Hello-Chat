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

final userProfileCacheProvider = StateProvider<Map<String, UserModel>>((ref) => {});

final cachedUserProfileProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  final cache = ref.read(userProfileCacheProvider);
  if (cache.containsKey(uid)) return cache[uid];

  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (!doc.exists) return null;

  final user = UserModel.fromMap(Map<String, dynamic>.from(doc.data()!));
  ref.read(userProfileCacheProvider.notifier).update((state) => {...state, uid: user});
  return user;
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

final rocketSettingsProvider = StreamProvider<List<int>>((ref) {
  return FirebaseFirestore.instance
      .collection('system_configs')
      .doc('rocket_settings')
      .snapshots()
      .map((snap) {
        final defaultTargets = [1000000, 2000000, 3000000, 5000000, 10000000];
        final data = snap.data();
        if (data == null || data['targets'] == null) return defaultTargets;
        final list = (data['targets'] as List<dynamic>).map((e) => (e as num).toInt()).toList();
        if (list.length == 5) return list;
        return defaultTargets;
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
      'isEquipped': category == 'frame' ? (user.profileFrame.isEmpty || user.profileFrame == 'none') : 
                    (category == 'bubble' ? (user.chatBubble.isEmpty || user.chatBubble == 'none') : 
                    (category == 'mount' ? (user.entryAnimation.isEmpty || user.entryAnimation == 'none') : false)),
      'expiryDate': 'Permanent'
    });

    // 2. Inject VIP Packages if applicable
    final bool isVipActive = user.vipTier != null && user.vipTier != 'none' && user.vipExpiry != null && user.vipExpiry!.isAfter(DateTime.now());
    final String vipExpiryStr = isVipActive 
        ? '${user.vipExpiry!.difference(DateTime.now()).inDays.clamp(1, 30)} Days' 
        : '30 Days';

    if (category == 'frame') {
      for (int i = 1; i <= 8; i++) {
        String frameUrl = '';
        if (i == 1) frameUrl = 'assets/VIP/VIP 1/Frame.svga';
        else if (i == 2) frameUrl = 'assets/VIP/VIP 2/VIP 2/Frame.svga';
        else if (i == 3) frameUrl = 'assets/VIP/VIP 3/VIP 3/Frame.svga';
        else if (i == 4) frameUrl = 'assets/VIP/VIP 4/VIP 4/Frame.svga';
        else if (i == 5) frameUrl = 'assets/VIP/VIP 5/VIP 5/User Frame.svga';
        else if (i == 6) frameUrl = 'assets/VIP/VIP 6/VIP 6/User Frame.svga';
        else if (i == 7) frameUrl = 'assets/VIP/VIP 7/VIP 7/Frame.svga';
        else if (i == 8) frameUrl = 'assets/VIP/VIP 8/VIP 8/User Frame.svga';

        specialItems.add({
          'id': 'vip_frame_$i',
          'name': 'VIP $i Frame',
          'type': 'VIP Package',
          'imageUrl': frameUrl,
          'category': 'frame',
          'isEquipped': user.profileFrame == frameUrl,
          'expiryDate': vipExpiryStr,
        });
      }
    } else if (category == 'mount') {
      for (int i = 1; i <= 8; i++) {
        String entryUrl = '';
        if (i == 1) entryUrl = 'assets/VIP/VIP 1/Entry.svga';
        else if (i == 2) entryUrl = 'assets/VIP/VIP 2/VIP 2/Entry.svga';
        else if (i == 3) entryUrl = 'assets/VIP/VIP 3/VIP 3/Entry.svga';
        else if (i == 4) entryUrl = 'assets/VIP/VIP 4/VIP 4/Entry.svga';
        else if (i == 5) entryUrl = 'assets/VIP/VIP 5/VIP 5/Entry.svga';
        else if (i == 6) entryUrl = 'assets/VIP/VIP 6/VIP 6/VIP 6 Entry.svga';
        else if (i == 7) entryUrl = 'assets/VIP/VIP 7/VIP 7/Entry.svga';
        else if (i == 8) entryUrl = 'assets/VIP/VIP 8/VIP 8/VIP 8 Entry Effect.svga';

        specialItems.add({
          'id': 'vip_entry_$i',
          'name': 'VIP $i Entry',
          'type': 'VIP Package',
          'imageUrl': entryUrl,
          'category': 'mount',
          'isEquipped': user.entryAnimation == entryUrl,
          'expiryDate': vipExpiryStr,
        });
      }
    } else if (category == 'bubble') {
      for (int i = 1; i <= 8; i++) {
        String bubbleUrl = i == 1 
            ? 'assets/VIP/VIP 1/Chat Bubble.png' 
            : 'assets/VIP/VIP $i/VIP $i/Chat Bubble.png';

        specialItems.add({
          'id': 'vip_bubble_$i',
          'name': 'VIP $i Bubble',
          'type': 'VIP Package',
          'imageUrl': bubbleUrl,
          'category': 'bubble',
          'isEquipped': user.chatBubble == bubbleUrl,
          'expiryDate': vipExpiryStr,
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
      .collection('sender_rankings')
      .doc('total')
      .collection('overall')
      .orderBy('amount', descending: true)
      .limit(3)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => ({...doc.data(), 'uid': doc.id})).toList());
});

String _getIsoWeekKey(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day);
  final dayNum = utc.weekday;
  final d = utc.add(Duration(days: 4 - dayNum));
  final yearStart = DateTime.utc(d.year, 1, 1);
  final weekNo = ((d.difference(yearStart).inDays) / 7).floor() + 1;
  return "${d.year}-W${weekNo.toString().padLeft(2, '0')}";
}

final userSenderRankingsProvider = StreamProvider.family<List<Map<String, dynamic>>, ({String targetUid, String period})>((ref, arg) {
  if (arg.targetUid.isEmpty) return Stream.value([]);

  final now = DateTime.now().toUtc();
  String bucket = 'overall';
  if (arg.period == 'daily') {
    bucket = now.toIso8601String().substring(0, 10);
  } else if (arg.period == 'weekly') {
    bucket = _getIsoWeekKey(now);
  } else if (arg.period == 'monthly') {
    bucket = now.toIso8601String().substring(0, 7);
  } else {
    bucket = 'overall';
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(arg.targetUid)
      .collection('sender_rankings')
      .doc(arg.period)
      .collection(bucket)
      .orderBy('amount', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
        final docs = snapshot.docs;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

        List<Map<String, dynamic>> results = [];
        for (var doc in docs) {
          final data = doc.data();
          
          // 🛡️ Inactive Sender Rule: Filter out senders who haven't sent gifts to this target user ID in 30 consecutive days
          final updatedAt = data['updatedAt'];
          if (updatedAt != null && updatedAt is Timestamp) {
            final updatedMs = updatedAt.toDate().millisecondsSinceEpoch;
            if ((nowMs - updatedMs) > thirtyDaysMs) {
              continue; // Exclude inactive sender
            }
          }

          results.add({
            ...data,
            'senderUid': doc.id,
          });
        }
        return results;
      });
});
