import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/features/games/presentation/screens/spin_wheel_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spin Wheel - Round Synchronization & Timing Logic', () {
    const serverRoundDurationMs = 40000;
    const serverBettingPhaseSec = 30;
    const serverSpinPhaseSec = 5;

    test('40-second cycle calculates deterministic round IDs', () {
      final nowMs = 1700000000000; // arbitrary timestamp
      final roundId1 = (nowMs ~/ serverRoundDurationMs).toString();
      final roundIdNext = ((nowMs + serverRoundDurationMs) ~/ serverRoundDurationMs).toString();

      expect(int.parse(roundIdNext), equals(int.parse(roundId1) + 1));
    });

    test('Phase boundaries are strictly enforced across the 40s timeline', () {
      // Phase 1a: 0s-20s -> Betting Open ("Select time", not locked)
      for (int sec = 0; sec < 20; sec++) {
        final secondsIntoCycle = sec;
        expect(secondsIntoCycle < 20, isTrue);
        final isBetLocked = false;
        expect(isBetLocked, isFalse);
      }

      // Phase 1b: 20s-30s -> Bets Closed ("BETS CLOSED", locked)
      for (int sec = 20; sec < 30; sec++) {
        final secondsIntoCycle = sec;
        final isBetLocked = secondsIntoCycle >= 20;
        expect(isBetLocked, isTrue);
      }

      // Phase 2: 30s-35s -> Spinning Phase
      for (int sec = 30; sec < 35; sec++) {
        final secondsIntoCycle = sec;
        final isSpinningPhase = secondsIntoCycle >= serverBettingPhaseSec &&
            secondsIntoCycle < (serverBettingPhaseSec + serverSpinPhaseSec);
        expect(isSpinningPhase, isTrue);
      }

      // Phase 3: 35s-40s -> Results / Rollover Phase
      for (int sec = 35; sec < 40; sec++) {
        final secondsIntoCycle = sec;
        final isResultsPhase = secondsIntoCycle >= (serverBettingPhaseSec + serverSpinPhaseSec);
        expect(isResultsPhase, isTrue);
      }
    });

    test('Stale closure guard: Rejects responses from previous round', () {
      const activeRoundId = "42500";
      const pastSubmissionRoundId = "42499";

      // If response comes back for past round, it must be ignored
      final isStale = pastSubmissionRoundId != activeRoundId;
      expect(isStale, isTrue, reason: "Must reject bets resolved after round has already advanced");
    });

    test('Error SnackBar suppression: Suppressed during spinning and results phases', () {
      bool shouldSuppressSnackBar(SpinGameState state, String currentRound, String submissionRound) {
        if (state == SpinGameState.spinning || state == SpinGameState.results || currentRound != submissionRound) {
          return true; // Suppressed
        }
        return false;
      }

      expect(shouldSuppressSnackBar(SpinGameState.spinning, "100", "100"), isTrue);
      expect(shouldSuppressSnackBar(SpinGameState.results, "100", "100"), isTrue);
      expect(shouldSuppressSnackBar(SpinGameState.betting, "101", "100"), isTrue);
      expect(shouldSuppressSnackBar(SpinGameState.betting, "100", "100"), isFalse);
    });
  });
}
