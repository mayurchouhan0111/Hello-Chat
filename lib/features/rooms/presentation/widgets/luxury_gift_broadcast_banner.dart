import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/constants/new_assets_constants.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/svga_player.dart';

class LuxuryGiftBroadcastEvent {
  final String id;
  final String senderUid;
  final String targetUid;
  final String giftName;
  final String? giftImageUrl;
  final int count;

  const LuxuryGiftBroadcastEvent({
    required this.id,
    required this.senderUid,
    required this.targetUid,
    required this.giftName,
    this.giftImageUrl,
    required this.count,
  });
}

class LuxuryGiftBroadcastQueue extends ChangeNotifier {
  final List<LuxuryGiftBroadcastEvent> _queue = [];
  LuxuryGiftBroadcastEvent? _current;
  Timer? _timer;

  LuxuryGiftBroadcastEvent? get current => _current;

  void enqueue(LuxuryGiftBroadcastEvent event) {
    if (event.id.isEmpty) return;
    if (_current?.id == event.id) return;
    if (_queue.any((e) => e.id == event.id)) return;
    if (_queue.length >= 10) _queue.removeAt(0);
    _queue.add(event);
    if (_current == null) _advance();
  }

  void _advance() {
    _timer?.cancel();
    _current = _queue.isEmpty ? null : _queue.removeAt(0);
    notifyListeners();
    if (_current != null) {
      _timer = Timer(const Duration(seconds: 4), _advance);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final luxuryGiftBroadcastProvider =
    ChangeNotifierProvider.autoDispose.family<LuxuryGiftBroadcastQueue, String>((ref, roomId) {
  final queue = LuxuryGiftBroadcastQueue();
  ref.onDispose(queue.dispose);
  return queue;
});

class LuxuryGiftBroadcastBanner extends ConsumerWidget {
  final String roomId;

  const LuxuryGiftBroadcastBanner({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(luxuryGiftBroadcastProvider(roomId));
    final event = queue.current;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: event == null
          ? const SizedBox.shrink(key: ValueKey('luxury_broadcast_empty'))
          : _LuxuryGiftBannerCard(
              key: ValueKey(event.id),
              event: event,
            ),
    );
  }
}

class _LuxuryGiftBannerCard extends ConsumerWidget {
  final LuxuryGiftBroadcastEvent event;

  const _LuxuryGiftBannerCard({super.key, required this.event});

  String _nameOf(WidgetRef ref, String uid) {
    if (uid.isEmpty) return 'Room';
    final profile = ref.watch(userProfileProvider(uid)).valueOrNull;
    if (profile == null) return 'User';
    if (profile.displayName.trim().isNotEmpty) return profile.displayName.trim();
    if (profile.username.trim().isNotEmpty) return profile.username.trim();
    return 'User';
  }

  String _photoOf(WidgetRef ref, String uid) {
    if (uid.isEmpty) return '';
    return ref.watch(userProfileProvider(uid)).valueOrNull?.profilePhotoUrl ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderName = _nameOf(ref, event.senderUid);
    final receiverName = _nameOf(ref, event.targetUid);
    final senderPhoto = _photoOf(ref, event.senderUid);
    final receiverPhoto = _photoOf(ref, event.targetUid);

    // Native SVGA Canvas: 750 x 200
    return AspectRatio(
      aspectRatio: 750 / 200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final s = w / 750.0;

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // 1. Native Golden SVGA Marquee Animation
              const SvgaPlayer(
                assetPath: NewAssets.luxuryGiftBanner,
                fit: BoxFit.fill,
              ),

              // 2. Sender Avatar: native bbox (x=70.5, y=61.0, w=78.0, h=78.0)
              Positioned(
                left: 70.5 * s,
                top: 61.0 * s,
                width: 78.0 * s,
                height: 78.0 * s,
                child: _CircleAvatarSlot(photoUrl: senderPhoto, size: 78.0 * s),
              ),

              // 3. Sender Name: native bbox (x=159.0, y=66.5, w=240.0, h=30.0)
              Positioned(
                left: 159.0 * s,
                top: 66.5 * s,
                width: 240.0 * s,
                height: 30.0 * s,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.0 * s,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Receiver Avatar: native bbox (x=225.8, y=100.2, w=40.0, h=40.0)
              Positioned(
                left: 225.8 * s,
                top: 100.2 * s,
                width: 40.0 * s,
                height: 40.0 * s,
                child: _CircleAvatarSlot(photoUrl: receiverPhoto, size: 40.0 * s),
              ),

              // 5. Receiver Name: native bbox (x=269.0, y=106.5, w=135.0, h=30.0)
              Positioned(
                left: 269.0 * s,
                top: 105.0 * s,
                width: 135.0 * s,
                height: 30.0 * s,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    receiverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFFFD700),
                      fontSize: 11.0 * s,
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),

              // 6. Gift Icon: native bbox (x=413.9, y=56.0, w=90.0, h=90.0)
              Positioned(
                left: 413.9 * s,
                top: 56.0 * s,
                width: 90.0 * s,
                height: 90.0 * s,
                child: Center(
                  child: (event.giftImageUrl != null && event.giftImageUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: event.giftImageUrl!,
                          width: 80.0 * s,
                          height: 80.0 * s,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.card_giftcard_rounded,
                            color: const Color(0xFFFFD700),
                            size: 42.0 * s,
                          ),
                        )
                      : Icon(
                          Icons.card_giftcard_rounded,
                          color: const Color(0xFFFFD700),
                          size: 42.0 * s,
                        ),
                ),
              ),

              // 7. Multiplier Count: native bbox (x=506.5, y=75.0, w=100.0, h=50.0)
              Positioned(
                left: 506.5 * s,
                top: 75.0 * s,
                width: 100.0 * s,
                height: 50.0 * s,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'x${event.count}',
                    maxLines: 1,
                    style: TextStyle(
                      color: const Color(0xFFFFE082),
                      fontSize: 24.0 * s,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                      shadows: const [
                        Shadow(color: Color(0xFFE65100), blurRadius: 4, offset: Offset(0, 1.5)),
                        Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CircleAvatarSlot extends StatelessWidget {
  final String photoUrl;
  final double size;

  const _CircleAvatarSlot({required this.photoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: photoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: photoUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Icon(Icons.person, color: Colors.white70, size: size * 0.6),
            )
          : Icon(Icons.person, color: Colors.white70, size: size * 0.6),
    );
  }
}
