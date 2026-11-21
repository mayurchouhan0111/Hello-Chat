import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/room_provider.dart';

/// Reusable Real-Time Welcome Message Banner.
///
/// Reactively watches [currentRoomStreamProvider(roomId)] and displays the
/// room's canonical [welcomeMessage].
/// - Instantly updates when Firestore document changes in real time.
/// - Hides completely ([SizedBox.shrink]) if empty or only whitespace.
class RoomWelcomeBanner extends ConsumerWidget {
  final String roomId;
  final EdgeInsetsGeometry? margin;
  final bool dismissible;

  const RoomWelcomeBanner({
    super.key,
    required this.roomId,
    this.margin,
    this.dismissible = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(currentRoomStreamProvider(roomId));
    final room = roomAsync.valueOrNull;
    final message = room?.welcomeMessage.trim() ?? '';

    // Hide if empty or whitespace
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
        margin:
            margin ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xEE0B1528), Color(0xDD121B33)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF00E5FF),
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
