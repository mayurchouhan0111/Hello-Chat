import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/models/room_model.dart';
import '../core/models/participant_model.dart';

class RoomService {
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

  // 1. Create Room (Frontend Version)
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
    
    // Add creator as participant
    final participantRef = roomRef.collection('participants').doc(uid);
    batch.set(participantRef, {
      'uid': uid,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
      'seatIndex': 0,
      'isMuted': false,
    });

    await batch.commit();
    return roomId;
  }

  // 2. Join Room (Frontend Version)
  Future<void> joinRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in.");

    final roomRef = _db.collection('rooms').doc(roomId);
    
    return _db.runTransaction((transaction) async {
      final roomDoc = await transaction.get(roomRef);
      if (!roomDoc.exists) throw Exception("Room does not exist.");
      
      final roomData = roomDoc.data()!;
      final bannedUids = List<String>.from(roomData['bannedUids'] ?? []);
      if (bannedUids.contains(uid)) throw Exception("You are banned from this room.");

      final participantRef = roomRef.collection('participants').doc(uid);
      transaction.set(participantRef, {
        'uid': uid,
        'role': 'listener',
        'joinedAt': FieldValue.serverTimestamp(),
        'seatIndex': -1,
        'isMuted': false,
      });

      transaction.update(roomRef, {
        'currentUsersCount': FieldValue.increment(1),
      });
    });
  }

  // 3. Leave Room (Frontend Version) - FIXES HOST LEAVE BUG
  Future<void> leaveRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final roomRef = _db.collection('rooms').doc(roomId);
    
    return _db.runTransaction((transaction) async {
      final roomDoc = await transaction.get(roomRef);
      if (!roomDoc.exists) return;

      final isOwner = roomDoc.data()?['ownerUid'] == uid;

      // Remove from participants
      transaction.delete(roomRef.collection('participants').doc(uid));

      if (isOwner) {
        // If owner leaves, room should either end or just stay active?
        // Standard behavior is room ends if creator leaves for long.
        // For now, let's keep it active but decrement count.
        transaction.update(roomRef, {
          'currentUsersCount': FieldValue.increment(-1),
        });
      } else {
        transaction.update(roomRef, {
          'currentUsersCount': FieldValue.increment(-1),
        });
      }
    });
  }

  // 4. End Room (Frontend Version)
  Future<void> endRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('rooms').doc(roomId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestMic(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('rooms').doc(roomId).collection('micRequests').doc(uid).set({
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> grantMic(String roomId, String targetUid, int seatIndex) async {
    final batch = _db.batch();
    final roomRef = _db.collection('rooms').doc(roomId);
    
    batch.update(roomRef.collection('participants').doc(targetUid), {
      'role': 'speaker',
      'seatIndex': seatIndex,
    });
    batch.delete(roomRef.collection('micRequests').doc(targetUid));
    
    await batch.commit();
  }

  Future<void> kickUser(String roomId, String targetUid) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    await _db.runTransaction((transaction) async {
      transaction.delete(roomRef.collection('participants').doc(targetUid));
      transaction.update(roomRef, {
        'bannedUids': FieldValue.arrayUnion([targetUid]),
        'currentUsersCount': FieldValue.increment(-1),
      });
    });
  }

  Future<void> muteUser(String roomId, String targetUid, bool mute) async {
    await _db.collection('rooms').doc(roomId).collection('participants').doc(targetUid).update({
      'isMuted': mute,
    });
  }

  // 5. Start PK Battle (Frontend Version)
  Future<void> startPKBattle({
    required String roomId,
    required String leftUid,
    required String rightUid,
    int durationSeconds = 300,
  }) async {
    final now = DateTime.now();
    final endTime = now.add(Duration(seconds: durationSeconds));

    await _db.collection('rooms').doc(roomId).update({
      'pkActive': true,
      'pkStartTime': FieldValue.serverTimestamp(),
      'pkEndTime': Timestamp.fromDate(endTime),
      'pkScores': {leftUid: 0, rightUid: 0},
      'pkTeams': {leftUid: 'left', rightUid: 'right'},
      'pkWinnerUid': null,
    });
  }

  Future<void> endPKBattle(String roomId) async {
    await _db.collection('rooms').doc(roomId).update({
      'pkActive': false,
      'pkWinnerUid': null, // Logic to determine winner can be added here
    });
  }
}
