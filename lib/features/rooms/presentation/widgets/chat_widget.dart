import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/models/message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/broadcast_service.dart';
import '../../../../utils/level_utils.dart';
import '../../../../core/widgets/user_badge.dart';
import '../../../../core/utils/badge_utils.dart';
import 'package:gap/gap.dart';
import '../../../../core/widgets/app_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../services/gift_service.dart';
import 'gift_combo_overlay.dart';

class ChatWidget extends ConsumerStatefulWidget {
  final List<RoomMessage> messages;
  final String? roomId;
  final List<BroadcastModel>? broadcasts;
  final Function(String uid)? onUserTap;

  const ChatWidget({super.key, required this.messages, this.roomId, this.broadcasts, this.onUserTap});

  @override
  ConsumerState<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends ConsumerState<ChatWidget> {
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<RoomMessage> _visibleMessages = [];
  final List<RoomMessage> _incomingQueue = [];
  List<RoomMessage> _prevMessages = [];
  Timer? _queueTimer;

  /// Newest arrival per combo stream, used to tell a continuing combo apart
  /// from a brand new one to the same receiver with the same gift.
  final Map<String, DateTime> _lastGiftAt = {};

  void _startTimerIfNeeded() {
    if (_queueTimer != null && _queueTimer!.isActive) return;
    _queueTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _processNextQueueItem();
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(ChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages != widget.messages) {
      final currentUid = ref.read(authStateProvider).value?.uid;
      final myProfile = ref.read(cachedUserProfileProvider(currentUid ?? '')).value;
      final blocked = (myProfile is UserModel) ? myProfile.blockedUids : <String>[];
      _reconcileMessages(widget.messages, blocked);
    }
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }

  void _reconcileMessages(List<RoomMessage> currentMessages, List<String> blocked) {
    if (currentMessages.isEmpty) {
      if (_visibleMessages.isNotEmpty || _incomingQueue.isNotEmpty || _prevMessages.isNotEmpty) {
        setState(() {
          _visibleMessages.clear();
          _incomingQueue.clear();
          _prevMessages.clear();
          _lastGiftAt.clear();
          _listKey = GlobalKey<AnimatedListState>();
        });
      }
      return;
    }

    final isFirstRun = _prevMessages.isEmpty;

    if (isFirstRun) {
      // Seed queue with the 3 most recent allowed messages.
      //
      // Walking oldest-first and folding as we go does two things: it stops a
      // room opened mid-combo from stacking a row per tap, and it primes
      // `_lastGiftAt` so the fold rule below has a baseline from the very first
      // new message instead of starting empty.
      for (final m in currentMessages.reversed) {
        if (blocked.contains(m.uid)) continue;
        // Added straight to the queue so the fold rule can see the row that the
        // previous message of the same stream just established.
        if (_foldsIntoLiveComboRow(m)) continue;
        _incomingQueue.add(m);
      }
      if (_incomingQueue.length > 3) {
        _incomingQueue.removeRange(0, _incomingQueue.length - 3);
      }
      _prevMessages = List.from(currentMessages);
      return;
    }

    // Identify and filter new messages.
    //
    // Gift messages are additionally folded into the row already on screen for
    // the same combo stream: `sendGiftWithCombo` writes one document per tap, so
    // without this a 52-tap combo would queue 52 rows behind the live one.
    final newMsgs = <RoomMessage>[];
    for (final m in currentMessages) {
      if (_prevMessages.any((pm) => pm.msgId == m.msgId)) continue;
      if (blocked.contains(m.uid)) continue;
      newMsgs.add(m);
    }

    // Chronological ordering (oldest new message to newest new message)
    final newMsgsSorted = newMsgs.reversed.toList();

    // Fold in arrival order, appending as we go - the same shape as the seed
    // path above. Two taps of one combo routinely land in a single snapshot, and
    // `_foldsIntoLiveComboRow` only looks at the visible list and the queue, so a
    // message has to be queued *before* the next one is judged or every message
    // in the batch becomes its own row.
    for (final m in newMsgsSorted) {
      if (_foldsIntoLiveComboRow(m)) continue;
      _incomingQueue.add(m);
    }

    _shedAndMergeQueue();

    _prevMessages = List.from(currentMessages);
    if (_incomingQueue.isNotEmpty) {
      _startTimerIfNeeded();
    }
  }

  /// True when this gift message belongs to a combo row that is already on
  /// screen (or about to be), so it must not become a row of its own.
  ///
  /// The row's "xN" is kept moving by [GiftComboController], which the tile
  /// watches - so folding here loses no information.
  bool _foldsIntoLiveComboRow(RoomMessage m) {
    final key = m.giftComboKey;
    if (key == null) return false;

    final rowIsLive = _visibleMessages.any((v) => v.giftComboKey == key) ||
        _incomingQueue.any((q) => q.giftComboKey == key);

    final prevAt = _lastGiftAt[key];
    // Chained against the previous arrival, not the row's first message, so a
    // combo the user keeps extending past the banner window still folds.
    final continues =
        rowIsLive && prevAt != null && m.createdAt.difference(prevAt) <= kComboBannerTimeout;

    if (prevAt == null || m.createdAt.isAfter(prevAt)) {
      if (_lastGiftAt.length > 300) _lastGiftAt.clear();
      _lastGiftAt[key] = m.createdAt;
    }
    return continues;
  }

  void _shedAndMergeQueue() {
    if (_incomingQueue.length <= 8) return;

    // 1. Group consecutive room-join system events to prevent scroll spam
    final joinMessages = _incomingQueue.where((m) => m.type == 'system' && m.uid != 'system').toList();
    if (joinMessages.length > 2) {
      _incomingQueue.removeWhere((m) => m.type == 'system' && m.uid != 'system');
      
      final mergedMsg = RoomMessage(
        msgId: 'merged_joins_${DateTime.now().millisecondsSinceEpoch}',
        uid: 'system',
        text: '${joinMessages.length} members entered the room',
        type: 'system',
        createdAt: DateTime.now(),
      );
      _incomingQueue.insert(0, mergedMsg);
    }

    // 2. High-traffic shedding: prioritize gifts, drop oldest low-priority texts
    if (_incomingQueue.length > 10) {
      final gifts = _incomingQueue.where((m) => m.type == 'gift').toList();
      final others = _incomingQueue.where((m) => m.type != 'gift').toList();
      
      _incomingQueue.clear();
      // Keep up to 4 of the latest regular messages, and all gifts
      _incomingQueue.addAll(others.skip((others.length - 4).clamp(0, others.length)));
      _incomingQueue.addAll(gifts);
      
      _incomingQueue.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  void _processNextQueueItem() {
    if (!mounted) return;
    if (_incomingQueue.isEmpty) {
      if (_visibleMessages.length <= 3) {
        _queueTimer?.cancel();
        _queueTimer = null;
      }
      return;
    }

    final nextMsg = _incomingQueue.removeAt(0);

    // Dedup guard
    if (_visibleMessages.any((m) => m.msgId == nextMsg.msgId)) return;

    setState(() {
      // Index 0 represents the bottom of the list view in reverse mode.
      _visibleMessages.insert(0, nextMsg);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 320));

      // Strictly limit to 4 visible messages
      if (_visibleMessages.length > 4) {
        final oldestIndex = _visibleMessages.length - 1;
        final oldestMsg = _visibleMessages[oldestIndex];

        _listKey.currentState?.removeItem(
          oldestIndex,
          (context, animation) => _buildAnimatedTile(oldestMsg, animation, isRemoving: true),
          duration: const Duration(milliseconds: 280),
        );
        _visibleMessages.removeAt(oldestIndex);
      }
    });
  }

  Widget _buildAnimatedTile(RoomMessage msg, Animation<double> animation, {bool isRemoving = false}) {
    final curve = isRemoving ? Curves.easeInCubic : Curves.easeOutCubic;
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    return SizeTransition(
      sizeFactor: curvedAnimation,
      axisAlignment: isRemoving ? -1.0 : 1.0,
      child: FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: isRemoving ? Offset.zero : const Offset(-0.25, 0.0),
            end: isRemoving ? const Offset(0.0, -0.35) : Offset.zero,
          ).animate(curvedAnimation),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: isRemoving ? 1.0 : 0.92,
              end: isRemoving ? 0.88 : 1.0,
            ).animate(curvedAnimation),
            child: RoomMessageTile(msg: msg, roomId: widget.roomId, onUserTap: widget.onUserTap),
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(int index, Animation<double> animation) {
    if (index < 0 || index >= _visibleMessages.length) return const SizedBox.shrink();
    final msg = _visibleMessages[index];

    return _buildAnimatedTile(msg, animation, isRemoving: false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final myProfileAsync = ref.watch(cachedUserProfileProvider(currentUid ?? ''));

    final blocked = myProfileAsync.maybeWhen(
      data: (myProfile) => (myProfile != null && myProfile is UserModel)
          ? myProfile.blockedUids
          : <String>[],
      orElse: () => <String>[],
    );

    if (_prevMessages.isEmpty && widget.messages.isNotEmpty) {
      _reconcileMessages(widget.messages, blocked);
    }

    final broadcastWidgets = widget.broadcasts?.map((b) => Container(
      key: ValueKey('broadcast_${b.id}'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 4, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF673AB7).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Text(
        b.message,
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
      ),
    )).toList() ?? [];

    return AnimatedList(
      key: _listKey,
      reverse: true,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      initialItemCount: _visibleMessages.length + broadcastWidgets.length,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      itemBuilder: (context, index, animation) {
        final msgCount = _visibleMessages.length;
        if (index < msgCount) {
          return _buildListItem(index, animation);
        }
        final bIndex = index - msgCount;
        if (bIndex >= 0 && bIndex < broadcastWidgets.length) {
          return broadcastWidgets[bIndex];
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class RoomMessageTile extends ConsumerWidget {
  final RoomMessage msg;
  final String? roomId;
  final Function(String uid)? onUserTap;

  const RoomMessageTile({super.key, required this.msg, this.roomId, this.onUserTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      child: _buildTileContent(context, ref),
    );
  }

  Widget _buildTileContent(BuildContext context, WidgetRef ref) {
    if (msg.type == 'gift') {
      return GestureDetector(
        onTap: () {
          if (msg.uid.isNotEmpty) onUserTap?.call(msg.uid);
        },
        child: _buildRichGiftMessage(msg, ref),
      );
    }
    if (msg.type == 'system') {
      return GestureDetector(
        onTap: () {
          if (msg.uid != 'system' && msg.uid.isNotEmpty) onUserTap?.call(msg.uid);
        },
        child: _buildRichSystemMessage(ref, msg),
      );
    }
    if (msg.type == 'image') {
      return GestureDetector(
        onTap: () {
          if (msg.uid.isNotEmpty) onUserTap?.call(msg.uid);
        },
        child: _buildImageMessage(context, ref, msg),
      );
    }
    if (msg.type == 'sticker') {
      return GestureDetector(
        onTap: () {
          if (msg.uid.isNotEmpty) onUserTap?.call(msg.uid);
        },
        child: _buildStickerMessage(ref, msg),
      );
    }

    final userAsync = ref.watch(cachedUserProfileProvider(msg.uid));

    return GestureDetector(
      onTap: () {
        if (msg.uid.isNotEmpty) onUserTap?.call(msg.uid);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
      child: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          final u = user as UserModel;
          final allBadges = getBadgesForUser(u);

          final roomData = roomId != null ? ref.watch(currentRoomStreamProvider(roomId!)).value : null;
          final isRoomAdmin = roomData?.isUserAdmin(u.uid) ?? false;

          final filteredBadges = allBadges.where((b) {
            if (b is UserBadge) {
              return b.type == BadgeType.level || b.type == BadgeType.vip || b.type == BadgeType.noble || b.type == BadgeType.admin;
            }
            return false;
          }).toList();

          if (isRoomAdmin && !filteredBadges.any((b) => b is UserBadge && b.label == "Admin")) {
            filteredBadges.insert(0, const UserBadge(
              label: "Admin",
              type: BadgeType.role,
              icon: Icons.admin_panel_settings_rounded,
            ));
          }

          final String userBubble = u.chatBubble.trim();
          final bool isExplicitNoneBubble = userBubble.toLowerCase() == 'none';
          String? bubbleAsset;
          if (!isExplicitNoneBubble) {
            if (userBubble.isNotEmpty) {
              bubbleAsset = userBubble;
            } else {
              final level = _getVipLevel(u.vipTier);
              if (level >= 1 && level <= 8 && u.isVipActive) {
                bubbleAsset = level == 1 
                    ? 'assets/VIP/VIP 1/Chat Bubble.png' 
                    : 'assets/VIP/VIP $level/VIP $level/Chat Bubble.png';
              }
            }
          }

          DecorationImage? bubbleImage;
          if (bubbleAsset != null && bubbleAsset.isNotEmpty) {
            final ImageProvider imgProvider = bubbleAsset.startsWith('assets/')
                ? AssetImage(bubbleAsset)
                : CachedNetworkImageProvider(bubbleAsset) as ImageProvider;
            bubbleImage = DecorationImage(image: imgProvider, fit: BoxFit.fill);
          }

          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: bubbleImage != null 
                ? BoxDecoration(
                    image: bubbleImage,
                  )
                : BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(18),
                  ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AppAvatar(
                      imageUrl: u.profilePhotoUrl,
                      radius: 13,
                      vipTier: u.vipTier,
                      frameUrl: u.profileFrame,
                      userLevel: u.level,
                      tags: u.tags,
                      frameMultiplier: 2.0,
                    ),
                  ),
                  const Gap(7),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...filteredBadges.map((badge) {
                              if (badge is UserBadge) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: SizedBox(
                                    height: 18,
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: UserBadge(
                                        label: badge.label,
                                        type: badge.type,
                                        icon: badge.icon,
                                        customFrameAsset: badge.customFrameAsset,
                                        margin: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return badge;
                            }),
                            Builder(
                              builder: (context) {
                                final roomData = roomId != null ? ref.watch(currentRoomStreamProvider(roomId!)).value : null;
                                final isRoomOwner = roomData?.ownerUid == u.uid;
                                final isRoomAdmin = roomData?.isUserAdmin(u.uid) ?? false;

                                return Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isRoomOwner)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFD700),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              "Owner",
                                              style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        )
                                      else if (isRoomAdmin)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E5FF),
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: const [BoxShadow(color: Color(0x6600E5FF), blurRadius: 4)],
                                            ),
                                            child: const Text(
                                              "Admin",
                                              style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          u.displayName,
                                          style: const TextStyle(
                                            color: Color(0xFF80D8FF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          msg.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context, WidgetRef ref, RoomMessage msg) {
    final userAsync = ref.watch(cachedUserProfileProvider(msg.uid));

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          final u = user as UserModel;

          return Align(
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(
                  imageUrl: u.profilePhotoUrl,
                  radius: 13,
                  vipTier: u.vipTier,
                  frameUrl: u.profileFrame,
                  userLevel: u.level,
                  tags: u.tags,
                  frameMultiplier: 2.0,
                ),
                const Gap(8),
                GestureDetector(
                  onTap: () => _showFullImageDialog(context, msg.text),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 140,
                      maxHeight: 140,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: msg.text,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox(
                          width: 80, height: 80,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 40),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  void _showFullImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: Hero(
              tag: imageUrl,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(color: Color(0xFF00E5FF)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerMessage(WidgetRef ref, RoomMessage msg) {
    final userAsync = ref.watch(cachedUserProfileProvider(msg.uid));

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          final u = user as UserModel;

          return Align(
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(
                  imageUrl: u.profilePhotoUrl,
                  radius: 13,
                  vipTier: u.vipTier,
                  frameUrl: u.profileFrame,
                  userLevel: u.level,
                  tags: u.tags,
                  frameMultiplier: 2.0,
                ),
                const Gap(8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      msg.text,
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 40),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildRichGiftMessage(RoomMessage msg, WidgetRef ref) {
    String text = msg.text.trim();
    String name = text;
    String multiplier = "1";

    int lastXIndex = text.lastIndexOf(" x");
    if (lastXIndex != -1) {
      name = text.substring(0, lastXIndex).trim();
      final afterX = text.substring(lastXIndex + 2).trim();
      // Clean multiplier from combo or lucky annotations
      final spaceIdx = afterX.indexOf(" ");
      multiplier = spaceIdx != -1 ? afterX.substring(0, spaceIdx) : afterX;
    }

    // Ensure format matches "Sent to [Receiver]"
    if (!name.toLowerCase().startsWith("sent to") && !name.toLowerCase().startsWith("send to")) {
      String targetName = "";
      if (msg.targetUid.isNotEmpty) {
        final targetProfile = ref.watch(cachedUserProfileProvider(msg.targetUid)).value;
        if (targetProfile != null && targetProfile.displayName.trim().isNotEmpty) {
          targetName = targetProfile.displayName.trim();
        }
      }
      if (targetName.isNotEmpty) {
        name = "Sent to $targetName";
      } else if (name.isNotEmpty) {
        name = "Sent to $name";
      } else {
        name = "Sent gift";
      }
    }

    // The row holds the combo's FIRST message, whose text freezes at x1.
    // Live combo stream gives the animated live count.
    if (roomId != null) {
      final combos = ref.watch(giftComboControllerProvider(roomId!));
      final key = msg.giftComboKey;
      final count = combos[key]?.count ?? combos.settledCount(key);
      if (count != null) multiplier = '$count';
    }

    // Resolve authoritative gift icon image (cover icon, not SVGA/JSON animation file)
    String? resolvedGiftImageUrl = (msg.imageUrl != null && msg.imageUrl!.trim().isNotEmpty)
        ? msg.imageUrl!.trim()
        : null;

    if (resolvedGiftImageUrl == null && msg.giftId != null && msg.giftId!.trim().isNotEmpty) {
      final giftsList = ref.watch(giftsStreamProvider).value;
      if (giftsList != null) {
        for (final g in giftsList) {
          if (g.giftId == msg.giftId && g.imageUrl.trim().isNotEmpty) {
            resolvedGiftImageUrl = g.imageUrl.trim();
            break;
          }
        }
      }
    }

    // Fallback: check if animationUrl happens to be a static image (png, webp, jpg, gif)
    if (resolvedGiftImageUrl == null && msg.animationUrl != null && msg.animationUrl!.trim().isNotEmpty) {
      final lowerAnim = msg.animationUrl!.toLowerCase();
      if (lowerAnim.contains('.png') || lowerAnim.contains('.jpg') || lowerAnim.contains('.webp') || lowerAnim.contains('.gif')) {
        resolvedGiftImageUrl = msg.animationUrl!.trim();
      }
    }

    Widget giftIconWidget;
    if (resolvedGiftImageUrl != null && resolvedGiftImageUrl.isNotEmpty) {
      if (resolvedGiftImageUrl.startsWith('http://') || resolvedGiftImageUrl.startsWith('https://')) {
        giftIconWidget = CachedNetworkImage(
          imageUrl: resolvedGiftImageUrl,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(width: 24, height: 24),
          errorWidget: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.amber, size: 20),
        );
      } else if (resolvedGiftImageUrl.startsWith('assets/')) {
        giftIconWidget = Image.asset(
          resolvedGiftImageUrl,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.amber, size: 20),
        );
      } else {
        giftIconWidget = const Icon(Icons.card_giftcard, color: Colors.amber, size: 20);
      }
    } else {
      giftIconWidget = const Icon(Icons.card_giftcard, color: Colors.amber, size: 20);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B1FA2).withOpacity(0.55),
            const Color(0xFFAB47BC).withOpacity(0.30),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFE040FB), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          giftIconWidget,
          const SizedBox(width: 4),
          Text(
            "x$multiplier",
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichSystemMessage(WidgetRef ref, RoomMessage msg) {
    if (msg.uid == 'system' || msg.uid.isEmpty) {
      return _buildSimpleSystemMessage(msg.text);
    }

    final userAsync = ref.watch(cachedUserProfileProvider(msg.uid));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: userAsync.when(
        data: (user) {
          if (user == null) {
            return _buildSimpleSystemMessage(msg.text);
          }
          final u = user as UserModel;
          return _buildRichJoinMessage(u);
        },
        loading: () => _buildSimpleSystemMessage(msg.text),
        error: (_, __) => _buildSimpleSystemMessage(msg.text),
      ),
    );
  }

  Widget _buildSimpleSystemMessage(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFD54F),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRichJoinMessage(UserModel user) {
    final allBadges = getBadgesForUser(user);

    final filteredBadges = allBadges.where((b) {
      if (b is UserBadge) {
        return b.type == BadgeType.level ||
            b.type == BadgeType.vip ||
            b.type == BadgeType.noble ||
            b.type == BadgeType.family ||
            b.type == BadgeType.agency;
      }
      return false;
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAvatar(
            imageUrl: user.profilePhotoUrl,
            radius: 12,
            vipTier: user.vipTier,
            frameUrl: user.profileFrame,
            userLevel: user.level,
            tags: user.tags,
            frameMultiplier: 2.0,
          ),
          const Gap(8),
          Flexible(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...filteredBadges.map((badge) {
                  if (badge is UserBadge) {
                    return SizedBox(
                      height: 18,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: UserBadge(
                          label: badge.label,
                          type: badge.type,
                          icon: badge.icon,
                          customFrameAsset: badge.customFrameAsset,
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    );
                  }
                  return badge;
                }),
                Text(
                  user.displayName.isNotEmpty ? user.displayName : "User",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  "entered ✨",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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

int _getVipLevel(String vipTierName) {
  final clean = vipTierName.toLowerCase().replaceAll(' ', '');
  if (clean.startsWith('vip')) {
    final numStr = clean.substring(3);
    final val = int.tryParse(numStr);
    if (val != null) return val;
  }
  return 0;
}

