import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/message_model.dart';
import '../../../../core/providers/profile_provider.dart';

/// How long a combo banner survives after the last update of its stream.
///
/// This is deliberately the same value as `kQuickSendComboWindow` in
/// `quick_send_combo_bar.dart`: if the banner timed out sooner it would unmount
/// mid-combo and the next tap would rebuild it from scratch, which is exactly
/// the "banner does not stay on screen for the whole combo" defect.
const kComboBannerTimeout = Duration(milliseconds: 5500);

/// Exit animation length. The controller removes the session this long after
/// flipping [ActiveGiftCombo.exiting].
const kComboBannerExit = Duration(milliseconds: 260);

/// One live combo stream: a single sender comboing one gift onto one receiver.
class ActiveGiftCombo {
  ActiveGiftCombo({
    required this.comboKey,
    required this.senderUid,
    required this.receiverUid,
    required this.giftId,
    required this.giftIconUrl,
    required this.count,
    required DateTime startedAt,
  })  : serverCount = count,
        lastSeenAt = startedAt,
        lastActivity = startedAt,
        lastMsgId = '';

  final String comboKey;
  final String senderUid;
  final String receiverUid;
  final String giftId;

  /// Re-read from the newest message so the icon survives a gift swap.
  String giftIconUrl;

  /// Displayed count. Monotonic: local taps raise it, server echoes win via max.
  int count;

  /// Highest count the server has actually confirmed. A failed dispatch rolls
  /// the optimistic bump back down to this floor.
  int serverCount;

  /// Newest server message already folded in - guards against `roomMessages`
  /// re-delivering the whole history on every snapshot.
  DateTime lastSeenAt;
  String lastMsgId;

  /// Local clock of the last tap or message, used only for ordering the track.
  /// Deliberately separate from [lastSeenAt], which must never see local time.
  DateTime lastActivity;

  /// comboCount-less messages (the picker's first send) count each doc once.
  final Set<String> countedIds = <String>{};

  bool exiting = false;
  Timer? dismissTimer;
  Timer? exitTimer;
}

/// Holds the active combo streams for one room and drives the banner track.
///
/// Two consumers, one source of truth:
///  * [GiftComboOverlay] renders exactly one banner per stream and updates its
///    count in place - never one banner per tap.
///  * the chat gift tile reads `count` so its "xN" keeps moving after the
///    per-tap chat rows are folded into a single row.
class GiftComboController extends ChangeNotifier {
  final Map<String, ActiveGiftCombo> _combos = {};

  /// Final count of every combo that has already settled, so the chat row that
  /// opened the stream does not snap back to the "x1" baked into its text.
  /// Bounded: a room never shows more than a handful of gift rows at once.
  final Map<String, int> _settled = {};

  /// Newest activity first, so the track can cap what it draws without hiding
  /// the stream the user is currently tapping.
  List<ActiveGiftCombo> get active {
    final list = _combos.values.toList();
    list.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return list;
  }

  ActiveGiftCombo? operator [](String? comboKey) =>
      comboKey == null ? null : _combos[comboKey];

  /// Last count of a stream that already settled, or null if there was none.
  int? settledCount(String? comboKey) =>
      comboKey == null ? null : _settled[comboKey];

  void applyRemote(RoomMessage msg, {required String giftIconUrl}) {
    final key = msg.giftComboKey;
    if (key == null) return;

    var combo = _combos[key];
    final settledFloor = _settled[key] ?? 0;

    if (combo == null) {
      // If this message has a combo count that is less than or equal to what already settled,
      // it is a stale/delayed echo of the completed combo. Never resurrect with a lower number!
      if (msg.comboCount > 0 && msg.comboCount <= settledFloor) {
        return;
      }
      final initialCount = msg.comboCount > 0 ? msg.comboCount : math.max(1, msg.quantity);
      combo = ActiveGiftCombo(
        comboKey: key,
        senderUid: msg.uid,
        receiverUid: msg.targetUid,
        giftId: msg.giftId!,
        giftIconUrl: giftIconUrl,
        count: math.max(settledFloor > 0 ? settledFloor : 1, initialCount),
        startedAt: msg.createdAt,
      );
      combo.lastMsgId = msg.msgId;
      if (msg.comboCount == 0) combo.countedIds.add(msg.msgId);
      _combos[key] = combo;
      _arm(combo);
      notifyListeners();
      return;
    }

    // `roomMessages` re-emits the whole window on every snapshot: only a
    // strictly newer message than the last one folded in may touch the session,
    // UNLESS the message has a higher combo count (higher combo count always advances).
    final bool isHigherCombo = msg.comboCount > 0 && msg.comboCount > combo.count;
    if (!isHigherCombo) {
      if (msg.createdAt.isBefore(combo.lastSeenAt)) return;
      if (msg.createdAt == combo.lastSeenAt && msg.msgId == combo.lastMsgId) return;
    }

    if (msg.comboCount > 0) {
      combo.count = math.max(combo.count, math.max(settledFloor, msg.comboCount));
      combo.serverCount = math.max(combo.serverCount, math.max(settledFloor, msg.comboCount));
    } else if (combo.countedIds.add(msg.msgId)) {
      final once = math.max(1, msg.quantity);
      combo.count = math.max(combo.count, math.max(settledFloor, once));
      combo.serverCount = math.max(combo.serverCount, math.max(settledFloor, once));
    }
    combo.giftIconUrl = giftIconUrl;
    if (msg.createdAt.isAfter(combo.lastSeenAt) || isHigherCombo) {
      combo.lastSeenAt = msg.createdAt;
      combo.lastMsgId = msg.msgId;
    }
    _arm(combo);
    notifyListeners();
  }

