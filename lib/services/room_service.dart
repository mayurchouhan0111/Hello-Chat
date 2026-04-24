import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/models/room_model.dart';
import '../core/models/participant_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/base_firebase_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
      .orderBy('joinedAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Participant.fromMap(doc.data(), doc.id)).toList());
  }

  // Room Management
  Future<String> createRoom({
    required String name,
    required String theme,
    String? coverUrl,
    bool isPrivate = false,
    String? password,
    int capacity = 10,
    bool backgroundMusic = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in.");

    final roomId = _db.collection('rooms').doc().id;
    final roomRef = _db.collection('rooms').doc(roomId);

    final roomData = {
      'roomId': roomId,
      'createdBy': uid,
      'ownerUid': uid,
      'name': name,
      'theme': theme,
      'coverUrl': coverUrl ?? '',
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

    final batch = _db.batch();
    batch.set(roomRef, roomData);
    
    final participantData = {
      'uid': uid,
      'displayName': 'Host',
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
      'seatIndex': 0,
      'isMuted': false,
    };

    batch.set(roomRef.collection('participants').doc(uid), participantData);
    await batch.commit();
    return roomId;
  }

  Future<void> joinRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final roomRef = _db.collection('rooms').doc(roomId);
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      // 1. Add participant
      transaction.set(roomRef.collection('participants').doc(uid), {
        'uid': uid,
        'displayName': 'Guest',
        'role': 'audience',
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'seatIndex': -1,
        'isMuted': false,
      });

      // 2. Increment count
      transaction.update(roomRef, {'currentUsersCount': FieldValue.increment(1)});

      // 3. Track active room on user profile (CRITICAL for presence sync)
      transaction.update(userRef, {'activeRoomId': roomId});
    });
  }

  Future<void> leaveRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final roomRef = _db.collection('rooms').doc(roomId);
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      transaction.delete(roomRef.collection('participants').doc(uid));
      transaction.update(roomRef, {'currentUsersCount': FieldValue.increment(-1)});
      
      // Clear active room ID
      transaction.update(userRef, {'activeRoomId': FieldValue.delete()});
    });
  }

  Future<void> endRoom(String roomId) async {
    await _db.collection('rooms').doc(roomId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateParticipantPresence(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('rooms').doc(roomId).collection('participants').doc(uid).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // Seat Management
  Future<void> takeSeat(String roomId, int index) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final roomRef = _db.collection('rooms').doc(roomId);
    
    try {
      await _db.runTransaction((transaction) async {
        // Check if anyone else has this seat index
        final seatQuery = await roomRef.collection('participants')
          .where('seatIndex', isEqualTo: index)
          .get();
        
        if (seatQuery.docs.isNotEmpty) {
          throw Exception("Seat already taken");
        }

        transaction.update(roomRef.collection('participants').doc(uid), {
          'seatIndex': index,
          'role': 'speaker', // Switch role to speaker if they were audience
          // We don't reset isMuted if switching to avoid re-muting someone who was talking
        });
      });
    } catch (e) {
      debugPrint("Error taking seat: $e");
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

  Future<void> updateRoomSettings(String roomId, Map<String, dynamic> updates) async {
    await _db.collection('rooms').doc(roomId).update(updates);
  }

  // ⚔️ Professional PK Battle Management
  Future<Map<String, dynamic>> testConnection() async {
    final result = await callFunction('pingServer');
    final serverProjectId = result['projectId'];
    final myProjectId = 'hellochat-e8965'; // From firebase_options.dart

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
  Future<void> removeModerator(String roomId, String targetUid) async {
    await _db.collection('rooms').doc(roomId).update({
      'admins': FieldValue.arrayRemove([targetUid])
    });
  }

  Future<void> kickUser(String roomId, String targetUid) async {
    await _db.collection('rooms').doc(roomId).update({
      'bannedUids': FieldValue.arrayUnion([targetUid])
    });
    // Also remove from participants
    await _db.collection('rooms').doc(roomId).collection('participants').doc(targetUid).delete();
  }

  Future<void> clearRoomMessages(String roomId) async {
    final messages = await _db.collection('rooms').doc(roomId).collection('messages').get();
    final batch = _db.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> muteUser(String roomId, String targetUid, bool mute) async {
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
}
