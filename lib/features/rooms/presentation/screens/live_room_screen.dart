import 'dart:async';
import 'package:hello_chat/core/widgets/app_toast.dart';
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
import '../../../../core/models/room_theme_model.dart';
import '../../../../core/models/gift_model.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/svip_level_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/overlay_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/emoji_reaction.dart';
import '../../../../core/router/app_router.dart';
import '../widgets/seat_grid.dart';
import '../widgets/chat_widget.dart';
import '../widgets/gift_panel.dart';
import '../widgets/quick_send_combo_bar.dart';
import '../widgets/pk_matching_bottom_sheet.dart';
import '../widgets/gift_animation_overlay.dart';
import '../widgets/pk_battle_widget.dart';
import '../widgets/active_pk_battle_grid.dart';
import 'pk_battle_arena_screen.dart';
import '../widgets/pk_challenge_banner.dart';
import '../widgets/live_activity_feed.dart';
import '../widgets/entry_effect_overlay.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/svga_player.dart';
import '../../../../core/services/broadcast_service.dart';
import '../../../../core/services/report_service.dart';
import '../../../../core/utils/week_helper.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../services/voice_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/viewers_list_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/providers/room_reactions_provider.dart';

import '../../../games/presentation/widgets/games_panel.dart';
import '../../../games/presentation/widgets/unified_games_hub_sheet.dart';
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
import '../widgets/rocket_winner_popup_overlay.dart';

import '../widgets/audio_call_invite_dialog.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../core/models/room_banner_model.dart';
import '../../../../services/room_support_service.dart';
import '../../../../core/providers/room_support_provider.dart';
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

class _QuickSendState {
  final GiftModel gift;
  final String targetUid;
  final String targetName;
  final String targetPhoto;
  final int startCount;

