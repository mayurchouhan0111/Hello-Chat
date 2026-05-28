import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/pk_battle_widget.dart';
import '../widgets/active_pk_battle_grid.dart';
import '../widgets/live_activity_feed.dart';
import '../widgets/chat_widget.dart';
import '../widgets/gift_panel.dart';

class ActivePKBattleScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ActivePKBattleScreen({super.key, required this.roomId});

  @override
  ConsumerState<ActivePKBattleScreen> createState() => _ActivePKBattleScreenState();
}

class _ActivePKBattleScreenState extends ConsumerState<ActivePKBattleScreen> {
  final TextEditingController _chatController = TextEditingController();

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await ref.read(chatServiceProvider).sendTextMessage(widget.roomId, uid, text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.roomId));
    final participantsAsync = ref.watch(roomParticipantsProvider(widget.roomId));
    final messagesAsync = ref.watch(roomMessagesProvider(widget.roomId));

    // Listen for PK end to navigate back
    ref.listen(currentRoomStreamProvider(widget.roomId), (prev, next) {
      if (!mounted) return;
      
      final room = next.value;
      if (room != null && !room.pkActive) {
        // If there's a winner, we wait for the banner to show before popping
        if (room.pkWinnerUid != null) {
          debugPrint("Winner declared! Waiting for banner...");
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        } else {
          debugPrint("PK BATTLE ENDED DETECTED in listener. Navigating back...");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: roomAsync.when(
        data: (room) {
          if (room == null || room.status == 'ended') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
            });
            return const Center(child: CircularProgressIndicator());
          }

          final bool showWinner = !room.pkActive && room.pkWinnerUid != null;

          return Stack(
            children: [
              // Background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    PKBattleWidget(room: room),
                    const Gap(12),
                    Expanded(
                      flex: 6,
                      child: participantsAsync.when(
                        data: (pts) => ActivePKBattleGrid(room: room, participants: pts),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Column(
                              children: [
                                messagesAsync.when(
                                  data: (msgs) => LiveActivityFeed(messages: msgs),
                                  loading: () => const SizedBox(height: 140),
                                  error: (_, __) => const SizedBox(height: 140),
                                ),
                                Expanded(
                                  child: messagesAsync.when(
                                    data: (msgs) => ChatWidget(messages: msgs),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 60,
                            left: 16,
                            right: 16,
                            child: Text(
                              "News: You can like the host/guest to increase our PK score.",
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
                          ),
                        ],
                      ),
                    ),
                    _buildBottomBar(room),
                  ],
                ),
              ),

              // Manual Leave Button
              Positioned(
                left: 16,
                top: MediaQuery.of(context).padding.top + 8,
                child: IconButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                ),
              ),

              // Winner Banner Overlay
              if (showWinner) _buildWinnerBanner(room),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildWinnerBanner(var room) {
    final String winnerUid = room.pkWinnerUid;
    final winnerProfile = ref.watch(userProfileProvider(winnerUid));

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              winnerUid == 'draw' ? "IT'S A DRAW!" : "VICTORY!",
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontStyle: FontStyle.italic,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut).shimmer(duration: 2.seconds),
            const Gap(30),
            
            if (winnerUid != 'draw')
              winnerProfile.when(
                data: (user) {
                  final userData = user as UserModel?;
                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140, height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 40, spreadRadius: 10)],
                            ),
                          ),
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white10,
                            backgroundImage: (userData != null && userData.profilePhotoUrl.isNotEmpty) 
                              ? CachedNetworkImageProvider(userData.profilePhotoUrl)
                              : null,
                            child: userData == null ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
                          ),
                          Positioned(
                            top: -20,
                            child: Icon(Icons.workspace_premium_rounded, color: Colors.yellowAccent, size: 50)
                                .animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                          ),
                        ],
                      ),
                      const Gap(20),
                      Text(
                        userData?.displayName ?? "Winner",
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Gap(10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFF4776E6)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "SCORE: ${room.pkScores[winnerUid] ?? 0}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, end: 0),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Icon(Icons.error, color: Colors.red, size: 40),
              ),
            
            const Gap(40),
            const Text(
              "Returning to room in 5s...",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ).animate().fadeIn(delay: 2.seconds),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildBottomBar(var room) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _chatController,
                  cursorColor: Colors.white,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "Cheer for your team...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const Gap(12),
            GestureDetector(
              onTap: () {
                 showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => GiftPanel(roomId: widget.roomId),
                );
              },
              child: Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF8E54E9)]),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, color: color, size: 14),
          const Gap(6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 1, end: 0);
  }
}
