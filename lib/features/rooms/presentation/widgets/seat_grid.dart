import 'dart:math' as math;

import '../../../../core/models/room_theme_model.dart';
import 'package:flutter/material.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_reactions_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/svip_level_model.dart';
import '../../../../core/widgets/svga_player.dart';

/// Registry of GlobalKeys for occupied seat cells so the gift overlay can
/// resolve a receiver's on-screen rect (Layer 1 seat-anchored effects).
///
/// Keys are scoped `$roomId|$uid`: two rooms can be mounted at once
/// (minimized-room overlay) and a GlobalKey may only appear once per tree.
class SeatAnchors {
  SeatAnchors._();

  static final Map<String, GlobalKey> _keys = {};

  static GlobalKey keyFor(String roomId, String uid) {
    final id = '$roomId|$uid';
    return _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'seat_$id'));
  }

  /// Global rect of the seat cell, or null when the seat isn't laid out
  /// (empty seat, first frames after mount, recipient offline).
  static Rect? rectFor(String roomId, String uid) {
    if (uid.isEmpty) return null;
    final ctx = _keys['$roomId|$uid']?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static void clearRoom(String roomId) {
    final prefix = '$roomId|';
    _keys.removeWhere((key, _) => key.startsWith(prefix));
  }
}

class SeatGrid extends ConsumerWidget {
  final String roomId;
  final int capacity;
  final Function(int) onSeatTap;
  final Function(int) onSeatLongPress;
  final Function(Participant) onUserLongPress;
  final List<int> lockedSeats;
  final bool isYoutubeActive;
  final String ownerUid;
  final int? optimisticMySeatIndex;
  final RoomTheme? theme;

