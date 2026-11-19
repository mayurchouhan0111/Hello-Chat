import 'package:audioplayers/audioplayers.dart';
import 'package:hello_chat/features/games/presentation/widgets/wheel_sounds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/providers/game_provider.dart';
import 'package:hello_chat/features/games/presentation/widgets/game_top_winner_banner.dart';
import 'package:hello_chat/features/games/presentation/widgets/spin_wheel_layout.dart';

class _TestPlayer extends Fake implements AudioPlayer {
  String? asset;
  int plays = 0;
  bool disposed = false;
  @override
  Future<void> setSourceAsset(String path, {String? mimeType}) async {
    asset = path;
  }

  @override
  Future<void> setAudioContext(AudioContext context) async {}
  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> resume() async {
    plays++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test(
      'wheel ticks follow segment changes and the reveal chimes once per round',
      () async {
    final tick = _TestPlayer(), chime = _TestPlayer();
    final sounds = WheelSounds.withPlayers(tick, chime)..prepare();
    sounds.tick();
    await Future<void>.delayed(Duration.zero);
    expect(tick.asset, 'games/wheel_tick.wav');
    expect(tick.plays, 1);
    sounds.tick();
    sounds.reveal('round1');
    sounds.reveal('round1');
    await Future<void>.delayed(Duration.zero);
    expect(tick.plays, 1);
    expect(chime.asset, 'games/wheel_result.wav');
    expect(chime.plays, 1);
    sounds.tick();
    sounds.silence();
    await Future<void>.delayed(Duration.zero);
    expect(tick.plays, 1);
    sounds.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(tick.disposed && chime.disposed, isTrue);
  });

  for (final size in const [
    Size(320, 568),
    Size(360, 800),
    Size(430, 932),
    Size(740, 360)
  ]) {
    testWidgets('All wheel stakes can be selected above the footer at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 100;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.fromLTRB(12, 32, 12, 34),
            textScaler: const TextScaler.linear(2)),
        child: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => SpinWheelLayout(
                      header: const SizedBox(height: 56),
                      board: const SizedBox(width: 484, height: 548),
                      footer:
                          const SizedBox(height: 280, child: Text('Records')),
                      selectedAmount: selected,
                      onAmountChanged: (v) => setState(() => selected = v),
                    ))),
      )));
      for (final (label, amount) in [
        ('100k', 100000),
        ('10k', 10000),
        ('1k', 1000),
        ('100', 100)
      ]) {
        final chip = find.text(label);
        expect(chip.hitTestable(), findsOneWidget);
        expect(tester.getRect(chip).bottom,
            lessThan(tester.getRect(find.text('Records')).top));
        await tester.tap(chip);
        await tester.pump();
        expect(selected, amount);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Rooms show the same live winner, win count and game icon',
      (tester) async {
    final leader = StateProvider<Map<String, dynamic>?>((_) => null);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          luckySpinWinnerEventProvider
              .overrideWith((ref) => Stream.value(ref.watch(leader))),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: Column(children: [
          GlobalWheelWinnerBanner(),
          GlobalWheelWinnerBanner()
        ])))));
    final state =
        ProviderScope.containerOf(tester.element(find.byType(Scaffold)))
            .read(leader.notifier);
    await tester.pump();
    expect(find.byType(GameTopWinnerBanner), findsNothing);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (name, wins) in [('Israt', 8000), ('Rashid', 13000)]) {
      state.state = {
        'eventId': 'event_$name',
        'roundId': 'test_round',
        'announcedAtMs': now,
        'uid': name,
        'amount': wins,
        'avatar': '',
      };
      await tester.pump();
      await tester.pump();
      expect(find.byType(GameTopWinnerBanner), findsNWidgets(2));
      expect(find.text('$wins'), findsNWidgets(2));
    }
    state.state = null;
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(GameTopWinnerBanner), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
