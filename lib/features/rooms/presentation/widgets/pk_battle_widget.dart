import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/room_model.dart';

class PKBattleWidget extends StatelessWidget {
  final RoomModel room;
  const PKBattleWidget({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    if (!room.pkActive) return const SizedBox.shrink();

    final scores = room.pkScores ?? {'left': 0, 'right': 0};
    final leftScore = scores['left'] ?? 0;
    final rightScore = scores['right'] ?? 0;
    final total = leftScore + rightScore;
    final leftRatio = total == 0 ? 0.5 : leftScore / total;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildTimer(room.pkEndTime),
          const Gap(8),
          Row(
            children: [
              _buildSideInfo(true, leftScore, room.pkTeams),
              const Gap(10),
              Expanded(
                child: _buildProgressBar(leftRatio),
              ),
              const Gap(10),
              _buildSideInfo(false, rightScore, room.pkTeams),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimer(DateTime? endTime) {
    if (endTime == null) return const SizedBox.shrink();
    
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final remaining = endTime.difference(now);
        if (remaining.isNegative) return const Text("PK Ended", style: TextStyle(color: Colors.white70, fontSize: 12));
        
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
          ),
          child: Text(
            "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}",
            style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildSideInfo(bool isLeft, int score, Map<String, String>? teams) {
    final uid = teams?.entries.firstWhere((e) => e.value == (isLeft ? 'left' : 'right'), orElse: () => const MapEntry('', '')).key;
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage("https://api.dicebear.com/7.x/avataaars/png?seed=$uid"),
        ),
        const Gap(4),
        Text(
          "$score 💎",
          style: TextStyle(
            color: isLeft ? Colors.cyanAccent : Colors.pinkAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double leftRatio) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Expanded(
              flex: (leftRatio * 100).toInt(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.cyan, Colors.cyanAccent]),
                ),
              ),
            ),
            Expanded(
              flex: ((1 - leftRatio) * 100).toInt(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.pinkAccent, Colors.pink]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
