import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';

class RoomNavigationHelper {
  static Future<void> joinRoom(BuildContext context, WidgetRef ref, String roomId, {RoomModel? preloadedRoom}) async {
    RoomModel? room = preloadedRoom;
    
    // Fetch room if not provided
    if (room == null) {
      final roomAsync = await ref.read(currentRoomStreamProvider(roomId).future);
      room = roomAsync;
    }

    if (room == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room not found or ended')),
        );
      }
      return;
    }

    final myUid = ref.read(authStateProvider).value?.uid;
    final isOwner = myUid == room.ownerUid;
    final hasPassword = room.passwordHash != null && room.passwordHash!.isNotEmpty;

    // Allow entry if no password, or if the caller owns the room
    if (!hasPassword || isOwner) {
      ref.read(routerProvider).pushNamed(AppRoutes.liveRoom, pathParameters: {'roomId': roomId});
      return;
    }

    // Show password dialog
    if (context.mounted) {
      final passwordController = TextEditingController();
      final result = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black.withOpacity(0.5),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim1, anim2) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, color: Color(0xFF00B8D4), size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Room Locked",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "This room requires a password to enter.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      autofocus: true,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: "Password",
                        hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 0, fontWeight: FontWeight.w500),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Cancel", style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                if (passwordController.text == room!.passwordHash) {
                                  Navigator.pop(context, true);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Incorrect password", style: TextStyle(fontWeight: FontWeight.bold))),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text("Join", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          return Transform.scale(
            scale: Curves.easeOutBack.transform(anim1.value),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          );
        },
      );

      if (result == true) {
        ref.read(routerProvider).pushNamed(AppRoutes.liveRoom, pathParameters: {'roomId': roomId});
      }
    }
  }
}
