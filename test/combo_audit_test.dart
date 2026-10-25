// ignore_for_file: avoid_print
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/gift_combo_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Combo Audit & Verification', () {
    test('1. GiftComboController local taps increment count from 1 to 5', () {
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
      }
      expect(controller[comboKey]!.count, equals(5));
      print('[Audit] Local taps banner count: ${controller[comboKey]!.count}');
    });

    test('2. GiftComboController remote events with comboCount increment from 1 to 5', () {
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
      }
      expect(controller['sender1_receiver1_giftA']!.count, equals(5));
      print('[Audit] Remote comboCount banner count: ${controller['sender1_receiver1_giftA']!.count}');
    });

    test('3. GiftComboController remote events without comboCount (comboCount=0)', () {
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
      }
      expect(controller['sender1_receiver1_giftA']!.count, equals(5));
      print('[Audit] Remote uncounted banner count: ${controller['sender1_receiver1_giftA']!.count}');
    });

    test('4. Scenario A: Send x1 five times quickly from one sender', () {
      final simulator = _GiftQueueSimulator();
      final controller = GiftComboController();
      const comboKey = 'sender1_receiver1_crystal_princess';

      for (int i = 1; i <= 5; i++) {
        controller.tapLocal(
          comboKey,
          senderUid: 'sender1',
          receiverUid: 'receiver1',
          giftId: 'crystal_princess',
          giftIconUrl: 'icon.png',
          count: i,
        );
        simulator.enqueueRoomAnimation(_SimulatedAnim(
          id: 'tap_$i',
          giftId: 'crystal_princess',
          giftName: 'Crystal Princess',
          senderUid: 'sender1',
          comboCount: i,
          quantity: 1,
        ));
      }

      final bannerCount = controller[comboKey]!.count;
      final totalPlaysQueued = simulator.totalPlaysQueued;
      print('[Scenario A] Sent x1 five times: totalPlaysQueued=$totalPlaysQueued, bannerCount=$bannerCount');
      expect(bannerCount, equals(5));
      expect(totalPlaysQueued, equals(5));

      // Simulate execution of plays
      final executedPlays = simulator.drainAllPlays();
      print('[Scenario A] Executed sequential plays: $executedPlays');
      expect(executedPlays, equals(5));
    });

    test('5. Scenario B: Quantity of 5 in one event', () {
      final simulator = _GiftQueueSimulator();
      final controller = GiftComboController();
      const comboKey = 'sender1_receiver1_crystal_princess';

      controller.applyRemote(
        RoomMessage(
          msgId: 'batch_msg_1',
          uid: 'sender1',
          text: 'Crystal Princess x5',
          type: 'gift',
          createdAt: DateTime.now(),
          giftId: 'crystal_princess',
          targetUid: 'receiver1',
          quantity: 5,
          comboCount: 5,
        ),
        giftIconUrl: 'icon.png',
      );

      simulator.enqueueRoomAnimation(_SimulatedAnim(
        id: 'batch_1',
        giftId: 'crystal_princess',
        giftName: 'Crystal Princess',
        senderUid: 'sender1',
        comboCount: 5,
        quantity: 5,
      ));

      final bannerCount = controller[comboKey]!.count;
      final totalPlaysQueued = simulator.totalPlaysQueued;
      print('[Scenario B] Quantity x5 in one event: totalPlaysQueued=$totalPlaysQueued, bannerCount=$bannerCount');
      expect(bannerCount, equals(5));
      expect(totalPlaysQueued, equals(5));

      final executedPlays = simulator.drainAllPlays();
      print('[Scenario B] Executed sequential plays: $executedPlays');
      expect(executedPlays, equals(5));
    });

    test('6. Scenario C: Two senders sending same gift', () {
      final simulator = _GiftQueueSimulator();
      final controller = GiftComboController();
      const comboKey1 = 'sender1_receiver1_crystal_princess';
      const comboKey2 = 'sender2_receiver1_crystal_princess';

      // Sender 1 sends quantity 2
      controller.applyRemote(
        RoomMessage(
          msgId: 's1_msg_1',
          uid: 'sender1',
          text: 'Crystal Princess x2',
          type: 'gift',
          createdAt: DateTime.now(),
          giftId: 'crystal_princess',
          targetUid: 'receiver1',
          quantity: 2,
          comboCount: 2,
        ),
        giftIconUrl: 'icon.png',
      );
      simulator.enqueueRoomAnimation(_SimulatedAnim(
        id: 's1_anim_1',
        giftId: 'crystal_princess',
        giftName: 'Crystal Princess',
        senderUid: 'sender1',
        comboCount: 2,
        quantity: 2,
      ));

      // Sender 2 sends quantity 3
      controller.applyRemote(
        RoomMessage(
          msgId: 's2_msg_1',
          uid: 'sender2',
          text: 'Crystal Princess x3',
          type: 'gift',
          createdAt: DateTime.now().add(const Duration(milliseconds: 50)),
          giftId: 'crystal_princess',
          targetUid: 'receiver1',
          quantity: 3,
          comboCount: 3,
        ),
        giftIconUrl: 'icon.png',
      );
      simulator.enqueueRoomAnimation(_SimulatedAnim(
        id: 's2_anim_1',
        giftId: 'crystal_princess',
        giftName: 'Crystal Princess',
        senderUid: 'sender2',
        comboCount: 3,
        quantity: 3,
      ));

      final bannerCount1 = controller[comboKey1]!.count;
      final bannerCount2 = controller[comboKey2]!.count;
      print('[Scenario C] Two Senders: Sender1 banner=$bannerCount1, Sender2 banner=$bannerCount2');
      expect(bannerCount1, equals(2));
      expect(bannerCount2, equals(3));
      expect(simulator.totalPlaysQueued, equals(5)); // 2 + 3

      // Verify FIFO queue preservation: sender 1 plays 2 times, then sender 2 plays 3 times
      final playOrder = simulator.drainAllPlaysWithSender();
      print('[Scenario C] Play sequence: $playOrder');
      expect(playOrder, equals(['sender1', 'sender1', 'sender2', 'sender2', 'sender2']));
    });

    test('7. Scenario D: Combo cap of 10 plays per combo entry', () {
      final simulator = _GiftQueueSimulator();
      final controller = GiftComboController();
      const comboKey = 'sender1_receiver1_crystal_princess';

      // Send 15 taps
      for (int i = 1; i <= 15; i++) {
        controller.tapLocal(
          comboKey,
          senderUid: 'sender1',
          receiverUid: 'receiver1',
          giftId: 'crystal_princess',
          giftIconUrl: 'icon.png',
          count: i,
        );
        simulator.enqueueRoomAnimation(_SimulatedAnim(
          id: 'tap_$i',
          giftId: 'crystal_princess',
          giftName: 'Crystal Princess',
          senderUid: 'sender1',
          comboCount: i,
          quantity: 1,
        ));
      }

      final bannerCount = controller[comboKey]!.count;
      print('[Scenario D] Combo Cap: Sent 15 taps, bannerCount=$bannerCount, totalPlaysQueued=${simulator.totalPlaysQueued}');
      expect(bannerCount, equals(15)); // Banner still reflects total sent
      expect(simulator.totalPlaysQueued, equals(10)); // Plays strictly capped at 10
      expect(simulator.droppedPlays, equals(5)); // 5 excess plays dropped with log

      final executed = simulator.drainAllPlays();
      expect(executed, equals(10));
    });

    test('8. Scenario E: Luxury queue cap counts queue entries, not plays', () {
      final simulator = _GiftQueueSimulator();

      // Enqueue 6 different senders: 1 active playing + 5 in queue (queue length reaches 5)
      for (int s = 1; s <= 6; s++) {
        simulator.enqueueRoomAnimation(_SimulatedAnim(
          id: 's${s}_anim',
          giftId: 'crystal_princess',
          giftName: 'Crystal Princess',
          senderUid: 'sender_$s',
          comboCount: 5,
          quantity: 5,
        ));
      }

      // 1 active playing, 5 in queue -> queue entries = 5 (at max cap)
      expect(simulator.luxuryQueue.length, equals(5));
      expect(simulator.droppedEntries, equals(0));

      // Add a 7th sender -> queue exceeds 5, drops oldest
      simulator.enqueueRoomAnimation(_SimulatedAnim(
        id: 's7_anim',
        giftId: 'crystal_princess',
        giftName: 'Crystal Princess',
        senderUid: 'sender_7',
        comboCount: 5,
        quantity: 5,
      ));
      expect(simulator.droppedEntries, equals(1));
      print('[Scenario E] Luxury cap: counted queue entries; oldest dropped only when distinct entries exceeded cap');
    });
  });
}

