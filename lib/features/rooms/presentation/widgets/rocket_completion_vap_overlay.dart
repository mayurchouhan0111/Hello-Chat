import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/models/user_model.dart';

class RocketCompletionVapOverlay extends ConsumerStatefulWidget {
  final int level;
  final String roomId;
  final VoidCallback onComplete;

  const RocketCompletionVapOverlay({
    super.key,
    required this.level,
    required this.roomId,
    required this.onComplete,
  });

  @override
  ConsumerState<RocketCompletionVapOverlay> createState() => _RocketCompletionVapOverlayState();
}

class _RocketCompletionVapOverlayState extends ConsumerState<RocketCompletionVapOverlay> {
  bool _showVariant2 = false;

  @override
  void initState() {
    super.initState();
    _showVariant2 = false;
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.roomId));
    final room = roomAsync.value;

    UserModel? topUser;
    if (room != null) {
      // Prefer lastRocketResults (server-written accurate top 3) over stale rocketContributions
      String? topUid;
      if (room.lastRocketResults != null) {
        final top3 = (room.lastRocketResults!['top3'] as List<dynamic>?) ?? [];
        if (top3.isNotEmpty && top3[0] is Map) {
          topUid = (top3[0] as Map)['uid'] as String?;
        }
      }
      if (topUid == null || topUid.isEmpty) {
        final contributions = room.rocketContributions ?? {};
        final sorted = contributions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topUid = sorted.isNotEmpty ? sorted.first.key : null;
      }
      final targetUid = topUid ?? room.ownerUid;
      final userAsync = ref.watch(userProfileProvider(targetUid));
      topUser = userAsync.value;
    }

    final needsSequence = widget.level >= 3;
    final variant = needsSequence ? (_showVariant2 ? 2 : 1) : 1;
    final vapPath = RocketVapConfig.vapAssetPath(widget.level, variant: variant);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            VapAnimation(
              key: ValueKey('completion_${widget.level}_$_showVariant2'),
              assetPath: vapPath,
              profileImageUrl: topUser?.profilePhotoUrl,
              fit: BoxFit.contain,
              loop: false,
              onComplete: () {
                if (needsSequence && !_showVariant2) {
                  setState(() => _showVariant2 = true);
                } else {
                  Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
                }
              },
            ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFF00FFFF).withOpacity(0.4)),
                  ),
                  child: Text(
                    "LEVEL ${widget.level + 1} ROCKET LAUNCHED!",
                    style: const TextStyle(
                      color: Color(0xFF00FFFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
