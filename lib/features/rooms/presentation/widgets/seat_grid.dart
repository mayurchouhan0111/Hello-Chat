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
    // First registration wins the rectFor slot. Later callers (host seat,
    // minimized-room overlay) get a private key so GlobalKeys never collide.
    final existing = _keys[id];
    if (existing != null) {
      return GlobalKey(debugLabel: 'seat_${id}_${existing.hashCode}');
    }
    final key = GlobalKey(debugLabel: 'seat_$id');
    _keys[id] = key;
    return key;
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final participants = ref.watch(roomParticipantsProvider(roomId)).value ?? [];
    
    // Batch fetch all participant profiles in a single Firestore query
    final occupiedUids = participants.where((p) => p.uid.isNotEmpty).map((p) => p.uid).toList();
    if (currentUid != null && !occupiedUids.contains(currentUid)) {
      occupiedUids.add(currentUid);
    }
    final profilesAsync = ref.watch(batchedProfilesProvider(occupiedUids));
    final profiles = profilesAsync.value ?? {};
    final myProfile = currentUid != null ? ref.watch(userProfileProvider(currentUid)).value : null;
    
    int crossAxisCount = 4;
    double avatarRadius = capacity == 8 ? 24 : (capacity <= 12 ? 22 : 20);
    double iconSize = capacity == 8 ? 20 : (capacity <= 12 ? 18 : 16);
    double fontSize = capacity == 8 ? 10 : (capacity <= 12 ? 9 : 8);

    if (isYoutubeActive) {
      avatarRadius = 20;
      iconSize = 16;
      fontSize = 9;
      if (capacity == 16) {
        crossAxisCount = 8;
        avatarRadius = 14;
        iconSize = 12;
        fontSize = 7;
      } else if (capacity >= 12) {
        crossAxisCount = 6;
      } else if (capacity == 10) {
        crossAxisCount = 5;
      }
    } else {
      if (capacity >= 12) {
        crossAxisCount = 6;
      } else if (capacity == 10) {
        crossAxisCount = 5;
      }
    }

    final bool showHostInGrid = isYoutubeActive;
    final itemCount = showHostInGrid ? capacity : capacity - 1;
 
    return Padding(
      padding: isYoutubeActive 
          ? const EdgeInsets.only(top: 2, bottom: 2, left: 0, right: 0)
          : const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: isYoutubeActive ? 2 : 2,
          crossAxisSpacing: isYoutubeActive ? 4 : 4,
          mainAxisExtent: (isYoutubeActive
              ? (capacity >= 16 ? 60 : 70)
              : (capacity >= 16 ? 72 : (capacity >= 12 ? 80 : 92))) + 14,
        ),
        itemCount: itemCount,
        itemBuilder: (context, gridIndex) {
          final index = showHostInGrid ? gridIndex : gridIndex + 1;
 
          final participant = participants.firstWhere(
            (p) => p.seatIndex == index, 
            orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), isMuted: true, role: 'audience')
          );

          // ⚡ Optimistic local override for instant 0ms visual seat switching
          Participant effectiveParticipant = participant;
          if (optimisticMySeatIndex != null && currentUid != null) {
            if (index == optimisticMySeatIndex) {
              // Show current user immediately on the tapped seat
              final myExisting = participants.firstWhere((p) => p.uid == currentUid, orElse: () => participant);
              effectiveParticipant = Participant(
                uid: currentUid,
                seatIndex: index,
                joinedAt: myExisting.uid == currentUid ? myExisting.joinedAt : DateTime.now(),
                lastActive: DateTime.now(),
                isMuted: myExisting.uid == currentUid ? myExisting.isMuted : false,
                role: 'speaker',
                diamondsReceived: myExisting.uid == currentUid ? myExisting.diamondsReceived : 0,
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
            final effectiveProfile = profiles[effectiveParticipant.uid] ??
                (effectiveParticipant.uid == currentUid ? myProfile : null);
            // In non-YouTube mode the owner also renders in the separate global
            // host widget (which registers its own anchor). One uid may only
            // hold one GlobalKey per tree, so the grid cell steps aside.
            final anchorUid =
                (!isYoutubeActive && effectiveParticipant.uid == ownerUid) ? null : effectiveParticipant.uid;
            return KeyedSubtree(
              key: anchorUid != null ? SeatAnchors.keyFor(roomId, anchorUid) : null,
              child: OccupiedSeatWidget(
                key: ValueKey('occupied_${index}_${effectiveParticipant.uid}_${effectiveParticipant.diamondsReceived}'),
                participant: effectiveParticipant,
                roomId: roomId,
                index: index,
                radius: avatarRadius,
                iconSize: iconSize,
                fontSize: fontSize,
                currentUid: currentUid,
                onSeatTap: onSeatTap,
                onSeatLongPress: onSeatLongPress,
                userProfile: effectiveProfile,
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
  final Function(int) onSeatTap;
  final Function(int) onSeatLongPress;
  final UserModel? userProfile;

  const OccupiedSeatWidget({
    super.key,
    required this.participant,
    required this.roomId,
    required this.index,
    required this.radius,
    required this.iconSize,
    required this.fontSize,
    required this.currentUid,
    required this.onSeatTap,
    required this.onSeatLongPress,
    this.userProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveUserAsync = ref.watch(userProfileProvider(participant.uid));
    final liveUser = liveUserAsync.valueOrNull ?? userProfile;
    final roomData = ref.watch(currentRoomStreamProvider(roomId)).value;
    final isParticipantAdmin = roomData?.isUserAdmin(participant.uid) ?? false;

    final user = liveUser ?? UserModel(
      uid: participant.uid,
      createdAt: participant.joinedAt,
      phoneNumber: null,
      username: participant.displayName.isNotEmpty ? participant.displayName : 'User',
      displayName: participant.displayName.isNotEmpty ? participant.displayName : 'User',
      profilePhotoUrl: participant.profilePhotoUrl,
      profileFrame: participant.profileFrame,
      vipTier: participant.vipTier,
      level: participant.level,
      tags: participant.tags,
      badges: participant.tags,
      helloId: participant.helloId,
      lastActive: participant.lastActive,
      role: participant.role,
    );

    final String photoUrl = user.profilePhotoUrl.isNotEmpty 
        ? user.profilePhotoUrl 
        : (participant.profilePhotoUrl.isNotEmpty ? participant.profilePhotoUrl : '');

    return RepaintBoundary(
      child: GestureDetector(
        key: ValueKey('seat_${index}_${participant.uid}'),
        onTap: () => onSeatTap(index),
        onLongPress: () => onSeatLongPress(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: Builder(
              builder: (context) {
                final displayFrame = user.profileFrame;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (!participant.isMuted) SpeakingBorderWidget(user: user, radius: radius),
                    Stack(
                      alignment: Alignment.bottomRight,
                      clipBehavior: Clip.none,
                      children: [
                        OverflowBox(
                          maxWidth: radius * 2.5,
                          maxHeight: radius * 2.5,
                          child: AppAvatar(
                            imageUrl: photoUrl,
                            frameUrl: displayFrame,
                            vipTier: user.vipTier,
                            userLevel: user.level,
                            tags: user.tags,
                            radius: radius,
                            showFrame: true,
                            frameMultiplier: 1.5,
                          ),
                        ),
                        if (participant.isMuted)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Icon(Icons.mic_off, color: Colors.white, size: radius > 22 ? 11 : 9),
                            ),
                          ),
                      ],
                    ),
                    SeatEmojiReactionWidget(uid: participant.uid),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          if (isParticipantAdmin) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
              ),
              child: const Text(
                "Admin",
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 2),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: radius * 2 + 16),
              child: SizedBox(
                height: fontSize + 4,
                child: Center(
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName : participant.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: fontSize, 
                      fontWeight: FontWeight.bold,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("💎", style: TextStyle(fontSize: 7)),
                const SizedBox(width: 2),
                Text(
                  participant.diamondsReceived >= 1000
                      ? '${(participant.diamondsReceived / 1000).toStringAsFixed(1)}k'
                      : '${participant.diamondsReceived}',
                  style: TextStyle(color: Colors.yellowAccent, fontSize: fontSize - 1, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // ⚡ QUICK SEND COMBO BADGE
          // Stamped by sendGiftWithCombo on rooms/{roomId}/participants/{uid}.
          // Mirrors the live xN on the sender's combo bar so the receiver's seat
          // shows the current streak level.
          if (participant.comboCount > 1)
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 220),
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF6A00)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF9100).withOpacity(0.5), blurRadius: 6),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.black, size: 9),
                    const SizedBox(width: 1),
                    Text(
                      'x${participant.comboCount}',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSize - 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
    final speakingUids = ref.watch(speakingUidsProvider).value ?? [];
    final int agoraUid = user.uid.hashCode & 0xFFFFFFFF;
    final bool isSpeaking = speakingUids.contains(agoraUid);
    final hasFrame = user.profileFrame.isNotEmpty && user.profileFrame.toLowerCase() != 'none';

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
      ).animate()
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

  const EmptySeatWidget({
    super.key,
    required this.index,
    required this.radius,
    required this.iconSize,
    required this.fontSize,
    required this.isLocked,
    required this.onSeatTap,
    required this.onSeatLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('seat_empty_$index'),
      onTap: () => onSeatTap(index),
      onLongPress: () => onSeatLongPress(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: isLocked ? Colors.black38 : Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: isLocked ? Colors.redAccent.withOpacity(0.3) : Colors.white10, width: 1.5),
            ),
            child: Icon(
              isLocked ? Icons.lock_rounded : Icons.chair_alt_rounded, 
              color: isLocked ? Colors.redAccent.withOpacity(0.7) : Colors.white38, 
              size: iconSize * (isLocked ? 0.9 : 1.0)
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: fontSize + 4,
            child: Center(
              child: isLocked 
                  ? Text("Locked", style: TextStyle(color: Colors.redAccent.withOpacity(0.6), fontSize: fontSize, fontWeight: FontWeight.bold))
                  : Text(index == 0 ? "Owner" : "$index", style: TextStyle(color: Colors.white70, fontSize: fontSize, fontWeight: FontWeight.bold)),
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

class _SpeakingRippleBorderState extends State<_SpeakingRippleBorder> with SingleTickerProviderStateMixin {
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
    final double borderSize = widget.hasFrame ? widget.radius * 5.2 : widget.radius * 2.5;

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
    return oldDelegate.progress != progress || oldDelegate.borderSize != borderSize;
  }
}
