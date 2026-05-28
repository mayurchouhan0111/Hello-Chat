import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlobalRocketBanner extends StatelessWidget {
  final String userName;
  final String roomName;
  final int level;

  const GlobalRocketBanner({
    super.key, 
    required this.userName,
    required this.roomName,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E54E9), Color(0xFF4776E6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4776E6).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.rocket_launch_rounded, color: Color(0xFFFFD700), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "$userName launched a Lv.$level Rocket in $roomName!",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "JOIN >",
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: -2, end: 0, duration: 500.ms).then().shimmer(duration: 2.seconds);
  }
}
