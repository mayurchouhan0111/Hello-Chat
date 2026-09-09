import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/gift_event_model.dart';
import 'base_firebase_service.dart';

final giftEventServiceProvider = Provider<GiftEventService>((ref) => GiftEventService());

/// Streams all currently active gift events within the active date window
final activeGiftEventsStreamProvider = StreamProvider<List<GiftEventModel>>((ref) {
  return ref.watch(giftEventServiceProvider).getActiveGiftEvents();
});

/// Primary active gift event (if any is currently live)
final primaryActiveGiftEventProvider = Provider<GiftEventModel?>((ref) {
  final eventsAsync = ref.watch(activeGiftEventsStreamProvider);
  return eventsAsync.valueOrNull?.isNotEmpty == true ? eventsAsync.value!.first : null;
});

/// Streams top participants for an event leaderboard
final giftEventLeaderboardProvider = StreamProvider.family<List<EventParticipant>, String>((ref, eventId) {
  if (eventId.isEmpty) return Stream.value([]);
  return ref.watch(giftEventServiceProvider).getEventLeaderboard(eventId);
});

/// Streams the authenticated user's current progress/rank for an event
final currentUserEventProgressProvider = StreamProvider.family<EventParticipant?, String>((ref, eventId) {
  if (eventId.isEmpty) return Stream.value(null);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(giftEventServiceProvider).getUserEventProgress(eventId, uid);
});

class GiftEventService with BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream active gift events ordered by priority/start date
  Stream<List<GiftEventModel>> getActiveGiftEvents() {
    return _db
        .collection('gift_events')
        .snapshots()
        .map((snap) {
          final currentMs = DateTime.now().millisecondsSinceEpoch;
          return snap.docs
              .map((doc) => GiftEventModel.fromMap(doc.data(), doc.id))
              .filterActive(currentMs);
        });
  }

  /// Get specific event by ID stream
  Stream<GiftEventModel?> getEventByIdStream(String eventId) {
    return _db.collection('gift_events').doc(eventId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GiftEventModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Stream live leaderboard of participants ordered by points
  Stream<List<EventParticipant>> getEventLeaderboard(String eventId, {int limit = 50}) {
    return _db
        .collection('gift_events')
        .doc(eventId)
        .collection('participants')
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          return snap.docs.asMap().entries.map((entry) {
            final idx = entry.key;
            final doc = entry.value;
            return EventParticipant.fromMap(doc.data(), doc.id, rank: idx + 1);
          }).toList();
        });
  }

  /// Stream specific participant status in event
  Stream<EventParticipant?> getUserEventProgress(String eventId, String uid) {
    return _db
        .collection('gift_events')
        .doc(eventId)
        .collection('participants')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return EventParticipant.fromMap(doc.data()!, doc.id);
        });
  }
}

extension GiftEventListExtension on Iterable<GiftEventModel> {
  List<GiftEventModel> filterActive(int currentMs) {
    return where((ev) => ev.endDate.millisecondsSinceEpoch >= currentMs).toList();
  }
}
