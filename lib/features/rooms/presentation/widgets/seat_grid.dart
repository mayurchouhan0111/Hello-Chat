import 'package:flutter/material.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: capacity > 10 ? 4 : 4, // 4 seats per row
        mainAxisSpacing: 20,
        crossAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: capacity,
      itemBuilder: (context, index) {
        final participant = participants.firstWhere(
          (p) => p.seatIndex == index, 
          orElse: () => Participant(uid: '', joinedAt: DateTime.now(), isMuted: true, role: 'audience')
        );

        final isOccupied = participant.uid.isNotEmpty;

        return GestureDetector(
          onTap: () => onSeatTap(index),
          child: Column(
            children: [
              _buildSeatIcon(ref, participant, isOccupied, index),
              const SizedBox(height: 6),
              if (isOccupied)
                _buildSeatName(ref, participant.uid)
              else
                Text("${index + 1}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeatIcon(WidgetRef ref, Participant p, bool isOccupied, int index) {
    if (!isOccupied) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: const Icon(Icons.chair_alt_rounded, color: Colors.white38, size: 24),
      );
    }

    final userAsync = ref.watch(userProfileProvider(p.uid));
    
    return userAsync.when(
      data: (user) {
        final u = user as UserModel;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Speaking Animation Border
            _buildSpeakingBorder(ref, p.uid),
            
            CircleAvatar(
              radius: 28,
              backgroundImage: CachedNetworkImageProvider(u.profilePhotoUrl),
              child: p.isMuted 
                ? Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.mic_off, color: Colors.white, size: 10),
                    ),
                  )
                : null,
            ),
            
            if (p.role == 'host')
              Positioned(
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                  child: const Text("OWNER", style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(strokeWidth: 2),
      error: (_, __) => const Icon(Icons.error, color: Colors.red),
    );
  }

  Widget _buildSpeakingBorder(WidgetRef ref, String uid) {
    // For now we simulate speaking. In real app, we'd watch a speaking state for this UID
    // Using a random fake simulation for now as requested
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds)
     .fade(begin: 0.3, end: 1);
  }

  Widget _buildSeatName(WidgetRef ref, String uid) {
    final userAsync = ref.watch(userProfileProvider(uid));
    return userAsync.when(
      data: (user) => Text(
        (user as UserModel).displayName,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
      loading: () => const Text("...", style: TextStyle(color: Colors.white, fontSize: 10)),
      error: (_, __) => const Text("?", style: TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}
