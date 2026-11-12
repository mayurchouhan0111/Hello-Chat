import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/youtube_panel.dart';
import '../screens/spin_wheel_screen.dart';
import '../screens/lucky_draw_screen.dart';

/// Unified Games & Tools Bottom Sheet matching reference design.
/// Contains "Tools" (Counter, Lucky bag, Music, Pick Me, Effect)
/// and "Party Game" 4-column grid (Ludo, Billiard, Jackaroo, Monster Crush,
/// Carrom Pool, Umo, Dart King, Snake Ludo, Spin Wheel, Lucky Draw).
class UnifiedGamesHubSheet extends ConsumerStatefulWidget {
  final String roomId;
  final int initialCategory;

  const UnifiedGamesHubSheet({
    super.key,
    required this.roomId,
    this.initialCategory = 0,
  });

  @override
  ConsumerState<UnifiedGamesHubSheet> createState() => _UnifiedGamesHubSheetState();
}

class _UnifiedGamesHubSheetState extends ConsumerState<UnifiedGamesHubSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161522),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ═════════════════════════════════════════════════════════════
              // SECTION 1: "Tools"
              // ═════════════════════════════════════════════════════════════
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  "Tools",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Gap(8),

              // 5 Circular Tool Items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToolItem(
                      title: "Counter",
                      iconWidget: _buildCounterIcon(),
                      onTap: () => _handleCounter(context),
                    ),
                    _buildToolItem(
                      title: "Lucky bag",
                      iconWidget: _buildLuckyBagIcon(),
                      onTap: () => _handleLuckyBag(context),
                    ),
                    _buildToolItem(
                      title: "Music",
                      iconWidget: _buildMusicIcon(),
                      onTap: () => _handleMusic(context),
                    ),
                    _buildToolItem(
                      title: "Pick Me",
                      iconWidget: _buildPickMeIcon(),
                      onTap: () => _handlePickMe(context),
                    ),
                    _buildToolItem(
                      title: "Effect",
                      iconWidget: _buildEffectIcon(),
                      onTap: () => _handleEffect(context),
                    ),
                  ],
                ),
              ),

              const Gap(22),

              // ═════════════════════════════════════════════════════════════
              // SECTION 2: "Party Game"
              // ═════════════════════════════════════════════════════════════
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  "Party Game",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Gap(8),

              // 4-Column Grid of Game Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                  children: [
                    _buildGameCard(
                      title: "LUDO",
                      artwork: _buildLudoArtwork(),
                      onTap: () => _launchPartyGame(context, "Ludo"),
                    ),
                    _buildGameCard(
                      title: "BILLIARD",
                      artwork: _buildBilliardArtwork(),
                      onTap: () => _launchPartyGame(context, "Billiard"),
                    ),
                    _buildGameCard(
                      title: "JACKAROO",
                      artwork: _buildJackarooArtwork(),
                      onTap: () => _launchPartyGame(context, "Jackaroo"),
                    ),
                    _buildGameCard(
                      title: "MONSTERCRU\nSH",
                      artwork: _buildMonsterCrushArtwork(),
                      onTap: () => _launchPartyGame(context, "Monster Crush"),
                    ),
                    _buildGameCard(
                      title: "CARROMPOOL",
                      artwork: _buildCarromPoolArtwork(),
                      onTap: () => _launchPartyGame(context, "Carrom Pool"),
                    ),
                    _buildGameCard(
                      title: "UMO",
                      artwork: _buildUmoArtwork(),
                      onTap: () => _launchPartyGame(context, "UMO"),
                    ),
                    _buildGameCard(
                      title: "DART KING",
                      artwork: _buildDartKingArtwork(),
                      onTap: () => _launchPartyGame(context, "Dart King"),
                    ),
                    _buildGameCard(
                      title: "SNAKE LUDO",
                      artwork: _buildSnakeLudoArtwork(),
                      onTap: () => _launchPartyGame(context, "Snake Ludo"),
                    ),
                    _buildGameCard(
                      title: "SPIN WHEEL",
                      artwork: _buildSpinWheelArtwork(),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SpinWheelScreen(roomId: widget.roomId),
                          ),
                        );
                      },
                    ),
                    _buildGameCard(
                      title: "LUCKY DRAW",
                      artwork: _buildLuckyDrawArtwork(),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LuckyDrawScreen(roomId: widget.roomId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Gap(10),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TOOL ITEMS HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildToolItem({
    required String title,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const Gap(7),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9E9EA7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 1. Counter (Golden star coin)
  Widget _buildCounterIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA000).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.star_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  // 2. Lucky Bag (Red packet with gold seal)
  Widget _buildLuckyBagIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Envelope flap curve
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 18,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFFFD700), width: 1.2),
                ),
              ),
            ),
          ),
          // Center gold seal
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFD700),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
            child: const Center(
              child: Icon(Icons.diamond_rounded, size: 10, color: Color(0xFFB71C1C)),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Music (Vinyl record with red center)
  Widget _buildMusicIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E2129),
        border: Border.all(color: const Color(0xFF323644), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Concentric groove ring
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
            ),
          ),
          // Red vinyl center
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEF4444),
            ),
            child: Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // Glossy reflection arc
          Positioned(
            top: 4,
            right: 8,
            child: Container(
              width: 10,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Pick Me (Cute blue droplet with crown & pink glow)
  Widget _buildPickMeIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Droplet body
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF67E8F9), Color(0xFF0284C7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anime eyes
                Positioned(
                  top: 18,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      const Gap(10),
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Cute 3-point crown on top
          Positioned(
            top: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 5, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFD700), borderRadius: BorderRadius.vertical(top: Radius.circular(3)))),
                const Gap(1),
                Container(width: 6, height: 11, decoration: const BoxDecoration(color: Color(0xFFFFD700), borderRadius: BorderRadius.vertical(top: Radius.circular(3)))),
                const Gap(1),
                Container(width: 5, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFD700), borderRadius: BorderRadius.vertical(top: Radius.circular(3)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Effect (Blue badge with magic wand and sparkles)
  Widget _buildEffectIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.auto_fix_high_rounded,
          color: Color(0xFFFFF176),
          size: 26,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PARTY GAME CARDS HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildGameCard({
    required String title,
    required Widget artwork,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                ],
              ),
              child: artwork,
            ),
          ),
          const Gap(5),
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB0B0C0),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  // 1. Ludo Artwork
  Widget _buildLudoArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Mini dice
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDiceDot(),
                      const Gap(8),
                      _buildDiceDot(),
                    ],
                  ),
                  const Gap(4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDiceDot(),
                      const Gap(8),
                      _buildDiceDot(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Yellow Ludo badge
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "LUDO",
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceDot() => Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
      );

  // 2. Billiard Artwork
  Widget _buildBilliardArtwork() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF15803D),
        border: Border(
          top: BorderSide(color: Color(0xFF78350F), width: 3),
          left: BorderSide(color: Color(0xFF78350F), width: 3),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 8-ball
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 2)),
              ],
            ),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    "8",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Yellow cursive Billiard label
          const Positioned(
            bottom: 3,
            child: Text(
              "Billiard",
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Jackaroo Artwork
  Widget _buildJackarooArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFF92400E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Marbles ring
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMarble(const Color(0xFFEF4444)),
              const Gap(5),
              _buildMarble(const Color(0xFF3B82F6)),
              const Gap(5),
              _buildMarble(const Color(0xFF10B981)),
            ],
          ),
          // Yellow banner
          Positioned(
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "JACKAROO",
                style: TextStyle(
                  color: Color(0xFF78350F),
                  fontWeight: FontWeight.w900,
                  fontSize: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarble(Color color) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
        ),
      );

  // 4. Monster Crush Artwork
  Widget _buildMonsterCrushArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF581C87)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cute one-eyed green monster
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Colorful candies around
          Positioned(
            top: 6,
            left: 8,
            child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFF43F5E), shape: BoxShape.circle)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle)),
          ),
        ],
      ),
    );
  }

  // 5. Carrom Pool Artwork
  Widget _buildCarromPoolArtwork() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFF92400E), width: 3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center circle
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
            ),
          ),
          // Striker
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
          ),
          // Text badge
          Positioned(
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF92400E),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "Carrom Pool",
                style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. UMO Artwork
  Widget _buildUmoArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700),
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: const Center(
            child: Text(
              "UMO",
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 7. Dart King Artwork
  Widget _buildDartKingArtwork() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Target rings
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEF4444), width: 4),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          // Darts
          Positioned(
            top: 10,
            right: 12,
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: 3,
                height: 16,
                color: const Color(0xFF38BDF8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 8. Snake Ludo Artwork
  Widget _buildSnakeLudoArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Stepping blocks
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(width: 16, height: 8, decoration: BoxDecoration(color: const Color(0xFFFBBF24), borderRadius: BorderRadius.circular(2))),
          ),
          Positioned(
            bottom: 22,
            right: 12,
            child: Container(width: 16, height: 8, decoration: BoxDecoration(color: const Color(0xFFEC4899), borderRadius: BorderRadius.circular(2))),
          ),
          // Cute green snake
          const Icon(Icons.gesture_rounded, color: Color(0xFF4ADE80), size: 36),
        ],
      ),
    );
  }

  // 9. Spin Wheel Artwork (Native Game)
  Widget _buildSpinWheelArtwork() {
    return Image.asset(
      "assets/images/game_spin_wheel_art.jpg",
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0284C7), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.casino_rounded, color: Color(0xFFFFD700), size: 32),
        ),
      ),
    );
  }

  // 10. Lucky Draw Artwork (Native Game)
  Widget _buildLuckyDrawArtwork() {
    return Image.asset(
      "assets/images/game_lucky_draw_art.jpg",
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF3B0764)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFD700), size: 32),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // INTERACTIVE ACTION HANDLERS
  // ═════════════════════════════════════════════════════════════════════════

  void _handleCounter(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.timer_rounded, color: Color(0xFFFFD700), size: 24),
            Gap(8),
            Text("Room Counter", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          "Use the counter to time games, speeches, or quick room countdowns.",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AppToast.showSuccess(context, "60s Room Timer Started! ⏱️");
            },
            child: const Text("START 60S", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleLuckyBag(BuildContext context) {
    Navigator.pop(context);
    AppToast.showInfo(context, "Lucky Bag is active! Send a Lucky Bag to room members.");
  }

  void _handleMusic(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => YouTubePanel(roomId: widget.roomId),
    );
  }

  void _handlePickMe(BuildContext context) {
    final participants = ref.read(roomParticipantsProvider(widget.roomId)).value ?? [];
    Navigator.pop(context);

    if (participants.isEmpty) {
      AppToast.showWarning(context, "No participants available to pick right now!");
      return;
    }

    final luckyIndex = math.Random().nextInt(participants.length);
    final luckyUser = participants[luckyIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Center(
          child: Text("👑 Pick Me Winner!", style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_rounded, color: Color(0xFFFF4081), size: 48),
            const Gap(12),
            Text(
              "User #${luckyUser.uid.substring(0, math.min(6, luckyUser.uid.length))}",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Gap(6),
            const Text(
              "Was selected by the Pick Me wheel!",
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CONGRATULATIONS!", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEffect(BuildContext context) {
    Navigator.pop(context);
    AppToast.showInfo(context, "Room Entrance & Gift Effects are active ✨");
  }

  void _launchPartyGame(BuildContext context, String gameName) {
    Navigator.pop(context);
    AppToast.showInfo(context, "$gameName table is ready! Inviting room members... 🎲");
  }
}
