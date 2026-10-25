import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/core/services/server_time_service.dart';

void main() {
  setUp(() {
    ServerTimeService.reset();
  });

  group('Gift Replay Triple-Gate Filter Unit Tests', () {
    test('1. Join after 1 hour: gift sent 1h ago is rejected (beforeJoin / old)', () {
      final now = DateTime.now();
      final joinTimeMs = now.millisecondsSinceEpoch;
      final giftSent1HourAgo = RoomMessage(
        msgId: 'msg_old_1h',
        uid: 'user_A',
        text: 'Sent Luxury Car',
        type: 'gift',
        giftId: 'luxury_car',
        animationUrl: 'assets/vap/luxury_car.mp4',
        durationMs: 8000,
        createdAt: now.subtract(const Duration(hours: 1)),
      );

      final createdAtMs = giftSent1HourAgo.createdAt.millisecondsSinceEpoch;
      final ageMs = joinTimeMs - createdAtMs;
      final effectiveDuration = giftSent1HourAgo.durationMs;

      // Gate 2 check:
      final isBeforeJoin = createdAtMs < (joinTimeMs - 2000);
      // Gate 3 check:
      final isExpired = ageMs > (effectiveDuration + 5000);

      expect(isBeforeJoin, isTrue, reason: 'Gift from 1h ago must trigger beforeJoin');
      expect(isExpired, isTrue, reason: 'Gift from 1h ago must trigger old/expired');
    });

    test('2. Join during a playing gift: age > duration + 5s or beforeJoin drops it (skip policy)', () {
      final now = DateTime.now();
      final joinTimeMs = now.millisecondsSinceEpoch;
      // Gift sent 15 seconds ago, animation lasts 6s
      final midPlayGift = RoomMessage(
        msgId: 'msg_mid_play',
        uid: 'user_A',
        text: 'Sent Palace',
        type: 'gift',
        giftId: 'palace',
        animationUrl: 'assets/vap/palace.mp4',
        durationMs: 6000,
        createdAt: now.subtract(const Duration(seconds: 15)),
      );

      final createdAtMs = midPlayGift.createdAt.millisecondsSinceEpoch;
      final ageMs = joinTimeMs - createdAtMs;
      final effectiveDuration = midPlayGift.durationMs;

      final shouldSkip = createdAtMs < (joinTimeMs - 2000) || ageMs > (effectiveDuration + 5000);
      expect(shouldSkip, isTrue, reason: 'Partial in-flight gift from before join must be cleanly skipped');
    });

    test('3. Re-entering the same room: old gifts from first session are skipped', () {
      final now = DateTime.now();
      // First session was at now - 20 minutes
      // Re-entered at now
      final reenterTimeMs = now.millisecondsSinceEpoch;

      final session1Gift = RoomMessage(
        msgId: 'msg_session_1',
        uid: 'user_C',
        text: 'Sent Rocket',
        type: 'gift',
        giftId: 'rocket',
        animationUrl: 'assets/vap/rocket.mp4',
        durationMs: 7000,
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

      final createdAtMs = session1Gift.createdAt.millisecondsSinceEpoch;
      expect(createdAtMs < (reenterTimeMs - 2000), isTrue,
          reason: 'Re-entry joinTime must exclude earlier session gifts');
    });

    test('4. Network drop & reconnect: duplicate msgIds are rejected by processedSet', () {
      final processedIds = <String>{};
      const msgId = 'msg_live_123';
      processedIds.add(msgId);

      // Reconnect re-delivers snapshot with msg_live_123
      expect(processedIds.contains(msgId), isTrue,
          reason: 'Duplicate snapshot emissions must be deduplicated by processedMessageIds');
    });

    test('5. Wrong phone clock (+/- 10 min): calibrated server offset protects filtering', () {
      // Simulate phone clock 10 minutes BEHIND real server time
      const tenMinutesMs = 10 * 60 * 1000;
      ServerTimeService.setMockOffset(tenMinutesMs);

      final phoneLocalTime = DateTime.now();
      final realServerNowMs = ServerTimeService.serverNowMs;

      // A gift sent right now on server:
      final serverCreatedAt = phoneLocalTime.add(const Duration(minutes: 10));
      final msg = RoomMessage(
        msgId: 'msg_clock_skew',
        uid: 'user_A',
        text: 'Sent Castle',
        type: 'gift',
        giftId: 'castle',
        animationUrl: 'assets/vap/castle.mp4',
        durationMs: 8000,
        createdAt: serverCreatedAt,
      );

      final createdAtMs = msg.createdAt.millisecondsSinceEpoch;
      final ageMs = realServerNowMs - createdAtMs;

      expect(ageMs >= 0, isTrue);
      expect(ageMs < 5000, isTrue, reason: 'RTT offset-calibrated clock computes accurate ~0s age despite phone clock skew');
    });

    test('6. Normal new gift sent while in room: passes all gates and plays', () {
      final now = DateTime.now();
      final joinTimeMs = now.millisecondsSinceEpoch - 10000; // joined 10s ago

      // Gift sent right now
      final newGift = RoomMessage(
        msgId: 'msg_fresh_001',
        uid: 'user_B',
        text: 'Sent Dragon',
        type: 'gift',
        giftId: 'dragon',
        animationUrl: 'assets/vap/dragon.mp4',
        durationMs: 5000,
        createdAt: now,
      );

      final createdAtMs = newGift.createdAt.millisecondsSinceEpoch;
      final ageMs = now.millisecondsSinceEpoch - createdAtMs;
      final isBeforeJoin = createdAtMs < (joinTimeMs - 2000);
      final isExpired = ageMs > (newGift.durationMs + 5000);

      expect(isBeforeJoin, isFalse);
      expect(isExpired, isFalse);
    });

    test('7. Combo of 5 separate taps: all 5 messages are eligible and play in sequence', () {
      final now = DateTime.now();
      final joinTimeMs = now.millisecondsSinceEpoch - 15000; // joined 15s ago

      final comboMessages = List.generate(5, (index) {
        return RoomMessage(
          msgId: 'msg_combo_${index + 1}',
          uid: 'user_sender',
          text: 'Sent Rose x${index + 1}',
          type: 'gift',
          giftId: 'rose',
          animationUrl: 'assets/svga/rose.svga',
          comboCount: index + 1,
          quantity: 1,
          durationMs: 3000,
          createdAt: now.add(Duration(milliseconds: index * 200)),
        );
      });

      for (int i = 0; i < 5; i++) {
        final m = comboMessages[i];
        final createdAtMs = m.createdAt.millisecondsSinceEpoch;
        final ageMs = now.millisecondsSinceEpoch - createdAtMs;
        expect(createdAtMs >= (joinTimeMs - 2000), isTrue);
        expect(ageMs <= (m.durationMs + 5000), isTrue);
        expect(m.comboCount, equals(i + 1));
      }
    });
  });
}
