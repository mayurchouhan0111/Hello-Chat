import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/game_service.dart';
import '../../../../core/services/network_connectivity_service.dart';

class YummyBingoScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const YummyBingoScreen({super.key, this.roomId});

  @override
  ConsumerState<YummyBingoScreen> createState() => _YummyBingoScreenState();
}

class _YummyBingoScreenState extends ConsumerState<YummyBingoScreen> {
  late final WebViewController _controller;
  final GameService _gameService = GameService();
  bool _cloudFunctionDisabled = false;
  String? _errorMessage;

  static final List<String> _weightedPool = [
    'wild',
    'dice', 'dice', 'dice',
    'burger', 'burger', 'burger', 'burger',
    'fries', 'fries', 'fries', 'fries', 'fries',
    'cake', 'cake', 'cake', 'cake', 'cake', 'cake',
    'banana', 'banana', 'banana', 'banana', 'banana', 'banana', 'banana',
    'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon', 'lemon',
    'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry', 'cherry',
    'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover', 'clover',
  ];

  static const Map<String, Map<int, int>> _yummySymbols = {
    'wild':   { 3: 50, 4: 200, 5: 1000 },
    'dice':   { 3: 40, 4: 150, 5: 600 },
    'burger': { 3: 20, 4: 80,  5: 300 },
    'fries':  { 3: 15, 4: 60,  5: 250 },
    'cake':   { 3: 12, 4: 50,  5: 200 },
    'banana': { 3: 10, 4: 40,  5: 150 },
    'lemon':  { 3: 8,  4: 30,  5: 100 },
    'cherry': { 3: 5,  4: 20,  5: 80 },
    'clover': { 3: 5,  4: 15,  5: 50 },
  };

  static const List<List<int>> _paylines = [
    [1, 1, 1, 1, 1], // Center row
    [0, 0, 0, 0, 0], // Top row
    [2, 2, 2, 2, 2], // Bottom row
    [0, 1, 2, 1, 0], // V-shape
    [2, 1, 0, 1, 2], // Inverted-V
    [0, 0, 1, 2, 2], // Zig-zag top
    [2, 2, 1, 0, 0], // Zig-zag bot
    [1, 0, 0, 0, 1], // High crest
    [1, 2, 2, 2, 1], // Low valley
  ];

  @override
  void initState() {
    super.initState();
    // Edge-to-edge transparent system bars for immersive gameplay
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    _initWebView();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    try {
      _controller.runJavaScript('if (window.audio && window.audio.ctx) { try { window.audio.ctx.close(); } catch(e){} }');
    } catch (_) {}
    super.dispose();
  }

