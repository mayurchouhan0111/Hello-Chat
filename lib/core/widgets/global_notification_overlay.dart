import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../providers/auth_provider.dart';
import '../router/app_router.dart';
import 'package:hello_chat/core/utils/room_navigation_helper.dart';

class GlobalNotificationOverlay extends ConsumerWidget {
  final Widget child;
  const GlobalNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Stack(
      children: [
        child,
        if (user != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('global_notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final doc = snapshot.data!.docs.first;
                final data = doc.data() as Map<String, dynamic>;
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                // Auto-dismiss banners older than 12 seconds
                if (createdAt != null && DateTime.now().difference(createdAt).inSeconds > 12) {
                  return const SizedBox.shrink();
                }

                return _GlobalLuckyBagBanner(doc: doc, data: data);
              },
            ),
          ),
      ],
    );
  }
}

class _GlobalLuckyBagBanner extends ConsumerWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;

  const _GlobalLuckyBagBanner({required this.doc, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomId = data['roomId'] as String? ?? '';
    final message = data['message'] as String? ?? '🎉 A Lucky Bag was dropped! Join & Claim Now!';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD81B60), Color(0xFF8E24AA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.pink.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: Colors.amberAccent, width: 1.5),
        ),
        child: Row(
          children: [
            const Text("🧧", style: TextStyle(fontSize: 26)),
            const Gap(12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const Gap(10),
            ElevatedButton(
              onPressed: () {
                if (roomId.isNotEmpty) {
                  RoomNavigationHelper.joinRoom(context, ref, roomId);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Claim", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ],
        ),
      ),
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

    return Material(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    "to join $roomName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Gap(12),
            // TextButton(
            //   onPressed: () => doc.reference.update({'status': 'rejected'}),
            //   child: const Text("Ignore", style: TextStyle(color: Colors.white54)),
            // ),
            ElevatedButton(
              onPressed: () {
                doc.reference.update({'status': 'accepted'});
                RoomNavigationHelper.joinRoom(context, ref, roomId);
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

    return Material(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    "to a PK Battle in $roomName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                RoomNavigationHelper.joinRoom(context, ref, roomId);
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
    );
  }
}
