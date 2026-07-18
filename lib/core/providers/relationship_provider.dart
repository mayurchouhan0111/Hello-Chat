import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/relationship_service.dart';
import '../models/relationship_model.dart';
import '../models/relationship_level_model.dart';
import '../models/relationship_reward_model.dart';
import '../models/relationship_ranking_model.dart';

final relationshipServiceProvider = Provider<RelationshipService>((ref) {
  return RelationshipService();
});

final relationshipStreamProvider =
    StreamProvider.family<RelationshipModel?, String>((ref, id) {
  return ref.watch(relationshipServiceProvider).streamRelationship(id);
});

final userRelationshipsProvider =
    StreamProvider.family<List<RelationshipModel>, String>((ref, uid) {
  return ref.watch(relationshipServiceProvider).streamUserRelationships(uid);
});

final userFriendshipsProvider =
    StreamProvider.family<List<RelationshipModel>, String>((ref, uid) {
  return ref
      .watch(relationshipServiceProvider)
      .streamUserRelationships(uid, type: RelationshipType.friendship);
});

final userCPProvider =
    StreamProvider.family<RelationshipModel?, String>((ref, uid) {
  return ref
      .watch(relationshipServiceProvider)
      .streamUserRelationships(uid, type: RelationshipType.cp)
      .map((list) => list.isNotEmpty ? list.first : null);
});

final relationshipLevelsProvider = StreamProvider<List<RelationshipLevelModel>>((ref) {
  return ref.watch(relationshipServiceProvider).streamLevels();
});

final relationshipRewardsProvider = StreamProvider<List<RelationshipRewardModel>>((ref) {
  return ref.watch(relationshipServiceProvider).streamRewards();
});

final relationshipRankingsProvider =
    StreamProvider.family<List<RelationshipRankingModel>, RankingPeriod>((ref, period) {
  return ref.watch(relationshipServiceProvider).streamRankings(period);
});

final friendRequestProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(relationshipServiceProvider).streamFriendRequests(uid);
});

final sentFriendRequestsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(relationshipServiceProvider).streamSentFriendRequests(uid);
});

final receivedCPInvitesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(relationshipServiceProvider).streamReceivedCPInvites(uid);
});
