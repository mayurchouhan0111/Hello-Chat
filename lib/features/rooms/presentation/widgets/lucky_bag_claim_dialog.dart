import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/constants/new_assets_constants.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:hello_chat/core/widgets/svga_player.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'package:hello_chat/services/gift_service.dart';

class LuckyBagClaimDialog extends ConsumerStatefulWidget {
  final String bagId;
  final Map<String, dynamic>? initialData;

  const LuckyBagClaimDialog({
    super.key,
    required this.bagId,
    this.initialData,
  });

  @override
  ConsumerState<LuckyBagClaimDialog> createState() => _LuckyBagClaimDialogState();
}

class _LuckyBagClaimDialogState extends ConsumerState<LuckyBagClaimDialog> {
  Timer? _clock;
  bool _claiming = false;
  bool _claimed = false;
  int _reward = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_claiming || _claimed) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _claiming = true;
      _error = null;
    });

    try {
      final result = await ref.read(giftServiceProvider).claimLuckyBag(bagId: widget.bagId);
      final reward = (result['rewardDiamonds'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(walletBalanceProvider);
      setState(() {
        _claiming = false;
        _claimed = true;
        _reward = reward;
      });
      AppToast.showDiamond(context, '+$reward diamonds added to your balance');
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      String message = 'Could not open the Lucky Bag. Please try again.';
      if (raw.contains('already-exists')) {
        message = 'You already claimed a share of this Lucky Bag.';
      } else if (raw.contains('failed-precondition')) {
        message = 'This Lucky Bag is already fully claimed.';
      } else if (raw.contains('not-found')) {
        message = 'This Lucky Bag has expired.';
      } else if (raw.contains('unauthenticated')) {
        message = 'Please sign in again to claim.';
      }
      setState(() {
        _claiming = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('lucky_bags').doc(widget.bagId).snapshots(),
      builder: (context, snapshot) {
        final live = snapshot.data?.data();
        final data = live ?? widget.initialData ?? const <String, dynamic>{};
        final total = (data['totalDiamonds'] as num?)?.toInt() ?? 0;
        final remaining = (data['remainingWinners'] as num?)?.toInt() ?? 0;
        final winners = (data['winnerCount'] as num?)?.toInt() ?? 0;
        final sender = (data['senderName'] as String?)?.trim();
        final status = (data['status'] as String?) ?? 'active';
        final opensAt = (data['opensAt'] as Timestamp?)?.toDate();
        final openingSeconds = opensAt == null
            ? 0
            : opensAt.difference(DateTime.now()).inSeconds.clamp(0, 3600);
        final isPending = openingSeconds > 0;
        final claimedUids = (data['claimedUids'] as List?)?.map((e) => e.toString()).toSet() ?? <String>{};
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final alreadyClaimed = myUid.isNotEmpty && claimedUids.contains(myUid);
        final isDepleted = status != 'active' || remaining <= 0;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A0B12), Color(0xFF17060B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.55), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF1744).withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
                  ),
                ),
                const SizedBox(
                  width: 108,
                  height: 108,
                  child: SvgaPlayer(
                    assetPath: NewAssets.luckyBagCountdown,
                    fit: BoxFit.contain,
                  ),
                ),
                const Gap(6),
                Text(
                  _claimed ? 'LUCKY BAG OPENED!' : 'LUCKY BAG',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const Gap(4),
                Text(
                  sender != null && sender.isNotEmpty ? 'Dropped by $sender' : 'A Lucky Bag is waiting for you',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const Gap(16),
                if (_claimed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOU RECEIVED',
                          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2),
                        ),
                        const Gap(8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const PremiumDiamond(size: 30),
                            const Gap(10),
                            Text(
                              '$_reward',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('AWESOME', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          label: 'TOTAL POOL',
                          value: total.toString(),
                          icon: const PremiumDiamond(size: 16),
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: _InfoTile(
                          label: 'REMAINING',
                          value: '$remaining / $winners',
                          icon: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF7043), size: 17),
                        ),
                      ),
                    ],
                  ),
                  const Gap(10),
                  Text(
                    alreadyClaimed
                        ? 'You already grabbed a share of this bag.'
                        : isPending
                            ? 'Opens in ${openingSeconds ~/ 60}:${(openingSeconds % 60).toString().padLeft(2, '0')}'
                            : isDepleted
                            ? 'This Lucky Bag is fully claimed.'
                            : 'Tap to claim one random diamond share from the pool.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.4),
                  ),
                  if (_error != null) ...[
                    const Gap(10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const Gap(18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_claiming || alreadyClaimed || isPending || isDepleted) ? null : _claim,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white12,
                        disabledForegroundColor: Colors.white38,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        elevation: 0,
                      ),
                      child: _claiming
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                          : Text(
                              alreadyClaimed
                                  ? 'ALREADY CLAIMED'
                                  : isPending
                                      ? 'OPENING SOON'
                                      : isDepleted
                                      ? 'BAG EMPTY'
                                      : 'OPEN LUCKY BAG',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.1),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Widget icon;

  const _InfoTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const Gap(6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const Gap(5),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
