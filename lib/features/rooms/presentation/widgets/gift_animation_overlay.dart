import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import '../../../../core/utils/app_persistent_cache.dart';
import '../../../../core/models/gift_model.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../services/gift_service.dart';
import 'gift_combo_overlay.dart';
import 'seat_grid.dart';

/// Representation of an immediate local gift animation event.
class GiftAnimationEvent {
  final String id;
  final String roomId;
  final String giftId;
  final String giftUrl;
  final String? imageUrl;
  final String? soundUrl;
  final String format;
  final String category;
  final String giftName;
  final String tier;
  final int durationMs;
  final String senderUid;
  final String targetUid;
  final int quantity;
  final int comboCount;
  final String text;

  GiftAnimationEvent({
    required this.id,
    required this.roomId,
    required this.giftId,
    required this.giftUrl,
    this.imageUrl,
    this.soundUrl,
    this.format = 'json',
    this.category = 'Normal',
    this.giftName = '',
    this.tier = 'NORMAL',
    this.durationMs = 0,
    required this.senderUid,
    required this.targetUid,
    this.quantity = 1,
    this.comboCount = 0,
    this.text = '',
  });
}

/// Controller allowing immediate optimistic gift animation triggers
/// without waiting for Firestore network roundtrip, and deduplicating server echoes.
class GiftAnimationController extends ChangeNotifier {
  final List<GiftAnimationEvent> _pendingLocalEvents = [];
  final Map<String, List<int>> _recentLocalDispatches = {};
  int _localCounter = 0;

  List<GiftAnimationEvent> consumePendingEvents() {
    if (_pendingLocalEvents.isEmpty) return const [];
    final list = List<GiftAnimationEvent>.from(_pendingLocalEvents);
    _pendingLocalEvents.clear();
    return list;
  }

