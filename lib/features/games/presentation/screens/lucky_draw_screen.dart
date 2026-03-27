import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

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
  // ─── Bet state ────────────────────────────────────────────────────────────
  int _selectedBet = 100;
  final List<int> _betOptions = [100, 500, 1000, 5000];

  // ─── Game state ───────────────────────────────────────────────────────────
  bool _isPlaying = false;          // true after DRAW NOW tapped, until all revealed
  bool _resultReady = false;        // true once server responded
  List<bool> _revealed = [false, false, false];
  List<double> _multipliers = [0.0, 0.0, 0.0];
  int? _winIndex;

  // ─── Per-card flip controllers ────────────────────────────────────────────
  late List<AnimationController> _flipControllers;
  late List<Animation<double>> _flipAnimations;

  @override
  void initState() {
    super.initState();
    _flipControllers = List.generate(
      3,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _flipAnimations = _flipControllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: c, curve: Curves.easeInOutBack),
    ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _flipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Reset everything for a new round ────────────────────────────────────
  void _reset() {
    for (final c in _flipControllers) {
      c.reset();
    }
    setState(() {
      _isPlaying = false;
      _resultReady = false;
      _revealed = [false, false, false];
      _multipliers = [0.0, 0.0, 0.0];
      _winIndex = null;
    });
  }

  // ─── Fetch result from server ─────────────────────────────────────────────
  void _play() async {
    if (_isPlaying) return;

    _reset();
    await Future.microtask(() {}); // let reset settle

    setState(() => _isPlaying = true);
    HapticFeedback.heavyImpact();

    try {
      await ref.read(gameActionProvider.notifier).playLuckyDraw(_selectedBet);
      final result = ref.read(gameActionProvider).value;

      if (result == null) throw Exception("No result from server");

      // Assign win to a random position (server only returns the multiplier,
      // not which card index it belongs to – this is intentional UX).
      final winPos = math.Random().nextInt(3);

      setState(() {
        _winIndex = winPos;
        _multipliers = List.generate(
          3,
              (i) => i == winPos ? result.multiplier : 0.0,
        );
        _resultReady = true; // cards are now tappable
      });
    } catch (e) {
      if (!mounted) return;
      _reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ─── Reveal a single card ─────────────────────────────────────────────────
  void _reveal(int index) {
    // Only allow reveal after server responded and card not yet flipped
    if (!_resultReady || _revealed[index]) return;

    HapticFeedback.mediumImpact();

    // Animate the flip for this card
    _flipControllers[index].forward();

    // Wait for mid-flip (0.5) then mark as revealed so the front shows
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _revealed[index] = true);
    });

    // Check if all cards are revealed
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final allRevealed = List.generate(3, (i) => i == index || _revealed[i])
          .every((r) => r);
      if (allRevealed) {
        setState(() => _isPlaying = false);
        if (_winIndex != null && _multipliers[_winIndex!] > 5) {
          _showWinCelebration();
        }
      }
    });
  }

  void _showWinCelebration() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        // Auto-dismiss after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        });

        return Center(
          child: Icon(Icons.celebration, color: Colors.amberAccent, size: 140)
              .animate()
              .scale(duration: 400.ms, curve: Curves.elasticOut)
              .then()
              .shake(duration: 1.seconds),
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final balance =
        ref.watch(currentUserProfileProvider).value?.diamondBalance ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "LUCKY DRAW",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ).animate().shimmer(duration: 3.seconds, color: Colors.amberAccent),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                const Icon(Icons.diamond, color: Colors.cyanAccent, size: 22),
                const Gap(6),
                Text(
                  balance.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                const Gap(10),
                const Text(
                  "CHOOSE YOUR FATE",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ).animate().fadeIn().shimmer(duration: 2.5.seconds),

                const Gap(40),

                // ── Card row ──────────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 40) / 3;
                    final cardHeight = cardWidth * 1.45;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        3,
                            (i) =>
                            _buildFlippableCard(i, cardWidth, cardHeight),
                      ),
                    );
                  },
                ),

                const Gap(60),

                // ── Bet panel ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.18),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "STAKE YOUR DIAMONDS",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _betOptions
                            .map((bet) => _buildNeonBetButton(bet))
                            .toList(),
                      ),
                      const Gap(32),
                      SizedBox(
                        width: double.infinity,
                        height: 62,
                        child: ElevatedButton(
                          // Allow play only when not playing AND all cards
                          // have been revealed (or first time)
                          onPressed: _isPlaying ? null : _play,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(
                                  color: Colors.amberAccent, width: 2.5),
                            ),
                            elevation: 0,
                          ),
                          child: _isPlaying
                              ? (_resultReady
                              ? const Text(
                            "TAP CARDS TO REVEAL",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ).animate().shimmer(
                              duration: 1.2.seconds)
                              : const Text(
                            "DRAWING...",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amberAccent,
                            ),
                          ).animate().shimmer(
                              duration: 1.2.seconds))
                              : const Text(
                            "DRAW NOW",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Per-card flip widget ─────────────────────────────────────────────────
  Widget _buildFlippableCard(int index, double width, double height) {
    return GestureDetector(
      onTap: () => _reveal(index),
      child: AnimatedBuilder(
        animation: _flipAnimations[index],
        builder: (context, _) {
          final angle = _flipAnimations[index].value * math.pi;
          final isSecondHalf = _flipAnimations[index].value >= 0.5;

          // Flip back the matrix when showing the front to avoid mirror effect
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(isSecondHalf ? angle - math.pi : angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isSecondHalf
                ? _buildCardFront(index, width, height)
                : _buildCardBack(index, width, height),
          );
        },
      ),
    );
  }

  Widget _buildCardBack(int index, double width, double height) {
    // Pulse border when result is ready and this card is not yet revealed
    final tapable = _resultReady && !_revealed[index];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1B4D), Color(0xFF1A0033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: tapable
              ? Colors.amberAccent
              : Colors.amber.withOpacity(0.4),
          width: tapable ? 3.0 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: tapable
                ? Colors.amber.withOpacity(0.9)
                : Colors.amber.withOpacity(0.4),
            blurRadius: tapable ? 30 : 18,
            spreadRadius: tapable ? 8 : 3,
          ),
          BoxShadow(
            color: Colors.cyan.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          tapable ? Icons.touch_app_rounded : Icons.help_outline,
          color: tapable ? Colors.amberAccent : Colors.white38,
          size: 46,
        ),
      ),
    );
  }

  Widget _buildCardFront(int index, double width, double height) {
    final isWin = _multipliers[index] > 0;
    final multiplier = _multipliers[index];

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isWin
            ? Colors.amber.withOpacity(0.18)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isWin ? Colors.amberAccent : Colors.white24,
          width: isWin ? 3.5 : 2,
        ),
        boxShadow: isWin
            ? [
          BoxShadow(
            color: Colors.amber.withOpacity(0.85),
            blurRadius: 35,
            spreadRadius: 12,
          )
        ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isWin ? Icons.stars_rounded : Icons.close_rounded,
            color: isWin ? Colors.amberAccent : Colors.white38,
            size: 52,
          ),
          const Gap(10),
          Text(
            isWin ? "${multiplier.toStringAsFixed(multiplier.truncateToDouble() == multiplier ? 0 : 1)}x" : "MISS",
            style: TextStyle(
              color: isWin ? Colors.amberAccent : Colors.white38,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              shadows: isWin
                  ? [const Shadow(color: Colors.amber, blurRadius: 25)]
                  : null,
            ),
          ),
        ],
      ),
    ).animate().scale(
      begin: const Offset(0.7, 0.7),
      duration: 300.ms,
      curve: Curves.elasticOut,
    );
  }

  Widget _buildNeonBetButton(int amount) {
    final isSelected = _selectedBet == amount;

    return GestureDetector(
      onTap: _isPlaying ? null : () => setState(() => _selectedBet = amount),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Colors.amber.withOpacity(0.25)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected ? Colors.amberAccent : Colors.white24,
                width: isSelected ? 3.5 : 2,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: Colors.amberAccent.withOpacity(0.7),
                  blurRadius: 22,
                )
              ]
                  : [],
            ),
            child: const Icon(Icons.diamond,
                color: Colors.cyanAccent, size: 32),
          ),
          const Gap(8),
          Text(
            "$amount",
            style: TextStyle(
              color: isSelected ? Colors.amberAccent : Colors.white70,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 34,
              height: 3.5,
              decoration: BoxDecoration(
                color: Colors.amberAccent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}