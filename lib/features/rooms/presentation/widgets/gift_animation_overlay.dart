import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';

class GiftAnimationOverlay extends ConsumerStatefulWidget {
  final String roomId;
  final Widget child;

  const GiftAnimationOverlay({
    super.key,
    required this.roomId,
    required this.child,
  });

  @override
  ConsumerState<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends ConsumerState<GiftAnimationOverlay> {
  final Set<String> _processedMessageIds = {};
  final List<_ActiveGiftAnimation> _activeAnimations = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _setupListener();
  }

  void _setupListener() {
    // We use ref.listenManual or subscribe to the stream directly in a post-frame callback
    // to ensure the provider is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscription = ref.read(roomMessagesProvider(widget.roomId).stream).listen((messages) {
        if (!mounted) return;
        _handleMessages(messages);
      });
    });
  }

  void _handleMessages(List<RoomMessage> messages) {
    final now = DateTime.now();
    final threshold = now.subtract(const Duration(seconds: 15));

    bool changed = false;
    for (final msg in messages) {
      if (msg.type == 'gift' && 
          msg.animationUrl != null && 
          !_processedMessageIds.contains(msg.msgId) &&
          msg.createdAt.isAfter(threshold)) {
        
        _activeAnimations.add(_ActiveGiftAnimation(
          id: msg.msgId,
          url: msg.animationUrl!,
          senderUid: msg.uid,
          text: msg.text,
        ));
        changed = true;
        
        // Remove after 6 seconds
        Timer(const Duration(seconds: 6), () {
          if (mounted) {
            setState(() {
              _activeAnimations.removeWhere((a) => a.id == msg.msgId);
            });
          }
        });
      }
      _processedMessageIds.add(msg.msgId);
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeAnimations.map((anim) => _buildAnimationItem(anim)),
      ],
    );
  }

  Widget _buildAnimationItem(_ActiveGiftAnimation anim) {
    return Positioned.fill(
      key: ValueKey(anim.id),
      child: IgnorePointer(
        child: Stack(
          children: [
            // Full screen Lottie
            Center(
              child: Lottie.network(
                anim.url.trim(),
                repeat: false,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint("Lottie error: $error");
                  return const SizedBox(); // Fallback to nothing if animation fails
                },
              ),
            ),
            
            // Top Banner for the gift
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: _GiftNotificationBanner(uid: anim.senderUid, text: anim.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveGiftAnimation {
  final String id;
  final String url;
  final String senderUid;
  final String text;

  _ActiveGiftAnimation({
    required this.id, 
    required this.url,
    required this.senderUid,
    required this.text,
  });
}

class _GiftNotificationBanner extends ConsumerWidget {
  final String uid;
  final String text;

  const _GiftNotificationBanner({required this.uid, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(uid));

    return userAsync.when(
      data: (user) {
        final u = user as UserModel;
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(u.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${u.uid}/100" : u.profilePhotoUrl),
                ),
                const Gap(12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      u.displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      text,
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
