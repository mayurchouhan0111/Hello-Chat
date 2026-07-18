import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/family_service.dart';
import '../models/family_model.dart';
import '../models/family_battle_model.dart';
import '../models/family_battle_request_model.dart';
import '../models/family_join_request_model.dart';
import '../models/family_member_model.dart';
import '../models/family_policy_model.dart';
import '../models/family_ranking_model.dart';

final familyServiceProvider = Provider((ref) => FamilyService());

final familyStreamProvider = StreamProvider.family<FamilyModel?, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).streamFamily(familyId);
});

final pendingRequestsProvider = StreamProvider.family<List<FamilyJoinRequestModel>, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).streamPendingRequests(familyId);
});

final allFamiliesProvider = StreamProvider<List<FamilyModel>>((ref) {
  return ref.watch(familyServiceProvider).streamAllFamilies();
});

final familyMembersProvider = StreamProvider.family<List<FamilyMemberModel>, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).streamFamilyMembers(familyId);
});

final familyRankingsProvider = StreamProvider.family<List<FamilyRankingModel>, RankingPeriod>((ref, period) {
  return ref.watch(familyServiceProvider).streamRankings(period);
});

final familyPoliciesProvider = FutureProvider.family<List<FamilyPolicyModel>, String>((ref, familyId) async {
  return ref.watch(familyServiceProvider).getFamilyPolicies(familyId);
});

final familyMemberProvider = StreamProvider.family<FamilyMemberModel?, ({String familyId, String userId})>((ref, arg) {
  return ref.watch(familyServiceProvider).streamFamilyMember(arg.familyId, arg.userId);
});

final userApplicationStatusProvider = StreamProvider.family<JoinRequestStatus?, ({String userId, String familyId})>((ref, arg) {
  return FirebaseFirestore.instance
      .collection('familyJoinRequests')
      .doc('${arg.userId}_${arg.familyId}')
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        final data = doc.data() as Map<String, dynamic>;
        return JoinRequestStatus.values.firstWhere((e) => e.name == data['status']);
      });
});

final activeBattleProvider = StreamProvider.family<FamilyBattleModel?, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).streamActiveBattle(familyId);
});

final battleHistoryProvider = StreamProvider.family<List<FamilyBattleModel>, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).streamBattleHistory(familyId);
});

final incomingBattleRequestsProvider = StreamProvider.family<List<FamilyBattleRequestModel>, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).streamIncomingBattleRequests(familyId);
});

final sentBattleRequestsProvider = StreamProvider.family<List<FamilyBattleRequestModel>, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).streamSentBattleRequests(familyId);
});
