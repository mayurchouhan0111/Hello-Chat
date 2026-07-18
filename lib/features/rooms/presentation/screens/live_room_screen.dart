import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello_chat/core/services/wakelock_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/overlay_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/emoji_reaction.dart';
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
import '../../../../core/widgets/svga_player.dart';
import '../../../../core/services/broadcast_service.dart';
import '../../../../core/services/report_service.dart';
import '../../../../services/voice_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/viewers_list_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/providers/room_reactions_provider.dart';

import '../../../games/presentation/widgets/games_panel.dart';
import '../widgets/room_star_progress_widget.dart';
import '../widgets/room_settings_sheet.dart';
import '../widgets/room_user_options_sheet.dart';
import '../widgets/youtube_panel.dart';
import '../widgets/youtube_room_player.dart';
import '../widgets/room_invite_sheet.dart';
import '../widgets/rocket_progress_widget.dart';
import '../widgets/rocket_launch_overlay.dart';
import '../widgets/rocket_completion_vap_overlay.dart';
import '../widgets/sticker_sheet.dart';
import '../widgets/share_room_sheet.dart';
import '../widgets/rocket_reward_explosion_overlay.dart';
import '../widgets/audio_call_invite_dialog.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../core/models/room_banner_model.dart';
import 'package:url_launcher/url_launcher.dart';

class _OverlappingAvatarItem extends ConsumerStatefulWidget {
  final Participant participant;
  final double radius;

  const _OverlappingAvatarItem({
    required this.participant,
    required this.radius,
  });

  @override
  ConsumerState<_OverlappingAvatarItem> createState() => _OverlappingAvatarItemState();
}

class _OverlappingAvatarItemState extends ConsumerState<_OverlappingAvatarItem> {
  @override
  Widget build(BuildContext context) {
    final liveUser = ref.watch(userProfileProvider(widget.participant.uid)).value;
    final p = widget.participant;

    final String effectivePhoto = liveUser?.profilePhotoUrl.isNotEmpty == true
        ? liveUser!.profilePhotoUrl
        : (p.profilePhotoUrl.isNotEmpty ? p.profilePhotoUrl : "https://picsum.photos/seed/${p.uid}/100");
    final String effectiveFrame = liveUser?.profileFrame.isNotEmpty == true
        ? liveUser!.profileFrame
        : p.profileFrame;
    final String effectiveVip = liveUser?.vipTier.isNotEmpty == true ? liveUser!.vipTier : p.vipTier;
    final int effectiveLevel = liveUser?.level ?? p.level;
    final List<String> effectiveTags = liveUser?.tags.isNotEmpty == true ? liveUser!.tags : p.tags;

    return AppAvatar(
      radius: widget.radius,
      imageUrl: effectivePhoto,
      frameUrl: effectiveFrame,
      vipTier: effectiveVip,
      userLevel: effectiveLevel,
      tags: effectiveTags,
    );
  }
}

class LiveRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LiveRoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}


class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> with WidgetsBindingObserver {
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0.0;
    if (_wasKeyboardVisible && !isKeyboardVisible && _chatFocusNode.hasFocus) {
      _chatFocusNode.unfocus();
    }
    _wasKeyboardVisible = isKeyboardVisible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      debugPrint('[ROOM_LIFECYCLE] App resumed for room ${widget.roomId}');
      try {
        ref.read(roomServiceProvider).updateParticipantPresence(widget.roomId);
      } catch (_) {}
      WakelockService().acquire();
      ref.read(voiceServiceProvider).onAppResumed();

      _presenceTimer?.cancel();
      _startPresenceTimer();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('[ROOM_LIFECYCLE] App paused for room ${widget.roomId}');
      try {
        ref.read(roomServiceProvider).updateParticipantPresence(widget.roomId);
      } catch (_) {}
      WakelockService().release();
      ref.read(voiceServiceProvider).onAppPaused();
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
  bool _isRocketNotificationShowing = false;
  int _notificationCountdown = 10;
  Timer? _notificationTimer;
  bool _isRocketFlying = false;
  bool _isRocketLaunching = false;
  int _launchingLevel = 1;
  bool _isRocketLanding = false;
  int _landingCountdown = 6;
  bool _showExplosionOverlay = false;
  Map<String, int> _launchContributions = {};
  Timer? _landingTimer;
  bool _isMinimizing = false;
  bool _hasJoinedRoom = false;
  bool _hasShownMyOwnEntry = false;
  bool _isUploadingImage = false;

