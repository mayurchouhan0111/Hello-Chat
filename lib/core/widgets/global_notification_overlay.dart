import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../providers/auth_provider.dart';
import '../router/app_router.dart';

class GlobalNotificationOverlay extends ConsumerWidget {
  final Widget child;
  const GlobalNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return child;

    return Stack(
      children: [
        child,
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            final doc = snapshot.data!.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'];

            if (type == 'room_invitation') {
              return _RoomInvitationBanner(doc: doc);
            }
            
            if (type == 'pk_invitation') {
              return _PKInvitationBanner(doc: doc);
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _RoomInvitationBanner extends ConsumerWidget {
  final QueryDocumentSnapshot doc;
  const _RoomInvitationBanner({required this.doc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = doc.data() as Map<String, dynamic>;
    final senderName = data['senderName'] ?? "A friend";
    final roomName = data['roomName'] ?? "Live Room";
    final roomId = data['roomId'];

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
            border: Border.all(color: Colors.indigo.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.indigo,
                child: Icon(Icons.meeting_room_rounded, color: Colors.white),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$senderName invited you",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      "to join $roomName",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              TextButton(
                onPressed: () => doc.reference.update({'status': 'rejected'}),
                child: const Text("Ignore", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  doc.reference.update({'status': 'accepted'});
                  ref.read(routerProvider).pushNamed(AppRoutes.liveRoom, pathParameters: {'roomId': roomId});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Join"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PKInvitationBanner extends ConsumerWidget {
  final QueryDocumentSnapshot doc;
  const _PKInvitationBanner({required this.doc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = doc.data() as Map<String, dynamic>;
    final senderName = data['senderName'] ?? "Host";
    final roomName = data['roomName'] ?? "Live Room";
    final roomId = data['roomId'];

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.pinkAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
            ],
            border: Border.all(color: Colors.pinkAccent.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.orange, Colors.pink])),
                child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$senderName challenges you!",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      "to a PK Battle in $roomName",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              TextButton(
                onPressed: () => doc.reference.update({'status': 'rejected'}),
                child: const Text("Decline", style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  doc.reference.update({'status': 'accepted'});
                  ref.read(routerProvider).pushNamed(AppRoutes.liveRoom, pathParameters: {'roomId': roomId});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Accept"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
