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
import '../../../../core/providers/overlay_provider.dart';
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
import '../widgets/room_invite_sheet.dart';

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
      // We don't forcefully leave anymore
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
    
    // 🛡️ Auto-Clear PIP: If we are entering a room, hide any existing minimized bubbles.
    Future.microtask(() => ref.read(roomOverlayProvider.notifier).clear());

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
    _presenceTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      // 🛡️ Use mounted check — safe for ConsumerStatefulWidget
      // ref is always valid when mounted is true
      if (!mounted) return;
      try {
        ref.read(roomServiceProvider).updateParticipantPresence(widget.roomId);
      } catch (_) {
        // Widget disposed between mounted check and ref.read — safe to ignore
      }
    });
  }

  @override
  void dispose() {
    // 🛡️ Pre-capture ref values before disposal begins
    final isMinimized = ref.read(roomOverlayProvider).isMinimized;
    final voiceService = ref.read(voiceServiceProvider);

    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    
    // 🎧 Voice Persistence Logic
    // If we are minimizing, we stay in the voice channel!
    if (!isMinimized) {
      voiceService.leaveRoom();
    }
    
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, 'end'),
              child: const Text("END ROOM", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (result == 'minimize') {
        ref.read(roomOverlayProvider.notifier).minimize(widget.roomId);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
      } else if (result == 'end') {
        if (!mounted) return;
        await ref.read(voiceServiceProvider).leaveRoom();
        if (!mounted) return;
        await ref.read(roomServiceProvider).endRoom(widget.roomId);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
      } else if (result == 'leave') {
        if (!mounted) return;
        await ref.read(voiceServiceProvider).leaveRoom();
        if (!mounted) return;
        await ref.read(roomServiceProvider).leaveRoom(widget.roomId);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
      } else {
        if (mounted) setState(() => _isLeavingRoom = false);
      }
    } else {
      // For Guests: show a quick Choice Dialog (Leave or Minimize)
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Exit Room", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text("Would you like to stay in the room via a floating bubble?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'leave'),
              child: const Text("LEAVE", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );

      if (result == 'minimize') {
        ref.read(roomOverlayProvider.notifier).minimize(widget.roomId);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
      } else if (result == 'leave') {
        if (!mounted) return;
        await ref.read(voiceServiceProvider).leaveRoom();
        if (!mounted) return;
        await ref.read(roomServiceProvider).leaveRoom(widget.roomId);
        if (mounted && GoRouter.of(context).canPop()) context.pop();
      } else {
        if (mounted) setState(() => _isLeavingRoom = false);
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
    final myUid = ref.watch(authStateProvider.select((v) => v.value?.uid));
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.roomId));
    final messagesAsync = ref.watch(roomMessagesProvider(widget.roomId));
    final profiles = ref.watch(roomParticipantsProvider(widget.roomId));

    ref.listen(currentRoomStreamProvider(widget.roomId), (prev, next) {
      if (!mounted) return;
      if (next.hasValue) {
        final room = next.value;
        if (room != null) {
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

    ref.listen(roomParticipantsProvider(widget.roomId), (prev, next) {
      if (!mounted) return;
      
      if (!_isLeavingVoluntarily && !_isLeavingRoom) {
        // Safe check for myUid using the value captured in build
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

      if (_entryParticipant == null && next.hasValue) {
        final pts = next.value!;
        final now = DateTime.now();
        for (var p in pts) {
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
        if (room == null) {
          return const Scaffold(
            backgroundColor: Colors.orange,
            body: Center(child: Text("Room Missing", style: TextStyle(color: Colors.white))),
          );
        }
        if (room.status == 'ended') return _buildRoomEndedSummary();

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
                  Positioned.fill(
                    child: Image.network(
                      room.coverUrl.isEmpty ? "https://picsum.photos/seed/${room.roomId}/600/1200" : room.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black),
                    ),
                  ),
                  Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

                  SafeArea(
                    child: Column(
                      children: [
                        _buildRoomAppBar(room, profiles.value ?? []),
                        
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                                children: [
                                YouTubeRoomPlayer(room: room, myUid: myUid),
                                  if (!room.isYoutubeActive) ...[
                                    const SizedBox(height: 8),
                                    profiles.maybeWhen(
                                      data: (pts) {
                                        final myUid = ref.read(authStateProvider).value?.uid;
                                        final isOwner = room.ownerUid == myUid;
                                        
                                        if (!isOwner) return const SizedBox.shrink();

                                        final hostPart = pts.firstWhere(
                                          (p) => p.seatIndex == 0,
                                          orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), isMuted: true, role: 'host'),
                                        );
                                        return _buildHostSeat(hostPart, room);
                                      },
                                      orElse: () => const SizedBox.shrink(), 
                                    ),
                                  ],
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                  child: profiles.maybeWhen(
                                    data: (pts) => SeatGrid(
                                      participants: pts,
                                      capacity: room.capacity,
                                      lockedSeats: room.lockedSeats,
                                      isYoutubeActive: room.isYoutubeActive,
                                      ownerUid: room.ownerUid,
                                      onSeatTap: (idx) => _onSeatTap(idx, pts, room),
                                      onSeatLongPress: (idx) => _onSeatLongPress(idx, room),
                                      onUserLongPress: _showUserOptions,
                                    ),
                                    orElse: () => const SizedBox(height: 300), // Stable estimated height
                                  ),
                                ),
                                const SizedBox(height: 120), // Reduced from 180 to optimize space
                              ],
                            ),
                          ),
                        ),

                        _buildBottomBar(room),
                      ],
                    ),
                  ),

                  if (!room.pkActive && room.pkChallenge != null)
                    Positioned(
                      top: 100, left: 20, right: 20,
                      child: PKChallengeBanner(room: room),
                    ),

                  Positioned(
                    bottom: 115, // Moved down slightly as requested
                    left: 12,
                    right: 40,
                    child: IgnorePointer(
                      ignoring: false,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.white],
                              stops: [0.0, 0.2], // Fade out the top 20%
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: messagesAsync.when(
                            data: (msgs) => ChatWidget(messages: msgs),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
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

  Widget _buildRoomAppBar(RoomModel room, List<Participant> participants) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final ownerAsync = ref.watch(userProfileProvider(room.ownerUid));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Row: Info & Controls
          Row(
            children: [
              // Consolidated Info & Spark Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ownerAsync.when(
                      data: (owner) {
                        final u = owner as UserModel?;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppAvatar(
                              radius: 18,
                              imageUrl: u?.profilePhotoUrl ?? "",
                              tags: u?.tags,
                              showFrame: false,
                            ),
                            const Gap(8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  room.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  "ID:${u?.displayId ?? '...'}",
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Gap(8),
                          ],
                        );
                      },
                      loading: () => const SizedBox(width: 80, height: 40),
                      error: (_, __) => const SizedBox(width: 80, height: 40),
                    ),
                    // Spark Follow Button
                    GestureDetector(
                      onTap: () async {
                        final myUid = ref.read(authStateProvider).value?.uid;
                        if (myUid == null) return;
                        if (myUid == room.ownerUid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("You are the owner of this room!")),
                          );
                          return;
                        }
                        
                        await ref.read(profileServiceProvider).toggleFollow(myUid, room.ownerUid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Followed ${room.name}'s Host!"),
                              backgroundColor: const Color(0xFF8E54E9),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Right Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCircleActionBtn(Icons.refresh_rounded, onTap: () {}),
                  const Gap(10),
                  _buildCircleActionBtn(Icons.zoom_in_map_rounded, onTap: () {
                     ref.read(roomOverlayProvider.notifier).minimize(widget.roomId);
                     if (mounted && GoRouter.of(context).canPop()) context.pop();
                  }),
                  const Gap(10),
                  _buildCircleActionBtn(Icons.close_rounded, isClose: true, onTap: _leaveRoom),
                ],
              ),
            ],
          ),
          const Gap(10),
          // 2. Bottom Row: Tags & Viewers
          Row(
            children: [
              _buildAppBarTag("Popularity Rank", Icons.favorite_rounded, const Color(0xFFFFD700)),
              const Gap(8),
              RoomStarProgressWidget(room: room),
              const Spacer(),
              // Viewer Avatars
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ViewersListSheet(
                    roomId: room.roomId, 
                    participants: participants, 
                    ownerUid: room.ownerUid,
                    onUserSelected: _showUserOptions
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildOverlappingAvatars(participants),
                      const Gap(8),
                      Text(
                        "${participants.length}",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionBtn(IconData icon, {bool isClose = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isClose ? Colors.redAccent.withOpacity(0.3) : Colors.black.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildAppBarTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const Gap(4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildOverlappingAvatars(List<Participant> participants) {
    final topParticipants = participants.take(3).toList();
    const double spacing = 15.0;
    return SizedBox(
      height: 24,
      width: (topParticipants.length * spacing) + 12,
      child: Stack(
        children: List.generate(topParticipants.length, (index) {
          return Positioned(
            left: index * spacing,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: AppAvatar(
                radius: 11,
                imageUrl: topParticipants[index].profilePhotoUrl.isEmpty 
                    ? "https://picsum.photos/seed/${topParticipants[index].uid}/100" 
                    : topParticipants[index].profilePhotoUrl,
                tags: topParticipants[index].tags,
              ),
            ),
          );
        }),
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
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: _chatController,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Say hi...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const Gap(6),

          Consumer(builder: (context, ref, child) {
            final myUid = FirebaseAuth.instance.currentUser?.uid;
            final bool isHostOrAdmin = room.ownerUid == myUid || (room.admins.contains(myUid));
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

                if (isHostOrAdmin)
                   _buildCompactBottomButton(Icons.live_tv_rounded, const Color(0xFFFF0000), _showYouTubePanel),

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

  Widget _buildHostSeat(Participant host, RoomModel room) {
    if (host.uid.isEmpty) {
      return GestureDetector(
        onTap: () => _onSeatTap(0, [], room),
        child: Container(
          width: 70, height: 70,
          decoration: BoxDecoration(color: Colors.black12, shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
          child: const Icon(Icons.person, color: Colors.white24, size: 32),
        ),
      );
    }

    final userAsync = ref.watch(userProfileProvider(host.uid));

    return GestureDetector(
      onTap: () => _showUserOptions(host),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🚀 Center it up
        children: [
          userAsync.when(
            data: (user) {
              final u = user as UserModel;
              final currentUid = ref.watch(authStateProvider).value?.uid;
              final isMe = currentUid == u.uid;
              final isRoomOwner = currentUid == room.ownerUid;
              final showSecretFrame = isMe && isRoomOwner;

              final displayFrame = u.profileFrame;
              const double frameMult = 2.3;

              return Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildHostRipple(),
                      AppAvatar(
                        imageUrl: u.profilePhotoUrl,
                        frameUrl: displayFrame,
                        vipTier: u.vipTier,
                        tags: u.tags,
                        radius: 28,
                        showFrame: true,
                        frameMultiplier: frameMult,
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10, width: 0.5),
                      ),
                      child: Text(
                        u.displayName,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (host.isMuted)
                     Positioned(
                      top: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_off, color: Colors.white, size: 10),
                      ),
                    ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, __) => const Icon(Icons.error, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildHostRipple() {
    return Container(
      width: 75, height: 75,
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
    final roomAsync = ref.read(currentRoomStreamProvider(widget.roomId));
    
    participantsAsync.whenData((pts) {
      roomAsync.whenData((room) {
        if (room == null) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => ViewersListSheet(
            roomId: widget.roomId,
            participants: pts,
            ownerUid: room.ownerUid,
            onUserSelected: (p) => _showUserOptions(p),
          ),
        );
      });
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
              leading: const Icon(Icons.grid_view_rounded, color: Colors.blueAccent),
              title: const Text("Manage Room Capacity", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Expand to 8, 12, or 16 seats", style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                _showCapacitySettings();
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

  void _showCapacitySettings() {
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
            const Text("Room Expansion", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(8),
            const Text("Choose how many seats to unlock in your room.", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const Gap(20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [8, 12, 16].map((cap) => GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(roomServiceProvider).setRoomCapacity(widget.roomId, cap);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Room expanded to $cap seats!")),
                    );
                  }
                },
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("$cap", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text("SEATS", style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
              )).toList(),
            ),
            const Gap(32),
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

  void _onSeatTap(int index, List<Participant> participants, RoomModel room) async {
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
      if (room.lockedSeats.contains(index)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This seat is locked by host")),
        );
        return;
      }
      await ref.read(roomServiceProvider).takeSeat(widget.roomId, index);
    } else if (participantOnSeat.uid == uid) {
      _showMySeatOptions(myParticipation);
    } else {
      _showUserOptions(participantOnSeat);
    }
  }

  void _onSeatLongPress(int index, RoomModel room) {
    final myUid = ref.read(authStateProvider).value?.uid;
    final isHostOrAdmin = room.ownerUid == myUid || room.admins.contains(myUid);
    
    if (!isHostOrAdmin) return;

    final isLocked = room.lockedSeats.contains(index);

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
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              "Seat ${index + 1} Options",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isLocked ? Colors.greenAccent : Colors.redAccent).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLocked ? Icons.lock_open_rounded : Icons.lock_rounded, 
                  color: isLocked ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              title: Text(
                isLocked ? "Unlock Seat" : "Lock Seat", 
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                isLocked ? "Allow users to take this seat" : "Prevent users from taking this seat",
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(roomServiceProvider).toggleSeatLock(room.roomId, index, !isLocked);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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
                await ref.read(voiceServiceProvider).muteLocalAudio(newMuteStatus);
                await ref.read(roomServiceProvider).muteUser(widget.roomId, myPart.uid, newMuteStatus);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: const Text("Leave Seat", style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(voiceServiceProvider).muteLocalAudio(true);
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
        ref.read(voiceServiceProvider).leaveRoom();
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
