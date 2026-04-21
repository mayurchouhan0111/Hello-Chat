import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import 'dart:ui';

class PKBattleWidget extends ConsumerWidget {
  final RoomModel room;
  const PKBattleWidget({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!room.pkActive) return const SizedBox.shrink();

    final scores = room.pkScores ?? {};
    final pkTeams = room.pkTeams ?? {};
    
    int leftScore = 0;
    int rightScore = 0;

    pkTeams.forEach((uid, side) {
      if (side == 'left') leftScore += (scores[uid] ?? 0);
      if (side == 'right') rightScore += (scores[uid] ?? 0);
    });

    final total = leftScore + rightScore;
    final double leftRatio = total == 0 ? 0.5 : leftScore / total;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Top Bar: Popularity Ranks & Logo
        _buildTopBanner(leftScore, rightScore),
        
        const Gap(8),

        // 2. Center: Timer & Glowing Progress Bar
        _buildBattleInterface(leftRatio, room.pkEndTime, ref),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }


  Widget _buildTopBanner(int leftScore, int rightScore) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Popularity
          _buildPopularityRank(leftScore, true),
          
          // ROOM PK Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  "ROOM",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  " PK",
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
              ],
            ),
          ),

          // Right Popularity
          _buildPopularityRank(rightScore, false),
        ],
      ),
    );
  }

  Widget _buildPopularityRank(int score, bool isLeft) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          if (isLeft) const Icon(Icons.star, color: Colors.yellow, size: 12),
          const Gap(4),
          Text(
            "$score",
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const Gap(4),
          if (!isLeft) const Icon(Icons.star, color: Colors.yellow, size: 12),
        ],
      ),
    );
  }

  Widget _buildBattleInterface(double leftRatio, DateTime? endTime, WidgetRef ref) {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Glowing Progress Bar
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: (leftRatio > 0.5 ? const Color(0xFF00E5FF) : const Color(0xFFFF4081)).withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: (leftRatio * 1000).toInt().clamp(1, 1000),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF14B8A6)],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: ((1 - leftRatio) * 1000).toInt().clamp(1, 1000),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFE24B4A), Color(0xFFF43F5E)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().shimmer(duration: 3.seconds),
                  // Progress Divider
                  Align(
                    alignment: Alignment(leftRatio * 2 - 1, 0),
                    child: Container(
                      width: 4,
                      height: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const Gap(6),
          
          // Timer Widget
          _buildDigitalTimer(endTime, ref),
        ],
      ),
    );
  }


  Widget _buildDigitalTimer(DateTime? endTime, WidgetRef ref) {

    if (endTime == null) return const SizedBox.shrink();
    
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final remaining = endTime.difference(now);
        
        if (remaining.isNegative) {
          // Identify Winner
          final scores = room.pkScores ?? {};
          int leftScore = 0;
          int rightScore = 0;
          room.pkTeams?.forEach((uid, side) {
            if (side == 'left') leftScore += (scores[uid] ?? 0);
            if (side == 'right') rightScore += (scores[uid] ?? 0);
          });

          final String winnerText = leftScore > rightScore ? "HOME WIN" : (rightScore > leftScore ? "AWAY WIN" : "DRAW");
          final Color winnerColor = leftScore > rightScore ? Colors.cyanAccent : (rightScore > leftScore ? Colors.pinkAccent : Colors.orangeAccent);

          // 🛡️ AUTOMATED CLEANUP: 
          // If the timer is up and 'pkActive' is still true, we need to officially end it.
          // We let the HOST do it immediately, or ANY user as a fallback to prevent stuck rooms.
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          final isHost = myUid == room.ownerUid;
          
          if (room.pkActive && (isHost || remaining.inSeconds < -2)) {
             Future.microtask(() => ref.read(roomServiceProvider).endPKBattle(room.roomId));
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: winnerColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: winnerColor.withOpacity(0.4)),
            ),
            child: Text(
              winnerText, 
              style: TextStyle(color: winnerColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)
            ),

          ).animate().shimmer(duration: 2.seconds).scale(duration: 400.ms);
        }

        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        final timerStr = "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            timerStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
        );
      },
    );
  }
}
