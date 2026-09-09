import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/gift_event_model.dart';

void main() {
  group('Gift Event System Tests', () {
    test('EventGiftItem serialization and point mapping', () {
      final gift = EventGiftItem(
        giftId: 'royal_carriage',
        name: 'Royal Carriage',
        priceInDiamonds: 8000,
        eventPoints: 16000,
        imageUrl: 'assets/svga/235.svga',
      );

      final map = gift.toMap();
      expect(map['giftId'], 'royal_carriage');
      expect(map['priceInDiamonds'], 8000);
      expect(map['eventPoints'], 16000);

      final reconstructed = EventGiftItem.fromMap(map);
      expect(reconstructed.giftId, 'royal_carriage');
      expect(reconstructed.eventPoints, 16000);
    });

    test('EventRewardTier serialization and rank range', () {
      final tier = EventRewardTier(
        rankFrom: 1,
        rankTo: 1,
        title: 'Rank 1 Champion',
        diamonds: 500000,
        frameUrl: 'assets/VIP/VIP 1/Frame.svga',
        frameDays: 30,
        badgeTitle: 'Carnival King',
        customReward: 'Golden Aura',
      );

      final map = tier.toMap();
      expect(map['rankFrom'], 1);
      expect(map['rankTo'], 1);
      expect(map['diamonds'], 500000);
      expect(map['frameDays'], 30);

      final reconstructed = EventRewardTier.fromMap(map);
      expect(reconstructed.title, 'Rank 1 Champion');
      expect(reconstructed.diamonds, 500000);
    });

    test('GiftEventModel active window and duration evaluation', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 2));
      final future = now.add(const Duration(days: 5));

      final activeEvent = GiftEventModel(
        id: 'event_spring_2026',
        title: 'Spring Carnival',
        description: 'Collect event points',
        startDate: past,
        endDate: future,
        isActive: true,
        gifts: [
          const EventGiftItem(giftId: 'rose', name: 'Rose', priceInDiamonds: 50, eventPoints: 100),
          const EventGiftItem(giftId: 'rocket', name: 'Rocket', priceInDiamonds: 5000, eventPoints: 10000),
        ],
        rewards: [
          const EventRewardTier(rankFrom: 1, rankTo: 1, title: 'Champion', diamonds: 100000),
        ],
      );

      expect(activeEvent.isLive, isTrue);
      expect(activeEvent.remainingDuration.inDays, greaterThanOrEqualTo(4));

      // Inactive event test
      final disabledEvent = GiftEventModel(
        id: 'event_disabled',
        title: 'Disabled Event',
        startDate: past,
        endDate: future,
        isActive: false,
      );
      expect(disabledEvent.isLive, isFalse);

      // Ended event test
      final endedEvent = GiftEventModel(
        id: 'event_ended',
        title: 'Ended Event',
        startDate: past.subtract(const Duration(days: 10)),
        endDate: past,
        isActive: true,
      );
      expect(endedEvent.isLive, isFalse);
      expect(endedEvent.remainingDuration, Duration.zero);
    });

    test('Event Points accrual math matches specification', () {
      const giftItem = EventGiftItem(
        giftId: 'lucky_chest',
        name: 'Lucky Chest',
        priceInDiamonds: 100000,
        eventPoints: 200000,
      );

      const quantity = 5;
      final totalEarned = giftItem.eventPoints * quantity;
      expect(totalEarned, 1000000);
    });

    test('EventParticipant serialization and leaderboard ranking', () {
      final rawDocs = [
        {'displayName': 'Alpha', 'points': 50000, 'giftCount': 10, 'diamondsSpent': 25000},
        {'displayName': 'Beta', 'points': 85000, 'giftCount': 15, 'diamondsSpent': 40000},
        {'displayName': 'Gamma', 'points': 120000, 'giftCount': 22, 'diamondsSpent': 60000},
      ];

      // Sort descending by points
      rawDocs.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

      final participants = rawDocs.asMap().entries.map((entry) {
        return EventParticipant.fromMap(entry.value, 'user_${entry.key}', rank: entry.key + 1);
      }).toList();

      expect(participants[0].displayName, 'Gamma');
      expect(participants[0].rank, 1);
      expect(participants[1].displayName, 'Beta');
      expect(participants[1].rank, 2);
      expect(participants[2].displayName, 'Alpha');
      expect(participants[2].rank, 3);
    });
  });
}
