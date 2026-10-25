import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/core/services/server_time_service.dart';
import 'package:hello_chat/core/services/gift_replay_guard.dart';

void main() {
  setUp(() {
    ServerTimeService.reset();
  });

  group('Gift Replay Guard Production Tests (Direct Call to GiftReplayGuard.evaluate)', () {
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

      final decision = GiftReplayGuard.evaluate(
        msgId: giftSent1HourAgo.msgId,
        type: giftSent1HourAgo.type,
        animationUrl: giftSent1HourAgo.animationUrl,
        giftId: giftSent1HourAgo.giftId,
        createdAt: giftSent1HourAgo.createdAt,
        hasExplicitTimestamp: giftSent1HourAgo.hasExplicitTimestamp,
        durationMs: giftSent1HourAgo.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: joinTimeMs,
        nowServerMs: now.millisecondsSinceEpoch,
      );

      expect(decision.shouldPlay, isFalse);
      expect(decision.reason, GiftSkipReason.beforeJoin);
      expect(decision.logMessage, contains('reason=beforeJoin'));
      expect(decision.logMessage, contains('msgId=msg_old_1h'));
    });

    test('2. Join during a playing gift: age > duration + 5s or beforeJoin drops it', () {
      final now = DateTime.now();
      final joinTimeMs = now.millisecondsSinceEpoch;
      // Sent 15s ago, animation lasts 6s
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

      final decision = GiftReplayGuard.evaluate(
        msgId: midPlayGift.msgId,
        type: midPlayGift.type,
        animationUrl: midPlayGift.animationUrl,
        giftId: midPlayGift.giftId,
        createdAt: midPlayGift.createdAt,
        hasExplicitTimestamp: midPlayGift.hasExplicitTimestamp,
        durationMs: midPlayGift.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: joinTimeMs,
        nowServerMs: now.millisecondsSinceEpoch,
      );

      expect(decision.shouldPlay, isFalse);
      expect(decision.reason, GiftSkipReason.beforeJoin);
    });

    test('3. Re-entering the same room: old gifts from first session are skipped', () {
      final now = DateTime.now();
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

      final decision = GiftReplayGuard.evaluate(
        msgId: session1Gift.msgId,
        type: session1Gift.type,
        animationUrl: session1Gift.animationUrl,
        giftId: session1Gift.giftId,
        createdAt: session1Gift.createdAt,
        hasExplicitTimestamp: session1Gift.hasExplicitTimestamp,
        durationMs: session1Gift.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: reenterTimeMs,
        nowServerMs: now.millisecondsSinceEpoch,
      );

      expect(decision.shouldPlay, isFalse);
      expect(decision.reason, GiftSkipReason.beforeJoin);
    });

    test('4. Network drop & reconnect: duplicate msgIds are rejected by processedSet', () {
      final processedIds = <String>{'msg_live_123'};
      final now = DateTime.now();

      final decision = GiftReplayGuard.evaluate(
        msgId: 'msg_live_123',
        type: 'gift',
        animationUrl: 'assets/vap/car.mp4',
        giftId: 'car',
        createdAt: now,
        hasExplicitTimestamp: true,
        durationMs: 5000,
        processedMessageIds: processedIds,
        joinTimeServerMs: now.millisecondsSinceEpoch - 5000,
        nowServerMs: now.millisecondsSinceEpoch,
      );

      expect(decision.shouldPlay, isFalse);
      expect(decision.reason, GiftSkipReason.duplicate);
      expect(decision.logMessage, contains('reason=duplicate'));
    });

    test('5. Wrong phone clock (+/- 10 min): calibrated server offset protects filtering', () {
      const tenMinutesMs = 10 * 60 * 1000;
      ServerTimeService.setMockOffset(tenMinutesMs);

      final phoneLocalTime = DateTime.now();
      final realServerNowMs = ServerTimeService.serverNowMs;

      // Gift sent right now on server:
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

      final decision = GiftReplayGuard.evaluate(
        msgId: msg.msgId,
        type: msg.type,
        animationUrl: msg.animationUrl,
        giftId: msg.giftId,
        createdAt: msg.createdAt,
        hasExplicitTimestamp: true,
        durationMs: msg.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: realServerNowMs - 5000, // joined 5s ago
        nowServerMs: realServerNowMs,
      );

      expect(decision.shouldPlay, isTrue);
      expect(decision.reason, GiftSkipReason.none);
      expect(decision.ageMs < 5000, isTrue);
    });

    test('6. Normal new gift sent while in room: passes all gates and plays', () {
      final now = DateTime.now();
      final joinTimeMs = now.millisecondsSinceEpoch - 10000;

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

      final decision = GiftReplayGuard.evaluate(
        msgId: newGift.msgId,
        type: newGift.type,
        animationUrl: newGift.animationUrl,
        giftId: newGift.giftId,
        createdAt: newGift.createdAt,
        hasExplicitTimestamp: true,
        durationMs: newGift.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: joinTimeMs,
        nowServerMs: now.millisecondsSinceEpoch,
      );

      expect(decision.shouldPlay, isTrue);
      expect(decision.reason, GiftSkipReason.none);
    });

    test('7. Combo of 5 separate taps: all 5 messages are eligible and play in sequence', () {
      final now = DateTime.now();
      final joinTimeMs = now.millisecondsSinceEpoch - 15000;

      final comboMessages = List.generate(5, (index) {
        return RoomMessage(
          msgId: 'msg_combo_${index + 1}',
          uid: 'user_A',
          text: 'Sent Rose',
          type: 'gift',
          giftId: 'rose',
          animationUrl: 'assets/vap/rose.mp4',
          durationMs: 3000,
          comboCount: index + 1,
          createdAt: now.add(Duration(milliseconds: index * 200)),
        );
      });

      final processed = <String>{};
      for (final msg in comboMessages) {
        final decision = GiftReplayGuard.evaluate(
          msgId: msg.msgId,
          type: msg.type,
          animationUrl: msg.animationUrl,
          giftId: msg.giftId,
          createdAt: msg.createdAt,
          hasExplicitTimestamp: true,
          durationMs: msg.durationMs,
          processedMessageIds: processed,
          joinTimeServerMs: joinTimeMs,
          nowServerMs: now.millisecondsSinceEpoch + 1000,
        );

        expect(decision.shouldPlay, isTrue);
        processed.add(msg.msgId);
      }
      expect(processed.length, 5);
    });

    test('8. Failed server time: falls back gracefully to local clock and document calibration', () {
      // ServerTimeService without sync has offset = 0
      expect(ServerTimeService.offsetMs, 0);

      // Now simulate a document arriving with authoritative server timestamp 5 seconds ahead
      final docServerTimestamp = DateTime.now().add(const Duration(seconds: 5));
      ServerTimeService.calibrateWithServerTimestamp(docServerTimestamp);
      expect(ServerTimeService.offsetMs >= 4000, isTrue);

      final now = ServerTimeService.serverNow;
      final gift = RoomMessage(
        msgId: 'msg_fallback_sync',
        uid: 'user_X',
        text: 'Sent Star',
        type: 'gift',
        giftId: 'star',
        animationUrl: 'assets/vap/star.mp4',
        durationMs: 4000,
        createdAt: now,
      );

      final decision = GiftReplayGuard.evaluate(
        msgId: gift.msgId,
        type: gift.type,
        animationUrl: gift.animationUrl,
        giftId: gift.giftId,
        createdAt: gift.createdAt,
        hasExplicitTimestamp: true,
        durationMs: gift.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: ServerTimeService.serverNowMs - 2000,
        nowServerMs: ServerTimeService.serverNowMs,
      );

      expect(decision.shouldPlay, isTrue);
    });

    test('9. Missing timestamp: old events arriving without server timestamp are rejected', () {
      final now = DateTime.now();
      final msgWithoutTimestamp = RoomMessage(
        msgId: 'msg_no_timestamp',
        uid: 'user_Z',
        text: 'Sent Mystery Box',
        type: 'gift',
        giftId: 'box',
        animationUrl: 'assets/vap/box.mp4',
        durationMs: 5000,
        createdAt: now,
        hasExplicitTimestamp: false, // Firestore doc lacked createdAt field
      );

      final decision = GiftReplayGuard.evaluate(
        msgId: msgWithoutTimestamp.msgId,
        type: msgWithoutTimestamp.type,
        animationUrl: msgWithoutTimestamp.animationUrl,
        giftId: msgWithoutTimestamp.giftId,
        createdAt: msgWithoutTimestamp.createdAt,
        hasExplicitTimestamp: msgWithoutTimestamp.hasExplicitTimestamp,
        durationMs: msgWithoutTimestamp.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: now.millisecondsSinceEpoch,
        nowServerMs: now.millisecondsSinceEpoch,
      );

      expect(decision.shouldPlay, isFalse);
      expect(decision.reason, GiftSkipReason.missingTimestamp);
      expect(decision.logMessage, contains('reason=missingTimestamp'));
      expect(decision.logMessage, contains('age=unknown'));
    });

    test('10. Event arriving during join window: within -2s jitter tolerance passes Gate 2', () {
      final now = DateTime.now();
      final joinTimeMs = now.millisecondsSinceEpoch;

      // Event timestamp is 1.5 seconds before joinTime recorded on client
      final inFlightEvent = RoomMessage(
        msgId: 'msg_in_flight',
        uid: 'user_W',
        text: 'Sent Plane',
        type: 'gift',
        giftId: 'plane',
        animationUrl: 'assets/vap/plane.mp4',
        durationMs: 5000,
        createdAt: now.subtract(const Duration(milliseconds: 1500)),
      );

      final decision = GiftReplayGuard.evaluate(
        msgId: inFlightEvent.msgId,
        type: inFlightEvent.type,
        animationUrl: inFlightEvent.animationUrl,
        giftId: inFlightEvent.giftId,
        createdAt: inFlightEvent.createdAt,
        hasExplicitTimestamp: true,
        durationMs: inFlightEvent.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: joinTimeMs,
        nowServerMs: now.millisecondsSinceEpoch,
      );

      expect(decision.shouldPlay, isTrue, reason: 'Within 2s jitter window during room transition is accepted');
    });

    test('11. Sender local echo right after joining: skipped with reason=localEcho', () {
      final now = DateTime.now();
      final echoMsg = RoomMessage(
        msgId: 'msg_my_echo',
        uid: 'my_user_id',
        text: 'Sent Crown',
        type: 'gift',
        giftId: 'crown',
        animationUrl: 'assets/vap/crown.mp4',
        durationMs: 6000,
        createdAt: now,
      );

      final decision = GiftReplayGuard.evaluate(
        msgId: echoMsg.msgId,
        type: echoMsg.type,
        animationUrl: echoMsg.animationUrl,
        giftId: echoMsg.giftId,
        createdAt: echoMsg.createdAt,
        hasExplicitTimestamp: true,
        durationMs: echoMsg.durationMs,
        processedMessageIds: <String>{},
        joinTimeServerMs: now.millisecondsSinceEpoch - 1000,
        nowServerMs: now.millisecondsSinceEpoch,
        isLocalEcho: true, // Sender already played optimistically
      );

      expect(decision.shouldPlay, isFalse);
      expect(decision.reason, GiftSkipReason.localEcho);
      expect(decision.logMessage, contains('reason=localEcho'));
    });
  });
}