  /// Dispatches an animation immediately for the local sender without waiting for network roundtrip.
  void playLocalGift({
    required GiftModel gift,
    required String senderUid,
    required String targetUid,
    int quantity = 1,
    int comboCount = 0,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final key = '$senderUid|$targetUid|${gift.giftId}';
    final timestamps = _recentLocalDispatches.putIfAbsent(key, () => <int>[]);
    timestamps.add(nowMs);

    // Prune entries older than 15s across all keys
    _recentLocalDispatches.removeWhere((_, list) {
      list.removeWhere((time) => nowMs - time > 15000);
      return list.isEmpty;
    });

    final rawUrl = gift.lottieAssetPath.trim().isNotEmpty ? gift.lottieAssetPath.trim() : gift.imageUrl.trim();
    final localSvga = SvgaParserUtil.getLocalGiftSvgaPath(rawUrl, giftId: gift.giftId, giftName: gift.name);
    final localVap = SvgaParserUtil.getLocalVapPath(rawUrl, giftId: gift.giftId, giftName: gift.name);
    final localLottie = SvgaParserUtil.getLocalLottiePath(rawUrl, giftId: gift.giftId, giftName: gift.name);

    String resolvedFormat = gift.animationFormat;
    String resolvedUrl = rawUrl;
    if (localSvga != null) {
      resolvedFormat = 'svga';
      resolvedUrl = localSvga;
    } else if (localVap != null) {
      resolvedFormat = 'vap';
      resolvedUrl = localVap;
    } else if (localLottie != null) {
      resolvedFormat = 'json';
      resolvedUrl = localLottie;
    } else {
      final lower = rawUrl.toLowerCase();
      if (lower.contains('.svga')) {
        resolvedFormat = 'svga';
      } else if (lower.contains('.vap') || lower.contains('.vpa') || lower.contains('.mp4') || lower.contains('.pag')) {
        resolvedFormat = 'vap';
      } else if (lower.contains('.png') || lower.contains('.jpg') || lower.contains('.webp')) {
        resolvedFormat = 'image';
      }
    }

    final event = GiftAnimationEvent(
      id: 'local_${nowMs}_${_localCounter++}_${gift.giftId}_$targetUid',
      roomId: '',
      giftId: gift.giftId,
      giftUrl: resolvedUrl,
      imageUrl: gift.imageUrl,
      soundUrl: gift.soundUrl,
      format: resolvedFormat,
      category: gift.category,
      giftName: gift.name,
      tier: gift.animationTier,
      durationMs: gift.durationMs,
      senderUid: senderUid,
      targetUid: targetUid,
      quantity: quantity > 0 ? quantity : 1,
      comboCount: comboCount,
      text: 'Sent ${gift.name} x$quantity',
    );

    _pendingLocalEvents.add(event);
    notifyListeners();
  }

  /// Returns true if a server echo was already played locally.
  bool shouldSkipEcho({
    required String senderUid,
    required String targetUid,
    required String giftId,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final key = '$senderUid|$targetUid|$giftId';
    final timestamps = _recentLocalDispatches[key];
    if (timestamps != null && timestamps.isNotEmpty) {
      while (timestamps.isNotEmpty) {
        final dispatchedAt = timestamps.removeAt(0);
        if (nowMs - dispatchedAt < 12000) {
          if (timestamps.isEmpty) {
            _recentLocalDispatches.remove(key);
          }
          return true;
        }
      }
      if (timestamps.isEmpty) {
        _recentLocalDispatches.remove(key);
      }
    }
    return false;
  }
}

final giftAnimationControllerProvider =
    ChangeNotifierProvider.family<GiftAnimationController, String>((ref, roomId) {
  final controller = GiftAnimationController();
  ref.onDispose(controller.dispose);
  return controller;
});

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
  /// Anchor for resolving seat rects relative to this overlay's coordinate
  /// space (Layer 1 seat-anchored effects).
  final GlobalKey _overlayKey = GlobalKey(debugLabel: 'gift_overlay_stack');
  final Set<String> _processedMessageIds = {};
  bool _initialHistorySeeded = false;
  final List<_ActiveGiftAnimation> _pendingQueue = [];
  final Map<String, List<_ActiveGiftAnimation>> _seatQueues = {};
  final Map<String, _ActiveSeatGift> _currentSeatGifts = {};
  _ActiveGiftAnimation? _currentAnimation;
  bool _isPlaying = false;
  Timer? _animationTimer;
  List<GiftModel> _gifts = [];

  void _enqueueSeatAnimation(String targetUid, _ActiveGiftAnimation animation) {
    if (!mounted) return;
    final key = targetUid.isNotEmpty ? targetUid : '_unseated_';
    final queue = _seatQueues.putIfAbsent(key, () => []);
    if (queue.length < 50) {
      queue.add(animation);
    }
    _checkNextSeatAnimation(key);
  }

  void _checkNextSeatAnimation(String targetKey) {
    if (!mounted) return;
    if (_currentSeatGifts.containsKey(targetKey)) return;

    final queue = _seatQueues[targetKey];
    if (queue == null || queue.isEmpty) return;

    final nextAnim = queue.removeAt(0);
    // Backstop only — the player's own onComplete normally advances the queue.
    // Kept above the inner players' watchdogs so it never cuts a live clip.
    final int safeMs = math.max(nextAnim.durationMs + 4000, 20000);
    final timer = Timer(Duration(milliseconds: safeMs), () {
      _onSeatAnimationFinished(targetKey, nextAnim.id);
    });

    setState(() {
      _currentSeatGifts[targetKey] = _ActiveSeatGift(
        id: nextAnim.id,
        targetUid: targetKey == '_unseated_' ? '' : targetKey,
        animation: nextAnim,
        expiryTimer: timer,
        hasFlown: false,
      );
    });
  }

  void _onSeatAnimationFinished(String targetKey, String animId) {
    if (!mounted) return;
    final active = _currentSeatGifts[targetKey];
    if (active?.id == animId) {
      active?.expiryTimer.cancel();
      final queue = _seatQueues[targetKey];
      if (queue != null && queue.isNotEmpty) {
        final nextAnim = queue.removeAt(0);
        final int safeMs = math.max(nextAnim.durationMs + 4000, 20000);
        final timer = Timer(Duration(milliseconds: safeMs), () {
          _onSeatAnimationFinished(targetKey, nextAnim.id);
        });
        setState(() {
          _currentSeatGifts[targetKey] = _ActiveSeatGift(
            id: nextAnim.id,
            targetUid: targetKey == '_unseated_' ? '' : targetKey,
            animation: nextAnim,
            expiryTimer: timer,
            hasFlown: true, // Seamless transition at the seat anchor without flying from center or blank flashing
          );
        });
      } else {
        setState(() {
          _currentSeatGifts.remove(targetKey);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Configure global audio context once so individual players never incur platform latency
    try {
      AudioPlayer.global.setAudioContext(
        const AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint("[GiftAudio] Failed to set global audio context: $e");
    }

    // Loads the catalog so every gift message can be resolved by giftId to its
    // tier / duration / sound instead of URL-sniffing. Deferred one tick so
    // initState never touches `ref` synchronously.
    Future.microtask(_preloadGifts);
  }

  void _preloadGifts() async {
    if (!mounted) return;
    try {
      final gifts = await ref.read(giftServiceProvider).getGiftsFuture();
      if (mounted) {
        setState(() {
          _gifts = gifts;
        });
      }
      for (final gift in gifts) {
        if (!mounted) return;
        final url = gift.lottieAssetPath.trim();
        if (url.isNotEmpty) {
          final localSvga = SvgaParserUtil.getLocalGiftSvgaPath(url, giftId: gift.giftId, giftName: gift.name);
          final localVap = SvgaParserUtil.getLocalVapPath(url, giftId: gift.giftId, giftName: gift.name);
          final localLottie = SvgaParserUtil.getLocalLottiePath(url, giftId: gift.giftId, giftName: gift.name);

          if (localSvga != null || url.toLowerCase().contains('.svga') || gift.animationFormat == 'svga') {
            final targetPath = localSvga ?? url;
            if (targetPath.startsWith('assets/')) {
              SvgaParserUtil.decodeSafeFromAssets(targetPath).then((movie) {
                SvgaParserUtil.getPreparedAudios(movie, targetPath, 30);
              });
            }
          } else if (localVap != null || url.toLowerCase().contains('.mp4') || url.toLowerCase().contains('.vap') || gift.animationFormat == 'vap') {
            final targetVap = localVap ?? url;
            if (targetVap.startsWith('assets/')) {
              rootBundle.load(targetVap).then<void>((_) {}, onError: (_) {});
            }
          } else {
            final targetLottie = localLottie ?? (url.startsWith('assets/') ? url : null);
            if (targetLottie != null) {
              LottieCache.preloadLocal(targetLottie);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("[GiftCache] Error preloading gifts: $e");
    }
  }

  void _handleLocalAnimationEvents(List<GiftAnimationEvent> events) {
    bool changed = false;
    for (final ev in events) {
      final qty = ev.quantity > 0 ? ev.quantity : 1;
      final playCount = qty > 10 ? 10 : qty;
      final targetUid = ev.targetUid.trim();

      // Ensure local asset path & format are resolved
      final rawUrl = ev.giftUrl;
      final localSvga = SvgaParserUtil.getLocalGiftSvgaPath(rawUrl, giftId: ev.giftId, giftName: ev.giftName);
      final localVap = SvgaParserUtil.getLocalVapPath(rawUrl, giftId: ev.giftId, giftName: ev.giftName);
      final localLottie = SvgaParserUtil.getLocalLottiePath(rawUrl, giftId: ev.giftId, giftName: ev.giftName);

      String resolvedFormat = ev.format;
      String resolvedUrl = rawUrl;
      if (localSvga != null) {
        resolvedFormat = 'svga';
        resolvedUrl = localSvga;
      } else if (localVap != null) {
        resolvedFormat = 'vap';
        resolvedUrl = localVap;
      } else if (localLottie != null) {
        resolvedFormat = 'json';
        resolvedUrl = localLottie;
      } else {
        final lower = rawUrl.toLowerCase();
        if (lower.contains('.svga')) {
          resolvedFormat = 'svga';
        } else if (lower.contains('.vap') || lower.contains('.vpa') || lower.contains('.mp4') || lower.contains('.pag')) {
          resolvedFormat = 'vap';
        }
      }

      if (ev.tier == 'NORMAL') {
        for (int i = 0; i < playCount; i++) {
          final anim = _ActiveGiftAnimation(
            id: "${ev.id}_$i",
            url: resolvedUrl,
            senderUid: ev.senderUid,
            text: ev.text,
            imageUrl: ev.imageUrl,
            soundUrl: ev.soundUrl,
            format: resolvedFormat,
            giftCategory: ev.category,
            giftName: ev.giftName,
            tier: ev.tier,
            durationMs: ev.durationMs,
            targetUid: targetUid.isNotEmpty ? targetUid : null,
          );
          _enqueueSeatAnimation(targetUid, anim);
        }
      } else {
        for (int i = 0; i < playCount; i++) {
          final anim = _ActiveGiftAnimation(
            id: "${ev.id}_$i",
            url: resolvedUrl,
            senderUid: ev.senderUid,
            text: ev.text,
            imageUrl: ev.imageUrl,
            soundUrl: ev.soundUrl,
            format: resolvedFormat,
            giftCategory: ev.category,
            giftName: ev.giftName,
            tier: ev.tier,
            durationMs: ev.durationMs,
            targetUid: targetUid.isNotEmpty ? targetUid : null,
          );
          if (_pendingQueue.length < 50) {
            _pendingQueue.add(anim);
            changed = true;
          }
        }
      }
    }
    if (changed && mounted) {
      _triggerNextAnimation();
    }
  }

  void _handleMessages(List<RoomMessage> messages) {
    // On room entry, seed the entire existing history as already processed so
    // joining (or re-mounting the overlay, e.g. PK toggling) never replays
    // gifts that were sent before we started watching. Only genuinely new
    // messages arriving after mount are animated.
    if (!_initialHistorySeeded) {
      _initialHistorySeeded = true;
      for (final m in messages) {
        _processedMessageIds.add(m.msgId);
      }
    }

    final combos = ref.read(giftComboControllerProvider(widget.roomId));
    final animController = ref.read(giftAnimationControllerProvider(widget.roomId));
    final currentUid = ref.read(currentUserProfileProvider).value?.uid;

    // Filter unprocessed gift messages (accept if animationUrl is non-empty OR giftId is non-empty)
    final newGifts = messages.where((msg) =>
        msg.type == 'gift' &&
        !_processedMessageIds.contains(msg.msgId) &&
        (
          (msg.animationUrl != null && msg.animationUrl!.trim().isNotEmpty) ||
          (msg.giftId != null && msg.giftId!.trim().isNotEmpty)
        )).toList();

    // Process strictly in ascending chronological sending order (oldest first, newest last)
    newGifts.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      if (cmp != 0) return cmp;
      return a.comboCount.compareTo(b.comboCount);
    });

    bool changed = false;
    for (final msg in newGifts) {
      _processedMessageIds.add(msg.msgId);

      // Check if this sender already played this gift optimistically
      final isFromMe = currentUid != null && msg.uid == currentUid;
      if (isFromMe && animController.shouldSkipEcho(
        senderUid: msg.uid,
        targetUid: msg.targetUid,
        giftId: msg.giftId ?? '',
      )) {
        // Still feed combo controller with authoritative icon, but skip redundant local re-animation
        combos.applyRemote(msg, giftIconUrl: msg.imageUrl ?? msg.animationUrl ?? '');
        continue;
      }

      final String effectiveGiftId = msg.giftId?.trim() ?? '';
      String giftUrl = msg.animationUrl?.trim() ?? '';
      String? imageUrl = msg.imageUrl;
      String? soundUrl = msg.soundUrl;
      String format = msg.format?.isNotEmpty == true ? msg.format! : '';
      String category = msg.giftCategory?.isNotEmpty == true ? msg.giftCategory! : 'Normal';
      String giftName = msg.giftName?.isNotEmpty == true ? msg.giftName! : '';
      String tier = msg.tier?.isNotEmpty == true ? msg.tier! : '';
      int durationMs = msg.durationMs;

      // 1. Match from cached catalog
      GiftModel? matched;
      if (effectiveGiftId.isNotEmpty) {
        for (final g in _gifts) {
          if (g.giftId == effectiveGiftId) {
            matched = g;
            break;
          }
        }
      }
      if (matched == null && giftUrl.isNotEmpty) {
        for (final g in _gifts) {
          if (g.lottieAssetPath.trim() == giftUrl || g.imageUrl.trim() == giftUrl) {
            matched = g;
            break;
          }
        }
      }

      if (matched != null) {
        imageUrl ??= matched.imageUrl;
        soundUrl ??= matched.soundUrl;
        if (format.isEmpty) format = matched.animationFormat;
        if (category == 'Normal') category = matched.category;
        if (giftName.isEmpty) giftName = matched.name;
        if (tier.isEmpty) tier = matched.animationTier;
        if (durationMs <= 0) durationMs = matched.durationMs;
        if (giftUrl.isEmpty) giftUrl = matched.lottieAssetPath.trim();
        if (giftUrl.isEmpty) giftUrl = matched.imageUrl.trim();
      }

      // 2. Resolve local asset paths if available
      final lookupKey = giftUrl.isNotEmpty ? giftUrl : effectiveGiftId;
      final localSvga = SvgaParserUtil.getLocalGiftSvgaPath(lookupKey, giftId: effectiveGiftId, giftName: giftName);
      final localVap = SvgaParserUtil.getLocalVapPath(lookupKey, giftId: effectiveGiftId, giftName: giftName);
      final localLottie = SvgaParserUtil.getLocalLottiePath(lookupKey, giftId: effectiveGiftId, giftName: giftName);

      if (localSvga != null) {
        format = 'svga';
        giftUrl = localSvga;
      } else if (localVap != null) {
        format = 'vap';
        giftUrl = localVap;
      } else if (localLottie != null) {
        if (format.isEmpty) format = 'json';
        giftUrl = localLottie;
      }

      // 3. Authoritative inference of format (file extension in URL overrides stale 'json' tag)
      final lower = giftUrl.toLowerCase();
      if (localSvga != null || lower.contains('.svga') || format == 'svga') {
        format = 'svga';
      } else if (localVap != null || lower.contains('.vap') || lower.contains('.vpa') || lower.contains('.mp4') || lower.contains('.pag') || format == 'vap' || format == 'mp4') {
        format = 'vap';
      } else if (lower.contains('.png') || lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.webp') || lower.contains('.gif') || format == 'image') {
        format = 'image';
      } else if (format.isEmpty) {
        format = 'json';
      }

      // 4. Fallback URL
      if (giftUrl.isEmpty) {
        giftUrl = imageUrl ?? '🎁';
      }

      // 5. Derive tier
      if (tier.isEmpty) {
        final c = category.trim().toUpperCase();
        if (c == 'MEDIUM' || c == 'SVGA' || c == 'VAP') {
          tier = 'MEDIUM';
        } else if (c == 'LUXURY' || c == 'SPECIAL') {
          tier = 'LUXURY';
        } else {
          tier = 'NORMAL';
        }
      }

      // Feed combo controller with authoritative cover image
      combos.applyRemote(msg, giftIconUrl: imageUrl ?? matched?.imageUrl ?? giftUrl);

      final qty = msg.quantity > 0 ? msg.quantity : 1;
      final playCount = qty > 10 ? 10 : qty;
      final targetUid = msg.targetUid.trim();

      if (tier == 'NORMAL') {
        for (int i = 0; i < playCount; i++) {
          final animId = "${msg.msgId}_${targetUid}_$i";
          final anim = _ActiveGiftAnimation(
            id: animId,
            url: giftUrl,
            senderUid: msg.uid,
            text: msg.text,
            imageUrl: imageUrl,
            soundUrl: soundUrl,
            format: format,
            giftCategory: category,
            giftName: giftName,
            tier: tier,
            durationMs: durationMs,
            targetUid: targetUid.isNotEmpty ? targetUid : null,
          );
          _enqueueSeatAnimation(targetUid, anim);
        }
      } else {
        for (int i = 0; i < playCount; i++) {
          final anim = _ActiveGiftAnimation(
            id: "${msg.msgId}_$i",
            url: giftUrl,
            senderUid: msg.uid,
            text: msg.text,
            imageUrl: imageUrl,
            soundUrl: soundUrl,
            format: format,
            giftCategory: category,
            giftName: giftName,
            tier: tier,
            durationMs: durationMs,
            targetUid: targetUid.isNotEmpty ? targetUid : null,
          );
          
          if (_pendingQueue.length < 50) {
            _pendingQueue.add(anim);
            changed = true;
          }
        }
      }
    }

    if (_processedMessageIds.length > 500) {
      _processedMessageIds.removeAll(_processedMessageIds.take(_processedMessageIds.length - 250).toList());
    }

    if (changed && mounted) {
      _triggerNextAnimation();
    }
  }

  void _triggerNextAnimation() {
    if (_isPlaying || _pendingQueue.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isPlaying = true;
      _currentAnimation = _pendingQueue.removeAt(0);
    });
    _scheduleSafetyFallback();
  }

  void _scheduleSafetyFallback() {
    // Safety fallback: force complete ONLY if onComplete never fires. The floor
    // is kept above every inner player's own watchdog (SVGA ~14s, VAP ~12s) so
    // it never cuts a clip that is still legitimately playing.
    final int animDuration = _currentAnimation?.durationMs ?? 0;
    final bool isLuxury = _currentAnimation?.tier == 'LUXURY';
    final int graceMs = math.max(
      animDuration + 4000,
      isLuxury ? 22000 : 20000,
    );
    _animationTimer?.cancel();
    _animationTimer = Timer(Duration(milliseconds: graceMs), () {
      if (_isPlaying && mounted) {
        debugPrint("[GiftCache] Safety fallback timer fired.");
        _onAnimationFinished();
      }
    });
  }

  void _onAnimationFinished() {
    if (!mounted) return;
    _animationTimer?.cancel();
    if (_pendingQueue.isNotEmpty) {
      // Transition immediately to next queued room animation without 1-frame blank gap
      setState(() {
        _isPlaying = true;
        _currentAnimation = _pendingQueue.removeAt(0);
      });
      _scheduleSafetyFallback();
    } else {
      setState(() {
        _currentAnimation = null;
        _isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    for (final sg in _currentSeatGifts.values) {
      sg.expiryTimer.cancel();
    }
    _currentSeatGifts.clear();
    _seatQueues.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(giftAnimationControllerProvider(widget.roomId), (previous, next) {
      final events = next.consumePendingEvents();
      if (events.isNotEmpty) {
        _handleLocalAnimationEvents(events);
      }
    });

    ref.listen(roomMessagesProvider(widget.roomId), (previous, next) {
      if (next.hasValue && next.value != null) {
        _handleMessages(next.value!);
      }
    });

    final overlayBox = _overlayKey.currentContext?.findRenderObject();
    final List<Widget> seatWidgets = [];

    for (final seatGift in _currentSeatGifts.values) {
      final targetKey = seatGift.targetUid.isNotEmpty ? seatGift.targetUid : '_unseated_';
      final seatRect = seatGift.targetUid.isNotEmpty
          ? SeatAnchors.rectFor(widget.roomId, seatGift.targetUid)
          : null;

      if (seatRect != null && overlayBox is RenderBox && overlayBox.attached && overlayBox.hasSize) {
        final localTopLeft = overlayBox.globalToLocal(seatRect.topLeft);
        const giftSize = 220.0;
        final avatarCenter = localTopLeft + Offset(seatRect.width / 2, seatRect.height * 0.25);
        seatWidgets.add(
          _SeatGiftFlight(
            key: ValueKey('seat_flight_${seatGift.id}'),
            from: overlayBox.size.center(Offset.zero),
            to: avatarCenter,
            size: giftSize,
            animateFlight: !seatGift.hasFlown,
            child: RepaintBoundary(
              key: ValueKey('seat_gift_boundary_${seatGift.id}'),
              child: IgnorePointer(
                key: ValueKey('seat_gift_${seatGift.id}'),
                child: _HeldGiftPlayer(
                  key: ValueKey(seatGift.id),
                  animation: seatGift.animation,
                  onComplete: () => _onSeatAnimationFinished(targetKey, seatGift.id),
                ),
              ),
            ),
          ),
        );
      } else {
        // Fallback: ALWAYS render centered in the room so the player is NEVER unmounted!
        const giftSize = 240.0;
        seatWidgets.add(
          Positioned.fill(
            key: ValueKey('seat_pos_${seatGift.id}'),
            child: RepaintBoundary(
              key: ValueKey('seat_gift_boundary_${seatGift.id}'),
              child: IgnorePointer(
                key: ValueKey('seat_gift_${seatGift.id}'),
                child: Center(
                  child: SizedBox(
                    width: giftSize,
                    height: giftSize,
                    child: _HeldGiftPlayer(
                      key: ValueKey(seatGift.id),
                      animation: seatGift.animation,
                      onComplete: () => _onSeatAnimationFinished(targetKey, seatGift.id),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      key: _overlayKey,
      children: [
        widget.child,
        // Layer 1 - NORMAL: Sequential queued seat gift animations (isolated in RepaintBoundary)
        ...seatWidgets,
        // Separate layer: Combo Overlay banner
        GiftComboOverlay(roomId: widget.roomId),
        // Layer 2 & 3: Medium & Luxury room animations
        if (_currentAnimation != null)
          _buildAnimationItem(_currentAnimation!),
      ],
    );
  }

  Widget _buildAnimationItem(_ActiveGiftAnimation anim) {
    // MEDIUM/LUXURY get a hold wrapper: gift-icon base always visible,
    // Lottie loops until hold expires, audio gets full time before dispose.
    final player = RepaintBoundary(
      key: ValueKey('room_anim_boundary_${anim.id}'),
      child: IgnorePointer(
        key: ValueKey(anim.id),
        child: _HeldRoomPlayer(
          key: ValueKey(anim.id),
          animation: anim,
          onComplete: _onAnimationFinished,
        ),
      ),
    );

    // Layer 2 - MEDIUM: centered in the middle of the room.
    if (anim.tier == 'MEDIUM') {
      return Positioned.fill(
        child: Center(
          child: SizedBox(
            width: 360,
            height: 360,
            child: player,
          ),
        ),
      );
    }

    // Layer 3 - LUXURY (and fallback): full-screen room cinematic.
    return Positioned.fill(
      child: player,
    );
  }
}

/// Flies a seat gift from the overlay center to the receiver's seat anchor.
/// Animates Positioned left/top (layout) rather than Transform, so native
/// VAP platform views are not blanked mid-flight on Android.
class _SeatGiftFlight extends StatefulWidget {
  final Offset from;
  final Offset to;
  final double size;
  final Widget child;
  final bool animateFlight;

  const _SeatGiftFlight({
    super.key,
    required this.from,
    required this.to,
    required this.size,
    required this.child,
    this.animateFlight = true,
  });

  @override
  State<_SeatGiftFlight> createState() => _SeatGiftFlightState();
}

class _SeatGiftFlightState extends State<_SeatGiftFlight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animateFlight ? 550 : 0),
    );
    _position = Tween<Offset>(
      begin: widget.animateFlight ? widget.from : widget.to,
      end: widget.to,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animateFlight) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animateFlight) {
      final center = widget.to;
      return Positioned(
        left: center.dx - widget.size / 2,
        top: center.dy - widget.size / 2,
        width: widget.size,
        height: widget.size,
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final center = _position.value;
        return Positioned(
          left: center.dx - widget.size / 2,
          top: center.dy - widget.size / 2,
          width: widget.size,
          height: widget.size,
          child: widget.child,
        );
      },
    );
  }
}

class _ActiveGiftAnimation {
  final String id;
  final String url;
  final String senderUid;
  final String text;
  final String? imageUrl;
  final String? soundUrl;
  final String format;
  final String giftCategory;
  final String giftName;
  final String? targetUid;

  /// NORMAL | MEDIUM | LUXURY - which overlay layer this plays on.
  final String tier;

  /// 0 = asset/default derived duration.
  final int durationMs;

  _ActiveGiftAnimation({
    required this.id, 
    required this.url,
    required this.senderUid,
    required this.text,
    this.imageUrl,
    this.soundUrl,
    this.format = 'json',
    this.giftCategory = 'Normal',
    this.giftName = '',
    this.targetUid,
    this.tier = 'NORMAL',
    this.durationMs = 0,
  });
}

class _ActiveSeatGift {
  final String id;
  final String targetUid;
  final _ActiveGiftAnimation animation;
  final Timer expiryTimer;
  final bool hasFlown;

  _ActiveSeatGift({
    required this.id,
    required this.targetUid,
    required this.animation,
    required this.expiryTimer,
    this.hasFlown = false,
  });
}

/// Seat-anchored NORMAL gift player: golden aura + elastic bounce + minimum
/// on-screen hold so short Lottie/SVGA clips are always perceivable.
class _HeldGiftPlayer extends StatefulWidget {
  final _ActiveGiftAnimation animation;
  final VoidCallback onComplete;

  const _HeldGiftPlayer({
    super.key,
    required this.animation,
    required this.onComplete,
  });

  @override
  State<_HeldGiftPlayer> createState() => _HeldGiftPlayerState();
}

class _HeldGiftPlayerState extends State<_HeldGiftPlayer> {
  static const int kMinHoldMs = 2500;
  /// Last-resort cap if a player never reports completion. Kept generous so it
  /// never preempts a clip that is still legitimately playing (NORMAL gifts are
  /// held until the inner player's own onComplete fires).
  static const int kSafetyCapMs = 20000;
  Timer? _holdTimer;
  Timer? _safetyTimer;
  bool _released = false;
  bool _holdElapsed = false;
  bool _innerDone = false;

  @override
  void initState() {
    super.initState();
    final int hold = math.max(widget.animation.durationMs, kMinHoldMs);
    _holdTimer = Timer(Duration(milliseconds: hold), () {
      _holdElapsed = true;
      _tryRelease();
    });
    _safetyTimer = Timer(const Duration(milliseconds: kSafetyCapMs), _release);
  }

  void _release() {
    if (_released || !mounted) return;
    _released = true;
    _holdTimer?.cancel();
    _safetyTimer?.cancel();
    widget.onComplete();
  }

  /// Release only when the minimum hold has elapsed AND the inner player
  /// finished — so long assets play fully instead of being cut at the hold.
  void _tryRelease() {
    if (_holdElapsed && _innerDone) _release();
  }

  void _onInnerComplete() {
    _innerDone = true;
    _tryRelease();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // VAP/SVGA are native platform views — any Flutter Transform/Opacity on
    // them blanks the content on Android. Only the real animation (plus a soft
    // aura) renders; no static gift cover/icon is drawn first.
    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft aura (isolated in RepaintBoundary so continuous ticks don't repaint the player)
        RepaintBoundary(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFD700).withValues(alpha: 0.35),
                  const Color(0xFFFF8C00).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                stops: const [0.15, 0.50, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.15, 1.15),
                duration: 900.ms,
                curve: Curves.easeInOut,
              ),
        ),

        // Animation player on top — isolated in RepaintBoundary
        SizedBox(
          width: 200,
          height: 200,
          child: RepaintBoundary(
            child: _GiftAnimationPlayer(
              key: ValueKey('held_${widget.animation.id}'),
              animation: widget.animation,
              onComplete: _onInnerComplete,
            ),
          ),
        ),
      ],
    );
  }
}

/// Room-level MEDIUM/LUXURY gift player: hold timer controls release so
/// Lottie loops + audio get full play time before dismiss.
class _HeldRoomPlayer extends StatefulWidget {
  final _ActiveGiftAnimation animation;
  final VoidCallback onComplete;

  const _HeldRoomPlayer({
    super.key,
    required this.animation,
    required this.onComplete,
  });

  @override
  State<_HeldRoomPlayer> createState() => _HeldRoomPlayerState();
}

class _HeldRoomPlayerState extends State<_HeldRoomPlayer> {
  Timer? _holdTimer;
  Timer? _maxLifeTimer;
  bool _released = false;
  bool _holdStarted = false;
  bool _holdElapsed = false;
  bool _innerDone = false;

  int get _minHoldMs {
    final int declared = widget.animation.durationMs > 0 ? widget.animation.durationMs : 0;
    final int tierDefault = widget.animation.tier == 'LUXURY' ? 7000 : 5000;
    return math.max(declared, tierDefault);
  }

  @override
  void initState() {
    super.initState();
    _startHold();
  }

  void _onPlayerStarted() {
    // If format player starts after async load, refresh hold so user sees full animation
    if (!_released && mounted) {
      _startHold(forceReset: true);
    }
  }

  void _startHold({bool forceReset = false}) {
    if (_released || !mounted) return;
    if (_holdStarted && !forceReset) return;
    _holdStarted = true;
    _holdTimer?.cancel();
    _maxLifeTimer?.cancel();
    _holdTimer = Timer(Duration(milliseconds: _minHoldMs), () {
      _holdElapsed = true;
      _tryRelease();
    });
    // Absolute last-resort cap so an inner player that never reports
    // completion can't wedge the global medium/luxury queue. Kept well past the
    // inner players' own watchdogs so it never cuts a still-playing animation
    // short (release is normally driven by _innerDone from the real onComplete).
    _maxLifeTimer = Timer(
      Duration(milliseconds: math.max(_minHoldMs + 4000, 20000)),
      _release,
    );
  }

  /// Release when the hold elapsed AND the inner player finished —
  /// compositions longer than the tier default play fully instead of
  /// being cut at the hold boundary.
  void _tryRelease() {
    if (_holdElapsed && _innerDone) _release();
  }

  void _onInnerComplete() {
    _innerDone = true;
    _tryRelease();
  }

  void _release() {
    if (_released || !mounted) return;
    _released = true;
    _holdTimer?.cancel();
    _maxLifeTimer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _maxLifeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GiftAnimationPlayer(
      key: ValueKey('room_${widget.animation.id}'),
      animation: widget.animation,
      holdMs: _minHoldMs,
      onStart: _onPlayerStarted,
      onComplete: _onInnerComplete,
    );
  }
}

class _GiftAnimationPlayer extends StatefulWidget {
  final _ActiveGiftAnimation animation;
  final VoidCallback onComplete;
  /// If > 0, Lottie plays until this hold expires (so short compositions stay visible).
  final int holdMs;
  /// Fired once when the format player actually starts rendering/playing,
  /// so hold timers can begin after async load instead of during it.
  final VoidCallback? onStart;

  const _GiftAnimationPlayer({
    super.key,
    required this.animation,
    required this.onComplete,
    this.holdMs = 0,
    this.onStart,
  });

  @override
  State<_GiftAnimationPlayer> createState() => _GiftAnimationPlayerState();
}

class _GiftAnimationPlayerState extends State<_GiftAnimationPlayer> {
  bool _hasError = false;
  AudioPlayer? _audioPlayer;
  bool _isDisposed = false;
  Timer? _audioHoldTimer;

  @override
  void initState() {
    super.initState();
    _playSound();
  }

  void _playSound() async {
    final soundUrl = widget.animation.soundUrl?.trim() ?? '';
    if (soundUrl.isNotEmpty) {
      try {
        _audioPlayer = AudioPlayer();
        await _audioPlayer?.setVolume(1.0);
        if (_isDisposed) return;
        if (soundUrl.startsWith('http')) {
          await _audioPlayer?.play(UrlSource(soundUrl));
        } else if (soundUrl.startsWith('assets/')) {
          await _audioPlayer?.play(AssetSource(soundUrl.replaceFirst('assets/', '')));
        }
        // When holdMs is set (luxury/medium), ensure audio gets full play time.
        // If audio is shorter than hold, dispose already stopped it. If audio is longer,
        // hold timer keeps player alive until hold expires then dispose stops audio.
        if (widget.holdMs > 0) {
          _audioHoldTimer?.cancel();
          _audioHoldTimer = Timer(Duration(milliseconds: widget.holdMs + 500), () {
            // Extra grace so audio can finish after hold expires.
          });
        }
      } catch (e) {
        debugPrint("[GiftAudio] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioHoldTimer?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _handleError() {
    if (mounted && !_isDisposed) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _FallbackImagePlayer(
        key: ValueKey('${widget.animation.id}_fallback'),
        imageUrl: widget.animation.imageUrl,
        onComplete: widget.onComplete,
      );
    }

    final url = widget.animation.url.trim();
    final lowerUrl = url.toLowerCase();
    final fmt = widget.animation.format.toLowerCase();
    final hasCustomSound = widget.animation.soundUrl?.trim().isNotEmpty ?? false;

    // Build the format-specific player.
    Widget player = _buildFormatPlayer(url, lowerUrl, fmt, hasCustomSound);

    // When holdMs > 0 (luxury/medium), show a soft aura behind the player so
    // the animation is never framed against a blank canvas. No static gift
    // cover icon is drawn first — only the real SVGA/VAP/Lottie plays.
    if (widget.holdMs > 0) {
      final bool isLuxury = widget.animation.tier == 'LUXURY';
      return Stack(
        alignment: Alignment.center,
        children: [
          // Soft aura behind everything (isolated in RepaintBoundary)
          RepaintBoundary(
            child: Container(
              width: isLuxury ? 320 : 240,
              height: isLuxury ? 320 : 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.35),
                    const Color(0xFFFF8C00).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.15, 0.50, 1.0],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.15, 1.15),
                  duration: 900.ms,
                  curve: Curves.easeInOut,
                ),
          ),
          // Animation player on top — no Transform/Opacity on this subtree.
          player,
        ],
      );
    }

    return player;
  }

  Widget _buildFormatPlayer(String url, String lowerUrl, String fmt, bool hasCustomSound) {
    final VoidCallback? onStart = widget.onStart;
    final giftName = widget.animation.giftName;

    // 1. SVGA Animation Format
    if (lowerUrl.contains('.svga') || fmt == 'svga') {
      final localPath = SvgaParserUtil.getLocalGiftSvgaPath(url, giftName: giftName);
      if (localPath != null || url.startsWith('assets/')) {
        return _SvgaLocalPlayer(
          key: ValueKey('${widget.animation.id}_svga_local'),
          assetPath: localPath ?? url,
          hasCustomSound: hasCustomSound,
          holdMs: widget.holdMs,
          onComplete: widget.onComplete,
          onError: _handleError,
          onStart: onStart,
        );
      }
      return _SvgaNetworkPlayer(
        key: ValueKey('${widget.animation.id}_svga_net'),
        url: url,
        hasCustomSound: hasCustomSound,
        holdMs: widget.holdMs,
        onComplete: widget.onComplete,
        onError: _handleError,
        onStart: onStart,
      );
    }

    // 2. VAP / VPA / MP4 / PAG alpha-video format.
    if (lowerUrl.contains('.vap') ||
        lowerUrl.contains('.vpa') ||
        lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.pag') ||
        fmt == 'vap' ||
        fmt == 'vpa' ||
        fmt == 'mp4' ||
        fmt == 'pag') {
      final localVap = SvgaParserUtil.getLocalVapPath(url, giftName: giftName);
      return _VapNetworkPlayer(
        key: ValueKey('${widget.animation.id}_vap'),
        url: localVap ?? url,
        durationMs: widget.animation.durationMs > 0 ? widget.animation.durationMs : widget.holdMs,
        holdMs: widget.holdMs,
        onComplete: widget.onComplete,
        onError: _handleError,
        onStart: onStart,
      );
    }

    // 3. Static / Animated Image Format (PNG, JPG, WEBP, GIF)
    if (lowerUrl.contains('.png') || lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg') || lowerUrl.contains('.gif') || lowerUrl.contains('.webp') || fmt == 'image') {
      return _ImageGiftPlayer(
        key: ValueKey('${widget.animation.id}_image'),
        imageUrl: url.isNotEmpty ? url : (widget.animation.imageUrl ?? ''),
        durationMs: widget.animation.durationMs,
        onComplete: widget.onComplete,
        onStart: onStart,
      );
    }

    // 4. Lottie JSON Format (Default)
    final localLottiePath = SvgaParserUtil.getLocalLottiePath(url, giftName: giftName);
    if (localLottiePath != null || (url.startsWith('assets/') && (url.endsWith('.json') || fmt == 'json'))) {
      return _LottieLocalPlayer(
        key: ValueKey('${widget.animation.id}_lottie_local'),
        assetPath: localLottiePath ?? url,
        originalUrl: url,
        hasCustomSound: hasCustomSound,
        holdMs: widget.holdMs,
        onComplete: widget.onComplete,
        onError: _handleError,
        onStart: onStart,
      );
    }

    if (url.startsWith('http')) {
      return _LottieNetworkPlayer(
        key: ValueKey('${widget.animation.id}_lottie_net'),
        url: url,
        hasCustomSound: hasCustomSound,
        holdMs: widget.holdMs,
        onComplete: widget.onComplete,
        onError: _handleError,
        onStart: onStart,
      );
    }

    return _FallbackImagePlayer(
      key: ValueKey('${widget.animation.id}_fallback'),
      imageUrl: widget.animation.imageUrl,
      onComplete: widget.onComplete,
      onStart: onStart,
    );
  }
}

class _VapNetworkPlayer extends StatefulWidget {
  final String url;
  final int durationMs;
  /// If > 0, hold player alive for at least this long (luxury/medium full duration).
  final int holdMs;
  final VoidCallback onComplete;
  final VoidCallback onError;
  final VoidCallback? onStart;

  const _VapNetworkPlayer({
    super.key,
    required this.url,
    required this.durationMs,
    this.holdMs = 0,
    required this.onComplete,
    required this.onError,
    this.onStart,
  });

  @override
  State<_VapNetworkPlayer> createState() => _VapNetworkPlayerState();
}

class _VapNetworkPlayerState extends State<_VapNetworkPlayer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Startup budget: network download + native handler registration.
    final int startupMs = math.max(widget.holdMs, 15000);
    _timer = Timer(Duration(milliseconds: startupMs), widget.onComplete);
  }

  void _onStart() {
    widget.onStart?.call();
    _timer?.cancel();
    // duration_ms (when set) wins, with a 3s grace so it never cuts off a
    // video whose own onComplete is about to fire. holdMs ensures luxury holds full duration.
    final int base = widget.durationMs > 0 ? widget.durationMs + 3000 : 12000;
    final int ms = math.max(math.max(base, 12000), widget.holdMs > 0 ? widget.holdMs : 0);
    _timer = Timer(Duration(milliseconds: ms), widget.onComplete);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: VapAnimation(
        key: ValueKey('vap_anim_${widget.key ?? widget.url}_${widget.durationMs}_${widget.holdMs}'),
        assetPath: widget.url,
        onComplete: widget.onComplete,
        onError: widget.onError,
        onStart: _onStart,
      ),
    );
  }
}

class _ImageGiftPlayer extends StatefulWidget {
  final String imageUrl;
  final int durationMs;
  final VoidCallback onComplete;
  final VoidCallback? onStart;

  const _ImageGiftPlayer({
    super.key,
    required this.imageUrl,
    required this.durationMs,
    required this.onComplete,
    this.onStart,
  });

  @override
  State<_ImageGiftPlayer> createState() => _ImageGiftPlayerState();
}

class _ImageGiftPlayerState extends State<_ImageGiftPlayer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.onStart?.call();
    final int ms = widget.durationMs > 0 ? widget.durationMs : 3200;
    _timer = Timer(Duration(milliseconds: ms), widget.onComplete);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = widget.imageUrl.trim();
    if (imgUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final int ms = widget.durationMs > 0 ? widget.durationMs : 3200;
    final int fadeOutDelay = math.max(ms - 500, 1800);

    Widget imageContent;
    if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
      imageContent = CachedNetworkImage(
        imageUrl: imgUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox(),
        errorWidget: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.amber, size: 52),
      );
    } else if (imgUrl.startsWith('assets/')) {
      imageContent = Image.asset(
        imgUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.amber, size: 52),
      );
    } else {
      imageContent = const Icon(Icons.card_giftcard, color: Colors.amber, size: 52);
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Radiant glowing aura behind the gift
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFD700).withOpacity(0.65),
                  const Color(0xFFFF8C00).withOpacity(0.35),
                  Colors.transparent,
                ],
                stops: const [0.25, 0.65, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.15, 1.15),
                duration: 900.ms,
                curve: Curves.easeInOut,
              ),

          // 2. Floating sparkles / stars around gift
          Positioned(
            top: 6,
            right: 12,
            child: const Icon(Icons.auto_awesome, color: Color(0xFFFFEB3B), size: 18)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.6, 0.6), end: const Offset(1.2, 1.2), duration: 600.ms)
                .rotate(begin: 0, end: 0.25, duration: 800.ms),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: const Icon(Icons.star, color: Color(0xFFFFD700), size: 14)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.1, 1.1), duration: 700.ms),
          ),

          // 3. Main gift icon with spring entrance, gentle floating bob, and dissolve
          SizedBox(
            width: 82,
            height: 82,
            child: imageContent,
          )
              .animate()
              .scale(
                begin: const Offset(0.2, 0.2),
                end: const Offset(1.08, 1.08),
                duration: 450.ms,
                curve: Curves.elasticOut,
              )
              .then()
              .scale(
                begin: const Offset(1.08, 1.08),
                end: const Offset(1.0, 1.0),
                duration: 200.ms,
              )
              .then()
              .moveY(
                begin: 0,
                end: -8,
                duration: 1000.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(
                duration: 1200.ms,
                color: Colors.white.withOpacity(0.5),
              )
              .then(delay: Duration(milliseconds: fadeOutDelay))
              .fadeOut(duration: 400.ms),
        ],
      ),
    );
  }
}

