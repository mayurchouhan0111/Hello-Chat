import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hello_chat/core/models/gift_model.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:hello_chat/services/gift_service.dart';

import 'gift_combo_overlay.dart';
import 'gift_animation_overlay.dart';

/// How long a Quick Send combo survives after the last tap. Matches the
/// production live-streaming apps: keep tapping to extend, stop and it settles.
///
/// Aliased rather than duplicated: the combo banner must outlive the bar by
/// exactly this window, not by a differently-tuned copy of it.
const kQuickSendComboWindow = kComboBannerTimeout;

/// Can the user afford one more tap of a combo?
///
/// `reserved` is the cost of taps already dispatched but not yet reflected in
/// the Firestore balance. Firestore streams the new balance back well after a
/// tap burst, so without subtracting the in-flight reservation every tap in the
/// burst would be approved against the same stale balance and the server would
/// reject the tail of the combo.
///
/// Pure and top-level so it can be asserted directly - this is the one place
/// the combo can overspend, so it gets a runnable check.
bool canAffordQuickSend({
  required int balance,
  required int reserved,
  required int price,
}) =>
    balance - reserved >= price;

/// Persistent "Quick Send" bar that replaces the gift picker after the first send.
///
/// One tap == exactly one gift, no re-opening the picker. The combo count
/// increments per tap, the countdown ring resets per tap, and the bar collapses
/// itself when the window lapses or the wallet runs dry.
class QuickSendComboBar extends ConsumerStatefulWidget {
  final String roomId;
  final GiftModel gift;
  final String targetUid;
  final String targetName;
  final String targetPhotoUrl;

  /// Combo depth already banked by the picker's first send, so the bar starts at
  /// x1 rather than x0 and the very next tap is x2.
  final int startCount;

  final VoidCallback onDismiss;

  const QuickSendComboBar({
    super.key,
    required this.roomId,
    required this.gift,
    required this.targetUid,
    required this.targetName,
    required this.targetPhotoUrl,
    required this.onDismiss,
    this.startCount = 1,
  });

  @override
  ConsumerState<QuickSendComboBar> createState() => _QuickSendComboBarState();
}

