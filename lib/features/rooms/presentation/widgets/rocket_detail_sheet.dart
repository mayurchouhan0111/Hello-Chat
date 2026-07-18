import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';

class RocketDetailSheet extends ConsumerStatefulWidget {
  final RoomModel room;
  const RocketDetailSheet({super.key, required this.room});

  @override
  ConsumerState<RocketDetailSheet> createState() => _RocketDetailSheetState();
}

class _RocketDetailSheetState extends ConsumerState<RocketDetailSheet> with TickerProviderStateMixin {
  int _selectedLevel = 0;
  String _selectedTab = "Top1";

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

  int _getTargetForLevel(int level) {
    switch (level) {
      case 0: return 1000000;
      case 1: return 2000000;
      case 2: return 3000000;
      case 3: return 5000000;
      case 4: return 10000000;
      default: return 10000000;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.room.roomId));
    final room = roomAsync.value ?? widget.room;

    final target = _getTargetForLevel(_selectedLevel);
    final fuel = _selectedLevel == room.rocketLevel ? room.rocketFuel : (_selectedLevel < room.rocketLevel ? target : 0);
    final progress = (fuel / target).clamp(0.0, 1.0);

    final contributions = _resolveContributions(room);
    final sorted = contributions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topContributorId = sorted.isNotEmpty ? sorted.first.key : room.ownerUid;
    final topUser = ref.watch(userProfileProvider(topContributorId)).value;

