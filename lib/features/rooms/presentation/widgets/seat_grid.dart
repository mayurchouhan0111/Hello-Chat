import 'package:flutter/material.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/app_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SeatGrid extends ConsumerWidget {
  final List<Participant> participants;
  final int capacity;
  final Function(int) onSeatTap;
  final Function(Participant) onUserLongPress;

  const SeatGrid({
    super.key,
    required this.participants,
    required this.capacity,
    required this.onSeatTap,
    required this.onUserLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dynamic layout based on capacity to keep it compact and wide
    final int crossAxisCount = capacity == 8 ? 4 : (capacity == 12 ? 6 : 8);
    final double avatarRadius = capacity == 8 ? 28 : (capacity == 12 ? 22 : 18);
    final double iconSize = capacity == 8 ? 24 : (capacity == 12 ? 18 : 14);
    final double fontSize = capacity == 8 ? 11 : (capacity == 12 ? 9 : 8);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: capacity == 8 ? 20 : 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: capacity,
      itemBuilder: (context, index) {
        final participant = participants.firstWhere(
          (p) => p.seatIndex == index, 
          orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), isMuted: true, role: 'audience')
        );

        final isOccupied = participant.uid.isNotEmpty;

        return GestureDetector(
          onTap: () => onSeatTap(index),
          child: Column(
            children: [
              _buildSeatIcon(ref, participant, isOccupied, index, avatarRadius, iconSize),
              const SizedBox(height: 4),
              if (isOccupied)
                _buildSeatName(ref, participant.uid, fontSize)
              else
                Text("${index + 1}", style: TextStyle(color: Colors.white70, fontSize: fontSize)),
            ],
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack).fadeIn(duration: 300.ms);
      },
    );
  }

  Widget _buildSeatIcon(WidgetRef ref, Participant p, bool isOccupied, int index, double radius, double iconSize) {
    if (!isOccupied) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Icon(Icons.chair_alt_rounded, color: Colors.white38, size: iconSize),
      );
    }

    final userAsync = ref.watch(userProfileProvider(p.uid));
    
    return userAsync.when(
      data: (user) {
        final u = user as UserModel;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Speaking Animation Border
            _buildSpeakingBorder(ref, p.uid, radius),
            
            Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                  imageUrl: u.profilePhotoUrl,
                  frameUrl: u.profileFrame,
                  vipTier: u.vipTier,
                  radius: radius,
                  showFrame: true,
                  frameMultiplier: 1.4,
                ),
                if (p.isMuted)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Icon(Icons.mic_off, color: Colors.white, size: radius > 20 ? 10 : 8),
                  ),
              ],
            ),
            
            if (p.role == 'host')
              Positioned(
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(4)),
                  child: Text("OWNER", style: TextStyle(color: Colors.black, fontSize: radius > 20 ? 8 : 6, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
      },
      loading: () => SizedBox(width: radius, height: radius, child: const CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => Icon(Icons.error, color: Colors.red, size: radius),
    );
  }

  Widget _buildSpeakingBorder(WidgetRef ref, String uid, double radius) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.cyanAccent.withOpacity(0.5),
                width: 1.5,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat())
           .scale(
             begin: const Offset(1, 1), 
             end: const Offset(1.3, 1.3), 
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
