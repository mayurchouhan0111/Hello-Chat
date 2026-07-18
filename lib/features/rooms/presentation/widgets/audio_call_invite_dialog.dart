import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/services/voice_service.dart';

class AudioCallInviteListener extends ConsumerStatefulWidget {
  final Widget child;
  final String roomId;

  const AudioCallInviteListener({
    super.key,
    required this.child,
    required this.roomId,
  });

  @override
  ConsumerState<AudioCallInviteListener> createState() => _AudioCallInviteListenerState();
}

class _AudioCallInviteListenerState extends ConsumerState<AudioCallInviteListener> {
  StreamSubscription? _inviteSub;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _listenForInvites();
  }

  void _listenForInvites() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    _inviteSub = ref.read(roomServiceProvider).audioInvitationsStream(widget.roomId, myUid).listen((invite) {
      if (invite == null) {
        _dismissOverlay();
        return;
      }
      if (invite['status'] == 'pending') {
        _showInviteDialog(invite);
      }
    });
  }

  void _showInviteDialog(Map<String, dynamic> invite) {
    _dismissOverlay();

    final fromUid = invite['fromUid'] as String? ?? '';
    final type = invite['type'] as String? ?? 'invite';
    if (fromUid.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: _AudioCallInviteCard(
            roomId: widget.roomId,
            fromUid: fromUid,
            type: type,
            onAccept: () => _respondToInvite(true),
            onDecline: () => _respondToInvite(false),
          ),
        ),
      ),
    );

    if (mounted) {
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _respondToInvite(bool accepted) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    if (accepted) {
      try {
        final roomService = ref.read(roomServiceProvider);
        final voiceService = ref.read(voiceServiceProvider);

        final participants = ref.read(roomParticipantsProvider(widget.roomId)).value ?? [];
        final takenSeats = participants.map((p) => p.seatIndex).toSet();
        final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
        final capacity = room?.capacity ?? 8;

        int seatIndex = 0;
        for (int i = 0; i < capacity; i++) {
          if (!takenSeats.contains(i)) {
            seatIndex = i;
            break;
          }
        }

        await roomService.takeSeat(widget.roomId, seatIndex);
        await voiceService.setBroadcasterRole();
        await roomService.respondToAudioCall(widget.roomId, myUid, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("You are now on the mic! (Seat $seatIndex)"), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        debugPrint("Error accepting audio call invite: $e");
      }
    } else {
      await ref.read(roomServiceProvider).respondToAudioCall(widget.roomId, myUid, false);
    }
    _dismissOverlay();
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    _dismissOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AudioCallInviteCard extends StatelessWidget {
  final String roomId;
  final String fromUid;
  final String type;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _AudioCallInviteCard({
    required this.roomId,
    required this.fromUid,
    required this.type,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isBring = type == 'bring';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -100 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E1B4B).withOpacity(0.97),
              const Color(0xFF312E81).withOpacity(0.97),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFCC00FF).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(isBring ? Icons.call_made_rounded : Icons.headset_mic_rounded, color: const Color(0xFFCC00FF), size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              isBring ? "Bring to Call" : "Audio Live Call",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              isBring
                  ? "The host wants to bring you into the audio live call!"
                  : "The host has invited you to join the audio live call!",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onDecline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text("Decline", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFFCC00FF)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text("Accept", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
