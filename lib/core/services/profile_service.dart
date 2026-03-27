import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/cloudinary_service.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  // Stream of user profile
  Stream<UserModel> getProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      return UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
    });
  }

  // Check username availability directly via Firestore
  Future<bool> isUsernameAvailable(String username) async {
    final cleanUsername = username.toLowerCase().trim();
    final doc = await _db.collection('usernames').doc(cleanUsername).get();
    return !doc.exists;
  }
  
  // Setup Profile via Firestore Transaction
  Future<void> setupUserProfile({
    required String username,
    required String displayName,
    required String bio,
    required String country,
    required String profilePhotoUrl,
    required String uid,
  }) async {
    final cleanUsername = username.toLowerCase().trim();
    final userRef = _db.collection('users').doc(uid);
    final usernameRef = _db.collection('usernames').doc(cleanUsername);

    return _db.runTransaction((transaction) async {
      final usernameDoc = await transaction.get(usernameRef);
      if (usernameDoc.exists && usernameDoc.data()?['uid'] != uid) {
        throw Exception("Username is already taken by another user.");
      }

      final userDoc = await transaction.get(userRef);
      final Map<String, dynamic> userData = {
        'username': cleanUsername,
        'displayName': displayName,
        'bio': bio,
        'country': country,
        'profilePhotoUrl': profilePhotoUrl,
        'lastActive': FieldValue.serverTimestamp(),
      };

      if (!userDoc.exists) {
        userData.addAll({
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'diamondBalance': 0,
          'xp': 0,
          'level': 1,
          'followerCount': 0,
          'followingCount': 0,
          'status': 'online',
          'badges': [],
          'profileFrame': '',
          'tags': [],
          'vipTier': 'none',
          'isBanned': false,
        });
        transaction.set(userRef, userData);
      } else {
        transaction.update(userRef, userData);
      }

      transaction.set(usernameRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Update existing Profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? country,
    String? profilePhotoUrl,
    String? status,
  }) async {
    final Map<String, dynamic> updates = {
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (country != null) 'country': country,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (status != null) 'status': status,
      'lastActive': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(uid).update(updates);
  }

  // Upload Profile Photo via Cloudinary
  Future<String> uploadProfilePhoto(String uid, File image) async {
    return await _cloudinary.uploadImage(image.path, folder: "profile_photos");
  }

  // Upload Normal/Moment Photo via Cloudinary
  Future<String> uploadMediaPhoto(String uid, File image, String tag) async {
    return await _cloudinary.uploadImage(image.path, folder: tag == "moment" ? "moments" : "gallery");
  }

  // Create Media Document in Firestore
  Future<void> createMediaPost({
    required String uid,
    required String imageUrl,
    required String tag,
    String caption = "",
  }) async {
    final mediaId = _db.collection('users').doc(uid).collection('media').doc().id;
    final mediaRef = _db.collection('users').doc(uid).collection('media').doc(mediaId);
    
    final Map<String, dynamic> mediaData = {
      'mediaId': mediaId,
      'userId': uid,
      'imageUrl': imageUrl,
      'tag': tag,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': 0,
      'commentsCount': 0,
      'isDeleted': false,
    };

    return _db.runTransaction((transaction) async {
      transaction.set(mediaRef, mediaData);
      if (tag == "moment") {
        transaction.set(_db.collection('moments').doc(mediaId), mediaData);
      }
      transaction.update(_db.collection('users').doc(uid), {
        'mediaCount': FieldValue.increment(1),
        if (tag == "moment") 'momentCount': FieldValue.increment(1),
        if (tag == "moment") 'lastMomentAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Toggle Like on Media
  Future<void> toggleLike({
    required String ownerUid,
    required String mediaId,
    required String likerUid,
    required bool isMoment,
  }) async {
    final likeRef = _db.collection('users').doc(ownerUid).collection('media').doc(mediaId).collection('likes').doc(likerUid);
    final mediaRef = _db.collection('users').doc(ownerUid).collection('media').doc(mediaId);
    final momentRef = _db.collection('moments').doc(mediaId);

    final likeDoc = await likeRef.get();
    final bool isLiking = !likeDoc.exists;

    return _db.runTransaction((transaction) async {
      if (isLiking) {
        transaction.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
        transaction.update(mediaRef, {'likesCount': FieldValue.increment(1)});
        if (isMoment) {
          transaction.update(momentRef, {'likesCount': FieldValue.increment(1)});
        }
      } else {
        transaction.delete(likeRef);
        transaction.update(mediaRef, {'likesCount': FieldValue.increment(-1)});
        if (isMoment) {
          transaction.update(momentRef, {'likesCount': FieldValue.increment(-1)});
        }
      }
    });
  }

  // Add Comment
  Future<void> addComment({
    required String ownerUid,
    required String mediaId,
    required String commenterUid,
    required String text,
    required bool isMoment,
  }) async {
    final commentId = _db.collection('users').doc(ownerUid).collection('media').doc(mediaId).collection('comments').doc().id;
    final commentRef = _db.collection('users').doc(ownerUid).collection('media').doc(mediaId).collection('comments').doc(commentId);
    final mediaRef = _db.collection('users').doc(ownerUid).collection('media').doc(mediaId);
    final momentRef = _db.collection('moments').doc(mediaId);

    final Map<String, dynamic> commentData = {
      'commentId': commentId,
      'userId': commenterUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };

    return _db.runTransaction((transaction) async {
      transaction.set(commentRef, commentData);
      transaction.update(mediaRef, {'commentsCount': FieldValue.increment(1)});
      if (isMoment) {
        transaction.update(momentRef, {'commentsCount': FieldValue.increment(1)});
      }
    });
  }

  // Get Comments Stream
  Stream<List<Map<String, dynamic>>> getCommentsStream(String ownerUid, String mediaId) {
    return _db.collection('users').doc(ownerUid).collection('media').doc(mediaId).collection('comments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // Follow User
  Future<void> followUser(String followerUid, String targetUid) async {
    if (followerUid == targetUid) return;
    
    final followerRef = _db.collection('users').doc(followerUid);
    final targetRef = _db.collection('users').doc(targetUid);
    final subFollowerRef = targetRef.collection('followers').doc(followerUid);
    final subFollowingRef = followerRef.collection('following').doc(targetUid);

    return _db.runTransaction((transaction) async {
      final doc = await transaction.get(subFollowerRef);
      if (doc.exists) return;

      transaction.set(subFollowerRef, {'followedAt': FieldValue.serverTimestamp()});
      transaction.set(subFollowingRef, {'followedAt': FieldValue.serverTimestamp()});
      
      transaction.update(followerRef, {'followingCount': FieldValue.increment(1)});
      transaction.update(targetRef, {'followerCount': FieldValue.increment(1)});
    });
  }

  // Unfollow User
  Future<void> unfollowUser(String followerUid, String targetUid) async {
    final followerRef = _db.collection('users').doc(followerUid);
    final targetRef = _db.collection('users').doc(targetUid);
    final subFollowerRef = targetRef.collection('followers').doc(followerUid);
    final subFollowingRef = followerRef.collection('following').doc(targetUid);

    return _db.runTransaction((transaction) async {
      final doc = await transaction.get(subFollowerRef);
      if (!doc.exists) return;

      transaction.delete(subFollowerRef);
      transaction.delete(subFollowingRef);
      
      transaction.update(followerRef, {'followingCount': FieldValue.increment(-1)});
      transaction.update(targetRef, {'followerCount': FieldValue.increment(-1)});
    });
  }

  // Get Followers Stream
  Stream<List<String>> getFollowersStream(String uid) {
    return _db.collection('users').doc(uid).collection('followers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  // Get Following Stream
  Stream<List<String>> getFollowingStream(String uid) {
    return _db.collection('users').doc(uid).collection('following').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

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

  // Single Moment Stream
  Stream<Map<String, dynamic>> getMomentStream(String mediaId) {
    return _db.collection('moments').doc(mediaId).snapshots().map((snapshot) {
      if (!snapshot.exists) return {};
      return snapshot.data() as Map<String, dynamic>;
    });
  }
}