  const _QuickSendState({
    required this.gift,
    required this.targetUid,
    required this.targetName,
    required this.targetPhoto,
    required this.startCount,
  });
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> with WidgetsBindingObserver {
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

  // ── Quick Send / Repeat Combo (docked bar, see quick_send_combo_bar.dart) ──
  // Isolated notifier: changes rebuild ONLY the bottom bar, not the entire live room tree.
  final ValueNotifier<_QuickSendState?> _quickSendNotifier = ValueNotifier<_QuickSendState?>(null);
  Participant? _entryParticipant;
  Timer? _presenceTimer;
  bool _isLeavingRoom = false;
  bool _isLeavingVoluntarily = false;
  bool _hasLeftRoom = false;
  bool _isRocketNotificationShowing = false;
  final ValueNotifier<int> _notificationCountdownNotifier = ValueNotifier<int>(10);
  Timer? _notificationTimer;
  bool _isRocketFlying = false;
  bool _isRocketLaunching = false;
  int _launchingLevel = 1;
  bool _isRocketLanding = false;
  final ValueNotifier<int> _landingCountdownNotifier = ValueNotifier<int>(6);
  bool _showExplosionOverlay = false;
  Map<String, int> _launchContributions = {};
  Timer? _landingTimer;
  final List<int> _rocketLaunchQueue = [];

  void _processNextRocketQueueItem() {
    if (!mounted) return;
    if (_isRocketNotificationShowing || _isRocketFlying || _isRocketLaunching || _isRocketLanding || _showExplosionOverlay) {
      return;
    }
    if (_rocketLaunchQueue.isNotEmpty) {
      final nextLevel = _rocketLaunchQueue.removeAt(0);
      _showRocketLaunchAnimation(nextLevel);
    }
  }
  bool _isMinimizing = false;
  bool _hasJoinedRoom = false;
  bool _hasShownMyOwnEntry = false;
  bool _isUploadingImage = false;
  int? _optimisticSeatIndex;

  final PageController _bannerPageController = PageController();
  Timer? _bannerTimer;
  int _bannerCurrentPage = 0;
  final ValueNotifier<int> _bannerCurrentPageNotifier = ValueNotifier<int>(0);
  Timer? _explosionAutoDismissTimer;

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
        onQuickSendActivated: _onQuickSendActivated,
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    
    // Check if restoring an active ongoing room session (from minimize / PIP)
    final overlayNotifier = ref.read(roomOverlayProvider.notifier);
    final bool isRestoringSession = overlayNotifier.isRestoringSession(widget.roomId);
    if (isRestoringSession) {
      _hasShownMyOwnEntry = true;
    }

    // 🛡️ Auto-Clear PIP: If we are entering a room, hide any existing minimized bubbles.
    Future.microtask(() => ref.read(roomOverlayProvider.notifier).clear());
    WidgetsBinding.instance.addObserver(this);
    // Capture providers early to avoid ref reads in dispose
    _voiceService = ref.read(voiceServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      try {
        final roomService = ref.read(roomServiceProvider);
        final authState = ref.read(authStateProvider).value;
        final isRestoring = ref.read(roomOverlayProvider.notifier).isRestoringSession(widget.roomId);

        if (!isRestoring) {
          // Register fresh active session and join room in Firestore
          ref.read(roomOverlayProvider.notifier).registerActiveSession(widget.roomId);
          await roomService.joinRoom(widget.roomId);
        }
        if (!mounted) return;
        if (mounted) setState(() => _hasJoinedRoom = true);
        
        // Step 2: Join Agora Channel (safe, non-fatal to other services)
        try {
          await _voiceService.joinRoom(widget.roomId, authState?.uid ?? 'guest');
        } catch (e) {
          debugPrint("⚠️ Non-fatal Agora join error: $e");
        }
        
        if (!mounted) return;

        // Step 2.5: Auto-promote Room Owner / Seated User to Broadcaster Role
        try {
          final myUid = authState?.uid;
          if (myUid != null) {
            var room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
            String? ownerUid = room?.ownerUid;
            if (ownerUid == null) {
              try {
                final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
                if (roomDoc.exists) {
                  ownerUid = roomDoc.data()?['ownerUid'] as String?;
                }
              } catch (_) {}
            }
            final isOwner = ownerUid == myUid;
            if (isOwner) {
              debugPrint("🎙️ [ROOM_ENTRY] Current user is Room Owner ($myUid). Setting Agora Broadcaster role & unmuting mic.");
              await _voiceService.setBroadcasterRole();
              await _voiceService.muteLocalAudio(false);
              await roomService.muteUser(widget.roomId, myUid, false);
            }
          }
        } catch (e) {
          debugPrint("⚠️ Non-fatal role init error: $e");
        }
        
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
      if (!_bannerPageController.hasClients) return;
      final nextPage = (_bannerCurrentPage + 1) % banners.length;
      _bannerPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _triggerRocketHeartbeat() {
    try {
      ref.read(roomServiceProvider).updateParticipantPresence(widget.roomId);
    } catch (_) {}
  }

  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    // Trigger immediate initial heartbeat
    _triggerRocketHeartbeat();
    _presenceTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
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
    _notificationCountdownNotifier.dispose();
    _landingCountdownNotifier.dispose();
    _quickSendNotifier.dispose();
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();

    // 🎧 Voice Persistence Logic
    // If we are minimizing OR navigating away without explicitly leaving, we stay in the voice channel!
    if (!_hasLeftRoom && !_isMinimizing && _isLeavingVoluntarily) {
      _hasLeftRoom = true;
      debugPrint('🚪 [ROOM_EXIT] Reason: LiveRoomScreen.dispose voluntary leave roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
      voiceService.leaveRoom();
    } else {
      // Auto-minimize if we navigate away (e.g. going to messages) without leaving the room
      if (!_isLeavingVoluntarily && !_isLeavingRoom) {
         try {
           debugPrint('🚪 [ROOM_EXIT] Reason: LiveRoomScreen.dispose auto-minimizing roomId=${widget.roomId}');
           ref.read(roomOverlayProvider.notifier).minimize(widget.roomId);
         } catch (_) {}
      }
    }

    _explosionAutoDismissTimer?.cancel();
    _bannerCurrentPageNotifier.dispose();
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
            TextButton(
              onPressed: () => Navigator.pop(context, 'leave'),
              child: const Text("LEAVE", style: TextStyle(color: Colors.amberAccent)),
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
        debugPrint('🚪 [ROOM_EXIT] Reason: Host chosen minimize for roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
        ref.read(roomOverlayProvider.notifier).minimize(widget.roomId, ctx: context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
      } else if (result == 'end') {
        _hasLeftRoom = true;
        debugPrint('🚪 [ROOM_EXIT] Reason: Host ended room for roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
        ref.read(roomOverlayProvider.notifier).endSession(widget.roomId);
        await Future.wait([
          voiceService.leaveRoom(),
          roomService.endRoom(widget.roomId),
        ]);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
      } else if (result == 'leave') {
        _hasLeftRoom = true;
        debugPrint('🚪 [ROOM_EXIT] Reason: Host voluntary leave without ending roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
        ref.read(roomOverlayProvider.notifier).endSession(widget.roomId);
        await Future.wait([
          voiceService.leaveRoom(),
          roomService.leaveRoom(widget.roomId),
        ]);
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
        debugPrint('🚪 [ROOM_EXIT] Reason: Listener chosen minimize for roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
        ref.read(roomOverlayProvider.notifier).minimize(widget.roomId, ctx: context);
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/home');
        }
      } else if (result == 'leave') {
        _hasLeftRoom = true;
        debugPrint('🚪 [ROOM_EXIT] Reason: Listener voluntary leave for roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
        ref.read(roomOverlayProvider.notifier).endSession(widget.roomId);
        await Future.wait([
          voiceService.leaveRoom(),
          roomService.leaveRoom(widget.roomId),
        ]);
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
      isScrollControlled: true,
      builder: (sheetContext) => StickerSheet(
        onStickerSelected: (stickerPath) async {
          final uid = ref.read(authStateProvider).value?.uid;
          if (uid == null) return;
          await ref.read(chatServiceProvider).sendStickerMessage(
            widget.roomId,
            uid,
            stickerPath,
          );
        },
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
              debugPrint('🚪 [ROOM_EXIT] Reason: Host has ended room (room.status==ended) for roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
              ScaffoldMessenger.of(context).showSnackBar(
                TopSnackBar(context: context, content: const Text("The host has ended this room.")),
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
                    ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
                        content: Text("👉 The user has rejected the PK request"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                 } else if (status == 'expired') {
                    ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("The PK challenge has expired.")),
                    );
                 }
               }
            }
          }

          // 🚀 Rocket Launch Trigger with Multi-Rocket Queueing
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
              for (int lv = prevRoom.rocketLevel; lv < room.rocketLevel; lv++) {
                if (!_rocketLaunchQueue.contains(lv)) {
                  _rocketLaunchQueue.add(lv);
                }
              }
              _processNextRocketQueueItem();
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
              debugPrint('[ROOM_DISCONNECT] User $myUid missing from room ${widget.roomId} participant list');
              debugPrint('[ROOM_DISCONNECT] Timestamp: ${DateTime.now().toIso8601String()}');
              debugPrint('[ROOM_DISCONNECT] Socket status: ${ref.read(voiceServiceProvider).isMuted}');
              debugPrint('[ROOM_DISCONNECT] _isLeavingVoluntarily: $_isLeavingVoluntarily, _isLeavingRoom: $_isLeavingRoom, _isMinimizing: $_isMinimizing');
              debugPrint('[ROOM_DISCONNECT] Room participants count: ${participants.length}');
              final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
              final isBanned = room != null && room.bannedUids.contains(myUid);
              final isEnded = room != null && room.status == 'ended';

              if (isBanned || isEnded) {
                debugPrint('🚪 [ROOM_EXIT] Reason: User removed from participant list (isBanned=$isBanned, isEnded=$isEnded) for roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
                      content: Text(isBanned ? "You have been removed from the room." : "This room has ended."),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  Future.microtask(() {
                    if (context.mounted) {
                      if (GoRouter.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    }
                  });
                }
              } else {
                // Non-ban participant list transient fluctuation or reap: auto-heal presence
                debugPrint('[ROOM_PRESENCE] Transient participant drop for $myUid in ${widget.roomId}. Auto-rejoining presence...');
                ref.read(roomServiceProvider).updateParticipantPresence(widget.roomId);
              }
            }
          }
        }
      }

      if (myUid != null && next.hasValue) {
        final pts = next.value!;
        final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
        final me = pts.where((p) => p.uid == myUid).firstOrNull;
        final isOwner = room != null && room.ownerUid == myUid;
        final isOnSeat = isOwner || (me != null && (me.seatIndex ?? -1) >= 0);
        final voice = ref.read(voiceServiceProvider);

        if (isOnSeat) {
          final bool currentMute = me?.isMuted ?? false;
          if (!voice.isBroadcaster) {
            voice.setBroadcasterRole();
          }
          if (prev != null && prev.hasValue) {
            final prevMe = prev.value!.where((p) => p.uid == myUid).firstOrNull;
            if (prevMe == null || prevMe.isMuted != currentMute) {
              voice.muteLocalAudio(currentMute);
            }
          } else {
            voice.muteLocalAudio(currentMute);
          }
        } else if (!isOwner && (me == null || (me.seatIndex ?? -1) < 0)) {
          if (voice.isBroadcaster) {
            voice.setAudienceRole();
          }
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
    
    ref.listen<AsyncValue<List<Participant>>>(roomParticipantsProvider(widget.roomId), (prev, next) {
      if (_optimisticSeatIndex != null) {
        final pts = next.value ?? [];
        final myUid = ref.read(authStateProvider).value?.uid;
        if (myUid != null) {
          if (_optimisticSeatIndex == -1) {
            final me = pts.firstWhere((p) => p.uid == myUid, orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), isMuted: false, role: 'none'));
            if (me.uid.isEmpty || me.seatIndex == null || me.seatIndex! < 0) {
              setState(() => _optimisticSeatIndex = null);
            }
          } else {
            if (pts.any((p) => p.uid == myUid && p.seatIndex == _optimisticSeatIndex)) {
              setState(() => _optimisticSeatIndex = null);
            }
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
            debugPrint('🚪 [ROOM_EXIT] Reason: PopScope back navigation minimizing roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
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
            body: Stack(
              children: [
                GiftAnimationOverlay(
                  roomId: widget.roomId,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: _buildRoomBackground(room),
                        ),
                      ),
                      Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4))),

                      // BACKGROUND LAYER (Seats, Video - Stays fixed)
                      SafeArea(
                        child: Column(
                          children: [
                            RepaintBoundary(child: _buildRoomAppBar(room)),
                            Expanded(
                              child: Column(
                                    children: [
                                    YouTubeRoomPlayer(room: room, myUid: myUid),
                                      if (!room.isYoutubeActive) ...[
                                        Consumer(
                                          builder: (context, ref, child) {
                                            final pts = ref.watch(roomParticipantsProvider(widget.roomId)).value ?? [];
                                            final hostPart = pts.firstWhere(
                                              (p) => p.uid == room.ownerUid,
                                              orElse: () => pts.firstWhere(
                                                (p) => p.seatIndex == 0,
                                                orElse: () => Participant(uid: room.ownerUid, joinedAt: DateTime.now(), lastActive: DateTime.now(), isMuted: false, role: 'owner', seatIndex: 0),
                                              ),
                                            );
                                            return KeyedSubtree(
                                              key: ValueKey('host_seat_${widget.roomId}_${room.isYoutubeActive}_${hostPart.diamondsReceived}'),
                                              child: RepaintBoundary(child: _buildHostSeat(hostPart, room, pts)),
                                            );
                                          },
                                        ),
                                      ],
                                      Expanded(
                                        child: SeatGrid(
                                          key: ValueKey('seatgrid_${widget.roomId}_${room.isYoutubeActive}'),
                                          roomId: widget.roomId,
                                          capacity: room.capacity,
                                          lockedSeats: room.lockedSeats,
                                          isYoutubeActive: room.isYoutubeActive,
                                          ownerUid: room.ownerUid,
                                          optimisticMySeatIndex: _optimisticSeatIndex,
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
                                    roomId: widget.roomId,
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
                      // LAYER 3: INTERACTIVE ROOM BOTTOM BAR (Chat input or Morphing Combo Bar)
                      // When a gift is sent, this bar smoothly transforms into the Combo Bar
                      // and smoothly returns when the combo finishes, eliminating overlaps.
                      // ═══════════════════════════════════════════════════════════
                      Positioned(
                        bottom: MediaQuery.of(context).padding.bottom + 4,
                        left: 0,
                        right: 0,
                        child: ValueListenableBuilder<_QuickSendState?>(
                          valueListenable: _quickSendNotifier,
                          builder: (context, qs, _) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: RepaintBoundary(child: child),
                                  ),
                                );
                              },
                              child: qs != null
                                  ? KeyedSubtree(
                                      key: ValueKey('combo_${qs.gift.giftId}_${qs.targetUid}'),
                                      child: QuickSendComboBar(
                                        key: ValueKey('bar_${qs.gift.giftId}_${qs.targetUid}'),
                                        roomId: widget.roomId,
                                        gift: qs.gift,
                                        targetUid: qs.targetUid,
                                        targetName: qs.targetName,
                                        targetPhotoUrl: qs.targetPhoto,
                                        startCount: qs.startCount,
                                        onDismiss: _dismissQuickSend,
                                        onOpenGiftPicker: _showGiftPanel,
                                      ),
                                    )
                                  : KeyedSubtree(
                                      key: const ValueKey('normal_bottom_bar'),
                                      child: _buildBottomBar(room),
                                    ),
                            );
                          },
                        ),
                      ),

                      // ═══════════════════════════════════════════════════════════
                      // LAYER 4: RIGHT FLOATING ACTION COLUMN (Room Support & Rocket)
                      // ═══════════════════════════════════════════════════════════
                      Positioned(
                        bottom: 85 + MediaQuery.of(context).padding.bottom,
                        right: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Consumer(
                              builder: (context, ref, _) {
                                final cycle = ref.watch(roomSupportCycleProvider(widget.roomId)).valueOrNull;
                                final isCurrentWeek = cycle?['weekId'] == WeekHelper.getCurrentServerWeekId();
                                final totalCoins = isCurrentWeek ? ((cycle?['totalCoins'] as num?)?.toInt() ?? 0) : 0;
                                final lvl = RoomSupportService.calculateLevel(totalCoins);
                                final badgeText = lvl > 0 ? "LVL $lvl" : "SUPPORT";

                                return RepaintBoundary(
                                  child: GestureDetector(
                                    onTap: () {
                                      context.push('/room-support', extra: {'roomId': widget.roomId});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFFF9D00).withValues(alpha: 0.8),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [Color(0xFFFFB700), Color(0xFFFF3D00)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0xFFFF5500),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
                                          ),
                                          const Gap(3),
                                          Text(
                                            badgeText,
                                            style: const TextStyle(
                                              color: Color(0xFFFFD700),
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.6,
                                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                                      duration: 3.seconds,
                                      color: Colors.amber.withValues(alpha: 0.3),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            RepaintBoundary(child: RocketProgressWidget(room: room)),
                          ],
                        ),
                      ),

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
                // 🚀 ROCKET OVERLAY LAYER (Renders ABOVE GiftAnimationOverlay so rockets are never hidden)
                _buildRocketNotificationOverlay(),
                _buildRocketFlyingOverlay(),
                _buildRocketOverlay(),
                _buildRocketLandingOverlay(room),
                _buildExplosionOverlay(room),
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

  Widget _buildRoomBackground(RoomModel room) {
    Widget backgroundWidget;
    // Background is driven strictly by Room Theme (or custom backgroundUrl), NEVER coverUrl!
    if (room.backgroundUrl.isNotEmpty) {
      if (room.backgroundUrl.startsWith('assets/')) {
        backgroundWidget = Image.asset(
          room.backgroundUrl,
          fit: BoxFit.cover,
          cacheWidth: 1080,
          errorBuilder: (_, __, ___) => _buildFallbackTheme(room.theme),
        );
      } else {
        backgroundWidget = CachedNetworkImage(
          imageUrl: room.backgroundUrl,
          fit: BoxFit.cover,
          memCacheWidth: 1080,
          errorWidget: (_, __, ___) => _buildFallbackTheme(room.theme),
        );
      }
    } else {
      final theme = RoomThemeCatalog.getTheme(room.theme);
      if (theme.assetPath != null && theme.assetPath!.isNotEmpty) {
        backgroundWidget = Image.asset(
          theme.assetPath!,
          fit: BoxFit.cover,
          cacheWidth: 1080,
          errorBuilder: (_, __, ___) => _buildGradientBackground(theme.gradient),
        );
      } else if (theme.imageUrl != null && theme.imageUrl!.isNotEmpty) {
        backgroundWidget = CachedNetworkImage(
          imageUrl: theme.imageUrl!,
          fit: BoxFit.cover,
          memCacheWidth: 1080,
          errorWidget: (_, __, ___) => _buildGradientBackground(theme.gradient),
        );
      } else {
        backgroundWidget = _buildGradientBackground(theme.gradient);
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        backgroundWidget,
        // Ambient readability scrim ensuring seats, controls, and text are always visible
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.22),
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0.32),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientBackground(List<Color> gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
      ),
    );
  }

  Widget _buildFallbackTheme(String themeId) {
    final theme = RoomThemeCatalog.getTheme(themeId);
    return _buildGradientBackground(theme.gradient);
  }

  Widget _buildGlassOverlay({required Widget child, bool isBottom = false}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
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

  Widget _buildHostHeaderContent(RoomModel room, UserModel? u) {
    final ownerDisplayName = (u?.displayName.isNotEmpty == true && u!.displayName != 'Host' && u.displayName != 'Guest')
        ? u.displayName
        : (room.name.isNotEmpty ? room.name : (u?.username.isNotEmpty == true ? u!.username : 'Host'));
    final explicitId = u?.displayId ?? u?.helloId;
    final rawOwnerId = (explicitId ?? room.ownerUid).toString();
    // Public IDs are ~10 chars and must render in full: abbreviating to 8 chars with no
    // ellipsis let two different hosts display an identical "ID:30196666".
    // Only the raw Firebase UID fallback is shortened, and always with an ellipsis.
    final ownerIdString = explicitId != null || rawOwnerId.length <= 8
        ? rawOwnerId
        : '${rawOwnerId.substring(0, 8)}…';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(
          imageUrl: u?.profilePhotoUrl ?? '',
          radius: 17,
        ),
        const Gap(6),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ownerDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "ID:$ownerIdString",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.group_rounded, size: 11, color: Colors.white.withValues(alpha: 0.75)),
                    const SizedBox(width: 2),
                    Consumer(
                      builder: (context, ref, _) {
                        final count = ref.watch(roomParticipantsProvider(widget.roomId).select((p) => p.value?.length ?? 0));
                        return Text(
                          "$count",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(6),
      ],
    );
  }

  Widget _buildRoomAppBar(RoomModel room) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final ownerAsync = ref.watch(cachedUserProfileProvider(room.ownerUid));
    final isOwner = currentUid != null && currentUid == room.ownerUid;
    final isAdmin = currentUid != null && (room.isUserAdmin(currentUid) || room.admins.contains(currentUid));
    final canManageSettings = isOwner || isAdmin;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Row: Info & Controls
          Row(
            children: [
              // Consolidated Host Capsule - Clickable for Room Settings / Profile
              Expanded(
                child: Builder(
                  builder: (context) {
                    final myUid = ref.watch(authStateProvider).value?.uid;
                    final isUserAdmin = myUid != null && (room.ownerUid == myUid || room.admins.contains(myUid) || room.isUserAdmin(myUid));
                    final isOwnerUser = myUid != null && room.ownerUid == myUid;
                    
                    return GestureDetector(
                      onTap: isUserAdmin ? () => _showRoomSettings(room) : () => _showUserProfile(room.ownerUid),
                      behavior: HitTestBehavior.opaque,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.38),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: ownerAsync.when(
                                  data: (owner) => _buildHostHeaderContent(room, owner as UserModel?),
                                  loading: () => _buildHostHeaderContent(room, null),
                                  error: (_, __) => _buildHostHeaderContent(room, null),
                                ),
                              ),
                              // Spark Follow Button (Only for Non-Owners)
                              if (!isOwnerUser)
                                GestureDetector(
                                  onTap: () async {
                                    final myUid = ref.read(authStateProvider).value?.uid;
                                    if (myUid == null) return;
                                    
                                    await ref.read(profileServiceProvider).toggleFollow(myUid, room.ownerUid);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
                                          content: Text("Followed ${room.name}'s Host!"),
                                          backgroundColor: const Color(0xFF8E54E9),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFFFE000), Color(0xFFFFB700)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: Color(0x66FFB700), blurRadius: 6),
                                      ],
                                    ),
                                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 19),
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
              const Gap(8),
              // Right Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canManageSettings) ...[
                    _buildCircleActionBtn(Icons.settings_outlined, onTap: () => _showRoomSettings(room)),
                    const Gap(6),
                  ],
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
                  const Gap(6),
                  _buildCircleActionBtn(Icons.crop_free_rounded, onTap: () {
                     _isMinimizing = true;
                     final router = GoRouter.of(context);
                     ref.read(roomOverlayProvider.notifier).minimize(widget.roomId, ctx: context);
                     if (router.canPop()) {
                       router.pop();
                     } else {
                       router.go('/home');
                     }
                   }),
                  const Gap(6),
                  _buildCircleActionBtn(Icons.power_settings_new_rounded, isClose: true, onTap: _leaveRoom),
                ],
              ),
            ],
          ),
          const Gap(8),
          // 2. Bottom Row: Tags & Viewers
          Row(
            children: [
              GestureDetector(
                onTap: () => _openRoomGiftLeaderboard(room),
                child: _buildAppBarTag(
                  "${_formatDiamondCount(room.currentMonthlyTargetProgress)} >",
                  Icons.emoji_events_rounded,
                  const Color(0xFFFFD700),
                ),
              ),
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
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isClose ? const Color(0xFFEF4444).withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: isClose ? const Color(0xFFEF4444).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isClose ? const Color(0xFFEF4444).withValues(alpha: 0.2) : Colors.black26,
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }

  Widget _buildAppBarTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
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
    final currentUid = ref.read(authStateProvider).value?.uid;
    final isOwner = currentUid != null && currentUid == room.ownerUid;
    final isAdmin = currentUid != null && (room.isUserAdmin(currentUid) || room.admins.contains(currentUid));
    if (!isOwner && !isAdmin) return;

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
                image: DecorationImage(
                  image: ResizeImage.resizeIfNeeded(42, 42, NetworkImage(url)), 
                  fit: BoxFit.cover,
                ),
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
                image: DecorationImage(
                  image: ResizeImage.resizeIfNeeded(42, 42, NetworkImage(avatar)), 
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: Colors.white30, width: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }


  void _showRoomChatInputSheet({int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 8,
            top: 8,
            left: 12,
            right: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1116),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // 1. Gallery / Photo Icon
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadImage(source: ImageSource.gallery);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 10, left: 2),
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),

                // 2. Center Capsule Input with Smiley button
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222530),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            autofocus: true,
                            textInputAction: TextInputAction.send,
                            cursorColor: const Color(0xFF59F588),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              filled: false,
                              fillColor: Colors.transparent,
                              hintText: "Say Hi~",
                              hintStyle: TextStyle(
                                color: Color(0xFF858C9E),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) {
                              Navigator.pop(sheetContext);
                              _sendMessage();
                            },
                          ),
                        ),
                        // Smiley / Sticker trigger
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _showStickerSheet();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.sentiment_satisfied_alt_rounded,
                              color: Color(0xFFD1D5DB),
                              size: 23,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // 3. Send Pill Button (Vibrant Yellow to Lime-Mint Gradient)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _sendMessage();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF066), Color(0xFF59F588)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(19),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF59F588).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Send",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text("Uploading photo..."),
              ],
            ),
            backgroundColor: Color(0xFF6366F1),
            duration: Duration(seconds: 4),
          ),
        );
      }

      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return;

      final file = File(pickedFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.roomId)
          .child('${uid}_$timestamp.jpg');

      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final chatService = ref.read(chatServiceProvider);
      await chatService.sendImageMessage(widget.roomId, uid, downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
            content: Text("Photo shared successfully! 🖼️"),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
            content: Text("Failed to upload image: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildBottomBar(RoomModel room) {
    return Consumer(builder: (context, ref, child) {
      final myUid = ref.watch(authStateProvider).value?.uid;
      final participants = ref.watch(roomParticipantsProvider(widget.roomId)).value ?? [];
      final myPart = participants.firstWhere(
        (p) => p.uid == myUid,
        orElse: () => Participant(
          uid: myUid ?? '',
          joinedAt: DateTime.now(),
          lastActive: DateTime.now(),
          role: room.ownerUid == myUid ? 'owner' : 'audience',
          seatIndex: room.ownerUid == myUid ? 0 : -1,
          isMuted: false,
        ),
      );
      final bool isOwner = room.ownerUid == myUid;
      final bool isOnSeat = isOwner || (myPart.seatIndex ?? -1) >= 0;
      final bool isMicMuted = myPart.isMuted;

      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Chat bubble outline icon (opens chat input sheet)
            _buildBottomIcon(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => _showRoomChatInputSheet(initialTab: 0),
            ),

            // 2. Mail / Inbox outline icon with red badge '2'
            _buildInboxBottomIcon(
              onTap: () => context.push(AppRoutes.inbox),
            ),

            // 3. Speaker toggle icon
            _buildBottomIcon(
              icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              onTap: () {
                final nextSpeakerState = !_isSpeakerOn;
                setState(() => _isSpeakerOn = nextSpeakerState);
                ref.read(voiceServiceProvider).muteRoomAudio(!nextSpeakerState);
                if (mounted) {
                  if (nextSpeakerState) {
                    AppToast.showSuccess(context, "Room Audio Restored 🔊", title: "Speaker On");
                  } else {
                    AppToast.showWarning(context, "Room Audio Muted 🔇", title: "Speaker Muted");
                  }
                }
              },
            ),

            // 4. Dedicated circular mic button with outline ring
            _buildMicCircleButton(
              isOnSeat: isOnSeat,
              isMicMuted: isMicMuted,
              onTap: () async {
                if (myUid == null) return;
                if (!isOnSeat) {
                  AppToast.showWarning(context, "Please take a mic seat first to speak", title: "Mic Seat Required");
                  return;
                }

                final nextMute = !isMicMuted;
                final voice = ref.read(voiceServiceProvider);
                if (!voice.isBroadcaster) {
                  await voice.setBroadcasterRole();
                }
                await voice.muteLocalAudio(nextMute);
                await ref.read(roomServiceProvider).muteUser(widget.roomId, myUid, nextMute);

                if (mounted) {
                  if (nextMute) {
                    AppToast.showWarning(context, "Microphone Muted 🔇", title: "Mic Muted");
                  } else {
                    AppToast.showSuccess(context, "Microphone Active 🎙️", title: "Mic Active");
                  }
                }
              },
            ),

            // 5. Emoji / Stickers icon
            _buildBottomIcon(
              icon: Icons.sentiment_satisfied_alt_rounded,
              onTap: _showStickerSheet,
            ),

            // 6. Grid (4 squares) / Tools icon
            _buildBottomIcon(
              icon: Icons.grid_view_rounded,
              size: 23,
              onTap: () => _showGamesPanel(),
            ),

            // 7. Gamepad / Party Games icon
            _buildBottomIcon(
              icon: Icons.sports_esports_outlined,
              onTap: () => _showGamesPanel(),
            ),

            // 8. 3D Gift Box
            Semantics(
              button: true,
              label: 'gift-button',
              child: GestureDetector(
                onTap: _showGiftPanel,
                behavior: HitTestBehavior.opaque,
                child: const _GiftBox3DIcon(),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBottomIcon({
    required IconData icon,
    required VoidCallback onTap,
    double size = 24,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }

  Widget _buildInboxBottomIcon({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 24),
            Positioned(
              top: -3,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: const Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicCircleButton({
    required bool isOnSeat,
    required bool isMicMuted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: isMicMuted ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            !isOnSeat
                ? Icons.mic_none_rounded
                : (isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
            color: isMicMuted ? const Color(0xFFEF4444) : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildPillIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(button: true, label: 'room-action', child: Icon(icon, color: color, size: 21)),
    );
  }

  Widget _buildHostSeat(Participant host, RoomModel room, List<Participant> allParticipants) {
    final myUid = ref.watch(authStateProvider).value?.uid;

    // Global Owner Seat: Find active owner participant or fallback to ownerUid participant
    final Participant activeHost = allParticipants.firstWhere(
      (p) => p.uid == room.ownerUid,
      orElse: () => allParticipants.firstWhere(
        (p) => p.seatIndex == 0,
        orElse: () => host,
      ),
    );

    // Check if Room Owner is actively present in room participants
    final bool isOwnerOnline = allParticipants.any((p) => p.uid == room.ownerUid);

    final userAsync = ref.watch(cachedUserProfileProvider(room.ownerUid));

    // Layer 1 seat anchor: gift overlay resolves host seat via SeatAnchors.
    // In non-YouTube mode, seat_grid steps aside for the owner uid so the host
    // widget registers this key safely without duplicate GlobalKey collisions.
    final hostAnchor = room.ownerUid.isNotEmpty
        ? SeatAnchors.keyFor(room.roomId, room.ownerUid)
        : null;

    final hostSeat = GestureDetector(
      onTap: () {
        if (activeHost.uid.isNotEmpty) {
          _showUserOptions(activeHost);
        } else {
          _onSeatTap(0, allParticipants, room);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          userAsync.when(
            data: (user) {
              final u = user as UserModel?;
              final displayName = u?.displayName.isNotEmpty == true ? u!.displayName : "Owner";
              final photoUrl = u?.profilePhotoUrl ?? "";
              final displayFrame = u?.profileFrame ?? "";
              final vipTier = u?.vipTier ?? "none";
              final level = u?.level ?? 1;
              final tags = u?.tags ?? [];
              const double frameMult = 2.3;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Dim avatar & ripple when Owner is Offline in the room
                      Opacity(
                        opacity: isOwnerOnline ? 1.0 : 0.45,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (u != null && isOwnerOnline) Positioned.fill(child: HostRippleWidget(user: u)),
                            SizedBox(
                              width: 56, // radius 28 * 2
                              height: 56,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  AppAvatar(
                                    imageUrl: photoUrl,
                                    frameUrl: displayFrame,
                                    vipTier: vipTier,
                                    userLevel: level,
                                    tags: tags,
                                    radius: 28,
                                    showFrame: true,
                                    frameMultiplier: frameMult,
                                  ),
                                  if (activeHost.uid.isNotEmpty) SeatEmojiReactionWidget(uid: activeHost.uid),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (activeHost.isMuted)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 11),
                          ),
                        ),
                    ],
                  ),
                  // Host label below avatar
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOwnerOnline
                            ? [const Color(0xFF059669), const Color(0xFF10B981)]
                            : [const Color(0xFF334155), const Color(0xFF475569)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOwnerOnline
                            ? const Color(0xFF34D399).withValues(alpha: 0.5)
                            : Colors.white10,
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isOwnerOnline
                              ? const Color(0xFF059669).withValues(alpha: 0.35)
                              : Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOwnerOnline) ...[
                          const Icon(Icons.workspace_premium_rounded, size: 9, color: Color(0xFFFFD700)),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          isOwnerOnline ? "Host" : "Offline",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Owner name below Host label
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: isOwnerOnline ? Colors.white : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Diamond counter
                  Container(
                    margin: const EdgeInsets.only(top: 3),
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
                          activeHost.diamondsReceived >= 1000
                              ? '${(activeHost.diamondsReceived / 1000).toStringAsFixed(1)}k'
                              : '${activeHost.diamondsReceived}',
                          style: const TextStyle(color: Colors.yellowAccent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              width: 56, height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700))),
            ),
            error: (_, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: const Icon(Icons.person, color: Colors.amber, size: 28),
                ),
                const SizedBox(height: 4),
                const Text("Owner", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );

    return hostAnchor == null
        ? hostSeat
        : KeyedSubtree(key: hostAnchor, child: hostSeat);
  }




  void _showPKPanel() {
    final room = ref.read(currentRoomStreamProvider(widget.roomId)).value;
    final myUid = ref.read(authStateProvider).value?.uid;

    if (room == null || myUid == null) return;

    // Only allow room owner to start PK
    if (room.ownerUid != myUid) {
      ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
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

  void _openRoomGiftLeaderboard([RoomModel? room]) {
    context.push(
      AppRoutes.roomGiftLeaderboard,
      extra: {
        'roomId': widget.roomId,
        'roomName': room?.name ?? 'Room Gifts',
      },
    );
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
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Room locked with default pass!")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_off, color: Colors.white),
              title: const Text("Mute All Seat", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(roomServiceProvider).muteAllSeats(widget.roomId);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("All speakers muted.")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: Colors.blueAccent),
              title: const Text("Manage Room Capacity", style: TextStyle(color: Colors.white)),
              subtitle: Text("Expand to ${kRoomCapacityOptions.join(', ')} seats", style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
                 ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Blacklist UI coming soon.")));
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
              children: kRoomCapacityOptions.map((cap) => GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(roomServiceProvider).setRoomCapacity(widget.roomId, cap);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Room expanded to $cap seats!")),
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

  void _showGamesPanel({int initialCategory = 0}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UnifiedGamesHubSheet(
        roomId: widget.roomId,
        initialCategory: initialCategory,
      ),
    );
  }

  void _showGiftPanel() {
    final qs = _quickSendNotifier.value;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      sheetAnimationStyle: AnimationStyle(
        duration: Duration.zero,
        reverseDuration: Duration.zero,
      ),
      builder: (context) => GiftPanel(
        roomId: widget.roomId,
        targetUid: qs != null && qs.targetUid.isNotEmpty ? qs.targetUid : null,
        initialGift: qs?.gift,
        onQuickSendActivated: _onQuickSendActivated,
      ),
    );
  }

  void _onQuickSendActivated(
    GiftModel gift,
    String targetUid,
    String targetName,
    String targetPhotoUrl, {
    int startCount = 1,
  }) {
    debugPrint('QC activated: gift=${gift.name} target=$targetUid name=$targetName start=$startCount');
    _quickSendNotifier.value = _QuickSendState(
      gift: gift,
      targetUid: targetUid,
      targetName: targetName,
      targetPhoto: targetPhotoUrl,
      startCount: startCount,
    );
  }

  void _dismissQuickSend() {
    _quickSendNotifier.value = null;
  }

  void _onSeatTap(int index, List<Participant> participants, RoomModel room) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    if (index == 0 && room.ownerUid != uid) {
      ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, 
          content: Text("Only the room owner can take the host seat"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final participantOnSeat = participants.firstWhere(
      (p) => p.seatIndex == index,
      orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), role: 'none', isMuted: false),
    );

    final myParticipation = participants.firstWhere(
      (p) => p.uid == uid,
      orElse: () => Participant(uid: '', joinedAt: DateTime.now(), lastActive: DateTime.now(), role: 'none', isMuted: false),
    );

    if (participantOnSeat.uid.isEmpty) {
      if (room.lockedSeats.contains(index)) {
        AppToast.showOverlay(
          context,
          message: "This seat is locked by host",
          type: ToastType.error,
        );
        return;
      }

      final bool wasAlreadyBroadcaster = myParticipation.seatIndex != null && myParticipation.seatIndex! >= 0;

      // ⚡ INSTANT OPTIMISTIC UI: Move avatar to seat immediately in 0ms!
      setState(() {
        _optimisticSeatIndex = index;
      });

      try {
        final takeSeatFuture = ref.read(roomServiceProvider).takeSeat(widget.roomId, index, ownerUid: room.ownerUid);
        if (!wasAlreadyBroadcaster) {
          final voiceFuture = ref.read(voiceServiceProvider).setBroadcasterRole();
          await Future.wait([takeSeatFuture, voiceFuture]);
        } else {
          // Already broadcasting! Skip Agora role switch to eliminate audio delays
          await takeSeatFuture;
        }
        if (mounted) {
          setState(() {
            _optimisticSeatIndex = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _optimisticSeatIndex = null;
          });
          AppToast.showOverlay(
            context,
            message: e.toString().replaceAll('Exception: ', '').replaceAll('Exception:', '').trim(),
            type: ToastType.error,
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
                setState(() {
                  _optimisticSeatIndex = -1;
                });
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
                  ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Thanks for reporting. We will review this room shortly.")));
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
        debugPrint('🚪 [ROOM_EXIT] Reason: _buildRoomEndedSummary leaving voice and popping roomId=${widget.roomId}\nStack:\n${StackTrace.current}');
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

  void _showRocketLaunchAnimation(int level) {
    if (_isRocketNotificationShowing || _isRocketFlying || _isRocketLaunching) return;
    _notificationCountdownNotifier.value = 10;
    setState(() {
      _isRocketNotificationShowing = true;
      _launchingLevel = level;
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
      if (_notificationCountdownNotifier.value > 1) {
        _notificationCountdownNotifier.value--;
      } else {
        timer.cancel();
        _dismissRocketNotification();
      }
    });
  }

  void _dismissRocketNotification() {
    ref.read(isRocketActiveProvider(widget.roomId).notifier).state = true;
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
        child: ValueListenableBuilder<int>(
          valueListenable: _notificationCountdownNotifier,
          builder: (context, countdown, _) {
            return Container(
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
                            '$countdown',
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
                      value: countdown / 10,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRocketFlyingOverlay() {
    if (!_isRocketFlying) return const SizedBox.shrink();
    return Positioned.fill(
      child: RepaintBoundary(
        child: RocketLaunchOverlay(
          level: _launchingLevel,
          roomId: widget.roomId,
          onComplete: () {
            _triggerRocketHeartbeat();
            setState(() {
              _isRocketFlying = false;
              _isRocketLaunching = true;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRocketOverlay() {
    if (!_isRocketLaunching) return const SizedBox.shrink();
    return Positioned.fill(
      child: RepaintBoundary(
        child: RocketCompletionVapOverlay(
          level: _launchingLevel, 
          roomId: widget.roomId,
          onComplete: () {
            _triggerRocketHeartbeat();
            ref.read(isRocketActiveProvider(widget.roomId).notifier).state = false;
            _landingCountdownNotifier.value = 6;
            setState(() {
              _isRocketLaunching = false;
              _isRocketLanding = true;
            });
            _startLandingTimer();
          },
        ),
      ),
    );
  }

  void _startLandingTimer() {
    _landingTimer?.cancel();
    _landingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_landingCountdownNotifier.value > 1) {
        _landingCountdownNotifier.value--;
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
                "EXPLODING IN ${_landingCountdownNotifier.value}s",
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
                _bannerCurrentPageNotifier.value = index;
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
          ValueListenableBuilder<int>(
            valueListenable: _bannerCurrentPageNotifier,
            builder: (context, currentPage, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (i) {
                  final isActive = i == currentPage;
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
              );
            },
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
          return false;
        });
      }
    }
  }

  Widget _buildExplosionOverlay(RoomModel room) {
    if (!_showExplosionOverlay) return const SizedBox.shrink();

    // Auto-dismiss safety timer so explosion overlay never blocks queue if user doesn't tap Close
    _explosionAutoDismissTimer ??= Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      _explosionAutoDismissTimer = null;
      if (_showExplosionOverlay) {
        setState(() {
          _showExplosionOverlay = false;
        });
        ref.invalidate(walletBalanceProvider);
        ref.invalidate(currentUserProfileProvider);
        Future.delayed(const Duration(milliseconds: 400), () {
          _processNextRocketQueueItem();
        });
      }
    });

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    int? myRank;
    int myCoins = 0;
    int myXp = 0;
    String myFrameDuration = '24h';

    if (myUid != null) {
      final sortedUids = _launchContributions.keys.toList()
        ..sort((a, b) => _launchContributions[b]!.compareTo(_launchContributions[a]!));
      
      final rankIndex = sortedUids.indexOf(myUid);
      if (rankIndex >= 0 && rankIndex < 3) {
        myRank = rankIndex + 1;
        
        final level = (_launchingLevel - 1).clamp(0, 4);
        const frameDurations = ['24h', '24h', '24h', '24h', '72h'];
        myFrameDuration = frameDurations[level];
        
        int king = 30000, t2 = 15000, t3 = 7500, xp = 2000;
        switch (level) {
          case 0: king = 30000; t2 = 15000; t3 = 8000; xp = 2000; break;
          case 1: king = 60000; t2 = 40000; t3 = 30000; xp = 3000; break;
          case 2: king = 200000; t2 = 150000; t3 = 100000; xp = 5000; break;
          case 3: king = 500000; t2 = 300000; t3 = 250000; xp = 10000; break;
          case 4: king = 800000; t2 = 500000; t3 = 350000; xp = 15000; break;
        }
        
        if (myRank == 1) { myCoins = king; myXp = xp; }
        else if (myRank == 2) { myCoins = t2; myXp = xp ~/ 2; }
        else if (myRank == 3) { myCoins = t3; myXp = xp ~/ 3; }
      }
    }

    final explosion = RocketRewardExplosionOverlay(
      level: (_launchingLevel - 1).clamp(0, 4),
      contributions: _launchContributions,
      onClose: () {
        _explosionAutoDismissTimer?.cancel();
        _explosionAutoDismissTimer = null;
        setState(() {
          _showExplosionOverlay = false;
        });
        ref.invalidate(walletBalanceProvider);
        ref.invalidate(currentUserProfileProvider);
        Future.delayed(const Duration(milliseconds: 500), () {
          _processNextRocketQueueItem();
        });
      },
    );

    if (myRank != null) {
      return Stack(
        children: [
          explosion,
          RocketWinnerPopupOverlay(
            level: (_launchingLevel - 1).clamp(0, 4),
            rank: myRank,
            coins: myCoins,
            xp: myXp,
            frameDuration: myFrameDuration,
            onClose: () {
              _explosionAutoDismissTimer?.cancel();
              _explosionAutoDismissTimer = null;
              setState(() {
                _showExplosionOverlay = false;
              });
              ref.invalidate(walletBalanceProvider);
              ref.invalidate(currentUserProfileProvider);
              Future.delayed(const Duration(milliseconds: 500), () {
                _processNextRocketQueueItem();
              });
            },
          ),
        ],
      );
    }

    return explosion;
  }

  String _formatDiamondCount(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class HostRippleWidget extends ConsumerStatefulWidget {
  final UserModel user;

  const HostRippleWidget({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<HostRippleWidget> createState() => _HostRippleWidgetState();
}

class _HostRippleWidgetState extends ConsumerState<HostRippleWidget> with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int agoraUid = widget.user.uid.hashCode & 0xFFFFFFFF;
    final bool isSpeaking = ref.watch(
      speakingUidsProvider.select((s) => (s.value ?? []).contains(agoraUid)),
    );

    if (!isSpeaking) {
      if (_rippleController.isAnimating) {
        _rippleController.stop();
        _rippleController.reset();
      }
      return const SizedBox.shrink();
    }

    if (!_rippleController.isAnimating) {
      _rippleController.repeat();
    }

    final hasFrame = widget.user.profileFrame.isNotEmpty && widget.user.profileFrame.toLowerCase() != 'none';

    // Check equipped mic wave
    final micWave = widget.user.equippedMicWave;
    final isExplicitNone = micWave.toLowerCase() == 'none';
    String? waveAsset;
    if (!isExplicitNone && micWave.isNotEmpty) {
      waveAsset = micWave;
    } else if (!isExplicitNone) {
      final svip = widget.user.svipLevel ?? 0;
      if (svip > 0) {
        waveAsset = SVIPLevelModel.getLevelByTier(svip).micWaveAsset;
      } else if (widget.user.isVipActive) {
        waveAsset = getVipMicWavesPath(widget.user.vipTier);
      }
    }

    if (waveAsset != null && waveAsset.isNotEmpty) {
      final double waveSize = hasFrame ? 28 * 5.2 : 28 * 3.2;
      return RepaintBoundary(
        child: SizedBox(
          width: waveSize,
          height: waveSize,
          child: IgnorePointer(
            child: SvgaPlayer(
              key: ValueKey('host_wave_${widget.user.uid}_$waveAsset'),
              assetPath: waveAsset,
              fit: BoxFit.contain,
              loop: true,
            ),
          ),
        ),
      );
    }

    final frameMult = hasFrame ? 2.3 : 1.0;
    final double baseRippleSize = 28 * 2 * frameMult;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _rippleController,
        builder: (context, child) {
          final scale = 1.0 + _rippleController.value * 0.3;
          final opacity = (1.0 - _rippleController.value).clamp(0.0, 1.0);
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity * 0.4,
              child: Container(
                width: baseRippleSize + 10,
                height: baseRippleSize + 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GiftBox3DIcon extends StatelessWidget {
  const _GiftBox3DIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB703), Color(0xFFFB8500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFB8500).withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Vertical Ribbon
          Container(
            width: 5,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF007F),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // Horizontal Ribbon
          Container(
            width: 32,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFFF007F),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          // 3D Pink Ribbon Bow on Top
          Positioned(
            top: -4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -0.3,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2A85),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white38, width: 0.5),
                    ),
                  ),
                ),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF007F),
                    shape: BoxShape.circle,
                  ),
                ),
                Transform.rotate(
                  angle: 0.3,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2A85),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white38, width: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
