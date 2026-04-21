import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/game_provider.dart';
import '../../../../core/providers/profile_provider.dart';

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
  double _prizePool = 1250450;
  
  // For sphere animation
  late AnimationController _sphereController;

  @override
  void initState() {
    super.initState();
    _sphereController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _sphereController.dispose();
    super.dispose();
  }

  void _play() async {
    if (_isDrawing) return;

    setState(() => _isDrawing = true);
    HapticFeedback.heavyImpact();

    try {
      // Simulate real draw delay for drama
      await Future.delayed(const Duration(seconds: 3));
      
      await ref.read(gameActionProvider.notifier).playLuckyDraw(_selectedTickets * 100);
      final result = ref.read(gameActionProvider).value;

      if (result == null) throw Exception("No result from server");

      if (mounted) {
        _showResult(result);
        setState(() => _isDrawing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDrawing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showResult(dynamic result) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(currentUserProfileProvider).value?.diamondBalance ?? 0;

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
                        onPressed: () => Navigator.pop(context),
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
                              _prizePool.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
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
                          onTap: _isDrawing ? null : _play,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isDrawing 
                                  ? [Colors.grey.shade800, Colors.grey.shade900]
                                  : [const Color(0xFF00E5FF), const Color(0xFF00B8D4)]
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _isDrawing ? [] : [
                                BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 15)
                              ]
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _isDrawing ? "DRAWING IN PROGRESS..." : "CONFIRM DRAW",
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
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
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTickets = count);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.white38 : Colors.white10),
        ),
        child: Text(
          "x$count",
          style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}