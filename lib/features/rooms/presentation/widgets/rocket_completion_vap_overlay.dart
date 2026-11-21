import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';

class RocketCompletionVapOverlay extends ConsumerStatefulWidget {
  final int level;
  final String roomId;
  final String? ticketId;
  final VoidCallback onComplete;
  final VoidCallback? onError;

  const RocketCompletionVapOverlay({
    super.key,
    required this.level,
    required this.roomId,
    this.ticketId,
    required this.onComplete,
    this.onError,
  });

  @override
  ConsumerState<RocketCompletionVapOverlay> createState() =>
      _RocketCompletionVapOverlayState();
}

String? _resolveTopUid(dynamic room) {
  if (room == null) return null;
  if (room.lastRocketResults != null) {
    final top3 = (room.lastRocketResults!['top3'] as List<dynamic>?) ?? [];
    if (top3.isNotEmpty && top3[0] is Map) {
      final uid = (top3[0] as Map)['uid'] as String?;
      if (uid != null && uid.isNotEmpty) return uid;
    }
  }
  final contributions =
      (room.rocketContributions as Map<dynamic, dynamic>?) ?? {};
  if (contributions.isNotEmpty) {
    final sorted = contributions.entries.toList()
      ..sort((a, b) => ((b.value as num?)?.toInt() ?? 0)
          .compareTo((a.value as num?)?.toInt() ?? 0));
    return sorted.first.key?.toString();
  }
  return room.ownerUid as String?;
}

class _RocketCompletionVapOverlayState
    extends ConsumerState<RocketCompletionVapOverlay> {
  bool _showVariant2 = false;
  // Guard against duplicate completion signals (MethodChannel + watchdog race).
  bool _dismissed = false;
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    _showVariant2 = false;
    _armWatchdog();
  }

  void _armWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 8), () {
      if (!_dismissed && mounted) {
        debugPrint(
            '[RocketCompletionVapOverlay] Watchdog timeout triggered for ticket=${widget.ticketId}');
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
    final needsSequence = widget.level >= 3;
    final variant = needsSequence ? (_showVariant2 ? 2 : 1) : 1;
    final vapPath =
        RocketVapConfig.vapAssetPath(widget.level, variant: variant);

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

    return SizedBox.expand(
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              VapAnimation(
                key: ValueKey('completion_${widget.level}_$_showVariant2'),
                assetPath: vapPath,
                profileImageUrl: avatarUrl,
                fit: BoxFit.contain,
                loop: false,
                onError: () {
                  widget.onError?.call();
                  _handleComplete();
                },
                onComplete: () {
                  if (_dismissed) return;
                  if (needsSequence && !_showVariant2) {
                    setState(() => _showVariant2 = true);
                    _armWatchdog();
                  } else {
                    _handleComplete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
