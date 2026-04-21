import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_model.dart';
import '../models/family_join_request_model.dart';

class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _families => _firestore.collection('families');
  CollectionReference get _joinRequests => _firestore.collection('familyJoinRequests');
  CollectionReference get _users => _firestore.collection('users');

  // Create a family
  Future<void> createFamily({
    required String ownerId,
    required String name,
    String? tag,
    required String description,
    String? notice,
    String? avatarUrl,
    JoinMode joinMode = JoinMode.free,
    int levelRequirement = 0,
  }) async {
    final docRef = _families.doc();
    final family = FamilyModel(
      id: docRef.id,
      name: name,
      tag: tag,
      description: description,
      notice: notice,
      ownerId: ownerId,
      avatarUrl: avatarUrl,
      memberUids: [ownerId],
      createdAt: DateTime.now(),
      joinMode: joinMode,
      levelRequirement: levelRequirement,
    );

    await docRef.set(family.toMap());
    
    // Update user model
    await _users.doc(ownerId).update({
      'familyId': docRef.id,
      'isFamilyOwner': true,
    });
  }

  // Apply to join a family
  Future<void> applyToJoin({
    required String userId,
    required String familyId,
    required String userName,
    required String userAvatar,
  }) async {
    final docRef = _joinRequests.doc('${userId}_$familyId');
    final request = FamilyJoinRequestModel(
      id: docRef.id,
      userId: userId,
      familyId: familyId,
      userName: userName,
      userAvatar: userAvatar,
      status: JoinRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    await docRef.set(request.toMap());
  }

  // Approve a request
  Future<void> approveRequest(FamilyJoinRequestModel request) async {
    final batch = _firestore.batch();

    // 1. Update request status
    batch.update(_joinRequests.doc(request.id), {'status': JoinRequestStatus.accepted.name});

    // 2. Add user to family member list
    batch.update(_families.doc(request.familyId), {
      'memberUids': FieldValue.arrayUnion([request.userId])
    });

    // 3. Update user's familyId
    batch.update(_users.doc(request.userId), {
      'familyId': request.familyId,
      'isFamilyOwner': false,
    });

    await batch.commit();
  }

  // Reject a request
  Future<void> rejectRequest(String requestId) async {
    await _joinRequests.doc(requestId).update({'status': JoinRequestStatus.rejected.name});
  }

  // Remove member
  Future<void> removeMember(String familyId, String userId) async {
    final batch = _firestore.batch();

    batch.update(_families.doc(familyId), {
      'memberUids': FieldValue.arrayRemove([userId])
    });

    batch.update(_users.doc(userId), {
      'familyId': null,
      'isFamilyOwner': false,
    });

    await batch.commit();
  }

  // Disband family
  Future<void> disbandFamily(FamilyModel family) async {
    final batch = _firestore.batch();

    // 1. Clear family info from all members
    for (var uid in family.memberUids) {
      batch.update(_users.doc(uid), {
        'familyId': null,
        'isFamilyOwner': false,
      });
    }

    // 2. Clear pull requests
    final requests = await _joinRequests.where('familyId', isEqualTo: family.id).get();
    for (var doc in requests.docs) {
      batch.delete(doc.reference);
    }

    // 3. Delete family doc
    batch.delete(_families.doc(family.id));

    await batch.commit();
  }

  // Leave family
  Future<void> leaveFamily(String userId, String familyId) async {
    await removeMember(familyId, userId);
  }

  // DEVELOPER TOOLS: Simulation
  Future<void> seedMockMembers(String familyId) async {
    final batch = _firestore.batch();
    final names = ["Alpha_Warrior", "Nebula_PK", "Ghost_Rider", "Storm_Master", "Shadow_Blade"];
    
    for (int i = 0; i < 5; i++) {
      final fakeUid = 'sim_${familyId}_$i';
      final combatPts = 1000 + (i * 500);
      
      // Create user
      batch.set(_users.doc(fakeUid), {
        'uid': fakeUid,
        'displayName': names[i],
        'username': names[i].toLowerCase(),
        'profilePhotoUrl': 'https://api.dicebear.com/7.x/avataaars/png?seed=${names[i]}',
        'combatPoints': combatPts,
        'familyId': familyId,
        'isFamilyOwner': false,
        'level': 10 + i,
      });

      // Add to family
      batch.update(_families.doc(familyId), {
        'memberUids': FieldValue.arrayUnion([fakeUid]),
        'totalCombatPoints': FieldValue.increment(combatPts),
      });
    }
    await batch.commit();
  }

  Future<void> simulateBattleWin(FamilyModel family) async {
    await _families.doc(family.id).update({
      'totalBattlePoints': FieldValue.increment(1000),
      // Auto-level up if points exceed threshold
      if ((family.totalBattlePoints + 1000) >= family.level * 5000) 
        'level': FieldValue.increment(1)
    });
  }

  // Streams
  Stream<FamilyModel?> streamFamily(String familyId) {
    return _families.doc(familyId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return FamilyModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Stream<List<FamilyJoinRequestModel>> streamPendingRequests(String familyId) {
    return _joinRequests
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: JoinRequestStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FamilyJoinRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<FamilyModel>> streamAllFamilies() {
    return _families.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => FamilyModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }
}