class _SvgaLocalPlayer extends StatefulWidget {
  final String assetPath;
  final bool hasCustomSound;
  /// If > 0, hold player alive for at least this long (luxury/medium full duration).
  final int holdMs;
  final VoidCallback onComplete;
  final VoidCallback onError;
  final VoidCallback? onStart;
  const _SvgaLocalPlayer({
    super.key,
    required this.assetPath,
    this.hasCustomSound = false,
    this.holdMs = 0,
    required this.onComplete,
    required this.onError,
    this.onStart,
  });

  @override
  State<_SvgaLocalPlayer> createState() => _SvgaLocalPlayerState();
}

class _SvgaLocalPlayerState extends State<_SvgaLocalPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;
  bool _isDisposed = false;
  Timer? _completeTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Timer> _audioTimers = [];

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    // Instant frame-0 start if the MovieEntity was already pre-decoded in memory
    final cachedMovie = SvgaParserUtil.getCachedMovie(widget.assetPath);
    if (cachedMovie != null) {
      _controller?.videoItem = cachedMovie;
      _isLoading = false;
      _controller?.forward(from: 0.0).whenComplete(() {
        if (!_isDisposed && mounted) {
          debugPrint("[SVGAPlayer] Local SVGA controller finished forward pass.");
          _completeTimer?.cancel();
          widget.onComplete();
        }
      });
      widget.onStart?.call();
      final cachedAudios = SvgaParserUtil.getCachedPreparedAudios(widget.assetPath);
      if (cachedAudios != null && !widget.hasCustomSound) {
        _playPreparedAudios(cachedAudios);
      }
      _scheduleWatchdog(cachedMovie);
    } else {
      _loadAnimation();
    }
  }

  void _scheduleWatchdog(dynamic videoItem) {
    int frames = 0;
    int fps = 0;
    try {
      final dynamic v = videoItem;
      if (v.params != null) {
        frames = v.params.frames ?? 0;
        fps = v.params.fps ?? 0;
      } else if (v.frames != null) {
        frames = v.frames ?? 0;
        fps = v.fps ?? 0;
      }
    } catch (_) {}

    final int effectiveFps = fps > 0 ? fps : 30;
    final int durationMs = (_controller?.duration != null && _controller!.duration!.inMilliseconds > 0)
        ? _controller!.duration!.inMilliseconds
        : ((frames > 0 && effectiveFps > 0)
            ? ((frames / effectiveFps) * 1000).toInt()
            : 8500);

    final int watchdogMs = math.max(
      math.max(durationMs + 3500, 14000),
      widget.holdMs > 0 ? widget.holdMs + 2000 : 0,
    );
    _completeTimer?.cancel();
    _completeTimer = Timer(Duration(milliseconds: watchdogMs), () {
      if (!_isDisposed && mounted) {
        debugPrint("[SVGAPlayer] Safety watchdog timer fired after ${watchdogMs}ms for ${widget.assetPath}");
        widget.onComplete();
      }
    });
  }

  void _loadAnimation() async {
    try {
      final videoItem = await SvgaParserUtil.decodeSafeFromAssets(widget.assetPath);
      if (_isDisposed || !mounted) return;

      int fps = 0;
      try {
        final dynamic v = videoItem;
        if (v.params != null) {
          fps = v.params.fps ?? 0;
        } else if (v.frames != null) {
          fps = v.fps ?? 0;
        }
      } catch (e) {
        debugPrint("[SVGAPlayer] Failed to get SVGA fps: $e");
      }

      final int effectiveFps = fps > 0 ? fps : 30;

      // Pre-extract audios BEFORE starting video so audio and video start in 100% lockstep
      final preparedAudios = widget.hasCustomSound
          ? <PreparedSvgaAudio>[]
          : await SvgaParserUtil.getPreparedAudios(videoItem, widget.assetPath, effectiveFps);

      if (_isDisposed || !mounted) return;

      setState(() {
        _controller?.videoItem = videoItem;
        _isLoading = false;
        _controller?.forward(from: 0.0).whenComplete(() {
          if (!_isDisposed && mounted) {
            debugPrint("[SVGAPlayer] Local SVGA controller finished forward pass.");
            _completeTimer?.cancel();
            widget.onComplete();
          }
        });
      });
      widget.onStart?.call();

      _playPreparedAudios(preparedAudios);
      _scheduleWatchdog(videoItem);
    } catch (e) {
      debugPrint("Error parsing local SVGA: $e");
      if (!_isDisposed && mounted) {
        widget.onError();
      }
    }
  }

  void _playPreparedAudios(List<PreparedSvgaAudio> preparedAudios) {
    if (widget.hasCustomSound || preparedAudios.isEmpty) return;
    debugPrint("[SVGAPlayer] Playing ${preparedAudios.length} embedded audio track(s) for ${widget.assetPath}");
    for (final audio in preparedAudios) {
      if (audio.delayMs > 0) {
        final timer = Timer(Duration(milliseconds: audio.delayMs), () async {
          if (!_isDisposed && mounted) {
            try {
              debugPrint("[SVGAPlayer] Playing delayed SVGA audio (${audio.delayMs}ms): ${audio.file.path}");
              await _audioPlayer.setVolume(1.0);
              await _audioPlayer.play(DeviceFileSource(audio.file.path), volume: 1.0);
            } catch (ae) {
              debugPrint("[SVGAPlayer] Error playing SVGA audio: $ae");
            }
          }
        });
        _audioTimers.add(timer);
      } else {
        try {
          debugPrint("[SVGAPlayer] Playing immediate SVGA audio: ${audio.file.path}");
          _audioPlayer.setVolume(1.0);
          _audioPlayer.play(DeviceFileSource(audio.file.path), volume: 1.0);
        } catch (ae) {
          debugPrint("[SVGAPlayer] Error playing SVGA audio: $ae");
        }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _completeTimer?.cancel();
    for (final timer in _audioTimers) {
      timer.cancel();
    }
    _audioTimers.clear();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _controller?.videoItem == null) {
      return const SizedBox.shrink();
    }
    return SVGAImage(
      _controller!,
      fit: BoxFit.contain,
    );
  }
}