  UserModel? _getProfile() {
    try {
      return mounted ? ref.read(currentUserProfileProvider).value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              _sendInitialUserData();
            }
          },
          onWebResourceError: (error) {
            debugPrint('[YummyBingo] WebView resource error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterApp',
        onMessageReceived: _handleJavaScriptMessage,
      );

    // Android-specific performance tuning: unlock autoplay and hardware rendering
    if (_controller.platform is AndroidWebViewController) {
      final android = _controller.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
    }

    try {
      String htmlContent = await rootBundle.loadString('assets/games/yummy_bingo.html');
      htmlContent = htmlContent.replaceAll('{{BG_IMAGE_DATA}}', '');
      await _controller.loadHtmlString(htmlContent, baseUrl: 'about:blank');
    } catch (e) {
      debugPrint('[YummyBingo] loadHtmlString error: $e, falling back to asset');
      try {
        await _controller.loadFlutterAsset('assets/games/yummy_bingo.html');
      } catch (err) {
        debugPrint('[YummyBingo] Error loading game asset: $err');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load game assets. Please try again.';
          });
        }
      }
    }
  }

  void _sendInitialUserData() {
    if (!mounted) return;
    try {
      final user = _getProfile();
      final balance = user?.diamondBalance ?? 0;
      final level = user?.level ?? 1;
      final xp = user?.xp ?? 0;
      final vipTier = user?.vipTier ?? 'VIP';
      final displayName = user?.displayName.isNotEmpty == true ? user!.displayName : 'Player';

      // Send initial data immediately without waiting for network
      final data = {
        'balance': balance,
        'jackpot': 276619,
        'vipData': {
          'tier': vipTier.isNotEmpty ? vipTier : 'VIP',
          'level': level,
          'xp': xp,
          'nextMilestone': (level + 1) * 5000,
          'title': displayName,
        },
      };

      final jsonStr = jsonEncode(data);
      _controller.runJavaScript('if (window.initUserData) window.initUserData($jsonStr);');

      // Asynchronously fetch latest jackpot from Firestore in background
      FirebaseFirestore.instance.collection('games_meta').doc('yummy_bingo').get().then((doc) {
        if (mounted && doc.exists && doc.data() != null) {
          final jp = (doc.data()!['jackpot'] as num?)?.toInt();
          if (jp != null) {
            _controller.runJavaScript('if (window.initUserData) window.initUserData({"jackpot": $jp});');
          }
        }
      }).catchError((_) {});
    } catch (e) {
      debugPrint('[YummyBingo] Error sending initial user data: $e');
    }
  }

  Future<void> _handleJavaScriptMessage(JavaScriptMessage message) async {
    if (!mounted) return;
    try {
      final Map<String, dynamic> data = jsonDecode(message.message);
      final String action = data['action'] ?? '';

      switch (action) {
        case 'ready':
          _sendInitialUserData();
          break;

        case 'spin':
          await _handleServerSpin(data);
          break;

        case 'claim_free_coins':
          await _handleClaimFreeCoins();
          break;

        case 'recharge':
          if (mounted) {
            context.push(AppRoutes.wallet);
          }
          break;

        case 'menu':
        case 'close':
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          break;

        case 'tab_navigate':
          final tab = data['tab'] as String?;
          if (mounted) {
            if (tab == 'home') {
              if (Navigator.canPop(context)) Navigator.pop(context);
            } else if (tab == 'leaderboard') {
              context.push(AppRoutes.leaderboard);
            } else if (tab == 'rewards') {
              await _handleClaimFreeCoins();
            }
          }
          break;

        case 'sync_balance':
          final balance = _getProfile()?.diamondBalance ?? 0;
          if (mounted) {
            await _controller.runJavaScript('if (window.updateUserBalance) window.updateUserBalance($balance);');
          }
          break;

        default:
          debugPrint('[YummyBingo] Unknown bridge action: $action');
      }
    } catch (e) {
      debugPrint('[YummyBingo] Error handling JS message: $e');
    }
  }

  Future<void> _handleClaimFreeCoins() async {
    final user = _getProfile();
    final int currentBalance = user?.diamondBalance ?? 0;
    final int newBalance = currentBalance + 10000;

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'diamondBalance': FieldValue.increment(10000),
        }).catchError((_) {});
      } catch (_) {}
    }

    if (mounted) {
      await _controller.runJavaScript('if (window.updateUserBalance) window.updateUserBalance($newBalance);');
    }
  }

  Future<void> _handleServerSpin(Map<String, dynamic> data) async {
    if (!mounted) return;
    final int lines = (data['lines'] as num?)?.toInt() ?? 2;
    final int betPerLine = (data['betPerLine'] as num?)?.toInt() ?? 2000;
    final int totalBet = lines * betPerLine;

    final currentBalance = _getProfile()?.diamondBalance ?? 0;
    if (currentBalance < totalBet) {
      // Instead of jarring error modal, notify the game to show a sleek recharge/claim prompt
      await _controller.runJavaScript('if (window.onInsufficientBalance) window.onInsufficientBalance($currentBalance, $totalBet);');
      return;
    }

    Map<String, dynamic>? result;
    if (!_cloudFunctionDisabled && NetworkConnectivityService().isOnline) {
      try {
        result = await _gameService.playYummyBingo(
          lines: lines,
          betPerLine: betPerLine,
          roomId: widget.roomId,
        ).timeout(const Duration(milliseconds: 800));
      } catch (e) {
        _cloudFunctionDisabled = true;
        debugPrint('[YummyBingo] Cloud function unavailable: $e. Switched to instant local engine.');
      }
    }

    // High performance local payline engine (sub-millisecond evaluation)
    result ??= _generateLocalSpinResult(
      lines: lines,
      betPerLine: betPerLine,
      currentBalance: currentBalance,
    );

    if (!mounted) return;
    final resultJson = jsonEncode(result);
    await _controller.runJavaScript('if (window.onServerSpinResult) window.onServerSpinResult($resultJson);');
  }

  Map<String, dynamic> _generateLocalSpinResult({
    required int lines,
    required int betPerLine,
    required int currentBalance,
  }) {
    final rng = math.Random();
    // 5 reels x 3 rows matrix
    final List<List<String>> matrix = [];
    for (int c = 0; c < 5; c++) {
      final List<String> col = [];
      for (int r = 0; r < 3; r++) {
        col.add(_weightedPool[rng.nextInt(_weightedPool.length)]);
      }
      matrix.add(col);
    }

    final activePaylines = _paylines.sublist(0, lines);
    final List<Map<String, dynamic>> winningLines = [];
    int totalWin = 0;

    for (int lIdx = 0; lIdx < activePaylines.length; lIdx++) {
      final lineCoords = activePaylines[lIdx];
      final symbolsOnLine = [
        matrix[0][lineCoords[0]],
        matrix[1][lineCoords[1]],
        matrix[2][lineCoords[2]],
        matrix[3][lineCoords[3]],
        matrix[4][lineCoords[4]],
      ];

      String first = symbolsOnLine[0];
      int matchCount = 1;
      final List<List<int>> pos = [[0, lineCoords[0]]];

      for (int i = 1; i < symbolsOnLine.length; i++) {
        final cur = symbolsOnLine[i];
        if (cur == first || cur == 'wild' || (first == 'wild' && cur != 'wild')) {
          if (first == 'wild' && cur != 'wild') first = cur;
          matchCount++;
          pos.add([i, lineCoords[i]]);
        } else {
          break;
        }
      }

      if (matchCount >= 3) {
        final mult = _yummySymbols[first]?[matchCount] ?? 0;
        final payout = mult * betPerLine;
        if (payout > 0) {
          totalWin += payout;
          winningLines.add({
            'line': {
              'id': lIdx + 1,
              'coords': lineCoords,
            },
            'symbol': first,
            'count': matchCount,
            'payout': payout,
            'positions': pos,
          });
        }
      }
    }

    final totalBet = lines * betPerLine;
    final netDelta = totalWin - totalBet;
    final newBalance = math.max(0, currentBalance + netDelta);

    // Atomically adjust diamonds in Firestore if user is signed in
    final user = _getProfile();
    if (user != null) {
      try {
        FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'diamondBalance': FieldValue.increment(netDelta),
        }).catchError((_) {});
      } catch (_) {}
    }

    return {
      'matrix': matrix,
      'winningLines': winningLines,
      'totalWin': totalWin,
      'totalBet': totalBet,
      'newBalance': newBalance,
      'jackpot': 276619 + rng.nextInt(60),
      'wonJackpot': false,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Listen to real-time profile diamond balance updates
    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider, (previous, next) {
      if (!mounted) return;
      final prevBalance = previous?.value?.diamondBalance;
      final nextBalance = next.value?.diamondBalance;
      if (nextBalance != null && nextBalance != prevBalance) {
        try {
          _controller.runJavaScript('if (window.updateUserBalance) window.updateUserBalance($nextBalance);');
        } catch (_) {}
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      body: Stack(
        children: [
          // 100% Fullscreen Game WebView without SafeArea restrictions
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _initWebView,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned.fill(
              child: RepaintBoundary(
                // Use default Texture Layer composition (TLHC) - zero thread hopping or BLASTBufferQueue contention
                child: WebViewWidget(controller: _controller),
              ),
            ),
        ],
      ),
    );
  }
}