  const SeatGrid({
    super.key,
    required this.roomId,
    required this.capacity,
    required this.onSeatTap,
    required this.onSeatLongPress,
    required this.onUserLongPress,
    this.lockedSeats = const [],
    this.isYoutubeActive = false,
    this.ownerUid = '',
    this.optimisticMySeatIndex,
    this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final participants =
        ref.watch(roomParticipantsProvider(roomId)).value ?? [];

    int crossAxisCount = 4;
    double avatarRadius = 26;
    double iconSize = 22;
    double fontSize = 10;

    if (isYoutubeActive) {
      avatarRadius = 20;
      iconSize = 16;
      fontSize = 9;
      if (capacity >= 16) {
        crossAxisCount = 8;
        avatarRadius = 16;
        iconSize = 13;
        fontSize = 7.5;
      } else if (capacity >= 12) {
        crossAxisCount = 6;
      } else if (capacity == 10) {
        crossAxisCount = 5;
      }
    } else {
      if (capacity == 8) {
        crossAxisCount = 4; // 2 rows of 4
        avatarRadius = 26;
        iconSize = 22;
        fontSize = 10;
      } else if (capacity == 9) {
        crossAxisCount = 4; // 2 rows of 4 (+ host)
        avatarRadius = 25;
        iconSize = 21;
        fontSize = 10;
      } else if (capacity == 12) {
        crossAxisCount = 4; // 3 rows of 4
        avatarRadius = 22;
        iconSize = 18;
        fontSize = 9;
      } else if (capacity == 13) {
        crossAxisCount = 4; // 3 rows of 4 (+ host)
        avatarRadius = 22;
        iconSize = 18;
        fontSize = 9;
      } else if (capacity >= 16) {
        crossAxisCount = 4; // 4 rows of 4
        avatarRadius = 19;
        iconSize = 15;
        fontSize = 8.5;
      } else if (capacity == 10) {
        crossAxisCount = 5;
        avatarRadius = 22;
        iconSize = 18;
        fontSize = 9;
      }
    }

    final bool showHostInGrid = isYoutubeActive;
    final itemCount = (showHostInGrid ? capacity : capacity - 1).clamp(0, 16);

    final scaler = MediaQuery.textScalerOf(context);
    final portraitExtent = avatarRadius * 2 + 12;
    final rowExtent = portraitExtent +
        12 +
        scaler.scale(fontSize) * 1.25 +
        scaler.scale(fontSize - 1) * 1.25;
    final double spacing = capacity >= 16 ? 2.0 : (capacity >= 12 ? 3.0 : 4.0);
    return Padding(
      padding: isYoutubeActive
          ? const EdgeInsets.only(top: 2, bottom: 2, left: 0, right: 0)
          : const EdgeInsets.only(top: 4, bottom: 4, left: 0, right: 0),
      child: GridView.builder(
        primary: false,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: 4,
          mainAxisExtent: rowExtent.ceilToDouble(),
        ),
        itemCount: itemCount,
        itemBuilder: (context, gridIndex) {
          final index = showHostInGrid ? gridIndex : gridIndex + 1;

          final participant = participants.firstWhere(
              (p) => p.seatIndex == index,
              orElse: () => Participant(
                  uid: index == 0 && ownerUid.isNotEmpty ? ownerUid : '',
                  displayName: index == 0 && ownerUid.isNotEmpty ? 'Owner' : '',
                  joinedAt: DateTime.now(),
                  lastActive: DateTime.now(),
                  isMuted: true,
                  role:
                      index == 0 && ownerUid.isNotEmpty ? 'owner' : 'audience',
                  seatIndex: index));

          // ⚡ Optimistic local override for instant 0ms visual seat switching
          Participant effectiveParticipant = participant;
          if (optimisticMySeatIndex != null && currentUid != null) {
            if (index == optimisticMySeatIndex) {
              // Show current user immediately on the tapped seat
              final myExisting = participants.firstWhere(
                  (p) => p.uid == currentUid,
                  orElse: () => participant);
              effectiveParticipant = Participant(
                uid: currentUid,
                seatIndex: index,
                joinedAt: myExisting.uid == currentUid
                    ? myExisting.joinedAt
                    : DateTime.now(),
                lastActive: DateTime.now(),
                isMuted:
                    myExisting.uid == currentUid ? myExisting.isMuted : false,
                role: 'speaker',
                diamondsReceived: myExisting.uid == currentUid
                    ? myExisting.diamondsReceived
                    : 0,
              );
            } else if (participant.uid == currentUid) {
              // Current user has moved away from this seat
              effectiveParticipant = Participant(
                uid: '',
                joinedAt: DateTime.now(),
                lastActive: DateTime.now(),
                isMuted: true,
                role: 'audience',
              );
            }
          }

          final isLocked = lockedSeats.contains(index);
          final isOccupied = effectiveParticipant.uid.isNotEmpty;

          if (isOccupied) {
            // In non-YouTube mode the owner also renders in the separate global
            // host widget (which registers its own anchor). One uid may only
            // hold one GlobalKey per tree, so the grid cell steps aside.
            final anchorUid =
                (!isYoutubeActive && effectiveParticipant.uid == ownerUid)
                    ? null
                    : effectiveParticipant.uid;
            return KeyedSubtree(
              key: anchorUid != null
                  ? SeatAnchors.keyFor(roomId, anchorUid)
                  : null,
              child: OccupiedSeatWidget(
                key: ValueKey('occupied_${index}_${effectiveParticipant.uid}'),
                participant: effectiveParticipant,
                roomId: roomId,
                index: index,
                radius: avatarRadius,
                iconSize: iconSize,
                fontSize: fontSize,
                currentUid: currentUid,
                isOwner: effectiveParticipant.uid == ownerUid,
                online:
                    participants.any((p) => p.uid == effectiveParticipant.uid),
                onSeatTap: onSeatTap,
                onSeatLongPress: onSeatLongPress,
                theme: theme,
              ),
            );
          }

          return EmptySeatWidget(
            index: index,
            radius: avatarRadius,
            iconSize: iconSize,
            fontSize: fontSize,
            isLocked: isLocked,
            onSeatTap: onSeatTap,
            onSeatLongPress: onSeatLongPress,
            theme: theme,
          );
        },
      ),
    );
  }
}

class OccupiedSeatWidget extends ConsumerWidget {
  final Participant participant;
  final int index;
  final double radius;
  final double iconSize;
  final double fontSize;
  final String? currentUid;
  final String roomId;
  final bool isOwner;
  final bool online;
  final Function(int) onSeatTap;
  final Function(int) onSeatLongPress;
  final UserModel? userProfile;
  final RoomTheme? theme;

