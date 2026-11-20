import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/constants/new_assets_constants.dart';
import 'package:hello_chat/core/widgets/svga_player.dart';

import 'lucky_bag_claim_dialog.dart';

/// Newest active Lucky Bag in a room. Null when no bag is claimable.
final activeRoomLuckyBagProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('lucky_bags')
      .where('roomId', isEqualTo: roomId)
      .where('status', isEqualTo: 'active')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots()
      .map((snapshot) {
    final now = DateTime.now();
    final docs = snapshot.docs.where((doc) {
      final data = doc.data();
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      return expiresAt == null || expiresAt.isAfter(now);
    }).toList();
    if (docs.isEmpty) return null;
    final bag = Map<String, dynamic>.from(docs.first.data());
    bag['bagId'] = docs.first.id;
    return bag;
  });
});

class FloatingLuckyBagWidget extends ConsumerWidget {
  final String roomId;

  const FloatingLuckyBagWidget({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(activeRoomLuckyBagProvider(roomId)).valueOrNull;
    if (bag == null) return const SizedBox.shrink();

    final bagId = bag['bagId'] as String? ?? '';
    if (bagId.isEmpty) return const SizedBox.shrink();
    final opensAt = (bag['opensAt'] as Timestamp?)?.toDate();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.65),
          builder: (_) => LuckyBagClaimDialog(bagId: bagId, initialData: bag),
        );
      },
      child: SizedBox(
        width: 68,
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 1. Native Unclipped SVGA Lucky Bag Item (Transparent background, no ClipOval deformation)
            const Positioned(
              top: 0,
              left: 2,
              right: 2,
              bottom: 8,
              child: SvgaPlayer(
                assetPath: NewAssets.luckyBagCountdown,
                fit: BoxFit.contain,
              ),
            ),

            // 2. Countdown Badge positioned neatly at the bottom
            Positioned(
              bottom: 0,
              child: _CountdownBadge(opensAt: opensAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownBadge extends StatefulWidget {
  final DateTime? opensAt;

  const _CountdownBadge({this.opensAt});

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  Timer? _timer;
  String _label = 'LIVE';

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final deadline = widget.opensAt;
    if (deadline == null) {
      if (_label != 'LIVE' && mounted) setState(() => _label = 'LIVE');
      return;
    }
    final remaining = deadline.difference(DateTime.now());
    final seconds = math.max(0, remaining.inSeconds);
    final next = seconds <= 0
        ? 'LIVE'
        : (seconds < 60
            ? '${seconds}s'
            : '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}');
    if (next != _label && mounted) setState(() => _label = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
