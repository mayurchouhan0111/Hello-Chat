import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/gift_combo_overlay.dart';

RoomMessage _gift({
  required String id,
  required String sender,
  required String receiver,
  required String giftId,
  required DateTime at,
  int comboCount = 0,
  int quantity = 1,
  String type = 'gift',
}) =>
    RoomMessage(
      msgId: id,
      uid: sender,
      text: 'Sent to bob x1',
      type: type,
      giftId: giftId,
      animationUrl: 'https://x/anim.json',
      targetUid: receiver,
      quantity: quantity,
      comboCount: comboCount,
      createdAt: at,
    );

void main() {
  late GiftComboController ctrl;
  final t0 = DateTime(2026, 1, 1, 12);

  setUp(() => ctrl = GiftComboController());
  tearDown(() => ctrl.dispose());

  test('converges to the server aggregate and survives re-delivery', () {
    final msgs = [
      for (var i = 1; i <= 5; i++)
        _gift(
          id: 'm$i',
          sender: 'u1',
          receiver: 'u2',
          giftId: 'rose',
          at: t0.add(Duration(seconds: i)),
          comboCount: i,
        ),
    ];

    for (final m in msgs) {
      ctrl.applyRemote(m, giftIconUrl: 'icon');
    }
    expect(ctrl.active, hasLength(1));
    expect(ctrl.active.single.count, 5);

    // roomMessages re-emits the whole window on every snapshot.
    for (final m in msgs) {
      ctrl.applyRemote(m, giftIconUrl: 'icon');
    }
    expect(ctrl.active, hasLength(1));
    expect(ctrl.active.single.count, 5);
  });

  test('one session per stream, not one per message', () {
    ctrl.applyRemote(
      _gift(id: 'a', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0, comboCount: 1),
      giftIconUrl: 'icon',
    );
    ctrl.applyRemote(
      _gift(id: 'b', sender: 'u1', receiver: 'u3', giftId: 'rose', at: t0, comboCount: 1),
      giftIconUrl: 'icon',
    );
    ctrl.applyRemote(
      _gift(id: 'c', sender: 'u1', receiver: 'u2', giftId: 'crown', at: t0, comboCount: 1),
      giftIconUrl: 'icon',
    );
    expect(ctrl.active, hasLength(3));
  });

  test('a comboCount-less message counts exactly once', () {
    final first = _gift(id: 'a', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0);
    ctrl.applyRemote(first, giftIconUrl: 'icon');
    expect(ctrl.active.single.count, 1);

    ctrl.applyRemote(first, giftIconUrl: 'icon');
    ctrl.applyRemote(first, giftIconUrl: 'icon');
    expect(ctrl.active.single.count, 1);
  });

  test('an older message cannot move a stream backwards', () {
    ctrl.applyRemote(
      _gift(id: 'b', sender: 'u1', receiver: 'u2', giftId: 'rose',
          at: t0.add(const Duration(seconds: 5)), comboCount: 4),
      giftIconUrl: 'icon',
    );
    ctrl.applyRemote(
      _gift(id: 'a', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0, comboCount: 1),
      giftIconUrl: 'icon',
    );
    expect(ctrl.active.single.count, 4);
  });

  test('optimistic tap then server echo does not double count', () {
    ctrl.tapLocal(
      comboKeyFor('u1', 'u2', 'rose'),
      senderUid: 'u1',
      receiverUid: 'u2',
      giftId: 'rose',
      giftIconUrl: 'icon',
      count: 2,
    );
    expect(ctrl.active.single.count, 2);

    ctrl.applyRemote(
      _gift(id: 'a', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0, comboCount: 2),
      giftIconUrl: 'icon',
    );
    expect(ctrl.active.single.count, 2);

    ctrl.applyRemote(
      _gift(id: 'b', sender: 'u1', receiver: 'u2', giftId: 'rose',
          at: t0.add(const Duration(seconds: 1)), comboCount: 3),
      giftIconUrl: 'icon',
    );
    expect(ctrl.active.single.count, 3);
  });

  test('a failed dispatch rolls back only as far as the server confirmed', () {
    final key = comboKeyFor('u1', 'u2', 'rose');
    ctrl.applyRemote(
      _gift(id: 'a', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0, comboCount: 3),
      giftIconUrl: 'icon',
    );
    ctrl.tapLocal(key, senderUid: 'u1', receiverUid: 'u2', giftId: 'rose',
        giftIconUrl: 'icon', count: 4);
    expect(ctrl.active.single.count, 4);

    ctrl.rollbackLocal(key);
    expect(ctrl.active.single.count, 3);
  });

  test('settled counts outlive the session so the chat row never snaps back', () {
    final key = comboKeyFor('u1', 'u2', 'rose');
    ctrl.applyRemote(
      _gift(id: 'a', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0, comboCount: 7),
      giftIconUrl: 'icon',
    );
    expect(ctrl.settledCount(key), isNull);

    ctrl.remove(key);
    expect(ctrl.active, isEmpty);
    expect(ctrl.settledCount(key), 7);
  });

  test('non-gifts and gifts with no receiver never open a stream', () {
    ctrl.applyRemote(
      _gift(id: 'a', sender: 'u1', receiver: '', giftId: 'rose', at: t0, comboCount: 1),
      giftIconUrl: 'icon',
    );
    ctrl.applyRemote(
      _gift(id: 'b', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0, type: 'text'),
      giftIconUrl: 'icon',
    );
    expect(ctrl.active, isEmpty);
  });

  test('higher combo count is never dropped even if timestamp has network clock skew', () {
    // Message 1 arrives with count 2 at t0 + 2s
    ctrl.applyRemote(
      _gift(id: 'm1', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0.add(const Duration(seconds: 2)), comboCount: 2),
      giftIconUrl: 'icon',
    );
    expect(ctrl.active.single.count, 2);

    // Message 2 arrives with higher count 3, but slightly earlier/skewed timestamp (e.g. t0 + 1s)
    ctrl.applyRemote(
      _gift(id: 'm2', sender: 'u1', receiver: 'u2', giftId: 'rose', at: t0.add(const Duration(seconds: 1)), comboCount: 3),
      giftIconUrl: 'icon',
    );
    expect(ctrl.active.single.count, 3, reason: 'Higher combo streak must advance despite timestamp skew');
  });
}