  const OccupiedSeatWidget({
    super.key,
    required this.participant,
    required this.roomId,
    required this.index,
    required this.radius,
    required this.iconSize,
    required this.fontSize,
    required this.currentUid,
    this.isOwner = false,
    this.online = true,
    required this.onSeatTap,
    required this.onSeatLongPress,
    this.userProfile,
    this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveUserAsync = ref.watch(userProfileProvider(participant.uid));
    final liveUser = liveUserAsync.valueOrNull ?? userProfile;
    return RepaintBoundary(
      child: GestureDetector(
        key: ValueKey('seat_${index}_${participant.uid}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSeatTap(index),
        onLongPress: () => onSeatLongPress(index),
        child: RoomSeatPortrait(
          participant: participant,
          profile: liveUser,
          extent: radius * 2 + 12,
          fontSize: fontSize,
          isOwner: isOwner,
          online: online,
        ),
      ),
    );
  }
}

/// The frame, speaking effect and reactions share a measured portrait area.
/// Captions always start below its paint boundary, including for still frames
/// that AppAvatar shifts upwards.
class RoomSeatPortrait extends StatelessWidget {
  const RoomSeatPortrait({
    super.key,
    required this.participant,
    required this.profile,
    required this.extent,
    required this.fontSize,
    this.isOwner = false,
    this.online = true,
  });

  final Participant participant;
  final UserModel? profile;
  final double extent;
  final double fontSize;
  final bool isOwner;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final user = profile;
    final name = user != null && user.displayName.isNotEmpty
        ? user.displayName
        : participant.displayName;
    final photo = user != null && user.profilePhotoUrl.isNotEmpty
        ? user.profilePhotoUrl
        : participant.profilePhotoUrl;
    final frame = user != null && user.profileFrame.isNotEmpty
        ? user.profileFrame
        : participant.profileFrame;
    final displayId = user != null && user.displayId.isNotEmpty
        ? user.displayId
        : (user?.helloId?.toString() ?? participant.helloId?.toString() ?? '');
    final total = participant.diamondsReceived;
    final amount = total >= 1000000
        ? '${(total / 1000000).toStringAsFixed(1)}M'
        : total >= 1000
            ? '${(total / 1000).toStringAsFixed(1)}k'
            : '$total';
    const shadow = [
      Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1))
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(extent, constraints.maxWidth);
      final radius = side / 3.25;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              height: extent,
              child: Center(
                  child: ClipRect(
                child: SizedBox.square(
                  dimension: side,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (online && !participant.isMuted && user != null)
                        SpeakingBorderWidget(user: user, radius: radius),
                      Opacity(
                        opacity: online ? 1 : 0.5,
                        child: AppAvatar(
                          imageUrl: photo,
                          frameUrl: frame,
                          vipTier: user?.vipTier ?? participant.vipTier,
                          svipLevel: user?.svipLevel,
                          userLevel: user?.level ?? participant.level,
                          tags: user?.tags ?? participant.tags,
                          radius: radius,
                          frameMultiplier: 1.45,
                          uniformFrameSize: true,
                        ),
                      ),
                      SizedBox.square(
                        dimension: radius * 2,
                        child: Stack(children: [
                          SeatEmojiReactionWidget(uid: participant.uid)
                        ]),
                      ),
                    ],
                  ),
                ),
              ))),
          const SizedBox(height: 2),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xB30B0E1B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOwner) ...[
                    Icon(Icons.workspace_premium_rounded,
                        size: fontSize,
                        color:
                            online ? const Color(0xFFFFD77B) : Colors.white60,
                        semanticLabel: online ? 'Host' : 'Host offline'),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          height: 1.25,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (participant.isMuted && online) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.mic_off_rounded,
                        size: fontSize,
                        color: const Color(0xFFFFB8BB),
                        semanticLabel: 'Microphone muted'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          if (isOwner)
            Text(
              displayId.isEmpty ? 'ID unavailable' : 'ID: $displayId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFFE082),
                fontSize: fontSize - 1,
                height: 1.25,
                fontWeight: FontWeight.w600,
                shadows: shadow,
              ),
            )
          else
            Semantics(
              label: '$total Diamonds received',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.diamond_rounded,
                      size: fontSize,
                      color: const Color(0xFF9EE5FF),
                      shadows: shadow),
                  const SizedBox(width: 2),
                  Flexible(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(amount,
                              maxLines: 1,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: fontSize - 1,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  shadows: shadow)))),
                ],
              ),
            ),
        ],
      );
    });
  }
}

/// Room-owner-only portrait composition. Normal room seats intentionally keep
/// using [RoomSeatPortrait] so owner styling can never resize their frames.
class RoomOwnerSeatPortrait extends StatelessWidget {
  const RoomOwnerSeatPortrait({
    super.key,
    required this.participant,
    required this.profile,
    this.online = true,
  });

