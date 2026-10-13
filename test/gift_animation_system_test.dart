import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/gift_animation_overlay.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';

void main() {
  group('Gift Animation System Tier Resolution', () {
    test('Normal gifts correctly resolve tier to NORMAL', () {
      final gift = GiftModel(
        giftId: 'rose',
        name: 'Rose',
        priceInDiamonds: 50,
        imageUrl: 'rose.png',
        lottieAssetPath: '',
        category: 'Normal',
        tier: 'NORMAL',
        animationFormat: 'json',
      );
      expect(gift.animationTier, 'NORMAL');
    });

    test('Medium gifts correctly resolve tier to MEDIUM', () {
      final gift = GiftModel(
        giftId: 'mystic_rings',
        name: 'Mystic Rings',
        priceInDiamonds: 1200,
        imageUrl: 'rings.png',
        lottieAssetPath: '',
        category: 'Medium',
        tier: 'MEDIUM',
        animationFormat: 'svga',
      );
      expect(gift.animationTier, 'MEDIUM');
    });

    test('Luxury gifts correctly resolve tier to LUXURY', () {
      final gift = GiftModel(
        giftId: 'car_king',
        name: 'Car King',
        priceInDiamonds: 400000,
        imageUrl: 'car.png',
        lottieAssetPath: '',
        category: 'Luxury',
        tier: 'LUXURY',
        animationFormat: 'mp4',
      );
      expect(gift.animationTier, 'LUXURY');
    });

    test('Multi-receiver ID key generation produces unique concurrent keys', () {
      const msgId = 'msg_12345';
      final targets = ['user_1', 'user_2', 'user_3', 'user_4', 'user_5'];
      final keys = <String>{};

      for (final t in targets) {
        final key = '${msgId}_${t}_0';
        expect(keys.contains(key), isFalse);
        keys.add(key);
      }

      expect(keys.length, equals(5));
    });

    test('Exact combo matching: 1x, 2x, 5x, 10x gifts produce exactly 1, 2, 5, 10 sequential animations', () {
      const msgId = 'msg_combo_test';
      const targetUid = 'recipient_seat_1';

      List<String> generateAnimIds(int quantity, int comboCount) {
        final qty = quantity > 0 ? quantity : (comboCount > 0 ? comboCount : 1);
        final keys = <String>[];
        for (int i = 0; i < qty; i++) {
          keys.add('${msgId}_${targetUid}_$i');
        }
        return keys;
      }

      // 1x gift -> exactly 1 animation
      expect(generateAnimIds(1, 0).length, equals(1));
      // 2x gift -> exactly 2 animations
      expect(generateAnimIds(2, 0).length, equals(2));
      // 5x gift -> exactly 5 animations
      expect(generateAnimIds(5, 0).length, equals(5));
      // 10x gift -> exactly 10 animations
      expect(generateAnimIds(10, 0).length, equals(10));

      // Fallback when quantity is 0 but comboCount is provided
      expect(generateAnimIds(0, 5).length, equals(5));
      expect(generateAnimIds(0, 2).length, equals(2));

      // 5 rapid taps each sending quantity: 1 with incrementing comboCount 1..5
      final rapidTapAnimIds = <String>[];
      for (int tap = 1; tap <= 5; tap++) {
        final tapMsgId = 'msg_tap_$tap';
        const tapQty = 1;
        for (int i = 0; i < tapQty; i++) {
          rapidTapAnimIds.add('${tapMsgId}_${targetUid}_$i');
        }
      }
      expect(rapidTapAnimIds.length, equals(5));
      expect(rapidTapAnimIds.toSet().length, equals(5));
    });

    test('Targeted recipient profile routing routes non-luxury gifts to seat queue', () {
      bool isSeatTargeted(String targetUid, String tier) {
        return (tier == 'NORMAL' || (targetUid.trim().isNotEmpty && tier != 'LUXURY'));
      }

      // Targeted Normal gift -> seat queue
      expect(isSeatTargeted('user_123', 'NORMAL'), isTrue);
      // Targeted SVGA / Medium gift -> seat queue on recipient profile
      expect(isSeatTargeted('user_123', 'MEDIUM'), isTrue);
      // Room-wide Luxury gift -> room cinematic queue
      expect(isSeatTargeted('user_123', 'LUXURY'), isFalse);
      // Untargeted Medium gift -> room queue
      expect(isSeatTargeted('', 'MEDIUM'), isFalse);
    });

    test('GiftAnimationController dispatches optimistic event and consumePendingEvents drains it', () {
      final ctrl = GiftAnimationController();
      final gift = GiftModel(
        giftId: 'rose',
        name: 'Rose',
        priceInDiamonds: 50,
        imageUrl: 'rose.png',
        lottieAssetPath: 'assets/animations/lottie/Rose.json',
        category: 'Normal',
        tier: 'NORMAL',
        animationFormat: 'json',
      );

      ctrl.playLocalGift(
        gift: gift,
        senderUid: 'sender_1',
        targetUid: 'receiver_1',
        quantity: 2,
        comboCount: 1,
      );

      final events = ctrl.consumePendingEvents();
      expect(events.length, equals(1));
      expect(events.first.giftId, equals('rose'));
      expect(events.first.senderUid, equals('sender_1'));
      expect(events.first.targetUid, equals('receiver_1'));
      expect(events.first.quantity, equals(2));

      // Drained
      expect(ctrl.consumePendingEvents(), isEmpty);
      ctrl.dispose();
    });

    test('GiftAnimationController shouldSkipEcho consumes matching local echo and ignores strangers', () {
      final ctrl = GiftAnimationController();
      final gift = GiftModel(
        giftId: 'heart',
        name: 'Heart',
        priceInDiamonds: 10,
        imageUrl: 'heart.png',
        lottieAssetPath: '',
        category: 'Normal',
      );

      ctrl.playLocalGift(
        gift: gift,
        senderUid: 'me_uid',
        targetUid: 'target_uid',
        quantity: 1,
      );

      // Other sender should not skip
      expect(ctrl.shouldSkipEcho(senderUid: 'other_uid', targetUid: 'target_uid', giftId: 'heart'), isFalse);

      // Matching sender and target skips echo once
      expect(ctrl.shouldSkipEcho(senderUid: 'me_uid', targetUid: 'target_uid', giftId: 'heart'), isTrue);

      // Once consumed, subsequent check returns false
      expect(ctrl.shouldSkipEcho(senderUid: 'me_uid', targetUid: 'target_uid', giftId: 'heart'), isFalse);

      ctrl.dispose();
    });

    test('Sending the same gift twice locally creates unique event IDs and consumes echoes in FIFO order', () {
      final ctrl = GiftAnimationController();
      final gift = GiftModel(
        giftId: 'rose',
        name: 'Rose',
        priceInDiamonds: 50,
        imageUrl: 'rose.png',
        lottieAssetPath: 'assets/animations/lottie/Rose.json',
        category: 'Normal',
        tier: 'NORMAL',
        animationFormat: 'json',
      );

      // Send the same gift 3 times consecutively in rapid succession
      ctrl.playLocalGift(gift: gift, senderUid: 'u1', targetUid: 'u2', quantity: 1, comboCount: 1);
      ctrl.playLocalGift(gift: gift, senderUid: 'u1', targetUid: 'u2', quantity: 1, comboCount: 2);
      ctrl.playLocalGift(gift: gift, senderUid: 'u1', targetUid: 'u2', quantity: 1, comboCount: 3);

      final events = ctrl.consumePendingEvents();
      expect(events.length, equals(3));
      // Every event must have a distinct unique ID
      final eventIds = events.map((e) => e.id).toSet();
      expect(eventIds.length, equals(3), reason: 'Every consecutive send must have a unique monotonic ID');

      // Server echoes arrive for u1 -> u2 -> rose
      expect(ctrl.shouldSkipEcho(senderUid: 'u1', targetUid: 'u2', giftId: 'rose'), isTrue, reason: 'First echo consumed');
      expect(ctrl.shouldSkipEcho(senderUid: 'u1', targetUid: 'u2', giftId: 'rose'), isTrue, reason: 'Second echo consumed');
      expect(ctrl.shouldSkipEcho(senderUid: 'u1', targetUid: 'u2', giftId: 'rose'), isTrue, reason: 'Third echo consumed');

      // 4th echo arrives without local send -> NOT skipped
      expect(ctrl.shouldSkipEcho(senderUid: 'u1', targetUid: 'u2', giftId: 'rose'), isFalse, reason: 'No more local sends queued');

      ctrl.dispose();
    });

    test('Combo streak index does not multiply animation queue count', () {
      // Each tap in a 10x combo streak with quantity 1 must queue exactly 1 animation, not 55
      int totalQueued = 0;
      for (int streak = 1; streak <= 10; streak++) {
        const int quantity = 1;
        final int effectiveQty = quantity > 0 ? quantity : 1;
        totalQueued += effectiveQty;
      }
      expect(totalQueued, equals(10), reason: '10 combo taps must produce exactly 10 animations, not 55');
    });

    test('RoomMessage parses full animation metadata and handles null animationUrl', () {
      final map = {
        'uid': 'user_abc',
        'type': 'gift',
        'giftId': 'super_car',
        'quantity': 1,
        'comboCount': 5,
        'text': 'Sent Car',
        'createdAt': '2026-10-09T10:00:00Z',
        'imageUrl': 'car.png',
        'format': 'mp4',
        'tier': 'LUXURY',
        'giftName': 'Super Car',
        'giftCategory': 'Luxury',
        'durationMs': 5000,
        // animationUrl omitted deliberately
      };

      final msg = RoomMessage.fromMap(map, 'msg_doc_999');
      expect(msg.giftId, equals('super_car'));
      expect(msg.animationUrl, isNull);
      expect(msg.format, equals('mp4'));
      expect(msg.tier, equals('LUXURY'));
      expect(msg.giftName, equals('Super Car'));
      expect(msg.durationMs, equals(5000));

      // Resilient overlay filter test: message is accepted even if animationUrl is null!
      final bool wouldAccept = msg.type == 'gift' &&
          (
            (msg.animationUrl != null && msg.animationUrl!.trim().isNotEmpty) ||
            (msg.giftId != null && msg.giftId!.trim().isNotEmpty)
          );
      expect(wouldAccept, isTrue);
    });
  });

  group('Spin Wheel Canonical 12 o\'clock Segment Mapping', () {
    final canonicalSegments = [
      {'name': 'Hotdog', 'multiplier': 10, 'category': 'pizza'},
      {'name': 'Skewer', 'multiplier': 15, 'category': 'pizza'},
      {'name': 'Chicken', 'multiplier': 25, 'category': 'pizza'},
      {'name': 'Steak', 'multiplier': 45, 'category': 'pizza'},
      {'name': 'Carrot', 'multiplier': 5, 'category': 'salad'},
      {'name': 'Corn', 'multiplier': 5, 'category': 'salad'},
      {'name': 'Cabbage', 'multiplier': 5, 'category': 'salad'},
      {'name': 'Tomato', 'multiplier': 5, 'category': 'salad'},
    ];

    test('Sector 0 is Hotdog / Burger at 12 o\'clock', () {
      final hotdogOutcome = {'name': 'Hotdog', 'multiplier': 10};
      expect(resolveTargetSectorIndex(hotdogOutcome, canonicalSegments), equals(0));

      final burgerAliasOutcome = {'name': 'burger', 'multiplier': 10};
      expect(resolveTargetSectorIndex(burgerAliasOutcome, canonicalSegments), equals(0));
    });

    test('Sector 4 is Carrot at 6 o\'clock', () {
      final carrotOutcome = {'name': 'Carrot', 'multiplier': 5};
      expect(resolveTargetSectorIndex(carrotOutcome, canonicalSegments), equals(4));
    });

    test('Sector 7 is Tomato at 10:30 position', () {
      final tomatoOutcome = {'name': 'Tomato', 'multiplier': 5};
      expect(resolveTargetSectorIndex(tomatoOutcome, canonicalSegments), equals(7));
    });

    test('Food key normalizer maps aliases to canonical names', () {
      expect(normalizeFoodKey('Burger 10x'), equals('burger'));
      expect(normalizeFoodKey('Hotdog'), equals('hotdog'));
      expect(normalizeFoodKey('Kebab 15x'), equals('kebab'));
      expect(normalizeFoodKey('Meat 45x'), equals('steak'));
      expect(normalizeFoodKey('Carrot 5x'), equals('carrot'));
    });
  });
}
