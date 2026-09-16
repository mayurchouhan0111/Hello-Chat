import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/game_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/utils/app_persistent_cache.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/network_connectivity_service.dart';
import 'dart:async';

class LuckyDrawScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LuckyDrawScreen({super.key, required this.roomId});

  @override
  ConsumerState<LuckyDrawScreen> createState() => _LuckyDrawScreenState();
}

class _LuckyDrawScreenState extends ConsumerState<LuckyDrawScreen>
    with TickerProviderStateMixin {
  int _selectedTickets = 1;
  final List<int> _ticketOptions = [1, 5, 10, 50];
  bool _isDrawing = false;
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySub;
  double _prizePool = 1250450;
  
  // For sphere animation
  late AnimationController _sphereController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _localSoundPaths = {};

  @override
  void initState() {
    super.initState();
    _isOffline = !NetworkConnectivityService().isOnline;
    _connectivitySub = NetworkConnectivityService().onConnectivityChanged.listen((isOnline) {
      if (mounted) setState(() => _isOffline = !isOnline);
    });
    _sphereController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _precacheSounds();
  }

  void _precacheSounds() {}

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _sphereController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playSound(String url) {}

  void _play() async {
    if (_isDrawing) return;

    if (_isOffline || !NetworkConnectivityService().isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cannot play while offline. Please check your internet connection."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final balance = ref.read(currentUserProfileProvider).value?.diamondBalance ?? 0;
    final cost = _selectedTickets * 100;
    if (balance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient Diamonds")),
      );
      return;
    }

    setState(() => _isDrawing = true);
    // HapticFeedback.heavyImpact();

    // Play rolling suspense sound
    _playSound("https://assets.mixkit.co/active_storage/sfx/2021/2021-84.wav");

    try {
      // Simulate real draw delay for drama
      await Future.delayed(const Duration(seconds: 3));
      
      await ref.read(gameActionProvider.notifier).playLuckyDraw(_selectedTickets * 100);
      final result = ref.read(gameActionProvider).value;

      if (result == null) throw Exception("No result from server");

      if (mounted) {
        // Play result sound
        if (result.multiplier > 0) {
          _playSound("https://assets.mixkit.co/active_storage/sfx/2020/2020-84.wav"); // Win/Jackpot
        } else {
          _playSound("https://assets.mixkit.co/active_storage/sfx/2573/2573-84.wav"); // Loss/Consolation
        }

        _showResult(result);
        ref.invalidate(currentUserProfileProvider);
        setState(() => _isDrawing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDrawing = false);
        _audioPlayer.stop(); // Stop audio if error occurs
        
        String errorMessage = "An error occurred. Please try again.";
        final errorStr = e.toString();
        if (errorStr.contains('failed-precondition') || errorStr.contains('Betting phase closed')) {
          errorMessage = "Betting phase closed. Please wait for the next round.";
        } else {
          errorMessage = "Error: ${errorStr.split('\n').first}";
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
  }

  void _showResult(dynamic result) {
    bool dialogOpen = true;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        bool isWin = result.multiplier > 0;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isWin)
                  const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 120)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut)
                      .shimmer(delay: 600.ms)
                else
                  const Icon(Icons.sentiment_very_dissatisfied, color: Colors.white24, size: 100)
                      .animate()
                      .shake(),
                const Gap(24),
                Text(
                  isWin ? "JACKPOT HIT!" : "NEXT TIME...",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2
                  ),
                ),
                const Gap(8),
                Text(
                  isWin ? "You won ${result.prize} Diamonds" : "Every ticket is a new chance.",
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Gap(40),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)]),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text("CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      dialogOpen = false;
    });

    // Automatically close the dialog after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (dialogOpen && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final balance = userAsync.value?.diamondBalance ?? 0;
    final luckyDrawSettingsAsync = ref.watch(luckyDrawSettingsProvider);
    final livePrizePool = luckyDrawSettingsAsync.when(
      data: (settings) => (settings['currentPrizePool'] as num?)?.toDouble() ?? 1250450.0,
      loading: () => 1250450.0,
      error: (_, __) => 1250450.0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      body: Stack(
        children: [
          // Background energy vortex (animated spheres)
          ...List.generate(6, (index) {
            final random = math.Random(index);
            return Positioned(
              left: random.nextDouble() * MediaQuery.of(context).size.width,
              top: random.nextDouble() * MediaQuery.of(context).size.height * 0.6,
              child: AnimatedBuilder(
                animation: _sphereController,
                builder: (context, child) {
                  final offset = math.sin(_sphereController.value * 2 * math.pi + index) * 20;
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: Container(
                      width: 60 + random.nextDouble() * 40,
                      height: 60 + random.nextDouble() * 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF00E5FF).withOpacity(0.2),
                            const Color(0xFF00E5FF).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            context.go(AppRoutes.home);
                          }
                        },
                      ),
                      const Column(
                        children: [
                          Text("SQUARE", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 5)),
                          Text("LUCKY DRAW", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.diamond, color: Color(0xFFFFD700), size: 14),
                            const Gap(6),
                            Text("$balance", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Gap(20),

                // Prize Pool Counter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        const Text("TOTAL PRIZE POOL", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 3)),
                        const Gap(10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.diamond, color: Color(0xFFFFD700), size: 30),
                            const Gap(12),
                            Text(
                              livePrizePool.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 20)]
                              ),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().scale(),

                const Gap(40),

                // Live Draw Animation Area
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glass Container
                        Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2), width: 2),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.05), blurRadius: 40, spreadRadius: 10)
                            ]
                          ),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(color: Colors.white.withOpacity(0.02)),
                            ),
                          ),
                        ),
                        
                        // Floating Balls
                        ...List.generate(8, (i) {
                          return _buildFloatingBall(i);
                        }),
                        
                        if (_isDrawing)
                          const Text("DRAWING...", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2))
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 1.seconds)
                        else
                          const Icon(Icons.play_arrow_rounded, color: Colors.white24, size: 80),
                      ],
                    ),
                  ),
                ),

                // Footer Controls
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                    border: Border.all(color: Colors.white10)
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("PURCHASE TICKETS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          Text("1 TICKET = 100", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Gap(20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _ticketOptions.map((opt) => _buildTicketChip(opt)).toList(),
                      ),
                      const Gap(30),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: GestureDetector(
                          onTap: (!_isDrawing && !_isOffline) ? _play : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: (_isDrawing || _isOffline)
                                  ? [Colors.grey.shade800, Colors.grey.shade900]
                                  : [const Color(0xFF00E5FF), const Color(0xFF00B8D4)]
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: (_isDrawing || _isOffline) ? [] : [
                                BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 15)
                              ]
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isOffline) ...[
                                  const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 20),
                                  const Gap(8),
                                ],
                                Text(
                                  _isOffline
                                      ? "NO INTERNET CONNECTION"
                                      : (_isDrawing ? "DRAWING IN PROGRESS..." : "CONFIRM DRAW"),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildFloatingBall(int index) {
    final random = math.Random(index);
    return Positioned(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)]),
          boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 10)]
        ),
        child: Text("${random.nextInt(99)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      )
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .move(
        begin: Offset(random.nextDouble() * 100 - 50, random.nextDouble() * 100 - 50),
        end: Offset(random.nextDouble() * 100 - 50, random.nextDouble() * 100 - 50),
        duration: (2000 + random.nextInt(2000)).ms,
        curve: Curves.easeInOut
      ),
    );
  }

  Widget _buildTicketChip(int count) {
    bool isSelected = _selectedTickets == count;
    return GestureDetector(
      onTap: (_isDrawing || _isOffline) ? null : () {
        // HapticFeedback.selectionClick();
        _playSound("https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav");
        setState(() => _selectedTickets = count);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected 
              ? (_isOffline ? Colors.grey.shade700 : const Color(0xFF00E5FF))
              : ((_isDrawing || _isOffline) ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected 
                ? Colors.white38 
                : ((_isDrawing || _isOffline) ? Colors.white.withOpacity(0.02) : Colors.white10),
          ),
        ),
        child: Text(
          "x$count",
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : ((_isDrawing || _isOffline) ? Colors.white24 : Colors.white54),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}