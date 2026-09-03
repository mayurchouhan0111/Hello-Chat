import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

class RocketWinnerPopupOverlay extends StatelessWidget {
  final int level;
  final int rank;
  final int coins;
  final int xp;
  final String frameDuration;
  final VoidCallback onClose;

  const RocketWinnerPopupOverlay({
    super.key,
    required this.level,
    required this.rank,
    required this.coins,
    required this.xp,
    required this.frameDuration,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isTop1 = rank == 1;
    final isTop2 = rank == 2;
    final isTop3 = rank == 3;

    final String rankTitle = isTop1 ? "1ST PLACE CHAMPION" : (isTop2 ? "2ND PLACE WINNER" : (isTop3 ? "3RD PLACE WINNER" : "TOP $rank WINNER"));
    
    final Color primaryColor = isTop1
        ? const Color(0xFFFFD700)
        : (isTop2 ? const Color(0xFFE0E0E0) : (isTop3 ? const Color(0xFFFF9E80) : const Color(0xFF00E5FF)));
        
    final Color accentColor = isTop1
        ? const Color(0xFFFF9100)
        : (isTop2 ? const Color(0xFF9E9E9E) : (isTop3 ? const Color(0xFFD84315) : const Color(0xFF2979FF)));

    final List<Color> borderGradient = isTop1
        ? const [Color(0xFFFFD700), Color(0xFFFF9100), Color(0xFFFFEA00)]
        : (isTop2
            ? const [Color(0xFFFFFFFF), Color(0xFFB0BEC5), Color(0xFFECEFF1)]
            : const [Color(0xFFFFAB91), Color(0xFFFF6E40), Color(0xFFFFD180)]);

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.75),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 380,
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Ambient Light Halos
                      Positioned(
                        top: -20,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.35),
                            boxShadow: [
                              BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 80, spreadRadius: 30),
                            ],
                          ),
                        ),
                      ),

                      // Main Card Body
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E1435), Color(0xFF0F0B1E)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: primaryColor.withOpacity(0.8), width: 1.8),
                          boxShadow: [
                            BoxShadow(color: primaryColor.withOpacity(0.35), blurRadius: 30, spreadRadius: 2),
                            BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Trophy / Crown Animated Badge
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: borderGradient),
                                    boxShadow: [
                                      BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 20),
                                    ],
                                  ),
                                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2.seconds, begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05)),
                                
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF140D2B),
                                  ),
                                  child: Icon(
                                    isTop1 ? Icons.workspace_premium_rounded : (isTop2 ? Icons.military_tech_rounded : Icons.emoji_events_rounded),
                                    color: primaryColor,
                                    size: 46,
                                  ),
                                ),
                              ],
                            ),

                            const Gap(16),

                            // Congratulations Title
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [primaryColor, Colors.white, accentColor],
                                ).createShader(bounds),
                                child: const Text(
                                  "CONGRATULATIONS!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                                  ),
                                ),
                              ),
                            ).animate().fade(duration: 400.ms).slideY(begin: -0.2),

                            const Gap(8),

                            // Subtitle Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: primaryColor.withOpacity(0.4), width: 1),
                              ),
                              child: Text(
                                rankTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ).animate().fade(delay: 150.ms),

                            const Gap(20),

                            // Rewards Section Container
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Column(
                                children: [
                                  _buildRewardItem(
                                    icon: "💎",
                                    title: "Diamond Reward",
                                    value: "+${_format(coins)} Diamonds",
                                    valueColor: const Color(0xFF00E5FF),
                                  ),
                                  const Divider(color: Colors.white10, height: 16),
                                  _buildRewardItem(
                                    icon: "✨",
                                    title: "Experience Points",
                                    value: "+${_format(xp)} EXP",
                                    valueColor: const Color(0xFFFFB700),
                                  ),
                                  const Divider(color: Colors.white10, height: 16),
                                  _buildRewardItem(
                                    icon: "👑",
                                    title: "Rocket Avatar Frame",
                                    value: frameDuration,
                                    valueColor: const Color(0xFFE040FB),
                                  ),
                                ],
                              ),
                            ).animate().fade(delay: 300.ms).scale(begin: const Offset(0.9, 0.9)),

                            const Gap(24),

                            // Awesome / Claim Action Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                onClose();
                              },
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [primaryColor, accentColor]),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  "CLAIM REWARDS 🎉",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                                duration: 2.5.seconds,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ).animate().fade(delay: 450.ms).slideY(begin: 0.3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardItem({
    required String icon,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 20)),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const Gap(2),
              Text(
                value,
                style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}