    final top3Uids = sorted.take(3).map((e) => e.key).toList();

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF1E0045).withOpacity(0.8),
            const Color(0xFF0F0025),
          ],
          stops: const [0.0, 0.25, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const Gap(20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLevelSelector(room),
                    Expanded(child: _buildMainRocketDisplay(room, topUser?.profilePhotoUrl)),
                    _buildRightControls(progress),
                  ],
                ),
              ),
              _buildBottomPanel(room),
            ],
          ),
          Positioned(
            top: 20, right: 20,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector(RoomModel room) {
    return Container(
      width: 65,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              height: 52,
              width: 48,
              margin: const EdgeInsets.only(bottom: 4),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFCC00FF).withOpacity(0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFFCC00FF) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _RocketLevelSvgaButton(level: index),

                  if (isCurrent)
                    Positioned(
                      top: 1, right: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFCC00FF), borderRadius: BorderRadius.circular(3)),
                        child: const Text("LVL", style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
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

  Widget _buildMainRocketDisplay(RoomModel room, String? profileImageUrl) {
    final variant = _selectedLevel >= 3 ? 3 : 2;
    final vapPath = RocketVapConfig.vapAssetPath(_selectedLevel, variant: variant);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -10,
          bottom: -110,
          left: -40,
          right: -40,
          child: VapAnimation(
            assetPath: vapPath,
            profileImageUrl: profileImageUrl,
            fit: BoxFit.contain,
            loop: true,
          ),
        ),

        Positioned(
          top: 0, left: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCC00FF), width: 2),
              gradient: const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFFCC00FF)]),
            ),
            child: Text(
              "${_selectedLevel + 1}",
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),

        Positioned(
          top: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCC00FF).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00FFFF).withOpacity(0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                Text(
                  "Reward: ${_getMultiplierForLevel(_selectedLevel)}",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),
        ),

        if (room.rocketStatus == "cooldown" &&
            room.rocketCooldownUntil != null &&
            room.rocketCooldownUntil!.isAfter(DateTime.now()))
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20)
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "SYSTEM COOLDOWN",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                          const Gap(8),
                          _buildCooldownTimerDetail(room.rocketCooldownUntil!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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

  Widget _buildRightControls(double progress) {
    const double trackHeight = 200;

    return Container(
      width: 50,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: trackHeight,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFCC00FF).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCC00FF).withOpacity(0.15),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.1),
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: progress * trackHeight,
                    width: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8E54E9),
                          Color(0xFFCC00FF),
                          Color(0xFF00FFFF),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCC00FF).withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                      ],
                    ),
                  ),
                ),

                if (progress > 0.05)
                  Positioned(
                    bottom: (progress * trackHeight) - 4,
                    child: Container(
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFFF).withOpacity(0.8),
                            blurRadius: 15,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 1.seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),

                Positioned(
                  bottom: (progress * trackHeight) - 10,
                  right: -15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00FFFF).withOpacity(0.5), width: 1),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00FFFF).withOpacity(0.3), blurRadius: 8),
                      ],
                    ),
                    child: Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(
                        color: Color(0xFF00FFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 3.seconds),
                ),
              ],
            ),
          ),
          const Gap(12),
          _buildCircleIcon(Icons.help_outline_rounded, const Color(0xFFCC00FF)),
          const Gap(8),
          _buildCircleIcon(Icons.assignment_rounded, const Color(0xFFCC00FF)),
          const Gap(20),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  /// Resolves contributors from live rocketContributions (preferred) or lastRocketResults (fallback after launch)
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

  Map<String, dynamic> _getRewardsForLevel(int level) {
    const duration24h = '24h';
    const duration72h = '72h';
    switch (level) {
      case 0: return {'king': 30000, 't2': 15000, 't3': 7500, 'xp': 2000, 'frameDuration': duration24h};
      case 1: return {'king': 60000, 't2': 40000, 't3': 30000, 'xp': 3000, 'frameDuration': duration24h};
      case 2: return {'king': 200000, 't2': 150000, 't3': 100000, 'xp': 5000, 'frameDuration': duration24h};
      case 3: return {'king': 500000, 't2': 300000, 't3': 250000, 'xp': 10000, 'frameDuration': duration24h};
      case 4: return {'king': 800000, 't2': 500000, 't3': 350000, 'xp': 15000, 'frameDuration': duration72h};
      default: return {'king': 30000, 't2': 15000, 't3': 7500, 'xp': 2000, 'frameDuration': duration24h};
    }
  }

  Widget _buildBottomPanel(RoomModel room) {
    final contributions = _resolveContributions(room);
    final sortedRoomUids = contributions.keys.toList()
      ..sort((a, b) => contributions[b]!.compareTo(contributions[a]!));

    final top3 = sortedRoomUids.take(3).toList();
    final rest = sortedRoomUids.skip(3).toList();
    final rewards = _getRewardsForLevel(_selectedLevel);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0045),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Reset countdown: $_timeString",
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          // Top 3 Contributor List (always visible when contributors exist)
          if (top3.isNotEmpty)
            ...top3.asMap().entries.map((entry) {
              final rank = entry.key;
              final uid = entry.value;
              final medal = rank == 0 ? "🥇" : (rank == 1 ? "🥈" : "🥉");
              return _buildContributorRow(uid, contributions[uid] ?? 0, medal);
            }),
          if (top3.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("No contributors yet", style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          const Gap(8),
          // Reward info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRewardChip("🥇", "${_formatReward(rewards['king'] as int)} 💎"),
              _buildRewardChip("🥈", "${_formatReward(rewards['t2'] as int)} 💎"),
              _buildRewardChip("🥉", "${_formatReward(rewards['t3'] as int)} 💎"),
            ],
          ),
          const Gap(4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCC00FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 12),
                const SizedBox(width: 4),
                Text(
                  "Top 3 each receive Rocket Frame (${rewards['frameDuration']})",
                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Gap(12),
          // Rank 4+ scrollable list
          if (rest.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: rest.length,
                itemBuilder: (context, index) {
                  final uid = rest[index];
                  final contribution = contributions[uid] ?? 0;
                  final rank = index + 4;
                  return Consumer(
                    builder: (context, ref, child) {
                      final userAsync = ref.watch(userProfileProvider(uid));
                      return userAsync.when(
                        data: (user) {
                          if (user == null) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text("#$rank", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                AppAvatar(
                                  imageUrl: user.profilePhotoUrl,
                                  frameUrl: user.profileFrame,
                                  vipTier: user.vipTier,
                                  userLevel: user.level,
                                  tags: user.tags,
                                  radius: 14,
                                  showFrame: true,
                                  frameMultiplier: 1.3,
                                ),
                                const Gap(8),
                                Expanded(
                                  child: Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                Text("$contribution 💎", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  );
                },
              ),
            ),
          if (sortedRoomUids.isEmpty)
            const SizedBox(
              height: 60,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium_outlined, color: Colors.white24, size: 24),
                    Gap(4),
                    Text("Be the first to contribute!", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition(String uid, int contribution, int rank, RoomModel room) {
    return Consumer(
      builder: (context, ref, child) {
        final userAsync = ref.watch(userProfileProvider(uid));
        return userAsync.when(
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            final podiumHeight = rank == 1 ? 80.0 : 60.0;
            final crownColors = [Colors.amber, const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];
            final rankLabels = ["ROCKET KING", "TOP 2", "TOP 3"];

            return GestureDetector(
              onTap: () {},
              child: Container(
                width: 100,
                alignment: Alignment.bottomCenter,
                padding: EdgeInsets.only(bottom: rank == 1 ? 0 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AppAvatar(
                          imageUrl: user.profilePhotoUrl,
                          frameUrl: user.profileFrame,
                          vipTier: user.vipTier,
                          userLevel: user.level,
                          tags: user.tags,
                          radius: rank == 1 ? 22 : 16,
                          showFrame: true,
                          frameMultiplier: rank == 1 ? 1.8 : 1.4,
                        ),
                        Positioned(
                          bottom: -4,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: crownColors[rank - 1],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "#$rank",
                                style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    Text(
                      "$contribution 💎",
                      style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    if (rank == 1)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                        ),
                        child: Text(rankLabels[rank - 1], style: const TextStyle(color: Colors.amber, fontSize: 7, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => SizedBox(
            width: 80,
            height: 60,
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildContributorRow(String uid, int contribution, String medal) {
    return Consumer(
      builder: (context, ref, child) {
        final userAsync = ref.watch(userProfileProvider(uid));
        return userAsync.when(
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(medal, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  AppAvatar(
                    imageUrl: user.profilePhotoUrl,
                    frameUrl: user.profileFrame,
                    vipTier: user.vipTier,
                    userLevel: user.level,
                    tags: user.tags,
                    radius: 14,
                    showFrame: true,
                    frameMultiplier: 1.2,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Text(
                    "$contribution 💎",
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(height: 30, child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)))),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  String _formatReward(int amount) {
    if (amount >= 1000000) return "${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}M";
    if (amount >= 1000) return "${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 0)}K";
    return amount.toString();
  }

  Widget _buildRewardChip(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
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
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
        );
      },
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
      width: 45,
      height: 45,
      child: _isLoading
          ? const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)))
          : (_controller?.videoItem != null)
              ? SVGAImage(_controller!)
              : const Icon(Icons.rocket_launch_rounded, color: Colors.white24, size: 24),
    );
  }
}