class _FallbackImagePlayer extends StatefulWidget {
  final String? imageUrl;
  final VoidCallback onComplete;
  final VoidCallback? onStart;
  const _FallbackImagePlayer({
    super.key,
    required this.imageUrl,
    required this.onComplete,
    this.onStart,
  });

  @override
  State<_FallbackImagePlayer> createState() => _FallbackImagePlayerState();
}

class _FallbackImagePlayerState extends State<_FallbackImagePlayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    widget.onStart?.call();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.2).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.8).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _rotationAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.imageUrl ?? '';
    final isUrl = img.startsWith('http');

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD700).withOpacity(0.6),
                      const Color(0xFFFF8C00).withOpacity(0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(_controller.value * 0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: isUrl
                      ? CachedNetworkImage(
                          imageUrl: img,
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.card_giftcard,
                            color: Color(0xFFFFD700),
                            size: 80,
                          ),
                        )
                      : Text(
                          img.isNotEmpty ? img : '🎁',
                          style: const TextStyle(fontSize: 80),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SvgaNetworkPlayer extends StatefulWidget {
  final String url;
  final bool hasCustomSound;
  /// If > 0, hold player alive for at least this long (luxury/medium full duration).
  final int holdMs;
  final VoidCallback onComplete;
  final VoidCallback onError;
  final VoidCallback? onStart;
  const _SvgaNetworkPlayer({
    super.key,
    required this.url,
    this.hasCustomSound = false,
    this.holdMs = 0,
    required this.onComplete,
    required this.onError,
    this.onStart,
  });

  @override
  State<_SvgaNetworkPlayer> createState() => _SvgaNetworkPlayerState();
}

class _SvgaNetworkPlayerState extends State<_SvgaNetworkPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;
  bool _isDisposed = false;
  Timer? _completeTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Timer> _audioTimers = [];

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    final localPath = SvgaParserUtil.getLocalGiftSvgaPath(widget.url);
    final cachedMovie = localPath != null
        ? SvgaParserUtil.getCachedMovie(localPath)
        : SvgaParserUtil.getCachedMovie(widget.url);
    if (cachedMovie != null) {
      _controller?.videoItem = cachedMovie;
      _isLoading = false;
      _controller?.forward(from: 0.0).whenComplete(() {
        if (!_isDisposed && mounted) {
          debugPrint("[SVGAPlayer] Network SVGA controller finished forward pass.");
          _completeTimer?.cancel();
          widget.onComplete();
        }
      });
      widget.onStart?.call();
      final key = localPath ?? widget.url;
      final cachedAudios = SvgaParserUtil.getCachedPreparedAudios(key);
      if (cachedAudios != null && !widget.hasCustomSound) {
        _playPreparedAudios(cachedAudios);
      }
      _scheduleWatchdog(cachedMovie);
    } else {
      _loadAnimation();
    }
  }

  void _scheduleWatchdog(dynamic videoItem) {
    int frames = 0;
    int fps = 0;
    try {
      final dynamic v = videoItem;
      if (v.params != null) {
        frames = v.params.frames ?? 0;
        fps = v.params.fps ?? 0;
      } else if (v.frames != null) {
        frames = v.frames ?? 0;
        fps = v.fps ?? 0;
      }
    } catch (_) {}

    final int effectiveFps = fps > 0 ? fps : 30;
    final int durationMs = (_controller?.duration != null && _controller!.duration!.inMilliseconds > 0)
        ? _controller!.duration!.inMilliseconds
        : ((frames > 0 && effectiveFps > 0)
            ? ((frames / effectiveFps) * 1000).toInt()
            : 8500);

    final int watchdogMs = math.max(
      math.max(durationMs + 3500, 14000),
      widget.holdMs > 0 ? widget.holdMs + 2000 : 0,
    );
    _completeTimer?.cancel();
    _completeTimer = Timer(Duration(milliseconds: watchdogMs), () {
      if (!_isDisposed && mounted) {
        debugPrint("[SVGAPlayer] Safety watchdog timer fired after ${watchdogMs}ms for ${widget.url}");
        widget.onComplete();
      }
    });
  }

  void _loadAnimation() async {
    try {
      final videoItem = await SvgaCache.load(widget.url);
      if (_isDisposed || !mounted) return;

      int frames = 0;
      int fps = 0;
      try {
        final dynamic v = videoItem;
        if (v.params != null) {
          frames = v.params.frames ?? 0;
          fps = v.params.fps ?? 0;
        } else if (v.frames != null) {
          frames = v.frames ?? 0;
          fps = v.fps ?? 0;
        }
      } catch (e) {
        debugPrint("[SVGAPlayer] Failed to get SVGA frames/fps from params: $e");
      }

      final int effectiveFps = fps > 0 ? fps : 30;

      // Pre-extract audios BEFORE starting video so audio and video start in 100% lockstep
      final preparedAudios = widget.hasCustomSound
          ? <PreparedSvgaAudio>[]
          : await SvgaParserUtil.getPreparedAudios(videoItem, widget.url, effectiveFps);

      if (_isDisposed || !mounted) return;

      setState(() {
        _controller?.videoItem = videoItem;
        _isLoading = false;
        _controller?.forward(from: 0.0).whenComplete(() {
          if (!_isDisposed && mounted) {
            debugPrint("[SVGAPlayer] Network SVGA controller finished forward pass.");
            _completeTimer?.cancel();
            widget.onComplete();
          }
        });
      });
      widget.onStart?.call();

      _playPreparedAudios(preparedAudios);

      final int durationMs = (_controller?.duration != null && _controller!.duration!.inMilliseconds > 0)
          ? _controller!.duration!.inMilliseconds
          : ((frames > 0 && effectiveFps > 0)
              ? ((frames / effectiveFps) * 1000).toInt()
              : 8500);

      debugPrint("[SVGAPlayer] Playing SVGA: ${widget.url} for duration: ${durationMs}ms (frames: $frames, fps: $effectiveFps, audios: ${preparedAudios.length})");

      final int watchdogMs = math.max(
        math.max(durationMs + 3500, 14000),
        widget.holdMs > 0 ? widget.holdMs + 2000 : 0,
      );
      _completeTimer?.cancel();
      _completeTimer = Timer(Duration(milliseconds: watchdogMs), () {
        if (!_isDisposed && mounted) {
          debugPrint("[SVGAPlayer] Safety watchdog timer fired after ${watchdogMs}ms for ${widget.url}");
          widget.onComplete();
        }
      });
    } catch (e) {
      debugPrint("Error parsing network SVGA: $e");
      if (!_isDisposed && mounted) {
        widget.onError();
      }
    }
  }

  void _playPreparedAudios(List<PreparedSvgaAudio> preparedAudios) {
    if (widget.hasCustomSound || preparedAudios.isEmpty) return;
    debugPrint("[SVGAPlayer] Playing ${preparedAudios.length} embedded audio track(s) for network SVGA: ${widget.url}");
    for (final audio in preparedAudios) {
      if (audio.delayMs > 0) {
        final timer = Timer(Duration(milliseconds: audio.delayMs), () async {
          if (!_isDisposed && mounted) {
            try {
              debugPrint("[SVGAPlayer] Playing delayed network SVGA audio (${audio.delayMs}ms): ${audio.file.path}");
              await _audioPlayer.setVolume(1.0);
              await _audioPlayer.play(DeviceFileSource(audio.file.path), volume: 1.0);
            } catch (ae) {
              debugPrint("[SVGAPlayer] Error playing SVGA audio: $ae");
            }
          }
        });
        _audioTimers.add(timer);
      } else {
        try {
          debugPrint("[SVGAPlayer] Playing immediate network SVGA audio: ${audio.file.path}");
          _audioPlayer.setVolume(1.0);
          _audioPlayer.play(DeviceFileSource(audio.file.path), volume: 1.0);
        } catch (ae) {
          debugPrint("[SVGAPlayer] Error playing SVGA audio: $ae");
        }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _completeTimer?.cancel();
    for (final timer in _audioTimers) {
      timer.cancel();
    }
    _audioTimers.clear();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _controller?.videoItem == null) {
      return const SizedBox.shrink();
    }
    return SVGAImage(
      _controller!,
      fit: BoxFit.contain,
    );
  }
}

class SvgaCache {
  static Future<dynamic> load(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) throw Exception("Empty URL");
    return await SvgaParserUtil.decodeSafeFromUrl(cleanUrl);
  }

  static void preload(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isNotEmpty) {
      SvgaParserUtil.decodeSafeFromUrl(cleanUrl).then((_) {
        debugPrint("[GiftCache] SVGA Preloaded and cached successfully: $url");
      }).catchError((e) {
        debugPrint("Background SVGA preloading failed for $url: $e");
      });
    }
  }
}

