import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/game_provider.dart';
import 'package:hello_chat/core/constants/new_assets_constants.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:hello_chat/core/widgets/svga_player.dart';

class GlobalWheelWinnerBanner extends ConsumerStatefulWidget {
  final bool blocked;

  const GlobalWheelWinnerBanner({super.key, this.blocked = false});

  @override
  ConsumerState<GlobalWheelWinnerBanner> createState() =>
      _GlobalWheelWinnerBannerState();
}

class _GlobalWheelWinnerBannerState
    extends ConsumerState<GlobalWheelWinnerBanner> {
  Timer? _dismissTimer;
  Map<String, dynamic>? _visibleEvent;
  Map<String, dynamic>? _pendingEvent;
  String? _lastEventId;

  void _showEvent(Map<String, dynamic>? event) {
    if (event == null || !mounted) return;
    final eventId = (event['eventId'] ?? '').toString();
    final announcedAtMs = (event['announcedAtMs'] as num?)?.toInt() ?? 0;
    final ageMs = DateTime.now().millisecondsSinceEpoch - announcedAtMs;
    if (eventId.isEmpty ||
        eventId == _lastEventId ||
        ageMs < -5000 ||
        ageMs > 10000) {
      return;
    }
    if (widget.blocked) {
      _pendingEvent = event;
      return;
    }
    _lastEventId = eventId;
    _pendingEvent = null;
    _dismissTimer?.cancel();
    setState(() => _visibleEvent = event);
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visibleEvent = null);
    });
  }

  @override
  void didUpdateWidget(covariant GlobalWheelWinnerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.blocked && widget.blocked && _visibleEvent != null) {
      _dismissTimer?.cancel();
      _pendingEvent = _visibleEvent;
      _visibleEvent = null;
    } else if (oldWidget.blocked && !widget.blocked && _pendingEvent != null) {
      final pending = _pendingEvent;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showEvent(pending));
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      luckySpinWinnerEventProvider,
      (_, next) => _showEvent(next.valueOrNull),
    );
    final winner = _visibleEvent;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
        child: winner == null
            ? const SizedBox.shrink(key: ValueKey('winner_banner_empty'))
            : Center(
                key: ValueKey((winner['eventId'] ?? '').toString()),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: GameTopWinnerBanner(
                    label: 'TOP 1 WINNER',
                    name: (winner['userName'] ?? winner['name'] ?? 'Winner')
                        .toString(),
                    showName: true,
                    avatarUrl: (winner['avatar'] ?? '').toString(),
                    amount: (winner['amount'] as num?)?.toInt() ?? 0,
                    gameIconAsset: 'assets/images/game_spin_wheel_art.jpg',
                  ),
                ),
              ),
      ),
    );
  }
}

/// Animated 750x128 ribbon that celebrates the #1 winner of a game round.
/// Perfectly aligned to the native SVGA slots:
/// - Left: Game trophy graphic (native SVGA)
/// - Middle: Top Winner label, Name, and Diamond Jackpot amount
/// - Right: Circular winner avatar inside the golden laurel wreath (sendheadimg)
class GameTopWinnerBanner extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final int amount;
  final String label;
  final int? totalWins;
  final String gameIconAsset;
  final bool showName;

  const GameTopWinnerBanner({
    super.key,
    required this.name,
    this.avatarUrl = '',
    required this.amount,
    this.label = 'TOP 1 WINNER',
    this.totalWins,
    this.gameIconAsset = 'assets/images/game_spin_wheel_art.jpg',
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    // Native SVGA Canvas: 750 x 128
    return AspectRatio(
      aspectRatio: 750 / 128,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final s = w / 750.0;

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // 1. Native Golden Winner Ribbon Animation
              const SvgaPlayer(
                assetPath: NewAssets.gameTopWinnerBanner,
                fit: BoxFit.fill,
              ),

              Positioned(
                left: 80 * s,
                top: 30 * s,
                width: 72 * s,
                height: 72 * s,
                child: ClipOval(
                  child: Image.asset(
                    gameIconAsset,
                    semanticLabel: 'Game icon',
                    fit: BoxFit.cover,
                    cacheWidth: 100,
                  ),
                ),
              ),

              if (totalWins != null) ...[
                Positioned(
                  left: 170 * s,
                  right: 198 * s,
                  top: 40 * s,
                  bottom: 18 * s,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: const Color(0xDE522A0D),
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6 * s),
                      child: Column(children: [
                        Expanded(
                            child: Center(
                                child: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 26 * s,
                                        height: 1)))),
                        Expanded(
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    '$totalWins ${totalWins == 1 ? "win" : "wins"}',
                                    style: TextStyle(
                                        color: const Color(0xFFFFDF91),
                                        fontSize: 24 * s,
                                        fontWeight: FontWeight.w600)))),
                      ]),
                    ),
                  ),
                ),
              ] else ...[
                // 2. Winner Information (Center slot: x=200..540)
                Positioned(
                  left: 200.0 * s,
                  top: 24.0 * s,
                  width: 340.0 * s,
                  height: 50.0 * s,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFFFD700),
                          fontSize: 9.0 * s,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          height: 1.0,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 3)
                          ],
                        ),
                      ),
                      SizedBox(height: 3.0 * s),
                      if (showName)
                        Text(
                          name.isEmpty ? 'Winner' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5 * s,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            shadows: const [
                              Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                  offset: Offset(0, 1))
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 3. Diamond Jackpot Amount (Center-bottom slot: y=76..110)
                Positioned(
                  left: 230.0 * s,
                  top: 76.0 * s,
                  width: 280.0 * s,
                  height: 34.0 * s,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      PremiumDiamond(size: 16.0 * s),
                      SizedBox(width: 5.0 * s),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            amount.toString(),
                            style: TextStyle(
                              color: const Color(0xFFFFE082),
                              fontSize: 17.0 * s,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(
                                    color: Color(0xFFE65100),
                                    blurRadius: 4,
                                    offset: Offset(0, 1)),
                                Shadow(
                                    color: Colors.black,
                                    blurRadius: 5,
                                    offset: Offset(0, 1.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 4. Winner Avatar: native bbox (x=566.0, y=22.0, w=89.0, h=89.0)
              Positioned(
                left: 566.0 * s,
                top: 22.0 * s,
                width: 89.0 * s,
                height: 89.0 * s,
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: 89.0 * s,
                          height: 89.0 * s,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person,
                            color: Colors.white70,
                            size: 46.0 * s,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: Colors.white70,
                          size: 46.0 * s,
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
