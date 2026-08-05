import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/cloudinary_service.dart';
import 'base_firebase_service.dart';

class ProfileService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  // Stream of user profile
  Stream<UserModel?> getProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      return UserModel.fromMap(Map<String, dynamic>.from(data as Map));
    });
  }

  // Check username availability
  Future<bool> isUsernameAvailable(String username) async {
    final result = await callFunction('checkUsernameAvailability', {'username': username});
    return (result['available'] as bool);
  }
  
  // Setup Profile (Restored 'uid' for compatibility, though function uses context)
  Future<void> setupUserProfile({
    required String username,
    required String displayName,
    required String bio,
    required String country,
    required String profilePhotoUrl,
    String? uid, // Kept to fix compilation, but internal logic uses context
  }) async {
    await callFunction('setupProfile', {
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'country': country,
      'profilePhotoUrl': profilePhotoUrl,
    });
  }

  // Follow User (Restored positional followerUid for compatibility)
  Future<void> followUser(String followerUid, String targetUid) async {
    await callFunction('followUser', {'targetUid': targetUid});
  }

  // Unfollow User (Restored positional followerUid for compatibility)
  Future<void> unfollowUser(String followerUid, String targetUid) async {
    await callFunction('unfollowUser', {'targetUid': targetUid});
  }
  // Toggle Follow
  Future<void> toggleFollow(String followerUid, String targetUid) async {
    final following = await getFollowingStream(followerUid).first;
    if (following.contains(targetUid)) {
      await unfollowUser(followerUid, targetUid);
    } else {
      await followUser(followerUid, targetUid);
    }
  }

  // Update existing Profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? country,
    String? profilePhotoUrl,
    String? status,
    String? gender,
    DateTime? birthday,
    String? height,
    String? weight,
    String? hometown,
    List<String>? languages,
    String? ethnicity,
    String? personalLabel,
    String? company,
  }) async {
    final Map<String, dynamic> updates = {
      if (displayName != null) 'displayName': displayName,
      if (displayName != null) 'displayName_lowercase': displayName.toLowerCase(),
      if (bio != null) 'bio': bio,
      if (country != null) 'country': country,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (status != null) 'status': status,
      if (gender != null) 'gender': gender,
      if (birthday != null) 'birthday': birthday,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (hometown != null) 'hometown': hometown,
      if (languages != null) 'languages': languages,
      if (ethnicity != null) 'ethnicity': ethnicity,
      if (personalLabel != null) 'personalLabel': personalLabel,
      if (company != null) 'company': company,
      'lastActive': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(uid).update(updates);
  }

  // Generic Update for Metadata/KYC
  Future<void> updateProfileFields(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // Update User Location
  Future<void> updateUserLocation(String uid, String country) async {
    await _db.collection('users').doc(uid).update({
      'country': country,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }
  
  // Record Profile Visit
  Future<void> recordProfileVisit(String targetUid, String visitorAvatar) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid == targetUid) return;

    final userRef = _db.collection('users').doc(targetUid);
    
    // We update count and shift the visitor avatars list
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      List<String> visitors = List<String>.from(data['recentVisitors'] ?? []);
      
      // Add if not already in recent list (or just add new)
      if (!visitors.contains(visitorAvatar)) {
        visitors.insert(0, visitorAvatar);
        if (visitors.length > 5) visitors = visitors.sublist(0, 5);
      }

      transaction.update(userRef, {
        'visitorCount': FieldValue.increment(1),
        'recentVisitors': visitors,
      });
    });
  }

  // Media & Social (Restored missing streams and logic)

  // Followers Stream
  Stream<List<String>> getFollowersStream(String uid) {
    return _db.collection('users').doc(uid).collection('followers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  // Following Stream
  Stream<List<String>> getFollowingStream(String uid) {
    return _db.collection('users').doc(uid).collection('following').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  // Upload Profile Photo
  Future<String> uploadProfilePhoto(String uid, File image) async {
    return await _cloudinary.uploadImage(image.path, folder: "profile_photos");
  }

  // Upload Media Photo
  Future<String> uploadMediaPhoto(String uid, File image, String tag) async {
    return await _cloudinary.uploadImage(image.path, folder: tag == "moment" ? "moments" : "gallery");
  }

  // Create Media Post (Moved to Cloud Functions to resolve permissions)
  Future<void> createMediaPost({
    required String uid,
    required String imageUrl,
    required String tag,
    String caption = "",
  }) async {
    await callFunction('createMediaPost', {
      'imageUrl': imageUrl,
      'tag': tag,
      'caption': caption,
    });
  }

  // Toggle Like (Moved to Cloud Functions to resolve permissions)
  Future<void> toggleLike({
    required String ownerUid,
    required String mediaId,
    required String likerUid,
    required bool isMoment,
  }) async {
    await callFunction('toggleLike', {
      'ownerUid': ownerUid,
      'mediaId': mediaId,
      'isMoment': isMoment,
    });
  }

  // Add Comment (Moved to Cloud Functions to resolve permissions)
  Future<void> addComment({
    required String ownerUid,
    required String mediaId,
    required String commenterUid,
    required String text,
    required bool isMoment,
  }) async {
    await callFunction('addComment', {
      'ownerUid': ownerUid,
      'mediaId': mediaId,
      'text': text,
      'isMoment': isMoment,
    });
  }

  // Comments Stream (Restored)
  Stream<List<Map<String, dynamic>>> getCommentsStream(String ownerUid, String mediaId) {
    return _db.collection('users').doc(ownerUid).collection('media').doc(mediaId).collection('comments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // Moments List Stream
  Stream<List<Map<String, dynamic>>> getMomentsStream() {
    return _db.collection('moments')
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // User Media Stream
  Stream<List<Map<String, dynamic>>> getUserMediaStream(String uid, {String? tag}) {
    Query query = _db.collection('users').doc(uid).collection('media')
      .orderBy('createdAt', descending: true);
    if (tag != null) query = query.where('tag', isEqualTo: tag);
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // Single Moment Stream (Restored)
  Stream<Map<String, dynamic>> getMomentStream(String mediaId) {
    return _db.collection('moments').doc(mediaId).snapshots().map((snapshot) {
      if (!snapshot.exists) return {};
      return snapshot.data() as Map<String, dynamic>;
    });
  }

  // Recharge Diamonds (SVIP Loyalty Trigger)

  Future<Map<String, dynamic>> rechargeDiamonds(int amount, String packageId) async {
    return await callFunction('rechargeDiamonds', {
      'amount': amount,
      'packageId': packageId,
    });
  }

  Future<void> sendCPInvite(String targetUid) async {
    await callFunction('sendCPInvite', {'targetUid': targetUid});
  }

  Future<void> acceptCPInvite(String inviteId) async {
    await callFunction('acceptCPInvite', {'inviteId': inviteId});
  }

  Stream<List<Map<String, dynamic>>> getCPInvitesStream(String uid) {
    return _db.collection('cp_invites').where('targetUid', isEqualTo: uid).snapshots().map((snap) => snap.docs.map((d) => ({...d.data(), 'id': d.id})).toList());
  }

  Future<void> redeemReferralCode(String code) async {
    await callFunction('redeemReferralCode', {'code': code});
  }

  Future<void> equipItem(String itemId, String category) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final Map<String, String> fieldMap = {
      'frame': 'profileFrame',
      'mount': 'entryAnimation',
      'bubble': 'chatBubble',
      'aperture': 'equippedMicWave',
      'crown': 'equippedCrown',
    };
    final String targetField = fieldMap[category] ?? category;

    // For local asset paths or direct frame URLs, apply direct update immediately
    if (itemId.startsWith('assets/') || itemId == 'none') {
      if (uid != null) {
        await updateProfileFields(uid, {targetField: itemId == 'none' ? '' : itemId});
      }
      return;
    }

    try {
      await callFunction('equipItem', {'itemId': itemId, 'category': category});
    } catch (e) {
      if (uid != null) {
        await updateProfileFields(uid, {targetField: itemId});
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getWarehouseItemsStream(String uid, String category) {
    return _db.collection('users').doc(uid).collection('vault')
      .where('category', isEqualTo: category)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => ({...d.data(), 'id': d.id}))
          .where((item) => !_isVaultItemExpired(item))
          .toList());
  }

  bool _isVaultItemExpired(Map<String, dynamic> item) {
    final expiresAt = item['expiresAt'];
    if (expiresAt == null) return false;
    DateTime? expiry;
    if (expiresAt is Timestamp) {
      expiry = expiresAt.toDate();
    } else if (expiresAt is String) {
      expiry = DateTime.tryParse(expiresAt);
    }
    return expiry != null && expiry.isBefore(DateTime.now());
  }

  Future<void> purchasePrestigeItem(String itemId) async {
    await callFunction('purchasePrestigeItem', {'itemId': itemId});
  }

  Stream<List<Map<String, dynamic>>> getPrestigeItemsStream() {
    return _db.collection('prestige_items')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => ({...d.data(), 'id': d.id})).toList());
  }

  Future<void> feedPrestigeItems() async {
     final items = [
       {'name': 'Nebula Frame', 'price': 500, 'category': 'frame', 'imageUrl': 'https://i.ibb.co/vz6G3H1/vip1-frame.png', 'validityDays': 30, 'isActive': true},
       {'name': 'Royal Crown', 'price': 1200, 'category': 'frame', 'imageUrl': 'https://i.ibb.co/vz6G3H1/vip1-frame.png', 'validityDays': 7, 'isActive': true},
       {'name': 'Crystal Bubble', 'price': 300, 'category': 'bubble', 'imageUrl': 'https://i.ibb.co/0y6mN3k/bubble.png', 'validityDays': 15, 'isActive': true},
       {'name': 'Dragon Steed', 'price': 15000, 'category': 'mount', 'imageUrl': 'https://i.ibb.co/BS6Z8PQ/noble6-badge.png', 'validityDays': 30, 'isActive': true},
       {'name': 'Cyber Car', 'price': 50000, 'category': 'mount', 'imageUrl': 'https://i.ibb.co/xJ5c2zT/mount.png', 'validityDays': 365, 'isActive': true},
     ];

     for (var item in items) {
       await _db.collection('prestige_items').doc(item['name']!.toString().toLowerCase().replaceAll(' ', '_')).set(item);
     }
  }

  // Optimized Friends Stream (Mutual Followers)
  Stream<List<String>> getFriendsStream(String uid) {
    final following = getFollowingStream(uid);
    final followers = getFollowersStream(uid);
    
    return following.asyncMap((followingList) async {
       final followersList = await followers.first;
       return followingList.where((id) => followersList.contains(id)).toList();
    });
  }

  // Family Rooms Stream
  Stream<List<Map<String, dynamic>>> getFamilyRoomsStream(String familyId) {
    return _db.collection('rooms')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .asyncMap((roomSnap) async {
         final roomDocs = roomSnap.docs;
         List<Map<String, dynamic>> familyRooms = [];
         
         for (var doc in roomDocs) {
           final data = doc.data();
           final ownerUid = data['ownerUid'] as String;
           
           // Fetch owner profile to check familyId
           final ownerDoc = await _db.collection('users').doc(ownerUid).get();
           final ownerData = ownerDoc.data();
           if (ownerData != null && ownerData['familyId'] == familyId) {
             familyRooms.add(data);
           }
         }
         return familyRooms;
      });
  }
}