class _SimulatedAnim {
  final String id;
  final String giftId;
  final String giftName;
  final String senderUid;
  final int comboCount;
  final int quantity;
  final int totalPlays;
  final int remainingPlays;
  final int currentPlayIndex;

  _SimulatedAnim({
    required this.id,
    required this.giftId,
    required this.giftName,
    required this.senderUid,
    required this.comboCount,
    this.quantity = 1,
    int? totalPlays,
    int? remainingPlays,
    this.currentPlayIndex = 1,
  })  : totalPlays = totalPlays ?? comboCount,
        remainingPlays = remainingPlays ?? (totalPlays ?? comboCount);

  _SimulatedAnim copyWith({
    int? comboCount,
    int? totalPlays,
    int? remainingPlays,
    int? currentPlayIndex,
  }) {
    return _SimulatedAnim(
      id: id,
      giftId: giftId,
      giftName: giftName,
      senderUid: senderUid,
      comboCount: comboCount ?? this.comboCount,
      quantity: quantity,
      totalPlays: totalPlays ?? this.totalPlays,
      remainingPlays: remainingPlays ?? this.remainingPlays,
      currentPlayIndex: currentPlayIndex ?? this.currentPlayIndex,
    );
  }
}

class _GiftQueueSimulator {
  static const int kMaxComboPlays = 10;
  bool isFullScreenPlaying = false;
  _SimulatedAnim? currentFullScreenAnim;
  final List<_SimulatedAnim> luxuryQueue = [];
  int droppedPlays = 0;
  int droppedEntries = 0;