class LottieCache {
  static final Map<String, LottieComposition> _cache = {};
  static final Set<String> _loading = {};

  static LottieComposition? getCached(String keyOrPath) {
    return _cache[keyOrPath.trim()];
  }

  static Future<LottieComposition> load(String url) async {
    final cleanUrl = url.trim();
    if (_cache.containsKey(cleanUrl)) {
      return _cache[cleanUrl]!;
    }
    while (_loading.contains(cleanUrl)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_cache.containsKey(cleanUrl)) {
        return _cache[cleanUrl]!;
      }
    }
    
    _loading.add(cleanUrl);
    try {
      final file = await AppPersistentCache.getFile(cleanUrl);
      final composition = await FileLottie(file).load();
      _cache[cleanUrl] = composition;
      return composition;
    } finally {
      _loading.remove(cleanUrl);
    }
  }

  static void preload(String url) async {
    try {
      await load(url);
    } catch (e) {
      debugPrint("Background Lottie preloading failed for $url: $e");
    }
  }

  static Future<LottieComposition> loadLocal(String assetPath) async {
    final cleanPath = assetPath.trim();
    if (_cache.containsKey(cleanPath)) {
      return _cache[cleanPath]!;
    }
    while (_loading.contains(cleanPath)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_cache.containsKey(cleanPath)) {
        return _cache[cleanPath]!;
      }
    }
    
    _loading.add(cleanPath);
    try {
      final composition = await AssetLottie(cleanPath).load();
      _cache[cleanPath] = composition;
      return composition;
    } finally {
      _loading.remove(cleanPath);
    }
  }

  static void preloadLocal(String assetPath) async {
    try {
      await loadLocal(assetPath);
    } catch (e) {
      debugPrint("Background local Lottie preloading failed for $assetPath: $e");
    }
  }
}

