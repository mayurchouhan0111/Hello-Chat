import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/new_assets_constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_diamond.dart';
import '../widgets/svga_player.dart';
import 'package:hello_chat/core/utils/room_navigation_helper.dart';

final _dismissedGlobalNotificationIdProvider =
    StateProvider<String?>((ref) => null);

class GlobalNotificationOverlay extends ConsumerWidget {
  final Widget child;
  const GlobalNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final dismissedId = ref.watch(_dismissedGlobalNotificationIdProvider);

    return Stack(
      children: [
        child,
        if (user != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('global_notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final doc = snapshot.data!.docs.first;
                if (doc.id == dismissedId) {
                  return const SizedBox.shrink();
                }
                final data = doc.data() as Map<String, dynamic>;
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate() ??
                    createdAt?.add(const Duration(seconds: 5));
                if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
                  return const SizedBox.shrink();
                }

                return _GlobalLuckyBagBanner(
                  key: ValueKey(doc.id),
                  doc: doc,
                  data: data,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _GlobalLuckyBagBanner extends ConsumerStatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;

  const _GlobalLuckyBagBanner({
    super.key,
    required this.doc,
    required this.data,
  });

  @override
  ConsumerState<_GlobalLuckyBagBanner> createState() =>
      _GlobalLuckyBagBannerState();
}

class _GlobalLuckyBagBannerState extends ConsumerState<_GlobalLuckyBagBanner> {
  Timer? _expiryTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    final createdAt = (widget.data['createdAt'] as Timestamp?)?.toDate();
    final expiresAt = (widget.data['expiresAt'] as Timestamp?)?.toDate() ??
        createdAt?.add(const Duration(seconds: 5));
    final remaining =
        expiresAt?.difference(DateTime.now()) ?? const Duration(seconds: 5);
    if (remaining <= Duration.zero) {
      _visible = false;
    } else {
      _expiryTimer = Timer(remaining, () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (!_visible) return const SizedBox.shrink();
    final senderAvatar = data['senderAvatar'] as String? ?? '';
    final roomName = data['roomName'] as String? ?? '';
    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : 'Lucky Bag Dropped!';
    final totalDiamonds = data['totalDiamonds'] ?? data['diamonds'] ?? 0;
    final roomId = data['roomId'] as String? ?? '';

    // Native SVGA Canvas: 720 x 220
    return Dismissible(
      key: Key(widget.doc.id),
      direction: DismissDirection.up,
      onDismissed: (_) {
        ref.read(_dismissedGlobalNotificationIdProvider.notifier).state =
            widget.doc.id;
      },
      child: GestureDetector(
        onTap: () {
          ref.read(_dismissedGlobalNotificationIdProvider.notifier).state =
              widget.doc.id;
          if (roomId.isNotEmpty) {
            RoomNavigationHelper.joinRoom(context, ref, roomId);
          }
        },
        child: AspectRatio(
          aspectRatio: 720 / 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final s = w / 720.0;

              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // 1. Native Golden Red Envelope SVGA Banner
                  const SvgaPlayer(
                    assetPath: NewAssets.luckyBagBanner,
                    fit: BoxFit.fill,
                  ),

                  // 2. Sender Avatar: native bbox (x=157.0, y=99.0, w=64.0, h=64.0)
                  Positioned(
                    left: 157.0 * s,
                    top: 99.0 * s,
                    width: 64.0 * s,
                    height: 64.0 * s,
                    child: ClipOval(
                      child: senderAvatar.isNotEmpty
                          ? Image.network(
                              senderAvatar,
                              width: 64.0 * s,
                              height: 64.0 * s,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.person,
                                  color: Colors.white70, size: 32.0 * s),
                            )
                          : Icon(Icons.person,
                              color: Colors.white70, size: 32.0 * s),
                    ),
                  ),

                  // 3. Info Text Area: native bbox (x=230.0, y=92.0, w=345.0, h=75.0)
                  Positioned(
                    left: 230.0 * s,
                    top: 92.0 * s,
                    width: 345.0 * s,
                    height: 75.0 * s,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5 * s,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4)
                            ],
                          ),
                        ),
                        SizedBox(height: 3.0 * s),
                        Row(
                          children: [
                            PremiumDiamond(size: 13.0 * s),
                            SizedBox(width: 4.0 * s),
                            Text(
                              '$totalDiamonds',
                              style: TextStyle(
                                color: const Color(0xFFFFD700),
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5 * s,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 4)
                                ],
                              ),
                            ),
                            if (roomName.isNotEmpty) ...[
                              SizedBox(width: 6.0 * s),
                              Expanded(
                                child: Text(
                                  '•  $roomName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5 * s,
                                    fontWeight: FontWeight.w600,
                                    shadows: const [
                                      Shadow(
                                          color: Colors.black87, blurRadius: 3)
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 4. "GRAB NOW" Action Tag (native button area: x=585, y=98, w=90, h=65)
                  Positioned(
                    left: 585.0 * s,
                    top: 106.0 * s,
                    width: 90.0 * s,
                    height: 50.0 * s,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.0 * s, vertical: 4.0 * s),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(12.0 * s),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 1.5)),
                          ],
                        ),
                        child: Text(
                          'GRAB',
                          style: TextStyle(
                            color: const Color(0xFFB71C1C),
                            fontSize: 10.5 * s,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
