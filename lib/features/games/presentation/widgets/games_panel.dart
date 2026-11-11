import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/providers/user_provider.dart';

import '../screens/lucky_draw_screen.dart';
import '../screens/spin_wheel_screen.dart';

// ═════════════════════════════════════════════════════════════════════════
// COMMENTED OUT GAMES PER CLIENT INSTRUCTION:
// The client specifically requested to keep Yummy Bingo and Teen Patti
// commented out and NOT active in the Games tab.
// ═════════════════════════════════════════════════════════════════════════
// import '../screens/yummy_bingo_screen.dart';
// import '../screens/teen_patti_screen.dart';

class GamesPanel extends ConsumerWidget {
  final String roomId;
  final void Function(int tabIndex)? onSwitchTab;

  const GamesPanel({
    super.key,
    required this.roomId,
    this.onSwitchTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider).value;
    final diamondBalance = user?.diamondBalance ?? 0;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Clean title + Diamond balance chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "FEATURED GAMES",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              // Diamond Balance Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond_rounded, size: 14, color: Color(0xFFFFD700)),
                    const Gap(5),
                    Text(
                      "$diamondBalance",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),

          // 2-Column Grid of our 2 active games matching Snapchat Minis reference style
          Row(
            children: [
              // 1. Spin Wheel (Active Native Game)
              _buildGameArtCard(
                context,
                title: "Spin Wheel",
                subtitle: "Win up to 10x prizes!",
                badge: "POPULAR 🎡",
                imageAsset: "assets/images/game_spin_wheel_art.jpg",
                glowColor: const Color(0xFF0284C7),
                accentColor: const Color(0xFF38BDF8),
                onTap: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => SpinWheelScreen(roomId: roomId)),
                  );
                },
              ),
              const Gap(14),

              // 2. Lucky Draw (Active Native Game)
              _buildGameArtCard(
                context,
                title: "Lucky Draw",
                subtitle: "High stakes jackpot!",
                badge: "JACKPOT 💎",
                imageAsset: "assets/images/game_lucky_draw_art.jpg",
                glowColor: const Color(0xFFD97706),
                accentColor: const Color(0xFFFBBF24),
                onTap: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => LuckyDrawScreen(roomId: roomId)),
                  );
                },
              ),
            ],
          ),

          // ═════════════════════════════════════════════════════════════
          // COMMENTED OUT PER CLIENT REQUIREMENT:
          // Yummy Bingo and Teen Patti remain commented out as requested.
          // ═════════════════════════════════════════════════════════════
          // YUMMY BINGO:
          // _buildGameArtCard(
          //   context,
          //   title: "Yummy Bingo",
          //   subtitle: "5-Reel Fruit & Jackpot!",
          //   badge: "HOT 🔥",
          //   imageAsset: "assets/images/game_yummy_bingo_art.jpg",
          //   glowColor: const Color(0xFFE11D48),
          //   accentColor: const Color(0xFFFB7185),
          //   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => YummyBingoScreen(roomId: roomId))),
          // ),
          // TEEN PATTI:
          // _buildGameArtCard(
          //   context,
          //   title: "Teen Patti",
          //   subtitle: "Multiplayer Card Table!",
          //   badge: "LIVE ♠️",
          //   imageAsset: "assets/images/game_teen_patti_art.jpg",
          //   glowColor: const Color(0xFF047857),
          //   accentColor: const Color(0xFF6EE7B7),
          //   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TeenPattiScreen(roomId: roomId))),
          // ),

          const Gap(16),
        ],
      ),
    );
  }

  Widget _buildGameArtCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badge,
    required String imageAsset,
    required Color glowColor,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 230,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. High-Quality Generated Game Artwork Background
                  Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [glowColor, glowColor.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.sports_esports_rounded, size: 48, color: Colors.white38),
                        ),
                      );
                    },
                  ),

                  // 2. Vignette & Bottom Gradient Scrim for crystal clear readability
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.90),
                        ],
                        stops: const [0.0, 0.28, 0.65, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // 3. Card Content (Top badge + Bottom Title, Subtitle & Play Capsule)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Polished Game Title
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(2),

                        // Subtitle
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(8),

                        // Modern Play Capsule Button
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accentColor, glowColor],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                              Gap(4),
                              Text(
                                "PLAY NOW",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
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
        ),
      ),
    );
  }
}
