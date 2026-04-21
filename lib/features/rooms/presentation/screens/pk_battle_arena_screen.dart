import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/models/participant_model.dart';
import '../widgets/active_pk_battle_grid.dart';
import '../widgets/pk_battle_widget.dart';
import '../widgets/chat_widget.dart';
import '../widgets/gift_panel.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';

class PKBattleArenaScreen extends ConsumerWidget {
  final RoomModel room;
  final List<Participant> participants;

  const PKBattleArenaScreen({
    super.key,
    required this.room,
    required this.participants,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).value?.uid;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F172A),
                    Colors.black,
                    const Color(0xFF1E1B4B),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // 1. Top Header (Minimalist)
                    _buildHeader(context, ref, myUid),

                    // 2. The Battle Scoreboard (Timer + Progress)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: PKBattleWidget(room: room),
                    ),

                    // 3. The Arena (Split Grid)
                    Expanded(
                      child: ActivePKBattleGrid(
                        room: room,
                        participants: participants,
                      ),
                    ),

                    // 4. Chat Feed (Compact)
                    SizedBox(
                      height: 150,
                      child: ref.watch(roomMessagesProvider(room.roomId)).when(
                        data: (msgs) => ChatWidget(messages: msgs),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),

                    // 5. Action Bar (Locked to essentials)
                    _buildPKBottomBar(context, ref),
                  ],
                ),
              ),
            ),
            
            // 🎭 MATCH START OVERLAY ... (Existing)
            _buildMatchStartOverlay(),

            // 🏆 WINNER RESULT OVERLAY
            if (room.pkPhase == 'finished' || (room.pkActive == false && room.pkWinnerUid != null))
              _PKResultOverlay(room: room),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchStartOverlay() {
    return Center(
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "MATCH START",
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 4,
                shadows: [
                  Shadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 20),
                  Shadow(color: Colors.pinkAccent.withOpacity(0.5), blurRadius: 40),
                ]
              )
            ).animate()
              .scale(duration: 600.ms, begin: const Offset(0.5, 0.5), end: const Offset(1.2, 1.2), curve: Curves.elasticOut)
              .then().fadeOut(delay: 1500.ms),
            
            Container(
              width: 200, height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Colors.cyanAccent, Colors.pinkAccent])
              ),
            ).animate().scaleX(duration: 400.ms).then().fadeOut(delay: 1500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, String? myUid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 14),
                    const Gap(8),
                    Flexible(
                      child: Text(
                        room.name, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 🛡️ BATTLE CONTROLS
          Builder(
            builder: (context) {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final isHost = room.ownerUid == currentUid;
              final isExpired = room.pkEndTime != null && room.pkEndTime!.isBefore(DateTime.now());
              
              // Only show 'End PK' to host OR everyone if timer is expired
              if (isHost || isExpired) {
                return GestureDetector(
                  onTap: () => ref.read(roomServiceProvider).endPKBattle(room.roomId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isExpired 
                          ? [Colors.blueAccent, Colors.cyanAccent] 
                          : [Colors.pinkAccent, Colors.redAccent]
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: (isExpired ? Colors.cyan : Colors.pink).withOpacity(0.3), blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Icon(isExpired ? Icons.check_circle_rounded : Icons.stop_circle_rounded, color: Colors.white, size: 16),
                        const Gap(6),
                        Text(
                          isExpired ? "CLEANUP" : "END PK", 
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox(width: 32); 
              },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildPKBottomBar(BuildContext context, WidgetRef ref) {
     final myUid = ref.watch(authStateProvider).value?.uid;
     final isHost = room.ownerUid == myUid;

     return Container(
       padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
       child: Row(
         children: [
           Expanded(
             child: Container(
               height: 40,
               decoration: BoxDecoration(
                 color: Colors.white.withOpacity(0.08),
                 borderRadius: BorderRadius.circular(20),
               ),
               child: const Center(
                 child: Text("Cheer for your team...", style: TextStyle(color: Colors.white38, fontSize: 12)),
               ),
             ),
           ),
           const Gap(12),
           _buildActionButton(Icons.theater_comedy_rounded, Colors.purpleAccent, () {}),
           const Gap(8),
           _buildGiftButton(context),
         ],
       ),
     );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3))),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildGiftButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => GiftPanel(roomId: room.roomId),
        );
      },
      child: Container(
        width: 44, height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [const Color(0xFF00E5FF), const Color(0xFF8E54E9)]),
        ),
        child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds);
  }
}

class _PKResultOverlay extends ConsumerStatefulWidget {
  final RoomModel room;
  const _PKResultOverlay({required this.room});

  @override
  ConsumerState<_PKResultOverlay> createState() => _PKResultOverlayState();
}

class _PKResultOverlayState extends ConsumerState<_PKResultOverlay> {
  Timer? _countdownTimer;
  int _secondsRemaining = 10;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _countdownTimer?.cancel();
            // Automatically trigger cleanup if host, or the UI will naturally refresh 
            // once the host clicks CLEANUP.
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.room.pkWinnerData ?? {};
    final winnerUid = data['winnerUid'] as String?;
    final totalDiamonds = data['totalDiamonds'] ?? 0;
    final winnerName = data['winnerName'] ?? "Unknown";

    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 80)
              .animate(onPlay: (c) => c.repeat())
              .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2), curve: Curves.elasticOut)
              .shimmer(),
            const Gap(16),
            Text(
              winnerUid == null ? "DRAW!" : "WINNER!",
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
            ).animate().fadeIn(),
            if (winnerUid != null)
              Text(
                winnerName,
                style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            const Gap(32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond_rounded, color: Colors.cyanAccent, size: 24),
                  const Gap(10),
                  Text("$totalDiamonds", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Gap(40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildContributorList("LEFT TEAM", data['top3Left'] ?? []),
                _buildContributorList("RIGHT TEAM", data['top3Right'] ?? []),
              ],
            ),
            const Gap(60),
            Text(
              "Returning to room in ${_secondsRemaining}s...",
              style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributorList(String title, List<dynamic> list) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const Gap(12),
        ...list.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text("${item['amount']}", style: const TextStyle(color: Colors.white, fontSize: 12)),
        )),
        if (list.isEmpty) const Text("No contributions", style: TextStyle(color: Colors.white24, fontSize: 10)),
      ],
    );
  }
}
