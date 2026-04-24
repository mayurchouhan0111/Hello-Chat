import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/router/app_router.dart';
import '../widgets/seat_grid.dart';
import '../widgets/chat_widget.dart';
import '../widgets/gift_panel.dart';
import '../widgets/pk_matching_bottom_sheet.dart';
import '../widgets/gift_animation_overlay.dart';
import '../widgets/pk_battle_widget.dart';
import '../widgets/active_pk_battle_grid.dart';
import 'pk_battle_arena_screen.dart';
import '../widgets/pk_challenge_banner.dart';
import '../widgets/live_activity_feed.dart';
import '../widgets/entry_effect_overlay.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/services/broadcast_service.dart';
import '../../../../core/services/report_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/viewers_list_sheet.dart';

import '../../../games/presentation/widgets/games_panel.dart';
import '../widgets/room_star_progress_widget.dart';
import '../widgets/room_settings_sheet.dart';
import '../widgets/room_user_options_sheet.dart';
import '../widgets/youtube_panel.dart';
import '../widgets/youtube_room_player.dart';

class LiveRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LiveRoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}


class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      ref.read(roomServiceProvider).updateParticipantPresence(widget.roomId);
    } else if (state == AppLifecycleState.paused) {
      // We don't forcefully leave anymore; RTDB onDisconnect will handle signal loss/kill.
      // This allows users to check notifications without being kicked.
    }
  }


  void _leaveRoomSilently() {
    final myUid = ref.read(authStateProvider).value?.uid;
    final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
    if (myUid != null && room != null && room.ownerUid != myUid) {
      ref.read(roomServiceProvider).leaveRoom(widget.roomId);
    }
  }
  final TextEditingController _chatController = TextEditingController();
  bool _isSpeakerOn = true;
  bool _isCameraOn = false;
  Participant? _entryParticipant;
  Timer? _presenceTimer;
  bool _isLeavingRoom = false;
  bool _isLeavingVoluntarily = false;

  void _showUserOptions(Participant p) async {
    final uid = ref.read(authStateProvider).value?.uid;
    final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
    if (uid == null || room == null) return;

    final bool isHost = room.ownerUid == uid;
    final bool isAdmin = room.admins.contains(uid);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomUserOptionsSheet(
        participant: p,
        roomId: widget.roomId,
        isHost: isHost,
        isAdmin: isAdmin,
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      try {
        final roomService = ref.read(roomServiceProvider);
        final voiceService = ref.read(voiceServiceProvider);
        final authState = ref.read(authStateProvider).value;

        // Step 1: Join Firestore Room
        await roomService.joinRoom(widget.roomId);
        if (!mounted) return;

        // Step 2: Join Agora Channel
        await voiceService.joinRoom(widget.roomId, authState?.uid ?? 'guest');

        // Step 3: Start Presence Heartbeat
        _startPresenceTimer();
      } catch (e) {
        if (mounted) {
          debugPrint("Error joining room: $e");
        }
      }
    });
  }

  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (mounted) {
        ref.read(roomServiceProvider).updateParticipantPresence(widget.roomId);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    ref.read(voiceServiceProvider).leaveRoom();
    _chatController.dispose();
    super.dispose();
  }

  void _leaveRoom() async {
    setState(() {
      _isLeavingRoom = true;
      _isLeavingVoluntarily = true;
    });
    final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
    final myUid = ref.read(authStateProvider).value?.uid;

    if (room != null && myUid == room.ownerUid) {
      // Owner Logic
      if (!mounted) return;
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Room Control", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            "Do you want to end this room for everyone or just leave it running?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'leave'),
              child: const Text("JUST LEAVE", style: TextStyle(color: Colors.orangeAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, 'end'),
              child: const Text("END ROOM", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (result == 'end') {
        await ref.read(roomServiceProvider).endRoom(widget.roomId);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
      } else if (result == 'leave') {
        await ref.read(roomServiceProvider).leaveRoom(widget.roomId);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
      } else {
        setState(() => _isLeavingRoom = false);
      }
    } else {
      // Guest Logic
      try {
        await ref.read(roomServiceProvider).leaveRoom(widget.roomId);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
      } catch (e) {
        debugPrint("Error leaving room: $e");
        if (mounted) {
          setState(() => _isLeavingRoom = false);
          if (GoRouter.of(context).canPop()) context.pop();
        }
      }
    }
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    await ref.read(chatServiceProvider).sendTextMessage(widget.roomId, uid, text);
    _chatController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.roomId));
    final messagesAsync = ref.watch(roomMessagesProvider(widget.roomId));
    final profiles = ref.watch(roomParticipantsProvider(widget.roomId));

    // 🛡️ Monitor Room Status: Ends the session if room is deleted or archived
    ref.listen(currentRoomStreamProvider(widget.roomId), (prev, next) {
      if (!mounted) return;
      if (next.hasValue) {
        final room = next.value;
        if (room != null) {
          // Room end check
          if (room.status == 'ended') {
            if (!_isLeavingRoom && mounted && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("The host has ended this room.")),
              );
              if (GoRouter.of(context).canPop()) {
                context.pop();
              }
            }
          }

          // ⚔️ Challenge Feedback logic
          final prevRoom = prev?.value;
          if (prevRoom != null && room.pkChallenge != null && prevRoom.pkChallenge != null) {
            final myUid = ref.read(authStateProvider).value?.uid;
            if (myUid != null && myUid == room.pkChallenge!['senderUid']) {
               final status = room.pkChallenge!['status'];
               final prevStatus = prevRoom.pkChallenge!['status'];
               
               if (status != prevStatus && mounted && context.mounted) {
                 if (status == 'rejected') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("👉 The user has rejected the PK request"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                 } else if (status == 'expired') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("The PK challenge has expired.")),
                    );
                 }
               }
            }
          }
        }
      }
    });

    // 🛡️ Monitor Participants: Handles Entry Effects and Presence Logic
    ref.listen(roomParticipantsProvider(widget.roomId), (prev, next) {
      if (!mounted) return;
      
      // 1. SILENT PRESENCE GUARD (Departure logic)
      if (!_isLeavingVoluntarily && !_isLeavingRoom) {
        final myUid = ref.read(authStateProvider).value?.uid;
        if (myUid != null && next.hasValue) {
          final participants = next.value!;
          final isStillIn = participants.any((p) => p.uid == myUid);
          if (prev != null && prev.hasValue) {
            final wasInRoom = prev.value!.any((p) => p.uid == myUid);
            if (wasInRoom && !isStillIn) {
              if (mounted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Disconnected due to inactivity or connection loss.")),
                );
                if (GoRouter.of(context).canPop()) {
                  context.pop();
                }
              }
            }
          }
        }
      }

      // 2. ROOM ENTRY EFFECTS (Join logic)
      if (_entryParticipant == null && next.hasValue) {
        final pts = next.value!;
        final now = DateTime.now();
        for (var p in pts) {
          // Generous 10-second window to account for server sync latency
          final isNew = p.joinedAt.isAfter(now.subtract(const Duration(seconds: 10)));
          
          if (isNew) {
             if (mounted) {
               setState(() => _entryParticipant = p);
             }
             break;
          }
        }
      }
    });
    
    return roomAsync.when(
      data: (room) {
        if (room == null) return Scaffold(backgroundColor: Colors.orange, body: Center(child: Text("Room Missing", style: TextStyle(color: Colors.white))));
        if (room.status == 'ended') return _buildRoomEndedSummary();

        // ⚔️ PK Mode Switch (Restore if active)
        if (room.pkActive || room.pkPhase == 'finished') {
          return profiles.when(
            data: (pts) => PKBattleArenaScreen(room: room, participants: pts),
            loading: () => const Scaffold(backgroundColor: Colors.blueAccent, body: Center(child: CircularProgressIndicator(color: Colors.white))),
            error: (e, __) => Scaffold(backgroundColor: Colors.deepPurple, body: Center(child: Text("PK UI Error: $e"))),
          );
        }

        return PopScope(
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            _leaveRoom();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: false,
            body: GiftAnimationOverlay(
              roomId: widget.roomId,
              child: Stack(
                children: [
                  // 1. Background
                  Positioned.fill(
                    child: Image.network(
                      room.coverUrl.isEmpty ? "https://picsum.photos/seed/${room.roomId}/600/1200" : room.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black),
                    ),
                  ),
                  Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

                  // 2. MAIN UI LAYER
                  SafeArea(
                    child: Column(
                      children: [
                        // A. Top Stats & Header
                        profiles.when(
                          data: (pts) => _buildTopBar(room, pts),
                          loading: () => const SizedBox(height: 50),
                          error: (_, __) => const SizedBox(height: 50),
                        ),
                        _buildBroadcastTicker(),
                        _buildSubTopBar(room),
                        
                        // B. THE SCROLLABLE HUB: Player + Seats
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                // YouTube Player (Dynamic Visibility)
                                YouTubeRoomPlayer(room: room),
                                
                                // Seat Grid (Flexible height based on content)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: profiles.when(
                                    data: (pts) => SeatGrid(
                                      participants: pts,
                                      capacity: 8,
                                      onSeatTap: (idx) => _onSeatTap(idx, pts),
                                      onUserLongPress: _showUserOptions,
                                    ),
                                    loading: () => const Center(child: CircularProgressIndicator()),
                                    error: (e, __) => const SizedBox(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // C. Floating Chat Area
                        SizedBox(
                          height: 160,
                          child: messagesAsync.when(
                            data: (msgs) => ChatWidget(messages: msgs),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ),

                        // D. Master Controls
                        _buildBottomBar(room),
                      ],
                    ),
                  ),

                  // 🛡️ PK Invitation Banner (Floating)
                  if (!room.pkActive && room.pkChallenge != null)
                    Positioned(
                      top: 100, left: 20, right: 20,
                      child: PKChallengeBanner(room: room),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator())),
      error: (e, __) => Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Error: $e"))),
    );
  }

  // 💎 NEW: Premium Glassmorphic Wrapper
  Widget _buildGlassOverlay({required Widget child, bool isBottom = false}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            border: Border(
              bottom: isBottom ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
              top: isBottom ? BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5) : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  void _showYouTubePanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => YouTubePanel(roomId: widget.roomId),
    );
  }

  Widget _buildTopBar(RoomModel room, List<Participant> participants) {
    // Determine top contributors (top 3 by mock score for now)
    final guestParticipants = participants.where((p) => p.uid != room.ownerUid).toList();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          // 1. Host Info Pill
          Container(
            height: 36,
            padding: const EdgeInsets.only(left: 4, right: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(
                  radius: 14,
                  imageUrl: room.coverUrl.isEmpty ? "https://picsum.photos/seed/${room.ownerUid}/100" : room.coverUrl,
                  showFrame: false,
                ),
                const Gap(6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 60),
                  child: Text(
                    room.name,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(6),
                if (room.ownerUid == ref.read(authStateProvider).value?.uid)
                  GestureDetector(
                    onTap: () {
                      ref.read(roomServiceProvider).updateRoomSettings(room.roomId, {
                        'pkActive': !room.pkActive,
                        'pkStartTime': FieldValue.serverTimestamp(),
                        'pkEndTime': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
                        'pkTeams': {room.ownerUid: 'left', 'placeholder': 'right'},
                        'pkScores': {room.ownerUid: 0, 'placeholder': 0},
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: room.pkActive ? [Colors.red, Colors.orange] : [Colors.grey, Colors.blueGrey]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text("PK", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
                const Gap(6),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 10),
                ),
              ],
            ),
          ),
          const Gap(8),

          // 2. Contributor List
          Expanded(
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: guestParticipants.length,
                itemBuilder: (context, index) {
                  final p = guestParticipants[index];
                  // Mock scores for the reference look
                  final scores = ["6K", "3K", "1.5K", "800", "500"];
                  final score = index < scores.length ? scores[index] : "0";

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAvatar(
                          radius: 14,
                          imageUrl: p.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${p.uid}/100" : p.profilePhotoUrl,
                          showFrame: false,
                        ),
                        const Gap(2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            score, 
                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Viewers & Close
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_rounded, color: Colors.white, size: 14),
                  const Gap(4),
                  // 🛡️ Scoped Watcher for viewers to prevent 'defunct element' crashes on exit
                  Consumer(
                    builder: (context, ref, child) {
                      final async = ref.watch(roomParticipantsProvider(widget.roomId));
                      return async.when(
                        data: (pts) => Text(
                          "${pts.length}", 
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                        ),
                        loading: () => Text("${room.currentUsersCount}", style: const TextStyle(color: Colors.white, fontSize: 11)),
                        error: (_, __) => Text("${room.currentUsersCount}", style: const TextStyle(color: Colors.white, fontSize: 11)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const Gap(4),
          if (room.ownerUid == ref.read(authStateProvider).value?.uid)
            IconButton(
              onPressed: () => _showRoomSettings(room),
              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          IconButton(
            onPressed: _leaveRoom,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTopBar(RoomModel room) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildDynamicBadge(
            icon: Icons.emoji_events_rounded,
            text: "No.${room.hourlyRank} This Hour",
            color: Colors.orangeAccent,
          ),
          const Gap(8),
          _buildDynamicBadge(
            icon: Icons.volume_up_rounded,
            text: "${room.roomType} Room",
            color: Colors.blueAccent,
          ),
          const Spacer(),
          // 🌟 Compact Star Progress
          RoomStarProgressWidget(room: room),
        ],
      ),
    );
  }

  void _showRoomSettings(RoomModel room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: RoomSettingsSheet(room: room),
      ),
    );
  }

  Widget _buildDynamicBadge({required IconData icon, required String text, required Color color, List<String>? avatars, String? avatar}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const Gap(4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          if (avatars != null) ...[
            const Gap(6),
            ...avatars.take(3).map((url) => Container(
              margin: const EdgeInsets.only(left: 2),
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                border: Border.all(color: Colors.white30, width: 0.5),
              ),
            )),
          ],
          if (avatar != null) ...[
            const Gap(6),
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover),
                border: Border.all(color: Colors.white30, width: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildBottomBar(RoomModel room) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          // 1. Text Field (Flexible space)
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: _chatController,
                cursorColor: Colors.black54,
                style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: "Say hi...",
                  hintStyle: TextStyle(color: Colors.black26, fontSize: 12),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const Gap(6),

          // 2. Action Icons (Compact sequential list)
          Consumer(builder: (context, ref, child) {
            final myUid = FirebaseAuth.instance.currentUser?.uid;
            final bool isHostOrAdmin = room.ownerUid == myUid || (room.admins.contains(myUid));
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🛡️ PK CLEANUP / END BUTTON
                Builder(builder: (context) {
                  final isExpired = room.pkEndTime != null && room.pkEndTime!.isBefore(DateTime.now());
                  if ((myUid == room.ownerUid && room.pkActive) || (isExpired && room.pkPhase == 'finished')) {
                    return GestureDetector(
                      onTap: () => ref.read(roomServiceProvider).endPKBattle(room.roomId),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: isExpired ? [Colors.cyan, Colors.blue] : [Colors.pink, Colors.red]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(isExpired ? Icons.refresh_rounded : Icons.stop_rounded, color: Colors.white, size: 14),
                            const Gap(4),
                            Text(isExpired ? "CLEANUP" : "END PK", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // 📺 YouTube Button (Host Only, Always Available)
                if (isHostOrAdmin)
                   _buildCompactBottomButton(Icons.live_tv_rounded, const Color(0xFFFF0000), _showYouTubePanel),

                // 🔒 Lock most icons during PK Battle to focus on support/gifts
                if (!room.pkActive) ...[
                  
                  _buildCompactBottomButton(
                    _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded, 
                    Colors.white, 
                    () {
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                      ref.read(voiceServiceProvider).toggleSpeakerphone(_isSpeakerOn);
                    }
                  ),
                  
                  Consumer(builder: (context, ref, child) {
                    final participants = ref.watch(roomParticipantsProvider(widget.roomId)).value ?? [];
                    final myUid = ref.watch(authStateProvider).value?.uid;
                    final myPart = participants.where((p) => p.uid == myUid && p.seatIndex != -1).firstOrNull;
                    
                    if (myPart == null) return const SizedBox.shrink();
                    
                    return _buildCompactBottomButton(
                      myPart.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, 
                      myPart.isMuted ? Colors.redAccent : Colors.white, 
                      () async {
                        final newMute = !myPart.isMuted;
                        await ref.read(voiceServiceProvider).muteLocalAudio(newMute);
                        await ref.read(roomServiceProvider).muteUser(widget.roomId, myUid ?? '', newMute);
                      }
                    );
                  }),

                  _buildCompactBottomButton(Icons.military_tech_rounded, Colors.orangeAccent, _showPKPanel),
                  _buildCompactBottomButton(Icons.games_outlined, Colors.white, _showGamesPanel),
                  const Gap(4),
                ],

                // 🎁 Gift Button (Always visible during PK)
                GestureDetector(
                  onTap: _showGiftPanel,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF8E54E9)]),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactBottomButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Icon(icon, color: color.withOpacity(0.9), size: 21),
      ),
    );
  }

  Widget _buildHostSeat(Participant host) {
    if (host.uid.isEmpty) {
      return Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: Colors.black12, shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
        child: const Icon(Icons.person, color: Colors.white24, size: 40),
      );
    }

    final userAsync = ref.watch(userProfileProvider(host.uid));

    return GestureDetector(
      onTap: () => _showUserOptions(host),
      child: Column(
        children: [
          userAsync.when(
            data: (user) {
              final u = user as UserModel;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Speaking Ripple Effect
                  _buildHostRipple(),
                  AppAvatar(
                    imageUrl: u.profilePhotoUrl,
                    frameUrl: u.profileFrame,
                    vipTier: u.vipTier,
                    radius: 40,
                    showFrame: true,
                    frameMultiplier: 1.5,
                  ),
                  if (host.isMuted)
                     Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_off, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, __) => const Icon(Icons.error, color: Colors.red),
          ),
          const Gap(6),
          userAsync.maybeWhen(
            data: (user) => Text(
              (user as UserModel).displayName,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHostRipple() {
    return Container(
      width: 85, height: 85,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 2),
      ),
    ).animate(onPlay: (c) => c.repeat()).scale(
      begin: const Offset(1, 1), end: const Offset(1.3, 1.3),
      duration: const Duration(seconds: 1), curve: Curves.easeOut
    ).fadeOut();
  }



  void _showPKPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PKMatchingBottomSheet(roomId: widget.roomId),
    );
  }

  void _showViewersSheet() {
    final participantsAsync = ref.read(roomParticipantsProvider(widget.roomId));
    participantsAsync.whenData((pts) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => ViewersListSheet(
          roomId: widget.roomId,
          participants: pts,
          onUserSelected: (p) => _showUserOptions(p),
        ),
      );
    });
  }

  void _showRoomRankingSheet() {
    final participantsAsync = ref.read(roomParticipantsProvider(widget.roomId));
    participantsAsync.whenData((pts) {
      final topContributors = pts.where((p) => p.role != 'host').toList();
      
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Room Ranking", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Gap(16),
              if (topContributors.isEmpty)
                const Center(child: Text("No contributors yet", style: TextStyle(color: Colors.white54)))
              else
                Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: topContributors.length,
                    itemBuilder: (context, index) {
                      final p = topContributors[index];
                      return ListTile(
                        leading: Text("#${index + 1}", style: TextStyle(color: index < 3 ? Colors.amber : Colors.white54, fontWeight: FontWeight.bold)),
                        title: Text(p.displayName.isNotEmpty ? p.displayName : "User", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        subtitle: Text("ID: ${p.uid}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        trailing: const Icon(Icons.stars_rounded, color: Colors.amberAccent),
                      );
                    },
                  ),
                ),
              const Gap(24),
            ],
          ),
        ),
      );
    });
  }

  void _showAdminSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Admin Controls", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(16),
            ListTile(
              leading: const Icon(Icons.password, color: Colors.white),
              title: const Text("Lock Room (Test Password)", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(roomServiceProvider).setRoomPassword(widget.roomId, "1234");
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Room locked with default pass!")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_off, color: Colors.white),
              title: const Text("Mute All Seat", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(roomServiceProvider).muteAllSeats(widget.roomId);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All speakers muted.")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text("Blacklist", style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Blacklist UI coming soon.")));
              },
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIconButton(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color, size: 28),
      onPressed: onTap,
    );
  }

  void _showGamesPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GamesPanel(roomId: widget.roomId),
    );
  }

  void _showGiftPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftPanel(roomId: widget.roomId),
    );
  }

  void _onSeatTap(int index, List<Participant> participants) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final participantOnSeat = participants.firstWhere(
      (p) => p.seatIndex == index,
      orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), role: 'none', isMuted: true),
    );

    final myParticipation = participants.firstWhere(
      (p) => p.uid == uid,
      orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), role: 'none', isMuted: true),
    );

    if (participantOnSeat.uid.isEmpty) {
      // Seat is empty - Join it or Switch to it
      await ref.read(roomServiceProvider).takeSeat(widget.roomId, index);
    } else if (participantOnSeat.uid == uid) {
      // It's my seat - Leave it
      _showMySeatOptions(myParticipation);
    } else {
      // Others' seat - Show user options
      _showUserOptions(participantOnSeat);
    }
  }

  void _showMySeatOptions(Participant myPart) {
    final bool isCurrentlyMuted = myPart.isMuted;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isCurrentlyMuted ? Icons.mic : Icons.mic_off, color: Colors.white),
              title: Text(isCurrentlyMuted ? "Unmute Me" : "Mute Me", style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final newMuteStatus = !isCurrentlyMuted;
                
                // 1. Update Agora (actual audio)
                await ref.read(voiceServiceProvider).muteLocalAudio(newMuteStatus);
                // 2. Update Database (UI status for others)
                await ref.read(roomServiceProvider).muteUser(widget.roomId, myPart.uid, newMuteStatus);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: const Text("Leave Seat", style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(voiceServiceProvider).muteLocalAudio(true); // Auto-mute on leave
                await ref.read(roomServiceProvider).leaveSeat(widget.roomId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserProfile(String targetUid) {
    context.push(AppRoutes.userProfile, extra: targetUid);
  }

  Widget _buildBroadcastTicker() {
    return ref.watch(activeBroadcastsProvider).when(
      data: (announcements) {
        if (announcements.isEmpty) return const SizedBox.shrink();
        final msg = announcements.first.message;

        return Container(
          width: double.infinity,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                  child: const Icon(Icons.volume_up_rounded, size: 14, color: Colors.white),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, __) => const SizedBox.shrink(),
    );
  }

  void _showReportOptions(BuildContext context, RoomModel room) {
    final reasons = ["Inappropriate Content", "Gambling", "Harassment", "Hate Speech", "Other"];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Report Room", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(8),
            const Text("Why are you reporting this room?", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const Gap(16),
            ...reasons.map((r) => ListTile(
              title: Text(r, style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
              onTap: () async {
                await ref.read(reportServiceProvider).submitReport(targetUid: room.roomId, reason: r);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for reporting. We will review this room shortly.")));
                }
              },
            )),
            const Gap(24),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomEndedSummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(voiceServiceProvider).leaveRoom(); // Safety leave
        if (Navigator.canPop(context)) context.pop();
      }
    });
    return const Scaffold(backgroundColor: Colors.black);
  }

  Widget _buildFloatingBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, color: color, size: 16),
          const Gap(8),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 1, end: 0);
  }
}
