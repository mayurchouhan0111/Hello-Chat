import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'package:hello_chat/core/providers/game_provider.dart';
import 'package:hello_chat/core/services/game_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hello_chat/core/utils/app_persistent_cache.dart';
import 'package:hello_chat/core/services/wakelock_service.dart';
import 'package:hello_chat/core/services/game_recovery_service.dart';

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
  SpinGameState _gameState = SpinGameState.betting;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();

  // Track cached sound paths to avoid socket exceptions
  String? _localBetSoundPath;
  String? _localSpinSoundPath;
  String? _localWinSoundPath;

  void _precacheSounds() async {
    try {
      final betFile = await AppPersistentCache.getFile("https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav");
      final spinFile = await AppPersistentCache.getFile("https://assets.mixkit.co/active_storage/sfx/2021/2021-84.wav");
      final winFile = await AppPersistentCache.getFile("https://assets.mixkit.co/active_storage/sfx/2020/2020-84.wav");
      
      if (mounted) {
        setState(() {
          _localBetSoundPath = betFile.path;
          _localSpinSoundPath = spinFile.path;
          _localWinSoundPath = winFile.path;
        });
        debugPrint("🔊 SpinWheel: Game sounds precached locally successfully!");
      }
    } catch (e) {
      debugPrint("⚠️ SpinWheel: Failed to precache game sounds: $e");
    }
  }

  void _playBetSoundAndHaptic() async {
    // HapticFeedback.lightImpact();
    try {
      await _effectPlayer.stop();
      if (_localBetSoundPath != null) {
        await _effectPlayer.play(DeviceFileSource(_localBetSoundPath!));
      } else {
        final file = await AppPersistentCache.getFile("https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav");
        _localBetSoundPath = file.path;
        await _effectPlayer.play(DeviceFileSource(_localBetSoundPath!));
      }
    } catch (_) {}
  }

  void _playCountdownTick() async {
    // HapticFeedback.selectionClick();
    try {
      await _effectPlayer.stop();
      if (_localBetSoundPath != null) {
        await _effectPlayer.play(DeviceFileSource(_localBetSoundPath!));
      } else {
        final file = await AppPersistentCache.getFile("https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav");
        _localBetSoundPath = file.path;
        await _effectPlayer.play(DeviceFileSource(_localBetSoundPath!));
      }
    } catch (_) {}
  }

  void _placeBet(String itemName, List<SpinItem> items) {
    if (_isBetLocked) return;
    if (_isOffline) return;

    final lowerName = itemName.toLowerCase().trim();
    if (lowerName == 'salad' || lowerName == 'pizza') {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient Diamonds & Stars"))
      );
      return;
    }

    _playBetSoundAndHaptic();

    setState(() {
      _currentBets[exactName] = (_currentBets[exactName] ?? 0) + _selectedChipValue;
      _betClickCounts[exactName] = (_betClickCounts[exactName] ?? 0) + 1;
    });

    // Clear confirmed state since bets changed
    setState(() {
      _confirmedBets = {};
    });

    // Start debounce timer for auto-submit
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || _currentBets.isEmpty) return;
      _autoSubmitBets();
    });

    // Persist bet state for crash recovery
    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final roundId = (now ~/ serverRoundMs).toString();
    GameRecoveryService().saveBetState(
      bets: _currentBets,
      betClickCounts: _betClickCounts,
      roundId: roundId,
      timestamp: now,
    );
  }

  Future<void> _autoSubmitBets() async {
    if (_currentBets.isEmpty || _isBetLocked) return;

    final totalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
    if (totalBet <= 0) return;

    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final secondsIntoCycle = (now % serverRoundMs) ~/ 1000;

    // Only auto-submit during betting phase (first 30 seconds of 40s cycle)
    if (secondsIntoCycle >= 30) return;

    try {
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: totalBet,
        bets: _currentBets,
        roomId: widget.roomId,
      );

      if (!mounted) return;

      final resultRoundId = result['roundId']?.toString();
      if (resultRoundId != null && result['status'] == 'confirmed') {
        setState(() {
          _confirmedBets = Map.from(_currentBets);
        });
        GameRecoveryService().clearBetState();
      }
    } catch (e) {
      debugPrint("⚠️ Auto-submit failed: $e");
    }
  }

  int _tickCurrentIndex = 0;
  int _tickTargetIndex = 0;
  int _currentTickIndex = 0;
  List<double> _tickDurations = [];
  List<double> _tickFireTimes = [];
  Timer? _tickTimer;

  bool _spinCompleted = false;
  bool _resultLock = false;
  int? _lastCalculatedRound;
  BuildContext? _bottomSheetContext;
  
  int _serverTimeOffset = 0;
  StreamSubscription? _offsetSubscription;
  String? _hasSpunForRound;
  bool _hasStartedFallbackCall = false;

  int get _synchronizedTimeMs {
    return DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async => await WakelockService().acquire());

    _offsetSubscription = FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (mounted) {
        final offset = (event.snapshot.value as num?)?.toInt() ?? 0;
        setState(() {
          _serverTimeOffset = offset;
        });
      }
    });

    // Firebase RTDB connection state
    _connectivitySub = FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) {
      if (!mounted) return;
      final rtdbConnected = event.snapshot.value as bool? ?? false;
      debugPrint('[SPIN_WHEEL] Firebase RTDB .info/connected = $rtdbConnected');
      _updateOfflineState(rtdbConnected: rtdbConnected);
    });

    // Platform network connectivity (WiFi / Mobile data)
    _platformConnectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      final hasNetwork = result != ConnectivityResult.none;
      debugPrint('[SPIN_WHEEL] Platform connectivity = $result (hasNetwork=$hasNetwork)');
      _updateOfflineState(platformOnline: hasNetwork);
    });

    // Initial platform check
    Connectivity().checkConnectivity().then((result) {
      if (!mounted) return;
      final hasNetwork = result != ConnectivityResult.none;
      debugPrint('[SPIN_WHEEL] Initial platform connectivity = $result (hasNetwork=$hasNetwork)');
      _updateOfflineState(platformOnline: hasNetwork);
    });

    _lastCalculatedRound = _calculateCurrentRound();
    _idleController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    int lastIdleSegment = 0;
    _idleController.addListener(() {
      if (_gameState != SpinGameState.betting || _isSpinning || _spinCompleted || !mounted) return;

      final double currentAngle = _idleController.value * 2 * math.pi;
      final double step = 2 * math.pi / 8;
      double normalized = (currentAngle + step / 2) % (2 * math.pi);
      if (normalized < 0) normalized += 2 * math.pi;
      final int segment = (normalized / step).floor() % 8;

      setState(() {
        _pointerAngle = currentAngle;
        _currentSegment = segment;
      });

      if (segment != lastIdleSegment) {
        // HapticFeedback.lightImpact();
        lastIdleSegment = segment;
      }
    });

    _precacheSounds();
    _startCountdown();
    _playPhaseSound(SpinGameState.betting);

    _tryRecoverGameState();
  }

  Future<void> _tryRecoverGameState() async {
    try {
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
        debugPrint("♻️ Game recovery: Restored bets for round $savedRoundId");
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

  void _playPhaseSound(SpinGameState state) async {
    try {
      await _audioPlayer.stop();
      if (!mounted) return;

      switch (state) {
        case SpinGameState.betting:
          if (_localBetSoundPath != null) {
            await _audioPlayer.play(DeviceFileSource(_localBetSoundPath!));
          } else {
            final file = await AppPersistentCache.getFile("https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav");
            _localBetSoundPath = file.path;
            if (mounted && _gameState == SpinGameState.betting) {
              await _audioPlayer.play(DeviceFileSource(_localBetSoundPath!));
            }
          }
          break;
        case SpinGameState.spinning:
          if (_localSpinSoundPath != null) {
            await _audioPlayer.play(DeviceFileSource(_localSpinSoundPath!));
          } else {
            final file = await AppPersistentCache.getFile("https://assets.mixkit.co/active_storage/sfx/2021/2021-84.wav");
            _localSpinSoundPath = file.path;
            if (mounted && _gameState == SpinGameState.spinning) {
              await _audioPlayer.play(DeviceFileSource(_localSpinSoundPath!));
            }
          }
          break;
        case SpinGameState.results:
          if (_localWinSoundPath != null) {
            await _audioPlayer.play(DeviceFileSource(_localWinSoundPath!));
          } else {
            final file = await AppPersistentCache.getFile("https://assets.mixkit.co/active_storage/sfx/2020/2020-84.wav");
            _localWinSoundPath = file.path;
            if (mounted && _gameState == SpinGameState.results) {
              await _audioPlayer.play(DeviceFileSource(_localWinSoundPath!));
            }
          }
          break;
      }
    } catch (_) {}
  }

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
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      const serverRoundDurationMs = 40000;
      const serverBettingPhaseSec = 30;
      const serverSpinPhaseSec = 5;

      final now = _synchronizedTimeMs;
      final secondsIntoCycle = (now % serverRoundDurationMs) ~/ 1000;
      final msIntoCycle = now % serverRoundDurationMs;
      final currentRoundVal = _calculateCurrentRound();
      _currentRoundId = (now ~/ serverRoundDurationMs).toString();

      // Rollover / Invalidations on a new round
      if (_lastCalculatedRound != null && currentRoundVal != _lastCalculatedRound) {
        // We no longer automatically close the bottom sheet here to prevent double-pop 
        // crashes if the user is dismissing it at the exact same moment.
        // It will be replaced when the next result arrives, or dismissed naturally.

        setState(() {
          _currentBets = {};
          _betClickCounts = {};
          _hasSpunForRound = null;
          _hasStartedFallbackCall = false;
          _hasShownResultForRound = null;
          if (_resultPendingRoundId != _currentRoundId) {
            _pendingRoundResult = null;
            _hasPendingResult = false;
            _resultPendingRoundId = null;
          }
          _resultLock = false;
          _spinCompleted = false;
          _showRoundTransition = false;
        });

        // Show any pending stored result from previous round after clearing old state
        if (_storedWinItem != null) {
          _showStoredResult();
        }
        _clearStoredResult();
        ref.invalidate(luckySpinStatsProvider);
        ref.invalidate(userGameHistoryProvider);
      }
      _lastCalculatedRound = currentRoundVal;

      // Round transition countdown (last 3 seconds before next round)
      final transitionStart = serverBettingPhaseSec + serverSpinPhaseSec + 7;
      if (secondsIntoCycle >= transitionStart && secondsIntoCycle < serverRoundDurationMs ~/ 1000) {
        final remaining = (serverRoundDurationMs ~/ 1000) - secondsIntoCycle;
        if (remaining <= 3 && remaining >= 1) {
          if (!_showRoundTransition) {
            setState(() { _showRoundTransition = true; });
          }
          if (remaining != _roundTransitionCountdown) {
            setState(() { _roundTransitionCountdown = remaining; });
          }
        }
      } else {
        if (_showRoundTransition) {
          setState(() { _showRoundTransition = false; });
        }
      }

      // Update countdown display (phase-aware)
      int newCountdown;
      String newLabel;
      if (_gameState == SpinGameState.results) {
        newCountdown = ((serverBettingPhaseSec + serverSpinPhaseSec + 5) - secondsIntoCycle).clamp(0, 5);
        newLabel = "Winning";
      } else if (_gameState == SpinGameState.spinning) {
        newCountdown = 0;
        newLabel = "Spinning";
      } else {
        newCountdown = (serverBettingPhaseSec - secondsIntoCycle).clamp(0, serverBettingPhaseSec);
        newLabel = "Select time";
      }
      if (newCountdown != _countdown || newLabel != _countdownLabel) {
        setState(() {
          _countdown = newCountdown;
          _countdownLabel = newLabel;
        });
        if (newCountdown <= 5 && newCountdown > 0 && _gameState == SpinGameState.betting) {
          _playCountdownTick();
        }
      }

      // Update bet locking state (lock 5s before server betting phase end)
      final newBetLocked = (secondsIntoCycle >= serverBettingPhaseSec - 5);
      if (newBetLocked != _isBetLocked) {
        setState(() {
          _isBetLocked = newBetLocked;
        });
      }

      // PHASE 1: BETTING / IDLE
      if (secondsIntoCycle < serverBettingPhaseSec) {
        if (_gameState != SpinGameState.betting && !_isSpinning) {
          setState(() {
            _gameState = SpinGameState.betting;
            _spinCompleted = false;
            _playPhaseSound(SpinGameState.betting);
            _idleController.repeat();
          });
        }
      }
      // PHASE 2: SPINNING PHASE
      else if (secondsIntoCycle >= serverBettingPhaseSec && secondsIntoCycle < serverBettingPhaseSec + serverSpinPhaseSec) {
        if (_gameState != SpinGameState.spinning && !_isSpinning && _hasSpunForRound != _currentRoundId) {
          setState(() {
            _gameState = SpinGameState.spinning;
          });
        }

        if (_hasSpunForRound != _currentRoundId && !_isSpinning) {
          final totalBet = _currentBets.values.fold(0, (sum, val) => sum + val);

          // 1. Bettor: Submit bets immediately!
          if (totalBet > 0) {
            _handleSpin();
            _hasSpunForRound = _currentRoundId;
          }
          // 2. Spectator: Use pending result from local storage, else fallback call
          else {
            if (_hasPendingResult && _resultPendingRoundId == _currentRoundId) {
              _startSpin(_pendingRoundResult!);
              _hasSpunForRound = _currentRoundId;
              _hasPendingResult = false;
            } else if (msIntoCycle >= serverBettingPhaseSec * 1000 + 1500 && !_hasStartedFallbackCall) {
              _hasStartedFallbackCall = true;
              _handleSpin();
              _hasSpunForRound = _currentRoundId;
            }
          }
        }
      }
      // PHASE 3: RESULTS CELEBRATION
      else if (secondsIntoCycle >= serverBettingPhaseSec + serverSpinPhaseSec) {
        if (_gameState != SpinGameState.results && !_isSpinning) {
          setState(() {
            _gameState = SpinGameState.results;
          });
        }

        // Show stored result from spin animation
        if (_storedWinItem != null && _hasShownResultForRound != _currentRoundId) {
          _hasShownResultForRound = _currentRoundId;
          _showStoredResult();
        }

        // Late Join / Spectator Catch-up: prefer pending result, fallback to stream
        if (!_resultLock && !_isSpinning && _storedWinItem == null && _hasShownResultForRound != _currentRoundId) {
          Map<String, dynamic>? outcome;
          if (_hasPendingResult && _resultPendingRoundId == _currentRoundId) {
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

            // Try to recover user's actual bet result from their game history if they were a player
            final history = ref.read(userGameHistoryProvider).value ?? [];
            final matchedHistory = history.where((h) => h['roundId']?.toString() == _currentRoundId).firstOrNull;
            if (matchedHistory != null) {
              prize = (matchedHistory['prize'] as num?)?.toInt() ?? 0;
              wager = (matchedHistory['totalBet'] as num?)?.toInt() ?? 0;
              betsCopy = (matchedHistory['bets'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
            }

            final resultName = outcome['name'] as String? ?? "";
            final resultEmoji = outcome['emoji'] as String? ?? "";
            final resultCategory = outcome['category'] as String?;
            final int serverSectorIndex = (outcome['sectorIndex'] as num?)?.toInt() ?? 0;

            final matchingSegment = segmentsMap.firstWhere(
              (s) => s['name']?.toString().toLowerCase().trim() == resultName.toLowerCase().trim(),
              orElse: () => segmentsMap[serverSectorIndex],
            );

            final winningItem = SpinItem(
              name: matchingSegment['name'] ?? resultName,
              multiplier: wager > 0 ? (prize / wager).round() : 0,
              emoji: resultEmoji.isNotEmpty ? resultEmoji : (matchingSegment['emoji'] ?? ''),
              category: resultCategory ?? matchingSegment['category']
            );

            final roundWinners = outcome['todayWinners'] as List? ?? outcome['roundWinners'] as List? ?? [];
            final roundIdVal = outcome['roundId']?.toString() ?? _currentRoundId ?? '';

            _hasSpunForRound = _currentRoundId;
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
    });
  }

  void _handleSpin() async {
    final settings = ref.read(gameSettingsProvider).value;
    if (settings == null || !settings['isActive'] || _isSpinning) return;
    
    _isSpinning = true;
    _isBetLocked = true;

    final wallet = ref.read(walletBalanceProvider).value;
    final diamonds = wallet?['diamonds'] ?? 0;
    final beans = wallet?['beans'] ?? 0;

    final totalBet = _currentBets.values.fold(0, (sum, val) => sum + val);

    if (totalBet > 0) {
      final totalPlayingPower = diamonds + (beans * 2 / 7).floor();
      if (totalPlayingPower < totalBet) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient Diamonds & Stars")));
         setState(() {
           _isSpinning = false;
           _isBetLocked = false;
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

    // Start fast Dummy Spin while waiting for network
    _tickTimer?.cancel();
    double currentDummyTickMs = 200.0;
    void dummyTick() {
      if (!mounted || !_isSpinning) return;
      setState(() {
        _currentSegment = (_currentSegment + 1) % 8;
      });
      // HapticFeedback.lightImpact();
      if (currentDummyTickMs > 60.0) {
        currentDummyTickMs -= 15.0; // Accelerate smoothly
      }
      _tickTimer = Timer(Duration(milliseconds: currentDummyTickMs.toInt()), dummyTick);
    }
    dummyTick();

    try {
      final result = await ref.read(gameServiceProvider).playSpinWheel(
        betAmount: totalBet,
        bets: _currentBets,
        roomId: widget.roomId,
      );
      
      if (!mounted) return;

      final resultRoundId = result['roundId']?.toString();
      const serverRoundMs = 40000;
      
      // If the result arrives late (e.g., cold start delay), we no longer discard it.
      // _startSpin will see the round mismatch and execute a quick 600ms spin to show the result.
      
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
        
        // ONLY SHOW SNACKBAR TO ACTIVE PLAYERS!
        if (hadBet) {
          String errorMessage = "Failed to spin. Please try again.";
          final errorStr = e.toString();
          if (errorStr.contains('failed-precondition') || errorStr.contains('Betting phase closed')) {
            errorMessage = "Betting phase closed. Please wait for the next round.";
          } else if (e is FirebaseFunctionsException) {
            errorMessage = e.message ?? errorMessage;
          } else {
            errorMessage = "Error: ${errorStr.split('\\n').first}";
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    }
  }

  void _startSpin(Map<String, dynamic> outcome) {
    if (!mounted) return;

    _tickTimer?.cancel();
    _idleController.stop();
    _idleController.reset();

    setState(() {
      _isSpinning = true;
      _isBetLocked = true;
      _gameState = SpinGameState.spinning;
    });

    final settings = ref.read(gameSettingsProvider).value;
    final segmentsMap = (settings?['segments'] as List? ?? []);

    final prize = (outcome['prize'] as num?)?.toInt() ?? 0;
    final label = outcome['label'] as String? ?? "0x";
    final type = outcome['type'] as String? ?? "standard";
    _lastResultType = type;

    final int serverSectorIndex = (outcome['sectorIndex'] as num?)?.toInt() ?? 0;
    final int targetIdx = serverSectorIndex;
    final int startIdx = _currentSegment;
    
    // Calculate dynamic deceleration to finish exactly before results phase
    final now = _synchronizedTimeMs;
    const serverRoundMs = 40000;
    final outcomeRoundId = outcome['roundId']?.toString();
    final _currentRoundId = (now ~/ serverRoundMs).toString();
    final msIntoCycle = now % serverRoundMs;

    double targetSpinDuration;
    if (outcomeRoundId != null && outcomeRoundId != _currentRoundId) {
      // Outcome is for a past round, spin quickly
      targetSpinDuration = 600.0;
    } else if (msIntoCycle >= 35000) {
      // Past the spin phase of the current round, spin quickly
      targetSpinDuration = 600.0;
    } else {
      // Normal case: finish exactly at the end of the spin phase
      targetSpinDuration = (35000 - msIntoCycle).toDouble().clamp(600.0, 5000.0);
    }
    
    int distanceToTarget = (targetIdx - startIdx + 8) % 8;
    int fullRotations = (targetSpinDuration ~/ 1200).clamp(1, 4); 
    final int totalTicks = distanceToTarget + (fullRotations * 8);

    _tickDurations = [];
    double sumSquares = 0;
    for (int i = 0; i < totalTicks; i++) {
      sumSquares += (i / totalTicks) * (i / totalTicks);
    }
    
    double baseA = 50.0; // minimum tick duration
    double baseB = (targetSpinDuration - totalTicks * baseA) / (sumSquares == 0 ? 1 : sumSquares);
    if (baseB < 0) { 
      baseB = 0; 
      baseA = targetSpinDuration / totalTicks; 
    }
    
    for (int i = 0; i < totalTicks; i++) {
      double progress = i / totalTicks;
      _tickDurations.add(baseA + baseB * progress * progress);
    }
    
    _tickFireTimes = [];
    double acc = 0;
    for (double d in _tickDurations) {
      _tickFireTimes.add(acc);
      acc += d;
    }
    
    _tickCurrentIndex = startIdx;
    _currentTickIndex = 0;
    _tickTargetIndex = targetIdx;
    
    final DateTime startTime = DateTime.now();
    
    void tickStep() {
      if (!mounted || !_isSpinning) {
        _tickTimer?.cancel();
        return;
      }
      
      final elapsedMs = (DateTime.now().difference(startTime).inMicroseconds / 1000.0);
      
      while (_currentTickIndex < _tickFireTimes.length && 
             _tickFireTimes[_currentTickIndex] <= elapsedMs) {
        
        _tickCurrentIndex = (_tickCurrentIndex + 1) % 8;
        
        setState(() {
          _currentSegment = _tickCurrentIndex;
        });
        
        // HapticFeedback.lightImpact();
        
        _currentTickIndex++;
      }
      
      if (_currentTickIndex >= _tickFireTimes.length) {
        _tickTimer?.cancel();

        final totalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
        final betsCopy = Map<String, int>.from(_currentBets);

        final resultName = outcome['name'] as String? ?? "";
        final resultEmoji = outcome['emoji'] as String? ?? "";
        final resultCategory = outcome['category'] as String?;

        final matchingSegment = segmentsMap.firstWhere(
          (s) => s['name']?.toString().toLowerCase().trim() == resultName.toLowerCase().trim(),
          orElse: () => segmentsMap[targetIdx],
        );

        final winningItem = SpinItem(
          name: matchingSegment['name'] ?? resultName,
          multiplier: totalBet > 0 ? (prize / totalBet).round() : 0,
          emoji: resultEmoji.isNotEmpty ? resultEmoji : (matchingSegment['emoji'] ?? ''),
          category: resultCategory ?? matchingSegment['category']
        );

        final roundWinners = outcome['todayWinners'] as List? ?? outcome['roundWinners'] as List? ?? [];
        final roundId = outcome['roundId']?.toString() ?? "";

        setState(() {
          _spinCompleted = true;
          _currentSegment = targetIdx;
          if (totalBet > 0) {
            _todayProfits += (prize - totalBet);
          }
          _isSpinning = false;
          _currentBets = {};
          _betClickCounts = {};
          _storedWinItem = winningItem;
          _storedPrize = prize;
          _storedWager = totalBet;
          _storedWinners = roundWinners;
          _storedRoundId = roundId;
          _storedBets = betsCopy;
          _resultLock = true;
        });

        _playPhaseSound(SpinGameState.results);

        ref.invalidate(walletBalanceProvider);
        ref.invalidate(userGameHistoryProvider);
        ref.invalidate(luckySpinStatsProvider);

        // Show immediately since the spin animation has finished
        if (_hasShownResultForRound != roundId) {
          _hasShownResultForRound = roundId;
          _showStoredResult();
        }
        return;
      }
    }
    
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 16), (_) => tickStep());
  }

  void _buildTickDurations(int totalTicks, double slowdownFactor, int baseDuration) {
    _tickDurations = [];
    
    int accelerationTicks = (totalTicks * 0.25).round();
    int constantTicks = (totalTicks * 0.30).round();
    int decelerationTicks = (totalTicks * 0.30).round();
    int settlingTicks = totalTicks - accelerationTicks - constantTicks - decelerationTicks;
    
    double baseTickMs = baseDuration / totalTicks;
    
    double minTickMs = baseTickMs * 0.15;
    double maxTickMs = baseTickMs * 2.5;
    
    for (int i = 0; i < totalTicks; i++) {
      double progress = i / totalTicks;
      double duration;
      
      if (i < accelerationTicks) {
        double accelProgress = i / accelerationTicks;
        duration = maxTickMs - (maxTickMs - minTickMs * 2) * accelProgress;
      } else if (i < accelerationTicks + constantTicks) {
        duration = minTickMs * 2;
      } else if (i < accelerationTicks + constantTicks + decelerationTicks) {
        double decelProgress = (i - accelerationTicks - constantTicks) / decelerationTicks;
        duration = (minTickMs * 2) + ((maxTickMs * slowdownFactor) - (minTickMs * 2)) * decelProgress;
      } else {
        double settleProgress = (i - accelerationTicks - constantTicks - decelerationTicks) / settlingTicks;
        duration = maxTickMs * slowdownFactor * (1 + settleProgress * 2);
      }
      
      _tickDurations.add(duration.clamp(minTickMs, maxTickMs * 1.5));
    }
  }

  void _showStoredResult() {
    if (_storedWinItem != null && mounted) {
      final item = _storedWinItem!;
      final prize = _storedPrize;
      final wager = _storedWager;
      final winners = _storedWinners;
      final roundId = _storedRoundId;
      final bets = _storedBets;
      _clearStoredResult();
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
    _storedWinItem = null;
    _storedPrize = 0;
    _storedWager = 0;
    _storedWinners = [];
    _storedRoundId = '';
    _storedBets = null;
  }

  void _showResultBottomSheet(BuildContext context, SpinItem item, int winnings, int wager, List<dynamic> winners, String roundId, {Map<String, int>? bets}) {
    if (!mounted) return;

    // Dismiss any currently open result sheet safely using removeRoute to avoid double-pop crashes
    if (_isBottomSheetOpen && _bottomSheetRoute != null) {
      _isBottomSheetOpen = false;
      final route = _bottomSheetRoute;
      _bottomSheetRoute = null;
      _bottomSheetContext = null;
      try {
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      } catch (e) {
        debugPrint("⚠️ SpinWheel: Error removing bottom sheet: $e");
      }
    }

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
          return _ResultBottomSheet(
            item: item,
            winnings: winnings,
            wager: wager,
            winners: winners,
            roundId: roundId,
            bets: bets,
          );
        },
      ).then((_) {
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
      context: context, backgroundColor: const Color(0xFF0F172A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
    WidgetsBinding.instance.removeObserver(this);
    WakelockService().release();
    _offsetSubscription?.cancel();
    _connectivitySub?.cancel();
    _platformConnectivitySub?.cancel();
    _debounceTimer?.cancel();
    _timer?.cancel();
    _tickTimer?.cancel();
    _idleController.dispose();
    _audioPlayer.dispose();
    _effectPlayer.dispose();
    GameRecoveryService().clearBetState();
    super.dispose();
  }

  void _updateOfflineState({bool? rtdbConnected, bool? platformOnline}) {
    if (rtdbConnected != null) _rtdbConnected = rtdbConnected;
    if (platformOnline != null) _platformHasNetwork = platformOnline;

    final effectiveRtdb = _rtdbConnected ?? true;
    final effectivePlatform = _platformHasNetwork;

    // Only show offline when BOTH Firebase RTDB AND platform say disconnected
    final wasOffline = _isOffline;
    _isOffline = !effectiveRtdb && !effectivePlatform;

    if (_isOffline != wasOffline) {
      debugPrint('[SPIN_WHEEL] Offline state changed: $_isOffline '
          '(rtdb=$effectiveRtdb, platform=$effectivePlatform)');
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final settingsAsync = ref.watch(gameSettingsProvider);
    final statsAsync = ref.watch(luckySpinStatsProvider);
    final historyAsync = ref.watch(userGameHistoryProvider);

    return Scaffold(
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
              final scale = constraints.maxWidth / 375;
              
              return Stack(
                children: [
              // 1. Background Image
               Positioned.fill(
                child: Image.asset(
                  'assets/images/processed_image.webp',
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFFDE047)),
                ),
              ),

              // 2. Header Elements
              _buildHeader(settings, _calculateCurrentRound(), scale, statsAsync.value),

              // 3. Main Circular Game
              Align(
                alignment: const Alignment(0, -0.55),
                child: SizedBox(
                  width: 360 * scale, height: 420 * scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 360 * scale, height: 420 * scale,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              size: Size(360 * scale, 420 * scale), 
                              painter: PodsPainter(
                                items: items, 
                                activeIndex: _currentSegment, 
                                betClickCounts: _betClickCounts,
                                scale: scale,
                                saladHits: statsAsync.value?['todaySaladHits'] ?? 0,
                                pizzaHits: statsAsync.value?['todayPizzaHits'] ?? 0,
                              ),
                            ),
                            
                            // Salad & Pizza Buttons (Positioned lower with negative offset)
                            Positioned(
                              bottom: -29 * scale,
                              left: 30 * scale,
                              child: GestureDetector(
                                onTap: _isBetLocked ? null : () => _placeBet("Salad", items),
                                child: _buildJackpotTab("Salad", "🥗", scale, _currentBets[saladItem.name] ?? 0),
                              ),
                            ),
                            Positioned(
                              bottom: -29 * scale,
                              right: 30 * scale,
                              child: GestureDetector(
                                onTap: _isBetLocked ? null : () => _placeBet("Pizza", items),
                                child: _buildJackpotTab("Pizza", "🍕", scale, _currentBets[pizzaItem.name] ?? 0),
                              ),
                            ),
                            
                            // Interactive Betting Pods (Shifted center to 180, 210)
                            ...List.generate(items.length, (index) {
                              final angle = index * (2 * math.pi / 8) - (math.pi / 2);
                              const radiusX = 135.0;
                              const radiusY = 156.0;
                              final podX = math.cos(angle) * radiusX * scale;
                              final podY = math.sin(angle) * radiusY * scale;
                              final name = items[index].name;
                              final bet = _currentBets[name] ?? 0;

                              return Positioned(
                                left: (180 * scale) + podX - (35 * scale),
                                top: (210 * scale) + podY - (40 * scale),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _isBetLocked ? null : () => _placeBet(name, items),
                                  child: Container(
                                    width: 70 * scale, height: 80 * scale,
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
                                                  padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                                                  decoration: BoxDecoration(
                                                    color: _confirmedBets[name] == bet ? Colors.green : Colors.amber,
                                                    borderRadius: BorderRadius.circular(10 * scale),
                                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        bet >= 1000 ? "${(bet/1000).toStringAsFixed(1)}k" : bet.toString(),
                                                        style: TextStyle(color: Colors.black, fontSize: 10 * scale, fontWeight: FontWeight.w900),
                                                      ),
                                                      if (_confirmedBets[name] == bet) ...[
                                                        SizedBox(width: 3 * scale),
                                                        Icon(Icons.check_circle, color: Colors.white, size: 12 * scale),
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
                                size: Size(360 * scale, 420 * scale), 
                                painter: GlowPointerPainter(activeIndex: _currentSegment, scale: scale)
                              ),
                            ),
                            Positioned(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // White Hub
                                  Container(
                                    width: 120 * scale, height: 120 * scale,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.transparent),
                                      boxShadow: const [],
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 25 * scale),
                                        child: Text("🐼", style: TextStyle(fontSize: 65 * scale)),
                                      ),
                                    ),
                                  ),
                                  // Select Time Banner
                                  Positioned(
                                    bottom: 0,
                                    child: Container(
                                      width: 90 * scale,
                                      padding: EdgeInsets.symmetric(vertical: 2 * scale),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(10 * scale),
                                        border: Border.all(color: Colors.transparent),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_countdownLabel, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9 * scale)),
                                            Text("${_countdown}s", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14 * scale)),
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

              // 4. Betting Section
              _buildBettingSection(settings, scale, statsAsync.value),

              if (_countdown <= 5 && !_isSpinning)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
                      child: const Text("BETS CLOSED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                    ),
                  ),
                ),

              Consumer(
                builder: (context, ref, child) {
                  final balance = ref.watch(walletBalanceProvider).value?['diamonds'] ?? 0;
                  final totalLocalBet = _currentBets.values.fold(0, (sum, val) => sum + val);
                  final displayedBalance = (balance - totalLocalBet).clamp(0, balance);

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
              
              if (_isOffline)
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
                            "Network Connection Required",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Please check your internet connection\nand try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: 40, left: 10,
                child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context)),
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
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 12, offset: const Offset(0, 4)),
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
    );
  }

  Widget _buildHeader(Map<String, dynamic> settings, int currentRound, double scale, Map<String, dynamic>? stats) {
    String? lastWinnerLabel;
    String? lastWinnerEmoji;
    if (stats != null && stats['lastGlobalOutcome'] != null) {
      final lastRoundStr = stats['lastGlobalRound']?.toString();
      if (lastRoundStr == null || _currentRoundId == null || lastRoundStr != _currentRoundId.toString()) {
        lastWinnerLabel = stats['lastGlobalOutcome']['label'];
        lastWinnerEmoji = stats['lastGlobalOutcome']['emoji'];
      }
    }

    return Positioned(
      top: 70 * scale, left: 20 * scale, right: 20 * scale,
      child: Column(
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
              padding: EdgeInsets.only(top: 8 * scale),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 4 * scale),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
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
      ),
    );
  }

  Widget _buildBettingSection(Map<String, dynamic> settings, double scale, Map<String, dynamic>? stats) {
    final segments = (settings['segments'] as List);
    final saladHits = stats?['todaySaladHits'] ?? 0;
    final pizzaHits = stats?['todayPizzaHits'] ?? 0;
    
    return Positioned(
      bottom: 197 * scale, left: 10 * scale, right: 10 * scale,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 13 * scale),
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10 * scale)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 14 * scale),
                SizedBox(width: 4 * scale),
                Text("7 = 2", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 12 * scale)),
              ],
            ),
          ),
          SizedBox(height: 12 * scale),
          // Chip Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChip(100, const Color(0xFFFFD700), scale),
              SizedBox(width: 28 * scale),
              _buildChip(1000, const Color(0xFFFFD700), scale),
              SizedBox(width: 30 * scale),
              _buildChip(10000, const Color(0xFFFFD700), scale),
              SizedBox(width: 29 * scale),
              _buildChip(100000, const Color(0xFFFFD700), scale),
            ],
          ),
        ],
      ),
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
    onTap: () => setState(() => _selectedChipValue = value),
    child: Container(
      width: 54 * scale, // Optimized width for 4 betting chips
      height: 54 * scale, // Optimized height
      decoration: BoxDecoration(
        color: isSelected ? Colors.red : color,
        borderRadius: BorderRadius.circular(10 * scale),
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
              Icon(Icons.stars, color: Colors.amber, size: 14 * scale),
            Text(
              value >= 1000 ? "${(value / 1000).floor()}k" : value.toString(),
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 11 * scale,
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

    final visibleHistory = history.where((rec) {
      final roundIdStr = rec['roundId']?.toString();
      if (roundIdStr != null && _currentRoundId != null && roundIdStr == _currentRoundId.toString()) {
        return false;
      }
      return true;
    }).toList();

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
                  final emoji = rec['emoji'] ?? '🎡';
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
      child: Container(
        height: 190 * scale,
        padding: EdgeInsets.only(top: 8 * scale, bottom: 8 * scale),
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
            GestureDetector(
              onTap: () => _showGameHistorySheet(),
              child: Text(
                "Catatan saya >",
                style: TextStyle(color: Colors.black87, fontSize: 11 * scale, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
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
          final leaderboard = ref.watch(luckySpinLeaderboardProvider).value ?? [];
          
          return Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("DAILY TOP PLAYERS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (leaderboard.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No top players yet today", style: TextStyle(color: Colors.white70)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: leaderboard.length,
                      itemBuilder: (context, index) {
                        final p = leaderboard[index];
                        final name = p['name'] ?? "Unknown";
                        final totalBets = (p['totalBets'] as num?)?.toInt() ?? 0;
                        final avatarUrl = p['avatar']?.toString() ?? "";
                        
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
                                    _formatNumber(totalBets),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Stack(
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
                const SizedBox(height: 20),
                
                Flexible(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final historyAsync = ref.watch(userGameHistoryProvider);
                      return historyAsync.when(
                        data: (history) {
                          if (history.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text("No game history found", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final h = history[index];
                              final betsMap = Map<String, dynamic>.from(h['bets'] ?? {});
                              final isWin = (h['prize'] ?? 0) > 0;
                              final stampColor = isWin ? const Color(0xFFF43F5E) : Colors.white30;
                              final stampText = isWin ? "WIN" : "LOSE";

                              final serialNo = h['serialNumber'] ?? (history.length - index);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "S/N: #$serialNo · Round: ${_getRelativeRoundNumber(h['roundId'])}",
                                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(_formatTimestamp(h['timestamp']), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        
                                        const Text("Selected food:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8, runSpacing: 6,
                                          children: betsMap.entries.map((entry) {
                                            final emoji = _getFoodEmoji(entry.key);
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.35),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(emoji, style: const TextStyle(fontSize: 14)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "${entry.value}",
                                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 14),

                                        Row(
                                          children: [
                                            const Text("Winning food: ", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                            Text(h['emoji'] ?? _getFoodEmoji(h['label'] ?? h['resultType'] ?? ''), style: const TextStyle(fontSize: 15)),
                                            const SizedBox(width: 6),
                                            Text(
                                              (h['label'] != null && !h['label'].toString().contains('x'))
                                                  ? h['label'].toString().toUpperCase()
                                                  : _getFoodNameFromEmoji(h['emoji'] ?? _getFoodEmoji(h['label'] ?? h['resultType'] ?? '')),
                                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        Row(
                                          children: [
                                            const Text("Win coins: ", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                            const PremiumDiamond(size: 13),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                "${h['prize'] ?? 0}",
                                                style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        if (h['balanceBefore'] != null && h['balanceAfter'] != null) ...[
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.only(right: 85),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    "Coin Balance: ${_formatBalance(h['balanceBefore'])} -> ${_formatBalance(h['balanceAfter'])}",
                                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const PremiumDiamond(size: 12),
                                              ],
                                            ),
                                          ),
                                        ],

                                        if (h['orderId'] != null) ...[
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.only(right: 85),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    "Order Id: ${h['orderId']}",
                                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () {
                                                    Clipboard.setData(ClipboardData(text: h['orderId'].toString()));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text("Order ID copied to clipboard"),
                                                        duration: Duration(seconds: 2),
                                                      ),
                                                    );
                                                  },
                                                  child: const Icon(
                                                    Icons.copy,
                                                    color: Colors.white54,
                                                    size: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    
                                    Positioned(
                                      bottom: 0, right: 0,
                                      child: Transform.rotate(
                                        angle: -0.15,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: stampColor, width: 2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "★ ★ ★",
                                                style: TextStyle(color: stampColor, fontSize: 6, letterSpacing: 1),
                                              ),
                                              Text(
                                                stampText,
                                                style: TextStyle(
                                                  color: stampColor,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
                        error: (err, _) => Center(child: Text("Error loading records: $err", style: const TextStyle(color: Colors.white70))),
                      );
                    },
                  ),
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
      ),
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

  Widget _buildFooterText() {
    return const SizedBox.shrink();
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

class SpinItem {
  final String name; final int multiplier; final String emoji; final String? category;
  SpinItem({required this.name, required this.multiplier, required this.emoji, this.category});
}

class PodsPainter extends CustomPainter {
  final List<SpinItem> items; final int activeIndex; final double scale;
  final int saladHits; final int pizzaHits;
  final Map<String, int> betClickCounts;
  PodsPainter({required this.items, required this.activeIndex, required this.betClickCounts, this.scale = 1.0, this.saladHits = 0, this.pizzaHits = 0});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radiusX = 135.0 * scale;
    final radiusY = 155.0 * scale;
    for (int i = 0; i < items.length; i++) {
        final angle = i * (2 * math.pi / 8) - (math.pi / 2);
        final podCenter = Offset(center.dx + math.cos(angle) * radiusX, center.dy + math.sin(angle) * radiusY);
        
        // 1. Transparent Pod (No Border)
        final podPaint = Paint()
          ..color = Colors.transparent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(podCenter, 70 * scale, podPaint);

        // 2. Pulse Highlight for Winning Segment
        if (i == activeIndex) {
          final pulsePaint = Paint()
            ..color = Colors.amber.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * scale
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale);
          canvas.drawCircle(podCenter, 65 * scale, pulsePaint);
          
          final glowPaint = Paint()
            ..color = Colors.white.withOpacity(0.15)
            ..style = PaintingStyle.fill
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * scale);
          canvas.drawCircle(podCenter, 60 * scale, glowPaint);
        }

        // 4. Draw Emoji (Top)
        final emojiPainter = TextPainter(text: TextSpan(text: items[i].emoji, style: TextStyle(fontSize: 32 * scale)), textDirection: TextDirection.ltr)..layout();
        emojiPainter.paint(canvas, podCenter - Offset(emojiPainter.width / 2, 25 * scale));

        // 5. Draw Win Label (Bottom)
        final labelPainter = TextPainter(
          text: TextSpan(
            text: "win ${items[i].multiplier} times", 
            style: TextStyle(
              color: i == activeIndex ? Colors.amber : Colors.black, 
              fontSize: 9 * scale, 
              fontWeight: FontWeight.w900,
              shadows: i == activeIndex ? [const Shadow(color: Colors.black26, blurRadius: 4)] : null
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
  final int activeIndex;
  final double scale;
  GlowPointerPainter({required this.activeIndex, this.scale = 1.0});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); 
    final radiusX = 130.0 * scale;
    final radiusY = 148.0 * scale;
    
    final double lightAngle = (activeIndex * (2 * math.pi / 8)) - (math.pi / 2);
    final lightPos = Offset(center.dx + math.cos(lightAngle) * radiusX, center.dy + math.sin(lightAngle) * radiusY);
    
    canvas.drawCircle(lightPos, 50 * scale, Paint()..color = const Color(0xFFFFD700).withOpacity(0.4)..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * scale));
    canvas.drawCircle(lightPos, 40 * scale, Paint()..color = Colors.white.withOpacity(0.6)..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale));
    canvas.drawCircle(lightPos, 4 * scale, Paint()..color = Colors.white);
  }
  @override bool shouldRepaint(covariant GlowPointerPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex || oldDelegate.scale != scale;
  }
}

class _ResultBottomSheet extends ConsumerStatefulWidget {
  final SpinItem item;
  final int winnings;
  final int wager;
  final List<dynamic> winners;
  final String? roundId;
  final Map<String, int>? bets;

  const _ResultBottomSheet({
    required this.item,
    required this.winnings,
    required this.wager,
    required this.winners,
    this.roundId,
    this.bets,
  });

  @override
  ConsumerState<_ResultBottomSheet> createState() => _ResultBottomSheetState();
}

class _ResultBottomSheetState extends ConsumerState<_ResultBottomSheet> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
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

    // Automatically close the bottom sheet after the results phase
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
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

                  // PODIUM ROW (Side-by-side Top 3 winners from backend data)
                  Consumer(
                    builder: (context, ref, child) {
                      final roundId = widget.roundId ?? '';
                      final liveWinners = ref.watch(luckySpinCurrentRoundWinnersProvider(roundId)).value ?? [];
                      final winnersList = liveWinners.isNotEmpty ? liveWinners : widget.winners;
                      if (winnersList.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              const Expanded(
                                child: CustomDashedDivider(color: Color(0xFFFFD700)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  "This round's biggest winner",
                                  style: TextStyle(
                                    color: const Color(0xFFFFD700).withOpacity(0.95),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: CustomDashedDivider(color: Color(0xFFFFD700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _buildWinnersPodium(liveWinners),
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnersPodium(List<dynamic> liveWinners) {
    final List<Widget> slots = [];
    final winnersList = liveWinners.isNotEmpty ? liveWinners : widget.winners;
    for (int i = 0; i < 3; i++) {
      final hasWinner = winnersList.length > i;
      final w = hasWinner ? winnersList[i] : null;
      slots.add(
        Expanded(
          child: _buildPodiumSlot(w, i),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: slots,
    );
  }

  Widget _buildPodiumSlot(dynamic winner, int index) {
    final rankColors = [
      const Color(0xFFFFD700), // Gold for Rank 1
      const Color(0xFFC0C0C0), // Silver for Rank 2
      const Color(0xFFCD7F32), // Bronze for Rank 3
    ];
    final rankBadgeLabel = "${index + 1}";

    final avatarUrl = winner != null ? (winner['avatar'] ?? winner['photoUrl'] ?? "").toString() : "";
    final name = winner != null ? (winner['name'] ?? winner['username'] ?? "User").toString() : "Empty";
    final amount = winner != null ? ((winner['winnings'] ?? winner['amount'] ?? 0) as num).toInt() : 0;

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
                border: Border.all(
                  color: rankColors[index],
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: rankColors[index].withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 23,
                backgroundColor: Colors.white10,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white38, size: 22) : null,
              ),
            ),
            Transform.translate(
              offset: const Offset(3, 3),
              child: Container(
                width: 15,
                height: 15,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  rankBadgeLabel,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumDiamond(size: 10.5),
            const SizedBox(width: 2.5),
            Text(
              _formatNumber(amount),
              style: TextStyle(
                color: rankColors[index],
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