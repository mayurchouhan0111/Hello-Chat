import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/mixer_sheet.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/pk_matching_bottom_sheet.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/room_settings_sheet.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/youtube_panel.dart';
import '../screens/spin_wheel_screen.dart';
import '../screens/lucky_draw_screen.dart';

/// Unified Games & Tools Bottom Sheet matching Hello Chat's real features
/// and the reference layout requested by client:
/// - Tools: [Music (YouTube)], [PK Battle], [Mixer], [Settings], [Lucky Bag]
/// - Games: [Spin Wheel], [Lucky Draw] (Only our 2 games, in card style)
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
    final room = ref.watch(currentRoomStreamProvider(widget.roomId)).value;
    final myUid = ref.watch(authStateProvider).value?.uid;
    final bool isHost = room != null && myUid != null && room.ownerUid == myUid;

    final participants = ref.watch(roomParticipantsProvider(widget.roomId)).value ?? [];
    final myPart = participants.where((p) => p.uid == myUid).firstOrNull;
    final bool isOnMic = isHost || (myPart != null && (myPart.seatIndex ?? -1) >= 0);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161522),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              // SECTION 1: "Tools" (Host gets all 5; Attendee gets attendee-appropriate tools)
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
              const Gap(10),

              // Circular Tool Items Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Music (YouTube Player) - always visible
                    _buildToolItem(
                      title: "Music",
                      iconWidget: _buildMusicIcon(),
                      onTap: () => _handleMusic(context),
                    ),
                    // 2. PK Battle - host only
                    if (isHost)
                      _buildToolItem(
                        title: "PK Battle",
                        iconWidget: _buildPkIcon(),
                        onTap: () => _handlePkBattle(context, isHost),
                      ),
                    // 3. Mixer (Audio Controls) - host or if on mic
                    if (isHost || isOnMic)
                      _buildToolItem(
                        title: "Mixer",
                        iconWidget: _buildMixerIcon(),
                        onTap: () => _handleMixer(context, isHost, isOnMic),
                      ),
                    // 4. Settings - host only
                    if (isHost)
                      _buildToolItem(
                        title: "Settings",
                        iconWidget: _buildSettingsIcon(),
                        onTap: () => _handleSettings(context, isHost),
                      ),
                    // 5. Lucky Bag - always visible
                    _buildToolItem(
                      title: "Lucky bag",
                      iconWidget: _buildLuckyBagIcon(),
                      onTap: () => _handleLuckyBag(context),
                    ),
                  ],
                ),
              ),

              const Gap(24),

              // ═════════════════════════════════════════════════════════════
              // SECTION 2: "Games" (Only our 2 real games)
              // ═════════════════════════════════════════════════════════════
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  "Games",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Gap(10),

              // 2-Column Grid of our 2 active games matching Snapchat Minis reference style
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    // 1. Spin Wheel (Active Native Game)
                    _buildGameCard(
                      context,
                      title: "Spin Wheel",
                      subtitle: "Win up to 10x prizes!",
                      badge: "POPULAR 🎡",
                      imageAsset: "assets/images/game_spin_wheel_art.jpg",
                      glowColor: const Color(0xFF0284C7),
                      accentColor: const Color(0xFF38BDF8),
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
                    const Gap(14),

                    // 2. Lucky Draw (Active Native Game)
                    _buildGameCard(
                      context,
                      title: "Lucky Draw",
                      subtitle: "High stakes jackpot!",
                      badge: "JACKPOT 💎",
                      imageAsset: "assets/images/game_lucky_draw_art.jpg",
                      glowColor: const Color(0xFFD97706),
                      accentColor: const Color(0xFFFBBF24),
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

              const Gap(12),
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

  // 1. Music (Vinyl record with red center)
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
            ),
          ),
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

  // 2. PK Battle (Amber circle with crossed swords / battle badge)
  Widget _buildPkIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.military_tech_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // 3. Mixer (Cyan / Blue circle with equalizer sliders)
  Widget _buildMixerIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.tune_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  // 4. Settings (Purple circle with gear)
  Widget _buildSettingsIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.settings_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  // 5. Lucky Bag (Red packet with gold seal)
  Widget _buildLuckyBagIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
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
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFD700),
            ),
            child: const Center(
              child: Icon(Icons.diamond_rounded, size: 10, color: Color(0xFFB71C1C)),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // GAME CARDS HELPER (Matching Snapchat Minis high-end cards)
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildGameCard(
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Artwork image
                  Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [glowColor, glowColor.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.sports_esports_rounded, size: 40, color: Colors.white38),
                      ),
                    ),
                  ),

                  // 2. Gradient scrim for readability
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.92),
                        ],
                        stops: const [0.0, 0.25, 0.6, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // 3. Card Content (Badge, Title, Subtitle, Play capsule)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Title
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Gap(2),

                        // Subtitle
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                        const Gap(8),

                        // Play Now Capsule Button
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accentColor, accentColor.withValues(alpha: 0.85)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 14, color: Colors.black),
                              Gap(4),
                              Text(
                                "PLAY NOW",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
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

  // ═════════════════════════════════════════════════════════════════════════
  // INTERACTIVE ACTION HANDLERS
  // ═════════════════════════════════════════════════════════════════════════

  void _handleMusic(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => YouTubePanel(roomId: widget.roomId),
    );
  }

  void _handlePkBattle(BuildContext context, bool isHost) {
    if (!isHost) {
      AppToast.showWarning(context, "Only the room host can initiate PK Battle", title: "Host Only");
      return;
    }
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PKMatchingBottomSheet(roomId: widget.roomId),
    );
  }

  void _handleMixer(BuildContext context, bool isHost, bool isOnMic) {
    if (!isHost && !isOnMic) {
      AppToast.showWarning(context, "Mixer controls are available when seated on a mic", title: "Mic Seat Required");
      return;
    }
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const MixerSheet(),
    );
  }

  void _handleSettings(BuildContext context, bool isHost) {
    if (!isHost) {
      AppToast.showWarning(context, "Only the room host can access room settings", title: "Host Only");
      return;
    }
    final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
    Navigator.pop(context);

    if (room == null) {
      AppToast.showWarning(context, "Room details loading, please try again");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RoomSettingsSheet(room: room),
    );
  }

  void _handleLuckyBag(BuildContext context) {
    Navigator.pop(context);
    AppToast.showInfo(context, "Lucky Bag is active! Send a Lucky Bag to room members.");
  }
}
