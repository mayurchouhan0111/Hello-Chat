import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';

class RocketLaunchOverlay extends ConsumerStatefulWidget {
  final int level;
  final String roomId;
  final String? ticketId;
  final VoidCallback onComplete;
  final VoidCallback? onError;

  const RocketLaunchOverlay({
    super.key,
    required this.level,
    required this.roomId,
    this.ticketId,
    required this.onComplete,
    this.onError,
  });

  @override
  ConsumerState<RocketLaunchOverlay> createState() =>
      _RocketLaunchOverlayState();
}

String? _resolveTopUid(dynamic room) {
  if (room == null) return null;
  // 1. Try lastRocketResults (server-written, most accurate)
  if (room.lastRocketResults != null) {
    final top3 = (room.lastRocketResults!['top3'] as List<dynamic>?) ?? [];
    if (top3.isNotEmpty && top3[0] is Map) {
      final uid = (top3[0] as Map)['uid'] as String?;
      if (uid != null && uid.isNotEmpty) return uid;
    }
  }
  // 2. Fallback to rocketContributions (may be stale/wiped but try anyway)
  final contributions =
      (room.rocketContributions as Map<dynamic, dynamic>?) ?? {};
  if (contributions.isNotEmpty) {
    final sorted = contributions.entries.toList()
      ..sort((a, b) => ((b.value as num?)?.toInt() ?? 0)
          .compareTo((a.value as num?)?.toInt() ?? 0));
    return sorted.first.key?.toString();
  }
  // 3. Fallback to owner
  return room.ownerUid as String?;
}

class _RocketLaunchOverlayState extends ConsumerState<RocketLaunchOverlay> {
  // Guard against duplicate completion signals (MethodChannel + watchdog race).
  bool _dismissed = false;
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    // Safety watchdog: rocket launch clip variant 3 is ~70 frames (2.3s).
    // If native decoder stalls, force complete after 6s.
    _watchdogTimer = Timer(const Duration(seconds: 6), () {
      if (!_dismissed && mounted) {
        debugPrint(
            '[RocketLaunchOverlay] Watchdog timeout triggered for ticket=${widget.ticketId}');
        _handleComplete();
      }
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    super.dispose();
  }

  void _handleComplete() {
    if (_dismissed) return;
    _dismissed = true;
    _watchdogTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vapPath = RocketVapConfig.vapAssetPath(widget.level, variant: 3);
    final room = ref.watch(currentRoomStreamProvider(widget.roomId)).value;
    final topUid = _resolveTopUid(room);
    final topProfile =
        topUid != null ? ref.watch(userProfileProvider(topUid)).value : null;
    final ownerProfile = (room?.ownerUid != null && room!.ownerUid != topUid)
        ? ref.watch(userProfileProvider(room.ownerUid)).value
        : topProfile;
    final currentProfile = ref.watch(currentUserProfileProvider).value;

    final avatarUrl = (topProfile?.profilePhotoUrl != null &&
            topProfile!.profilePhotoUrl.isNotEmpty)
        ? topProfile.profilePhotoUrl
        : (ownerProfile?.profilePhotoUrl != null &&
                ownerProfile!.profilePhotoUrl.isNotEmpty)
            ? ownerProfile.profilePhotoUrl
            : (room?.coverUrl != null && room!.coverUrl.isNotEmpty)
                ? room.coverUrl
                : currentProfile?.profilePhotoUrl;

    return RepaintBoundary(
      child: Container(
        color: Colors.black54,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              child: VapAnimation(
                key: ValueKey('launch_${widget.ticketId ?? widget.level}'),
                assetPath: vapPath,
                profileImageUrl: avatarUrl,
                fit: BoxFit.contain,
                loop: false,
                mute: true,
                onError: () {
                  widget.onError?.call();
                  _handleComplete();
                },
                onComplete: _handleComplete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
