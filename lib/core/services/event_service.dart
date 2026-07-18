import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../providers/auth_provider.dart';
import 'base_firebase_service.dart';

final eventServiceProvider = Provider<EventService>((ref) => EventService());

final activeEventsProvider = StreamProvider<List<EventModel>>((ref) {
  return ref.watch(eventServiceProvider).getActiveEvents();
});

final activeEventByTypeProvider = StreamProvider.family<EventModel?, String>((ref, type) {
  return ref.watch(eventServiceProvider).getActiveEventByType(type);
});

final eventByIdProvider = FutureProvider.family<EventModel?, String>((ref, eventId) async {
  return ref.watch(eventServiceProvider).getEventById(eventId);
});

final rechargePackagesProvider = StreamProvider.family<List<RechargePackageModel>, String>((ref, eventId) {
  return ref.watch(eventServiceProvider).getRechargePackages(eventId);
});

final rechargeMilestonesProvider = StreamProvider.family<List<RechargeMilestoneModel>, String>((ref, eventId) {
  return ref.watch(eventServiceProvider).getRechargeMilestones(eventId);
});

final userEventProgressProvider = FutureProvider.family<UserEventProgressModel?, String>((ref, eventId) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final service = ref.watch(eventServiceProvider);
  return service.getUserEventProgress(eventId);
});

class EventService with BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<EventModel>> getActiveEvents() {
    final now = Timestamp.now();
    return _db
        .collection('dynamic_events')
        .where('isActive', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: now)
        .where('endDate', isGreaterThanOrEqualTo: now)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => EventModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<EventModel?> getActiveEventByType(String type) {
    final now = Timestamp.now();
    return _db
        .collection('dynamic_events')
        .where('isActive', isEqualTo: true)
        .where('type', isEqualTo: type)
        .where('startDate', isLessThanOrEqualTo: now)
        .where('endDate', isGreaterThanOrEqualTo: now)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return EventModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
    });
  }

  Future<EventModel?> getEventById(String eventId) async {
    final doc = await _db.collection('dynamic_events').doc(eventId).get();
    if (!doc.exists) return null;
    return EventModel.fromMap(doc.data()!, doc.id);
  }

  Stream<List<RechargePackageModel>> getRechargePackages(String eventId) {
    return _db
        .collection('recharge_bonus_packages')
        .where('eventId', isEqualTo: eventId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RechargePackageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<RechargeMilestoneModel>> getRechargeMilestones(String eventId) {
    return _db
        .collection('recharge_milestones')
        .where('eventId', isEqualTo: eventId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RechargeMilestoneModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<UserEventProgressModel?> getUserEventProgress(String eventId) async {
    try {
      final result = await callFunction('getUserEventProgress', {'eventId': eventId});
      if (result == null) return null;
      final data = castMap(result);
      return UserEventProgressModel(
        uid: data['uid'] ?? '',
        eventId: eventId,
        progress: (data['progress'] as num?)?.toInt() ?? 0,
        claimedMilestones: List<String>.from(data['claimedMilestones'] ?? []),
      );
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> processRechargeBonus(int amount) async {
    try {
      final result = await callFunction('processRechargeBonus', {'amount': amount});
      return castMap(result);
    } catch (e) {
      return {'bonus': 0, 'eventId': null};
    }
  }

  Future<Map<String, dynamic>> trackRechargeMilestone(int amount, {bool includeBonus = false}) async {
    try {
      final result = await callFunction('trackRechargeMilestone', {
        'amount': amount,
        'includeBonus': includeBonus,
      });
      return castMap(result);
    } catch (e) {
      return {'progress': 0, 'milestones': [], 'newlyClaimed': []};
    }
  }

  Future<Map<String, dynamic>> claimMilestoneReward(String eventId, String milestoneId) async {
    try {
      final result = await callFunction('claimMilestoneReward', {
        'eventId': eventId,
        'milestoneId': milestoneId,
      });
      return castMap(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> enhancedRecharge(int amount, {String? packageId}) async {
    try {
      final result = await callFunction('enhancedRecharge', {
        'amount': amount,
        'packageId': packageId ?? '',
      });
      return castMap(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
