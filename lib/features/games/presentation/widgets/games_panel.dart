import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../screens/lucky_draw_screen.dart';
import '../screens/spin_wheel_screen.dart';
// import '../screens/yummy_bingo_screen.dart';
// import '../screens/teen_patti_screen.dart';

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
          // NOTE: Temporarily commented out from UI. Can be un-commented later.
          /*
          const Gap(16),
          Row(
            children: [
              _buildGameCard(
                context,
                "Yummy Bingo",
                "5-Reel Fruit & Jackpot!",
                Icons.casino_rounded,
                const Color(0xFFFF5252),
                () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => YummyBingoScreen(roomId: roomId)));
                },
                badge: "HOT 🔥",
              ),
              const Gap(16),
              _buildGameCard(
                context,
                "Teen Patti",
                "Multiplayer Card Table!",
                Icons.style_rounded,
                const Color(0xFFFFB300),
                () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => TeenPattiScreen(roomId: roomId)));
                },
                badge: "MULTIPLAYER ♠️",
              ),
            ],
          ),
          */
          const Gap(32),
        ],
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context,
    String title,
    String desc,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    String? badge,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 36),
                  const Gap(16),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Gap(4),
                  Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF416C).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