  /// Optimistic bump so the banner moves with the tap instead of waiting for
  /// the round trip. `count` is the bar's own running combo, so a re-delivered
  /// server echo with a lower value cannot pull it backwards.
  void tapLocal(
    String comboKey, {
    required String senderUid,
    required String receiverUid,
    required String giftId,
    required String giftIconUrl,
    required int count,
  }) {
    final combo = _combos.putIfAbsent(
      comboKey,
      () => ActiveGiftCombo(
        comboKey: comboKey,
        senderUid: senderUid,
        receiverUid: receiverUid,
        giftId: giftId,
        giftIconUrl: giftIconUrl,
        count: 1,
        // Epoch, not now: the first server message must beat local clock skew
        // or the echo would be judged "older than the session" and dropped.
        startedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    combo.count = math.max(combo.count, count);
    combo.giftIconUrl = giftIconUrl;
    _arm(combo);
    notifyListeners();
  }

  /// A dispatch failed: give back the optimistic bump, never below what the
  /// server has already confirmed.
  void rollbackLocal(String comboKey) {
    final combo = _combos[comboKey];
    if (combo == null) return;
    combo.count = math.max(combo.serverCount, combo.count - 1);
    notifyListeners();
  }

  void _arm(ActiveGiftCombo combo) {
    if (combo.exiting) {
      combo.exitTimer?.cancel();
      combo.exiting = false;
    }
    combo.lastActivity = DateTime.now();
    combo.dismissTimer?.cancel();
    combo.dismissTimer = Timer(kComboBannerTimeout, () => _beginExit(combo.comboKey));
  }

  void _beginExit(String comboKey) {
    final combo = _combos[comboKey];
    if (combo == null || combo.exiting) return;
    combo.exiting = true;
    notifyListeners();
    combo.exitTimer = Timer(kComboBannerExit, () => remove(comboKey));
  }

  void remove(String comboKey) {
    final combo = _combos.remove(comboKey);
    if (combo == null) return;
    // ponytail: FIFO eviction by insertion order - swap for LRU if a room ever
    // holds more live gift rows than this.
    if (_settled.length > 64) _settled.remove(_settled.keys.first);
    _settled[comboKey] = combo.count;
    combo.dismissTimer?.cancel();
    combo.exitTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final combo in _combos.values) {
      combo.dismissTimer?.cancel();
      combo.exitTimer?.cancel();
    }
    _combos.clear();
    super.dispose();
  }
}

/// Auto-disposed with the room. Always watched by [GiftComboOverlay] (mounted
/// for the whole room session), so a `ref.read` from the send bar or the
/// message listener can never create a provider that gets dropped mid-combo.
final giftComboControllerProvider = ChangeNotifierProvider.autoDispose
    .family<GiftComboController, String>((_, __) => GiftComboController());

/// Renders the active combo banners, positioned in the lower area directly above the chat message feed.
class GiftComboOverlay extends ConsumerWidget {
  final String roomId;

  const GiftComboOverlay({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combos = ref.watch(giftComboControllerProvider(roomId)).active;
    if (combos.isEmpty) return const SizedBox.shrink();

    final screenH = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final chatHeight = (screenH * 0.24).clamp(160.0, 220.0);
    // Positioned directly above the chat message area, under the seats (matching reference image)
    final bannerBottom = 56 + 8 + bottomInset + chatHeight + 6;

    return Positioned(
      bottom: bannerBottom,
      left: 10,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final combo in combos.take(1))
              RepaintBoundary(
                key: ValueKey('combo_banner_${combo.comboKey}'),
                child: _ComboBanner(combo: combo),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComboBanner extends ConsumerStatefulWidget {
  final ActiveGiftCombo combo;

  const _ComboBanner({required this.combo});

  @override
  ConsumerState<_ComboBanner> createState() => _ComboBannerState();
}

class _ComboBannerState extends ConsumerState<_ComboBanner>
    with SingleTickerProviderStateMixin {
  /// Drives the count bump. Keyed on the value we last painted, because the
  /// ActiveGiftCombo instance is mutated in place and so never "changes".
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: kComboBannerExit,
  );

  late int _shown = widget.combo.count;

  late final Animation<double> _bump = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 60,
    ),
  ]).animate(_pulse);

