import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/models/reward_model.dart';
import 'package:hello_chat/features/leaderboards/presentation/screens/room_gift_leaderboard_screen.dart';
import 'reward_ranking_widgets.dart';

class RocketDetailSheet extends ConsumerStatefulWidget {
  final RoomModel room;
  const RocketDetailSheet({super.key, required this.room});

  @override
  ConsumerState<RocketDetailSheet> createState() => _RocketDetailSheetState();
}

class _RocketDetailSheetState extends ConsumerState<RocketDetailSheet> with TickerProviderStateMixin {
  int _selectedLevel = 0;
  String _selectedTab = 'Room Owner';

  Timer? _countdownTimer;
  String _timeString = "00:00:00";

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.room.rocketLevel.clamp(0, 4);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final diff = tomorrow.difference(now);

      setState(() {
        _timeString = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  int _getTargetForLevel(int level, List<int> targets) {
    if (level >= 0 && level < targets.length) {
      return targets[level];
    }
    return 10000000;
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.room.roomId));
    final room = roomAsync.value ?? widget.room;

    final targetsAsync = ref.watch(rocketSettingsProvider);
    final targets = targetsAsync.valueOrNull ?? const [1000000, 2000000, 3000000, 5000000, 10000000];
    final target = _getTargetForLevel(_selectedLevel, targets);
    final fuel = _selectedLevel == room.rocketLevel ? room.rocketFuel : (_selectedLevel < room.rocketLevel ? target : 0);
    final progress = (fuel / target).clamp(0.0, 1.0);

    final contributions = _resolveContributions(room);
    final sorted = contributions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topContributorId = sorted.isNotEmpty ? sorted.first.key : room.ownerUid;
    final topUser = ref.watch(userProfileProvider(topContributorId)).value;

    final rewards = _getRewardsForLevel(_selectedLevel);
    final frameDur = rewards['frameDuration'] as String;
    final rewardState = RocketRewardState(
      level: _selectedLevel,
      tabRewards: {
        'Room Owner': [
          RewardModel.coins(amount: rewards['king'] as int, rank: 1),
          RewardModel.exp(amount: rewards['xp'] as int, rank: 1),
          RewardModel.badge(duration: frameDur, rank: 1),
        ],
        'TOP 1': [
          RewardModel.coins(amount: rewards['king'] as int, rank: 1),
          RewardModel.exp(amount: rewards['xp'] as int, rank: 1),
          RewardModel.badge(duration: frameDur, rank: 1),
        ],
        'TOP 2': [
          RewardModel.coins(amount: rewards['t2'] as int, rank: 2),
          RewardModel.exp(amount: (rewards['xp'] as int) ~/ 2, rank: 2),
          RewardModel.badge(duration: frameDur, rank: 2),
        ],
        'TOP 3': [
          RewardModel.coins(amount: rewards['t3'] as int, rank: 3),
          RewardModel.exp(amount: (rewards['xp'] as int) ~/ 3, rank: 3),
          RewardModel.badge(duration: frameDur, rank: 3),
        ],
      },
    );

    final rankingList = sorted.take(3).toList().asMap().entries.map((e) {
      final uid = e.value.key;
      final score = e.value.value;
      return RankingModel(rank: e.key + 1, userId: uid, score: score);
    }).toList();

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF09001A),
            Color(0xFF140032),
            Color(0xFF080014),
          ],
          stops: [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Top Room Header Bar ─────────────────────────────────
          _buildTopHeader(room),

          // ── Top Stats Bar ───────────────────────────────────────
          _buildTopStatsBar(room),

          // ── Scrollable Body ─────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    const Gap(6),

                    // ── Rocket Stage Area (Left Level Rack, Big 3D Rocket, Right Fuel Progress)
                    SizedBox(
                      height: 275,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildLevelSelector(room),
                          Expanded(child: _buildMainRocketDisplay(room, topUser?.profilePhotoUrl)),
                          _buildRightControls(progress),
                        ],
                      ),
                    ),

                    // ── Countdown Timer & Tier Diamonds Row ─────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Reset countdown: $_timeString',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Gap(5),
                        GestureDetector(
                          onTap: () => _showRocketRulesDialog(context),
                          child: const Icon(Icons.info_outline_rounded, color: Colors.white60, size: 14),
                        ),
                      ],
                    ),
                    const Gap(8),

                    // 3 Tier Diamond Medals Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMedalPill('🥇', '30K', const Color(0xFF00E5FF)),
                        const Gap(8),
                        _buildMedalPill('🥈', '15K', const Color(0xFF00E5FF)),
                        const Gap(8),
                        _buildMedalPill('🥉', '5K', const Color(0xFF00E5FF)),
                      ],
                    ),
                    const Gap(8),

                    // Top 3 Frame Notice Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A0E6E).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCC00FF).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 14),
                          Gap(6),
                          Text(
                            'Top 3 each receive Rocket Frame (24h)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Gap(4),
                          Icon(Icons.info_outline_rounded, color: Colors.white54, size: 12),
                        ],
                      ),
                    ),
                    const Gap(14),

                    // ── Reward Section ───────────────────────────────────
                    RewardSection(
                      rewardState: rewardState,
                      selectedTab: _selectedTab,
                      onTabChanged: (tab) => setState(() => _selectedTab = tab),
                    ),
                    const Gap(14),

                    // ── Ranking Section ──────────────────────────────────
                    RankingSection(
                      rankings: rankingList,
                    ),
                    const Gap(16),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Sticky Footer Bar ────────────────────────────
          _buildBottomFooter(contributions),
        ],
      ),
    );
  }

  // ── Top Room Header ─────────────────────────────────────────
  Widget _buildTopHeader(RoomModel room) {
    final displayName = room.name.isNotEmpty ? room.name : 'hello chat';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Row(
        children: [
          // Room Info Pill
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFF4776E6)]),
                    ),
                    child: const Center(
                      child: Icon(Icons.rocket_launch_rounded, color: Colors.amberAccent, size: 14),
                    ),
                  ),
                  const Gap(6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ID:${room.roomId.length > 8 ? room.roomId.substring(0, 8) : room.roomId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  const Gap(6),
                  // Lightning Bolt Button
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF9900)]),
                    ),
                    child: const Center(
                      child: Icon(Icons.bolt_rounded, color: Colors.black, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(6),
          // Action Buttons: Share, Refresh, Fullscreen, Close
          _buildActionIcon(Icons.share_outlined, () {}),
          const Gap(8),
          _buildActionIcon(Icons.refresh_rounded, () {
            ref.invalidate(currentRoomStreamProvider(widget.room.roomId));
          }),
          const Gap(8),
          _buildActionIcon(Icons.fullscreen_rounded, () {}),
          const Gap(8),
          // Crimson Close Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF8B1229),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // ── Top Stats Bar ───────────────────────────────────────────
  Widget _buildTopStatsBar(RoomModel room) {
    final displayName = room.name.isNotEmpty ? room.name : 'hello chat';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Trophy + Top List >
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoomGiftLeaderboardScreen(roomId: room.roomId, roomName: displayName)),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 16),
                Gap(4),
                Text(
                  'Top List >',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Color(0xFFFF9900), blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Dynamic Star Pill (Calculates 0 Star to 5 Stars with auto color changes)
          _buildStarPill(room),
          const Spacer(),
          // Fuel / Diamond counter
          Text(
            '${room.rocketFuel}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Level Selector on Left (Rocket Collection / Level Rack) ─
  Widget _buildLevelSelector(RoomModel room) {
    return Container(
      width: 50,
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final isSelected = _selectedLevel == index;
          final isCurrent = room.rocketLevel == index;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!mounted) return;
              setState(() => _selectedLevel = index);
            },
            child: Container(
              height: 44,
              width: 42,
              margin: const EdgeInsets.only(bottom: 3),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFCC00FF).withValues(alpha: 0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFFCC00FF) : Colors.transparent,
                  width: 1.8,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _RocketLevelSvgaButton(level: index),
                  if (isCurrent)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFCC00FF), borderRadius: BorderRadius.circular(3)),
                        child: const Text("Lv.1", style: TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Center Extra-Big 3D Rocket Display (Prominent & Centered)
  Widget _buildMainRocketDisplay(RoomModel room, String? profileImageUrl) {
    final variant = _selectedLevel >= 3 ? 3 : 2;
    final vapPath = RocketVapConfig.vapAssetPath(_selectedLevel, variant: variant);

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Glowing purple cosmic aura beneath rocket pedestal
        Positioned(
          bottom: 0,
          left: 10,
          right: 10,
          height: 38,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.elliptical(180, 35)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCC00FF).withValues(alpha: 0.75),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        ),

        // 3D VAP Rocket Animation aligned perfectly on top of purple cloud
        Positioned(
          top: 50,
          bottom: -30,
          left: -20,
          right: -20,
          child: Transform.scale(
            scale: 1.65,
            child: VapAnimation(
              assetPath: vapPath,
              profileImageUrl: profileImageUrl,
              fit: BoxFit.contain,
              loop: true,
            ),
          ),
        ),

        // Floating Multiplier Badge on top right
        Positioned(
          top: 6,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8E54E9).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00FFFF).withValues(alpha: 0.8), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8E54E9).withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 14),
                const Gap(4),
                Text(
                  "Reward: ${_getMultiplierForLevel(_selectedLevel)}",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),
        ),

        // System Cooldown Notice Overlay if applicable
        if (room.rocketStatus == "cooldown" &&
            room.rocketCooldownUntil != null &&
            room.rocketCooldownUntil!.isAfter(DateTime.now()))
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "SYSTEM COOLDOWN",
                        style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                      const Gap(6),
                      _buildCooldownTimerDetail(room.rocketCooldownUntil!),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Fuel Progress & Controls on Right ───────────────────────
  Widget _buildRightControls(double progress) {
    const double trackHeight = 150;

    return Container(
      width: 48,
      margin: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: trackHeight,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // Track Background
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFCC00FF).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                // Track Fill
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: progress * trackHeight,
                    width: 14,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E54E9), Color(0xFFCC00FF), Color(0xFF00FFFF)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Percentage Tag
                Positioned(
                  bottom: (progress * trackHeight).clamp(0.0, trackHeight - 16),
                  right: -12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070014),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00FFFF), width: 1),
                    ),
                    child: Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(
                        color: Color(0xFF00FFFF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),
          _buildCircleButton(Icons.help_outline_rounded, () {
            _showRocketRulesDialog(context);
          }),
          const Gap(6),
          _buildCircleButton(Icons.assignment_rounded, () {
            // History/Logs dialog
          }),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFFCC00FF).withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCC00FF), width: 1.2),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildMedalPill(String medal, String amount, Color diamondColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1B033A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6B11A8), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medal, style: const TextStyle(fontSize: 12)),
          const Gap(4),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFF00FFFF),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Gap(3),
          const Icon(Icons.diamond_rounded, color: Color(0xFF00FFFF), size: 12),
        ],
      ),
    );
  }

  // ── Bottom Sticky Footer ────────────────────────────────────
  Widget _buildBottomFooter(Map<String, int> contributions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF080014).withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF22003D))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFCC00FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFCC00FF), size: 16),
          ),
          const Gap(8),
          const Text(
            'Be the first to contribute!',
            style: TextStyle(
              color: Color(0xFFB8A9D4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMultiplierForLevel(int level) {
    switch (level) {
      case 0: return "1x";
      case 1: return "2x";
      case 2: return "4x";
      case 3: return "8x";
      case 4: return "15x";
      default: return "1x";
    }
  }

  Map<String, dynamic> _getRewardsForLevel(int level) {
    const duration24h = '24h';
    const duration72h = '72h';
    switch (level) {
      case 0: return {'king': 30000, 't2': 15000, 't3': 8000, 'xp': 2000, 'frameDuration': duration24h};
      case 1: return {'king': 60000, 't2': 40000, 't3': 30000, 'xp': 3000, 'frameDuration': duration24h};
      case 2: return {'king': 200000, 't2': 150000, 't3': 100000, 'xp': 5000, 'frameDuration': duration24h};
      case 3: return {'king': 500000, 't2': 300000, 't3': 250000, 'xp': 10000, 'frameDuration': duration24h};
      case 4: return {'king': 800000, 't2': 500000, 't3': 350000, 'xp': 15000, 'frameDuration': duration72h};
      default: return {'king': 30000, 't2': 15000, 't3': 8000, 'xp': 2000, 'frameDuration': duration24h};
    }
  }

  Map<String, int> _resolveContributions(RoomModel room) {
    if (room.rocketContributions != null && room.rocketContributions!.isNotEmpty) {
      return room.rocketContributions!;
    }
    if (room.lastRocketResults != null) {
      final top3 = (room.lastRocketResults!['top3'] as List<dynamic>?) ?? [];
      final result = <String, int>{};
      for (final entry in top3) {
        if (entry is Map) {
          final uid = entry['uid'] as String?;
          final amount = entry['amount'] as num?;
          if (uid != null && amount != null) {
            result[uid] = amount.toInt();
          }
        }
      }
      return result;
    }
    return {};
  }

  Widget _buildCooldownTimerDetail(DateTime until) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final diff = until.difference(now);
        if (diff.isNegative) return const SizedBox.shrink();

        final m = diff.inMinutes.toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');

        return Text(
          "$m:$s",
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
        );
      },
    );
  }

  void _showRocketRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF160032),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFCC00FF))),
        title: const Text('Rocket Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            '1. Send gifts in room to fuel the rocket.\n'
            '2. When the rocket reaches 100% fuel, it launches!\n'
            '3. Top 3 contributors and the room owner receive exclusive rewards and frames.\n'
            '4. Levels reset every 24 hours at 00:00.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: Color(0xFF00FFFF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  int _calculateStarLevel(int diamonds) {
    if (diamonds >= 250000) return 5;
    if (diamonds >= 100000) return 4;
    if (diamonds >= 50000) return 3;
    if (diamonds >= 10000) return 2;
    if (diamonds >= 1000) return 1;
    return 0;
  }

  Color _getStarColor(int level) {
    switch (level) {
      case 1: return const Color(0xFF00E5FF); // 1 Star: Cyan
      case 2: return const Color(0xFF00C853); // 2 Star: Green
      case 3: return const Color(0xFF9C27B0); // 3 Star: Purple
      case 4: return const Color(0xFFFF4081); // 4 Star: Pink
      case 5: return const Color(0xFFFFD700); // 5 Star: Gold
      default: return Colors.white60;          // 0 Star: Grey
    }
  }

  Widget _buildStarPill(RoomModel room) {
    final diamonds = room.weeklyEarnings;
    final starLevel = _calculateStarLevel(diamonds);
    final starColor = _getStarColor(starLevel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: starColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: starColor.withValues(alpha: 0.45), width: 1.0),
        boxShadow: [
          if (starLevel > 0)
            BoxShadow(
              color: starColor.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: starColor, size: 14),
          const Gap(4),
          Text(
            '$starLevel Star',
            style: TextStyle(
              color: starLevel > 0 ? starColor : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              shadows: starLevel > 0 ? [Shadow(color: starColor.withValues(alpha: 0.5), blurRadius: 4)] : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RocketLevelSvgaButton extends StatefulWidget {
  final int level;
  const _RocketLevelSvgaButton({required this.level});

  @override
  State<_RocketLevelSvgaButton> createState() => _RocketLevelSvgaButtonState();
}

class _RocketLevelSvgaButtonState extends State<_RocketLevelSvgaButton> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }

  Future<void> _loadAnimation() async {
    try {
      final svgaPath = RocketVapConfig.svgaIconPath(widget.level);
      final videoItem = await SvgaParserUtil.decodeSafeFromAssets(svgaPath);
      if (mounted) {
        setState(() {
          _controller?.videoItem = videoItem;
          _controller?.repeat();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading SVGA for level ${widget.level}: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: _isLoading
          ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)))
          : (_controller?.videoItem != null)
              ? SVGAImage(_controller!)
              : const Icon(Icons.rocket_launch_rounded, color: Colors.white24, size: 20),
    );
  }
}