class _LottieNetworkPlayer extends StatefulWidget {
  final String url;
  final bool hasCustomSound;
  /// If > 0, keep visible until this hold expires (so short compositions stay on screen).
  final int holdMs;
  final VoidCallback onComplete;
  final VoidCallback onError;
  final VoidCallback? onStart;
  const _LottieNetworkPlayer({
    super.key,
    required this.url,
    this.hasCustomSound = false,
    this.holdMs = 0,
    required this.onComplete,
    required this.onError,
    this.onStart,
  });

  @override
  State<_LottieNetworkPlayer> createState() => _LottieNetworkPlayerState();
}

class _LottieNetworkPlayerState extends State<_LottieNetworkPlayer> with SingleTickerProviderStateMixin {
  LottieComposition? _composition;
  bool _isLoading = true;
  bool _isDisposed = false;
  late final AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const Map<String, String> _lottieGiftSounds = {
    'rose': 'https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav',
    'balloon': 'https://assets.mixkit.co/active_storage/sfx/2019/2019-84.wav',
    'cake': 'https://assets.mixkit.co/active_storage/sfx/2017/2017-84.wav',
    'diamond': 'https://assets.mixkit.co/active_storage/sfx/2018/2018-84.wav',
    'cat': 'https://assets.mixkit.co/active_storage/sfx/2068/2068-84.wav',
    'crown': 'https://assets.mixkit.co/active_storage/sfx/2016/2016-84.wav',
    'gold': 'https://assets.mixkit.co/active_storage/sfx/2016/2016-84.wav',
    'celebration': 'https://assets.mixkit.co/active_storage/sfx/2020/2020-84.wav',
    'rocket': 'https://assets.mixkit.co/active_storage/sfx/2021/2021-84.wav',
    'car': 'https://assets.mixkit.co/active_storage/sfx/2022/2022-84.wav',
    'airplane': 'https://assets.mixkit.co/active_storage/sfx/2023/2023-84.wav',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _loadAnimation();
  }

