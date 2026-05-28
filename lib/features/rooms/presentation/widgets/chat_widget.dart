import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/models/message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/broadcast_service.dart';
import '../../../../utils/level_utils.dart';
import '../../../../core/widgets/user_badge.dart';
import '../../../../core/utils/badge_utils.dart';
import 'package:gap/gap.dart';
import '../../../../core/widgets/app_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatWidget extends ConsumerStatefulWidget {
  final List<RoomMessage> messages;
  final List<BroadcastModel>? broadcasts;
  final Function(String uid)? onUserTap;

  const ChatWidget({super.key, required this.messages, this.broadcasts, this.onUserTap});

  @override
  ConsumerState<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends ConsumerState<ChatWidget> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<RoomMessage> _visibleMessages = [];
  final List<RoomMessage> _incomingQueue = [];
  List<RoomMessage> _prevMessages = [];
  Timer? _queueTimer;

  @override
  void initState() {
    super.initState();
    // Periodic processing timer running at a fast, premium pace (300ms)
    _queueTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _processNextQueueItem();
    });
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }

  void _reconcileMessages(List<RoomMessage> currentMessages, List<String> blocked) {
    final isFirstRun = _prevMessages.isEmpty;

    if (isFirstRun) {
      // Seed queue with the 3 most recent allowed messages
      final initialMsgs = currentMessages
          .where((m) => !blocked.contains(m.uid))
          .take(3)
          .toList()
          .reversed
          .toList();

      _incomingQueue.addAll(initialMsgs);
      _prevMessages = List.from(currentMessages);
      return;
    }

    // Identify and filter new messages
    final newMsgs = currentMessages.where((m) {
      final isNew = !_prevMessages.any((pm) => pm.msgId == m.msgId);
      final isNotBlocked = !blocked.contains(m.uid);
      return isNew && isNotBlocked;
    }).toList();

    // Chronological ordering (oldest new message to newest new message)
    final newMsgsSorted = newMsgs.reversed.toList();

    _incomingQueue.addAll(newMsgsSorted);
    _shedAndMergeQueue();

    _prevMessages = List.from(currentMessages);
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
      _incomingQueue.addAll(others.skip(others.length - 4));
      _incomingQueue.addAll(gifts);
      
      _incomingQueue.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  void _processNextQueueItem() {
    if (!mounted || _incomingQueue.isEmpty) return;

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
            child: RoomMessageTile(msg: msg, onUserTap: widget.onUserTap),
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(int index, Animation<double> animation) {
    if (index >= _visibleMessages.length) return const SizedBox.shrink();
    final msg = _visibleMessages[index];

    return _buildAnimatedTile(msg, animation, isRemoving: false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final myProfileAsync = ref.watch(userProfileProvider(currentUid ?? ''));

    final blocked = myProfileAsync.maybeWhen(
      data: (myProfile) => (myProfile != null && myProfile is UserModel)
          ? myProfile.blockedUids
          : <String>[],
      orElse: () => <String>[],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reconcileMessages(widget.messages, blocked);
      }
    });

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
        return broadcastWidgets[index - msgCount];
      },
    );
  }
}

class RoomMessageTile extends ConsumerWidget {
  final RoomMessage msg;
  final Function(String uid)? onUserTap;

  const RoomMessageTile({super.key, required this.msg, this.onUserTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (msg.type == 'gift') {
      return GestureDetector(
        onTap: () {
          if (msg.uid.isNotEmpty) onUserTap?.call(msg.uid);
        },
        child: _buildRichGiftMessage(msg),
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
    if (msg.type == 'sticker') {
      return GestureDetector(
        onTap: () {
          if (msg.uid.isNotEmpty) onUserTap?.call(msg.uid);
        },
        child: _buildStickerMessage(ref, msg),
      );
    }

    final userAsync = ref.watch(userProfileProvider(msg.uid));

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

          final filteredBadges = allBadges.where((b) {
            if (b is UserBadge) {
              return b.type == BadgeType.level || b.type == BadgeType.vip || b.type == BadgeType.noble;
            }
            return false;
          }).toList();

          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
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

  Widget _buildStickerMessage(WidgetRef ref, RoomMessage msg) {
    final userAsync = ref.watch(userProfileProvider(msg.uid));

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

  Widget _buildRichGiftMessage(RoomMessage msg) {
    String text = msg.text;
    String name = text;
    String multiplier = "1";
    
    int lastXIndex = text.lastIndexOf(" x");
    if (lastXIndex != -1) {
      name = text.substring(0, lastXIndex);
      multiplier = text.substring(lastXIndex + 2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B1FA2).withOpacity(0.5),
            const Color(0xFFAB47BC).withOpacity(0.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFE040FB), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          if (msg.animationUrl != null && msg.animationUrl!.isNotEmpty)
            Image.network(
              msg.animationUrl!,
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.amber, size: 18),
            )
          else
            const Icon(Icons.card_giftcard, color: Colors.amber, size: 18),
          const SizedBox(width: 3),
          Text(
            "x$multiplier",
            style: const TextStyle(
              color: Colors.yellowAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
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

    final userAsync = ref.watch(userProfileProvider(msg.uid));

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