  int get totalPlaysQueued {
    int count = currentFullScreenAnim != null ? currentFullScreenAnim!.totalPlays : 0;
    for (final anim in luxuryQueue) {
      count += anim.totalPlays;
    }
    return count;
  }

  void enqueueRoomAnimation(_SimulatedAnim anim) {
    final int activePlays = (currentFullScreenAnim != null &&
            currentFullScreenAnim!.senderUid == anim.senderUid &&
            currentFullScreenAnim!.giftId == anim.giftId)
        ? currentFullScreenAnim!.totalPlays
        : 0;
    final int maxAllowedInQueue = math.max(0, kMaxComboPlays - activePlays);

    final existingIdx = luxuryQueue.indexWhere(
      (item) => item.senderUid == anim.senderUid && item.giftId == anim.giftId,
    );

    if (existingIdx != -1) {
      final existing = luxuryQueue[existingIdx];
      final int lastComboCount = existing.comboCount;
      final int deltaPlays = (anim.comboCount > 0 && lastComboCount > 0)
          ? math.max(anim.comboCount - lastComboCount, 1)
          : math.max(anim.quantity > 0 ? anim.quantity : anim.comboCount, 1);
      final int newTotal = existing.totalPlays + deltaPlays;
      final int newRemaining = existing.remainingPlays + deltaPlays;
      final int cappedTotal = math.min(newTotal, maxAllowedInQueue);
      final int cappedRemaining = math.min(newRemaining, maxAllowedInQueue);
      if (newTotal > maxAllowedInQueue) {
        droppedPlays += (newTotal - maxAllowedInQueue);
        print('[Simulator] Combo cap ($kMaxComboPlays) reached for ${anim.giftName}: dropped ${newTotal - maxAllowedInQueue} excess plays');
      }
      final int displayCombo = math.max(existing.comboCount, anim.comboCount);
      luxuryQueue[existingIdx] = existing.copyWith(
        comboCount: displayCombo,
        totalPlays: cappedTotal,
        remainingPlays: cappedRemaining,
      );
    } else {
      final int lastPlayingCombo = (currentFullScreenAnim != null &&
              currentFullScreenAnim!.senderUid == anim.senderUid &&
              currentFullScreenAnim!.giftId == anim.giftId)
          ? currentFullScreenAnim!.comboCount
          : 0;
      final int deltaPlays = (anim.comboCount > 0 && lastPlayingCombo > 0)
          ? math.max(anim.comboCount - lastPlayingCombo, 1)
          : math.max(anim.quantity > 0 ? anim.quantity : anim.comboCount, 1);
      final int cappedPlays = math.min(deltaPlays, isFullScreenPlaying ? maxAllowedInQueue : kMaxComboPlays);
      if (deltaPlays > (isFullScreenPlaying ? maxAllowedInQueue : kMaxComboPlays)) {
        droppedPlays += (deltaPlays - (isFullScreenPlaying ? maxAllowedInQueue : kMaxComboPlays));
        print('[Simulator] Combo cap ($kMaxComboPlays) reached for ${anim.giftName}: dropped ${deltaPlays - (isFullScreenPlaying ? maxAllowedInQueue : kMaxComboPlays)} excess plays');
      }
      final animWithPlays = anim.copyWith(
        totalPlays: cappedPlays,
        remainingPlays: cappedPlays,
        currentPlayIndex: 1,
      );

      if (!isFullScreenPlaying) {
        isFullScreenPlaying = true;
        currentFullScreenAnim = animWithPlays;
      } else {
        if (luxuryQueue.length >= 5) {
          luxuryQueue.removeAt(0);
          droppedEntries++;
          print('[Simulator] Max 5 luxury cap reached, dropped oldest');
        }
        luxuryQueue.add(animWithPlays);
      }
    }
  }