  final PageController _bannerPageController = PageController();
  Timer? _bannerTimer;
  int _bannerCurrentPage = 0;

  final FocusNode _chatFocusNode = FocusNode();
  bool _isChatFocused = false;
  bool _wasKeyboardVisible = false;

  // Store needed providers to avoid ref reads during dispose
  late final VoiceService _voiceService;

  void _showUserOptions(Participant p) async {
    final uid = ref.read(authStateProvider).value?.uid;
    final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
    if (uid == null || room == null) return;

    final bool isHost = room.ownerUid == uid;
    final bool isAdmin = room.admins.contains(uid);
    final bool isModerator = room.moderators.contains(uid);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomUserOptionsSheet(
        participant: p,
        roomId: widget.roomId,
        isHost: isHost,
        isAdmin: isAdmin,
        isModerator: isModerator,
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    
    // 🛡️ Auto-Clear PIP: If we are entering a room, hide any existing minimized bubbles.
    Future.microtask(() => ref.read(roomOverlayProvider.notifier).clear());
    WidgetsBinding.instance.addObserver(this);
    // Capture providers early to avoid ref reads in dispose
    _voiceService = ref.read(voiceServiceProvider);
    _chatFocusNode.addListener(() {
      if (mounted) setState(() => _isChatFocused = _chatFocusNode.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      try {
        final roomService = ref.read(roomServiceProvider);
        final authState = ref.read(authStateProvider).value;
        
        // Step 1: Join Firestore Room
        await roomService.joinRoom(widget.roomId);
        if (!mounted) return;
        if (mounted) setState(() => _hasJoinedRoom = true);
        
        // Step 2: Join Agora Channel (safe, non-fatal to other services)
        try {
          await _voiceService.joinRoom(widget.roomId, authState?.uid ?? 'guest');
        } catch (e) {
          debugPrint("⚠️ Non-fatal Agora join error: $e");
        }
        
        if (!mounted) return;
        
        // Step 3: Start Presence Heartbeat
        _startPresenceTimer();
        
        // Keep screen awake while in room
        await WakelockService().acquire();
      } catch (e) {
        if (mounted) {
          debugPrint("Error joining room services: $e");
        }
      }
    });

    _startBannerAutoScroll();
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final banners = ref.read(roomBannersProvider).valueOrNull ?? [];
      if (banners.isEmpty) return;
      final nextPage = (_bannerCurrentPage + 1) % banners.length;
      _bannerPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!mounted) return;
      try {
        await ref.read(roomServiceProvider).updateParticipantPresence(widget.roomId);
      } catch (e) {
        debugPrint('[ROOM_PRESENCE] Presence update failed for room ${widget.roomId}: $e');
      }
    });
  }

  @override
  void dispose() {
    // We check if the user is explicitly leaving. If not, auto-minimize to prevent dropping call.
    final voiceService = _voiceService;

    _notificationTimer?.cancel();
    _landingTimer?.cancel();
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    _chatFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();

    // 🎧 Voice Persistence Logic
    // If we are minimizing OR navigating away without explicitly leaving, we stay in the voice channel!
    if (!_isMinimizing && _isLeavingVoluntarily) {
      voiceService.leaveRoom();
    } else {
      // Auto-minimize if we navigate away (e.g. going to messages) without leaving the room
      if (!_isLeavingVoluntarily && !_isLeavingRoom) {
         try {
           ref.read(roomOverlayProvider.notifier).minimize(widget.roomId);
         } catch (_) {}
      }
    }

    _chatController.dispose();

    // Disable wake lock when leaving room
    WakelockService().release();

    super.dispose();
  }

  void _leaveRoom() async {
    setState(() {
      _isLeavingRoom = true;
      _isLeavingVoluntarily = true;
    });
    
    final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
    final myUid = ref.read(authStateProvider).value?.uid;
    final router = GoRouter.of(context);
    final voiceService = ref.read(voiceServiceProvider);
    final roomService = ref.read(roomServiceProvider);
    
    if (room != null && myUid == room.ownerUid) {
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
        _isMinimizing = true;
        ref.read(roomOverlayProvider.notifier).minimize(widget.roomId, ctx: context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
      } else if (result == 'end') {
        await voiceService.leaveRoom();
        await roomService.endRoom(widget.roomId);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
      } else if (result == 'leave') {
        await voiceService.leaveRoom();
        await roomService.leaveRoom(widget.roomId);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
      } else {
        if (mounted) setState(() => _isLeavingRoom = false);
      }
    } else {
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
        ref.read(roomOverlayProvider.notifier).minimize(widget.roomId, ctx: context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
      } else if (result == 'leave') {
        await voiceService.leaveRoom();
        await roomService.leaveRoom(widget.roomId);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
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

  void _showStickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StickerSheet(
        onStickerSelected: (path) async {
          final uid = ref.read(authStateProvider).value?.uid;
          if (uid == null) return;
          await ref.read(chatServiceProvider).sendStickerMessage(widget.roomId, uid, path);
        },
      ),
    );
  }

  void _pickAndUploadImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
            const Text(
              "Share Image",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerOption(context, Icons.camera_alt_outlined, "Camera", ImageSource.camera),
                _buildPickerOption(context, Icons.image_outlined, "Gallery", ImageSource.gallery),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.roomId)
          .child('${uid}_$timestamp.jpg');

      await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await storageRef.getDownloadURL();

      await ref.read(chatServiceProvider).sendImageMessage(widget.roomId, uid, downloadUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Widget _buildPickerOption(BuildContext context, IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateProvider.select((v) => v.value?.uid));
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.roomId));

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
                Future.microtask(() {
                  if (context.mounted) {
                    context.pop();
                  }
                });
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

          // 🚀 Rocket Launch Trigger
          if (prevRoom != null) {
    if (room.rocketLevel > prevRoom.rocketLevel) {
        // Use lastRocketResults (server-written accurate top 3) instead of prevRoom.rocketContributions
        // which gets wiped by the server after launch
        if (room.lastRocketResults != null) {
          final top3 = (room.lastRocketResults!['top3'] as List<dynamic>?) ?? [];
          _launchContributions = {};
          for (final entry in top3) {
            if (entry is Map && entry['uid'] != null && entry['amount'] != null) {
              _launchContributions[entry['uid'] as String] = (entry['amount'] as num).toInt();
            }
          }
        } else {
          _launchContributions = Map<String, int>.from(prevRoom.rocketContributions ?? {});
        }
        _showRocketLaunchAnimation(prevRoom.rocketLevel);
    }
          }
        }
      }
    });

    ref.listen(roomParticipantsProvider(widget.roomId), (prev, next) {
      if (!mounted) return;
      
      if (!_hasJoinedRoom) return;

      if (!_isLeavingVoluntarily && !_isLeavingRoom) {
        if (myUid != null && next.hasValue) {
          final participants = next.value!;
          final isStillIn = participants.any((p) => p.uid == myUid);
          if (prev != null && prev.hasValue) {
            final wasInRoom = prev.value!.any((p) => p.uid == myUid);
            if (wasInRoom && !isStillIn) {
              debugPrint('[ROOM_DISCONNECT] User $myUid removed from room ${widget.roomId}');
              debugPrint('[ROOM_DISCONNECT] Timestamp: ${DateTime.now().toIso8601String()}');
              debugPrint('[ROOM_DISCONNECT] Socket status: ${ref.read(voiceServiceProvider).isMuted}');
              debugPrint('[ROOM_DISCONNECT] _isLeavingVoluntarily: $_isLeavingVoluntarily, _isLeavingRoom: $_isLeavingRoom, _isMinimizing: $_isMinimizing');
              debugPrint('[ROOM_DISCONNECT] Room participants count: ${participants.length}');
              if (mounted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("You have been removed from the room."),
                    duration: const Duration(seconds: 3),
                  ),
                );
                if (GoRouter.of(context).canPop()) {
                  Future.microtask(() {
                    if (context.mounted) {
                      context.pop();
                    }
                  });
                }
              }
            }
          }
        }
      }

      if (myUid != null && prev != null && prev.hasValue && next.hasValue) {
        final prevMe = prev.value!.where((p) => p.uid == myUid).firstOrNull;
        final nextMe = next.value!.where((p) => p.uid == myUid).firstOrNull;
        if (prevMe != null && nextMe != null && prevMe.isMuted != nextMe.isMuted) {
          ref.read(voiceServiceProvider).muteLocalAudio(nextMe.isMuted);
        }
      }

      if (_entryParticipant == null && next.hasValue) {
        final pts = next.value!;
        final myUid = ref.read(authStateProvider).value?.uid;
        
        // Auto-show current user's entry effect once upon loading/re-entering the room
        if (!_hasShownMyOwnEntry && myUid != null) {
          final me = pts.where((p) => p.uid == myUid).firstOrNull;
          if (me != null) {
            _hasShownMyOwnEntry = true;
            if (mounted) {
              setState(() => _entryParticipant = me);
            }
            return;
          }
        }

        final now = DateTime.now();
        final prevUids = prev?.value?.map((p) => p.uid).toSet() ?? {};
        
        for (var p in pts) {
          if (p.uid == myUid) continue;
          final wasNotInRoom = !prevUids.contains(p.uid);
          final isNew = p.joinedAt.isAfter(now.subtract(const Duration(seconds: 10)));
          if (wasNotInRoom && isNew) {
             if (mounted) {
               setState(() => _entryParticipant = p);
             }
             break;
          }
        }
      }
    });

    ref.listen(roomMessagesProvider(widget.roomId), (prev, next) {
      if (!mounted) return;
      if (prev == null || !prev.hasValue || !next.hasValue) return;
      final prevMsgs = prev.value ?? [];
      final nextMsgs = next.value ?? [];
      for (final msg in nextMsgs) {
        if (msg.type != 'text' && msg.type != 'sticker') continue;
        final exists = prevMsgs.any((pm) => pm.msgId == msg.msgId);
        if (!exists) {
          if (msg.type == 'sticker' && msg.text.isNotEmpty) {
            final reaction = EmojiReaction(uid: msg.uid, assetPath: msg.text, timestamp: DateTime.now());
            ref.read(emojiReactionsProvider.notifier).update((state) => {...state, msg.uid: reaction});
            Future.delayed(const Duration(milliseconds: 1800), () {
              if (mounted) {
                ref.read(emojiReactionsProvider.notifier).update((state) {
                  final current = Map<String, EmojiReaction>.from(state);
                  if (current[msg.uid]?.timestamp == reaction.timestamp) {
                    current.remove(msg.uid);
                  }
                  return current;
                });
              }
            });
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
          final profiles = ref.watch(roomParticipantsProvider(widget.roomId));
          return profiles.when(
            data: (pts) => PKBattleArenaScreen(room: room, participants: pts),
            loading: () => const Scaffold(backgroundColor: Colors.blueAccent, body: Center(child: CircularProgressIndicator(color: Colors.white))),
            error: (e, __) => Scaffold(backgroundColor: Colors.deepPurple, body: Center(child: Text("PK UI Error: $e"))),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            ref.read(roomOverlayProvider.notifier).minimize(widget.roomId, ctx: context);
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/home');
            }
          },
          child: AudioCallInviteListener(
            roomId: widget.roomId,
            child: Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: false,
            body: GiftAnimationOverlay(
              roomId: widget.roomId,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CachedNetworkImage(
                        imageUrl: room.coverUrl.isEmpty ? "https://picsum.photos/seed/${room.roomId}/600/1200" : room.coverUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 600,
                        memCacheHeight: 1200,
                        errorWidget: (_, __, ___) => Container(color: Colors.black),
                      ),
                    ),
                  ),
                  Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

                  // BACKGROUND LAYER (Seats, Video - Stays fixed)
                  SafeArea(
                    child: Column(
                      children: [
                        _buildRoomAppBar(room),
                        Expanded(
                          child: Column(
                                children: [
                                YouTubeRoomPlayer(room: room, myUid: myUid),
                                  if (!room.isYoutubeActive) ...[
                                    const SizedBox(height: 8),
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final pts = ref.watch(roomParticipantsProvider(widget.roomId)).value ?? [];
                                        final hostPart = pts.firstWhere(
                                          (p) => p.seatIndex == 0,
                                          orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), isMuted: true, role: 'host'),
                                        );
                                        return _buildHostSeat(hostPart, room);
                                      },
                                    ),
                                  ],
                                  Expanded(
                                    child: SeatGrid(
                                      key: ValueKey('seatgrid_${widget.roomId}'),
                                      roomId: widget.roomId,
                                      capacity: room.capacity,
                                      lockedSeats: room.lockedSeats,
                                      isYoutubeActive: room.isYoutubeActive,
                                      ownerUid: room.ownerUid,
                                      onSeatTap: (idx) {
                                        final pts = ref.read(roomParticipantsProvider(widget.roomId)).value ?? [];
                                        _onSeatTap(idx, pts, room);
                                      },
                                      onSeatLongPress: (idx) => _onSeatLongPress(idx, room),
                                      onUserLongPress: _showUserOptions,
                                    ),
                                  ),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),

                  // ═══════════════════════════════════════════════════════════
                  // LAYER 2: SCROLLABLE CHAT MESSAGES + BROADCASTS
                  // ═══════════════════════════════════════════════════════════
                  Positioned(
                    bottom: 56 + 8 + MediaQuery.of(context).padding.bottom,
                    left: 4,
                    right: 70,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (MediaQuery.of(context).size.height * 0.24).clamp(160.0, 220.0),
                      ),
                      child: Consumer(
                        builder: (context, ref, child) {
                          final messagesAsync = ref.watch(roomMessagesProvider(widget.roomId));
                          final broadcasts = ref.watch(activeBroadcastsProvider).value ?? [];
                          
                          return messagesAsync.when(
                            data: (msgs) {
                              return ChatWidget(
                                messages: msgs,
                                broadcasts: broadcasts.isNotEmpty ? [broadcasts.first] : [],
                                onUserTap: (uid) {
                                  final pts = ref.read(roomParticipantsProvider(widget.roomId)).value ?? [];
                                  final p = pts.firstWhere(
                                    (p) => p.uid == uid, 
                                    orElse: () => Participant(
                                      uid: uid, 
                                      joinedAt: DateTime.now(), 
                                      lastActive: DateTime.now(), 
                                      isMuted: false, 
                                      role: 'audience',
                                    )
                                  );
                                  _showUserOptions(p);
                                },
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ),
                  ),

                  // ═══════════════════════════════════════════════════════════
                  // LAYER 3: BOTTOM INPUT BAR + ACTION BUTTONS
                  // Moves up with keyboard, everything else stays
                  // ═══════════════════════════════════════════════════════════
                  Positioned(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      child: _buildBottomBar(room),
                    ),
                  ),

                  // ═══════════════════════════════════════════════════════════
                  // LAYER 4: ROCKET WIDGET + BANNER CAROUSEL (fixed, right side)
                  // ═══════════════════════════════════════════════════════════
                  Positioned(
                    bottom: 60 + MediaQuery.of(context).padding.bottom,
                    right: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRoomBannerCarousel(),
                        const SizedBox(height: 8),
                        RocketProgressWidget(room: room),
                      ],
                    ),
                  ),

                  // PK CHALLENGE BANNER (conditional)
                  if (!room.pkActive && room.pkChallenge != null)
                    Positioned(
                      top: 100, left: 20, right: 20,
                      child: PKChallengeBanner(room: room),
                    ),
                  _buildRocketNotificationOverlay(),
                  _buildRocketFlyingOverlay(),
                  _buildRocketOverlay(),
                  _buildRocketLandingOverlay(room),
                  _buildExplosionOverlay(room),
                  if (_entryParticipant != null)
                    EntryEffectOverlay(
                      key: ValueKey('entry_${_entryParticipant!.uid}_${_entryParticipant!.joinedAt.millisecondsSinceEpoch}'),
                      participant: _entryParticipant!,
                      onEnd: () {
                        if (mounted) {
                          setState(() => _entryParticipant = null);
                        }
                      },
                    ),
                  if (_isUploadingImage)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    loading: () => const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator())),
    error: (e, __) => Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Error: $e"))),
  );
  }

  Widget _buildPinnedBroadcast(List<BroadcastModel> broadcasts) {
    if (broadcasts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF673AB7).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Text(
        broadcasts.first.message,
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
      ),
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

  Widget _buildRoomAppBar(RoomModel room) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final ownerAsync = ref.watch(cachedUserProfileProvider(room.ownerUid));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Row: Info & Controls
          Row(
            children: [
              // Consolidated Info & Spark Box - Clickable for Room Settings (Admin only)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final myUid = ref.watch(authStateProvider).value?.uid;
                    final isAdmin = room.ownerUid == myUid || room.admins.contains(myUid);
                    
                    return GestureDetector(
                      onTap: isAdmin ? () => _showRoomSettings(room) : null,
                      behavior: HitTestBehavior.opaque,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: ownerAsync.when(
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
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: Text(
                                                  room.name,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                                  maxLines: 1,
                                                ),
                                              ),
                                              Text(
                                                "ID:${u?.displayId ?? '...'}",
                                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Gap(8),
                                      ],
                                    );
                                  },
                                  loading: () => const SizedBox(width: 80, height: 40),
                                  error: (_, __) => const SizedBox(width: 80, height: 40),
                                ),
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
                      ),
                    );
                  },
                ),
              ),
              // Right Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCircleActionBtn(Icons.share_rounded, onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => ShareRoomSheet(
                        roomId: room.roomId,
                        roomName: room.name,
                      ),
                    );
                  }),
                  const Gap(10),
                  _buildCircleActionBtn(Icons.refresh_rounded, onTap: () {}),
                  const Gap(10),
                  _buildCircleActionBtn(Icons.zoom_in_map_rounded, onTap: () {
                     _isMinimizing = true;
                     final router = GoRouter.of(context);
                     ref.read(roomOverlayProvider.notifier).minimize(widget.roomId, ctx: context);
                     if (router.canPop()) {
                       router.pop();
                     } else {
                       router.go('/home');
                     }
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
              Consumer(
                builder: (context, ref, child) {
                  final participants = ref.watch(roomParticipantsProvider(widget.roomId)).value ?? [];
                  return GestureDetector(
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
                  );
                }
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
              child: _OverlappingAvatarItem(
                participant: topParticipants[index],
                radius: 11,
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
    return Consumer(builder: (context, ref, child) {
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      final bool isHostOrAdmin = room.ownerUid == myUid || (room.admins.contains(myUid));

      return Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Text input (always expands to take remaining space) ──────
            Expanded(
              child: Container(
                key: const ValueKey('chat_input_container'),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Keep index 0 stable to prevent TextField recreation and focus loss
                    SizedBox(
                      width: _isChatFocused ? 0 : 30,
                      child: Visibility(
                        visible: !_isChatFocused,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54, size: 18),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('chat_textfield'),
                        controller: _chatController,
                        focusNode: _chatFocusNode,
                        cursorColor: Colors.white,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: "Say hi...",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    if (_isChatFocused) ...[
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: Colors.white70, size: 20),
                        onPressed: _pickAndUploadImage,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 20),
                        onPressed: _showStickerSheet,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white70, size: 20),
                        onPressed: _sendMessage,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ),

            // ── Action buttons (wrapped in SizedBox/Visibility to maintain layout state and prevent focus loss) ──
            SizedBox(
              width: _isChatFocused ? 0 : null,
              height: _isChatFocused ? 0 : null,
              child: Visibility(
                visible: !_isChatFocused,
                maintainState: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Gap(6),
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
                        },
                      ),
                      Consumer(builder: (context, ref, child) {
                        final participants = ref.watch(roomParticipantsProvider(widget.roomId)).value ?? [];
                        final myUid2 = ref.watch(authStateProvider).value?.uid;
                        final myPart = participants.where((p) => p.uid == myUid2 && p.seatIndex != -1).firstOrNull;
                        if (myPart == null) return const SizedBox.shrink();
                        return _buildCompactBottomButton(
                          myPart.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          myPart.isMuted ? Colors.redAccent : Colors.white,
                          () async {
                            final newMute = !myPart.isMuted;
                            await ref.read(voiceServiceProvider).muteLocalAudio(newMute);
                            await ref.read(roomServiceProvider).muteUser(widget.roomId, myUid2 ?? '', newMute);
                          },
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
                ),
              ),
            ),
          ],
        ),
      );
    });
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
    final allParticipants = ref.watch(roomParticipantsProvider(widget.roomId)).value ?? [];

    if (host.uid.isEmpty) {
      return GestureDetector(
        onTap: () => _onSeatTap(0, allParticipants, room),
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

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(child: HostRippleWidget(user: u)),
                          SizedBox(
                            width: 56, // radius 28 * 2
                            height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                AppAvatar(
                                  imageUrl: u.profilePhotoUrl,
                                  frameUrl: displayFrame,
                                  vipTier: u.vipTier,
                                  userLevel: u.level,
                                  tags: u.tags,
                                  radius: 28,
                                  showFrame: true,
                                  frameMultiplier: frameMult,
                                 ),
                                 SeatEmojiReactionWidget(uid: host.uid),
                              ],
                            ),
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
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("💎", style: TextStyle(fontSize: 8)),
                        const SizedBox(width: 4),
                        Text(
                          host.diamondsReceived >= 1000 
                              ? '${(host.diamondsReceived / 1000).toStringAsFixed(1)}k' 
                              : '${host.diamondsReceived}',
                          style: const TextStyle(color: Colors.yellowAccent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
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




  void _showPKPanel() {
    final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
    final myUid = ref.read(authStateProvider).value?.uid;

    if (room == null || myUid == null) return;

    // Only allow room owner to start PK
    if (room.ownerUid != myUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text("Only the room owner can start a PK Battle!", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

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
      sheetAnimationStyle: AnimationStyle(
        duration: Duration.zero,
        reverseDuration: Duration.zero,
      ),
      builder: (context) => GiftPanel(roomId: widget.roomId),
    );
  }

  void _onSeatTap(int index, List<Participant> participants, RoomModel room) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    if (index == 0 && room.ownerUid != uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the room owner can take the host seat"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
      try {
        await ref.read(roomServiceProvider).takeSeat(widget.roomId, index);
        await ref.read(voiceServiceProvider).setBroadcasterRole();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
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
                await ref.read(voiceServiceProvider).setAudienceRole();
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

  int _getTargetForLevel(int level) {
    switch (level) {
      case 0: return 1000000;
      case 1: return 2000000;
      case 2: return 3000000;
      case 3: return 5000000;
      case 4: return 10000000;
      default: return 10000000;
    }
  }

  void _showRocketLaunchAnimation(int level) {
    if (_isRocketNotificationShowing || _isRocketFlying || _isRocketLaunching) return;
    setState(() {
      _isRocketNotificationShowing = true;
      _launchingLevel = level;
      _notificationCountdown = 10;
    });
    _startNotificationTimer();
  }

  void _startNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_notificationCountdown > 1) {
        setState(() {
          _notificationCountdown--;
        });
      } else {
        timer.cancel();
        _dismissRocketNotification();
      }
    });
  }

  void _dismissRocketNotification() {
    _notificationTimer?.cancel();
    setState(() {
      _isRocketNotificationShowing = false;
      _isRocketFlying = true;
    });
  }

  Widget _buildRocketNotificationOverlay() {
    if (!_isRocketNotificationShowing) return const SizedBox.shrink();
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade900.withOpacity(0.95),
                Colors.orange.shade800.withOpacity(0.95),
                Colors.orange.shade700.withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade300.withOpacity(0.4), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEVEL ${_launchingLevel + 1} ROCKET',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A rocket is flying across the room!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismissRocketNotification,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_notificationCountdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismissRocketNotification,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _notificationCountdown / 10,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRocketFlyingOverlay() {
    if (!_isRocketFlying) return const SizedBox.shrink();
    return RocketLaunchOverlay(
      level: _launchingLevel,
      roomId: widget.roomId,
      onComplete: () {
        setState(() {
          _isRocketFlying = false;
          _isRocketLaunching = true;
        });
      },
    );
  }

  Widget _buildRocketOverlay() {
    if (!_isRocketLaunching) return const SizedBox.shrink();
    return RocketCompletionVapOverlay(
      level: _launchingLevel, 
      roomId: widget.roomId,
      onComplete: () {
        setState(() {
          _isRocketLaunching = false;
          _isRocketLanding = true;
          _landingCountdown = 6;
        });
        _startLandingTimer();
      },
    );
  }

  void _startLandingTimer() {
    _landingTimer?.cancel();
    _landingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_landingCountdown > 1) {
        setState(() {
          _landingCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isRocketLanding = false;
          _showExplosionOverlay = true;
        });
      }
    });
  }

  Widget _buildRocketLandingOverlay(RoomModel room) {
    if (!_isRocketLanding) return const SizedBox.shrink();

    // Prefer lastRocketResults (server-written) over _launchContributions
    String? targetUid;
    if (room.lastRocketResults != null) {
      final top3 = (room.lastRocketResults!['top3'] as List<dynamic>?) ?? [];
      if (top3.isNotEmpty && top3[0] is Map) {
        targetUid = (top3[0] as Map)['uid'] as String?;
      }
    }
    targetUid ??= _launchContributions.isNotEmpty
        ? (_launchContributions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))).first.key
        : room.ownerUid;

    final userAsync = ref.watch(cachedUserProfileProvider(targetUid));
    final user = userAsync.value;

    return Center(
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: Color(0xFFFFD700),
                size: 40,
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 600.ms),
            
            const Gap(12),
            const Text(
              "ROCKET LANDED!",
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const Text(
              "Preparing Reward Settlement...",
              style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
            ),
            const Gap(16),

            if (user != null) ...[
              const Align(
                alignment: Alignment.center,
                child: Text(
                  "TOP CONTRIBUTOR",
                  style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
              const Gap(8),
              AppAvatar(
                imageUrl: user.profilePhotoUrl,
                frameUrl: user.profileFrame,
                vipTier: user.vipTier,
                userLevel: user.level,
                tags: user.tags,
                radius: 28,
                showFrame: true,
              ),
              const Gap(8),
              Text(
                user.displayName.isNotEmpty ? user.displayName : user.username,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "ID: ${user.displayId}",
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
            
            const Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Text(
                "EXPLODING IN ${_landingCountdown}s",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }

  Widget _buildRoomBannerCarousel() {
    final bannersAsync = ref.watch(roomBannersProvider);
    final banners = bannersAsync.valueOrNull ?? [];

    if (banners.isEmpty) {
      return GestureDetector(
        onTap: () => context.push('/room-support', extra: {'roomId': widget.roomId}),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.support_agent_rounded, color: Color(0xFFCC00FF), size: 16),
              const SizedBox(width: 4),
              const Text('Support', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PageView.builder(
              controller: _bannerPageController,
              onPageChanged: (index) {
                setState(() => _bannerCurrentPage = index);
              },
              itemCount: banners.length,
              itemBuilder: (context, index) {
                final banner = banners[index];
                return GestureDetector(
                  onTap: () => _handleBannerTap(banner),
                  child: CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.black26,
                      child: const Center(
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black26,
                      child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 24),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (i) {
              final isActive = i == _bannerCurrentPage;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: isActive ? 8 : 5,
                height: isActive ? 8 : 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.white : Colors.white38,
                  border: isActive ? Border.all(color: Colors.white60, width: 1) : null,
                ),
              );
            }),
          ),
      ],
    );
  }

  void _handleBannerTap(RoomBannerModel banner) {
    if (banner.actionType == 'navigation') {
      context.push(banner.actionValue, extra: {'roomId': widget.roomId});
    } else if (banner.actionType == 'url') {
      final uri = Uri.tryParse(banner.actionValue);
      if (uri != null && uri.scheme.startsWith('http')) {
        launchUrl(uri, mode: LaunchMode.externalApplication).catchError((e) {
          debugPrint('[BANNER_TAP] Failed to launch URL: $e');
        });
      }
    }
  }

  Widget _buildExplosionOverlay(RoomModel room) {
    if (!_showExplosionOverlay) return const SizedBox.shrink();

    return RocketRewardExplosionOverlay(
      level: (_launchingLevel - 1).clamp(0, 4),
      contributions: _launchContributions,
      onClose: () {
        setState(() {
          _showExplosionOverlay = false;
        });
        ref.invalidate(walletBalanceProvider);
        ref.invalidate(currentUserProfileProvider);
      },
    );
  }
}

class HostRippleWidget extends ConsumerWidget {
  final UserModel user;

  const HostRippleWidget({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakingUids = ref.watch(speakingUidsProvider).value ?? [];
    final int agoraUid = user.uid.hashCode & 0xFFFFFFFF;
    final bool isSpeaking = speakingUids.contains(agoraUid);

    if (!isSpeaking) return const SizedBox.shrink();

    final wavesPath = getVipMicWavesPath(user.vipTier);
    if (wavesPath != null) {
      return OverflowBox(
        maxWidth: 250,
        maxHeight: 250,
        child: SizedBox(
          width: 180,
          height: 180,
          child: IgnorePointer(
            child: SvgaPlayer(
              key: ValueKey('host_sound_waves_${user.vipTier}'),
              assetPath: wavesPath,
            ),
          ),
        ),
      );
    }
    final frameMult = user.profileFrame.isNotEmpty ? 2.3 : 1.0;
    final double baseRippleSize = 28 * 2 * frameMult;
    return Container(
      width: baseRippleSize + 10, height: baseRippleSize + 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 2),
      ),
    ).animate(onPlay: (c) => c.repeat()).scale(
      begin: const Offset(1, 1), end: const Offset(1.3, 1.3),
      duration: const Duration(seconds: 1), curve: Curves.easeOut
    ).fadeOut();
  }
}
