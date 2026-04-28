import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/providers/overlay_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/app_avatar.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/features/rooms/presentation/screens/live_room_screen.dart';
import 'package:hello_chat/services/room_service.dart';
import 'package:hello_chat/services/voice_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FloatingRoomOverlay extends ConsumerStatefulWidget {
  const FloatingRoomOverlay({super.key});

  @override
  ConsumerState<FloatingRoomOverlay> createState() => _FloatingRoomOverlayState();
}

class _FloatingRoomOverlayState extends ConsumerState<FloatingRoomOverlay> {
  Offset position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    final overlayState = ref.watch(roomOverlayProvider);
    
    // 🛡️ Guard: Only show if minimized and we have a roomId
    if (!overlayState.isMinimized || overlayState.roomId == null) {
      return const SizedBox.shrink();
    }

    return Consumer(
      builder: (context, ref, child) {
        final roomAsync = ref.watch(currentRoomStreamProvider(overlayState.roomId!));
        
        return roomAsync.when(
          data: (room) {
            if (room == null || !mounted) return const SizedBox.shrink();
            
            return Positioned(
              left: position.dx,
              top: position.dy,
              child: Draggable(
                feedback: _buildSquareBubble(room),
                childWhenDragging: const SizedBox.shrink(),
                onDragEnd: (details) {
                  if (mounted) {
                    setState(() {
                      position = details.offset;
                    });
                  }
                },
                child: GestureDetector(
                  onTap: () {
                    debugPrint('--- [OVERLAY TAP: Restoring Room ${room.roomId}] ---');
                    
                    // 🚀 Navigation: Use router instance directly
                    final router = ref.read(routerProvider);
                    router.pushNamed(AppRoutes.liveRoom, pathParameters: {'roomId': room.roomId});
                    
                    // 🛡️ Delay state change to avoid immediate disposal crash
                    Future.microtask(() {
                      if (mounted) {
                        ref.read(roomOverlayProvider.notifier).restore();
                      }
                    });
                  },
                  child: _buildSquareBubble(room),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildSquareBubble(dynamic room) {
    // RoomModel fields: coverUrl, name, ownerUid
    final String imageUrl = room.coverUrl.isNotEmpty ? room.coverUrl : "https://picsum.photos/seed/${room.ownerUid}/200";

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 1, offset: Offset(0, 4))
        ],
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // 🖼️ BACKGROUND IMAGE
            CachedNetworkImage(
              imageUrl: imageUrl,
              width: 90, height: 90,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[900]),
              errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Icon(Icons.live_tv, color: Colors.white24)),
            ),

            // 🌑 OVERLAY GRADIENT for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.7)],
                ),
              ),
            ),

            // 🔴 LIVE TAG
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                ),
              ),
            ),

            // ❌ CLOSE BUTTON
            Positioned(
              top: 0, right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 14),
                onPressed: () {
                  final roomId = ref.read(roomOverlayProvider).roomId;
                  if (roomId != null) {
                    ref.read(roomServiceProvider).leaveRoom(roomId);
                    ref.read(voiceServiceProvider).leaveRoom();
                  }
                  ref.read(roomOverlayProvider.notifier).clear();
                },
              ),
            ),

            // 📝 ROOM NAME
            Positioned(
              bottom: 6, left: 6, right: 6,
              child: Text(
                room.name.isEmpty ? "Room" : room.name,
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  decoration: TextDecoration.none,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
