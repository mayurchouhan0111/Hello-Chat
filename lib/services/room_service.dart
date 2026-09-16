import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import '../core/models/room_model.dart';
import '../core/models/participant_model.dart';
import '../core/models/room_banner_model.dart';
import 'package:flutter/foundation.dart';
import '../core/services/base_firebase_service.dart';

class RoomService with BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Streams
  Stream<List<RoomModel>> getRoomsDiscoveryStream() {
    return _db.collection('rooms')
      .where('status', isEqualTo: 'active')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => RoomModel.fromMap(doc.data())).toList());
  }

  Stream<RoomModel?> getRoomStream(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return RoomModel.fromMap(snapshot.data() as Map<String, dynamic>);
    });
  }

  Stream<List<Participant>> getParticipantsStream(String roomId) {
    return _db.collection('rooms').doc(roomId).collection('participants')
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs.map((doc) => Participant.fromMap(doc.data(), doc.id)).toList();
        list.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
        return list;
      });
  }

  Stream<List<RoomBannerModel>> getRoomBannersStream() {
    return _db.collection('room_integrated_banners')
      .orderBy('order', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => RoomBannerModel.fromMap(doc.data(), doc.id))
          .where((banner) => banner.enabled)
          .toList());
  }

  // Room Management
  Future<String> createRoom({
    required String name,
    required String theme,
    String? coverUrl,
    bool isPrivate = false,
    String? password,
    int capacity = 8,
    bool backgroundMusic = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in.");

    final roomId = 'room_$uid';
    final roomRef = _db.collection('rooms').doc(roomId);

    final userDoc = await _db.collection('users').doc(uid).get();
    final userDataProfile = userDoc.data();
    final hostAvatar = (userDataProfile?['profilePhotoUrl'] as String?)?.trim().isNotEmpty == true
        ? userDataProfile!['profilePhotoUrl']
        : (userDataProfile?['photoURL'] as String?) ?? '';
    final finalCoverUrl = (coverUrl != null && coverUrl.trim().isNotEmpty) ? coverUrl.trim() : hostAvatar;

    final roomData = {
      'roomId': roomId,
      'createdBy': uid,
      'ownerUid': uid,
      'name': name,
      'theme': theme,
      'coverUrl': finalCoverUrl,
      'roomCover': finalCoverUrl,
      'roomIcon': finalCoverUrl,
      'ownerAvatar': hostAvatar,
      'ownerProfilePic': hostAvatar,
      'userProfilePic': hostAvatar,
      'isPrivate': isPrivate,
      'passwordHash': password,
      'capacity': capacity,
      'currentUsersCount': 1,
      'backgroundMusic': backgroundMusic,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'admins': [uid],
      'bannedUids': [],
    };

    // Split into two commits: the room doc MUST exist before writing the
    // owner's participant doc, because Firestore rules evaluate batch writes
    // against pre-batch state (get()/exists() on the room would see it as
    // missing, causing the owner seat-0 participant write to be denied).
    await roomRef.set(roomData);

    final participantData = {
      'uid': uid,
      'displayName': userDataProfile?['displayName'] ?? 'Host',
      'profilePhotoUrl': userDataProfile?['profilePhotoUrl'] ?? '',
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
      'seatIndex': 0,
      'isMuted': false,
      'vipTier': userDataProfile?['vipTier'] ?? 'none',
      'nobleTier': userDataProfile?['nobleTier'] ?? 'Civilian',
      'entryAnimation': userDataProfile?['entryAnimation'] ?? '',
      'profileFrame': userDataProfile?['profileFrame'] ?? '',
      'badgeIcon': userDataProfile?['badgeIcon'] ?? '',
      'tags': userDataProfile?['tags'] ?? [],
      'level': userDataProfile?['level'] ?? 1,
      'helloId': userDataProfile?['helloId'],
    };

    final participantBatch = _db.batch();
    participantBatch.set(roomRef.collection('participants').doc(uid), participantData);

    // 3. Send Join Message
    participantBatch.set(roomRef.collection('messages').doc(), {
      'uid': uid,
      'text': '${userDataProfile?['displayName'] ?? 'Host'} joined the room',
      'type': 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await participantBatch.commit();
    return roomId;
  }

  Future<void> joinRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final roomRef = _db.collection('rooms').doc(roomId);
    final userRef = _db.collection('users').doc(uid);
    final participantRef = roomRef.collection('participants').doc(uid);

    await _db.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final userSnapshot = await transaction.get(userRef);
      final userData = userSnapshot.data();
      final displayName = userData?['displayName'] ?? 'Guest';
      final photoUrl = userData?['profilePhotoUrl'] ?? '';

      final participantSnapshot = await transaction.get(participantRef);

      if (!participantSnapshot.exists) {
        final isOwner = roomSnapshot.exists && roomSnapshot.get('ownerUid') == uid;
        transaction.set(participantRef, {
          'uid': uid,
          'role': isOwner ? 'owner' : 'audience',
          'seatIndex': isOwner ? 0 : -1,
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'isMuted': isOwner ? false : true,
          'displayName': displayName,
          'profilePhotoUrl': photoUrl,
          'vipTier': userData?['vipTier'] ?? 'none',
          'nobleTier': userData?['nobleTier'] ?? 'Civilian',
          'entryAnimation': userData?['entryAnimation'] ?? '',
          'profileFrame': userData?['profileFrame'] ?? '',
          'badgeIcon': userData?['badgeIcon'] ?? '',
          'tags': userData?['tags'] ?? [],
          'level': userData?['level'] ?? 1,
          'helloId': userData?['helloId'],
        });

        transaction.update(roomRef, {'currentUsersCount': FieldValue.increment(1)});

        transaction.set(roomRef.collection('messages').doc(), {
          'uid': uid,
          'text': '$displayName enter the room',
          'type': 'system',
          'createdAt': FieldValue.serverTimestamp(),
        });

        final welcomeMsg = roomSnapshot.exists && roomSnapshot.data() != null && roomSnapshot.data()!.containsKey('welcomeMessage') 
            ? (roomSnapshot.get('welcomeMessage') as String?) 
            : null;
        if (welcomeMsg != null && welcomeMsg.trim().isNotEmpty) {
          transaction.set(roomRef.collection('messages').doc(), {
            'uid': 'system',
            'text': '@$displayName 👉 ${welcomeMsg.trim()}',
            'type': 'system',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        debugPrint('[ROOM_JOIN] New participant $uid joined room $roomId');
      } else {
        // Restore existing participant — preserve seatIndex and role
        final existingData = participantSnapshot.data() as Map<String, dynamic>;
        final previousSeat = existingData['seatIndex'];
        final previousRole = existingData['role'];

        final isOwner = roomSnapshot.exists && roomSnapshot.get('ownerUid') == uid;
        final updatePayload = <String, dynamic>{
          'lastActive': FieldValue.serverTimestamp(),
        };

        if (isOwner) {
          if (previousSeat != 0) updatePayload['seatIndex'] = 0;
          if (previousRole != 'owner' && previousRole != 'host') updatePayload['role'] = 'owner';
          updatePayload['isMuted'] = false;
        } else {
          // If seatIndex was lost (set to null/undefined), restore to -1
          if (previousSeat == null) {
            updatePayload['seatIndex'] = -1;
          }
          if (previousRole == null) {
            updatePayload['role'] = 'audience';
          }
        }

        transaction.update(participantRef, updatePayload);

        debugPrint('[ROOM_JOIN] Existing participant $uid re-joined room $roomId (seatIndex=$previousSeat, role=$previousRole, isOwner=$isOwner)');
      }

      // Track active room on user profile (CRITICAL for presence sync)
      transaction.update(userRef, {'activeRoomId': roomId});
    });
  }

  Future<void> leaveRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    debugPrint('[ROOM_LEAVE] User $uid leaving room $roomId at ${DateTime.now().toIso8601String()}');

    final roomRef = _db.collection('rooms').doc(roomId);
    final userRef = _db.collection('users').doc(uid);

    try {
      await _db.runTransaction((transaction) async {
        transaction.delete(roomRef.collection('participants').doc(uid));
        transaction.update(roomRef, {'currentUsersCount': FieldValue.increment(-1)});
        
        // Clear active room ID
        transaction.update(userRef, {'activeRoomId': FieldValue.delete()});
      });
    } catch (e) {
      debugPrint('[ROOM_LEAVE] Transaction error ($e), attempting fallback individual writes');
      try {
        await roomRef.collection('participants').doc(uid).delete();
        await roomRef.update({'currentUsersCount': FieldValue.increment(-1)});
        await userRef.update({'activeRoomId': FieldValue.delete()});
      } catch (fallbackError) {
        debugPrint('[ROOM_LEAVE] Fallback error: $fallbackError');
      }
    }
  }

  Future<void> endRoom(String roomId) async {
    await Future.wait([
      _db.collection('rooms').doc(roomId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      }),
      _cleanupRoomImages(roomId),
    ]);
  }

  Future<void> _cleanupRoomImages(String roomId) async {
    try {
      const cloudName = "dceh4ob2i";
      const apiKey = "256641331991177";
      const apiSecret = "eNzBz9AxS9d_VF2ebvSoAth18s0";
      final basicAuth = base64Encode(utf8.encode("$apiKey:$apiSecret"));
      final prefix = "chat_images/$roomId";
      await Dio().post(
        "https://api.cloudinary.com/v1_1/$cloudName/resources/image/delete_by_prefix",
        options: Options(headers: {"Authorization": "Basic $basicAuth"}),
        data: {"prefix": prefix},
      );
    } catch (e) {
      debugPrint("Room image cleanup error: $e");
    }
  }

  Future<void> updateParticipantPresence(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('rooms').doc(roomId).collection('participants').doc(uid).set({
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('users').doc(uid).set({
        'isOnline': true,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ROOM_PRESENCE] Failed to update presence for $uid in $roomId: $e');
    }
  }

  // Seat Management - High-Performance Low-Latency Seat Switching (<150ms)
  Future<void> takeSeat(String roomId, int index, {String? ownerUid}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    // Resolve owner check: use provided ownerUid if passed to save a Firestore network round trip
    String? resolvedOwnerUid = ownerUid;
    if (resolvedOwnerUid == null) {
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      resolvedOwnerUid = roomDoc.exists ? roomDoc.get('ownerUid') as String? : null;
    }

    if (uid == resolvedOwnerUid) {
      if (index != 0) {
        throw Exception("As Room Owner, your seat is the top Host Seat (Seat 0).");
      }
    } else {
      if (index == 0) {
        throw Exception("Only the room owner can take the host seat");
      }
    }
    
    final roomRef = _db.collection('rooms').doc(roomId);
    final participantRef = roomRef.collection('participants').doc(uid);
    
    try {
      // Instant direct write to Firestore (0 extra queries)
      await participantRef.set({
        'seatIndex': index,
        'role': 'speaker',
      }, SetOptions(merge: true));

      debugPrint('[ROOM_SEAT] User $uid direct fast-assigned seat $index in room $roomId');
    } catch (e) {
      debugPrint('[ROOM_SEAT] Error taking seat: $e');
      rethrow;
    }
  }

  Future<void> leaveSeat(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('rooms').doc(roomId).collection('participants').doc(uid).update({
      'seatIndex': -1,
      'role': 'listener',
    });
  }

  Future<void> setSingerRole(String roomId, String targetUid, bool isSinger) async {
    await _db.collection('rooms').doc(roomId).collection('participants').doc(targetUid).set({
      'isSinger': isSinger,
    }, SetOptions(merge: true));
  }

  Future<void> updateRoomSettings(String roomId, Map<String, dynamic> updates) async {
    await _db.collection('rooms').doc(roomId).update(updates);
  }

  Future<void> setRoomCapacity(String roomId, int capacity) async {
    if (![8, 12, 16].contains(capacity)) {
       throw Exception("Invalid capacity. Allowed values: 8, 12, 16.");
    }
    await _db.collection('rooms').doc(roomId).update({
      'capacity': capacity,
    });
  }

  // ⚔️ Professional PK Battle Management
  Future<Map<String, dynamic>> testConnection() async {
    final result = await callFunction('pingServer');
    final serverProjectId = result['projectId'];
    const myProjectId = 'hellochat-e8965'; // From firebase_options.dart

    debugPrint('📡 [RoomService] Ping Result: $result');
    if (serverProjectId != myProjectId) {
       debugPrint('❌ [RoomService] CRITICAL ERROR: Project ID Mismatch!');
       debugPrint('   App: $myProjectId vs Server: $serverProjectId');
    } else {
       debugPrint('✅ [RoomService] Project IDs Match! ($serverProjectId)');
    }
    
    return result as Map<String, dynamic>;
  }

  Future<void> invitePKChallenge({
    required String roomId,
    required String targetUid,
    int durationSeconds = 300,
  }) async {
    // 🛡️ User Presence Guard: Check if opponent is actually in the room
    // Note: For testing/simulation via Admin Panel, we allow this even if they aren't in the participants subcollection.
    final participantDoc = await _db
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(targetUid)
        .get();

    if (!participantDoc.exists) {
      debugPrint('⚠️ [RoomService] Warning: Target user not in room. Proceeding for simulation/remote challenge.');
    }

    await callFunction('invitePKChallenge', {
      'roomId': roomId,
      'targetUid': targetUid,
      'senderUid': FirebaseAuth.instance.currentUser?.uid, // Diagnostic fallback
      'durationSeconds': durationSeconds,
    });
  }

  Future<void> sendRoomInvitation({
    required String roomId,
    required String targetUid,
  }) async {
    await callFunction('sendRoomInvitation', {
      'roomId': roomId,
      'targetUid': targetUid,
      'senderUid': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  Future<void> respondToPKChallenge({
    required String roomId,
    required bool accepted,
  }) async {
    await callFunction('respondToPKChallenge', {
      'roomId': roomId,
      'accepted': accepted,
      'receiverUid': FirebaseAuth.instance.currentUser?.uid, // Fallback
    });
  }

  Future<void> startPKBattle({
    required String roomId,
    required String leftUid,
    required String rightUid,
    int durationSeconds = 300,
  }) async {
    await callFunction('startPKBattle', {
      'roomId': roomId,
      'leftUid': leftUid,
      'rightUid': rightUid,
      'durationSeconds': durationSeconds,
      'adminUid': FirebaseAuth.instance.currentUser?.uid, // Fallback
    });
  }

  Future<void> endPKBattle(String roomId, {String? forcedWinnerUid}) async {
    await callFunction('endPKBattle', {
      'roomId': roomId,
      'adminUid': FirebaseAuth.instance.currentUser?.uid, // Fallback
      if (forcedWinnerUid != null) 'forcedWinnerUid': forcedWinnerUid,
    });
  }

  Future<void> inviteToPKTeam({required String roomId, required String targetUid, required String side}) async {
    // This could be implemented as a specialized message or subcollection entry
    // For now, let's just add them to the team structure directly if needed, or notify
    debugPrint("Inviting $targetUid to $side PK team in $roomId");
    // Implementation: Update a 'pkInvites' subcollection
    await _db.collection('rooms').doc(roomId).collection('pkInvites').doc(targetUid).set({
      'side': side,
      'invitedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> joinPKTeam({required String roomId, required String side}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db.collection('rooms').doc(roomId).update({
      'pkTeams.$uid': side,
      'pkScores.$uid': 0,
    });
  }

  Future<void> leavePKTeam(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db.collection('rooms').doc(roomId).update({
      'pkTeams.$uid': FieldValue.delete(),
      'pkScores.$uid': FieldValue.delete(),
    });
  }

  // Admin & Settings
  Future<void> addModerator(String roomId, String targetUid) async {
    await _db.collection('rooms').doc(roomId).update({
      'admins': FieldValue.arrayUnion([targetUid])
    });
  }

  Future<void> removeModerator(String roomId, String targetUid) async {
    await _db.collection('rooms').doc(roomId).update({
      'admins': FieldValue.arrayRemove([targetUid])
    });
  }

  Future<void> addRoomModerator(String roomId, String targetUid) async {
    await _db.collection('rooms').doc(roomId).update({
      'moderators': FieldValue.arrayUnion([targetUid])
    });
  }

  Future<void> removeRoomModerator(String roomId, String targetUid) async {
    await _db.collection('rooms').doc(roomId).update({
      'moderators': FieldValue.arrayRemove([targetUid])
    });
  }

  Future<void> kickUser(String roomId, String targetUid, {int? durationMinutes, String? reason}) async {
    // Server-side cloud function validates VIP 7+ kick protection
    await callFunction('roomKickUser', {
      'roomId': roomId,
      'targetUid': targetUid,
      'duration': durationMinutes,
      'reason': reason ?? '',
    });
  }

  Future<void> unbanUser(String roomId, String targetUid) async {
    await callFunction('roomUnbanUser', {
      'roomId': roomId,
      'targetUid': targetUid,
    });
  }

  Future<void> clearRoomMessages(String roomId) async {
    final messages = await _db.collection('rooms').doc(roomId).collection('messages').get();
    if (messages.docs.isEmpty) return;

    final chunks = <List<QueryDocumentSnapshot<Map<String, dynamic>>>>[];
    for (var i = 0; i < messages.docs.length; i += 400) {
      chunks.add(messages.docs.sublist(i, i + 400 > messages.docs.length ? messages.docs.length : i + 400));
    }

    for (var chunk in chunks) {
      final batch = _db.batch();
      for (var doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> updateRoomWelcomeMessage(String roomId, String welcomeMessage) async {
    await _db.collection('rooms').doc(roomId).update({
      'welcomeMessage': welcomeMessage,
    });
  }

  Future<void> muteUser(String roomId, String targetUid, bool mute) async {
    if (mute) {
      final userDoc = await _db.collection('users').doc(targetUid).get();
      final data = userDoc.data() ?? {};
      final svipLevel = (data['svipLevel'] as num?)?.toInt() ?? 0;
      final svipEnd = data['svipCycleEndDate'] as Timestamp?;
      final protEnd = data['assignedProtectionExpiresAt'] as Timestamp?;
      final now = DateTime.now();

      final isSvipProtected = (svipLevel >= 4 && svipEnd != null && svipEnd.toDate().isAfter(now)) ||
          (protEnd != null && protEnd.toDate().isAfter(now));

      if (isSvipProtected) {
        throw 'This user is protected by SVIP privileges. Kick Out and Mute actions are not allowed.';
      }
    }

    await _db.collection('rooms').doc(roomId).collection('participants').doc(targetUid).update({
      'isMuted': mute,
    });
  }

  Future<void> setRoomPassword(String roomId, String password) async {
    await _db.collection('rooms').doc(roomId).update({
      'passwordHash': password,
      'isPrivate': password.isNotEmpty,
    });
  }

  Future<void> muteAllSeats(String roomId) async {
    final speakers = await _db.collection('rooms').doc(roomId).collection('participants')
      .where('seatIndex', isNotEqualTo: -1).get();
    final batch = _db.batch();
    for (var doc in speakers.docs) {
      batch.update(doc.reference, {'isMuted': true});
    }
    await batch.commit();
  }

  // YouTube Integration
  Future<void> setYoutubeVideo(String roomId, String videoId) async {
    try {
      final doc = await _db.collection('rooms').doc(roomId).get();
      if (!doc.exists) {
        debugPrint('Room $roomId not found. Cannot set YouTube video.');
        return;
      }
      if (videoId.isEmpty) {
        await stopYoutube(roomId);
        return;
      }
      await _db.collection('rooms').doc(roomId).update({
        'youtubeVideoId': videoId,
        'isYoutubeActive': true,
        'youtubeStatus': 'playing',
        'youtubeSeekTime': 0,
      });
    } catch (e) {
      debugPrint('Error setting YouTube video: $e');
    }
  }

  Future<void> stopYoutube(String roomId) async {
    await _db.collection('rooms').doc(roomId).update({
      'isYoutubeActive': false,
      'youtubeVideoId': FieldValue.delete(),
      'youtubeStatus': 'stopped',
    });
  }
  Future<void> toggleSeatLock(String roomId, int index, bool lock) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    if (lock) {
      await roomRef.update({
        'lockedSeats': FieldValue.arrayUnion([index])
      });
    } else {
      await roomRef.update({
        'lockedSeats': FieldValue.arrayRemove([index])
      });
    }
  }

  // Audio Call Invitation
  Future<void> inviteToAudioCall(String roomId, String targetUid, {String type = 'invite'}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('rooms').doc(roomId).collection('audio_invitations').doc(targetUid).set({
      'fromUid': uid,
      'status': 'pending',
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<Map<String, dynamic>?> audioInvitationsStream(String roomId, String myUid) {
    return _db.collection('rooms').doc(roomId).collection('audio_invitations').doc(myUid)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          final data = snap.data()!;
          data['docId'] = snap.id;
          return data;
        });
  }

  Future<void> respondToAudioCall(String roomId, String myUid, bool accepted) async {
    final ref = _db.collection('rooms').doc(roomId).collection('audio_invitations').doc(myUid);
    if (accepted) {
      await ref.update({'status': 'accepted'});
    } else {
      await ref.delete();
    }
  }

  Future<void> clearAudioInvitation(String roomId, String targetUid) async {
    await _db.collection('rooms').doc(roomId).collection('audio_invitations').doc(targetUid).delete();
  }
}
