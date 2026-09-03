import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/providers/profile_provider.dart';

class RocketRewardExplosionOverlay extends ConsumerStatefulWidget {
  final int level; // 0-indexed (0 to 4)
  final Map<String, int> contributions;
  final VoidCallback onClose;

  const RocketRewardExplosionOverlay({
    super.key,
    required this.level,
    required this.contributions,
    required this.onClose,
  });

  @override
  ConsumerState<RocketRewardExplosionOverlay> createState() => _RocketRewardExplosionOverlayState();
}

class _RocketRewardExplosionOverlayState extends ConsumerState<RocketRewardExplosionOverlay> {
  Map<String, dynamic> _getRewards() {
    const frameDuration = ['24h', '24h', '24h', '24h', '72h'];
    switch (widget.level) {
      case 0: return {'king': 30000, 't2': 15000, 't3': 7500, 'frameDuration': frameDuration[0]};
      case 1: return {'king': 60000, 't2': 40000, 't3': 30000, 'frameDuration': frameDuration[1]};
      case 2: return {'king': 200000, 't2': 150000, 't3': 100000, 'frameDuration': frameDuration[2]};
      case 3: return {'king': 500000, 't2': 300000, 't3': 250000, 'frameDuration': frameDuration[3]};
      case 4: return {'king': 800000, 't2': 500000, 't3': 350000, 'frameDuration': frameDuration[4]};
      default: return {'king': 30000, 't2': 15000, 't3': 7500, 'frameDuration': frameDuration[0]};
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedUids = widget.contributions.keys.toList()
      ..sort((a, b) => widget.contributions[b]!.compareTo(widget.contributions[a]!));
    
    final rewards = _getRewards();
    final kingReward = rewards['king'] ?? 0;
    final t2Reward = rewards['t2'] ?? 0;
    final t3Reward = rewards['t3'] ?? 0;
    final totalPool = kingReward + t2Reward + t3Reward;

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.85),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Detailed reward summaries
            Container(
                width: MediaQuery.of(context).size.width * 0.88,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F0E2A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFCC00FF), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCC00FF).withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gold Crown / Title
                    const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 40)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(duration: 1.seconds, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
                    const Gap(8),
                    const Text(
                      "REWARD EXPLOSION!",
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const Text(
                      "Rocket Settlement Complete",
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Gap(20),

                    // Top User (King) Section
                    if (sortedUids.isNotEmpty)
                      _buildTopUserCard(sortedUids[0], kingReward)
                    else
                      const Text(
                        "No King Contributor",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    const Gap(16),

                    // Normal User Rewards (Top 2 and Top 3)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "OTHER BENEFICIARIES",
                        style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    const Gap(8),
                    if (sortedUids.length > 1)
                      Column(
                        children: [
                          if (sortedUids.length > 1)
                            _buildBeneficiaryRow(sortedUids[1], t2Reward, "#2"),
                          if (sortedUids.length > 2) ...[
                            const Gap(8),
                            _buildBeneficiaryRow(sortedUids[2], t3Reward, "#3"),
                          ],
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text(
                          "No other contributors rewarded",
                          style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const Gap(20),

                    // Summary Panel
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow("Total Reward Pool", "$totalPool 💎"),
                          const Divider(color: Colors.white10, height: 12),
                          _buildSummaryRow("Given to Top User", "$kingReward 💎"),
                          const Divider(color: Colors.white10, height: 12),
                          _buildSummaryRow("Given to Others", "${t2Reward + t3Reward} 💎"),
                          const Divider(color: Colors.white10, height: 12),
                          _buildSummaryRow("Frame Reward", "🚀 Rocket Frame (${rewards['frameDuration']})"),
                          const Divider(color: Colors.white10, height: 12),
                          _buildSummaryRow("Total Winners", "${sortedUids.take(3).length} Users"),
                        ],
                      ),
                    ),
                    const Gap(24),

                    // Close Button
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFFCC00FF)]),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Text(
                            "Awesome!",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUserCard(String uid, int rewardAmount) {
    return Consumer(
      builder: (context, ref, child) {
        final userAsync = ref.watch(userProfileProvider(uid));
        return userAsync.when(
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: user.profilePhotoUrl,
                    frameUrl: user.profileFrame,
                    vipTier: user.vipTier,
                    userLevel: user.level,
                    tags: user.tags,
                    radius: 28,
                    showFrame: true,
                    frameMultiplier: 1.8,
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        Text("UID: ${uid.substring(0, 8)}...", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const Gap(4),
                        const Text("ROCKET KING", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "+$rewardAmount",
                        style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const Text("Diamonds", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.amber))),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildBeneficiaryRow(String uid, int rewardAmount, String rankTag) {
    return Consumer(
      builder: (context, ref, child) {
        final userAsync = ref.watch(userProfileProvider(uid));
        return userAsync.when(
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: user.profilePhotoUrl,
                    frameUrl: user.profileFrame,
                    vipTier: user.vipTier,
                    userLevel: user.level,
                    tags: user.tags,
                    radius: 20,
                    showFrame: true,
                    frameMultiplier: 1.5,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text("$rankTag • UID: ${uid.substring(0, 8)}...", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                  Text(
                    "+$rewardAmount 💎",
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