  @override
  void didUpdateWidget(covariant _ComboBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.combo.count != _shown) {
      setState(() {
        _shown = widget.combo.count;
      });
      if (_pulse.isAnimating) {
        _pulse.forward(from: 0.15);
      } else {
        _pulse.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final combo = widget.combo;
    final sender = ref.watch(cachedUserProfileProvider(combo.senderUid)).value;
    final receiver = ref.watch(cachedUserProfileProvider(combo.receiverUid)).value;
    final senderName = sender?.displayName ?? '';
    final receiverName = receiver?.displayName ?? '';

    return AnimatedSlide(
      offset: combo.exiting ? const Offset(-1.2, 0) : Offset.zero,
      duration: kComboBannerExit,
      curve: Curves.easeInCubic,
      child: AnimatedOpacity(
        opacity: combo.exiting ? 0 : 1,
        duration: kComboBannerExit,
        curve: Curves.easeInCubic,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 28,
            padding: const EdgeInsets.only(left: 3, right: 8, top: 2, bottom: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xEE7C3AED), Color(0xCC6D28D9), Color(0x995B21B6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFA78BFA).withValues(alpha: 0.45),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x666D28D9),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Sender Avatar in golden circular ring
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                  ),
                  child: ClipOval(
                    child: (sender?.profilePhotoUrl.isNotEmpty ?? false)
                        ? CachedNetworkImage(
                            imageUrl: sender!.profilePhotoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 13,
                              color: Colors.white70,
                            ),
                          )
                        : Image.network(
                            "https://picsum.photos/seed/${combo.senderUid}/100",
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 13,
                              color: Colors.white70,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 5),
                // Sender Name
                Text(
                  senderName.isNotEmpty ? senderName : 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(width: 4),
                // "send" text
                const Text(
                  'send',
                  style: TextStyle(
                    color: Color(0xFFDDD6FE),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 4),
                // Receiver Name
                Text(
                  receiverName.isNotEmpty ? receiverName : 'Room',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFDE047),
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(width: 4),
                // Dedicated Gift Image/Icon
                _giftIcon(combo.giftIconUrl, combo.giftId),
                const SizedBox(width: 4),
                // Multiplier count
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) =>
                      Transform.scale(scale: _bump.value, child: child),
                  child: Text(
                    'x${widget.combo.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      shadows: [
                        Shadow(
                          color: Color(0xFF4C1D95),
                          blurRadius: 3,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _giftIcon(String url, String giftId) {
    String resolved = url.trim();
    if (resolved.isEmpty ||
        resolved.endsWith('.svga') ||
        resolved.endsWith('.json') ||
        resolved.endsWith('.vap') ||
        resolved.endsWith('.zip') ||
        resolved.endsWith('.mp4')) {
      resolved = _resolveGiftImage(giftId, resolved);
    }

    if (resolved.startsWith('assets/')) {
      return Image.asset(
        resolved,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.card_giftcard,
          color: Color(0xFFFFD700),
          size: 16,
        ),
      );
    }
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: resolved,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Icon(
          Icons.card_giftcard,
          color: Color(0xFFFFD700),
          size: 16,
        ),
        placeholder: (_, __) => const SizedBox(width: 20, height: 20),
      );
    }
    if (resolved.isNotEmpty && resolved.length <= 4) {
      return Center(
        child: Text(resolved, style: const TextStyle(fontSize: 14)),
      );
    }
    return const Icon(Icons.card_giftcard, color: Color(0xFFFFD700), size: 16);
  }

  static String _resolveGiftImage(String giftId, String fallback) {
    final lower = giftId.toLowerCase();
    if (lower.contains('bell')) return 'assets/images/gifts/golden_bell.png';
    if (lower.contains('love')) return 'assets/images/gifts/love_you.png';
    if (lower.contains('138') || lower.contains('panda') || lower.contains('moonlight')) {
      return 'assets/images/gifts/moonlight_panda.png';
    }
    if (lower.contains('windchime') || lower.contains('music')) {
      return 'assets/images/gifts/crystal_windchime.png';
    }
    if (lower.contains('piano') || lower.contains('169522')) {
      return 'assets/images/gifts/grand_piano.png';
    }
    if (lower.contains('feast') || lower.contains('2529')) {
      return 'assets/images/gifts/gourmet_feast.png';
    }
    if (lower.contains('romance') || lower.contains('251779')) {
      return 'assets/images/gifts/sweet_romance.png';
    }
    if (lower.contains('excalibur') || lower.contains('256006')) {
      return 'assets/images/gifts/flame_excalibur.png';
    }
    if (lower.contains('dates') || lower.contains('normal')) {
      return 'assets/images/gifts/golden_dates.png';
    }
    if (lower.contains('princess') || lower.contains('219667')) {
      return 'assets/images/gifts/crystal_princess.png';
    }
    if (lower.contains('rose')) return 'assets/images/gifts/rose.png';
    return fallback;
  }
}