  void _loadAnimation() async {
    try {
      final composition = await LottieCache.load(widget.url);
      if (_isDisposed || !mounted) return;
      setState(() {
        _composition = composition;
        _isLoading = false;
        _controller.duration = composition.duration;
        // Play once and freeze on the last frame. Repeating made short
        // compositions visibly restart mid-hold; the room player's hold
        // timer controls release instead.
        _controller.forward().whenComplete(() {
          if (!_isDisposed && mounted) {
            widget.onComplete();
          }
        });
      });
      widget.onStart?.call();
      _playGiftSound();
    } catch (e) {
      debugPrint("Error loading Lottie composition: $e");
      if (!_isDisposed && mounted) {
        widget.onError();
      }
    }
  }

  void _playGiftSound() async {
    if (widget.hasCustomSound) return;
    final lowerUrl = widget.url.toLowerCase();
    String? matchedSoundUrl;
    for (final entry in _lottieGiftSounds.entries) {
      if (lowerUrl.contains(entry.key)) {
        matchedSoundUrl = entry.value;
        break;
      }
    }
    if (matchedSoundUrl != null) {
      try {
        final file = await AppPersistentCache.getFile(matchedSoundUrl);
        if (!_isDisposed && mounted) {
          await _audioPlayer.stop();
          await _audioPlayer.play(DeviceFileSource(file.path));
        }
      } catch (e) {
        debugPrint("[LottiePlayer] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _composition == null) {
      return const SizedBox.shrink();
    }
    return Lottie(
      composition: _composition,
      controller: _controller,
      fit: BoxFit.contain,
      frameRate: FrameRate.composition,
    );
  }
}

class _LottieLocalPlayer extends StatefulWidget {
  final String assetPath;
  final String originalUrl;
  final bool hasCustomSound;
  /// If > 0, keep visible until this hold expires (so short compositions stay on screen).
  final int holdMs;
  final VoidCallback onComplete;
  final VoidCallback onError;
  final VoidCallback? onStart;
  const _LottieLocalPlayer({
    super.key,
    required this.assetPath,
    required this.originalUrl,
    this.hasCustomSound = false,
    this.holdMs = 0,
    required this.onComplete,
    required this.onError,
    this.onStart,
  });

  @override
  State<_LottieLocalPlayer> createState() => _LottieLocalPlayerState();
}

class _LottieLocalPlayerState extends State<_LottieLocalPlayer> with SingleTickerProviderStateMixin {
  LottieComposition? _composition;
  bool _isLoading = true;
  bool _isDisposed = false;
  late final AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  static final Map<String, File> _cachedSoundFiles = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    // Instant frame-0 start if the LottieComposition was already preloaded in memory
    final cached = LottieCache.getCached(widget.assetPath);
    if (cached != null) {
      _composition = cached;
      _isLoading = false;
      _controller.duration = cached.duration;
      _controller.forward().whenComplete(() {
        if (!_isDisposed && mounted) {
          widget.onComplete();
        }
      });
      widget.onStart?.call();
      _playGiftSound();
    } else {
      _loadAnimation();
    }
  }

  void _loadAnimation() async {
    try {
      final composition = await LottieCache.loadLocal(widget.assetPath);
      if (_isDisposed || !mounted) return;
      setState(() {
        _composition = composition;
        _isLoading = false;
        _controller.duration = composition.duration;
        // Play once and freeze on the last frame; the room player's hold
        // timer controls release instead of looping mid-hold.
        _controller.forward().whenComplete(() {
          if (!_isDisposed && mounted) {
            widget.onComplete();
          }
        });
      });
      widget.onStart?.call();
      _playGiftSound();
    } catch (e) {
      debugPrint("Error loading local Lottie composition: $e");
      if (!_isDisposed && mounted) {
        widget.onError();
      }
    }
  }

  void _playGiftSound() async {
    if (widget.hasCustomSound) return;
    final lowerUrl = widget.originalUrl.toLowerCase();
    String? matchedSoundUrl;
    for (final entry in _LottieNetworkPlayerState._lottieGiftSounds.entries) {
      if (lowerUrl.contains(entry.key)) {
        matchedSoundUrl = entry.value;
        break;
      }
    }
    if (matchedSoundUrl != null) {
      try {
        final cached = _cachedSoundFiles[matchedSoundUrl];
        final file = cached ?? await AppPersistentCache.getFile(matchedSoundUrl);
        _cachedSoundFiles[matchedSoundUrl] = file;
        if (!_isDisposed && mounted) {
          await _audioPlayer.stop();
          await _audioPlayer.play(DeviceFileSource(file.path));
        }
      } catch (e) {
        debugPrint("[LottieLocalPlayer] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _composition == null) {
      return const SizedBox.shrink();
    }
    return Lottie(
      composition: _composition,
      controller: _controller,
      fit: BoxFit.contain,
      frameRate: FrameRate.composition,
    );
  }
}
