import 'package:flutter/material.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/models/emoji_reaction.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/svga_player.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_reactions_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SeatGrid extends ConsumerWidget {
  final String roomId;
  final int capacity;
  final Function(int) onSeatTap;
  final Function(int) onSeatLongPress;
  final Function(Participant) onUserLongPress;
  final List<int> lockedSeats;
  final bool isYoutubeActive;
  final String ownerUid;

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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final participants = ref.watch(roomParticipantsProvider(roomId)).value ?? [];
    
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
              ? (capacity >= 16 ? 56 : 64)
              : (capacity >= 16 ? 64 : (capacity >= 12 ? 72 : 82))) + 12,
        ),
        itemCount: itemCount,
        itemBuilder: (context, gridIndex) {
          final index = showHostInGrid ? gridIndex : gridIndex + 1;
 
          final participant = participants.firstWhere(
            (p) => p.seatIndex == index, 
            orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), isMuted: true, role: 'audience')
          );

          final isLocked = lockedSeats.contains(index);
          final isOccupied = participant.uid.isNotEmpty;

          if (isOccupied) {
            return OccupiedSeatWidget(
              key: ValueKey('occupied_${index}_${participant.uid}'),
              participant: participant,
              index: index,
              radius: avatarRadius,
              iconSize: iconSize,
              fontSize: fontSize,
              currentUid: currentUid,
              onSeatTap: onSeatTap,
              onSeatLongPress: onSeatLongPress,
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
  final Function(int) onSeatTap;
  final Function(int) onSeatLongPress;

  const OccupiedSeatWidget({
    super.key,
    required this.participant,
    required this.index,
    required this.radius,
    required this.iconSize,
    required this.fontSize,
    required this.currentUid,
    required this.onSeatTap,
    required this.onSeatLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(cachedUserProfileProvider(participant.uid));

    return GestureDetector(
      key: ValueKey('seat_${index}_${participant.uid}'),
      onTap: () => onSeatTap(index),
      onLongPress: () => onSeatLongPress(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: userAsync.when(
              data: (user) {
                if (user == null) {
                  return Icon(Icons.error, color: Colors.red, size: radius);
                }
                final u = user as UserModel;
                final displayFrame = u.profileFrame;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (!participant.isMuted) SpeakingBorderWidget(user: u, radius: radius),
                    Stack(
                      alignment: Alignment.bottomRight,
                      clipBehavior: Clip.none,
                      children: [
                        OverflowBox(
                          maxWidth: radius * 3.2,
                          maxHeight: radius * 3.2,
                          child: AppAvatar(
                            imageUrl: u.profilePhotoUrl,
                            frameUrl: displayFrame,
                            vipTier: u.vipTier,
                            userLevel: u.level,
                            tags: u.tags,
                            radius: radius,
                            showFrame: true,
                            frameMultiplier: 2.1,
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
              loading: () => Center(
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.5)),
                ),
              ),
              error: (_, __) => Icon(Icons.error, color: Colors.red, size: radius),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: fontSize + 4,
            child: Center(
              child: userAsync.when(
                data: (user) => Text(
                  (user as UserModel?)?.displayName ?? "User",
                  style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                loading: () => Text("...", style: TextStyle(color: Colors.white, fontSize: fontSize)),
                error: (_, __) => Text("?", style: TextStyle(color: Colors.white, fontSize: fontSize)),
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
    final speakingUids = ref.watch(speakingUidsProvider).value ?? [];
    final int agoraUid = user.uid.hashCode & 0xFFFFFFFF;
    final bool isSpeaking = speakingUids.contains(agoraUid);
    final hasFrame = user.profileFrame.isNotEmpty;
    final wavesPath = getVipMicWavesPath(user.vipTier);

    if (!isSpeaking) return const SizedBox.shrink();

    Widget borderChild;
    if (wavesPath != null) {
      borderChild = OverflowBox(
        maxWidth: radius * 7.0,
        maxHeight: radius * 7.0,
        child: SizedBox(
          width: radius * 6.2,
          height: radius * 6.2,
          child: IgnorePointer(
            child: SvgaPlayer(
              key: ValueKey('speaking_sound_waves_${user.vipTier}'),
              assetPath: wavesPath,
            ),
          ),
        ),
      );
    } else {
      borderChild = _buildDefaultSpeakingBorder(radius, hasFrame);
    }

    return RepaintBoundary(child: borderChild);
  }

  Widget _buildDefaultSpeakingBorder(double radius, bool hasFrame) {
    final double borderSize = hasFrame ? radius * 5.2 : radius * 2.5;
    return Stack(
      alignment: Alignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            width: borderSize,
            height: borderSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.cyanAccent.withOpacity(0.5),
                width: 2.0,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.5, 1.5),
                duration: 1200.ms,
                delay: (i * 400).ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(duration: 1200.ms),
      ],
    );
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