  final Participant participant;
  final UserModel? profile;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final user = profile;
    final name = user != null && user.displayName.isNotEmpty
        ? user.displayName
        : participant.displayName;
    final photo = user != null && user.profilePhotoUrl.isNotEmpty
        ? user.profilePhotoUrl
        : participant.profilePhotoUrl;
    final frame = user != null && user.profileFrame.isNotEmpty
        ? user.profileFrame
        : participant.profileFrame;
    final displayId =
        user != null ? user.displayId : (participant.helloId?.toString() ?? '');
    final total = participant.diamondsReceived;
    final amount = total >= 1000000
        ? '${(total / 1000000).toStringAsFixed(1)}M'
        : total >= 1000
            ? '${(total / 1000).toStringAsFixed(1)}k'
            : '$total';

    return SizedBox(
      width: 140,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Snug avatar box: no unnecessary empty gaps below the seat
          SizedBox(
            width: 120,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox.square(
                  // A 62 dp portrait paints a 90 dp frame. Include its
                  // upward offset for still artwork in the clip bounds.
                  dimension: 100,
                  child: ClipRect(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (online && !participant.isMuted && user != null)
                          SpeakingBorderWidget(user: user, radius: 31),
                        Opacity(
                          opacity: online ? 1 : 0.55,
                          child: AppAvatar(
                            imageUrl: photo,
                            frameUrl: frame,
                            vipTier: user?.vipTier ?? participant.vipTier,
                            svipLevel: user?.svipLevel,
                            userLevel: user?.level ?? participant.level,
                            tags: user?.tags ?? participant.tags,
                            radius: 31,
                            frameMultiplier: 1.45,
                            uniformFrameSize: true,
                          ),
                        ),
                        SizedBox.square(
                          dimension: 62,
                          child: Stack(children: [
                            SeatEmojiReactionWidget(uid: participant.uid)
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                if (participant.isMuted && online)
                  Positioned(
                    top: 1,
                    right: 18,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE64855),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 3)
                        ],
                      ),
                      child: const Icon(Icons.mic_off_rounded,
                          size: 11,
                          color: Colors.white,
                          semanticLabel: 'Microphone muted'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Owner's ID and Name directly below the seat
          Container(
            constraints: const BoxConstraints(maxWidth: 130),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xEE0B0E1B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x44FFD54F), width: 0.8),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        size: 11.5, color: Color(0xFFFFD45C)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (displayId.isNotEmpty && displayId != 'User') ...[
                  const SizedBox(height: 1),
                  Text(
                    'ID: $displayId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 8.5,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 1),
            Semantics(
              label: '$total Diamonds received',
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xB8101322),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond_rounded,
                        size: 10, color: Color(0xFF9EE5FF)),
                    const SizedBox(width: 2.5),
                    Text(amount,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SpeakingBorderWidget extends ConsumerWidget {
  final UserModel user;
  final double radius;

  const SpeakingBorderWidget({
    super.key,
    required this.user,
    required this.radius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int agoraUid = user.uid.hashCode & 0xFFFFFFFF;
    final bool isSpeaking = ref.watch(
      speakingUidsProvider
          .select((asyncVal) => (asyncVal.value ?? []).contains(agoraUid)),
    );
    final hasFrame = user.profileFrame.isNotEmpty &&
        user.profileFrame.toLowerCase() != 'none';

    if (!isSpeaking) return const SizedBox.shrink();

    // Check equipped mic wave (aperture decoration)
    final micWave = user.equippedMicWave;
    final isExplicitNone = micWave.toLowerCase() == 'none';
    String? waveAsset;
    if (!isExplicitNone && micWave.isNotEmpty) {
      waveAsset = micWave;
    } else if (!isExplicitNone) {
      final svip = user.svipLevel ?? 0;
      if (svip > 0) {
        waveAsset = SVIPLevelModel.getLevelByTier(svip).micWaveAsset;
      } else if (user.isVipActive) {
        waveAsset = getVipMicWavesPath(user.vipTier);
      }
    }

    if (waveAsset != null && waveAsset.isNotEmpty) {
      final double waveSize = hasFrame ? radius * 5.2 : radius * 3.2;
      return RepaintBoundary(
        child: SizedBox(
          width: waveSize,
          height: waveSize,
          child: IgnorePointer(
            child: SvgaPlayer(
              key: ValueKey('mic_wave_${user.uid}_$waveAsset'),
              assetPath: waveAsset,
              fit: BoxFit.contain,
              loop: true,
            ),
          ),
        ),
      );
    }

    final borderChild = _buildDefaultSpeakingBorder(radius, hasFrame);

    return RepaintBoundary(child: borderChild);
  }

  Widget _buildDefaultSpeakingBorder(double radius, bool hasFrame) {
    return _SpeakingRippleBorder(radius: radius, hasFrame: hasFrame);
  }
}

class SeatEmojiReactionWidget extends ConsumerWidget {
  final String uid;

  const SeatEmojiReactionWidget({
    super.key,
    required this.uid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions = ref.watch(emojiReactionsProvider);
    final reaction = reactions[uid];
    if (reaction == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: ClipOval(
          child: Image.asset(
            reaction.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 200.ms)
          .scale(
            begin: const Offset(0.3, 0.3),
            end: const Offset(1.0, 1.0),
            duration: 400.ms,
            curve: Curves.easeOutBack,
          )
          .fadeOut(duration: 400.ms, delay: 1100.ms),
    );
  }
}

class EmptySeatWidget extends StatelessWidget {
  final int index;
  final double radius;
  final double iconSize;
  final double fontSize;
  final bool isLocked;
  final Function(int) onSeatTap;
  final Function(int) onSeatLongPress;
  final RoomTheme? theme;

  const EmptySeatWidget({
    super.key,
    required this.index,
    required this.radius,
    required this.iconSize,
    required this.fontSize,
    required this.isLocked,
    required this.onSeatTap,
    required this.onSeatLongPress,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = isLocked
        ? const Color(0xFFFF4D4D)
        : (theme?.seatRingColor ?? const Color(0x99FFFFFF));
    final glowColor = isLocked
        ? const Color(0x66FF4D4D)
        : (theme?.accentColor.withValues(alpha: 0.35) ??
            const Color(0x33FFFFFF));

    return GestureDetector(
      key: ValueKey('seat_empty_$index'),
      onTap: () => onSeatTap(index),
      onLongPress: () => onSeatLongPress(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: radius * 2 + 12,
            child: Center(
                child: Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLocked
                      ? [const Color(0xFF321414), const Color(0xFF1B0A0A)]
                      : [const Color(0xEE161D30), const Color(0xEE090D18)],
                ),
                border: Border.all(
                  color: ringColor,
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.70),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isLocked ? Icons.lock_rounded : Icons.chair_alt_rounded,
                  color: isLocked ? const Color(0xFFFF5252) : Colors.white,
                  size: iconSize * (isLocked ? 0.9 : 1.05),
                  shadows: const [
                    Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(0, 1)),
                  ],
                ),
              ),
            )),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xEE0B0E1B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isLocked
                    ? const Color(0x66FF4D4D)
                    : Colors.white.withValues(alpha: 0.22),
                width: 0.8,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: isLocked
                ? Text(
                    "Locked",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFFF6B6B),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  )
                : Text(
                    index == 0 ? "Owner" : "$index",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 3),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

int getVipLevel(String vipTierName) {
  final clean = vipTierName.toLowerCase().replaceAll(' ', '');
  if (clean.startsWith('vip')) {
    final numStr = clean.substring(3);
    final val = int.tryParse(numStr);
    if (val != null) return val;
  }
  return 0;
}

String? getVipMicWavesPath(String vipTierName) {
  final level = getVipLevel(vipTierName);
  if (level == 1) {
    return 'assets/VIP/VIP 1/Sound Waives.svga';
  } else if (level == 2) {
    return 'assets/VIP/VIP 2/VIP 2/Mic Waives.svga';
  } else if (level >= 3 && level <= 8) {
    return 'assets/VIP/VIP $level/VIP $level/Mic Waives.svga';
  }
  return null;
}

class _SpeakingRippleBorder extends StatefulWidget {
  final double radius;
  final bool hasFrame;

  const _SpeakingRippleBorder({required this.radius, required this.hasFrame});

  @override
  State<_SpeakingRippleBorder> createState() => _SpeakingRippleBorderState();
}

class _SpeakingRippleBorderState extends State<_SpeakingRippleBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double borderSize = widget.radius * (widget.hasFrame ? 2.65 : 2.1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(borderSize * 1.5, borderSize * 1.5),
          painter: _SpeakingRipplePainter(
            _controller.value,
            borderSize,
          ),
        );
      },
    );
  }
}

class _SpeakingRipplePainter extends CustomPainter {
  final double progress;
  final double borderSize;

  _SpeakingRipplePainter(this.progress, this.borderSize);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final delay = i * 0.33;
      final t = (progress - delay).clamp(0.0, 1.0);
      final scale = 1.0 + t * 0.5;
      final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.5;

      final paint = Paint()
        ..color = Colors.cyanAccent.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, borderSize / 2 * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeakingRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderSize != borderSize;
  }
}