class _QuickSendComboBarState extends ConsumerState<QuickSendComboBar>
    with TickerProviderStateMixin {
  /// Drives the countdown ring and the auto-dismiss.
  late final AnimationController _ring;

  /// Drives the x1 -> x2 -> x3 pop on the combo badge.
  late final AnimationController _bounce;

  /// Drives the collapse-out when the combo settles.
  late final AnimationController _exit;

  late final Animation<double> _bounceScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.30)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.30, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 60,
    ),
  ]).animate(_bounce);

  late int _combo;

  /// Diamonds already claimed by taps whose transaction has not resolved yet.
  /// The Firestore balance arrives long after a tap burst, so without this
  /// reservation every tap in the burst would be approved against the same
  /// stale balance and the server would reject the tail of the combo.
  int _reserved = 0;

  /// Serialises the actual sends. Rapid taps queue here instead of firing
  /// concurrent transactions at the same sender doc.
  Future<void> _chain = Future<void>.value();

  bool _finishing = false;

  /// Runs once the collapse-out animation has finished (e.g. open the wallet
  /// after an out-of-diamonds combo), so we never push a route mid-unmount.
  VoidCallback? _afterExit;

  @override
  void initState() {
    super.initState();
    debugPrint('QC bar mounted: gift=${widget.gift.name} target=${widget.targetUid} start=${widget.startCount}');
    _combo = widget.startCount;
    _ring = AnimationController(vsync: this, duration: kQuickSendComboWindow)
      ..addStatusListener(_onRingStatus)
      ..forward();
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))
      ..forward(from: 0);
    // `_exit` starts at value 1 and reverses to 0, so the settle status is
    // `dismissed` (AnimationController reports `completed` only when a forward
    // run reaches the upper bound). Listening for `completed` here meant the
    // dismiss callback and the recharge route never fired.
    _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1)
      ..addStatusListener((s) {
        if (s == AnimationStatus.dismissed && _finishing) _onExitComplete();
      });
  }

  void _onExitComplete() {
    debugPrint('QC bar dismissed combo=$_combo');
    widget.onDismiss();
    _afterExit?.call();
    _afterExit = null;
  }

  void _onRingStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  @override
  void dispose() {
    _ring
      ..removeStatusListener(_onRingStatus)
      ..dispose();
    _bounce.dispose();
    _exit.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_finishing) return;

    final price = widget.gift.priceInDiamonds;
    final liveBalance = ref.read(currentUserProfileProvider).value?.diamondBalance ?? 0;

    if (!canAffordQuickSend(balance: liveBalance, reserved: _reserved, price: price)) {
      _onInsufficient();
      return;
    }

    HapticFeedback.lightImpact();
    _reserved += price;
    _ring
      ..reset()
      ..forward();
    _bounce.forward(from: 0);
    setState(() => _combo += 1);

    final comboAtSend = _combo;
    _pushComboLocal(comboAtSend);

    // Synchronously capture Riverpod dependencies while the widget is guaranteed mounted
    final giftService = ref.read(giftServiceProvider);
    final combos = ref.read(giftComboControllerProvider(widget.roomId));
    final key = _comboKey;
    final roomId = widget.roomId;
    final gift = widget.gift;
    final targetUid = widget.targetUid;

    // Deliberately not awaited: the tap returns immediately so the button stays
    // responsive at 60fps, and the chain guarantees ordering + no dropped event.
    _chain = _chain.then((_) => _dispatch(
          giftService: giftService,
          combos: combos,
          key: key,
          roomId: roomId,
          gift: gift,
          targetUid: targetUid,
          combo: comboAtSend,
        )).whenComplete(() {
      _reserved -= price;
    });
  }

  /// Same key the server message and the chat row use, so the banner, the row
  /// and the ledger all describe one stream.
  String get _comboKey => comboKeyFor(
        ref.read(currentUserProfileProvider).value?.uid ?? '',
        widget.targetUid,
        widget.gift.giftId,
      );

  /// Optimistic bump: the banner has to move on the tap, not on the round trip.
  void _pushComboLocal(int count) {
    final senderUid = ref.read(currentUserProfileProvider).value?.uid ?? '';
    ref.read(giftComboControllerProvider(widget.roomId)).tapLocal(
          _comboKey,
          senderUid: senderUid,
          receiverUid: widget.targetUid,
          giftId: widget.gift.giftId,
          giftIconUrl: widget.gift.imageUrl,
          count: count,
        );
    ref.read(giftAnimationControllerProvider(widget.roomId)).playLocalGift(
          gift: widget.gift,
          senderUid: senderUid,
          targetUid: widget.targetUid,
          quantity: 1,
          comboCount: count,
        );
  }

  Future<void> _dispatch({
    required GiftService giftService,
    required GiftComboController combos,
    required String key,
    required String roomId,
    required GiftModel gift,
    required String targetUid,
    required int combo,
  }) async {
    try {
      await giftService.sendGift(
        roomId: roomId,
        gift: gift,
        targetUids: [targetUid],
        quantity: 1,
        comboCount: combo,
      );
    } catch (e) {
      // Give the optimistic bump back - the server never committed it.
      combos.rollbackLocal(key);
      if (!mounted) return;
      final msg = e
          .toString()
          .replaceAll('FirebaseFunctionsException:', '')
          .replaceAll('Exception:', '')
          .trim();
      if (msg.toLowerCase().contains('insufficient')) {
        _onInsufficient();
      } else {
        AppToast.showOverlay(
          context,
          message: msg.isEmpty ? 'Failed to send gift. Please try again.' : msg,
          type: ToastType.error,
        );
      }
    }
  }

  void _onInsufficient() {
    if (_finishing) return;
    _ring.stop();
    HapticFeedback.heavyImpact();
    AppToast.showOverlay(
      context,
      message: 'Insufficient Diamonds! Top up to keep the combo going.',
      type: ToastType.error,
    );
    // Grab the router while we are still mounted - the bar is about to unmount.
    final router = GoRouter.of(context);
    _finish(onSettled: () => router.push(AppRoutes.wallet));
  }

  void _finish({VoidCallback? onSettled}) {
    if (_finishing) return;
    _finishing = true;
    HapticFeedback.mediumImpact();
    _afterExit = onSettled;
    _ring.stop();
    _exit.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final liveBalance =
        ref.watch(currentUserProfileProvider.select((u) => u.value?.diamondBalance ?? 0));
    final price = widget.gift.priceInDiamonds;
    final affordable =
        canAffordQuickSend(balance: liveBalance, reserved: _reserved, price: price);

    return AnimatedBuilder(
      animation: _exit,
      builder: (context, child) => Opacity(
        opacity: _exit.value,
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF2D1B69), Color(0xFF1E1B4B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 0.5,
            ),
            const BoxShadow(
              color: Colors.black38,
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Close combo button on far left
            Semantics(
              button: true,
              label: 'combo-close',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _finish(),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(left: 2, right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                ),
              ),
            ),

            // Gift thumbnail
            _GiftThumb(url: widget.gift.imageUrl),
            const SizedBox(width: 8),

            // Gift name + diamond cost and recipient
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.gift.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PremiumDiamond(size: 11),
                          const SizedBox(width: 2),
                          Text(
                            '${widget.gift.priceInDiamonds}',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text(
                        "To: ",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: widget.targetPhotoUrl.isEmpty
                              ? null
                              : DecorationImage(
                                  image: CachedNetworkImageProvider(widget.targetPhotoUrl),
                                ),
                          color: widget.targetPhotoUrl.isEmpty ? Colors.white24 : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.targetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Remaining affordable balance pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumDiamond(size: 11),
                  const SizedBox(width: 3),
                  Text(
                    affordable ? '$liveBalance' : '0',
                    style: TextStyle(
                      color: affordable ? Colors.white : Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // One-tap repeat / combo button with circular countdown ring
            _SendButton(
              ring: _ring,
              bounceScale: _bounceScale,
              combo: _combo,
              enabled: affordable && !_finishing,
              onTap: _onTap,
              label: _combo == 1 ? 'Send' : 'Repeat',
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftThumb extends StatelessWidget {
  final String url;
  const _GiftThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url.isEmpty
            ? const Icon(Icons.card_giftcard_rounded, color: Colors.white54, size: 18)
            : url.startsWith('assets/')
                ? Image.asset(url, fit: BoxFit.contain, width: 26, height: 26)
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    width: 26,
                    height: 26,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.card_giftcard_rounded, color: Colors.white54, size: 18),
                  ),
      ),
    );
  }
}

/// The one-tap repeat button: a countdown ring around an xN combo badge.
class _SendButton extends StatelessWidget {
  final Animation<double> ring;
  final Animation<double> bounceScale;
  final int combo;
  final bool enabled;
  final VoidCallback onTap;
  final String label;

  const _SendButton({
    required this.ring,
    required this.bounceScale,
    required this.combo,
    required this.enabled,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label, combo $combo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: ring,
                builder: (context, _) => SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    value: (1.0 - ring.value).clamp(0.0, 1.0),
                    strokeWidth: 2.5,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                  ),
                ),
              ),
              ScaleTransition(
                scale: bounceScale,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: enabled
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF6A00)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800]),
                    shape: BoxShape.circle,
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF9100).withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'COMBO',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 6.8,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'x$combo',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
