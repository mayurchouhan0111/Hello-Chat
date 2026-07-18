import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlobalRocketBanner extends StatelessWidget {
  final String userName;
  final String userId;
  final String roomName;
  final String roomId;
  final int level;

  const GlobalRocketBanner({
    super.key, 
    required this.userName,
    required this.userId,
    required this.roomName,
    required this.roomId,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF8E54E9), // Premium deep purple
              Color(0xFF4776E6), // Royal blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E54E9).withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Rocket Icon Container with Glow
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded, 
                color: Color(0xFFFFD700), // Golden Rocket
                size: 20,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 800.ms)
            .rotate(begin: -0.05, end: 0.05, duration: 800.ms),
            
            const SizedBox(width: 12),
            
            // Text Details (Column)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                      children: [
                        TextSpan(
                          text: userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: " (ID: $userId)",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.normal,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11),
                      children: [
                        TextSpan(
                          text: "launched Lv.$level Rocket in ",
                          style: TextStyle(color: Colors.white.withOpacity(0.9)),
                        ),
                        TextSpan(
                          text: roomName,
                          style: const TextStyle(
                            color: Color(0xFFFFE082), // Light golden
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: " (Room: $roomId)",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // JOIN Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                "JOIN",
                style: TextStyle(
                  color: Color(0xFF3F2B96), // Match purple theme
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1.seconds),
          ],
        ),
      ),
    )
    .animate()
    .slideY(begin: -2, end: 0, duration: 400.ms, curve: Curves.easeOutBack)
    .then()
    .shimmer(duration: 2.seconds);
  }
}
