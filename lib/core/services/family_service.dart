import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/family_model.dart';
import '../models/family_battle_model.dart';
import '../models/family_battle_request_model.dart';
import '../models/family_join_request_model.dart';
import '../models/family_member_model.dart';
import '../models/family_policy_model.dart';
import '../models/family_ranking_model.dart';

class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _families => _firestore.collection('families');
  CollectionReference get _joinRequests => _firestore.collection('familyJoinRequests');
  CollectionReference get _users => _firestore.collection('users');

  CollectionReference _members(String familyId) =>
      _families.doc(familyId).collection('members');

  // Create a family
  Future<void> createFamily({
    required String ownerId,
    required String name,
    String? tag,
    required String description,
    String? notice,
    String? avatarUrl,
    String country = '',
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
      country: country,
    );

    await docRef.set(family.toMap());

    // Create owner member doc
    await _members(docRef.id).doc(ownerId).set(FamilyMemberModel(
      id: ownerId,
      familyId: docRef.id,
      userId: ownerId,
      role: 'owner',
      memberLevel: 1,
      memberXP: 0,
      combatPoints: 0,
      contribution: 0,
      joinedAt: DateTime.now(),
    ).toMap());

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

    // Check if a pending request already exists
    final existingDoc = await docRef.get();
    if (existingDoc.exists) {
      final existingData = existingDoc.data() as Map<String, dynamic>?;
      final existingStatus = existingData?['status'] as String?;
      if (existingStatus == JoinRequestStatus.pending.name) {
        throw Exception('A pending join request already exists');
      }
      if (existingStatus == JoinRequestStatus.accepted.name) {
        throw Exception('You are already a member of this family');
      }
      if (existingStatus == JoinRequestStatus.rejected.name) {
        // Allow re-applying by deleting the old rejected request
        await docRef.delete();
      }
    }

    await docRef.set(request.toMap());
  }

  // Approve a request
  Future<void> approveRequest(FamilyJoinRequestModel request) async {
    final canJoin = await checkCapacity(request.familyId);
    if (!canJoin) throw Exception('Family is full');
    final batch = _firestore.batch();

    batch.update(_joinRequests.doc(request.id), {'status': JoinRequestStatus.accepted.name});

    batch.update(_families.doc(request.familyId), {
      'memberUids': FieldValue.arrayUnion([request.userId]),
    });

    // Create member doc
    batch.set(_members(request.familyId).doc(request.userId), FamilyMemberModel(
      id: request.userId,
      familyId: request.familyId,
      userId: request.userId,
      role: 'member',
      joinedAt: DateTime.now(),
    ).toMap());

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

  // Directly add a member (owner/admin invite)
  Future<void> addMember(String familyId, String userId) async {
    final canJoin = await checkCapacity(familyId);
    if (!canJoin) throw Exception('Family is full');
    final batch = _firestore.batch();

    batch.update(_families.doc(familyId), {
      'memberUids': FieldValue.arrayUnion([userId]),
    });

    batch.set(_members(familyId).doc(userId), FamilyMemberModel(
      id: userId,
      familyId: familyId,
      userId: userId,
      role: 'member',
      joinedAt: DateTime.now(),
    ).toMap());

    batch.update(_users.doc(userId), {
      'familyId': familyId,
      'isFamilyOwner': false,
    });

    await batch.commit();
  }

  // Remove member
  Future<void> removeMember(String familyId, String userId) async {
    final batch = _firestore.batch();

    batch.update(_families.doc(familyId), {
      'memberUids': FieldValue.arrayRemove([userId]),
    });

    batch.delete(_members(familyId).doc(userId));

    batch.update(_users.doc(userId), {
      'familyId': null,
      'isFamilyOwner': false,
    });

    await batch.commit();
  }

  // Disband family
  Future<void> disbandFamily(FamilyModel family) async {
    final batch = _firestore.batch();

    for (var uid in family.memberUids) {
      batch.update(_users.doc(uid), {
        'familyId': null,
        'isFamilyOwner': false,
      });
      batch.delete(_members(family.id).doc(uid));
    }

    final requests = await _joinRequests.where('familyId', isEqualTo: family.id).get();
    for (var doc in requests.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_families.doc(family.id));

    await batch.commit();
  }

  // Leave family
  Future<void> leaveFamily(String userId, String familyId) async {
    await removeMember(familyId, userId);
  }

  // Promote to admin
  Future<void> promoteAdmin(String familyId, String userId) async {
    await _members(familyId).doc(userId).update({'role': 'admin'});
  }

  // Demote from admin
  Future<void> demoteAdmin(String familyId, String userId) async {
    await _members(familyId).doc(userId).update({'role': 'member'});
  }

  // Rename family
  Future<void> renameFamily(String familyId, String newName) async {
    await _families.doc(familyId).update({'name': newName});
  }

  // Update family avatar
  Future<void> updateFamilyAvatar(String familyId, String avatarUrl) async {
    await _families.doc(familyId).update({'avatarUrl': avatarUrl});
  }

  // Update family banner
  Future<void> updateFamilyBanner(String familyId, String bannerUrl) async {
    await _families.doc(familyId).update({'bannerUrl': bannerUrl});
  }

  // Update monthly target
  Future<void> updateMonthlyTarget(String familyId, int target) async {
    await _families.doc(familyId).update({'monthlyTarget': target});
  }

  // Add combat points to a member and family
  Future<void> addCombatPoints(String familyId, String userId, int points) async {
    await _firestore.runTransaction((tx) async {
      final familyRef = _families.doc(familyId);
      final familySnap = await tx.get(familyRef);
      if (!familySnap.exists) return;

      final current = (familySnap.data() as Map<String, dynamic>)['totalCombatPoints'] as num? ?? 0;
      final newTotal = current.toInt() + points;
      final newLevel = FamilyModel.familyLevelForPoints(newTotal);

      tx.update(familyRef, {
        'totalCombatPoints': FieldValue.increment(points),
        'currentMonthPoints': FieldValue.increment(points),
        'level': newLevel,
      });

      tx.update(_members(familyId).doc(userId), {
        'combatPoints': FieldValue.increment(points),
        'totalBattlePoints': FieldValue.increment(points),
        'contribution': FieldValue.increment(points),
        'memberXP': FieldValue.increment(points),
      });

      tx.update(_users.doc(userId), {
        'combatPoints': FieldValue.increment(points),
      });
    });
  }

  // Get member role
  Future<String> getMemberRole(String familyId, String userId) async {
    final doc = await _members(familyId).doc(userId).get();
    if (!doc.exists) return 'none';
    return (doc.data() as Map<String, dynamic>?)?['role'] ?? 'member';
  }

  // Check capacity
  Future<bool> checkCapacity(String familyId) async {
    final doc = await _families.doc(familyId).get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>;
    final memberUids = List<String>.from(data['memberUids'] ?? []);
    final memberLimit = data['memberLimit'] ?? 100;
    return memberUids.length < memberLimit;
  }

  // Duplicate name check
  Future<bool> checkDuplicateName(String name) async {
    final snap = await _families.where('name', isEqualTo: name).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  // Update family settings (owner only)
  Future<void> updateFamilySettings(String familyId, {
    String? notice,
    String? tag,
    JoinMode? joinMode,
    int? monthlyTarget,
  }) async {
    final update = <String, dynamic>{};
    if (notice != null) update['notice'] = notice;
    if (tag != null) update['tag'] = tag;
    if (joinMode != null) update['joinMode'] = joinMode.name;
    if (monthlyTarget != null) update['monthlyTarget'] = monthlyTarget;
    if (update.isNotEmpty) {
      await _families.doc(familyId).update(update);
    }
  }

  // ─── Family Policies ──────────────────────────────────────────
  Future<void> addFamilyPolicy(String familyId, String title, String description) async {
    await _families.doc(familyId).update({
      'policies': FieldValue.arrayUnion([
        FamilyPolicyModel(title: title, description: description).toMap()
      ]),
    });
  }

  Future<void> removeFamilyPolicy(String familyId, int index) async {
    final doc = await _families.doc(familyId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final policies = List<Map<String, dynamic>>.from(data['policies'] ?? []);
    if (index < 0 || index >= policies.length) return;
    policies.removeAt(index);
    await _families.doc(familyId).update({'policies': policies});
  }

  Future<void> updateFamilyPolicy(String familyId, int index, String title, String description) async {
    final doc = await _families.doc(familyId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final policies = List<Map<String, dynamic>>.from(data['policies'] ?? []);
    if (index < 0 || index >= policies.length) return;
    policies[index] = FamilyPolicyModel(title: title, description: description).toMap();
    await _families.doc(familyId).update({'policies': policies});
  }

  Future<List<FamilyPolicyModel>> getFamilyPolicies(String familyId) async {
    final doc = await _families.doc(familyId).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    final list = List<Map<String, dynamic>>.from(data['policies'] ?? []);
    return list.map((m) => FamilyPolicyModel.fromMap(m)).toList();
  }

  // Convert diamonds to family points (1:1)
  Future<void> convertDiamondsToPoints(String familyId, String userId, int diamonds) async {
    if (diamonds <= 0) throw Exception('Amount must be positive.');

    await _firestore.runTransaction((tx) async {
      final userRef = _users.doc(userId);
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('User not found.');

      final balance = (userSnap.data() as Map<String, dynamic>)['diamondBalance'] as num? ?? 0;
      if (balance < diamonds) throw Exception('Insufficient diamonds.');

      final familyRef = _families.doc(familyId);
      final familySnap = await tx.get(familyRef);
      if (!familySnap.exists) throw Exception('Family not found.');

      final current = (familySnap.data() as Map<String, dynamic>)['totalCombatPoints'] as num? ?? 0;
      final newTotal = current.toInt() + diamonds;
      final newLevel = FamilyModel.familyLevelForPoints(newTotal);

      final memberRef = _members(familyId).doc(userId);
      final memberSnap = await tx.get(memberRef);
      final memberData = memberSnap.data() as Map<String, dynamic>?;
      final currentDiamondsSent = memberData?['totalDiamondsSent'] as num? ?? 0;
      final currentBattlePoints = memberData?['totalBattlePoints'] as num? ?? 0;
      final currentContribution = memberData?['contribution'] as num? ?? 0;
      final history = List<Map<String, dynamic>>.from(memberData?['contributionHistory'] ?? []);
      history.add({
        'type': 'diamond_conversion',
        'amount': diamonds,
        'points': diamonds,
        'timestamp': DateTime.now().toIso8601String(),
      });

      tx.update(userRef, {'diamondBalance': FieldValue.increment(-diamonds)});
      tx.update(familyRef, {
        'totalCombatPoints': FieldValue.increment(diamonds),
        'totalDiamonds': FieldValue.increment(diamonds),
        'currentMonthPoints': FieldValue.increment(diamonds),
        'level': newLevel,
      });
      tx.update(memberRef, {
        'totalDiamondsSent': FieldValue.increment(diamonds),
        'totalBattlePoints': FieldValue.increment(diamonds),
        'contribution': FieldValue.increment(diamonds),
        'combatPoints': FieldValue.increment(diamonds),
        'memberXP': FieldValue.increment(diamonds),
        'contributionHistory': history,
      });
    });
  }

  // ─── Rankings ──────────────────────────────────────────────────
  CollectionReference get _rankings => _firestore.collection('familyRankings');

  Stream<List<FamilyRankingModel>> streamRankings(RankingPeriod period) {
    return _rankings
        .where('period', isEqualTo: period.name)
        .orderBy('rank')
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FamilyRankingModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Transfer ownership via Cloud Function
  Future<void> transferOwnership(String familyId, String newOwnerUid) async {
    await FirebaseFunctions.instance.httpsCallable('transferFamilyOwnership').call({
      'familyId': familyId,
      'newOwnerUid': newOwnerUid,
    });
  }

  // Kick member (alias for removeMember)
  Future<void> kickMember(String familyId, String userId) =>
      removeMember(familyId, userId);

  // ─── Battle Requests ──────────────────────────────────────────
  CollectionReference get _battleRequests =>
      _firestore.collection('familyBattleRequests');

  Future<void> sendBattleRequest({
    int cost = 0,
    required String challengerFamilyId,
    required String opponentFamilyId,
    String? challengerImageUrl,
    String? challengerUid,
  }) async {
    final existing = await _battleRequests
        .where('challengerFamilyId', isEqualTo: challengerFamilyId)
        .where('opponentFamilyId', isEqualTo: opponentFamilyId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('A pending battle request already exists between these families.');
    }

    final challengerDoc = await _families.doc(challengerFamilyId).get();
    final opponentDoc = await _families.doc(opponentFamilyId).get();
    final challenger = FamilyModel.fromMap(challengerDoc.data() as Map<String, dynamic>, challengerDoc.id);
    final opponent = FamilyModel.fromMap(opponentDoc.data() as Map<String, dynamic>, opponentDoc.id);

    // Use transaction to atomically create request and deduct diamonds if needed
    await _firestore.runTransaction((tx) async {
      // Deduct diamonds from challenger if a cost is specified
      if (cost > 0 && challengerUid != null) {
        final userRef = _users.doc(challengerUid);
        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) throw Exception('User not found.');
        final balance = (userSnap.data() as Map<String, dynamic>)['diamondBalance'] as num? ?? 0;
        if (balance < cost) throw Exception('Insufficient diamonds.');
        tx.update(userRef, {'diamondBalance': FieldValue.increment(-cost)});
      }

      // Create battle request document
      final reqRef = _battleRequests.doc();
      tx.set(reqRef, FamilyBattleRequestModel(
        id: reqRef.id,
        challengerFamilyId: challengerFamilyId,
        challengerName: challenger.name,
        challengerAvatar: challenger.avatarUrl,
        opponentFamilyId: opponentFamilyId,
        opponentName: opponent.name,
        opponentAvatar: opponent.avatarUrl,
        imageUrl: challengerImageUrl,
        createdAt: DateTime.now(),
      ).toMap());
    });
  }

  /// Deduct diamonds to grant battle access for the user.
  Future<void> purchaseBattleAccess({
    required String uid,
    int cost = 0,
  }) async {
    if (cost <= 0) return;
    await _firestore.runTransaction((tx) async {
      final userRef = _users.doc(uid);
      final snap = await tx.get(userRef);
      if (!snap.exists) throw Exception('User not found.');
      final balance = (snap.data() as Map<String, dynamic>)['diamondBalance'] as num? ?? 0;
      if (balance < cost) throw Exception('Insufficient diamonds.');
      tx.update(userRef, {'diamondBalance': FieldValue.increment(-cost)});
    });
  }

  /// Call server-side [acceptFamilyBattle] which validates:
  /// - pending request, no active battles for either family
  /// - participant capacity per level
  /// - per-user active battle limit (currentActiveBattleId)
  /// Creates mirrored battle docs + audit log in a Firestore transaction.
  Future<void> acceptBattleRequest(String requestId, String challengerId, String opponentId) async {
    final fn = FirebaseFunctions.instance.httpsCallable('acceptFamilyBattle');
    try {
      await fn({'requestId': requestId});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to accept battle.');
    }
  }

  Future<void> rejectBattleRequest(String requestId) async {
    final requestDoc = await _battleRequests.doc(requestId).get();
    if (!requestDoc.exists) {
      print('[FAMILY] Battle request $requestId not found for rejection.');
      return;
    }
    final data = requestDoc.data() as Map<String, dynamic>?;
    final status = data?['status'] as String?;
    if (status == 'rejected') {
      print('[FAMILY] Battle request $requestId already rejected.');
      return;
    }
    if (status == 'accepted') {
      print('[FAMILY] Battle request $requestId already accepted.');
      return;
    }
    await _battleRequests.doc(requestId).update({'status': 'rejected'});
  }

  Stream<List<FamilyBattleRequestModel>> streamIncomingBattleRequests(String familyId) {
    return _battleRequests
        .where('opponentFamilyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FamilyBattleRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<FamilyBattleRequestModel>> streamSentBattleRequests(String familyId) {
    return _battleRequests
        .where('challengerFamilyId', isEqualTo: familyId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FamilyBattleRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  CollectionReference _battles(String familyId) =>
      _families.doc(familyId).collection('battles');

  // Create a battle between two families
  Future<String> createBattle(String familyAId, String familyBId, {String? imageUrl}) async {
    final familyADoc = await _families.doc(familyAId).get();
    final familyBDoc = await _families.doc(familyBId).get();
    final familyA = FamilyModel.fromMap(familyADoc.data() as Map<String, dynamic>, familyADoc.id);
    final familyB = FamilyModel.fromMap(familyBDoc.data() as Map<String, dynamic>, familyBDoc.id);

    final battleRef = _battles(familyAId).doc();
    final now = DateTime.now();

    await battleRef.set(FamilyBattleModel(
      id: battleRef.id,
      familyAId: familyAId,
      familyBId: familyBId,
      familyAName: familyA.name,
      familyBName: familyB.name,
      familyAAvatar: familyA.avatarUrl,
      familyBAvatar: familyB.avatarUrl,
      imageUrl: imageUrl,
      startedAt: now,
      durationSeconds: 180,
      status: 'active',
    ).toMap());

    // Mirror to opponent's battles subcollection
    await _battles(familyBId).doc(battleRef.id).set(FamilyBattleModel(
      id: battleRef.id,
      familyAId: familyAId,
      familyBId: familyBId,
      familyAName: familyA.name,
      familyBName: familyB.name,
      familyAAvatar: familyA.avatarUrl,
      familyBAvatar: familyB.avatarUrl,
      imageUrl: imageUrl,
      startedAt: now,
      durationSeconds: 180,
      status: 'active',
    ).toMap());

    return battleRef.id;
  }

  /// Call server-side [scoreBattleTap] which validates:
  /// - active battle status, user participation
  /// - 300ms per-user rate limit
  /// Increments points server-side + updates member contribution.
  Future<void> scoreBattleTap(String battleId, String familyId, String opponentFamilyId, String userId, {int diamondAmount = 1}) async {
    final fn = FirebaseFunctions.instance.httpsCallable('scoreBattleTap');
    try {
      await fn({
        'battleId': battleId,
        'familyId': familyId,
        'points': diamondAmount,
      });
    } on FirebaseFunctionsException catch (e) {
      // Silently fail on rate-limit to avoid disrupting UX
      if (e.code == 'resource-exhausted') return;
      print('[FAMILY_BATTLE] Tap error: ${e.message}');
    }
  }

  // End battle and declare winner
  Future<void> endBattle(String battleId, String familyAId, String familyBId) async {
    final aDoc = await _battles(familyAId).doc(battleId).get();
    if (!aDoc.exists) return;
    final aPts = aDoc.get('familyAPoints') as int? ?? 0;
    final bPts = aDoc.get('familyBPoints') as int? ?? 0;

    String? winnerId;
    if (aPts > bPts) winnerId = familyAId;
    else if (bPts > aPts) winnerId = familyBId;

    final batch = _firestore.batch();
    final data = aDoc.data() as Map<String, dynamic>;

    // Update family A copy
    batch.update(_battles(familyAId).doc(battleId), {
      'status': 'completed',
      'winnerId': winnerId,
    });

    // Update or create family B copy
    final bDoc = await _battles(familyBId).doc(battleId).get();
    if (bDoc.exists) {
      batch.update(_battles(familyBId).doc(battleId), {
        'status': 'completed',
        'winnerId': winnerId,
      });
    } else {
      batch.set(_battles(familyBId).doc(battleId), {
        ...data,
        'status': 'completed',
        'winnerId': winnerId,
      });
    }

    // Award battle points to winner
    if (winnerId != null) {
      final gained = 500;
      batch.update(_families.doc(winnerId), {
        'totalBattlePoints': FieldValue.increment(gained),
      });
    }

    await batch.commit();
  }

  // Stream active battle for a family
  Stream<FamilyBattleModel?> streamActiveBattle(String familyId) {
    return _battles(familyId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          return FamilyBattleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        });
  }

  // Stream battle history for a family
  Stream<List<FamilyBattleModel>> streamBattleHistory(String familyId) {
    return _battles(familyId)
        .where('status', isEqualTo: 'completed')
        .orderBy('startedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FamilyBattleModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
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

  Stream<List<FamilyMemberModel>> streamFamilyMembers(String familyId) {
    return _members(familyId)
        .orderBy('combatPoints', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FamilyMemberModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<FamilyMemberModel?> streamFamilyMember(String familyId, String userId) {
    return _members(familyId).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return FamilyMemberModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }
}
