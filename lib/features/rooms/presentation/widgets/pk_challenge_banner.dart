import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class PKChallengeBanner extends ConsumerStatefulWidget {
  final RoomModel room;
  const PKChallengeBanner({super.key, required this.room});

  @override
  ConsumerState<PKChallengeBanner> createState() => _PKChallengeBannerState();
}

class _PKChallengeBannerState extends ConsumerState<PKChallengeBanner> with TickerProviderStateMixin {
  late AnimationController _progressController;
  int _timeLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..reverse(from: 1.0);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        // Client-side auto-reject or just wait for server to expire
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateProvider).value?.uid;
    final challenge = widget.room.pkChallenge;

    if (challenge == null || challenge['status'] != 'pending' || challenge['receiverUid'] != myUid) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 60,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: const [Colors.cyanAccent, Colors.pinkAccent, Colors.cyanAccent],
                stops: [0, _progressController.value, 1],
              ),
            ),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.orange, Colors.red]),
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${challenge['senderName']} challenges you!",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      "PK Battle Arena (${_timeLeft}s)",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionButton(
                    label: "Reject",
                    color: Colors.white12,
                    textColor: Colors.white70,
                    onTap: () => ref.read(roomServiceProvider).respondToPKChallenge(
                      roomId: widget.room.roomId,
                      accepted: false,
                    ),
                  ),
                  const Gap(8),
                  _actionButton(
                    label: "Accept",
                    color: Colors.indigo,
                    textColor: Colors.white,
                    onTap: () => ref.read(roomServiceProvider).respondToPKChallenge(
                      roomId: widget.room.roomId,
                      accepted: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate().slideY(begin: -1.0, end: 0, duration: 600.ms, curve: Curves.elasticOut),
    );
  }

  Widget _actionButton({required String label, required Color color, required Color textColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
