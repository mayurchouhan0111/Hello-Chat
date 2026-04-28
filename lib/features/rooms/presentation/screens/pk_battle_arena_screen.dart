import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import '../widgets/gift_animation_overlay.dart';
import '../widgets/room_invite_sheet.dart';

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
        body: GiftAnimationOverlay(
          roomId: room.roomId,
          child: Stack(
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.white],
                              stops: [0.0, 0.2],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: ref.watch(roomMessagesProvider(room.roomId)).when(
                            data: (msgs) => ChatWidget(messages: msgs),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
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
                    const Gap(8),
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => RoomInviteSheet(roomId: room.roomId),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white, size: 10),
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
            
            // 🚀 Final navigation and auto-cleanup
            final myUid = ref.read(authStateProvider).value?.uid;
            if (widget.room.ownerUid == myUid) {
              // Auto-cleanup for host: clear the PK state to return to regular room
              ref.read(roomServiceProvider).updateRoomSettings(widget.room.roomId, {
                'pkActive': false,
                'pkPhase': FieldValue.delete(),
                'pkChallenge': FieldValue.delete(),
                'pkScores': FieldValue.delete(),
                'pkTeams': FieldValue.delete(),
                'pkWinnerUid': FieldValue.delete(),
                'pkWinnerData': FieldValue.delete(),
              });
            }
            // Do NOT call Navigator.pop() here because PKBattleArenaScreen is built 
            // inline inside LiveRoomScreen body. Popping here would kick the user out of the room entirely!
            // When the host clears the pkPhase above, the stream will update and the UI will 
            // automatically revert to the SeatGrid layout.
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
    
    final AsyncValue<dynamic>? winnerProfileAsync = 
        winnerUid != null ? ref.watch(userProfileProvider(winnerUid)) : null;

    final String winnerName = winnerProfileAsync?.when(
      data: (user) => (user as UserModel?)?.displayName ?? "Unknown",
      loading: () => "Loading...",
      error: (_, __) => "Unknown",
    ) ?? "Unknown";

    final String? winnerAvatar = winnerProfileAsync?.when(
      data: (user) {
         final u = user as UserModel?;
         return (u != null && u.profilePhotoUrl.isNotEmpty) ? u.profilePhotoUrl : null;
      },
      loading: () => null,
      error: (_, __) => null,
    );

    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 🎇 Fireworks Particles Background
          if (winnerUid != null)
            ...List.generate(40, (index) {
              final rnd = Random(index);
              final startX = rnd.nextDouble() * MediaQuery.of(context).size.width;
              final startY = rnd.nextDouble() * MediaQuery.of(context).size.height;
              final endY = startY - 100 - rnd.nextDouble() * 200;
              final color = [Colors.cyanAccent, Colors.pinkAccent, Colors.amber, Colors.purpleAccent][rnd.nextInt(4)];
              
              return Positioned(
                left: startX,
                top: startY,
                child: Icon(Icons.star, color: color, size: rnd.nextDouble() * 20 + 8)
                  .animate(onPlay: (c) => c.repeat())
                  .fade(duration: 800.ms, delay: (rnd.nextInt(1000)).ms)
                  .scale(begin: Offset.zero, end: const Offset(1.5, 1.5))
                  .moveY(begin: 0, end: endY - startY, duration: (1000 + rnd.nextInt(1000)).ms),
              );
            }),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (winnerAvatar != null)
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 4),
                      image: DecorationImage(image: CachedNetworkImageProvider(winnerAvatar), fit: BoxFit.cover),
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 40, spreadRadius: 10)],
                    ),
                  ).animate().scale(duration: 800.ms, curve: Curves.elasticOut)
                else
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 80)
                    .animate(onPlay: (c) => c.repeat())
                    .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2), curve: Curves.elasticOut)
                    .shimmer(),
                const Gap(16),
                Text(
                  winnerUid == null ? "DRAW!" : "WINNER!",
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                ).animate().fadeIn(),
                if (winnerUid != null)
                  Text(
                    winnerName,
                    style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
                  ).animate().slideY(begin: 0.5, end: 0, duration: 500.ms),
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
        ],
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
