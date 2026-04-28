import 'package:flutter/material.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/providers/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SeatGrid extends ConsumerWidget {
  final List<Participant> participants;
  final int capacity;
  final Function(int) onSeatTap;
  final Function(int) onSeatLongPress;
  final Function(Participant) onUserLongPress;
  final List<int> lockedSeats;
  final bool isYoutubeActive;
  final String ownerUid;

  const SeatGrid({
    super.key,
    required this.participants,
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
    
    // 🪑 Dynamic Grid Logic: Adjust columns and sizes based on YouTube activity
    // 🪑 Standard 4x4 Grid for all layouts, but if YouTube is active, use 6 columns for 12 seats to keep it in 2 rows.
    int crossAxisCount = 4;
    double avatarRadius = capacity == 8 ? 24 : (capacity <= 12 ? 22 : 20);
    double iconSize = capacity == 8 ? 20 : (capacity <= 12 ? 18 : 16);
    double fontSize = capacity == 8 ? 10 : (capacity <= 12 ? 9 : 8);

    if (isYoutubeActive) {
      avatarRadius = 20;
      iconSize = 16;
      fontSize = 9;
      // Force 2-row layout if possible by increasing columns
      if (capacity == 16) {
        crossAxisCount = 8; // strictly 8x8 as per user (2 rows of 8)
        avatarRadius = 14;  // Small small size
        iconSize = 12;
        fontSize = 7;
      } else if (capacity >= 12) {
        crossAxisCount = 6; // strictly 6 as per user "make it 6x6"
      } else if (capacity == 10) {
        crossAxisCount = 5; // 5 columns for 10 seats (2 rows of 5)
      }
    } else {
      // 🏰 Standard Layout Tweaks
      if (capacity >= 12) {
        crossAxisCount = 6; // User requested 6x... layout for high capacity rooms
      } else if (capacity == 10) {
        crossAxisCount = 5; // User requested 5x5 layout for 10 seats
      }
    }

    // 💺 Dynamic Item Count: 
    // If YouTube is active, show ALL seats (including host 0) in the grid.
    // If not, Owner hides seat 0 from grid (as it's the big top seat).
    final isOwner = currentUid == ownerUid;
    final bool showHostInGrid = isYoutubeActive;
    final itemCount = (isOwner && !showHostInGrid) ? capacity - 1 : capacity;
 
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: isYoutubeActive ? 2 : 2,
          crossAxisSpacing: isYoutubeActive ? 4 : 4,
          mainAxisExtent: (isYoutubeActive && capacity == 16) ? 60 : (isYoutubeActive ? 78 : 82),
        ),
      itemCount: itemCount,
      itemBuilder: (context, gridIndex) {
        // If showHostInGrid is true, index is just gridIndex.
        // Otherwise, if Owner: grid 0 maps to seat 1.
        final index = showHostInGrid ? gridIndex : ((isOwner) ? gridIndex + 1 : gridIndex);
 
        final participant = participants.firstWhere(
          (p) => p.seatIndex == index, 
          orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), isMuted: true, role: 'audience')
        );

        final isLocked = lockedSeats.contains(index);
        final isOccupied = participant.uid.isNotEmpty;

        return GestureDetector(
          onTap: () => onSeatTap(index),
          onLongPress: () => onSeatLongPress(index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSeatIcon(ref, participant, isOccupied, isLocked, index, avatarRadius, iconSize, currentUid),
              const SizedBox(height: 4),
              SizedBox(
                height: fontSize + 4,
                child: Center(
                  child: isOccupied
                    ? _buildSeatName(ref, participant.uid, fontSize)
                    : (isLocked 
                        ? Text("Locked", style: TextStyle(color: Colors.redAccent.withOpacity(0.6), fontSize: fontSize, fontWeight: FontWeight.bold))
                        : Text("${index + 1}", style: TextStyle(color: Colors.white70, fontSize: fontSize))),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  Widget _buildSeatIcon(WidgetRef ref, Participant p, bool isOccupied, bool isLocked, int index, double radius, double iconSize, String? currentUid) {
    if (!isOccupied) {
      final isLocked = lockedSeats.contains(index);
      return Container(
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
      );
    }

    final userAsync = ref.watch(userProfileProvider(p.uid));
    final isOwnerView = currentUid == ownerUid && ownerUid.isNotEmpty;
    final isOwnerSeat = p.uid == ownerUid && ownerUid.isNotEmpty;
    
    return userAsync.when(
      data: (user) {
        final u = user as UserModel;
        String? displayFrame = u.profileFrame;

        return SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _buildSpeakingBorder(ref, p.uid, radius),
              
              Stack(
                alignment: Alignment.bottomRight,
                clipBehavior: Clip.none,
                children: [
                  OverflowBox(
                    maxWidth: 200,
                    maxHeight: 200,
                    child: AppAvatar(
                      imageUrl: u.profilePhotoUrl,
                      frameUrl: displayFrame,
                      vipTier: u.vipTier,
                      radius: radius,
                      showFrame: true,
                      frameMultiplier: 2.3,
                    ),
                  ),
                  if (p.isMuted)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Icon(Icons.mic_off, color: Colors.white, size: radius > 22 ? 11 : 9),
                      ),
                    ),
                ],
              ),
              
              if (p.role == 'host')
                Positioned(
                  top: -10, // Moved up to clear big frames
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700), 
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text("OWNER", style: TextStyle(color: Colors.black, fontSize: radius > 22 ? 8 : 6, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
      },
      loading: () => SizedBox(width: radius * 2, height: radius * 2, child: const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, __) => Icon(Icons.error, color: Colors.red, size: radius),
    );
  }

  Widget _buildSpeakingBorder(WidgetRef ref, String uid, double radius) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            width: radius * 2.5,
            height: radius * 2.5,
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

  Widget _buildSeatName(WidgetRef ref, String uid, double fontSize) {
    final userAsync = ref.watch(userProfileProvider(uid));
    return userAsync.when(
      data: (user) => Text(
        (user as UserModel).displayName,
        style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
      loading: () => Text("...", style: TextStyle(color: Colors.white, fontSize: fontSize)),
      error: (_, __) => Text("?", style: TextStyle(color: Colors.white, fontSize: fontSize)),
    );
  }
}
