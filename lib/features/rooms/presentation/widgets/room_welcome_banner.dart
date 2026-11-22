import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/room_provider.dart';

/// Reusable Real-Time Welcome Message Banner (Reference Image 2 Styling).
///
/// Reactively watches [currentRoomStreamProvider(roomId)] and displays the
/// room's canonical [welcomeMessage] in a rounded dark translucent bubble container.
/// - Positioned at the bottom, right above the chat messages list.
/// - Instantly updates when Firestore document changes in real time.
/// - Hides completely ([SizedBox.shrink]) if empty or only whitespace.
/// - Styled with cyan/light-blue text (`#4DEEEA`), rounded corners (16dp),
///   and left-aligned notice text.
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
    final rawMessage = room?.welcomeMessage.trim() ?? '';

    // Hide if empty or whitespace
    if (rawMessage.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayMessage = rawMessage.replaceAll(
      '[Room Name]',
      room?.name.isNotEmpty == true ? room!.name : 'the room',
    );

    return RepaintBoundary(
      child: Container(
        margin: margin ?? const EdgeInsets.fromLTRB(10, 4, 10, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC1A2B4C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0x404DEEEA),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF4DEEEA).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF4DEEEA),
                size: 13,
              ),
            ),
            Flexible(
              child: Text(
                displayMessage,
                textAlign: TextAlign.left,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4DEEEA),
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
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
