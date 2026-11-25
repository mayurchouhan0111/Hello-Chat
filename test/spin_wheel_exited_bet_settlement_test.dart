import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/providers/game_provider.dart';
import 'package:hello_chat/core/services/game_service.dart';

class _FakeGameService implements GameService {
  final List<Map<String, dynamic>> playCalls = [];
  final List<String> settledRounds = [];

  @override
  Future<Map<String, dynamic>> playSpinWheel({
    required int betAmount,
    Map<String, int>? bets,
    String? roundId,
    String? roomId,
    String? txnId,
  }) async {
    playCalls.add({
      'betAmount': betAmount,
      'bets': Map<String, int>.from(bets ?? {}),
      'roundId': roundId,
      'roomId': roomId,
      'txnId': txnId,
    });
    return {
      'roundId': roundId ?? '1',
      'totalBet': betAmount,
      'balance': 1000 - betAmount,
    };
  }

  @override
  Future<Map<String, dynamic>> settleSpinWheelRound({
    required String roundId,
    String? txnId,
  }) async {
    settledRounds.add(roundId);
    return {
      'settled': true,
      'roundId': roundId,
      'prize': 500,
      'balance': 1400,
      'winningFood': 'Tomato',
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spin Wheel - Automatic Settlement After Early Game Exit', () {
    test('Past unsettled round in history settles immediately via syncFromHistory',
        () async {
      final fakeService = _FakeGameService();
      final container = ProviderContainer(
        overrides: [
          gameServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final settler = container.read(spinWheelBackgroundSettlerProvider);
      final pastRoundId =
          ((DateTime.now().millisecondsSinceEpoch ~/ 40000) - 4).toString();

      settler.syncFromHistory([
        {
          'docId': 'spin_$pastRoundId',
          'game': 'spin_wheel',
          'roundId': pastRoundId,
          'totalBet': 3300000,
          'settled': false,
        }
      ]);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeService.settledRounds, equals([pastRoundId]));

      // Calling syncFromHistory again for an already-settled round is a no-op
      settler.syncFromHistory([
        {
          'docId': 'spin_$pastRoundId',
          'game': 'spin_wheel',
          'roundId': pastRoundId,
          'totalBet': 3300000,
          'settled': true,
          'status': 'ROUND_SETTLED',
        }
      ]);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(fakeService.settledRounds.length, equals(1));
    });

    test('Exiting with unconfirmed bets flushes playSpinWheel and settles completed round',
        () async {
      final fakeService = _FakeGameService();
      final container = ProviderContainer(
        overrides: [
          gameServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final settler = container.read(spinWheelBackgroundSettlerProvider);
      final completedRoundId =
          ((DateTime.now().millisecondsSinceEpoch ~/ 40000) - 1).toString();

      await settler.flushBetAndScheduleSettlement(
        roundId: completedRoundId,
        bets: {'Cabbage': 100, 'Corn': 200},
        roomId: 'room_1',
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeService.playCalls.length, equals(1));
      expect(fakeService.playCalls.first['betAmount'], equals(300));
      expect(fakeService.settledRounds, contains(completedRoundId));
    });

    test('In-progress round schedules future settlement timer rather than settling prematurely',
        () async {
      final fakeService = _FakeGameService();
      final container = ProviderContainer(
        overrides: [
          gameServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(container.dispose);

      final settler = container.read(spinWheelBackgroundSettlerProvider);
      final futureRoundId =
          ((DateTime.now().millisecondsSinceEpoch ~/ 40000) + 10).toString();

      settler.trackRound(futureRoundId);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeService.settledRounds, isEmpty);
    });
  });
}
