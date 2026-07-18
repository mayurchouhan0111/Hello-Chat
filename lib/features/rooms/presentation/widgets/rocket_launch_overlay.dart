import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';

class RocketLaunchOverlay extends ConsumerStatefulWidget {
  final int level;
  final String roomId;
  final VoidCallback onComplete;

  const RocketLaunchOverlay({
    super.key,
    required this.level,
    required this.roomId,
    required this.onComplete,
  });

  @override
  ConsumerState<RocketLaunchOverlay> createState() => _RocketLaunchOverlayState();
}

String? _resolveTopUid(dynamic room) {
  // 1. Try lastRocketResults (server-written, most accurate)
  if (room?.lastRocketResults != null) {
    final top3 = (room.lastRocketResults!['top3'] as List<dynamic>?) ?? [];
    if (top3.isNotEmpty && top3[0] is Map) {
      final uid = (top3[0] as Map)['uid'] as String?;
      if (uid != null && uid.isNotEmpty) return uid;
    }
  }
  // 2. Fallback to rocketContributions (may be stale/wiped but try anyway)
  final contributions = room?.rocketContributions ?? {};
  final sorted = contributions.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.isNotEmpty) return sorted.first.key;
  // 3. Fallback to owner
  return room?.ownerUid;
}

class _RocketLaunchOverlayState extends ConsumerState<RocketLaunchOverlay> {
  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.roomId));
    final room = roomAsync.value;

    // Prefer lastRocketResults (server-written accurate data) over stale rocketContributions
    final topUid = _resolveTopUid(room);

    String? profileImageUrl;
    if (topUid != null) {
      final userAsync = ref.watch(userProfileProvider(topUid));
      profileImageUrl = userAsync.value?.profilePhotoUrl;
    }

    final vapPath = RocketVapConfig.vapAssetPath(widget.level, variant: 3);

    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: VapAnimation(
              assetPath: vapPath,
              profileImageUrl: profileImageUrl,
              fit: BoxFit.contain,
              loop: false,
              onComplete: () {
                Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
              },
            ),
          ),

          Positioned(
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "LEVEL ${widget.level + 1} ROCKET",
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "LAUNCHED!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms).scale(),
          ),
        ],
      ),
    );
  }
}
