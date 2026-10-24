import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/gift_combo_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Combo Audit - Send x1 Five Times Quickly', () {
    test('GiftComboController local taps increment count from 1 to 5', () {
      final controller = GiftComboController();
      const comboKey = 'sender1_receiver1_giftA';

      for (int i = 1; i <= 5; i++) {
        controller.tapLocal(
          comboKey,
          senderUid: 'sender1',
          receiverUid: 'receiver1',
          giftId: 'giftA',
          giftIconUrl: 'icon.png',
          count: i,
        );
        final combo = controller[comboKey];
        expect(combo, isNotNull);
        expect(combo!.count, equals(i));
        print('Event $i: Banner combo count is ${combo.count}');
      }
      expect(controller[comboKey]!.count, equals(5));
    });

    test('GiftComboController remote events with comboCount increment from 1 to 5', () {
      final controller = GiftComboController();
      final now = DateTime.now();

      for (int i = 1; i <= 5; i++) {
        final msg = RoomMessage(
          msgId: 'msg_$i',
          uid: 'sender1',
          text: 'Sent gift x1',
          type: 'gift',
          createdAt: now.add(Duration(milliseconds: i * 200)),
          giftId: 'giftA',
          targetUid: 'receiver1',
          quantity: 1,
          comboCount: i,
        );
        controller.applyRemote(msg, giftIconUrl: 'icon.png');
        final combo = controller[msg.giftComboKey];
        expect(combo, isNotNull);
        expect(combo!.count, equals(i));
        print('Remote with comboCount $i: Banner count is ${combo.count}');
      }
      expect(controller['sender1_receiver1_giftA']!.count, equals(5));
    });

    test('GiftComboController remote events without comboCount (comboCount=0)', () {
      final controller = GiftComboController();
      final now = DateTime.now();

      for (int i = 1; i <= 5; i++) {
        final msg = RoomMessage(
          msgId: 'msg_no_combo_$i',
          uid: 'sender1',
          text: 'Sent gift x1',
          type: 'gift',
          createdAt: now.add(Duration(milliseconds: i * 200)),
          giftId: 'giftA',
          targetUid: 'receiver1',
          quantity: 1,
          comboCount: 0,
        );
        controller.applyRemote(msg, giftIconUrl: 'icon.png');
        final combo = controller[msg.giftComboKey];
        expect(combo, isNotNull);
        expect(combo!.count, equals(i));
        print('Remote without comboCount $i: Banner count is ${combo.count}');
      }
      expect(controller['sender1_receiver1_giftA']!.count, equals(5));
    });

    test('Queue absorption logic absorbs 5 quick x1 taps into the active playing gift', () {
      bool isFullScreenPlaying = false;
      _AuditAnim? currentFullScreenAnim;
      final List<_AuditAnim> luxuryQueue = [];

      void enqueueRoomAnimation(_AuditAnim anim) {
        if (isFullScreenPlaying &&
            currentFullScreenAnim != null &&
            currentFullScreenAnim!.senderUid == anim.senderUid &&
            currentFullScreenAnim!.giftId == anim.giftId) {
          final int delta = anim.comboCount > currentFullScreenAnim!.comboCount
              ? (anim.comboCount - currentFullScreenAnim!.comboCount)
              : (anim.comboCount > 0 ? anim.comboCount : 1);
          final int newCombo = currentFullScreenAnim!.comboCount + delta;
          currentFullScreenAnim = currentFullScreenAnim!.copyWith(
            comboCount: newCombo,
            text: '${anim.giftName} x$newCombo',
          );
          print('[Queue Audit] Event ${anim.id}: Absorbed into playing gift -> combo count is now ${currentFullScreenAnim!.comboCount}, luxury queue length=${luxuryQueue.length}');
          return;
        }

        if (!isFullScreenPlaying) {
          isFullScreenPlaying = true;
          currentFullScreenAnim = anim;
          print('[Queue Audit] Event ${anim.id}: Started playback -> combo count=${anim.comboCount}, luxury queue length=${luxuryQueue.length}');
        } else {
          luxuryQueue.add(anim);
          print('[Queue Audit] Event ${anim.id}: Added to queue -> luxury queue length=${luxuryQueue.length}');
        }
      }

      for (int i = 1; i <= 5; i++) {
        enqueueRoomAnimation(_AuditAnim(
          id: 'tap_$i',
          giftId: 'crystal_princess',
          giftName: 'Crystal Princess',
          senderUid: 'sender1',
          comboCount: i,
        ));
      }

      expect(currentFullScreenAnim, isNotNull);
      expect(currentFullScreenAnim!.comboCount, equals(5));
      expect(luxuryQueue.length, equals(0)); // All 4 subsequent taps absorbed into playing gift
      print('[Queue Audit Result] Playing gift absorbed taps 2..5; luxuryQueue.length=0; total count=${currentFullScreenAnim!.comboCount}');
    });
  });
}

class _AuditAnim {
  final String id;
  final String giftId;
  final String giftName;
  final String senderUid;
  final int comboCount;
  final String text;

  _AuditAnim({
    required this.id,
    required this.giftId,
    required this.giftName,
    required this.senderUid,
    required this.comboCount,
    this.text = '',
  });

  _AuditAnim copyWith({int? comboCount, String? text}) {
    return _AuditAnim(
      id: id,
      giftId: giftId,
      giftName: giftName,
      senderUid: senderUid,
      comboCount: comboCount ?? this.comboCount,
      text: text ?? this.text,
    );
  }
}