  int drainAllPlays() {
    int executed = 0;
    while (currentFullScreenAnim != null || luxuryQueue.isNotEmpty) {
      if (currentFullScreenAnim == null && luxuryQueue.isNotEmpty) {
        currentFullScreenAnim = luxuryQueue.removeAt(0);
      }
      if (currentFullScreenAnim != null) {
        executed++;
        if (currentFullScreenAnim!.remainingPlays > 1) {
          currentFullScreenAnim = currentFullScreenAnim!.copyWith(
            remainingPlays: currentFullScreenAnim!.remainingPlays - 1,
            currentPlayIndex: currentFullScreenAnim!.currentPlayIndex + 1,
          );
        } else {
          currentFullScreenAnim = null;
        }
      }
    }
    isFullScreenPlaying = false;
    return executed;
  }

  List<String> drainAllPlaysWithSender() {
    final List<String> list = [];
    while (currentFullScreenAnim != null || luxuryQueue.isNotEmpty) {
      if (currentFullScreenAnim == null && luxuryQueue.isNotEmpty) {
        currentFullScreenAnim = luxuryQueue.removeAt(0);
      }
      if (currentFullScreenAnim != null) {
        list.add(currentFullScreenAnim!.senderUid);
        if (currentFullScreenAnim!.remainingPlays > 1) {
          currentFullScreenAnim = currentFullScreenAnim!.copyWith(
            remainingPlays: currentFullScreenAnim!.remainingPlays - 1,
            currentPlayIndex: currentFullScreenAnim!.currentPlayIndex + 1,
          );
        } else {
          currentFullScreenAnim = null;
        }
      }
    }
    isFullScreenPlaying = false;
    return list;
  }
}
