import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'package:hello_chat/core/providers/game_provider.dart';
import 'package:hello_chat/core/services/game_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/wakelock_service.dart';
import 'package:hello_chat/core/services/game_recovery_service.dart';
import 'package:hello_chat/core/services/network_connectivity_service.dart';

enum SpinGameState { betting, spinning, results }

class SpinWheelScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const SpinWheelScreen({super.key, this.roomId});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  double _pointerAngle = 0.0;
  int _countdown = 30;
  Timer? _timer;
  int _currentSegment = 0;
  Map<String, int> _currentBets = {};
  Map<String, int> _betClickCounts = {};
  Map<String, int> _confirmedBets = {};
  String? _focusedIcon;
  String? _lastResultType;
  int _selectedChipValue = 100;
  int _todayProfits = 0;
  bool _isSpinning = false;
  bool _isBetLocked = false;
  bool _isOffline = false;
  bool _platformHasNetwork = true;
  bool? _rtdbConnected;
  Timer? _debounceTimer;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _platformConnectivitySub;

  Map<String, dynamic>? _pendingRoundResult;
  bool _hasPendingResult = false;
  String? _resultPendingRoundId;

  Map<String, dynamic>? _submittedSpinResult;
  bool _isAutoSubmitting = false;

  // Stored result for server-clock-synced display
  SpinItem? _storedWinItem;
  int _storedPrize = 0;
  int _storedWager = 0;
  List<dynamic> _storedWinners = [];
  String _storedRoundId = '';
  Map<String, int>? _storedBets;

  String? _hasShownResultForRound;
  bool _isBottomSheetOpen = false;
  Route? _bottomSheetRoute;
  DateTime? _bottomSheetOpenTime;
  String? _currentRoundId;

  int _roundTransitionCountdown = 0;
  bool _showRoundTransition = false;
  String _countdownLabel = "Select time";

  late AnimationController _idleController;
  late AnimationController _spinController;
  Animation<double>? _spinAnimation;
  Timer? _spinFallbackTimer;
  int _optimisticWinnings = 0;
  SpinGameState _gameState = SpinGameState.betting;
  Map<String, dynamic>? _currentSpinOutcome;

  // Track cached sound paths to avoid socket exceptions
  String? _localBetSoundPath;
  String? _localSpinSoundPath;
  String? _localWinSoundPath;

  void _precacheSounds() {}
  void _playBetSoundAndHaptic() {}
  void _playCountdownTick() {}

  bool _isShowingConnectionDialog = false;

  void _showConnectionNotFoundDialog({String? title, String? message}) {
    if (!mounted || _isShowingConnectionDialog) return;
    _isShowingConnectionDialog = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.amber.withOpacity(0.3), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title ?? "Connection Not Found",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message ?? "Unable to reach server. Please check your internet connection and try again.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: const Text("CLOSE"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFACC15),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final online = await NetworkConnectivityService().checkConnection();
                        if (mounted) {
                          _updateOfflineState(platformOnline: online);
                        }
                      },
                      child: const Text(
                        "RETRY",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isShowingConnectionDialog = false;
    });
  }

  void _placeBet(String itemName, List<SpinItem> items) {
    if (_isBetLocked || _isOffline || !_platformHasNetwork) {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ Bet blocked on "$itemName": isBetLocked=$_isBetLocked, isOffline=$_isOffline, platformHasNetwork=$_platformHasNetwork');
      if (mounted && (_isOffline || !_platformHasNetwork)) {
        _showConnectionNotFoundDialog();
      }
      return;
    }

    final lowerName = itemName.toLowerCase().trim();
    if (lowerName == 'salad' || lowerName == 'pizza') {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ Direct bet on category alias "$itemName" ignored');
      return;
    }

    final matchedItem = items.firstWhere(
      (item) => item.name.toLowerCase().trim() == itemName.toLowerCase().trim(),
      orElse: () => SpinItem(name: itemName, multiplier: 1, emoji: ''),
    );
    final exactName = matchedItem.name;

    final wallet = ref.read(walletBalanceProvider).value;
    final diamonds = wallet?['diamonds'] ?? 0;
    final beans = wallet?['beans'] ?? 0;
    final totalPlayingPower = diamonds + (beans * 2 / 7).floor();

    final currentTotalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    if (currentTotalBet + _selectedChipValue > totalPlayingPower) {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ Bet rejected on "$exactName": Insufficient funds (required: ${currentTotalBet + _selectedChipValue}, available: $totalPlayingPower)');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient Diamonds & Stars"))
      );
      return;
    }

    _playBetSoundAndHaptic();

    setState(() {
      _currentBets[exactName] = (_currentBets[exactName] ?? 0) + _selectedChipValue;
      _betClickCounts[exactName] = (_betClickCounts[exactName] ?? 0) + 1;
      _confirmedBets = {};
    });

    final newTotalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    debugPrint('[SPIN_WHEEL_EVENT] 🎲 Bet Placed on "$exactName": chip=$_selectedChipValue, itemTotal=${_currentBets[exactName]}, totalWager=$newTotalBet, clicks=${_betClickCounts[exactName]}');

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _currentBets.isEmpty) return;
      _autoSubmitBets();
    });

    _persistBetState();
  }

  bool _persistScheduled = false;
  void _persistBetState() {
    if (_persistScheduled) return;
    _persistScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistScheduled = false;
      if (!mounted) return;
      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final roundId = (now ~/ serverRoundMs).toString();
      GameRecoveryService().saveBetState(
        bets: _currentBets,
        betClickCounts: _betClickCounts,
        roundId: roundId,
        timestamp: now,
      );
    });
  }

  bool _hasPendingAdditionalBets = false;

  bool _hasUnconfirmedBets() {
    for (final entry in _currentBets.entries) {
      if ((_confirmedBets[entry.key] ?? 0) < entry.value) {
        return true;
      }
    }
    return false;
  }

  Future<void> _autoSubmitBets() async {
    if (_currentBets.isEmpty || _isOffline || !_platformHasNetwork) return;

    if (_isAutoSubmitting) {
      _hasPendingAdditionalBets = true;
      debugPrint('[SPIN_WHEEL_EVENT] ⏳ Auto-submit already in flight; queued pending bets for next batch');
      return;
    }

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;
    final submissionRoundId = (now ~/ serverRoundMs).toString();

    if (secondsIntoCycle >= 30) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Auto-submit aborted: secIntoCycle ($secondsIntoCycle) >= 30s for round $submissionRoundId');
      return;
    }

    final snapshotBets = Map<String, int>.from(_currentBets);
    final totalBet = snapshotBets.values.fold(0, (sum, val) => sum + val);
    if (totalBet <= 0) return;

    _isAutoSubmitting = true;
    _hasPendingAdditionalBets = false;
    debugPrint('[SPIN_WHEEL_EVENT] 🚀 Auto-submitting bets to backend: totalBet=$totalBet, bets=$snapshotBets, roundId=$submissionRoundId, secIntoCycle=$secondsIntoCycle');
    final remainingMs = 28000 - (now % serverRoundMs);
    final timeoutMs = remainingMs > 5000 ? remainingMs.clamp(5000, 22000) : 5000;
    try {
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: totalBet,
        bets: snapshotBets,
        roundId: submissionRoundId,
        roomId: widget.roomId,
      ).timeout(Duration(milliseconds: timeoutMs));

      if (!mounted) return;

      // STALE CLOSURE GUARD: If round changed while request was in flight, discard response
      if (_currentRoundId != submissionRoundId) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Stale bet response ignored for round $submissionRoundId (current: $_currentRoundId)');
        return;
      }

      final resultRoundId = result['roundId']?.toString();
      final serverTime = (result['serverTime'] as num?)?.toInt();
      if (serverTime != null) {
        final localNow = DateTime.now().millisecondsSinceEpoch;
        _serverTimeOffset = serverTime - localNow;
        debugPrint('[SPIN_WHEEL_EVENT] 🕒 Server time synchronized from API: offset=$_serverTimeOffset ms');
      }

      if (resultRoundId == submissionRoundId) {
        debugPrint('[SPIN_WHEEL_EVENT] ✅ Bets successfully confirmed by backend! roundId=$resultRoundId, prize=${result['prize']}, bets=$snapshotBets');
        _submittedSpinResult = result;
        setState(() {
          _confirmedBets = Map.from(snapshotBets);
        });
        GameRecoveryService().clearBetState();
        ref.invalidate(userGameHistoryProvider);
      }
    } catch (e) {
      debugPrint("[SPIN_WHEEL_EVENT] ❌ Auto-submit bets failed: $e. Handled gracefully.");
      _hasStartedFallbackCall = false;

      if (!mounted) return;

      // If user already has confirmed bets or an authoritative result, never wipe or show error!
      if (_submittedSpinResult != null || _confirmedBets.isNotEmpty) {
        debugPrint('[SPIN_WHEEL_EVENT] ℹ️ Suppressed error: User already has confirmed bets or result in place.');
        return;
      }

      // STRICT PHASE GUARD: Never show late bet failure during spinning or results phase!
      if (_gameState != SpinGameState.betting || _currentRoundId != submissionRoundId) {
        debugPrint('[SPIN_WHEEL_EVENT] 🔇 Suppressed late bet error during ${_gameState.name} phase.');
        return;
      }

      final errorStr = e.toString();
      if (errorStr.contains('failed-precondition') || errorStr.contains('Betting phase closed')) {
        setState(() {
          _currentBets = {};
          _betClickCounts = {};
          _confirmedBets = {};
          _submittedSpinResult = null;
        });
        GameRecoveryService().clearBetState();
      } else if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline) {
        _showConnectionNotFoundDialog();
      }
    } finally {
      _isAutoSubmitting = false;
      // If user placed additional bets while this network call was in flight, immediately dispatch the next batch!
      if (mounted && (_hasPendingAdditionalBets || _hasUnconfirmedBets())) {
        _hasPendingAdditionalBets = false;
        final currentSec = (_synchronizedTimeMs % 40000) ~/ 1000;
        if (_gameState == SpinGameState.betting && currentSec < 30) {
          debugPrint('[SPIN_WHEEL_EVENT] 🔄 In-flight call finished; dispatching queued delta bets now...');
          _autoSubmitBets();
        }
      }
    }
  }

  Future<void> _preFetchRoundOutcome() async {
    if (_isOffline || _isAutoSubmitting || _hasPendingResult || _submittedSpinResult != null) return;

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;
    final currentRoundId = (now ~/ serverRoundMs).toString();

    if (secondsIntoCycle >= 30) return;

    try {
      debugPrint('[SPIN_WHEEL_EVENT] ⚡ Pre-fetching spectator outcome for round $currentRoundId at ${secondsIntoCycle}s window...');
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: 0,
        bets: {},
        roomId: widget.roomId,
      );

      if (!mounted) return;

      final resultRoundId = result['roundId']?.toString();
      final serverTime = (result['serverTime'] as num?)?.toInt();
      if (serverTime != null) {
        final localNow = DateTime.now().millisecondsSinceEpoch;
        _serverTimeOffset = serverTime - localNow;
        debugPrint('[SPIN_WHEEL_EVENT] 🕒 Server time synchronized from spectator API: offset=$_serverTimeOffset ms');
      }
      if (resultRoundId == currentRoundId) {
        _pendingRoundResult = result;
        _hasPendingResult = true;
        _resultPendingRoundId = resultRoundId;
        debugPrint('[SPIN_WHEEL_EVENT] ⚡ Spectator outcome pre-fetched: roundId=$resultRoundId, item=${result['name']}, multiplier=${result['multiplier']}x, sector=${result['sectorIndex']}');
      }
    } catch (e) {
      debugPrint("[SPIN_WHEEL_EVENT] ⚠️ Spectator pre-fetch failed: $e");
      _hasStartedFallbackCall = true;
    }
  }

  int _tickCurrentIndex = 0;
  int _tickTargetIndex = 0;
  int _currentTickIndex = 0;
  List<double> _tickDurations = [];
  List<double> _tickFireTimes = [];
  Timer? _tickTimer;
  bool _isProcessingSpin = false;

  bool _spinCompleted = false;
  bool _resultLock = false;
  int? _lastCalculatedRound;
  Map<String, dynamic>? _lastGlobalOutcome;
  Map<String, dynamic>? _lastRoundResultForHistory;
  BuildContext? _bottomSheetContext;
  
  int _serverTimeOffset = 0;
  StreamSubscription? _offsetSubscription;
  StreamSubscription? _rtdbRoundSubscription;
  StreamSubscription? _rtdbRecentResultsSubscription;
  final List<Map<String, dynamic>> _realtimeRecentResults = [];
  String? _hasSpunForRound;
  bool _hasStartedFallbackCall = false;

  int get _synchronizedTimeMs {
    return DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
  }

  void _recordRoundOutcomeForRecentResults(Map<String, dynamic> outcome) {
    final rId = outcome['roundId']?.toString();
    if (rId == null || rId.isEmpty) return;
    final exists = _realtimeRecentResults.any((r) => r['roundId']?.toString() == rId);
    if (!exists && mounted) {
      setState(() {
        _realtimeRecentResults.insert(0, {
          'roundId': rId,
          'name': outcome['name'] ?? '',
          'emoji': outcome['emoji'] ?? '',
          'label': outcome['label'] ?? '${outcome['multiplier']}x',
          'multiplier': (outcome['multiplier'] as num?)?.toInt() ?? 5,
          'category': outcome['category'] ?? 'standard',
          'timestamp': outcome['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        });
        if (_realtimeRecentResults.length > 30) {
          _realtimeRecentResults.removeRange(30, _realtimeRecentResults.length);
        }
      });
    }
  }

  void _subscribeToRealtimeRoundState() {
    _rtdbRoundSubscription = FirebaseDatabase.instance
        .ref('lucky_spin_stats/lastGlobalOutcome')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;

      try {
        final rawData = event.snapshot.value;
        if (rawData is Map) {
          final outcome = Map<String, dynamic>.from(rawData);
          final roundId = outcome['roundId']?.toString();

          debugPrint('[SPIN_WHEEL_EVENT] 📡 RTDB stream event received for round $roundId: name=${outcome['name']}, sector=${outcome['sectorIndex']}, multiplier=${outcome['multiplier']}x');

          // Always store the latest outcome for "Last Winner" display and realtime result bar
          if (roundId != null) {
            _lastGlobalOutcome = outcome;
            _recordRoundOutcomeForRecentResults(outcome);
          }

          final now = _synchronizedTimeMs;
          const serverRoundMs = 40000;
          final currentRoundId = (now ~/ serverRoundMs).toString();

          if (roundId == currentRoundId) {
            _pendingRoundResult = outcome;
            _hasPendingResult = true;
            _resultPendingRoundId = roundId;

            // Store the result; the main countdown timer will pick it up
            // and trigger the spin. This avoids calling _startSpin directly
            // from a stream callback which can cause re-entrant setState issues.
            final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;
            if (secondsIntoCycle >= 30 && secondsIntoCycle < 35 && _hasSpunForRound != currentRoundId && !_isSpinning && !_isProcessingSpin) {
              debugPrint('[SPIN_WHEEL_EVENT] ⚡ Realtime DB WebSocket stream triggering spin for round $roundId at ${secondsIntoCycle}s');
              _hasSpunForRound = currentRoundId;
              _isProcessingSpin = true;
              _startSpin(outcome);
            }
          }
        }
      } catch (e) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Error parsing RTDB lastGlobalOutcome: $e');
      }
    });

    _rtdbRecentResultsSubscription = FirebaseDatabase.instance
        .ref('lucky_spin_stats/recentResults')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      try {
        final val = event.snapshot.value;
        if (val is List && mounted) {
          setState(() {
            for (final item in val) {
              if (item is Map) {
                final map = Map<String, dynamic>.from(item);
                final rId = map['roundId']?.toString();
                if (rId != null && !_realtimeRecentResults.any((r) => r['roundId']?.toString() == rId)) {
                  _realtimeRecentResults.add(map);
                }
              }
            }
            _realtimeRecentResults.sort((a, b) {
              final aId = int.tryParse(a['roundId']?.toString() ?? '0') ?? 0;
              final bId = int.tryParse(b['roundId']?.toString() ?? '0') ?? 0;
              return bId.compareTo(aId);
            });
            if (_realtimeRecentResults.length > 30) {
              _realtimeRecentResults.removeRange(30, _realtimeRecentResults.length);
            }
          });
        }
      } catch (e) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Error parsing RTDB recentResults: $e');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[SPIN_WHEEL_EVENT] 🎬 Game Screen Initialized (roomId: ${widget.roomId ?? "None"})');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WakelockService().acquire();
      debugPrint('[SPIN_WHEEL_EVENT] 🔒 Wakelock acquired for spin wheel game');
    });

    _subscribeToRealtimeRoundState();

    _offsetSubscription = FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (mounted) {
        final offset = (event.snapshot.value as num?)?.toInt() ?? 0;
        debugPrint('[SPIN_WHEEL_EVENT] 🕒 Server time offset synced: offset = $offset ms');
        setState(() {
          _serverTimeOffset = offset;
        });
      }
    });

    // Firebase RTDB connection state
    _connectivitySub = FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) {
      if (!mounted) return;
      final rtdbConnected = event.snapshot.value as bool? ?? false;
      debugPrint('[SPIN_WHEEL_EVENT] 📡 Firebase RTDB .info/connected = $rtdbConnected');
      _updateOfflineState(rtdbConnected: rtdbConnected);
    });

    // Platform network connectivity (WiFi / Mobile data) via NetworkConnectivityService
    _platformConnectivitySub = NetworkConnectivityService().onConnectivityChanged.listen((hasNetwork) {
      if (!mounted) return;
      debugPrint('[SPIN_WHEEL_EVENT] 📶 Platform connectivity changed: hasNetwork=$hasNetwork');
      _updateOfflineState(platformOnline: hasNetwork);
    });

    // Initial platform check
    final initialOnline = NetworkConnectivityService().isOnline;
    debugPrint('[SPIN_WHEEL_EVENT] 📶 Initial platform connectivity: isOnline=$initialOnline');
    _updateOfflineState(platformOnline: initialOnline);
    NetworkConnectivityService().checkConnection().then((hasNetwork) {
      if (!mounted) return;
      _updateOfflineState(platformOnline: hasNetwork);
    });

    _lastCalculatedRound = _calculateCurrentRound();
    debugPrint('[SPIN_WHEEL_EVENT] 🎯 Initial calculated round: $_lastCalculatedRound (synchronizedMs: $_synchronizedTimeMs)');
    _idleController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _idleController.addListener(() {
      if (_gameState != SpinGameState.betting || _isSpinning || _spinCompleted || !mounted) return;

      final double currentAngle = _idleController.value * 2 * math.pi;
      final double step = 2 * math.pi / 8;
      double normalized = (currentAngle + step / 2) % (2 * math.pi);
      if (normalized < 0) normalized += 2 * math.pi;
      final int segment = (normalized / step).floor() % 8;

      // Only call setState when the visual segment actually changes
      if (segment != _currentSegment) {
        setState(() {
          _pointerAngle = currentAngle;
          _currentSegment = segment;
        });
      } else {
        _pointerAngle = currentAngle;
      }
    });

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _spinController.addListener(() {
      if (_spinAnimation != null && mounted) {
        final double animVal = _spinAnimation!.value;
        final int stepCount = animVal.round();
        final int segment = ((stepCount % 8) + 8) % 8;
        if (segment != _currentSegment || _pointerAngle != animVal) {
          setState(() {
            _currentSegment = segment;
            _pointerAngle = animVal * (2 * math.pi / 8);
          });
        }
      }
    });
    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleDecelerationComplete();
      }
    });

    _precacheSounds();
    _startCountdown();
    _playPhaseSound(SpinGameState.betting);

    _tryRecoverGameState();
  }

  Future<void> _tryRecoverGameState() async {
    try {
      if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline) {
        await GameRecoveryService().clearBetState();
        return;
      }

      final saved = await GameRecoveryService().loadBetState();
      if (saved == null || !mounted) return;

      final savedRoundId = saved['roundId'] as String?;
      final savedBets = saved['bets'] as Map<String, dynamic>?;
      final savedClickCounts = saved['betClickCounts'] as Map<String, dynamic>?;
      final savedTimestamp = saved['timestamp'] as int?;

      if (savedRoundId == null || savedBets == null || savedTimestamp == null) return;

      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final _currentRoundId = (now ~/ serverRoundMs).toString();
      final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;

      // Only recover if the saved state is for the current round and betting is not locked yet
      if (savedRoundId != _currentRoundId || secondsIntoCycle >= 25) {
        await GameRecoveryService().clearBetState();
        return;
      }

      // Check if state is recent enough (within last 60 seconds)
      final age = now - savedTimestamp;
      if (age > 60000) {
        await GameRecoveryService().clearBetState();
        return;
      }

      if (mounted) {
        setState(() {
          for (final entry in savedBets.entries) {
            _currentBets[entry.key] = (entry.value as num).toInt();
          }
          for (final entry in (savedClickCounts ?? {}).entries) {
            _betClickCounts[entry.key] = (entry.value as num).toInt();
          }
        });
        debugPrint("[SPIN_WHEEL_EVENT] ♻️ Game recovery: Restored bets for round $savedRoundId: $_currentBets");
        // Re-submit restored bets if still in betting phase
        final secondsIntoCycle = (_synchronizedTimeMs % serverRoundMs) ~/ 1000;
        if (secondsIntoCycle < 30) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted && _currentBets.isNotEmpty) _autoSubmitBets();
          });
        }
      }
    } catch (e) {
      debugPrint("⚠️ Game recovery failed: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused) {
      // Save current game state on pause
      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final roundId = (now ~/ serverRoundMs).toString();
      GameRecoveryService().saveBetState(
        bets: _currentBets,
        betClickCounts: _betClickCounts,
        roundId: roundId,
        timestamp: now,
      );
      // Release wakelock when app goes to background
      WakelockService().release();
    } else if (state == AppLifecycleState.resumed) {
      // Re-acquire wakelock when app comes to foreground
      WakelockService().acquire();
    }
  }

  void _playPhaseSound(SpinGameState state) {}

  int _calculateCurrentRound() {
    final nowMs = _synchronizedTimeMs;
    const roundDuration = 40000;
    final startOfRoundEpochMs = (nowMs ~/ roundDuration) * roundDuration;
    final startOfRoundDate = DateTime.fromMillisecondsSinceEpoch(startOfRoundEpochMs, isUtc: true);
    final startOfDayUtc = DateTime.utc(startOfRoundDate.year, startOfRoundDate.month, startOfRoundDate.day);
    return ((startOfRoundEpochMs - startOfDayUtc.millisecondsSinceEpoch) ~/ roundDuration) + 1;
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;

      const serverRoundDurationMs = 40000;
      const serverBettingPhaseSec = 30;
      const serverSpinPhaseSec = 5;

      final now = _synchronizedTimeMs;
      final secondsIntoCycle = (now % serverRoundDurationMs) ~/ 1000;
      final msIntoCycle = now % serverRoundDurationMs;
      final currentRoundVal = _calculateCurrentRound();
      final currentRoundIdStr = (now ~/ serverRoundDurationMs).toString();

      // Rollover / Invalidations on a new round
      final bool isNewRound = (_lastCalculatedRound != null && currentRoundVal != _lastCalculatedRound) ||
          (_currentRoundId != null && currentRoundIdStr != _currentRoundId);
      _currentRoundId = currentRoundIdStr;

      if (isNewRound) {
        debugPrint('[SPIN_WHEEL_EVENT] 🔄 Round Rollover: Round $_lastCalculatedRound -> $currentRoundVal (roundId: $_currentRoundId). Resetting bets and state.');
        _dismissBottomSheet();
        _clearStoredResult();

        _spinFallbackTimer?.cancel();
        _spinController.stop();
        _spinController.reset();

        setState(() {
          _currentBets = {};
          _betClickCounts = {};
          _confirmedBets = {};
          _submittedSpinResult = null;
          _isAutoSubmitting = false;
          _hasPendingAdditionalBets = false;
          _hasSpunForRound = null;
          _hasStartedFallbackCall = false;
          _hasShownResultForRound = null;
          _isProcessingSpin = false;
          _isSpinning = false;
          _spinAnimation = null;
          _optimisticWinnings = 0;
          _currentSpinOutcome = null;
          _pendingRoundResult = null;
          _hasPendingResult = false;
          _resultPendingRoundId = null;
          _resultLock = false;
          _spinCompleted = false;
          _lastRoundResultForHistory = null;
          _showRoundTransition = false;
        });

        ref.invalidate(luckySpinStatsProvider);
        ref.invalidate(userGameHistoryProvider);
      }
      _lastCalculatedRound = currentRoundVal;

      // Batch all state changes into a single setState
      bool needsBuild = false;
      String newCountdownLabel = _countdownLabel;
      int newCountdown = _countdown;
      bool newBetLocked = _isBetLocked;
      bool newShowTransition = _showRoundTransition;
      int newTransitionCountdown = _roundTransitionCountdown;
      SpinGameState newGameState = _gameState;

      // Round transition countdown (last 3 seconds before next round: 37s, 38s, 39s)
      final transitionStart = serverBettingPhaseSec + serverSpinPhaseSec + 2; // 37s
      if (secondsIntoCycle >= transitionStart && secondsIntoCycle < serverRoundDurationMs ~/ 1000) {
        _dismissBottomSheet();
        final remaining = (serverRoundDurationMs ~/ 1000) - secondsIntoCycle;
        if (remaining <= 3 && remaining >= 1) {
          if (!newShowTransition) {
            newShowTransition = true;
            needsBuild = true;
          }
          if (remaining != newTransitionCountdown) {
            newTransitionCountdown = remaining;
            needsBuild = true;
          }
        }
      } else {
        if (newShowTransition) {
          newShowTransition = false;
          needsBuild = true;
        }
      }

      // PHASE-AWARE COUNTDOWN & STATE SYNCHRONIZATION
      // 0s-25s: Betting Open ("Select time", 30->6s)
      // 25s-30s: Bets Closed ("BETS CLOSED", 5->1s, lock bets)
      // 30s-35s: Spinning ("Spinning", 0s, lock bets)
      // 35s-37s: Winning & Results ("Winning", lock bets)
      // 37s-40s: Rollover ("Next Round", 3->1s, lock bets)

      // Total betting time: 30s
      // 0s-26s: Betting allowed ("Select time", 30->4s)
      // 27s-29s: Bets locked during final 3s ("BETS CLOSED", 3->1s)
      // 30s-35s: Spinning ("Spinning", 0s)
      // 35s-37s: Winning & Results ("Winning")
      // 37s-40s: Rollover ("Next Round", 3->1s)

      if (secondsIntoCycle < 27) {
        newBetLocked = false;
        newGameState = SpinGameState.betting;
        newCountdown = 30 - secondsIntoCycle;
        newCountdownLabel = "Select time";
      } else if (secondsIntoCycle >= 27 && secondsIntoCycle < 30) {
        if (!newBetLocked) {
          debugPrint('[SPIN_WHEEL_EVENT] 🔒 Phase 1b: BETS CLOSED at 27s (3s remaining in round $_currentRoundId, locking & auto-submitting)');
        }
        newBetLocked = true;
        newGameState = SpinGameState.betting;
        newCountdown = 30 - secondsIntoCycle;
        newCountdownLabel = "BETS CLOSED";
        if (!_isAutoSubmitting) {
          if (_hasUnconfirmedBets()) {
            _autoSubmitBets();
          } else if (_currentBets.isEmpty && !_hasPendingResult && !_hasStartedFallbackCall) {
            _hasStartedFallbackCall = true;
            _preFetchRoundOutcome();
          }
        }
      } else if (secondsIntoCycle >= 30 && secondsIntoCycle < 35) {
        newBetLocked = true;
        newGameState = SpinGameState.spinning;
        newCountdown = 0;
        newCountdownLabel = "Spinning";
      } else if (secondsIntoCycle >= 35 && secondsIntoCycle < 37) {
        newBetLocked = true;
        newGameState = SpinGameState.results;
        newCountdown = 40 - secondsIntoCycle;
        newCountdownLabel = "Winning";
      } else {
        newBetLocked = true;
        newGameState = SpinGameState.results;
        newCountdown = 40 - secondsIntoCycle;
        newCountdownLabel = "Next Round";
      }

      if (newCountdown != _countdown || newCountdownLabel != _countdownLabel || newBetLocked != _isBetLocked) {
        needsBuild = true;
        if (newCountdown <= 5 && newCountdown > 0 && !_isBetLocked) {
          _playCountdownTick();
        }
      }

      // PHASE 1: BETTING / IDLE
      if (secondsIntoCycle < serverBettingPhaseSec) {
        // HARD ENFORCEMENT: Bottom sheet and past stored results MUST NEVER exist during betting!
        if (_isBottomSheetOpen || _bottomSheetContext != null || _bottomSheetRoute != null) {
          _dismissBottomSheet();
        }
        if (_storedWinItem != null) {
          _clearStoredResult();
        }

        if (_gameState != SpinGameState.betting && !_isSpinning) {
          debugPrint('[SPIN_WHEEL_EVENT] 🟢 Entering Phase 1: BETTING OPEN (roundId: $_currentRoundId, secIntoCycle: $secondsIntoCycle, remaining: ${serverBettingPhaseSec - secondsIntoCycle}s)');
          newGameState = SpinGameState.betting;
          _spinCompleted = false;
          _playPhaseSound(SpinGameState.betting);
          _idleController.repeat();
          needsBuild = true;
        }
      }
      // PHASE 2: SPINNING PHASE
      else if (secondsIntoCycle >= serverBettingPhaseSec && secondsIntoCycle < serverBettingPhaseSec + serverSpinPhaseSec) {
        if (_gameState != SpinGameState.spinning && !_isSpinning && _hasSpunForRound != _currentRoundId) {
          debugPrint('[SPIN_WHEEL_EVENT] 🌀 Entering Phase 2: SPINNING (roundId: $_currentRoundId, msIntoCycle: $msIntoCycle)');
          newGameState = SpinGameState.spinning;
          needsBuild = true;
        }

        if (_hasSpunForRound != _currentRoundId && !_isSpinning && !_isProcessingSpin) {
          Map<String, dynamic>? availableOutcome;
          if (_submittedSpinResult != null && _submittedSpinResult!['roundId']?.toString() == _currentRoundId) {
            availableOutcome = Map<String, dynamic>.from(_submittedSpinResult!);
            if (_hasPendingResult && _pendingRoundResult != null && _resultPendingRoundId == _currentRoundId) {
              if (availableOutcome['todayWinners'] == null) {
                availableOutcome['todayWinners'] = _pendingRoundResult!['todayWinners'];
              }
            }
          } else if (_hasPendingResult && _resultPendingRoundId == _currentRoundId) {
            availableOutcome = _pendingRoundResult;
          } else {
            final stats = ref.read(luckySpinStatsProvider).value;
            if (stats?['lastGlobalRound']?.toString() == _currentRoundId) {
              availableOutcome = stats?['lastGlobalOutcome'] as Map<String, dynamic>?;
            }
          }

          if (availableOutcome == null && msIntoCycle >= serverBettingPhaseSec * 1000) {
            final roundIdInt = int.tryParse(_currentRoundId ?? '0') ?? 0;
            final defaultSegments = [
              { "name": "Tomato", "multiplier": 5, "emoji": "🍅", "category": "standard" },
              { "name": "Hotdog", "multiplier": 10, "emoji": "🌭", "category": "standard" },
              { "name": "Skewer", "multiplier": 15, "emoji": "🍢", "category": "standard" },
              { "name": "Chicken", "multiplier": 25, "emoji": "🍗", "category": "standard" },
              { "name": "Steak", "multiplier": 45, "emoji": "🥩", "category": "standard" },
              { "name": "Carrot", "multiplier": 5, "emoji": "🥕", "category": "standard" },
              { "name": "Corn", "multiplier": 5, "emoji": "🌽", "category": "standard" },
              { "name": "Cabbage", "multiplier": 5, "emoji": "🥬", "category": "standard" }
            ];
            final deterministicIdx = (roundIdInt * 7 + 3) % defaultSegments.length;
            final fallbackSeg = defaultSegments[deterministicIdx];
            availableOutcome = {
              'roundId': _currentRoundId,
              'sectorIndex': deterministicIdx,
              'name': fallbackSeg['name'],
              'emoji': fallbackSeg['emoji'],
              'multiplier': fallbackSeg['multiplier'],
              'label': '${fallbackSeg['multiplier']}x',
              'category': fallbackSeg['category'],
              'prize': 0,
              'todayWinners': [],
            };
            debugPrint('[SPIN_WHEEL_EVENT] ⚡ Instant 0ms spectator outcome computed for round $_currentRoundId (sector: $deterministicIdx, item: ${fallbackSeg['name']})');
          }

          if (availableOutcome != null) {
            _hasSpunForRound = _currentRoundId;
            _hasPendingResult = false;
            _startSpin(availableOutcome);
          }
        }
      }
      // PHASE 3: RESULTS CELEBRATION
      else if (secondsIntoCycle >= serverBettingPhaseSec + serverSpinPhaseSec) {
        if (_gameState != SpinGameState.results && !_isSpinning) {
          debugPrint('[SPIN_WHEEL_EVENT] 🏆 Entering Phase 3: RESULTS CELEBRATION (roundId: $_currentRoundId, secIntoCycle: $secondsIntoCycle)');
          newGameState = SpinGameState.results;
          needsBuild = true;
        }

        // Show stored result from spin animation
        if (_storedWinItem != null && _hasShownResultForRound != _currentRoundId) {
          _hasShownResultForRound = _currentRoundId;
          _showStoredResult();
        }

        // Late Join / Spectator Catch-up: prefer pending result, fallback to stream
        if (!_resultLock && !_isSpinning && _storedWinItem == null && _hasShownResultForRound != _currentRoundId) {
          Map<String, dynamic>? outcome;
          if (_submittedSpinResult != null && _submittedSpinResult!['roundId']?.toString() == _currentRoundId) {
            outcome = _submittedSpinResult;
          } else if (_hasPendingResult && _resultPendingRoundId == _currentRoundId) {
            outcome = _pendingRoundResult;
          } else {
            final statsAsync = ref.read(luckySpinStatsProvider);
            final stats = statsAsync.value;
            final lastGlobalRound = stats?['lastGlobalRound']?.toString();
            if (lastGlobalRound == _currentRoundId) {
              outcome = stats?['lastGlobalOutcome'] as Map<String, dynamic>?;
            }
          }

          if (outcome != null) {
            final resultSettings = ref.read(gameSettingsProvider).value;
            final segmentsMap = (resultSettings?['segments'] as List? ?? []);
            
            // Default to spectator
            int prize = 0;
            int wager = 0;
            Map<String, int>? betsCopy;

            final int targetIdx = resolveTargetSectorIndex(outcome, segmentsMap);
            final matchingSegment = (targetIdx >= 0 && targetIdx < segmentsMap.length)
                ? segmentsMap[targetIdx]
                : (segmentsMap.isNotEmpty ? segmentsMap.first : {});

            final resultName = outcome['name'] as String? ?? matchingSegment['name'] ?? "";
            final resultEmoji = outcome['emoji'] as String? ?? matchingSegment['emoji'] ?? "";
            final resultCategory = outcome['category'] as String? ?? matchingSegment['category'];

            final winMultiplier = (outcome['multiplier'] as num?)?.toInt() ??
                (matchingSegment['multiplier'] as num?)?.toInt() ??
                5;

            // Authoritative Bet & Prize resolution for celebration catch-up:
            final Map<String, int> activeBets = {};
            if (_submittedSpinResult != null && _submittedSpinResult!['bets'] is Map) {
              for (final entry in (_submittedSpinResult!['bets'] as Map).entries) {
                final k = entry.key.toString();
                final v = (entry.value as num?)?.toInt() ?? 0;
                if (v > 0) activeBets[k] = math.max(activeBets[k] ?? 0, v);
              }
            }
            for (final entry in _confirmedBets.entries) {
              if (entry.value > 0) activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
            }
            for (final entry in _currentBets.entries) {
              if (entry.value > 0) activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
            }

            if (activeBets.isNotEmpty) {
              wager = activeBets.values.fold(0, (sum, val) => sum + val);
              betsCopy = Map<String, int>.from(activeBets);
              final localPrize = calculateSpinWheelPrize(
                bets: activeBets,
                winningName: matchingSegment['name'] ?? resultName,
                winningCategory: resultCategory ?? matchingSegment['category'],
                roundType: outcome['type'] as String? ?? 'standard',
                multiplier: winMultiplier,
              );
              final serverPrize = (_submittedSpinResult != null && _submittedSpinResult!['roundId']?.toString() == _currentRoundId)
                  ? ((_submittedSpinResult!['prize'] as num?)?.toInt() ?? 0)
                  : 0;
              prize = math.max(serverPrize, localPrize);
            } else {
              // Try to recover user's actual bet result from their game history if they were a player
              final history = ref.read(userGameHistoryProvider).value ?? [];
              final matchedHistory = history.where((h) => h['roundId']?.toString() == _currentRoundId).firstOrNull;
              if (matchedHistory != null) {
                prize = (matchedHistory['prize'] as num?)?.toInt() ?? 0;
                wager = (matchedHistory['totalBet'] as num?)?.toInt() ?? 0;
                betsCopy = (matchedHistory['bets'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
              }
            }

            final winningItem = SpinItem(
              name: matchingSegment['name'] ?? resultName,
              multiplier: winMultiplier,
              emoji: resultEmoji.isNotEmpty ? resultEmoji : (matchingSegment['emoji'] ?? '🎰'),
              category: resultCategory ?? matchingSegment['category']
            );

            final roundWinners = outcome['todayWinners'] as List? ?? outcome['roundWinners'] as List? ?? [];
            final roundIdVal = outcome['roundId']?.toString() ?? _currentRoundId ?? '';

            _hasSpunForRound = _currentRoundId;
            _currentSegment = targetIdx;
            _pointerAngle = (targetIdx * (2 * math.pi / 8));
            _spinCompleted = true;
            _recordRoundOutcomeForRecentResults(outcome);
            _resultLock = true;
            _hasPendingResult = false;
            _hasShownResultForRound = _currentRoundId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) {
                 _showResultBottomSheet(
                   context,
                   winningItem,
                   prize,
                   wager,
                   roundWinners,
                   roundIdVal,
                   bets: betsCopy,
                 );
               }
             });
          }
        }
      }

      // Single batched setState for all countdown updates
      if (needsBuild || newGameState != _gameState || newCountdown != _countdown || newCountdownLabel != _countdownLabel || newBetLocked != _isBetLocked || newShowTransition != _showRoundTransition || newTransitionCountdown != _roundTransitionCountdown) {
        setState(() {
          _gameState = newGameState;
          _countdown = newCountdown;
          _countdownLabel = newCountdownLabel;
          _isBetLocked = newBetLocked;
          _showRoundTransition = newShowTransition;
          _roundTransitionCountdown = newTransitionCountdown;
        });
      }
    });
  }

  void _handleSpin() async {
    final settings = ref.read(gameSettingsProvider).value;
    if (settings == null || !settings['isActive'] || _isSpinning) return;

    if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline) {
      if (mounted) {
        _showConnectionNotFoundDialog();
      }
      return;
    }
    
    _isProcessingSpin = true;
    _isSpinning = true;
    _isBetLocked = true;

    // If _autoSubmitBets is currently in flight, wait for it to finish
    if (_isAutoSubmitting) {
      int retries = 0;
      while (_isAutoSubmitting && retries < 30 && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }
    }

    if (!mounted) return;

    // Check if _autoSubmitBets already successfully obtained the result for this round!
    if (_submittedSpinResult != null) {
      final resRoundId = _submittedSpinResult!['roundId']?.toString();
      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final currentRoundId = (now ~/ serverRoundMs).toString();

      if (resRoundId == currentRoundId || resRoundId == null) {
        final result = _submittedSpinResult!;
        _idleController.stop();
        _idleController.reset();
        _tickTimer?.cancel();
        GameRecoveryService().clearBetState();
        _startSpin(result);
        return;
      }
    }

    final wallet = ref.read(walletBalanceProvider).value;
    final diamonds = wallet?['diamonds'] ?? 0;
    final beans = wallet?['beans'] ?? 0;

    final totalBet = _currentBets.values.fold(0, (sum, val) => sum + val);

    final isAlreadyConfirmed = _confirmedBets.isNotEmpty &&
        _confirmedBets.values.fold(0, (sum, val) => sum + val) == totalBet;

    if (totalBet > 0 && !isAlreadyConfirmed) {
      final totalPlayingPower = diamonds + (beans * 2 / 7).floor();
      if (totalPlayingPower < totalBet) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient Diamonds & Stars")));
         setState(() {
           _isSpinning = false;
           _isBetLocked = false;
           _isProcessingSpin = false;
         });
         return;
      }
    }

    setState(() {
      _gameState = SpinGameState.spinning;
      _playPhaseSound(SpinGameState.spinning);
    });

    _idleController.stop();
    _idleController.reset();

    // Start fast Dummy Spin while waiting for network (throttled to prevent catch-up storm)
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_isSpinning) {
        _tickTimer?.cancel();
        return;
      }
      setState(() {
        _currentSegment = (_currentSegment + 1) % 8;
      });
    });

    try {
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: totalBet,
        bets: _currentBets,
        roomId: widget.roomId,
      );
      
      if (!mounted) return;

      
      _tickTimer?.cancel(); // Stop dummy spin
      GameRecoveryService().clearBetState();
      _startSpin(result);

    } catch (e) {
      _tickTimer?.cancel();
      _spinCompleted = false;
      if (mounted) {
        final hadBet = _currentBets.values.fold(0, (sum, val) => sum + val) > 0;
        setState(() {
          _isSpinning = false;
          _isProcessingSpin = false;
          if (hadBet) {
            // Failure happened during bet submission. Clear bet input so user becomes spectator,
            // and clear hasSpun/hasStartedFallback flags so spectator periodic-tick can retry.
            _gameState = SpinGameState.spinning;
            _isBetLocked = true;
            _currentBets = {};
            _betClickCounts = {};
            _hasSpunForRound = null;
            _hasStartedFallbackCall = false;
            GameRecoveryService().clearBetState();
          } else {
            _gameState = SpinGameState.betting;
            _isBetLocked = false;
          }
        });
        
        // If network issue, show dedicated connection dialog
        if (hadBet) {
          final errorStr = e.toString();
          if (_isOffline || !_platformHasNetwork || !NetworkConnectivityService().isOnline || errorStr.contains('network') || errorStr.contains('unavailable') || errorStr.contains('deadline-exceeded')) {
            _showConnectionNotFoundDialog();
          }
        }
      }
    }
  }

  void _startSpin(Map<String, dynamic> outcome) {
    if (!mounted) return;

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;

    // GATING GUARD: Wheel animation MUST NOT launch before 30.0s!
    if (secondsIntoCycle < 30) {
      debugPrint('[SPIN_GAME_LOG] ⏳ Outcome pre-cached in memory at ${secondsIntoCycle}s into round ${outcome['roundId']}. Waiting for 30s spinning phase...');
      return;
    }

    final outcomeRoundId = outcome['roundId']?.toString();
    final activeRoundId = (now ~/ serverRoundMs).toString();

    // Stale Round Guard: If this result belongs to a past round, do NOT disrupt the new round!
    if (outcomeRoundId != null && outcomeRoundId != activeRoundId) {
      debugPrint('[SPIN_GAME_LOG] ⚠️ Discarded stale spin outcome from past round: $outcomeRoundId (current: $activeRoundId)');
      setState(() {
        _isSpinning = false;
        _isProcessingSpin = false;
        _gameState = (secondsIntoCycle < 30) ? SpinGameState.betting : SpinGameState.spinning;
        _isBetLocked = (secondsIntoCycle >= 20);
      });
      return;
    }

    _tickTimer?.cancel();
    _idleController.stop();
    _idleController.reset();
    ScaffoldMessenger.of(context).clearSnackBars();

    _currentSpinOutcome = outcome;

    final settings = ref.read(gameSettingsProvider).value;
    final segmentsMap = (settings?['segments'] as List? ?? []);
    final int targetIdx = resolveTargetSectorIndex(outcome, segmentsMap);
    final int startIdx = _currentSegment;

    // Calculate dynamic spin duration based on time left in 30s-35s phase
    final msIntoCycle = now % serverRoundMs;
    int remainingSpinMs = 35000 - msIntoCycle;
    if (remainingSpinMs < 1200) {
      remainingSpinMs = 1200; // Minimum 1.2s so the user sees a smooth finish
    } else if (remainingSpinMs > 4500) {
      remainingSpinMs = 4500;
    }

    final int distance = (targetIdx - (startIdx % 8) + 8) % 8;
    final int fullRotations = remainingSpinMs > 2500 ? 4 : 2;
    final double totalSegmentSteps = (fullRotations * 8 + distance).toDouble();

    final double startVal = startIdx.toDouble();
    final double targetVal = startVal + totalSegmentSteps;

    _spinAnimation = Tween<double>(
      begin: startVal,
      end: targetVal,
    ).animate(
      CurvedAnimation(
        parent: _spinController,
        curve: Curves.easeOutCubic,
      ),
    );

    setState(() {
      _isSpinning = true;
      _isBetLocked = true;
      _gameState = SpinGameState.spinning;
    });

    _playPhaseSound(SpinGameState.spinning);
    debugPrint('[SPIN_WHEEL_EVENT] 🎡 Starting Hardware-Accelerated Spin: roundId=$outcomeRoundId, startIdx=$startIdx, targetIdx=$targetIdx, duration=${remainingSpinMs}ms');

    _spinController.duration = Duration(milliseconds: remainingSpinMs);
    _spinController.forward(from: 0.0);
  }

  void _handleDecelerationComplete() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    final outcome = _currentSpinOutcome;
    if (outcome == null) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Deceleration complete without active outcome.');
      setState(() {
        _isSpinning = false;
        _isProcessingSpin = false;
      });
      return;
    }

    final roundId = outcome['roundId']?.toString() ?? _currentRoundId ?? "";
    final settings = ref.read(gameSettingsProvider).value;
    final segmentsMap = (settings?['segments'] as List? ?? []);

    final int targetIdx = resolveTargetSectorIndex(outcome, segmentsMap);

    // Authoritative Bet & Prize resolution:
    final bool hasServerResult = _submittedSpinResult != null &&
        (_submittedSpinResult!['roundId']?.toString() == roundId || roundId.isEmpty);

    // Authoritative Bet & Prize resolution:
    // Merge all bets across server receipt, confirmed state, and local bets taking the max wager per item
    final Map<String, int> activeBets = {};
    if (_submittedSpinResult != null && _submittedSpinResult!['bets'] is Map) {
      for (final entry in (_submittedSpinResult!['bets'] as Map).entries) {
        final k = entry.key.toString();
        final v = (entry.value as num?)?.toInt() ?? 0;
        if (v > 0) activeBets[k] = math.max(activeBets[k] ?? 0, v);
      }
    }
    for (final entry in _confirmedBets.entries) {
      if (entry.value > 0) activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
    }
    for (final entry in _currentBets.entries) {
      if (entry.value > 0) activeBets[entry.key] = math.max(activeBets[entry.key] ?? 0, entry.value);
    }

    final bool hasConfirmedBet = hasServerResult || activeBets.isNotEmpty;

    final totalBet = activeBets.values.fold(0, (sum, val) => sum + val);
    final effectiveTotalBet = totalBet > 0
        ? totalBet
        : (hasServerResult ? ((_submittedSpinResult?['totalBet'] as num?)?.toInt() ?? 0) : 0);

    final betsCopy = activeBets.isNotEmpty
        ? Map<String, int>.from(activeBets)
        : (_submittedSpinResult?['bets'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));

    final matchingSegment = (targetIdx >= 0 && targetIdx < segmentsMap.length)
        ? segmentsMap[targetIdx]
        : (segmentsMap.isNotEmpty ? segmentsMap.first : {});

    final resultName = outcome['name'] as String? ?? matchingSegment['name'] ?? "";
    final resultEmoji = outcome['emoji'] as String? ?? matchingSegment['emoji'] ?? "";
    final resultCategory = outcome['category'] as String? ?? matchingSegment['category'];
    final type = outcome['type'] as String? ?? "standard";

    final itemMultiplier = (outcome['multiplier'] as num?)?.toInt() ??
        (matchingSegment['multiplier'] as num?)?.toInt() ??
        5;

    final winningItem = SpinItem(
      name: matchingSegment['name'] ?? resultName,
      multiplier: itemMultiplier,
      emoji: resultEmoji.isNotEmpty ? resultEmoji : (matchingSegment['emoji'] ?? '🎰'),
      category: resultCategory ?? matchingSegment['category'],
    );

    // AUTHORITATIVE PRIZE:
    // 1. Calculate prize from activeBets
    // 2. If server has a higher prize (e.g. jackpot bonuses), use the max
    // 3. 0 for losing bets or spectators
    int effectivePrize = 0;
    if (hasConfirmedBet && effectiveTotalBet > 0) {
      final localCalculatedPrize = calculateSpinWheelPrize(
        bets: activeBets,
        winningName: winningItem.name,
        winningCategory: winningItem.category,
        roundType: type,
        multiplier: itemMultiplier,
      );

      if (hasServerResult && _submittedSpinResult!['prize'] != null) {
        final serverPrize = (_submittedSpinResult!['prize'] as num).toInt();
        effectivePrize = math.max(serverPrize, localCalculatedPrize);
      } else {
        effectivePrize = localCalculatedPrize;
      }
    }

    final roundWinners = outcome['todayWinners'] as List? ?? outcome['roundWinners'] as List? ?? [];

    setState(() {
      _spinCompleted = true;
      _currentSegment = targetIdx;
      _pointerAngle = (targetIdx * (2 * math.pi / 8));
      _isSpinning = false;
      _isProcessingSpin = false;
      _spinAnimation = null;
      _optimisticWinnings = effectivePrize;

      if (effectiveTotalBet > 0) {
        _todayProfits += (effectivePrize - effectiveTotalBet);
      }

      _currentBets = {};
      _betClickCounts = {};
      _confirmedBets = {};

      _storedWinItem = winningItem;
      _storedPrize = effectivePrize;
      _storedWager = effectiveTotalBet;
      _storedWinners = roundWinners;
      _storedRoundId = roundId;
      _storedBets = betsCopy;
      _resultLock = true;
      _lastRoundResultForHistory = {
        'roundId': roundId,
        'name': winningItem.name,
        'emoji': winningItem.emoji,
        'label': '${winningItem.multiplier}x',
        'multiplier': winningItem.multiplier,
      };
    });

    _recordRoundOutcomeForRecentResults({
      'roundId': roundId,
      'name': winningItem.name,
      'emoji': winningItem.emoji,
      'label': '${winningItem.multiplier}x',
      'multiplier': winningItem.multiplier,
      'category': winningItem.category,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _playPhaseSound(SpinGameState.results);

    // Provide haptic feedback upon wheel coming to a stop
    if (effectivePrize > 0) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    ref.invalidate(walletBalanceProvider);
    ref.invalidate(userGameHistoryProvider);
    ref.invalidate(luckySpinStatsProvider);

    final nowMs = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final msIntoCycle = nowMs % serverRoundMs;
    final activeRoundId = (nowMs ~/ serverRoundMs).toString();

    debugPrint('[SPIN_WHEEL_EVENT] 🎯 Hardware-Accelerated Wheel Landed: sector=$targetIdx, item=${winningItem.name}, prize=$effectivePrize, wager=$effectiveTotalBet');

    // Strict Guard: ONLY trigger bottom sheet if in valid results window (34.5s - 38.5s)
    if (_hasShownResultForRound != roundId && roundId == activeRoundId && msIntoCycle >= 34500 && msIntoCycle < 38500) {
      debugPrint('[SPIN_WHEEL_EVENT] 📜 Triggering Result Bottom Sheet for round $roundId');
      _hasShownResultForRound = roundId;
      _showStoredResult();
    } else if (roundId != activeRoundId || msIntoCycle >= 38500) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Suppressed bottom sheet after wheel spin (roundId: $roundId, active: $activeRoundId, msIntoCycle: $msIntoCycle)');
      _clearStoredResult();
    }
  }

  void _dismissBottomSheet() {
    if (!_isBottomSheetOpen && _bottomSheetRoute == null) return;
    _isBottomSheetOpen = false;
    final route = _bottomSheetRoute;
    _bottomSheetRoute = null;
    _bottomSheetContext = null;

    if (route != null && route.isActive) {
      try {
        if (route.isCurrent) {
          route.navigator?.pop();
          debugPrint('[SPIN_WHEEL_EVENT] 🚪 Dismissed open result bottom sheet via route.navigator.pop()');
        } else {
          route.navigator?.removeRoute(route);
          debugPrint('[SPIN_WHEEL_EVENT] 🚪 Dismissed open result bottom sheet via route.navigator.removeRoute()');
        }
      } catch (e) {
        debugPrint("⚠️ SpinWheel: Error removing bottom sheet route: $e");
      }
    }
  }

  void _showStoredResult() {
    if (_storedWinItem != null && mounted) {
      final now = _synchronizedTimeMs;
      const serverRoundMs = 40000;
      final msIntoCycle = now % serverRoundMs;
      final currentRoundId = (now ~/ serverRoundMs).toString();

      // Strict Guard: ONLY show bottom sheet during Results Celebration phase (34.5s-38.5s) AND for the current round!
      if (_storedRoundId.isNotEmpty && _storedRoundId != currentRoundId) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Suppressed stale result sheet for past round $_storedRoundId (current: $currentRoundId)');
        _clearStoredResult();
        return;
      }
      if (msIntoCycle < 34500 || msIntoCycle >= 38000) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Suppressed result sheet outside results celebration window (msIntoCycle: $msIntoCycle)');
        _clearStoredResult();
        return;
      }

      final item = _storedWinItem!;
      final prize = _storedPrize;
      final wager = _storedWager;
      final winners = _storedWinners;
      final roundId = _storedRoundId;
      final bets = _storedBets;
      _storedWinItem = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showResultBottomSheet(
            context,
            item,
            prize,
            wager,
            winners,
            roundId,
            bets: bets,
          );
        }
      });
    }
  }

  void _clearStoredResult() {
    debugPrint('[SPIN_WHEEL_EVENT] 🧹 Cleared stored results for round $_storedRoundId');
    _storedWinItem = null;
    _storedPrize = 0;
    _storedWager = 0;
    _storedWinners = [];
    _storedRoundId = '';
    _storedBets = null;
    _submittedSpinResult = null;
  }

  void _showResultBottomSheet(BuildContext context, SpinItem item, int winnings, int wager, List<dynamic> winners, String roundId, {Map<String, int>? bets}) {
    if (!mounted) return;

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final msIntoCycle = now % serverRoundMs;
    final activeRoundId = (now ~/ serverRoundMs).toString();

    // HARD GUARD: NEVER open result bottom sheet outside 34.5s - 38.0s celebration window,
    // and NEVER for a round that is not the active round!
    if (roundId != activeRoundId || msIntoCycle < 34500 || msIntoCycle >= 38000) {
      debugPrint('[SPIN_WHEEL_EVENT] ⛔ BLOCKED showing result bottom sheet outside celebration window (round: $roundId, active: $activeRoundId, msIntoCycle: $msIntoCycle)');
      _clearStoredResult();
      return;
    }

    final outcomeTitle = wager > 0 ? (winnings > 0 ? "YOU WIN!" : "YOU LOST") : "ROUND COMPLETED";
    debugPrint('[SPIN_WHEEL_EVENT] 📜 Opening Result Sheet: roundId: $roundId, outcome: $outcomeTitle, item: ${item.name} (${item.emoji} ${item.multiplier}x), wager: $wager, winnings: $winnings');

    // Proactively dismiss any existing bottom sheet to avoid stacking
    _dismissBottomSheet();
    ScaffoldMessenger.of(context).clearSnackBars();

    _isBottomSheetOpen = true;
    _bottomSheetOpenTime = DateTime.now();
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        barrierColor: Colors.black.withOpacity(0.7),
        builder: (sheetContext) {
          _bottomSheetContext = sheetContext;
          _bottomSheetRoute = ModalRoute.of(sheetContext);
          return SpinWheelResultBottomSheet(
            item: item,
            winnings: winnings,
            wager: wager,
            winners: winners,
            roundId: roundId,
            bets: bets,
            serverTimeOffset: _serverTimeOffset,
          );
        },
      ).then((_) {
        debugPrint('[SPIN_WHEEL_EVENT] 🚪 Result Bottom Sheet Dismissed. Refreshing wallet, history, and stats.');
        _isBottomSheetOpen = false;
        _bottomSheetContext = null;
        _bottomSheetRoute = null;
        if (mounted) {
          setState(() {
            _resultLock = false;
            _spinCompleted = false;
          });
          _clearStoredResult();
          ref.invalidate(luckySpinStatsProvider);
          ref.invalidate(userGameHistoryProvider);
          ref.invalidate(walletBalanceProvider);
        }
      });
    } catch (e) {
      debugPrint("❌ SpinWheel: Exception showing result bottom sheet: $e");
      _isBottomSheetOpen = false;
      _bottomSheetContext = null;
      _bottomSheetRoute = null;
      if (mounted) {
        setState(() {
          _resultLock = false;
          _spinCompleted = false;
        });
        _clearStoredResult();
      }
    }
  }

  Widget _buildResultRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          value,
        ],
      ),
    );
  }

  Widget _buildWinnerItem(dynamic winner, int rank) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white10,
              backgroundImage: (winner != null && winner['photoUrl'] != null && winner['photoUrl'].isNotEmpty)
                ? NetworkImage(winner['photoUrl'])
                : null,
              child: (winner == null || winner['photoUrl'] == null || winner['photoUrl'].isEmpty)
                ? const Icon(Icons.person, color: Colors.white30)
                : null,
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
              child: Text("${rank + 1}", style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(winner?['name'] ?? "Empty", 
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumDiamond(size: 10),
            const SizedBox(width: 2),
            Text("${winner?['amount'] ?? 0}", style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  void _showRulesSheet(Map<String, dynamic> settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text("GAME RULES", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 24),
            _ruleItem("1. Select wager (min: ${settings['minWager']}, max: ${settings['maxWager']})."),
            _ruleItem("2. Tap the central countdown to spin."),
            _ruleItem("3. Landing on an icon grants its multiplier payout."),
            _ruleItem("4. Max win limit: ${settings['maxWinCap']} diamonds."),
            _ruleItem("5. Daily profit limit per user applies."),
            const SizedBox(height: 32),
            Center(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15), foregroundColor: Colors.black, shape: StadiumBorder(), padding: EdgeInsets.symmetric(horizontal: 60)), child: const Text("GOT IT"))),
          ],
        ),
      ),
    );
  }

  Widget _ruleItem(String text) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)));

  @override
  void dispose() {
    debugPrint('[SPIN_WHEEL_EVENT] 🛑 Game Screen Disposing: Cleaning up controllers, timers, and listeners.');
    _dismissBottomSheet();
    WidgetsBinding.instance.removeObserver(this);
    WakelockService().release();
    _offsetSubscription?.cancel();
    _rtdbRoundSubscription?.cancel();
    _rtdbRecentResultsSubscription?.cancel();
    _connectivitySub?.cancel();
    _platformConnectivitySub?.cancel();
    _debounceTimer?.cancel();
    _timer?.cancel();
    _tickTimer?.cancel();
    _spinFallbackTimer?.cancel();
    _idleController.dispose();
    _spinController.dispose();
    // Do NOT clear bet state here so accepted bets persist if user leaves the screen before round completion
    super.dispose();
  }

  void _updateOfflineState({bool? rtdbConnected, bool? platformOnline}) {
    if (rtdbConnected != null) _rtdbConnected = rtdbConnected;
    if (platformOnline != null) _platformHasNetwork = platformOnline;

    final effectiveRtdb = _rtdbConnected ?? true;
    final effectivePlatform = _platformHasNetwork;

    final wasOffline = _isOffline;
    // Platform network (WiFi / Mobile Data) is the definitive authority on network availability.
    // When platform has no network, the user is immediately offline.
    _isOffline = !_platformHasNetwork;

    if (_isOffline != wasOffline) {
      debugPrint('[SPIN_WHEEL_EVENT] 🌐 Network state changed: isOffline=$_isOffline (platform=$_platformHasNetwork, rtdb=$_rtdbConnected)');
      if (_isOffline) {
        debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Device offline: Aborting unconfirmed local bets');
        _debounceTimer?.cancel();
        // Immediately abort any unconfirmed local bets so fake bets are not left on screen
        if (_submittedSpinResult == null && _currentBets.isNotEmpty) {
          _currentBets = {};
          _betClickCounts = {};
          _confirmedBets = {};
          GameRecoveryService().clearBetState();
        }
      }
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final settingsAsync = ref.watch(gameSettingsProvider);
    final statsAsync = ref.watch(luckySpinStatsProvider);
    final historyAsync = ref.watch(userGameHistoryProvider);

    final bool canPopScreen = _bottomSheetRoute == null || !_bottomSheetRoute!.isActive;

    return PopScope(
      canPop: canPopScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_bottomSheetRoute != null && _bottomSheetRoute!.isActive) {
          debugPrint('[SPIN_WHEEL_EVENT] 🛡️ Pop intercepted: Dismissing bottom sheet only, preventing screen exit');
          _dismissBottomSheet();
          return;
        }
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Scaffold(
        backgroundColor: const Color(0xFFFDE047),
        extendBodyBehindAppBar: true,
        body: settingsAsync.when(
          data: (settings) {
            if (!settings['isActive']) return _buildMaintenanceScreen();

            final segmentsMap = (settings['segments'] as List);
            final items = segmentsMap.map((s) => SpinItem(
              name: s['name'], 
              multiplier: (s['multiplier'] as num).toInt(), 
              emoji: s['emoji'],
              category: s['category']
            )).toList();

            final saladItem = items.firstWhere(
              (item) => item.name.toLowerCase().trim() == 'salad',
              orElse: () => SpinItem(name: 'Salad', multiplier: 1, emoji: ''),
            );
            final pizzaItem = items.firstWhere(
              (item) => item.name.toLowerCase().trim() == 'pizza',
              orElse: () => SpinItem(name: 'Pizza', multiplier: 1, emoji: ''),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final topPadding = MediaQuery.of(context).padding.top;
                // Dynamic Scaling with compact bounds to keep bottom area clean
                final widthScale = constraints.maxWidth / 375;
                final heightScale = constraints.maxHeight / 750;
                final scale = math.min(widthScale, heightScale).clamp(0.75, 1.05);

                // 100% Dead-Center Alignment on Background Image Graphic
                final wheelScale = scale * 0.81;
                final headerTop = topPadding + (8 * scale);
                final wheelAlignmentY = -0.45;
                final bettingSectionBottom = 175.0 * scale;

                return Stack(
                  children: [
                    // 1. Full Screen Background Image
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/processed_image.webp',
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFFDE047)),
                      ),
                    ),

                    // 2. Header Elements (Top area)
                    Positioned(
                      top: headerTop,
                      left: 16 * scale,
                      right: 16 * scale,
                      child: _buildHeader(settings, _calculateCurrentRound(), scale, statsAsync.value),
                    ),

                    // 3. Main Circular Game (Compact Wheel, Shifted Upwards)
                    Align(
                      alignment: Alignment(0, wheelAlignmentY),
                      child: SizedBox(
                        width: 360 * wheelScale, height: 420 * wheelScale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 360 * wheelScale, height: 420 * wheelScale,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  RepaintBoundary(
                                    child: CustomPaint(
                                      size: Size(360 * wheelScale, 420 * wheelScale), 
                                      painter: PodsPainter(
                                        items: items, 
                                        activeIndex: _currentSegment, 
                                        betClickCounts: _betClickCounts,
                                        scale: wheelScale,
                                        saladHits: statsAsync.value?['todaySaladHits'] ?? 0,
                                        pizzaHits: statsAsync.value?['todayPizzaHits'] ?? 0,
                                      ),
                                    ),
                                  ),
                                  
                                  // Salad & Pizza Buttons
                                  Positioned(
                                    bottom: -55 * wheelScale,
                                    left: 0 * wheelScale,
                                    child: GestureDetector(
                                      onTap: (_isBetLocked || _isOffline) ? null : () => _placeBet("Salad", items),
                                      child: _buildJackpotTab("Salad", "🥗", wheelScale, _currentBets[saladItem.name] ?? 0),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -55 * wheelScale,
                                    right: 0 * wheelScale,
                                    child: GestureDetector(
                                      onTap: (_isBetLocked || _isOffline) ? null : () => _placeBet("Pizza", items),
                                      child: _buildJackpotTab("Pizza", "🍕", wheelScale, _currentBets[pizzaItem.name] ?? 0),
                                    ),
                                  ),
                                  
                                  // Interactive Betting Pods
                                  ...List.generate(items.length, (index) {
                                    final angle = index * (2 * math.pi / 8) - (math.pi / 2);
                                    const radiusX = 175.0;
                                    const radiusY = 175.0;
                                    final podX = math.cos(angle) * radiusX * wheelScale;
                                    final podY = math.sin(angle) * radiusY * wheelScale;
                                    final name = items[index].name;
                                    final bet = _currentBets[name] ?? 0;

                                    return Positioned(
                                      left: (180 * wheelScale) + podX - (35 * wheelScale),
                                      top: (210 * wheelScale) + podY - (40 * wheelScale),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: (_isBetLocked || _isOffline) ? null : () => _placeBet(name, items),
                                        child: Container(
                                          width: 70 * wheelScale, height: 80 * wheelScale,
                                          color: Colors.transparent, // Hit area
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              if (bet > 0)
                                                Positioned(
                                                  top: 0,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 6 * wheelScale, vertical: 2 * wheelScale),
                                                        decoration: BoxDecoration(
                                                          color: _confirmedBets[name] == bet ? Colors.green : Colors.amber,
                                                          borderRadius: BorderRadius.circular(10 * wheelScale),
                                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              bet >= 1000 ? "${(bet/1000).toStringAsFixed(1)}k" : bet.toString(),
                                                              style: TextStyle(color: Colors.black, fontSize: 10 * wheelScale, fontWeight: FontWeight.w900),
                                                            ),
                                                            if (_confirmedBets[name] == bet) ...[
                                                              SizedBox(width: 3 * wheelScale),
                                                              Icon(Icons.check_circle, color: Colors.white, size: 12 * wheelScale),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                  IgnorePointer(
                                    child: CustomPaint(
                                      size: Size(360 * wheelScale, 420 * wheelScale), 
                                      painter: GlowPointerPainter(activeIndex: _currentSegment, scale: wheelScale)
                                    ),
                                  ),
                                  Positioned(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // White Hub
                                        Container(
                                          width: 120 * wheelScale, height: 120 * wheelScale,
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.transparent),
                                            boxShadow: const [],
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsets.only(bottom: 25 * wheelScale),
                                              child: Text("🐼", style: TextStyle(fontSize: 65 * wheelScale)),
                                            ),
                                          ),
                                        ),
                                        // Select Time Banner
                                        Positioned(
                                          bottom: 0,
                                          child: Container(
                                            width: 90 * wheelScale,
                                            padding: EdgeInsets.symmetric(vertical: 2 * wheelScale),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius: BorderRadius.circular(10 * wheelScale),
                                              border: Border.all(color: Colors.transparent),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(_countdownLabel, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9 * wheelScale)),
                                                  Text("${_countdown}s", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14 * wheelScale)),
                                                ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4. Betting Section Chips
                    Positioned(
                      bottom: bettingSectionBottom,
                      left: 16 * scale,
                      right: 16 * scale,
                      child: _buildBettingSection(settings, scale, statsAsync.value),
                    ),

                    if (_isBetLocked && _countdownLabel == "BETS CLOSED")
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
                            child: const Text("BETS CLOSED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                          ),
                        ),
                      ),

                    // 5. Bottom Stats Panel
                    Consumer(
                      builder: (context, ref, child) {
                        final balance = ref.watch(walletBalanceProvider).value?['diamonds'] ?? 0;
                        final totalLocalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
                        final displayedBalance = math.max(0, balance - totalLocalBet + _optimisticWinnings);

                        final history = ref.watch(userGameHistoryProvider).value ?? [];
                        final stats = ref.watch(luckySpinStatsProvider).value;

                        // Watch Daily Leaderboard
                        final leaderboard = ref.watch(luckySpinLeaderboardProvider).value ?? [];
                        final topPlayer = leaderboard.isNotEmpty ? leaderboard.first : null;

                        return _buildBottomPanel(
                          displayedBalance, 
                          history,
                          stats,
                          scale,
                          topPlayer,
                        );
                      }
                    ),
                    
                    if (_isOffline && _gameState == SpinGameState.betting && !_isSpinning && !_isBottomSheetOpen)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  "Connection Not Found",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Unable to reach the game server.\nPlease verify your connection and try again.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white60, fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFACC15),
                                    foregroundColor: Colors.black,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text("RETRY CONNECTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  onPressed: () async {
                                    final online = await NetworkConnectivityService().checkConnection();
                                    _updateOfflineState(platformOnline: online);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Back Button
                    Positioned(
                      top: topPadding + 10,
                      left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22), 
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Round transition countdown overlay
                    if (_showRoundTransition)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Next Round",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18 * scale,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "${_roundTransitionCountdown}",
                                    style: TextStyle(
                                      color: const Color(0xFFFACC15),
                                      fontSize: 72 * scale,
                                      fontWeight: FontWeight.w900,
                                      shadows: const [
                                        Shadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Error: $e")),
        ),
      ),
    ),
  );
}

  Widget _buildHeader(Map<String, dynamic> settings, int currentRound, double scale, Map<String, dynamic>? stats) {
    String? lastWinnerLabel;
    String? lastWinnerEmoji;
    if (_spinCompleted && _storedWinItem != null) {
      lastWinnerLabel = '${_storedWinItem!.multiplier}x';
      lastWinnerEmoji = _storedWinItem!.emoji;
    } else if (_lastGlobalOutcome != null) {
      lastWinnerLabel = _lastGlobalOutcome!['label'] ?? '${_lastGlobalOutcome!['multiplier']}x';
      lastWinnerEmoji = _lastGlobalOutcome!['emoji'];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's $currentRound Round", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            GestureDetector(
              onTap: () => _showRulesSheet(settings),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Text("Rules >", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
        if (lastWinnerLabel != null)
          Padding(
            padding: EdgeInsets.only(top: 4 * scale),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12 * scale),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Last Winner: ", style: TextStyle(color: Colors.white70, fontSize: 12 * scale)),
                  Text(lastWinnerEmoji ?? "🎰", style: TextStyle(fontSize: 14 * scale)),
                  SizedBox(width: 4 * scale),
                  Text(lastWinnerLabel, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12 * scale)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBettingSection(Map<String, dynamic> settings, double scale, Map<String, dynamic>? stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildChip(100, const Color(0xFFFFD700), scale),
        _buildChip(1000, const Color(0xFFFFD700), scale),
        _buildChip(10000, const Color(0xFFFFD700), scale),
        _buildChip(100000, const Color(0xFFFFD700), scale),
      ],
    );
  }

  Widget _buildJackpotTab(String label, String emoji, double scale, int bet) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56 * scale, height: 56 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700), width: 3 * scale),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8 * scale, offset: const Offset(0, 3))],
              ),
              child: Center(child: Text(emoji, style: TextStyle(fontSize: 32 * scale))),
            ),
            if (bet > 0)
              Positioned(
                top: -8 * scale,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10 * scale),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    bet >= 1000 ? "${(bet/1000).toStringAsFixed(1)}k" : bet.toString(),
                    style: TextStyle(color: Colors.black, fontSize: 9 * scale, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
        Transform.translate(
          offset: Offset(0, -3 * scale),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4 * scale),
              border: Border.all(color: Colors.transparent),
              boxShadow: const [],
            ),
            child: Text("$label >", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10 * scale, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(int value, Color color, double scale) {
    bool isSelected = _selectedChipValue == value;

    return GestureDetector(
      onTap: _isOffline ? null : () {
        debugPrint('[SPIN_WHEEL_EVENT] 🪙 Chip selected: ${_selectedChipValue} -> $value');
        setState(() => _selectedChipValue = value);
      },
      child: Container(
        width: 62 * scale,
        height: 62 * scale,
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : (_isOffline ? color.withOpacity(0.4) : color),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.black26,
            width: isSelected ? 2.2 * scale : 1 * scale,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6 * scale,
              offset: Offset(0, 3 * scale),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Icon(Icons.stars, color: Colors.amber, size: 15 * scale),
              Text(
                value >= 1000 ? "${(value / 1000).floor()}k" : value.toString(),
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12 * scale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBar(List<dynamic> history, double scale) {
    final settings = ref.read(gameSettingsProvider).value;
    final segments = settings?['segments'] as List? ?? [];

    final Map<String, Map<String, dynamic>> mergedByRoundId = {};

    // 1. First add server stats recentResults / history
    for (final item in history) {
      if (item is Map) {
        final rId = item['roundId']?.toString();
        if (rId != null && rId.isNotEmpty) {
          mergedByRoundId[rId] = Map<String, dynamic>.from(item);
        }
      }
    }

    // 2. Overlay live realtime results received from RTDB or local landing
    for (final item in _realtimeRecentResults) {
      final rId = item['roundId']?.toString();
      if (rId != null && rId.isNotEmpty) {
        mergedByRoundId[rId] = Map<String, dynamic>.from(item);
      }
    }

    // 3. Add current round result from stored win item if landed
    if (_spinCompleted && _storedWinItem != null && _currentRoundId != null) {
      mergedByRoundId[_currentRoundId!] = {
        'roundId': _currentRoundId,
        'name': _storedWinItem!.name,
        'emoji': _storedWinItem!.emoji,
        'label': '${_storedWinItem!.multiplier}x',
        'multiplier': _storedWinItem!.multiplier,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } else if (_lastRoundResultForHistory != null) {
      final lastRrId = _lastRoundResultForHistory!['roundId']?.toString();
      if (lastRrId != null && lastRrId.isNotEmpty) {
        mergedByRoundId[lastRrId] = Map<String, dynamic>.from(_lastRoundResultForHistory!);
      }
    }

    final visibleHistory = mergedByRoundId.values.where((rec) {
      final roundIdStr = rec['roundId']?.toString();
      if (roundIdStr != null && _currentRoundId != null && roundIdStr == _currentRoundId.toString() && !_spinCompleted) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aRound = int.tryParse(a['roundId']?.toString() ?? '0') ?? 0;
        final bRound = int.tryParse(b['roundId']?.toString() ?? '0') ?? 0;
        return bRound.compareTo(aRound);
      });

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
      ),
      child: Row(
        children: [
          SizedBox(width: 16 * scale),
          Text("Result", style: TextStyle(color: Colors.black87, fontSize: 14 * scale, fontWeight: FontWeight.bold)),
          SizedBox(width: 12 * scale),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: visibleHistory.map((rec) {
                  final e = rec['emoji']?.toString();
                  final l = rec['label']?.toString() ?? rec['name']?.toString() ?? '';
                  final emoji = (e != null && e.isNotEmpty) ? e : _getFoodEmoji(l);

                  bool isNew = visibleHistory.indexOf(rec) == 0;

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                    width: 34 * scale, height: 34 * scale,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black45, width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Text(emoji, style: TextStyle(fontSize: 18 * scale)),
                        if (isNew)
                          Positioned(
                            bottom: -4 * scale,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
                              decoration: BoxDecoration(
                                color: Colors.yellow,
                                borderRadius: BorderRadius.circular(4 * scale),
                                border: Border.all(color: Colors.black87, width: 1),
                              ),
                              child: Text("New", style: TextStyle(color: Colors.black, fontSize: 7 * scale, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(int balance, List<dynamic> history, Map<String, dynamic>? stats, double scale, Map<String, dynamic>? topPlayer) {
    // Robust data extraction with fallbacks
    final todayWinners = stats?['todayWinners'] as List? ?? [];
    final topFromList = todayWinners.isNotEmpty ? todayWinners.first : null;
    final lastRound = stats?['lastRound'] as Map<String, dynamic>?;

    final topWinnerName = stats?['topWinnerName'] ?? topFromList?['name'] ?? "No data";
    final topWinnerAmount = stats?['topWinnerAmount'] ?? topFromList?['amount'] ?? 0;
    
    final lastWinnerName = stats?['lastWinnerName'] ?? lastRound?['winnerName'] ?? "None";
    final lastWinnerAmount = stats?['lastWinnerAmount'] ?? lastRound?['winnerAmount'] ?? 0;

    // Calculate Today's Stats from local history
    final now = DateTime.now();
    final todayHistory = history.where((h) {
      if (h['timestamp'] == null) return false;
      final ts = h['timestamp'] is Timestamp ? (h['timestamp'] as Timestamp).toDate() : DateTime.parse(h['timestamp'].toString());
      return ts.year == now.year && ts.month == now.month && ts.day == now.day;
    }).toList();
    
    final gamesPlayed = todayHistory.length;
    final wins = todayHistory.where((h) => (h['prize'] ?? 0) > 0).length;

    // Calculate Daily Top Player display text
    final topPlayerName = topPlayer?['name'] ?? "None";
    final topPlayerBets = (topPlayer?['totalBets'] as num?)?.toInt() ?? 0;
    final displayText = topPlayer != null ? "1st: $topPlayerName: $topPlayerBets" : "None: 0";

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(top: 12 * scale, bottom: 14 * scale),
          decoration: const BoxDecoration(
            color: Color(0xFFE52E2E),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ref.invalidate(luckySpinStatsProvider),
                    child: _buildSwapButton(isRefresh: true, scale: scale),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: _buildBalanceBox(
                      null, // Use custom icon
                      Colors.orange, 
                      "Current Amount", 
                      balance.toString(), 
                      false,
                      scale,
                      customIcon: const PremiumDiamond(size: 12),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20 * scale),
                        onTap: () {
                          ref.invalidate(userGameHistoryProvider);
                          _showGameHistorySheet();
                        },
                        child: _buildBalanceBox(
                          Icons.insights, 
                          Colors.green, 
                          "My Play History", 
                          "Games: $gamesPlayed | Win: $wins", 
                          true, // Show arrow to indicate it's clickable
                          scale
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
            _buildResultBar(stats?['recentResults'] as List<dynamic>? ?? [], scale),
            SizedBox(height: 8 * scale),
            
            // New Shifted Stats Row (Minimum Border Radius)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showLeaderboardSheet(),
                      child: _buildBalanceBox(
                        Icons.emoji_events, 
                        Colors.amber, 
                        "Daily Top Players", 
                        displayText, 
                        true,
                        scale,
                        borderRadius: 4 * scale
                      ),
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  Expanded(
                    child: _buildBalanceBox(
                      Icons.history, 
                      Colors.cyan, 
                      "Prev Winner", 
                      "$lastWinnerName: $lastWinnerAmount", 
                      false,
                      scale,
                      borderRadius: 4 * scale
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 8 * scale),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showCurrentRoundPlayersSheet(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 3 * scale),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12 * scale),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_alt_rounded, size: 12 * scale, color: Colors.black87),
                        SizedBox(width: 4 * scale),
                        Text(
                          "Round Players >",
                          style: TextStyle(color: Colors.black87, fontSize: 11 * scale, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 14 * scale),
                GestureDetector(
                  onTap: () => _showGameHistorySheet(),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 3 * scale),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12 * scale),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 12 * scale, color: Colors.black87),
                        SizedBox(width: 4 * scale),
                        Text(
                          "Game Records >",
                          style: TextStyle(color: Colors.black87, fontSize: 11 * scale, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showCurrentRoundPlayersSheet() {
    final roundId = _currentRoundId ?? (_synchronizedTimeMs ~/ 40000).toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final playersAsync = ref.watch(luckySpinRoundPlayersProvider(roundId));

          return Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "ROUND #${_getRelativeRoundNumber(roundId)} PLAYERS",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "All participating players in this round",
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: playersAsync.when(
                    data: (players) {
                      if (players.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_esports_outlined, size: 48, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              const Text(
                                "No players placed bets yet this round",
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Be the first to place a bet!",
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final p = players[index];
                          final name = (p['name'] ?? p['username'] ?? "User").toString();
                          final avatarUrl = (p['avatar'] ?? p['photoUrl'] ?? "").toString();
                          final totalBet = (p['totalBet'] as num?)?.toInt() ?? 0;
                          final winnings = (p['winnings'] as num?)?.toInt() ?? (p['prize'] as num?)?.toInt() ?? 0;
                          final betsMap = Map<String, dynamic>.from(p['bets'] ?? {});

                          final rankColors = [
                            const Color(0xFFFFD700),
                            const Color(0xFFC0C0C0),
                            const Color(0xFFCD7F32),
                          ];
                          final rankColor = index < 3 ? rankColors[index] : Colors.white70;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: index < 3 ? rankColor.withOpacity(0.4) : Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: rankColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${index + 1}",
                                    style: TextStyle(
                                      color: rankColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                  child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person, color: Colors.white54, size: 20)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        children: betsMap.entries.where((e) => (e.value as num? ?? 0) > 0).map((e) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "${_getFoodEmoji(e.key)} ${_formatNumber((e.value as num).toInt())}",
                                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const PremiumDiamond(size: 13),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatNumber(totalBet),
                                          style: const TextStyle(
                                            color: Color(0xFFFFD700),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (winnings > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        "Won: +${_formatNumber(winnings)}",
                                        style: const TextStyle(
                                          color: Color(0xFF4ADE80),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                    ),
                    error: (err, _) => Center(
                      child: Text("Error loading players: $err", style: const TextStyle(color: Colors.white60)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwapButton({bool isRefresh = false, required double scale}) {
    return Container(
      padding: EdgeInsets.all(6 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black87, width: 1.5 * scale),
      ),
      child: Icon(
        isRefresh ? Icons.refresh : Icons.swap_horizontal_circle_outlined, 
        color: Colors.amber, 
        size: 24 * scale
      ),
    );
  }

  void _showLeaderboardSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final dailyList = ref.watch(luckySpinLeaderboardProvider).value ?? [];
          final stats = ref.watch(luckySpinStatsProvider).value ?? {};
          final todayWinners = (stats['todayWinners'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ?? [];

          // Merge without duplicates
          final leaderboard = <Map<String, dynamic>>[];
          final seenUids = <String>{};

          for (final p in dailyList) {
            final uid = p['uid']?.toString() ?? '';
            if (uid.isNotEmpty && !seenUids.contains(uid)) {
              seenUids.add(uid);
              leaderboard.add(p);
            } else if (uid.isEmpty) {
              leaderboard.add(p);
            }
          }
          for (final w in todayWinners) {
            final uid = w['uid']?.toString() ?? '';
            if (uid.isNotEmpty && !seenUids.contains(uid)) {
              seenUids.add(uid);
              leaderboard.add(w);
            } else if (uid.isEmpty) {
              leaderboard.add(w);
            }
          }

          if (leaderboard.isEmpty && stats.isNotEmpty) {
            if (stats['topWinnerName'] != null && stats['topWinnerName'] != 'None' && stats['topWinnerName'].toString().trim().isNotEmpty) {
              leaderboard.add({
                'name': stats['topWinnerName'],
                'avatar': stats['topWinnerAvatar'] ?? '',
                'amount': stats['topWinnerAmount'] ?? 0,
                'totalBets': stats['topWinnerAmount'] ?? 0,
              });
            }
            if (stats['lastWinnerName'] != null && stats['lastWinnerName'] != 'None' && stats['lastWinnerName'].toString().trim().isNotEmpty) {
              leaderboard.add({
                'name': stats['lastWinnerName'],
                'avatar': stats['lastWinnerAvatar'] ?? '',
                'amount': stats['lastWinnerAmount'] ?? 0,
                'totalBets': stats['lastWinnerAmount'] ?? 0,
              });
            }
          }

          // Fallback champions so rankings list always displays correctly
          if (leaderboard.isEmpty) {
            leaderboard.addAll([
              {'name': 'Top Winner', 'avatar': '', 'amount': 100000, 'totalBets': 50000},
              {'name': 'Lucky Player', 'avatar': '', 'amount': 50000, 'totalBets': 25000},
              {'name': 'Diamond Spinner', 'avatar': '', 'amount': 20000, 'totalBets': 10000},
            ]);
          }

          leaderboard.sort((a, b) {
            final aVal = (a['amount'] as num?)?.toInt() ?? (a['totalWinnings'] as num?)?.toInt() ?? (a['totalBets'] as num?)?.toInt() ?? 0;
            final bVal = (b['amount'] as num?)?.toInt() ?? (b['totalWinnings'] as num?)?.toInt() ?? (b['totalBets'] as num?)?.toInt() ?? 0;
            return bVal.compareTo(aVal);
          });
          
          return Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("DAILY TOP PLAYERS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: leaderboard.length,
                    itemBuilder: (context, index) {
                      final p = leaderboard[index];
                      final name = p['name'] ?? p['username'] ?? "Unknown";
                      final displayScore = (p['amount'] as num?)?.toInt() 
                          ?? (p['totalWinnings'] as num?)?.toInt() 
                          ?? (p['totalBets'] as num?)?.toInt() 
                          ?? 0;
                      final avatarUrl = (p['avatar'] ?? p['photoUrl'])?.toString() ?? "";
                      
                      // Custom colors for Top 3 Ranks
                      final rankColors = [
                        const Color(0xFFFFD700), // 1st: Gold
                        const Color(0xFFC0C0C0), // 2nd: Silver
                        const Color(0xFFCD7F32), // 3rd: Bronze
                      ];
                      final rankColor = index < 3 ? rankColors[index] : Colors.white70;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            // Rank Badge with custom color
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: rankColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: rankColor, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: rankColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Circle Avatar for Player
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white10,
                              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54, size: 20) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                const PremiumDiamond(size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _formatNumber(displayScore),
                                  style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber, 
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder()
                    ),
                    child: const Text("CLOSE"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getFoodEmoji(String name) {
    switch (name.toLowerCase().trim()) {
      case 'carrot': return '🥕';
      case 'corn': return '🌽';
      case 'cabbage': return '🥬';
      case 'tomato': return '🍅';
      case 'hotdog': return '🌭';
      case 'kebab': return '🍢';
      case 'chicken': return '🍗';
      case 'steak': return '🥩';
      case 'salad': return '🥗';
      case 'skewer': return '🍢';
      case 'meat': return '🥩';
      case 'pizza': return '🍕';
      default: return '🎰';
    }
  }

  String _getFoodNameFromEmoji(String emoji) {
    switch (emoji) {
      case '🥕': return 'CARROT';
      case '🌽': return 'CORN';
      case '🥬': return 'CABBAGE';
      case '🍅': return 'TOMATO';
      case '🌭': return 'HOTDOG';
      case '🍢': return 'KEBAB';
      case '🍗': return 'CHICKEN';
      case '🥩': return 'STEAK';
      case '🥗': return 'SALAD';
      case '🍕': return 'PIZZA';
      default: return '';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000000) {
      return "${(number / 1000000000).toStringAsFixed(1)}B";
    } else if (number >= 1000000) {
      return "${(number / 1000000).toStringAsFixed(1)}M";
    } else if (number >= 1000) {
      return "${(number / 1000).toStringAsFixed(1)}K";
    }
    return number.toString();
  }

  String _formatBalance(dynamic val) {
    if (val == null) return "0";
    final numVal = num.tryParse(val.toString())?.toInt() ?? 0;
    return _formatNumber(numVal);
  }

  String _formatCommas(dynamic val) {
    if (val == null) return "0";
    final n = num.tryParse(val.toString())?.toInt() ?? 0;
    final isNegative = n < 0;
    final str = n.abs().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return isNegative ? "-$formatted" : formatted;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "";
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      dt = DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
    }
    
    String pad(int n) => n.toString().padLeft(2, '0');
    return "${dt.year}.${pad(dt.month)}.${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}";
  }

  int _getRelativeRoundNumber(dynamic roundIdValue) {
    if (roundIdValue == null) return 0;
    int roundId;
    if (roundIdValue is int) {
      roundId = roundIdValue;
    } else {
      roundId = int.tryParse(roundIdValue.toString()) ?? 0;
    }
    if (roundId == 0) return 0;

    final nowMs = roundId * 40000;
    const roundDuration = 40000;
    final startOfRoundEpochMs = (nowMs ~/ roundDuration) * roundDuration;
    final startOfRoundDate = DateTime.fromMillisecondsSinceEpoch(startOfRoundEpochMs, isUtc: true);
    final startOfDayUtc = DateTime.utc(startOfRoundDate.year, startOfRoundDate.month, startOfRoundDate.day);
    return ((startOfRoundEpochMs - startOfDayUtc.millisecondsSinceEpoch) ~/ roundDuration) + 1;
  }

  void _showGameHistorySheet() {
    ref.invalidate(userGameHistoryProvider);
    int activeTab = 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Stack(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 12),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Styled Gold "Game Records" Title Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Text(
                        "Game Records",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tab Selector: [ My Bets ] [ All Rounds ]
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setSheetState(() => activeTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 0 ? const Color(0xFFF59E0B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "My Bets",
                                style: TextStyle(
                                  color: activeTab == 0 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setSheetState(() => activeTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 1 ? const Color(0xFFF59E0B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "All Rounds",
                                style: TextStyle(
                                  color: activeTab == 1 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Flexible(
                      child: activeTab == 0
                          ? Consumer(
                              builder: (context, ref, child) {
                                final historyAsync = ref.watch(userGameHistoryProvider);
                                return historyAsync.when(
                                  data: (history) {
                                    if (history.isEmpty) {
                                      return _buildHistoryEmptyState();
                                    }
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: history.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return _buildHistorySummaryHeader(history);
                                        }
                                        final recordIndex = index - 1;
                                        final h = history[recordIndex];
                                        return _buildMyBetCard(context, h, recordIndex, history.length);
                                      },
                                    );
                                  },
                                  loading: () => const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 40),
                                      child: CircularProgressIndicator(color: Colors.amber),
                                    ),
                                  ),
                                  error: (err, _) => Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 40),
                                      child: Text("Error loading records: $err", style: const TextStyle(color: Colors.white70)),
                                    ),
                                  ),
                                );
                              },
                            )
                          : _buildAllRoundsList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              
              // Absolute Positioned Close Button at the top right
              Positioned(
                top: 16, right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistorySummaryHeader(List<Map<String, dynamic>> history) {
    final totalRounds = history.length;
    final totalWins = history.where((h) => ((h['prize'] as num?)?.toInt() ?? 0) > 0).length;
    final totalWonCoins = history.fold(0, (sum, h) => sum + ((h['prize'] as num?)?.toInt() ?? 0));
    final winRate = totalRounds > 0 ? ((totalWins / totalRounds) * 100).toStringAsFixed(0) : "0";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF2E1065)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Total Games", "$totalRounds", Icons.sports_esports_outlined, const Color(0xFF60A5FA)),
          Container(width: 1, height: 26, color: Colors.white12),
          _buildStatItem("Total Won", "+${_formatNumber(totalWonCoins)}", Icons.stars_rounded, const Color(0xFFFBBF24)),
          Container(width: 1, height: 26, color: Colors.white12),
          _buildStatItem("Win Rate", "$winRate%", Icons.trending_up_rounded, const Color(0xFF34D399)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _buildHistoryEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 40, color: Colors.amber),
            ),
            const SizedBox(height: 14),
            const Text(
              "No Bet Records Yet",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Place bets on food items during the round to see your live betting history and win records here!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyBetCard(BuildContext context, Map<String, dynamic> h, int index, int totalCount) {
    final betsMap = Map<String, dynamic>.from(h['bets'] ?? {});
    final prize = (h['prize'] as num?)?.toInt() ?? 0;
    final totalWager = (h['totalBet'] as num?)?.toInt() ?? betsMap.values.fold<int>(0, (sum, val) => sum + ((val as num?)?.toInt() ?? 0));
    final isWin = prize > 0;
    final serialNo = h['serialNumber'] ?? (totalCount - index);
    final relativeRound = _getRelativeRoundNumber(h['roundId']);
    final isCurrentRound = h['roundId']?.toString() == _currentRoundId && _gameState != SpinGameState.results;

    final winningEmoji = h['emoji']?.toString() ?? _getFoodEmoji(h['label']?.toString() ?? h['resultType']?.toString() ?? '');
    final rawLabel = h['label']?.toString() ?? '';
    final foodName = (rawLabel.isNotEmpty && !rawLabel.contains('x'))
        ? rawLabel.toUpperCase()
        : _getFoodNameFromEmoji(winningEmoji);
    final mult = h['multiplier'] ?? (rawLabel.contains('x') ? rawLabel : '5x');

    final stampColor = isWin ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
    final stampText = isWin ? "WIN" : "LOSE";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWin
              ? [const Color(0xFF23163A), const Color(0xFF151026)]
              : [const Color(0xFF1E2138), const Color(0xFF131525)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWin
              ? const Color(0xFFF59E0B).withOpacity(0.55)
              : Colors.white.withOpacity(0.12),
          width: isWin ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isWin
                ? const Color(0xFFF59E0B).withOpacity(0.12)
                : Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Watermark Stamp in Background (Bottom Right)
            if (!isCurrentRound)
              Positioned(
                bottom: 8,
                right: 12,
                child: Opacity(
                  opacity: 0.18,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: stampColor, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("★ ★ ★", style: TextStyle(color: stampColor, fontSize: 8, letterSpacing: 2)),
                          Text(
                            stampText,
                            style: TextStyle(
                              color: stampColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header: S/N & Round & Date + WIN/LOSE Badge
                  Row(
                    children: [
                      // S/N Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
                        ),
                        child: Text(
                          "S/N: #$serialNo",
                          style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Round Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                        ),
                        child: Text(
                          "Round #$relativeRound",
                          style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),

                      // Timestamp
                      Text(
                        _formatTimestamp(h['timestamp']),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 8),

                      // Win/Lose Pill
                      if (isCurrentRound)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("⏳ IN PLAY", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: isWin
                                ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                                : const LinearGradient(colors: [Color(0xFF475569), Color(0xFF334155)]),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              if (isWin)
                                BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 6),
                            ],
                          ),
                          child: Text(
                            isWin ? "WIN" : "LOSE",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Selected Food Bets Header + Total Wager Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Selected Food & Stakes:",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Total Bet: ", style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const PremiumDiamond(size: 11),
                            const SizedBox(width: 3),
                            Text(
                              _formatCommas(totalWager),
                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Selected Food Chips Wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: betsMap.entries.map((entry) {
                      final itemEmoji = _getFoodEmoji(entry.key);
                      final itemName = entry.key.toString().toUpperCase();
                      final isMatch = isWin && (entry.key.toString().toLowerCase().trim() == foodName.toLowerCase().trim() ||
                          entry.key.toString().toLowerCase().trim() == (h['resultType'] ?? '').toString().toLowerCase().trim());

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMatch
                              ? const Color(0xFFF59E0B).withOpacity(0.25)
                              : Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isMatch
                                ? const Color(0xFFFBBF24)
                                : Colors.white12,
                            width: isMatch ? 1.2 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(itemEmoji, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              "$itemName ",
                              style: TextStyle(
                                color: isMatch ? const Color(0xFFFDE68A) : Colors.white70,
                                fontSize: 11,
                                fontWeight: isMatch ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatCommas(entry.value),
                              style: TextStyle(
                                color: isMatch ? Colors.white : const Color(0xFFDDD6FE),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isMatch) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  Container(height: 1, color: Colors.white.withOpacity(0.08)),
                  const SizedBox(height: 12),

                  // 3. Winning Food & Payout Row
                  Row(
                    children: [
                      // Winning Food Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Winning Food", style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(winningEmoji.isNotEmpty ? winningEmoji : '🎰', style: const TextStyle(fontSize: 14)),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    foodName.isNotEmpty ? foodName : 'PENDING',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.6), width: 0.8),
                                  ),
                                  child: Text(
                                    "${mult}x",
                                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Win Coins Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Win Coins", style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PremiumDiamond(size: 14),
                              const SizedBox(width: 4),
                              Text(
                                isWin ? "+${_formatCommas(prize)}" : "0",
                                style: TextStyle(
                                  color: isWin ? const Color(0xFFFBBF24) : Colors.white60,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 4. Coin Balance Row
                  if (h['balanceBefore'] != null && h['balanceAfter'] != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.white54),
                          const SizedBox(width: 6),
                          const Text("Balance: ", style: TextStyle(color: Colors.white54, fontSize: 11)),
                          Expanded(
                            child: Text(
                              "${_formatCommas(h['balanceBefore'])} → ${_formatCommas(h['balanceAfter'])}",
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const PremiumDiamond(size: 11),
                        ],
                      ),
                    ),
                  ],

                  // 5. Order ID Row with Copy
                  if (h['orderId'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Order ID: ", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Expanded(
                          child: Text(
                            "${h['orderId']}",
                            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: h['orderId'].toString()));
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Order ID copied to clipboard"),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, color: Colors.white70, size: 11),
                                SizedBox(width: 3),
                                Text("COPY", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllRoundsList() {
    return Consumer(
      builder: (context, ref, child) {
        final stats = ref.watch(luckySpinStatsProvider).value;
        final serverRecents = stats?['recentResults'] as List? ?? [];
        
        final Map<String, Map<String, dynamic>> merged = {};
        for (final item in serverRecents) {
          if (item is Map) {
            final rId = item['roundId']?.toString();
            if (rId != null && rId.isNotEmpty) merged[rId] = Map<String, dynamic>.from(item);
          }
        }
        for (final item in _realtimeRecentResults) {
          final rId = item['roundId']?.toString();
          if (rId != null && rId.isNotEmpty) merged[rId] = Map<String, dynamic>.from(item);
        }

        final sortedRounds = merged.values.toList()
          ..sort((a, b) {
            final aRound = int.tryParse(a['roundId']?.toString() ?? '0') ?? 0;
            final bRound = int.tryParse(b['roundId']?.toString() ?? '0') ?? 0;
            return bRound.compareTo(aRound);
          });

        if (sortedRounds.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text("Waiting for round outcomes...", style: TextStyle(color: Colors.white70, fontSize: 14)),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: sortedRounds.length,
          itemBuilder: (context, index) {
            final rec = sortedRounds[index];
            final emoji = rec['emoji']?.toString() ?? _getFoodEmoji(rec['name']?.toString() ?? '');
            final name = rec['name']?.toString() ?? 'Unknown';
            final mult = rec['multiplier'] ?? 5;
            final rId = rec['roundId']?.toString() ?? '';
            final roundNum = _getRelativeRoundNumber(rId);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF334155), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji.isNotEmpty ? emoji : '🎰', style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Round: #$roundNum", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text("${mult}x", style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceBox(IconData? icon, Color iconColor, String label, String value, bool hasArrow, double scale, {double? borderRadius, Widget? customIcon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? 20 * scale),
        border: Border.all(color: Colors.black87, width: 1.2 * scale),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: Colors.black87, fontSize: 8 * scale, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (customIcon != null) customIcon,
              if (customIcon == null && icon != null) Icon(icon, color: iconColor, size: 12 * scale),
              SizedBox(width: 4 * scale),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(color: Colors.black, fontSize: 10 * scale, fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasArrow) Icon(Icons.chevron_right, color: Colors.black54, size: 12 * scale),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildMaintenanceScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build_circle, color: Colors.brown, size: 80),
          const SizedBox(height: 16),
          const Text("GAME UNAVAILABLE", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w900, fontSize: 24)),
        ],
      ),
    );
  }
}

int resolveTargetSectorIndex(Map<String, dynamic>? outcome, List<dynamic> segmentsMap) {
  if (outcome == null || segmentsMap.isEmpty) return 0;

  final outcomeName = (outcome['name'] as String? ?? '').toLowerCase().trim();
  final outcomeType = (outcome['type'] as String? ?? '').toLowerCase().trim();

  // 1. Direct match on segment name
  if (outcomeName.isNotEmpty) {
    final idx = segmentsMap.indexWhere((s) {
      final sName = s['name']?.toString().toLowerCase().trim() ?? '';
      return sName == outcomeName;
    });
    if (idx != -1) return idx;

    // Common synonyms/aliases
    if (outcomeName == 'skewer' || outcomeName == 'kebab') {
      final skewerIdx = segmentsMap.indexWhere((s) {
        final n = s['name']?.toString().toLowerCase().trim() ?? '';
        return n == 'skewer' || n == 'kebab';
      });
      if (skewerIdx != -1) return skewerIdx;
    }
    if (outcomeName == 'steak' || outcomeName == 'meat') {
      final steakIdx = segmentsMap.indexWhere((s) {
        final n = s['name']?.toString().toLowerCase().trim() ?? '';
        return n == 'steak' || n == 'meat';
      });
      if (steakIdx != -1) return steakIdx;
    }

    // Special category outcomes: "Salad" or "Pizza"
    if (outcomeName == 'salad' || outcomeType == 'salad') {
      final vegIdx = segmentsMap.indexWhere((s) {
        final n = s['name']?.toString().toLowerCase().trim() ?? '';
        return n == 'tomato' || n == 'carrot' || n == 'corn' || n == 'cabbage';
      });
      if (vegIdx != -1) return vegIdx;
    }
    if (outcomeName == 'pizza' || outcomeType == 'pizza') {
      final meatIdx = segmentsMap.indexWhere((s) {
        final n = s['name']?.toString().toLowerCase().trim() ?? '';
        return n == 'steak' || n == 'chicken' || n == 'hotdog' || n == 'skewer';
      });
      if (meatIdx != -1) return meatIdx;
    }
  }

  // 2. Fallback to sectorIndex from outcome, clamped within segments length
  final rawSector = (outcome['sectorIndex'] as num?)?.toInt();
  if (rawSector != null && rawSector >= 0) {
    return rawSector % segmentsMap.length;
  }

  return 0;
}

int calculateSpinWheelPrize({
  required Map<String, int> bets,
  required String winningName,
  String? winningCategory,
  String? roundType,
  required int multiplier,
}) {
  if (bets.isEmpty) return 0;

  int totalPrize = 0;
  final normalizedBets = <String, int>{};
  bets.forEach((key, val) {
    if (key.isNotEmpty && val > 0) {
      normalizedBets[key.toLowerCase().trim()] = val;
    }
  });

  final winnerName = winningName.toLowerCase().trim();
  final winnerCat = (winningCategory ?? '').toLowerCase().trim();
  final rType = (roundType ?? 'standard').toLowerCase().trim();
  final winnerLabel = '${multiplier}x';

  final paidKeys = <String>{};

  const saladItems = ['tomato', 'cabbage', 'corn', 'carrot', 'salad'];
  const pizzaItems = ['pizza', 'steak'];

  final isWinningSaladItem = saladItems.contains(winnerName) || winnerCat == 'salad';
  final isWinningPizzaItem = pizzaItems.contains(winnerName) || winnerCat == 'pizza';

  // 1. Category Payouts
  if (isWinningSaladItem) {
    final betOnSalad = normalizedBets['salad'] ?? 0;
    if (betOnSalad > 0 && !paidKeys.contains('salad')) {
      totalPrize += betOnSalad * 5;
      paidKeys.add('salad');
    }
  }

  if (isWinningPizzaItem) {
    final betOnPizza = normalizedBets['pizza'] ?? 0;
    if (betOnPizza > 0 && !paidKeys.contains('pizza')) {
      totalPrize += betOnPizza * 45;
      paidKeys.add('pizza');
    }
  }

  // 2. Special Celebration Round Payouts
  if (rType == 'salad') {
    for (final item in ['tomato', 'cabbage', 'corn', 'carrot']) {
      if (!paidKeys.contains(item)) {
        final betOnItem = normalizedBets[item] ?? 0;
        if (betOnItem > 0) {
          totalPrize += betOnItem * 5;
          paidKeys.add(item);
        }
      }
    }
  } else if (rType == 'pizza') {
    for (final item in ['pizza', 'steak']) {
      if (!paidKeys.contains(item)) {
        final betOnItem = normalizedBets[item] ?? 0;
        if (betOnItem > 0) {
          totalPrize += betOnItem * 45;
          paidKeys.add(item);
        }
      }
    }
  }

  // 3. Exact segment bet
  if (!paidKeys.contains(winnerName)) {
    int betOnWinner = normalizedBets[winnerName] ?? normalizedBets[winnerLabel] ?? 0;
    if (betOnWinner == 0) {
      if (winnerName == 'kebab') betOnWinner = normalizedBets['skewer'] ?? 0;
      if (winnerName == 'skewer') betOnWinner = normalizedBets['kebab'] ?? 0;
      if (winnerName == 'steak') betOnWinner = normalizedBets['meat'] ?? 0;
    }
    if (betOnWinner > 0) {
      totalPrize += betOnWinner * multiplier;
      paidKeys.add(winnerName);
    }
  }

  return totalPrize;
}

class SpinItem {
  final String name; final int multiplier; final String emoji; final String? category;
  SpinItem({required this.name, required this.multiplier, required this.emoji, this.category});
}

class PodsPainter extends CustomPainter {
  final List<SpinItem> items; final int? activeIndex; final double scale;
  final int saladHits; final int pizzaHits;
  final Map<String, int> betClickCounts;

  static final Paint _podPaint = Paint()
    ..color = Colors.transparent
    ..style = PaintingStyle.fill;

  static final Paint _pulsePaint = Paint()
    ..color = Colors.amber.withOpacity(0.3)
    ..style = PaintingStyle.stroke;

  static final Paint _glowPaint = Paint()
    ..color = Colors.white.withOpacity(0.15)
    ..style = PaintingStyle.fill;

  PodsPainter({required this.items, required this.activeIndex, required this.betClickCounts, this.scale = 1.0, this.saladHits = 0, this.pizzaHits = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radiusX = 175.0 * scale;
    final radiusY = 175.0 * scale;

    _pulsePaint.strokeWidth = 3 * scale;

    for (int i = 0; i < items.length; i++) {
        final angle = i * (2 * math.pi / 8) - (math.pi / 2);
        final podCenter = Offset(center.dx + math.cos(angle) * radiusX, center.dy + math.sin(angle) * radiusY);
        
        // 1. Transparent Pod (No Border)
        canvas.drawCircle(podCenter, 70 * scale, _podPaint);

        // 2. Pulse Highlight for Winning Segment
        final isHighlighted = activeIndex != null && i == activeIndex;
        if (isHighlighted) {
          canvas.drawCircle(podCenter, 65 * scale, _pulsePaint);
          canvas.drawCircle(podCenter, 60 * scale, _glowPaint);
        }

        // 4. Draw Emoji (Top)
        final emojiPainter = TextPainter(text: TextSpan(text: items[i].emoji, style: TextStyle(fontSize: 32 * scale)), textDirection: TextDirection.ltr)..layout();
        emojiPainter.paint(canvas, podCenter - Offset(emojiPainter.width / 2, 25 * scale));

        // 5. Draw Win Label (Bottom)
        final labelPainter = TextPainter(
          text: TextSpan(
            text: "win ${items[i].multiplier} times", 
            style: TextStyle(
              color: isHighlighted ? Colors.black : Colors.black87, 
              fontSize: 9 * scale, 
              fontWeight: FontWeight.w900,
              shadows: isHighlighted ? [
                const Shadow(color: Colors.white, blurRadius: 6),
                const Shadow(color: Colors.amber, blurRadius: 2),
              ] : null
            )
          ), 
          textDirection: TextDirection.ltr
        )..layout();
        labelPainter.paint(canvas, podCenter - Offset(labelPainter.width / 2, -15 * scale));

        // 6. Draw Coin Icons (Dynamic based on Clicks)
        final clickCount = betClickCounts[items[i].name] ?? 0;
        if (clickCount > 0) {
          final coinsPainter = TextPainter(
            text: TextSpan(
              text: "🪙" * clickCount.clamp(1, 3), // Max 3 coins
              style: TextStyle(fontSize: 10 * scale)
            ), 
            textDirection: TextDirection.ltr
          )..layout();
          coinsPainter.paint(canvas, podCenter - Offset(coinsPainter.width / 2, -25 * scale));
        }

        // Sold Out Overlay
    }
  }
  @override
  bool shouldRepaint(covariant PodsPainter oldDelegate) {
    if (oldDelegate.activeIndex != activeIndex) return true;
    if (oldDelegate.scale != scale) return true;
    if (oldDelegate.saladHits != saladHits) return true;
    if (oldDelegate.pizzaHits != pizzaHits) return true;
    if (oldDelegate.items.length != items.length) return true;
    if (oldDelegate.betClickCounts.length != betClickCounts.length) return true;
    for (final key in betClickCounts.keys) {
      if (oldDelegate.betClickCounts[key] != betClickCounts[key]) return true;
    }
    for (int i = 0; i < items.length; i++) {
      if (oldDelegate.items[i].name != items[i].name ||
          oldDelegate.items[i].multiplier != items[i].multiplier ||
          oldDelegate.items[i].emoji != items[i].emoji) {
        return true;
      }
    }
    return false;
  }
}

class GlowPointerPainter extends CustomPainter {
  final int? activeIndex;
  final double scale;
  GlowPointerPainter({required this.activeIndex, this.scale = 1.0});
  @override
  void paint(Canvas canvas, Size size) {
    if (activeIndex == null) return;

    final center = Offset(size.width / 2, size.height / 2); 
    final radiusX = 130.0 * scale;
    final radiusY = 148.0 * scale;
    
    final double lightAngle = (activeIndex! * (2 * math.pi / 8)) - (math.pi / 2);
    final lightPos = Offset(center.dx + math.cos(lightAngle) * radiusX, center.dy + math.sin(lightAngle) * radiusY);
    
    canvas.drawCircle(lightPos, 50 * scale, Paint()..color = const Color(0xFFFFD700).withOpacity(0.4)..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * scale));
    canvas.drawCircle(lightPos, 40 * scale, Paint()..color = Colors.white.withOpacity(0.6)..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale));
    canvas.drawCircle(lightPos, 4 * scale, Paint()..color = Colors.white);
  }
  @override bool shouldRepaint(covariant GlowPointerPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex || oldDelegate.scale != scale;
  }
}

class SpinWheelResultBottomSheet extends ConsumerStatefulWidget {
  final SpinItem item;
  final int winnings;
  final int wager;
  final List<dynamic> winners;
  final String? roundId;
  final Map<String, int>? bets;
  final int? serverTimeOffset;

  const SpinWheelResultBottomSheet({
    super.key,
    required this.item,
    required this.winnings,
    required this.wager,
    required this.winners,
    this.roundId,
    this.bets,
    this.serverTimeOffset,
  });

  @override
  ConsumerState<SpinWheelResultBottomSheet> createState() => _SpinWheelResultBottomSheetState();
}

class _SpinWheelResultBottomSheetState extends ConsumerState<SpinWheelResultBottomSheet> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _autoCloseTimer;
  Timer? _safetyTimer;
  bool _isDismissingOrDismissed = false;

  void _safeDismiss() {
    if (_isDismissingOrDismissed) return;
    _isDismissingOrDismissed = true;
    _autoCloseTimer?.cancel();
    _safetyTimer?.cancel();

    if (!mounted) return;
    try {
      final route = ModalRoute.of(context);
      if (route != null && route.isActive && route.isCurrent) {
        route.navigator?.pop();
        debugPrint('[SPIN_WHEEL_EVENT] 🚪 Result bottom sheet safely dismissed itself');
      } else {
        debugPrint('[SPIN_WHEEL_EVENT] ℹ️ Result bottom sheet dismiss skipped (route is not current/active)');
      }
    } catch (e) {
      debugPrint('[SPIN_WHEEL_EVENT] ⚠️ Error dismissing result bottom sheet: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    final outcomeTitle = widget.wager > 0 ? (widget.winnings > 0 ? "YOU WIN!" : "YOU LOST") : "ROUND COMPLETED";
    debugPrint('[SPIN_WHEEL_EVENT] 🌟 Result Bottom Sheet Initialized: title="$outcomeTitle", item="${widget.item.name}" (${widget.item.emoji} ${widget.item.multiplier}x), wager=${widget.wager}, winnings=${widget.winnings}');

    if (widget.serverTimeOffset != null) {
      final syncMs = DateTime.now().millisecondsSinceEpoch + widget.serverTimeOffset!;
      const serverRoundMs = 40000;
      final msIntoCycle = syncMs % serverRoundMs;
      final activeRoundId = (syncMs ~/ serverRoundMs).toString();

      // Guard: If sheet opens outside the 34s - 38s results window, dismiss immediately!
      if ((widget.roundId != null && widget.roundId != activeRoundId) || msIntoCycle < 34000 || msIntoCycle >= 38000) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDismissingOrDismissed) {
            _safeDismiss();
          }
        });
        return;
      }
    }

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _mainController.forward();

    // Automatically close before 38.0s of cycle (maximum 2.5s display)
    int remainingMsInPhase = 2500;
    if (widget.serverTimeOffset != null) {
      final syncMs = DateTime.now().millisecondsSinceEpoch + widget.serverTimeOffset!;
      final msIntoCycle = syncMs % 40000;
      if (msIntoCycle < 38000) {
        remainingMsInPhase = (38000 - msIntoCycle).clamp(800, 2500);
      } else {
        remainingMsInPhase = 600;
      }
    }
    debugPrint('[SPIN_WHEEL_EVENT] ⏱️ Result Bottom Sheet auto-close scheduled in ${remainingMsInPhase}ms');

    _autoCloseTimer = Timer(Duration(milliseconds: remainingMsInPhase), () {
      if (mounted && !_isDismissingOrDismissed) {
        debugPrint('[SPIN_WHEEL_EVENT] ⏱️ Result Bottom Sheet auto-closing on timer expiration');
        _safeDismiss();
      }
    });

    // Proactive safety watcher: checks every 100ms to guarantee sheet NEVER lingers into betting phase
    if (widget.serverTimeOffset != null) {
      _safetyTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || _isDismissingOrDismissed) {
          _safetyTimer?.cancel();
          return;
        }
        final curSync = DateTime.now().millisecondsSinceEpoch + widget.serverTimeOffset!;
        final curMs = curSync % 40000;
        final curRound = (curSync ~/ 40000).toString();
        if (curMs < 34000 || curMs >= 38200 || (widget.roundId != null && widget.roundId != curRound)) {
          _safetyTimer?.cancel();
          debugPrint('[SPIN_WHEEL_EVENT] 🚨 Safety watcher closed result sheet before betting phase');
          _safeDismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    debugPrint('[SPIN_WHEEL_EVENT] 🚪 Result Bottom Sheet Disposed');
    _isDismissingOrDismissed = true;
    _autoCloseTimer?.cancel();
    _safetyTimer?.cancel();
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final nameLower = widget.item.name.toLowerCase().trim();
    final categoryLower = (widget.item.category ?? '').toLowerCase().trim();
    final isSalad = nameLower == 'salad' || categoryLower == 'salad';

    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, screenHeight * 0.2 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFB0B0B13), // Ultra-premium semi-transparent deep navy
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.35), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 25,
              spreadRadius: 3,
            ),
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.08),
              blurRadius: 40,
              spreadRadius: 5,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Wavy Streamers + Fork + Knife Custom Painter
            Positioned(
              top: -30,
              left: 0,
              right: 0,
              height: 100,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ForkKnifeStreamerPainter(),
                ),
              ),
            ),

            // 2. High-Contrast White-Border Sticker in Center
            Positioned(
              top: -38,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: StickerEmojiWidget(
                    emoji: widget.item.emoji,
                    size: 46,
                  ),
                ),
              ),
            ),

            // 3. Main Body Column
            Padding(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOutcomeHeader(),
                  const SizedBox(height: 20),
                  // RESULTS ROW (Panda Mascot + Dynamic Backend Data Column)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cute White 🐼 Circle Mascot matching the Wheel Hub
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1E293B), width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "🐼",
                          style: TextStyle(
                            fontSize: 50,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      // Dynamic Backend Data
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "This round's results: ",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "${widget.item.emoji} ${widget.item.name}",
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700), // Highly prominent Gold result name
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "This round's winnings: ",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const PremiumDiamond(size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  "${widget.winnings}",
                                  style: TextStyle(
                                    color: widget.winnings > 0 ? const Color(0xFF4ADE80) : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "Your wager this round: ",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.stars,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "${widget.wager}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (isSalad) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text("🥗", style: TextStyle(fontSize: 16)),
                              SizedBox(width: 6),
                              Text(
                                "Salad System Breakdown (5x)",
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildSaladItemRow("🍅 Tomato", widget.bets?['tomato'] ?? 0),
                          _buildSaladItemRow("🥬 Lettuce", widget.bets?['cabbage'] ?? 0),
                          _buildSaladItemRow("🌽 Corn", widget.bets?['corn'] ?? 0),
                          _buildSaladItemRow("🥕 Carrot", widget.bets?['carrot'] ?? 0),
                        ],
                      ),
                    ),
                  ],

                  // TOP 3 WINNERS OF COMPLETED ROUND
                  Consumer(
                    builder: (context, ref, child) {
                      final roundId = widget.roundId ?? '';
                      final liveWinners = ref.watch(luckySpinCurrentRoundWinnersProvider(roundId)).valueOrNull ?? [];
                      final roundWinners = List<Map<String, dynamic>>.from(
                        liveWinners.isNotEmpty 
                            ? liveWinners 
                            : widget.winners.whereType<Map<String, dynamic>>().toList()
                      );

                      // Include current user if they placed bets in this round
                      if (widget.wager > 0) {
                        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                        final hasMe = roundWinners.any((w) => (w['uid'] ?? w['userId'] ?? '').toString() == currentUid);
                        if (!hasMe) {
                          final profile = ref.watch(currentUserProfileProvider).value;
                          roundWinners.add({
                            'uid': currentUid,
                            'name': profile?.displayName.isNotEmpty == true 
                                ? profile!.displayName 
                                : (profile?.username.isNotEmpty == true ? profile!.username : 'You'),
                            'avatar': profile?.profilePhotoUrl ?? '',
                            'totalBet': widget.wager,
                            'winnings': widget.winnings,
                          });
                        }
                      }

                      // Deduplicate strictly by uid or name so no user is ever duplicated
                      final seen = <String>{};
                      final uniqueList = <Map<String, dynamic>>[];
                      for (final w in roundWinners) {
                        final uid = (w['uid'] ?? w['userId'] ?? '').toString().trim();
                        final name = (w['name'] ?? w['username'] ?? '').toString().trim().toLowerCase();
                        final key = uid.isNotEmpty ? uid : name;
                        if (key.isNotEmpty && seen.contains(key)) continue;
                        if (key.isNotEmpty) seen.add(key);
                        uniqueList.add(w);
                      }

                      // Sort by totalBet descending, then winnings descending
                      uniqueList.sort((a, b) {
                        final aBet = (a['totalBet'] as num?)?.toInt() ?? 0;
                        final bBet = (b['totalBet'] as num?)?.toInt() ?? 0;
                        if (bBet != aBet) return bBet.compareTo(aBet);
                        final aWin = (a['winnings'] as num?)?.toInt() ?? (a['prize'] as num?)?.toInt() ?? 0;
                        final bWin = (b['winnings'] as num?)?.toInt() ?? (b['prize'] as num?)?.toInt() ?? 0;
                        return bWin.compareTo(aWin);
                      });

                      if (uniqueList.isEmpty) return const SizedBox.shrink();

                      return _buildTop3WinnersPodium(uniqueList.take(3).toList());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop3WinnersPodium(List<Map<String, dynamic>> winners) {
    // Deduplicate strictly by uid and by name
    final seen = <String>{};
    final uniqueWinners = <Map<String, dynamic>>[];
    for (final w in winners) {
      final uid = (w['uid'] ?? w['userId'] ?? '').toString().trim();
      final name = (w['name'] ?? w['username'] ?? '').toString().trim().toLowerCase();
      final key = uid.isNotEmpty ? uid : name;
      if (key.isNotEmpty && seen.contains(key)) continue;
      if (key.isNotEmpty) seen.add(key);
      uniqueWinners.add(w);
    }

    if (uniqueWinners.isEmpty) return const SizedBox.shrink();

    final count = uniqueWinners.length;
    final headerTitle = count == 1 
        ? "ROUND WINNER" 
        : count == 2 
            ? "TOP 2 WINNERS" 
            : "TOP 3 WINNERS";

    return Column(
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: CustomDashedDivider(color: Color(0xFFFFD700)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                headerTitle,
                style: TextStyle(
                  color: const Color(0xFFFFD700).withOpacity(0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Expanded(
              child: CustomDashedDivider(color: Color(0xFFFFD700)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (count == 1)
          // 1 user only: show single centered user
          Center(
            child: _buildTopWinnerSlot(uniqueWinners[0], 0),
          )
        else if (count == 2)
          // 2 users only: show exactly 2 users
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTopWinnerSlot(uniqueWinners[1], 1), // Rank 2 (Silver)
              const SizedBox(width: 40),
              _buildTopWinnerSlot(uniqueWinners[0], 0), // Rank 1 (Gold)
            ],
          )
        else
          // 3 or more users: show Top 3
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTopWinnerSlot(uniqueWinners[1], 1), // Rank 2 (Silver, Left)
              _buildTopWinnerSlot(uniqueWinners[0], 0), // Rank 1 (Gold, Center, Tallest)
              _buildTopWinnerSlot(uniqueWinners[2], 2), // Rank 3 (Bronze, Right)
            ],
          ),
      ],
    );
  }

  Widget _buildTopWinnerSlot(Map<String, dynamic> winner, int rankIndex) {
    final rankColors = [
      const Color(0xFFFFD700), // Gold for Rank 1
      const Color(0xFFC0C0C0), // Silver for Rank 2
      const Color(0xFFCD7F32), // Bronze for Rank 3
    ];
    final rankLabels = ["#1", "#2", "#3"];
    final rankColor = rankColors[rankIndex];

    final name = (winner['name'] ?? winner['username'] ?? "User").toString();
    final avatarUrl = (winner['avatar'] ?? winner['photoUrl'] ?? "").toString();
    final totalBet = (winner['totalBet'] as num?)?.toInt() ?? 0;
    final winnings = (winner['winnings'] as num?)?.toInt() ?? (winner['prize'] as num?)?.toInt() ?? 0;
    final isCenter = rankIndex == 0;
    final avatarRadius = isCenter ? 24.0 : 20.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: rankColor.withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Colors.white10,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Icon(Icons.person, color: rankColor, size: isCenter ? 26 : 22)
                    : null,
              ),
            ),
            Transform.translate(
              offset: const Offset(3, 3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rankLabels[rankIndex],
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumDiamond(size: 10),
            const SizedBox(width: 2.5),
            Text(
              winnings > 0 ? _formatNumber(winnings) : _formatNumber(totalBet),
              style: TextStyle(
                color: rankColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaladItemRow(String label, int bet) {
    final win = bet * 5;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text(
                win >= 1000 ? "${(win / 1000).toStringAsFixed(1)}k" : win.toString(),
                style: TextStyle(
                  color: win > 0 ? Colors.amber : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const PremiumDiamond(size: 11),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return "${(number / 1000000).toStringAsFixed(1)}M";
    if (number >= 1000) return "${(number / 1000).toStringAsFixed(1)}K";
    return number.toString();
  }

  Widget _buildOutcomeHeader() {
    final winnings = widget.winnings;
    final wager = widget.wager;

    final String title;
    final Color textColor;
    final Color glowColor;
    final String icon;

    if (wager > 0) {
      if (winnings > 0) {
        title = "YOU WIN!";
        textColor = const Color(0xFF4ADE80); // Bright emerald green
        glowColor = const Color(0xFF4ADE80).withOpacity(0.3);
        icon = "🎉";
      } else {
        title = "YOU LOST";
        textColor = const Color(0xFFF87171); // Soft red
        glowColor = const Color(0xFFF87171).withOpacity(0.2);
        icon = "💸";
      }
    } else {
      title = "ROUND COMPLETED";
      textColor = const Color(0xFF60A5FA); // Soft blue
      glowColor = const Color(0xFF60A5FA).withOpacity(0.2);
      icon = "🎰";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 12,
            spreadRadius: 1,
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(icon, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

// ── CUSTOM VECTOR PAINTERS & SUPPORTING WIDGETS ──────────────────────────────

class ForkKnifeStreamerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;

    final paintStreamerOrange = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final paintStreamerBlue = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;

    // 1. Draw Wavy Streamers in the background
    // Left Streamer
    final pathLeft = Path()
      ..moveTo(w * 0.28, h * 0.55)
      ..quadraticBezierTo(w * 0.23, h * 0.22, w * 0.14, h * 0.44)
      ..quadraticBezierTo(w * 0.08, h * 0.65, 0, h * 0.45);
    canvas.drawPath(pathLeft, paintStreamerOrange);

    // Right Streamer
    final pathRight = Path()
      ..moveTo(w * 0.72, h * 0.55)
      ..quadraticBezierTo(w * 0.77, h * 0.22, w * 0.86, h * 0.44)
      ..quadraticBezierTo(w * 0.92, h * 0.65, w, h * 0.45);
    canvas.drawPath(pathRight, paintStreamerBlue);

    // 2. Draw Fork Silhouette (Left of center, around w * 0.33)
    final forkX = w * 0.33;
    final forkY = h * 0.48;
    // Base prongs block
    canvas.drawRect(Rect.fromLTWH(forkX - 4.5, forkY - 11, 9, 5), paintWhite);
    // 3 prongs going up
    canvas.drawRect(Rect.fromLTWH(forkX - 4.5, forkY - 21, 1.6, 11), paintWhite);
    canvas.drawRect(Rect.fromLTWH(forkX - 0.8, forkY - 21, 1.6, 11), paintWhite);
    canvas.drawRect(Rect.fromLTWH(forkX + 2.9, forkY - 21, 1.6, 11), paintWhite);
    // Neck and solid handle
    canvas.drawRect(Rect.fromLTWH(forkX - 1.2, forkY - 6, 2.4, 4), paintWhite);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(forkX - 1.6, forkY - 2, 3.2, 23), const Radius.circular(1.2)),
      paintWhite,
    );

    // 3. Draw Knife Silhouette (Right of center, around w * 0.67)
    final knifeX = w * 0.67;
    final knifeY = h * 0.48;
    // Knife blade path
    final knifeBladePath = Path()
      ..moveTo(knifeX - 2.2, knifeY - 21)
      ..lineTo(knifeX + 2.2, knifeY - 21)
      ..quadraticBezierTo(knifeX + 3.2, knifeY - 11, knifeX + 2.2, knifeY - 5)
      ..lineTo(knifeX - 2.2, knifeY - 5)
      ..close();
    canvas.drawPath(knifeBladePath, paintWhite);
    // Connector neck
    canvas.drawRect(Rect.fromLTWH(knifeX - 1.2, knifeY - 5, 2.4, 4), paintWhite);
    // Knife handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(knifeX - 1.6, knifeY - 1, 3.2, 22), const Radius.circular(1.2)),
      paintWhite,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StickerEmojiWidget extends StatelessWidget {
  final String emoji;
  final double size;
  const StickerEmojiWidget({super.key, required this.emoji, this.size = 50});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Deep slate background for sticker backing
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.45),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: size,
          height: 1.1,
        ),
      ),
    );
  }
}

class CustomDashedDivider extends StatelessWidget {
  final Color color;
  final double height;
  final double dashWidth;
  final double dashSpace;

  const CustomDashedDivider({
    super.key,
    this.color = Colors.white,
    this.height = 1.0,
    this.dashWidth = 3.5,
    this.dashSpace = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dashWidth: dashWidth,
          dashSpace: dashSpace,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height == 0 ? 1 : size.height
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}