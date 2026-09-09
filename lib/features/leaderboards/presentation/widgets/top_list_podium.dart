import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/utils/room_navigation_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PodiumUserData {
  final String uid;
  final String displayName;
  final String photoUrl;
  final num score;
  final String? countryCode;
  final String? vipTier;
  final int? level;
  final String? profileFrame;
  final List<String>? tags;
  final bool isRoom;

  const PodiumUserData({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.score,
    this.countryCode,
    this.vipTier,
    this.level,
    this.profileFrame,
    this.tags,
    this.isRoom = false,
  });
}

/// 3D Shiny Golden Coin Icon matching the reference mobile gaming UI
class GoldenCoinIcon extends StatelessWidget {
  final double size;
  const GoldenCoinIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.85,
          colors: [
            Color(0xFFFFF7C2),
            Color(0xFFFFD700),
            Color(0xFFFFA000),
            Color(0xFFB45309),
          ],
          stops: [0.0, 0.4, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: const Color(0xFFFFF9D2), width: size * 0.08),
      ),
      child: Center(
        child: Container(
          width: size * 0.58,
          height: size * 0.58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFB45309).withValues(alpha: 0.6),
              width: size * 0.06,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 2-Tier Leaderboard Podium matching the reference grand palace stage:
/// - Tier 1: Rank 1 is the solitary Emperor centered between the dual red-carpet staircases,
///   flanked by two pedestal pillars with golden royal crowns.
/// - Tier 2: Rank 2 (Silver) and Rank 3 (Bronze) are two dedicated rectangular frosted cards
///   placed side-by-side underneath the staircase.
class TopListPodium extends ConsumerWidget {
  final List<PodiumUserData> topUsers;
  final bool isSendingTab; // true = Diamonds, false = Beans
  final bool isRoomTab;
  final bool enableAnimations;

  const TopListPodium({
    super.key,
    required this.topUsers,
    this.isSendingTab = true,
    this.isRoomTab = false,
    this.enableAnimations = true,
  });

  String _formatScore(num value) {
    // If value is very large, format with standard integer or commas
    return value.toInt().toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user1 = topUsers.isNotEmpty ? topUsers[0] : null;
    final user2 = topUsers.length > 1 ? topUsers[1] : null;
    final user3 = topUsers.length > 2 ? topUsers[2] : null;

    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 🏛️ Grand 3D Royal Stage & Red Carpet Dual Staircases Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 290,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/leaderboards/podium_grand_stage_bg.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2A1B0E), Color(0xFF140D1E), Color(0xFF0C0A10)],
                        ),
                      ),
                    ),
                  ),

                  // Atmospheric Gradient Overlays for depth and seamless contrast
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0C0A10).withValues(alpha: 0.4),
                          Colors.transparent,
                          const Color(0xFF0C0A10).withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  // Warm Golden Volumetric Lighting Burst behind Rank 1
                  Positioned(
                    top: 10,
                    left: screenWidth * 0.2,
                    right: screenWidth * 0.2,
                    height: 180,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFD700).withValues(alpha: 0.28),
                            const Color(0xFFFF9100).withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🏛️ Main Hierarchical Column (Tier 1 Hero + Tier 2 Twin Cards)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── TIER 1: Solo Grand Champion (#1) on Palace Stage ───────
              _buildTier1ChampionStage(context, ref, user1),

              const SizedBox(height: 10),

              // ── TIER 2: Twin Rectangular Hero Cards for #2 and #3 ──────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    // 🥈 Rank 2 Hero Card (Silver)
                    Expanded(
                      child: _buildTier2HeroCard(
                        context: context,
                        ref: ref,
                        user: user2,
                        rank: 2,
                        borderColor: const Color(0xFF94A3B8),
                        borderGlow: const Color(0xFFE2E8F0),
                        medalBg: const Color(0xFFCBD5E1),
                        medalText: const Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 🥉 Rank 3 Hero Card (Bronze)
                    Expanded(
                      child: _buildTier2HeroCard(
                        context: context,
                        ref: ref,
                        user: user3,
                        rank: 3,
                        borderColor: const Color(0xFFB45309),
                        borderGlow: const Color(0xFFF59E0B),
                        medalBg: const Color(0xFFD97706),
                        medalText: const Color(0xFFFFFBEB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 👑 TIER 1: Clean Solo Grand Champion (#1) on Palace Stage
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTier1ChampionStage(
    BuildContext context,
    WidgetRef ref,
    PodiumUserData? user,
  ) {
    if (user == null) {
      return const SizedBox(height: 210);
    }

    return SizedBox(
      height: 215,
      child: Center(
        child: GestureDetector(
          onTap: () {
            if (user.isRoom) {
              RoomNavigationHelper.joinRoom(context, ref, user.uid);
            } else {
              context.push(AppRoutes.userProfile, extra: user.uid);
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Clean Champion Avatar with Gold Ring + NO.1 Badge ──
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Outer Golden Halo Ring
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),

                    // Avatar with frame support
                    if (user.isRoom)
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.photoUrl)
                            : null,
                        child: user.photoUrl.isEmpty
                            ? const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 30)
                            : null,
                      )
                    else
                      AppAvatar(
                        imageUrl: user.photoUrl,
                        frameUrl: user.profileFrame,
                        vipTier: user.vipTier,
                        userLevel: user.level,
                        radius: 36,
                        showFrame: true,
                        frameMultiplier: 1.4,
                      ),

                    // 🎖️ "NO.1" Clean Ribbon Badge at bottom
                    Positioned(
                      bottom: -7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFE50914), Color(0xFFB8000A), Color(0xFF7A0000)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          "NO.1",
                          style: TextStyle(
                            color: Color(0xFFFFF9D2),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── User Display Name with Country Flag ──────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                  if (user.countryCode != null && user.countryCode!.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(
                        "https://flagcdn.com/w40/${user.countryCode!.toLowerCase()}.png",
                        width: 16,
                        height: 11,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 5),

              // ── Oblong Score Pill (Dark Container with Gold Border + Coin) ──
              _buildScorePill(
                score: _formatScore(user.score),
                borderColor: const Color(0xFFFFD700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 🏛️ TIER 2: Rectangular Frosted Hero Cards for Rank 2 & Rank 3
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTier2HeroCard({
    required BuildContext context,
    required WidgetRef ref,
    required PodiumUserData? user,
    required int rank,
    required Color borderColor,
    required Color borderGlow,
    required Color medalBg,
    required Color medalText,
  }) {
    if (user == null) {
      return Container(
        height: 168,
        decoration: BoxDecoration(
          color: const Color(0xFF141724).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Text("Empty", style: TextStyle(color: Colors.white24, fontSize: 12)),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (user.isRoom) {
          RoomNavigationHelper.joinRoom(context, ref, user.uid);
        } else {
          context.push(AppRoutes.userProfile, extra: user.uid);
        }
      },
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF242A38),
              Color(0xFF151926),
              Color(0xFF0F121C),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: borderGlow.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle Diagonal Sheen Line
              Positioned(
                top: 0,
                bottom: 0,
                left: -20,
                right: -20,
                child: CustomPaint(
                  painter: _DiagonalSheenPainter(color: borderGlow.withValues(alpha: 0.08)),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── Avatar + Laurel Ring + Rank Medal ─────────────
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Laurel Outer Ring
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: borderGlow, width: 2.2),
                              boxShadow: [
                                BoxShadow(
                                  color: borderGlow.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),

                          // Avatar Image
                          ClipOval(
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: user.isRoom
                                  ? CircleAvatar(
                                      radius: 29,
                                      backgroundImage: user.photoUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(user.photoUrl)
                                          : null,
                                      child: user.photoUrl.isEmpty
                                          ? const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 24)
                                          : null,
                                    )
                                  : AppAvatar(
                                      imageUrl: user.photoUrl,
                                      frameUrl: user.profileFrame,
                                      vipTier: user.vipTier,
                                      userLevel: user.level,
                                      radius: 29,
                                      showFrame: true,
                                      frameMultiplier: 1.45,
                                    ),
                            ),
                          ),

                          // Medal Badge (#2 or #3) at bottom right
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: medalBg,
                                border: Border.all(color: Colors.white, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "$rank",
                                  style: TextStyle(
                                    color: medalText,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── User Display Name + Badges + Flag ─────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (user.countryCode != null && user.countryCode!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Image.network(
                              "https://flagcdn.com/w40/${user.countryCode!.toLowerCase()}.png",
                              width: 14,
                              height: 10,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // ── Score Pill with 3D Gold Coin ──────────────────
                    _buildScorePill(
                      score: _formatScore(user.score),
                      borderColor: borderColor.withValues(alpha: 0.6),
                      fontSize: 11.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dark Oblong Pill with Golden Border & 3D Gold Coin
  Widget _buildScorePill({
    required String score,
    required Color borderColor,
    double fontSize = 12.5,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E16).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            score,
            style: TextStyle(
              color: const Color(0xFFFFD700),
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 5),
          const GoldenCoinIcon(size: 13),
        ],
      ),
    );
  }
}

/// Paints a subtle diagonal glass reflection across the card
class _DiagonalSheenPainter extends CustomPainter {
  final Color color;
  _DiagonalSheenPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
