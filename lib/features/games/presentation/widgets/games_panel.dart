import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../screens/lucky_draw_screen.dart';
import '../screens/spin_wheel_screen.dart';


class GamesPanel extends StatelessWidget {
  final String roomId;
  const GamesPanel({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ROOM GAMES",
            style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
          const Gap(24),
          Row(
            children: [
              _buildGameCard(
                context,
                "Spin Wheel",
                "Win up to 10x prizes!",
                Icons.slow_motion_video_rounded,
                Colors.blueAccent,
                () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => SpinWheelScreen(roomId: roomId)));
                },
              ),
              const Gap(16),
              _buildGameCard(
                context,
                "Lucky Draw",
                "High stakes, big wins!",
                Icons.style_rounded,
                const Color(0xFFFFD700),
                () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => LuckyDrawScreen(roomId: roomId)));
                },
              ),
            ],
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, String title, String desc, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 36),
              const Gap(16),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Gap(4),
              Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
