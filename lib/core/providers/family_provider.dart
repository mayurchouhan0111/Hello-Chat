import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/family_service.dart';
import '../models/family_model.dart';
import '../models/family_join_request_model.dart';

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

// Helper for checking if user has already applied
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
