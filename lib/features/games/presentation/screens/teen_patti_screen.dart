import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/services/game_service.dart';

class TeenPattiScreen extends ConsumerStatefulWidget {
  final String roomId;
  const TeenPattiScreen({super.key, required this.roomId});

  @override
  ConsumerState<TeenPattiScreen> createState() => _TeenPattiScreenState();
}

class _TeenPattiScreenState extends ConsumerState<TeenPattiScreen> {
  late final WebViewController _controller;
  final GameService _gameService = GameService();
  bool _isWebViewReady = false;
  String? _errorMessage;

  // In-memory static cache for base64 assets (0ms disk I/O on re-opens)
  static String? _cachedBgB64;
  static String? _cachedDealerB64;

  // Deduplication state to prevent redundant JSON bridge serialization
  String? _lastTableJson;
  String? _lastCardsJson;
  int? _lastBalance;

  @override
  void initState() {
    super.initState();
    // Edge-to-edge immersive full-screen display
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
      _controller.runJavaScript(
        'if (window.AudioEngine && window.AudioEngine.ctx) { try { window.AudioEngine.ctx.close(); } catch(e){} }',
      );
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
      ..setBackgroundColor(const Color(0xFF090514))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _isWebViewReady = true;
            if (mounted) {
              _sendInitialUserData();
              _syncCurrentTableState();
            }
          },
          onWebResourceError: (error) {
            debugPrint('[TeenPatti] WebView resource error: ${error.description}');
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
      String htmlContent = await rootBundle.loadString('assets/games/teen_patti.html');

      // Use cached base64 strings or load once into memory
      if (_cachedBgB64 == null) {
        try {
          final bytes = await rootBundle.load('assets/games/teen_patti_bg.jpg');
          _cachedBgB64 = base64Encode(bytes.buffer.asUint8List());
        } catch (_) {
          _cachedBgB64 = '';
        }
      }
      if (_cachedDealerB64 == null) {
        try {
          final bytes = await rootBundle.load('assets/games/teen_patti_dealer.png');
          _cachedDealerB64 = base64Encode(bytes.buffer.asUint8List());
        } catch (_) {
          _cachedDealerB64 = '';
        }
      }
      htmlContent = htmlContent.replaceAll(
        '{{BG_IMAGE_DATA}}',
        _cachedBgB64!.isNotEmpty ? 'data:image/jpeg;base64,$_cachedBgB64' : '',
      );
      htmlContent = htmlContent.replaceAll(
        '{{DEALER_IMAGE_DATA}}',
        _cachedDealerB64!.isNotEmpty ? 'data:image/png;base64,$_cachedDealerB64' : '',
      );

      await _controller.loadHtmlString(htmlContent, baseUrl: 'about:blank');
    } catch (e) {
      debugPrint('[TeenPatti] loadHtmlString error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load Teen Patti game assets.';
        });
      }
    }
  }

  void _sendInitialUserData() {
    if (!mounted || !_isWebViewReady) return;
    try {
      final user = _getProfile();
      final data = {
        'uid': user?.uid ?? '',
        'displayName': user?.displayName.isNotEmpty == true ? user!.displayName : 'Player',
        'avatarUrl': user?.profilePhotoUrl.isNotEmpty == true
            ? user!.profilePhotoUrl
            : 'https://api.dicebear.com/9.x/adventurer/svg?seed=${user?.uid ?? "Player"}',
        'diamondBalance': user?.diamondBalance ?? 0,
      };
      final jsonStr = jsonEncode(data);
      _controller.runJavaScript('if (window.initUserData) window.initUserData($jsonStr);');
    } catch (e) {
      debugPrint('[TeenPatti] Error sending initial user data: $e');
    }
  }

  void _syncCurrentTableState() {
    if (!mounted || !_isWebViewReady) return;
    try {
      final tableAsync = ref.read(teenPattiTableProvider(widget.roomId));
      tableAsync.whenData((tableData) {
        if (tableData != null) {
          final jsonStr = jsonEncode(tableData);
          _lastTableJson = jsonStr;
          _controller.runJavaScript('if (window.updateTableState) window.updateTableState($jsonStr);');
        }
      });
    } catch (e) {
      debugPrint('[TeenPatti] Error syncing table state: $e');
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
          _syncCurrentTableState();
          break;

        case 'haptic':
          final String type = data['type'] ?? 'light';
          switch (type) {
            case 'selection':
              HapticFeedback.selectionClick();
              break;
            case 'medium':
              HapticFeedback.mediumImpact();
              break;
            case 'heavy':
              HapticFeedback.heavyImpact();
              break;
            case 'vibrate':
              HapticFeedback.vibrate();
              break;
            case 'light':
            default:
              HapticFeedback.lightImpact();
              break;
          }
          break;

        case 'sit':
          final int seatIndex = (data['seat'] as num?)?.toInt() ?? 0;
          try {
            HapticFeedback.mediumImpact();
            await _gameService.joinTeenPattiSeat(roomId: widget.roomId, seatIndex: seatIndex);
          } catch (e) {
            _dispatchErrorToGame('Failed to sit: $e');
          }
          break;

        case 'leave':
          try {
            HapticFeedback.lightImpact();
            await _gameService.leaveTeenPattiSeat(roomId: widget.roomId);
          } catch (e) {
            _dispatchErrorToGame('Failed to leave: $e');
          }
          break;

        case 'start_round':
          try {
            HapticFeedback.heavyImpact();
            await _gameService.startTeenPattiRound(roomId: widget.roomId);
          } catch (e) {
            _dispatchErrorToGame('$e');
          }
          break;

        case 'see':
        case 'chaal':
        case 'raise':
        case 'fold':
        case 'show':
          final int? amount = (data['amount'] as num?)?.toInt();
          try {
            if (action == 'show') {
              HapticFeedback.heavyImpact();
            } else if (action == 'raise') {
              HapticFeedback.mediumImpact();
            } else {
              HapticFeedback.lightImpact();
            }
            await _gameService.sendTeenPattiAction(
              roomId: widget.roomId,
              action: action,
              amount: amount,
            );
          } catch (e) {
            _dispatchErrorToGame('$e');
          }
          break;

        case 'close':
          HapticFeedback.lightImpact();
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          break;

        default:
          debugPrint('[TeenPatti] Unknown JS message action: $action');
      }
    } catch (e) {
      debugPrint('[TeenPatti] Error handling JS message: $e');
    }
  }

  void _dispatchErrorToGame(String message) {
    if (!mounted || !_isWebViewReady) return;
    final sanitized = message.replaceAll("'", "\\'").replaceAll('"', '\\"');
    _controller.runJavaScript('if (window.clearActionPending) window.clearActionPending(); if (window.onActionError) window.onActionError("$sanitized");');
  }

  @override
  Widget build(BuildContext context) {
    // Zero-Rebuild State Listening: Only bridge to JS when state actually changes
    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider, (prev, next) {
      final user = next.value;
      if (_isWebViewReady && user != null) {
        final bal = user.diamondBalance;
        if (bal != _lastBalance) {
          _lastBalance = bal;
          _controller.runJavaScript('if (window.updateUserBalance) window.updateUserBalance($bal);');
        }
      }
    });

    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      teenPattiTableProvider(widget.roomId),
      (prev, next) {
        final tableData = next.value;
        if (_isWebViewReady && tableData != null) {
          final jsonStr = jsonEncode(tableData);
          if (jsonStr != _lastTableJson) {
            _lastTableJson = jsonStr;
            _controller.runJavaScript('if (window.updateTableState) window.updateTableState($jsonStr);');
          }
        }
      },
    );

    final uid = ref.watch(currentUserProfileProvider).value?.uid;
    if (uid != null && uid.isNotEmpty) {
      ref.listen<AsyncValue<List<dynamic>>>(
        myTeenPattiCardsProvider((roomId: widget.roomId, uid: uid)),
        (prev, next) {
          final cards = next.value;
          if (_isWebViewReady && cards != null && cards.isNotEmpty) {
            final jsonStr = jsonEncode(cards);
            if (jsonStr != _lastCardsJson) {
              _lastCardsJson = jsonStr;
              _controller.runJavaScript('if (window.updateMyCards) window.updateMyCards($jsonStr);');
            }
          }
        },
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF090514),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                    _initWebView();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090514),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            RepaintBoundary(
              child: WebViewWidget(controller: _controller),
            ),
            // Premium Casino Loading Screen while WebView initialises
            IgnorePointer(
              ignoring: _isWebViewReady,
              child: AnimatedOpacity(
                opacity: _isWebViewReady ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.0, -0.2),
                      radius: 1.0,
                      colors: [
                        Color(0xFF27144D),
                        Color(0xFF120924),
                        Color(0xFF090514),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFEF08A), Color(0xFFF59E0B), Color(0xFFB45309)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '♠️',
                              style: TextStyle(fontSize: 42),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'TEEN PATTI ROYALE',
                          style: TextStyle(
                            color: Color(0xFFFEF08A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Connecting to live room table...',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

