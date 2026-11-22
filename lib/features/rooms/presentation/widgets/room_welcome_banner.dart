import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/room_provider.dart';

/// Reusable Real-Time Welcome Message Banner (Matching Reference Image 5 / 9).
///
/// Reactively watches [currentRoomStreamProvider(roomId)] and displays the
/// room's canonical [welcomeMessage] or the platform policy notice in a
/// clean rounded dark translucent bubble container at the bottom of the room.
/// - Pinned at the bottom inside the chat area.
/// - Instantly updates when Firestore document changes in real time.
/// - Styled with cyan text (`#4DEEEA`), rounded corners (16dp),
///   subtle border (`0x334DEEEA`), and dark navy background (`#141F32`).
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

  static const defaultPlatformWelcomeText =
      'Welcome to Hello Chat! Please communicate respectfully. The platform prohibits inappropriate content such as pornography, violence, child exploitation, political content, advertisements, and other prohibited content.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(currentRoomStreamProvider(roomId));
    final room = roomAsync.valueOrNull;
    final rawMessage = room?.welcomeMessage.trim() ?? '';

    final displayMessage = rawMessage.isNotEmpty
        ? rawMessage.replaceAll(
            '[Room Name]',
            room?.name.isNotEmpty == true ? room!.name : 'the room',
          )
        : defaultPlatformWelcomeText;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        margin: margin ?? const EdgeInsets.fromLTRB(4, 4, 8, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xD9141F32),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0x334DEEEA),
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
        child: Text(
          displayMessage,
          textAlign: TextAlign.left,
          style: const TextStyle(
            color: Color(0xFF4DEEEA),
            fontSize: 12.5,
            height: 1.38,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
