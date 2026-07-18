import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/relationship_model.dart';
import '../models/relationship_level_model.dart';
import '../models/relationship_reward_model.dart';
import '../models/relationship_ranking_model.dart';
import 'base_firebase_service.dart';

class RelationshipService with BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<RelationshipModel?> streamRelationship(String relationshipId) {
    return _db.collection('relationships').doc(relationshipId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return RelationshipModel.fromMap(snap.data()!, snap.id);
    });
  }

  Stream<List<RelationshipModel>> streamUserRelationships(String uid, {RelationshipType? type}) {
    Query query = _db.collection('relationships')
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: 'active');

    if (type != null) {
      query = query.where('type', isEqualTo: type == RelationshipType.cp ? 'cp' : 'friendship');
    }

    return query.snapshots().map((snap) {
      return snap.docs.map((doc) => RelationshipModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id)).toList();
    });
  }

  Stream<List<RelationshipLevelModel>> streamLevels() {
    return _db.collection('relationship_levels')
        .orderBy('level')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RelationshipLevelModel.fromMap(doc.data())).toList());
  }

  Stream<List<RelationshipRewardModel>> streamRewards() {
    return _db.collection('relationship_rewards')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RelationshipRewardModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<RelationshipRankingModel>> streamRankings(RankingPeriod period) {
    return _db.collection('relationship_rankings')
        .where('period', isEqualTo: period.name)
        .orderBy('rank')
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RelationshipRankingModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<Map<String, dynamic>> searchUsers(String query) async {
    final result = await callFunction('searchUsers', {'query': query});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> sendFriendRequest(String targetUid) async {
    final result = await callFunction('sendFriendRequest', {'targetUid': targetUid});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async {
    final result = await callFunction('acceptFriendRequest', {'requestId': requestId});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> rejectFriendRequest(String requestId) async {
    final result = await callFunction('rejectFriendRequest', {'requestId': requestId});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> removeFriend(String relationshipId) async {
    final result = await callFunction('removeFriend', {'relationshipId': relationshipId});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> sendCPInvite(String targetUid) async {
    final result = await callFunction('sendCPInvite', {'targetUid': targetUid});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> acceptCPInvite(String inviteId) async {
    final result = await callFunction('acceptCPInvite', {'inviteId': inviteId});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> dissolveCP(String relationshipId) async {
    final result = await callFunction('dissolveCP', {'relationshipId': relationshipId});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> updateIntimacy(
      String relationshipId, String source, int points) async {
    final result = await callFunction('updateIntimacy', {
      'relationshipId': relationshipId,
      'source': source,
      'points': points,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Stream<List<Map<String, dynamic>>> streamFriendRequests(String uid) {
    return _db.collection('relationship_requests')
        .where('receiverUid', isEqualTo: uid)
        .where('type', isEqualTo: 'friendship')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Stream<List<Map<String, dynamic>>> streamSentFriendRequests(String uid) {
    return _db.collection('relationship_requests')
        .where('senderUid', isEqualTo: uid)
        .where('type', isEqualTo: 'friendship')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Stream<List<Map<String, dynamic>>> streamReceivedCPInvites(String uid) {
    return _db.collection('cp_invites')
        .where('targetUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }
}
