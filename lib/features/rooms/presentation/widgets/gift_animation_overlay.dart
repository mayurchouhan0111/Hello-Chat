import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import 'package:tancent_vap/tancent_vap.dart';
import '../../../../core/constants/gift_vap_catalog.dart';
import '../../../../core/utils/app_persistent_cache.dart';
import '../../../../core/models/gift_model.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../services/gift_service.dart';
import 'package:hello_chat/core/services/server_time_service.dart';
import 'package:hello_chat/core/services/gift_replay_guard.dart';
import 'gift_combo_overlay.dart';
import 'seat_grid.dart';

/// Debug-only kill-switch for the persistent VAP player's embedded AAC
/// audio. Flip to true to diagnose audio glitches without touching
/// SafeHardDecoder. Not read from config — recompile to toggle.
const bool kMuteVapAudio = false;

/// Maximum number of sequential animation plays permitted per combo entry.
/// Beyond this cap, extra plays are dropped while the banner still reflects the total sent count.
const int kMaxComboPlays = 10;

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
    final sUid = senderUid.trim();
    final tUid = targetUid.trim();
    final gId = gift.giftId.trim();

    // 1. Exact composite key
    final exactKey = '$sUid|$tUid|$gId';
    _recentLocalDispatches.putIfAbsent(exactKey, () => <int>[]).add(nowMs);

    // 2. Resilient fallback key (sender + giftId) for seat/unseated or multi-target sends
    if (sUid.isNotEmpty && gId.isNotEmpty) {
      final fallbackKey = '$sUid||$gId';
      _recentLocalDispatches.putIfAbsent(fallbackKey, () => <int>[]).add(nowMs);
    }

    // Prune entries older than 20s across all keys
    _recentLocalDispatches.removeWhere((_, list) {
      list.removeWhere((time) => nowMs - time > 20000);
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
      } else if (lower.contains('.png') || lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.webp')) {
        resolvedFormat = 'image';
      } else if (!lower.endsWith('.json')) {
        resolvedFormat = 'image';
      }
    }

    int resolvedDuration = gift.durationMs;
    String resolvedTier = gift.animationTier;
    if (resolvedFormat == 'vap' || localVap != null) {
      final spec = GiftVapCatalog.byId(gift.giftId) ??
          (localVap != null ? GiftVapCatalog.all.where((s) => s.assetPath == localVap).firstOrNull : null);
      if (spec != null) {
        if (resolvedDuration <= 0) {
          resolvedDuration = spec.durationMs;
        }
        if (spec.tier.isNotEmpty) {
          resolvedTier = spec.tier;
        }
      }
      if (localVap != null) {
        if (resolvedDuration <= 0) {
          resolvedDuration = SvgaParserUtil.getRealOrFallbackVapDurationSync(localVap);
        }
        final vt = SvgaParserUtil.getLocalVapTier(localVap);
        if (vt != null && (resolvedTier.isEmpty || resolvedTier == 'NORMAL')) {
          resolvedTier = vt;
        }
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
      tier: resolvedTier,
      durationMs: resolvedDuration,
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
    final sUid = senderUid.trim();
    final tUid = targetUid.trim();
    final gId = giftId.trim();

    // 1. Try exact composite key first
    final exactKey = '$sUid|$tUid|$gId';
    final timestamps = _recentLocalDispatches[exactKey];
    if (timestamps != null && timestamps.isNotEmpty) {
      while (timestamps.isNotEmpty) {
        final dispatchedAt = timestamps.removeAt(0);
        if (nowMs - dispatchedAt < 20000) {
          if (timestamps.isEmpty) _recentLocalDispatches.remove(exactKey);
          // Also consume matching entry from fallback key if present
          final fbList = _recentLocalDispatches['$sUid||$gId'];
          if (fbList != null && fbList.isNotEmpty) {
            fbList.removeAt(0);
            if (fbList.isEmpty) _recentLocalDispatches.remove('$sUid||$gId');
          }
          return true;
        }
      }
      if (timestamps.isEmpty) _recentLocalDispatches.remove(exactKey);
    }

    // 2. Resilient fallback key: match by (senderUid, giftId) within window
    if (sUid.isNotEmpty && gId.isNotEmpty) {
      final fallbackKey = '$sUid||$gId';
      final fallbackTimestamps = _recentLocalDispatches[fallbackKey];
      if (fallbackTimestamps != null && fallbackTimestamps.isNotEmpty) {
        while (fallbackTimestamps.isNotEmpty) {
          final dispatchedAt = fallbackTimestamps.removeAt(0);
          if (nowMs - dispatchedAt < 20000) {
            if (fallbackTimestamps.isEmpty) _recentLocalDispatches.remove(fallbackKey);
            return true;
          }
        }
        if (fallbackTimestamps.isEmpty) _recentLocalDispatches.remove(fallbackKey);
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

/// Shared audio player pool for room gift playback.
/// Reusing a single player prevents Android native MediaPlayer handle exhaustion
/// (which causes silent gift playback and UI thread lockups).
/// Best-effort detection of an embedded audio track in an MP4/VAP container:
/// walks top-level boxes to `moov`, then `moov > trak > mdia > hdlr` and
/// checks for the `soun` handler type using RandomAccessFile seeking.
/// Does not load entire 20-30MB files into memory. Returns false when the file
/// can't be read or parsed — callers then fall back to playing their own soundUrl.
Future<bool> mp4HasAudioTrack(String path) async {
  RandomAccessFile? raf;
  try {
    final file = File(path);
    if (!await file.exists()) return false;
    final fileLength = await file.length();
    if (fileLength < 16) return false;

    raf = await file.open(mode: FileMode.read);
    return await _hasAudioTrackInBoxes(raf, 0, fileLength);
  } catch (e) {
    return false;
  } finally {
    try {
      await raf?.close();
    } catch (_) {}
  }
}

Future<bool> _hasAudioTrackInBoxes(RandomAccessFile raf, int start, int end) async {
  int pos = start;
  final headerBuffer = Uint8List(16);

  while (pos + 8 <= end) {
    await raf.setPosition(pos);
    final bytesRead = await raf.readInto(headerBuffer, 0, 8);
    if (bytesRead < 8) break;

    int size = (headerBuffer[0] << 24) |
        (headerBuffer[1] << 16) |
        (headerBuffer[2] << 8) |
        headerBuffer[3];
    final type = String.fromCharCodes(headerBuffer.sublist(4, 8));
    int headerSize = 8;

    if (size == 1) {
      if (pos + 16 > end) break;
      final extraRead = await raf.readInto(headerBuffer, 8, 16);
      if (extraRead < 8) break;
      size = 0;
      for (int i = 0; i < 8; i++) {
        size = (size << 8) | headerBuffer[8 + i];
      }
      headerSize = 16;
    } else if (size == 0) {
      size = end - pos;
    }

    if (size < headerSize || pos + size > end) break;

    final payloadStart = pos + headerSize;
    final payloadEnd = pos + size;

    if (type == 'moov' || type == 'trak' || type == 'mdia') {
      if (await _hasAudioTrackInBoxes(raf, payloadStart, payloadEnd)) {
        return true;
      }
    } else if (type == 'hdlr') {
      if (payloadEnd - payloadStart >= 12) {
        await raf.setPosition(payloadStart + 8);
        final hdlrType = await raf.read(4);
        if (hdlrType.length == 4 && String.fromCharCodes(hdlrType) == 'soun') {
          return true;
        }
      }
    }

    pos += size;
  }
  return false;
}

class _GiftAudioPool {
  static AudioPlayer? _player;
  static Future<void> _lock = Future.value();
  static int _lastPlayMs = 0;
  static const int kMinAudioIntervalMs = 150;

  static AudioPlayer get player {
    _player ??= AudioPlayer();
    return _player!;
  }

  static Future<void> playFile(String path, {double volume = 1.0}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayMs < kMinAudioIntervalMs) {
      return Future.value();
    }
    _lastPlayMs = now;

    return _lock = _lock.then((_) async {
      try {
        final p = player;
        await p.stop();
        await p.setVolume(volume);
        await p.play(DeviceFileSource(path), volume: volume);
      } catch (e) {
        debugPrint("[GiftAudioPool] Error playing file ($path): $e");
      }
    });
  }

  static Future<void> playUrl(String url, {double volume = 1.0}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayMs < kMinAudioIntervalMs) {
      return Future.value();
    }
    _lastPlayMs = now;

    return _lock = _lock.then((_) async {
      try {
        final p = player;
        await p.stop();
        await p.setVolume(volume);
        await p.play(UrlSource(url), volume: volume);
      } catch (e) {
        debugPrint("[GiftAudioPool] Error playing url ($url): $e");
      }
    });
  }

  static Future<void> playAsset(String assetPath, {double volume = 1.0}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayMs < kMinAudioIntervalMs) {
      return Future.value();
    }
    _lastPlayMs = now;

    return _lock = _lock.then((_) async {
      try {
        final p = player;
        await p.stop();
        await p.setVolume(volume);
        final clean = assetPath.startsWith('assets/') ? assetPath.replaceFirst('assets/', '') : assetPath;
        await p.play(AssetSource(clean), volume: volume);
      } catch (e) {
        debugPrint("[GiftAudioPool] Error playing asset ($assetPath): $e");
      }
    });
  }

  static Future<void> stop() {
    return _lock = _lock.then((_) async {
      try {
        await _player?.stop();
      } catch (_) {}
    });
  }
}

class _GiftAnimationOverlayState extends ConsumerState<GiftAnimationOverlay>
    with WidgetsBindingObserver {
  /// Anchor for resolving seat rects relative to this overlay's coordinate
  /// space (Layer 1 seat-anchored effects).
  final GlobalKey _overlayKey = GlobalKey(debugLabel: 'gift_overlay_stack');
  final Set<String> _processedMessageIds = {};
  final Set<String> _processedEventIds = {};
  bool _initialHistorySeeded = false;
  int _joinTimeServerMs = 0;
  late final DateTime _mountTimestamp;

  /// True while the app is backgrounded: gift queues are cleared and new
  /// gifts are dropped (already marked processed, so nothing replays).
  bool _isAppPaused = false;

  // Seat queues for small/normal gifts (SVGA, Lottie, Seat flight)
  final Map<String, List<_ActiveGiftAnimation>> _seatQueues = {};
  final Map<String, _ActiveSeatGift> _currentSeatGifts = {};

  // Priority Queue for Room/Luxury full-screen animations:
  // - Luxury before small/medium
  // - Combo merging per sender+gift
  // - Max 5 queued luxury gifts
  // - Dedupe by event id
  // - Only one full-screen animation at a time
  final List<_ActiveGiftAnimation> _luxuryQueue = [];
  final List<_ActiveGiftAnimation> _mediumQueue = [];
  _ActiveGiftAnimation? _currentFullScreenAnim;
  bool _isFullScreenPlaying = false;
  double _vapOpacity = 0.0;
  Timer? _fullScreenWatchdogTimer;
  Timer? _transitionTimer;
  int? _waitingForReleaseTicket;
  Timer? _releaseFallbackTimer;

  // Persistent VAP Player in the room overlay:
  // - Created on room enter, released ONLY on room exit
  // - Per gift, call ONLY playFile()
  // - No per-gift PlatformView recreation, no surface polling
  VapController? _persistentVapController;
  final Completer<VapController> _vapControllerCompleter = Completer<VapController>();
  DateTime? _vapStartTime;
  String _currentDeviceModel = 'Android';
  int _currentFullScreenTicket = 0;

  List<GiftModel> _gifts = [];

  void _enqueueSeatAnimation(String targetUid, _ActiveGiftAnimation animation) {
    if (!mounted) return;
    if (_isAppPaused) return;

    // Pre-cache VAP file immediately in background so it's 100% ready on disk when queue reaches it
    if (animation.format == 'vap' || animation.url.endsWith('.vap') || animation.url.endsWith('.mp4')) {
      VapAnimation.preCache(animation.url);
    }
    final key = targetUid.isNotEmpty ? targetUid : '_unseated_';

    final queue = _seatQueues.putIfAbsent(key, () => []);
    final existingIdx = queue.indexWhere(
      (item) => item.senderUid == animation.senderUid && item.giftId == animation.giftId,
    );
    final int activePlays = (_currentSeatGifts[key]?.animation.senderUid == animation.senderUid &&
            _currentSeatGifts[key]?.animation.giftId == animation.giftId)
        ? _currentSeatGifts[key]!.animation.totalPlays
        : 0;
    final int maxAllowedInQueue = math.max(0, kMaxComboPlays - activePlays);

    if (existingIdx != -1) {
      final existing = queue[existingIdx];
      final int lastComboCount = existing.comboCount;
      final int deltaPlays = (animation.comboCount > 0 && lastComboCount > 0)
          ? math.max(animation.comboCount - lastComboCount, 1)
          : math.max(animation.totalPlays > 0 ? animation.totalPlays : (animation.comboCount > 0 ? animation.comboCount : 1), 1);
      final int newTotal = existing.totalPlays + deltaPlays;
      final int newRemaining = existing.remainingPlays + deltaPlays;
      final int cappedTotal = math.min(newTotal, maxAllowedInQueue);
      final int cappedRemaining = math.min(newRemaining, maxAllowedInQueue);
      if (newTotal > maxAllowedInQueue) {
        debugPrint("[SeatGift] Combo cap ($kMaxComboPlays) reached for ${animation.giftName}: dropped ${newTotal - maxAllowedInQueue} excess plays on $key");
      }
      final int displayCombo = math.max(existing.comboCount, animation.comboCount);
      queue[existingIdx] = existing.copyWith(
        comboCount: displayCombo,
        totalPlays: cappedTotal,
        remainingPlays: cappedRemaining,
        text: '${animation.giftName} x$displayCombo',
      );
      debugPrint("[SeatGift] Merged into queued seat gift: ${animation.giftName} (totalPlays=$cappedTotal, remaining=$cappedRemaining, combo=$displayCombo) on $key");
      return;
    }

    final int lastPlayingCombo = (_currentSeatGifts[key]?.animation.senderUid == animation.senderUid &&
            _currentSeatGifts[key]?.animation.giftId == animation.giftId)
        ? _currentSeatGifts[key]!.animation.comboCount
        : 0;
    final int deltaPlays = (animation.comboCount > 0 && lastPlayingCombo > 0)
        ? math.max(animation.comboCount - lastPlayingCombo, 1)
        : math.max(animation.totalPlays > 0 ? animation.totalPlays : (animation.comboCount > 0 ? animation.comboCount : 1), 1);
    final int cappedPlays = math.min(deltaPlays, maxAllowedInQueue);
    if (deltaPlays > maxAllowedInQueue) {
      debugPrint("[SeatGift] Combo cap ($kMaxComboPlays) reached for ${animation.giftName}: dropped ${deltaPlays - maxAllowedInQueue} excess plays on $key");
    }
    final animWithPlays = animation.copyWith(
      totalPlays: cappedPlays,
      remainingPlays: cappedPlays,
      currentPlayIndex: 1,
    );

    if (queue.length < 50) {
      queue.add(animWithPlays);
    }
    _checkNextSeatAnimation(key);
  }

  void _checkNextSeatAnimation(String targetKey) {
    if (!mounted) return;
    if (_currentSeatGifts.containsKey(targetKey)) return;

    final queue = _seatQueues[targetKey];
    if (queue == null || queue.isEmpty) return;

    final nextAnim = queue.removeAt(0);
    final comboKey = nextAnim.targetUid != null && nextAnim.targetUid!.isNotEmpty && nextAnim.giftId.isNotEmpty
        ? comboKeyFor(nextAnim.senderUid, nextAnim.targetUid!, nextAnim.giftId)
        : null;
    if (comboKey != null) {
      ref.read(giftComboControllerProvider(widget.roomId)).touch(comboKey);
    }

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

      if (active != null && active.animation.remainingPlays > 1) {
        final current = active.animation;
        final nextPlayIndex = current.currentPlayIndex + 1;
        final nextRemaining = current.remainingPlays - 1;
        debugPrint("[SeatGift] Repeating combo play on $targetKey: ${current.giftName} (play $nextPlayIndex of ${current.totalPlays}, $nextRemaining remaining)");

        final nextAnim = current.copyWith(
          remainingPlays: nextRemaining,
          currentPlayIndex: nextPlayIndex,
          text: '${current.giftName} x$nextPlayIndex',
        );
        final comboKey = current.targetUid != null && current.targetUid!.isNotEmpty && current.giftId.isNotEmpty
            ? comboKeyFor(current.senderUid, current.targetUid!, current.giftId)
            : null;
        if (comboKey != null) {
          ref.read(giftComboControllerProvider(widget.roomId)).touch(comboKey);
        }
        final int safeMs = math.max(nextAnim.durationMs + 4000, 20000);
        final nextAnimId = "${current.id}_p$nextPlayIndex";
        final timer = Timer(Duration(milliseconds: safeMs), () {
          _onSeatAnimationFinished(targetKey, nextAnimId);
        });
        setState(() {
          _currentSeatGifts[targetKey] = _ActiveSeatGift(
            id: nextAnimId,
            targetUid: targetKey == '_unseated_' ? '' : targetKey,
            animation: nextAnim,
            expiryTimer: timer,
            hasFlown: true, // Already flew to the seat on play 1, keep it anchored
          );
        });
        return;
      }

      final queue = _seatQueues[targetKey];
      if (queue != null && queue.isNotEmpty) {
        final nextAnim = queue.removeAt(0);
        final comboKey = nextAnim.targetUid != null && nextAnim.targetUid!.isNotEmpty && nextAnim.giftId.isNotEmpty
            ? comboKeyFor(nextAnim.senderUid, nextAnim.targetUid!, nextAnim.giftId)
            : null;
        if (comboKey != null) {
          ref.read(giftComboControllerProvider(widget.roomId)).touch(comboKey);
        }
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
            hasFlown: false, // Each queued gift animates its flight towards the person
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
    _joinTimeServerMs = ServerTimeService.serverNowMs;
    ServerTimeService.sync();
    // Record overlay mount timestamp with 2-second grace for initial history isolation
    _mountTimestamp = DateTime.now().subtract(const Duration(seconds: 2));
    WidgetsBinding.instance.addObserver(this);
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
      // Pre-cache all bundled VAP gifts and pre-decode SVGA gifts in background so first playback has zero I/O latency
      Future.delayed(const Duration(milliseconds: 1500), () {
        for (final spec in GiftVapCatalog.all) {
          VapAnimation.preCache(spec.assetPath);
        }
        for (final g in _gifts) {
          final raw = g.lottieAssetPath.isNotEmpty ? g.lottieAssetPath : g.imageUrl;
          final svga = SvgaParserUtil.getLocalGiftSvgaPath(raw, giftId: g.giftId, giftName: g.name);
          if (svga != null) {
            SvgaParserUtil.decodeSafeFromAssets(svga);
          }
        }
      });
    } catch (e) {
      debugPrint("[GiftCache] Error fetching gift catalog: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused) {
      _isAppPaused = true;
      debugPrint('[GiftOverlay] App paused: stopping VAP and clearing gift queues');
      _fullScreenWatchdogTimer?.cancel();
      _transitionTimer?.cancel();
      for (final sg in _currentSeatGifts.values) {
        sg.expiryTimer.cancel();
      }
      _currentSeatGifts.clear();
      _seatQueues.clear();
      _luxuryQueue.clear();
      _mediumQueue.clear();
      _currentFullScreenAnim = null;
      _isFullScreenPlaying = false;
      _vapStartTime = null;
      try {
        _persistentVapController?.stop();
      } catch (e) {
        debugPrint('[GiftOverlay] Error stopping VAP on pause: $e');
      }
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      // Accept new gifts only; anything dropped while paused stays marked
      // processed and is never replayed.
      _isAppPaused = false;
      debugPrint('[GiftOverlay] App resumed: accepting new gifts only');
    }
  }

  void _handleLocalAnimationEvents(List<GiftAnimationEvent> events) {
    for (final ev in events) {
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
        } else if (lower.contains('.png') || lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.webp')) {
          resolvedFormat = 'image';
        } else if (!lower.endsWith('.json')) {
          resolvedFormat = 'image';
        }
      }

      final bool isNativePlatformAnim = (resolvedFormat == 'vap' ||
          resolvedFormat == 'vpa' ||
          resolvedFormat == 'mp4' ||
          resolvedFormat == 'pag' ||
          resolvedFormat == 'svga');

      int resolvedDuration = ev.durationMs;
      String resolvedTier = ev.tier;
      if (resolvedFormat == 'vap' || localVap != null) {
        final spec = GiftVapCatalog.byId(ev.giftId) ??
            (localVap != null ? GiftVapCatalog.all.where((s) => s.assetPath == localVap).firstOrNull : null);
        if (spec != null) {
          if (resolvedDuration <= 0) {
            resolvedDuration = spec.durationMs;
          }
          if (spec.tier.isNotEmpty) {
            resolvedTier = spec.tier;
          }
        }
        if (localVap != null) {
          if (resolvedDuration <= 0) {
            resolvedDuration = SvgaParserUtil.getRealOrFallbackVapDurationSync(localVap);
          }
          final vt = SvgaParserUtil.getLocalVapTier(localVap);
          if (vt != null && (resolvedTier.isEmpty || resolvedTier == 'NORMAL')) {
            resolvedTier = vt;
          }
        }
      }

      if (resolvedTier == 'NORMAL' && !isNativePlatformAnim) {
        final count = math.max(ev.comboCount > 0 ? ev.comboCount : ev.quantity, 1);
        final anim = _ActiveGiftAnimation(
          id: ev.id,
          giftId: ev.giftId,
          url: resolvedUrl,
          senderUid: ev.senderUid,
          text: '${ev.giftName} x$count',
          imageUrl: ev.imageUrl,
          soundUrl: ev.soundUrl,
          format: resolvedFormat,
          giftCategory: ev.category,
          giftName: ev.giftName,
          tier: resolvedTier,
          durationMs: resolvedDuration,
          targetUid: targetUid.isNotEmpty ? targetUid : null,
          comboCount: count,
          totalPlays: count,
          remainingPlays: count,
          currentPlayIndex: 1,
        );
        _enqueueSeatAnimation(targetUid, anim);
      } else {
        final count = math.max(ev.comboCount > 0 ? ev.comboCount : ev.quantity, 1);
        final anim = _ActiveGiftAnimation(
          id: ev.id,
          giftId: ev.giftId,
          url: resolvedUrl,
          senderUid: ev.senderUid,
          text: ev.text.isNotEmpty ? ev.text : '${ev.giftName} x$count',
          imageUrl: ev.imageUrl,
          soundUrl: ev.soundUrl,
          format: resolvedFormat,
          giftCategory: ev.category,
          giftName: ev.giftName,
          tier: resolvedTier,
          durationMs: resolvedDuration,
          targetUid: targetUid.isNotEmpty ? targetUid : null,
          comboCount: count,
          totalPlays: count,
          remainingPlays: count,
          currentPlayIndex: 1,
        );
        _enqueueRoomAnimation(anim);
      }
    }
  }

  void _handleMessages(List<RoomMessage> messages) {
    // Calibrate server time offset from document server timestamp if not yet synced
    if (messages.isNotEmpty) {
      ServerTimeService.calibrateWithServerTimestamp(messages.first.createdAt);
    }

    // On room entry, seed existing historical messages created before mount
    // so joining never replays older gifts. Genuinely new gifts arriving at
    // or after mount are preserved and played for all participants.
    if (!_initialHistorySeeded) {
      _initialHistorySeeded = true;
      for (final m in messages) {
        if (m.createdAt.isBefore(_mountTimestamp)) {
          _processedMessageIds.add(m.msgId);
        }
      }
    }

    final combos = ref.read(giftComboControllerProvider(widget.roomId));
    final animController = ref.read(giftAnimationControllerProvider(widget.roomId));
    final currentUid = FirebaseAuth.instance.currentUser?.uid ??
        ref.read(currentUserProfileProvider).value?.uid ??
        ref.read(authStateProvider).value?.uid;

    final nowServerMs = ServerTimeService.serverNowMs;

    // Filter gift messages through the strict Triple-Gate (GiftReplayGuard):
    final List<RoomMessage> newGifts = [];

    for (final msg in messages) {
      final decision = GiftReplayGuard.evaluate(
        msgId: msg.msgId,
        type: msg.type,
        animationUrl: msg.animationUrl,
        giftId: msg.giftId,
        createdAt: msg.createdAt,
        hasExplicitTimestamp: msg.hasExplicitTimestamp,
        durationMs: msg.durationMs,
        processedMessageIds: _processedMessageIds,
        joinTimeServerMs: _joinTimeServerMs,
        nowServerMs: nowServerMs,
      );

      if (decision.isSkipped) {
        if (decision.reason != GiftSkipReason.notGiftType &&
            decision.reason != GiftSkipReason.missingAnimationPayload) {
          _processedMessageIds.add(msg.msgId);
          if (decision.logMessage != null) {
            debugPrint(decision.logMessage);
          }
        }
        continue;
      }

      newGifts.add(msg);
    }

    // Process strictly in ascending chronological sending order (oldest first, newest last)
    newGifts.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      if (cmp != 0) return cmp;
      return a.comboCount.compareTo(b.comboCount);
    });

    for (final msg in newGifts) {
      _processedMessageIds.add(msg.msgId);

      String effectiveGiftId = msg.giftId?.trim() ?? '';
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
      if (matched == null && giftName.isNotEmpty) {
        for (final g in _gifts) {
          if (g.name.trim().toLowerCase() == giftName.trim().toLowerCase()) {
            matched = g;
            break;
          }
        }
      }

      if (effectiveGiftId.isEmpty && matched != null) {
        effectiveGiftId = matched.giftId;
      }

      final String msgSenderUid = msg.uid.trim();
      final String safeCurrentUid = currentUid?.trim() ?? '';

      // Check if this sender already played this gift optimistically
      final isFromMe = safeCurrentUid.isNotEmpty && msgSenderUid == safeCurrentUid;
      if (isFromMe && (animController.shouldSkipEcho(
        senderUid: msgSenderUid,
        targetUid: msg.targetUid.trim(),
        giftId: effectiveGiftId,
      ) || (matched != null && animController.shouldSkipEcho(
        senderUid: msgSenderUid,
        targetUid: msg.targetUid.trim(),
        giftId: matched.giftId,
      )))) {
        // Still feed combo controller with authoritative icon, but skip redundant local re-animation
        debugPrint('🎁 [GIFT_SKIP] reason=localEcho, msgId=${msg.msgId}, giftId=$effectiveGiftId, age=${nowServerMs - msg.createdAt.millisecondsSinceEpoch}ms');
        combos.applyRemote(msg, giftIconUrl: imageUrl ?? matched?.imageUrl ?? giftUrl);
        continue;
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
      } else if (format.isEmpty || (format == 'json' && !lower.endsWith('.json') && localLottie == null)) {
        format = lower.endsWith('.json') ? 'json' : 'image';
      }

      if (durationMs <= 0 && (format == 'vap' || localVap != null)) {
        final spec = GiftVapCatalog.byId(effectiveGiftId) ??
            (localVap != null ? GiftVapCatalog.all.where((s) => s.assetPath == localVap).firstOrNull : null);
        if (spec != null) {
          durationMs = spec.durationMs;
          if (tier.isEmpty && spec.tier.isNotEmpty) {
            tier = spec.tier;
          }
        }
        if (localVap != null) {
          if (durationMs <= 0) {
            durationMs = SvgaParserUtil.getRealOrFallbackVapDurationSync(localVap);
          }
          final vt = SvgaParserUtil.getLocalVapTier(localVap);
          if (vt != null && (tier.isEmpty || tier == 'NORMAL')) {
            tier = vt;
          }
        }
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

      final targetUid = msg.targetUid.trim();

      // Skip duplicate animation if this is a server echo of a gift we already played optimistically
      if (currentUid != null && msg.uid == currentUid) {
        if (animController.shouldSkipEcho(
          senderUid: msg.uid,
          targetUid: targetUid,
          giftId: effectiveGiftId,
        )) {
          debugPrint("[GiftOverlay] Skipped local echo animation for msgId: ${msg.msgId}, gift: $effectiveGiftId");
          continue;
        }
      }

      final bool isNativePlatformAnim = (format == 'vap' ||
          format == 'vpa' ||
          format == 'mp4' ||
          format == 'pag' ||
          format == 'svga');

      if (tier == 'NORMAL' && !isNativePlatformAnim) {
        final count = math.max(msg.comboCount > 0 ? msg.comboCount : msg.quantity, 1);
        final anim = _ActiveGiftAnimation(
          id: "${msg.msgId}_$targetUid",
          giftId: effectiveGiftId,
          url: giftUrl,
          senderUid: msg.uid,
          text: '${giftName.isNotEmpty ? giftName : 'Gift'} x$count',
          imageUrl: imageUrl,
          soundUrl: soundUrl,
          format: format,
          giftCategory: category,
          giftName: giftName,
          tier: tier,
          durationMs: durationMs,
          targetUid: targetUid.isNotEmpty ? targetUid : null,
          comboCount: count,
          totalPlays: count,
          remainingPlays: count,
          currentPlayIndex: 1,
        );
        _enqueueSeatAnimation(targetUid, anim);
      } else {
        final count = math.max(msg.comboCount > 0 ? msg.comboCount : msg.quantity, 1);
        final anim = _ActiveGiftAnimation(
          id: msg.msgId,
          giftId: effectiveGiftId,
          url: giftUrl,
          senderUid: msg.uid,
          text: msg.text.isNotEmpty ? msg.text : '${giftName.isNotEmpty ? giftName : 'Gift'} x$count',
          imageUrl: imageUrl,
          soundUrl: soundUrl,
          format: format,
          giftCategory: category,
          giftName: giftName,
          tier: tier,
          durationMs: durationMs,
          targetUid: targetUid.isNotEmpty ? targetUid : null,
          comboCount: count,
          totalPlays: count,
          remainingPlays: count,
          currentPlayIndex: 1,
        );
        _enqueueRoomAnimation(anim);
      }
    }

    if (_processedMessageIds.length > 500) {
      _processedMessageIds.removeAll(_processedMessageIds.take(_processedMessageIds.length - 250).toList());
    }
  }

  void _setupPersistentVapController(VapController controller) {
    debugPrint("[VAP] Persistent VapController attached on room enter");
    _persistentVapController = controller;
    if (!_vapControllerCompleter.isCompleted) {
      _vapControllerCompleter.complete(controller);
    }
    controller.setAnimListener(
      onVideoStart: () {
        if (mounted && _vapOpacity != 1.0) {
          setState(() {
            _vapOpacity = 1.0;
          });
        }
        final now = DateTime.now();
        final ttffMs = _vapStartTime != null ? now.difference(_vapStartTime!).inMilliseconds : -1;
        debugPrint("[VAP_TRACE] onStart: id=${_currentFullScreenAnim?.id}, device=$_currentDeviceModel, ttff=${ttffMs}ms");
        // Re-arm from actual decode-start with a tighter budget.
        // Devices that never fire onVideoStart still fall back to the initial +800 ms budget.
        final int clipMs = _currentFullScreenAnim?.durationMs ?? 0;
        if (clipMs > 0 && _isFullScreenPlaying) {
          _armFullScreenSafetyTimer(clipMs + 1500, _currentFullScreenTicket);
          debugPrint("[VAP_TRACE] watchdog re-armed on start: duration=${clipMs}ms + 1500ms");
        }
      },
      onVideoStartWithDevice: (device) {
        if (device != null && device.isNotEmpty) {
          _currentDeviceModel = device;
        }
        if (mounted && _vapOpacity != 1.0) {
          setState(() {
            _vapOpacity = 1.0;
          });
        }
        final now = DateTime.now();
        final ttffMs = _vapStartTime != null ? now.difference(_vapStartTime!).inMilliseconds : -1;
        debugPrint("[VAP_TRACE] onStart: id=${_currentFullScreenAnim?.id}, device=$_currentDeviceModel, ttff=${ttffMs}ms");
        // Re-arm from actual decode-start (device-variant callback path).
        final int clipMs = _currentFullScreenAnim?.durationMs ?? 0;
        if (clipMs > 0 && _isFullScreenPlaying) {
          _armFullScreenSafetyTimer(clipMs + 1500, _currentFullScreenTicket);
          debugPrint("[VAP_TRACE] watchdog re-armed on start (device): duration=${clipMs}ms + 1500ms");
        }
      },
      onVideoComplete: () {
        debugPrint("[VAP_TRACE] onComplete: id=${_currentFullScreenAnim?.id}, device=$_currentDeviceModel, ticket=${controller.currentTicket}");
        if (mounted && _vapOpacity != 0.0) {
          setState(() {
            _vapOpacity = 0.0;
          });
        }
        if (_waitingForReleaseTicket != null && _waitingForReleaseTicket == controller.currentTicket) {
          debugPrint("[VAP_TRACE] release signal received after watchdog for ticket ${controller.currentTicket}");
          _releaseFallbackTimer?.cancel();
          _waitingForReleaseTicket = null;
        }
        _onFullScreenAnimationFinished(controller.currentTicket);
      },
      onFailed: (code, errorType, msg) {
        debugPrint("[VAP_TRACE] onFail: id=${_currentFullScreenAnim?.id}, code=$code, type=$errorType, msg=$msg, device=$_currentDeviceModel, ticket=${controller.currentTicket}");
        if (mounted && _vapOpacity != 0.0) {
          setState(() {
            _vapOpacity = 0.0;
          });
        }
        if (_waitingForReleaseTicket != null && _waitingForReleaseTicket == controller.currentTicket) {
          debugPrint("[VAP_TRACE] release signal (fail) received after watchdog for ticket ${controller.currentTicket}");
          _releaseFallbackTimer?.cancel();
          _waitingForReleaseTicket = null;
        }
        _onFullScreenAnimationFinished(controller.currentTicket);
      },
      onFailedWithDevice: (code, errorType, msg, device) {
        if (device != null && device.isNotEmpty) {
          _currentDeviceModel = device;
        }
        debugPrint("[VAP_TRACE] onFail: id=${_currentFullScreenAnim?.id}, code=$code, type=$errorType, msg=$msg, device=$_currentDeviceModel, ticket=${controller.currentTicket}");
        if (mounted && _vapOpacity != 0.0) {
          setState(() {
            _vapOpacity = 0.0;
          });
        }
        if (_waitingForReleaseTicket != null && _waitingForReleaseTicket == controller.currentTicket) {
          debugPrint("[VAP_TRACE] release signal (fail) received after watchdog for ticket ${controller.currentTicket}");
          _releaseFallbackTimer?.cancel();
          _waitingForReleaseTicket = null;
        }
        _onFullScreenAnimationFinished(controller.currentTicket);
      },
      onVideoDestroy: () {
        debugPrint("[VAP_TRACE] onVideoDestroy: id=${_currentFullScreenAnim?.id}, device=$_currentDeviceModel, ticket=${controller.currentTicket}");
      },
    );
  }

  void _enqueueRoomAnimation(_ActiveGiftAnimation anim) {
    if (!mounted) return;

    // Dedupe by event id
    if (_processedEventIds.contains(anim.id)) return;
    _processedEventIds.add(anim.id);
    if (_processedEventIds.length > 500) {
      _processedEventIds.removeAll(_processedEventIds.take(_processedEventIds.length - 250).toList());
    }
    if (_isAppPaused) return;

    // Pre-cache VAP file immediately in background so it's 100% ready on disk when queue reaches it
    if (anim.format == 'vap' || anim.url.endsWith('.vap') || anim.url.endsWith('.mp4')) {
      VapAnimation.preCache(anim.url);
    }

    final int activePlays = (_currentFullScreenAnim != null &&
            _currentFullScreenAnim!.senderUid == anim.senderUid &&
            _currentFullScreenAnim!.giftId == anim.giftId)
        ? _currentFullScreenAnim!.totalPlays
        : 0;
    final int maxAllowedInQueue = math.max(0, kMaxComboPlays - activePlays);

    if (anim.tier == 'LUXURY') {
      final existingIdx = _luxuryQueue.indexWhere(
        (item) => item.senderUid == anim.senderUid && item.giftId == anim.giftId,
      );
      if (existingIdx != -1) {
        final existing = _luxuryQueue[existingIdx];
        final int lastComboCount = existing.comboCount;
        final int deltaPlays = (anim.comboCount > 0 && lastComboCount > 0)
            ? math.max(anim.comboCount - lastComboCount, 1)
            : math.max(anim.totalPlays > 0 ? anim.totalPlays : (anim.comboCount > 0 ? anim.comboCount : 1), 1);
        final int newTotal = existing.totalPlays + deltaPlays;
        final int newRemaining = existing.remainingPlays + deltaPlays;
        final int cappedTotal = math.min(newTotal, maxAllowedInQueue);
        final int cappedRemaining = math.min(newRemaining, maxAllowedInQueue);
        if (newTotal > maxAllowedInQueue) {
          debugPrint("[GiftQueue] Combo cap ($kMaxComboPlays) reached for ${anim.giftName} (sender ${anim.senderUid}): dropped ${newTotal - maxAllowedInQueue} excess plays");
        }
        final int displayCombo = math.max(existing.comboCount, anim.comboCount);
        _luxuryQueue[existingIdx] = existing.copyWith(
          comboCount: displayCombo,
          totalPlays: cappedTotal,
          remainingPlays: cappedRemaining,
          text: '${anim.giftName} x$displayCombo',
        );
        debugPrint("[GiftQueue] Merged luxury combo in queue: ${anim.giftName} (totalPlays=$cappedTotal, remaining=$cappedRemaining, combo=$displayCombo) for sender ${anim.senderUid}");
      } else {
        final int lastPlayingCombo = (_currentFullScreenAnim != null &&
                _currentFullScreenAnim!.senderUid == anim.senderUid &&
                _currentFullScreenAnim!.giftId == anim.giftId)
            ? _currentFullScreenAnim!.comboCount
            : 0;
        final int deltaPlays = (anim.comboCount > 0 && lastPlayingCombo > 0)
            ? math.max(anim.comboCount - lastPlayingCombo, 1)
            : math.max(anim.totalPlays > 0 ? anim.totalPlays : (anim.comboCount > 0 ? anim.comboCount : 1), 1);
        final int cappedPlays = math.min(deltaPlays, maxAllowedInQueue);
        if (deltaPlays > maxAllowedInQueue) {
          debugPrint("[GiftQueue] Combo cap ($kMaxComboPlays) reached for ${anim.giftName} (sender ${anim.senderUid}): dropped ${deltaPlays - maxAllowedInQueue} excess plays");
        }
        final animWithPlays = anim.copyWith(
          totalPlays: cappedPlays,
          remainingPlays: cappedPlays,
          currentPlayIndex: 1,
        );
        // Max 5 queued luxury gift entries (drops oldest if exceeded)
        if (_luxuryQueue.length >= 5) {
          final dropped = _luxuryQueue.removeAt(0);
          debugPrint("[GiftQueue] Max 5 luxury cap reached, dropped oldest: ${dropped.giftName}");
        }
        _luxuryQueue.add(animWithPlays);
        debugPrint("[GiftQueue] Added luxury gift to queue: ${anim.giftName} (plays=$cappedPlays, combo=${anim.comboCount}) for sender ${anim.senderUid}, luxury queue length=${_luxuryQueue.length}");
      }
    } else {
      // Medium / other room animations
      final existingIdx = _mediumQueue.indexWhere(
        (item) => item.senderUid == anim.senderUid && item.giftId == anim.giftId,
      );
      if (existingIdx != -1) {
        final existing = _mediumQueue[existingIdx];
        final int lastComboCount = existing.comboCount;
        final int deltaPlays = (anim.comboCount > 0 && lastComboCount > 0)
            ? math.max(anim.comboCount - lastComboCount, 1)
            : math.max(anim.totalPlays > 0 ? anim.totalPlays : (anim.comboCount > 0 ? anim.comboCount : 1), 1);
        final int newTotal = existing.totalPlays + deltaPlays;
        final int newRemaining = existing.remainingPlays + deltaPlays;
        final int cappedTotal = math.min(newTotal, maxAllowedInQueue);
        final int cappedRemaining = math.min(newRemaining, maxAllowedInQueue);
        if (newTotal > maxAllowedInQueue) {
          debugPrint("[GiftQueue] Combo cap ($kMaxComboPlays) reached for ${anim.giftName} (sender ${anim.senderUid}): dropped ${newTotal - maxAllowedInQueue} excess plays");
        }
        final int displayCombo = math.max(existing.comboCount, anim.comboCount);
        _mediumQueue[existingIdx] = existing.copyWith(
          comboCount: displayCombo,
          totalPlays: cappedTotal,
          remainingPlays: cappedRemaining,
          text: '${anim.giftName} x$displayCombo',
        );
      } else {
        final int lastPlayingCombo = (_currentFullScreenAnim != null &&
                _currentFullScreenAnim!.senderUid == anim.senderUid &&
                _currentFullScreenAnim!.giftId == anim.giftId)
            ? _currentFullScreenAnim!.comboCount
            : 0;
        final int deltaPlays = (anim.comboCount > 0 && lastPlayingCombo > 0)
            ? math.max(anim.comboCount - lastPlayingCombo, 1)
            : math.max(anim.totalPlays > 0 ? anim.totalPlays : (anim.comboCount > 0 ? anim.comboCount : 1), 1);
        final int cappedPlays = math.min(deltaPlays, maxAllowedInQueue);
        if (deltaPlays > maxAllowedInQueue) {
          debugPrint("[GiftQueue] Combo cap ($kMaxComboPlays) reached for ${anim.giftName} (sender ${anim.senderUid}): dropped ${deltaPlays - maxAllowedInQueue} excess plays");
        }
        final animWithPlays = anim.copyWith(
          totalPlays: cappedPlays,
          remainingPlays: cappedPlays,
          currentPlayIndex: 1,
        );
        if (_mediumQueue.length < 20) {
          _mediumQueue.add(animWithPlays);
        }
      }
    }

    if (!_isFullScreenPlaying) {
      _checkNextFullScreenAnimation();
    }
  }

  void _checkNextFullScreenAnimation() {
    if (!mounted || _isFullScreenPlaying) return;
    if (ref.read(isRocketActiveProvider(widget.roomId))) {
      debugPrint("[GiftQueue] Rocket animation is active, holding full-screen gifts");
      return;
    }

    // Priority queue: luxury before small/medium, only one full-screen animation at a time
    _ActiveGiftAnimation? nextAnim;
    if (_luxuryQueue.isNotEmpty) {
      nextAnim = _luxuryQueue.removeAt(0);
    } else if (_mediumQueue.isNotEmpty) {
      nextAnim = _mediumQueue.removeAt(0);
    }

    if (nextAnim == null) return;
    _playFullScreenGift(nextAnim);
  }

  void _playFullScreenGift(_ActiveGiftAnimation anim) {
    if (!mounted) return;

    final isVap = anim.format == 'vap';
    final int ticket = ++_currentFullScreenTicket;

    setState(() {
      _isFullScreenPlaying = true;
      _currentFullScreenAnim = anim;
      if (isVap) {
        _vapOpacity = 0.0;
      }
    });

    final comboKey = anim.targetUid != null && anim.targetUid!.isNotEmpty && anim.giftId.isNotEmpty
        ? comboKeyFor(anim.senderUid, anim.targetUid!, anim.giftId)
        : null;
    if (comboKey != null) {
      ref.read(giftComboControllerProvider(widget.roomId)).touch(comboKey);
    }

    if (isVap) {
      _vapStartTime = DateTime.now();

      // soundUrl is layered on top of a VAP only when the file itself has no
      // audio track (mp4HasAudioTrack below). Bundled .vap assets all carry
      // embedded AAC, so their empty catalog soundUrl never even triggers the
      // check; a remote gift shipping a silent .vap + soundUrl still gets sound.

      // Duration safety cap: 2000 ms covers TTFF decode time
      final int duration = anim.durationMs > 0 ? anim.durationMs : 6000;
      _armFullScreenSafetyTimer(duration + 2000, ticket);
      debugPrint("[VAP_TRACE] play-chain armed id=${anim.id} ticket=$ticket url=${anim.url}");

      Future<VapController?> getController() async {
        if (_persistentVapController != null) return _persistentVapController;
        try {
          return await _vapControllerCompleter.future.timeout(const Duration(seconds: 4));
        } catch (_) {}
        return null;
      }

      getController().then((ctrl) {
        if (!mounted || !_isFullScreenPlaying || _currentFullScreenAnim?.id != anim.id || _currentFullScreenTicket != ticket) {
          debugPrint("[VAP_TRACE] playFile REFUSED: id=${anim.id}, ticket=$ticket, reason=ctrl guard rejected (mounted=$mounted, playing=$_isFullScreenPlaying, cur=${_currentFullScreenAnim?.id})");
          return;
        }
        if (ctrl == null) {
          debugPrint("[VAP_TRACE] playFile REFUSED: id=${anim.id}, ticket=$ticket, reason=Controller not ready within timeout");
          _onFullScreenAnimationFinished(ticket);
          return;
        }

        // Call playFile with pre-cached path
        VapAnimation.preCache(anim.url).then((filePath) {
          if (!mounted || !_isFullScreenPlaying || _currentFullScreenAnim?.id != anim.id || _currentFullScreenTicket != ticket) {
            debugPrint("[VAP_TRACE] playFile REFUSED: id=${anim.id}, ticket=$ticket, reason=preCache guard rejected (mounted=$mounted, playing=$_isFullScreenPlaying, cur=${_currentFullScreenAnim?.id})");
            return;
          }
          if (filePath != null && File(filePath).existsSync()) {
            final realDuration = SvgaParserUtil.getRealOrFallbackVapDurationSync(filePath);
            final effectiveDuration = realDuration > 0 ? realDuration : duration;
            // Safety watchdog timer (+1500ms safety buffer; normal completion is driven by onVideoComplete on exact last frame)
            _armFullScreenSafetyTimer(effectiveDuration + 1500, ticket);
            debugPrint("[VAP_TRACE] playFile requested: id=${anim.id}, ticket=$ticket, path=$filePath, durationMs=$effectiveDuration (real=$realDuration)");
            ctrl.playFile(filePath, anim.id, ticket).catchError((e) {
              debugPrint("[VAP_TRACE] onFail: id=${anim.id}, ticket=$ticket, error=$e");
              if (_currentFullScreenTicket == ticket) {
                _onFullScreenAnimationFinished(ticket);
              }
            });
            // soundUrl fallback: only when this .vap carries no audio track.
            // Runs after playFile so the TTFF path never waits on a file read.
            final String soundUrl = anim.soundUrl?.trim() ?? '';
            if (soundUrl.isNotEmpty) {
              mp4HasAudioTrack(filePath).then((hasAudio) {
                if (hasAudio || !mounted || !_isFullScreenPlaying ||
                    _currentFullScreenAnim?.id != anim.id || _currentFullScreenTicket != ticket) {
                  return;
                }
                debugPrint("[GiftAudio] VAP has no audio track, playing soundUrl: $soundUrl");
                if (soundUrl.startsWith('http')) {
                  _GiftAudioPool.playUrl(soundUrl);
                } else if (soundUrl.startsWith('assets/')) {
                  _GiftAudioPool.playAsset(soundUrl);
                }
              });
            }
          } else {
            debugPrint("[VAP_TRACE] playFile REFUSED: id=${anim.id}, ticket=$ticket, reason=Cache failed / file missing for ${anim.url}");
            if (_currentFullScreenTicket == ticket) {
              _onFullScreenAnimationFinished(ticket);
            }
          }
        }).catchError((e) {
          debugPrint("[VAP_TRACE] playFile REFUSED: id=${anim.id}, ticket=$ticket, reason=preCache error: $e");
          if (_currentFullScreenTicket == ticket) {
            _onFullScreenAnimationFinished(ticket);
          }
        });
      });
    } else {
      final int duration = anim.durationMs > 0 ? anim.durationMs : 5000;
      _armFullScreenSafetyTimer(duration + 1500, ticket);
    }
  }

  void _armFullScreenSafetyTimer(int ms, [int? ticket]) {
    _fullScreenWatchdogTimer?.cancel();
    _fullScreenWatchdogTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted && _isFullScreenPlaying) {
        if (ticket != null && ticket < _currentFullScreenTicket) {
          debugPrint("[VAP_TRACE] watchdog dropped: stale ticket $ticket < current $_currentFullScreenTicket");
          return;
        }
        debugPrint("[VAP_TRACE] WATCHDOG FIRED: id=${_currentFullScreenAnim?.id}, ticket=$ticket, safety timeout ${ms}ms elapsed - stopping persistent VAP controller and awaiting release signal");
        _handleWatchdogTimeout(ticket);
      }
    });
  }

  void _handleWatchdogTimeout([int? ticket]) {
    if (!mounted) return;
    if (ticket != null && ticket < _currentFullScreenTicket) {
      return;
    }

    setState(() {
      _vapOpacity = 0.0;
      _currentFullScreenAnim = null;
    });

    try {
      _persistentVapController?.stop();
    } catch (e) {
      debugPrint("[VAP_TRACE] Error calling stop on persistent VAP controller: $e");
    }

    // Wait for the release signal before the next gift starts
    _waitingForReleaseTicket = ticket;
    _releaseFallbackTimer?.cancel();
    _releaseFallbackTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _waitingForReleaseTicket == ticket) {
        debugPrint("[VAP_TRACE] release signal fallback timeout (300ms) reached after watchdog for ticket $ticket");
        _waitingForReleaseTicket = null;
        _onFullScreenAnimationFinished(ticket);
      }
    });
  }

  void _onFullScreenAnimationFinished([int? ticket]) {
    if (!mounted) return;
    if (ticket != null && ticket < _currentFullScreenTicket) {
      debugPrint("[VAP_TRACE] _onFullScreenAnimationFinished dropped: ticket $ticket < current $_currentFullScreenTicket");
      return;
    }
    // Guard: prevent double transition when both onVideoComplete and the watchdog
    // fire in the same Choreographer sync-barrier window.
    if (!_isFullScreenPlaying && _currentFullScreenAnim == null) {
      debugPrint("[VAP_TRACE] _onFullScreenAnimationFinished no-op: already dismissed (ticket=$ticket)");
      return;
    }
    _fullScreenWatchdogTimer?.cancel();
    _transitionTimer?.cancel();
    _releaseFallbackTimer?.cancel();
    _waitingForReleaseTicket = null;

    final current = _currentFullScreenAnim;
    if (current != null && current.remainingPlays > 1) {
      final nextPlayIndex = current.currentPlayIndex + 1;
      final nextRemaining = current.remainingPlays - 1;
      debugPrint("[GiftQueue] Repeating combo play: ${current.giftName} (play $nextPlayIndex of ${current.totalPlays}, $nextRemaining remaining) for sender ${current.senderUid}");

      final nextAnim = current.copyWith(
        remainingPlays: nextRemaining,
        currentPlayIndex: nextPlayIndex,
        text: '${current.giftName} x$nextPlayIndex',
      );

      setState(() {
        _vapOpacity = 0.0; // Immediately drop VAP view opacity between repeat combo plays
        _currentFullScreenAnim = nextAnim;
      });

      final comboKey = current.targetUid != null && current.targetUid!.isNotEmpty && current.giftId.isNotEmpty
          ? comboKeyFor(current.senderUid, current.targetUid!, current.giftId)
          : null;
      if (comboKey != null) {
        ref.read(giftComboControllerProvider(widget.roomId)).touch(comboKey);
      }

      // 100ms grace window for GPU surface reset before starting the next play
      _transitionTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && !_isAppPaused) {
          _playFullScreenGift(nextAnim);
        }
      });
      return;
    }

    setState(() {
      _vapOpacity = 0.0;
      _currentFullScreenAnim = null;
      _isFullScreenPlaying = false;
    });

    // 40ms grace window for GPU surface reset before picking the next queued gift
    _transitionTimer = Timer(const Duration(milliseconds: 40), () {
      if (mounted && !_isAppPaused) {
        _checkNextFullScreenAnimation();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fullScreenWatchdogTimer?.cancel();
    _transitionTimer?.cancel();
    _releaseFallbackTimer?.cancel();
    _waitingForReleaseTicket = null;
    for (final sg in _currentSeatGifts.values) {
      sg.expiryTimer.cancel();
    }
    _currentSeatGifts.clear();
    _seatQueues.clear();
    _luxuryQueue.clear();
    _mediumQueue.clear();
    _GiftAudioPool.stop();
    try {
      _persistentVapController?.stop();
      _persistentVapController?.dispose();
    } catch (e) {
      debugPrint("[VAP] Error disposing persistent controller: $e");
    }
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

    ref.listen(isRocketActiveProvider(widget.roomId), (prev, isRocket) {
      if (prev == true && isRocket == false) {
        _checkNextFullScreenAnimation();
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

      const giftSize = 220.0;
      final Size overlaySize = (overlayBox is RenderBox && overlayBox.attached && overlayBox.hasSize)
          ? overlayBox.size
          : MediaQuery.sizeOf(context);
      final centerPoint = overlaySize.center(Offset.zero);

      Offset targetCenter = centerPoint;
      if (seatRect != null && overlayBox is RenderBox && overlayBox.attached && overlayBox.hasSize) {
        final localTopLeft = overlayBox.globalToLocal(seatRect.topLeft);
        targetCenter = localTopLeft + Offset(seatRect.width / 2, seatRect.height * 0.25);
      } else {
        // Fallback for unseated recipient: position in upper-middle area
        targetCenter = Offset(overlaySize.width * 0.5, overlaySize.height * 0.32);
      }

      // Resolve origin coordinates from the sender
      Offset startCenter;
      final senderRect = seatGift.animation.senderUid.isNotEmpty
          ? SeatAnchors.rectFor(widget.roomId, seatGift.animation.senderUid)
          : null;
      if (senderRect != null && overlayBox is RenderBox && overlayBox.attached && overlayBox.hasSize) {
        final localSenderTopLeft = overlayBox.globalToLocal(senderRect.topLeft);
        startCenter = localSenderTopLeft + Offset(senderRect.width / 2, senderRect.height * 0.25);
      } else {
        // Sender is in the audience or tapping from the bottom quick send combo bar / gift button
        startCenter = Offset(overlaySize.width * 0.82, overlaySize.height - 75);
      }

      // If sender and target happen to be at the exact same coordinates (e.g. self-gifting):
      if ((startCenter - targetCenter).distance < 40) {
        startCenter = Offset(overlaySize.width * 0.82, overlaySize.height - 75);
      }

      final bool hasWaiting = (_seatQueues[targetKey]?.isNotEmpty == true);

      seatWidgets.add(
        _SeatGiftFlight(
          key: ValueKey('seat_flight_${seatGift.id}'),
          from: startCenter,
          to: targetCenter,
          size: giftSize,
          animateFlight: !seatGift.hasFlown,
          child: RepaintBoundary(
            key: ValueKey('seat_gift_boundary_${seatGift.id}'),
            child: IgnorePointer(
              key: ValueKey('seat_gift_${seatGift.id}'),
              child: _HeldGiftPlayer(
                key: ValueKey('held_player_${seatGift.id}'),
                animation: seatGift.animation,
                isFastCadence: hasWaiting,
                onComplete: () => _onSeatAnimationFinished(targetKey, seatGift.id),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      key: _overlayKey,
      children: [
        widget.child,
        // Layer 1 - NORMAL: Sequential queued seat gift animations (isolated in RepaintBoundary)
        ...seatWidgets,

        // Layer 2: Persistent VAP Player (created on room enter, warm and persistent, released on room exit)
        // Wrapped in RepaintBoundary and Opacity(_vapOpacity). When idle (_vapOpacity == 0.0),
        // Flutter skips painting entirely (layer = null), avoiding GPU work while keeping
        // the native TextureView warm at full screen resolution (never collapses to 0x0).
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: RepaintBoundary(
              child: Opacity(
                opacity: _vapOpacity,
                child: VapView(
                  scaleType: ScaleType.fitCenter,
                  repeat: 0,
                  mute: kMuteVapAudio,
                  onViewCreated: _setupPersistentVapController,
                ),
              ),
            ),
          ),
        ),

        // Layer 3: Non-VAP Medium & Luxury room animations (SVGA / Lottie / Image)
        if (_isFullScreenPlaying && _currentFullScreenAnim != null && _currentFullScreenAnim!.format != 'vap')
          _buildNonVapAnimationItem(_currentFullScreenAnim!),

        // Layer 4: Combo Overlay banner (direct child of Stack, self-isolating)
        GiftComboOverlay(roomId: widget.roomId),
      ],
    );
  }

  Widget _buildNonVapAnimationItem(_ActiveGiftAnimation anim) {
    // MEDIUM/LUXURY get a hold wrapper: gift-icon base always visible,
    // Lottie loops until hold expires, audio gets full time before dispose.
    final player = RepaintBoundary(
      key: ValueKey('room_anim_boundary_${anim.id}_p${anim.currentPlayIndex}'),
      child: IgnorePointer(
        key: ValueKey('${anim.id}_p${anim.currentPlayIndex}'),
        child: _HeldRoomPlayer(
          key: ValueKey('${anim.id}_p${anim.currentPlayIndex}'),
          animation: anim,
          onComplete: _onFullScreenAnimationFinished,
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

/// Flies a seat gift from the sender / bottom bar to the receiver's seat anchor along a curved parabolic trajectory.
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
  late final Animation<double> _flightCurve;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animateFlight ? 480 : 0),
    );

    _flightCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    );

    // Scale from 0.35 at launch to 1.12 near arrival, settling smoothly to 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.35, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 85,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 15,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {});
      }
    });

    if (widget.animateFlight) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_SeatGiftFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.to != widget.to && (!widget.animateFlight || _controller.isCompleted)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _computePosition(double t) {
    if (!widget.animateFlight || t >= 1.0) {
      return widget.to;
    }

    final double oneMinusT = 1.0 - t;
    final double dxDiff = widget.to.dx - widget.from.dx;
    final double midX = (widget.from.dx + widget.to.dx) / 2;

    // Upward parabolic arc lift
    final double dyDiff = (widget.from.dy - widget.to.dy).abs();
    final double arcLift = math.max(60.0, math.min(140.0, dyDiff * 0.30));

    // Lateral curve: slight outward deflection so the path feels natural and dynamic
    final double lateralBend = dxDiff.abs() > 40 ? (dxDiff > 0 ? -25.0 : 25.0) : 0.0;

    final controlPoint = Offset(
      midX + lateralBend,
      math.min(widget.from.dy, widget.to.dy) - arcLift,
    );

    final double posX = oneMinusT * oneMinusT * widget.from.dx +
        2 * oneMinusT * t * controlPoint.dx +
        t * t * widget.to.dx;
    final double posY = oneMinusT * oneMinusT * widget.from.dy +
        2 * oneMinusT * t * controlPoint.dy +
        t * t * widget.to.dy;

    return Offset(posX, posY);
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.to;
    // When flight finishes or if flight is disabled, render pure Positioned without any Transform.
    if (!widget.animateFlight || _controller.isCompleted) {
      return Positioned(
        left: center.dx - widget.size / 2,
        top: center.dy - widget.size / 2,
        width: widget.size,
        height: widget.size,
        child: widget.child,
      );
    }

    // Hardware-accelerated flight: Positioned stays static at destination to avoid per-frame Stack.performLayout.
    // Movement is performed purely via GPU Transform.translate.
    return Positioned(
      left: center.dx - widget.size / 2,
      top: center.dy - widget.size / 2,
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _flightCurve.value;
          final currentPos = _computePosition(t);
          final scale = _scaleAnimation.value;
          final offset = currentPos - widget.to;

          return Transform.translate(
            offset: offset,
            child: Transform.scale(
              alignment: Alignment.center,
              scale: scale,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _ActiveGiftAnimation {
  final String id;
  final String giftId;
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

  final int comboCount;
  final int totalPlays;
  final int remainingPlays;
  final int currentPlayIndex;

  _ActiveGiftAnimation({
    required this.id,
    this.giftId = '',
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
    this.comboCount = 1,
    int? totalPlays,
    int? remainingPlays,
    this.currentPlayIndex = 1,
  })  : totalPlays = totalPlays ?? comboCount,
        remainingPlays = remainingPlays ?? (totalPlays ?? comboCount);

  _ActiveGiftAnimation copyWith({
    String? id,
    String? giftId,
    String? url,
    String? senderUid,
    String? text,
    String? imageUrl,
    String? soundUrl,
    String? format,
    String? giftCategory,
    String? giftName,
    String? targetUid,
    String? tier,
    int? durationMs,
    int? comboCount,
    int? totalPlays,
    int? remainingPlays,
    int? currentPlayIndex,
  }) {
    return _ActiveGiftAnimation(
      id: id ?? this.id,
      giftId: giftId ?? this.giftId,
      url: url ?? this.url,
      senderUid: senderUid ?? this.senderUid,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      soundUrl: soundUrl ?? this.soundUrl,
      format: format ?? this.format,
      giftCategory: giftCategory ?? this.giftCategory,
      giftName: giftName ?? this.giftName,
      targetUid: targetUid ?? this.targetUid,
      tier: tier ?? this.tier,
      durationMs: durationMs ?? this.durationMs,
      comboCount: comboCount ?? this.comboCount,
      totalPlays: totalPlays ?? this.totalPlays,
      remainingPlays: remainingPlays ?? this.remainingPlays,
      currentPlayIndex: currentPlayIndex ?? this.currentPlayIndex,
    );
  }
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

  _ActiveSeatGift copyWith({
    String? id,
    String? targetUid,
    _ActiveGiftAnimation? animation,
    Timer? expiryTimer,
    bool? hasFlown,
  }) {
    return _ActiveSeatGift(
      id: id ?? this.id,
      targetUid: targetUid ?? this.targetUid,
      animation: animation ?? this.animation,
      expiryTimer: expiryTimer ?? this.expiryTimer,
      hasFlown: hasFlown ?? this.hasFlown,
    );
  }
}

/// Seat-anchored NORMAL gift player: golden aura + elastic bounce + minimum
/// on-screen hold so short Lottie/SVGA clips are always perceivable.
class _HeldGiftPlayer extends StatefulWidget {
  final _ActiveGiftAnimation animation;
  final VoidCallback onComplete;
  final bool isFastCadence;

  const _HeldGiftPlayer({
    super.key,
    required this.animation,
    required this.onComplete,
    this.isFastCadence = false,
  });

  @override
  State<_HeldGiftPlayer> createState() => _HeldGiftPlayerState();
}

class _HeldGiftPlayerState extends State<_HeldGiftPlayer> {
  static const int kMinHoldMs = 1200;
  static const int kSafetyCapMs = 20000;
  Timer? _holdTimer;
  Timer? _safetyTimer;
  bool _released = false;
  bool _holdElapsed = false;
  bool _innerDone = false;

  @override
  void initState() {
    super.initState();
    final int minHold = widget.isFastCadence ? 650 : kMinHoldMs;
    final int hold = math.max(widget.animation.durationMs, minHold);
    _holdTimer = Timer(Duration(milliseconds: hold), () {
      _holdElapsed = true;
      _tryRelease();
    });
    _safetyTimer = Timer(Duration(milliseconds: math.max(hold + 8000, kSafetyCapMs)), _release);
  }

  void _release() {
    if (_released || !mounted) return;
    _released = true;
    _holdTimer?.cancel();
    _safetyTimer?.cancel();
    widget.onComplete();
  }

  /// Release only when inner animation has completed and minimum hold elapsed,
  /// or immediately in fast cadence mode. Never kill an animation mid-play.
  void _tryRelease() {
    if (_released) return;
    if (_innerDone || widget.isFastCadence) {
      if (_holdElapsed || widget.isFastCadence) {
        _release();
      }
    }
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
    // them blanks the content on Android. Clean direct rendering without blurry hazy aura.
    return SizedBox(
      width: 200,
      height: 200,
      child: RepaintBoundary(
        child: _GiftAnimationPlayer(
          key: ValueKey('held_${widget.animation.id}'),
          animation: widget.animation,
          onComplete: _onInnerComplete,
        ),
      ),
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
  bool _holdElapsed = false;
  bool _innerDone = false;

  late final int _minHoldMs = math.max(
    math.max(widget.animation.durationMs, 0),
    widget.animation.tier == 'LUXURY' ? 7000 : 5000,
  );

  // Long-form formats may release as soon as the inner player is done.
  late final bool _isLongFormat = widget.animation.format == 'vap' ||
      widget.animation.format == 'svga' ||
      widget.animation.durationMs > 3000;

  @override
  void initState() {
    super.initState();
    _armTimers();
  }

  void _armTimers() {
    _holdTimer?.cancel();
    _maxLifeTimer?.cancel();
    _holdElapsed = false;
    _holdTimer = Timer(Duration(milliseconds: _minHoldMs), () {
      _holdElapsed = true;
      _tryRelease();
    });
    // Hard safety net: never leave a PlatformView mounted forever.
    _maxLifeTimer = Timer(
      Duration(milliseconds: math.max(_minHoldMs + 8000, 25000)),
      _release,
    );
  }

  // Restart the hold window once the native player actually starts rendering.
  void _onPlayerStarted() {
    if (!_released && mounted) _armTimers();
  }

  void _onInnerComplete() {
    _innerDone = true;
    _tryRelease();
  }

  void _tryRelease() {
    if (_released || !_innerDone) return;
    if (_holdElapsed || _isLongFormat) _release();
  }

  void _release() {
    if (_released || !mounted) return;
    _released = true;
    _holdTimer?.cancel();
    _maxLifeTimer?.cancel();
    // Unmount directly: no AnimatedOpacity/Opacity layers over the PlatformView.
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
    // VapAnimation already wraps its view in a RepaintBoundary.
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
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _playSound();
  }

  void _playSound() async {
    final soundUrl = widget.animation.soundUrl?.trim() ?? '';
    if (soundUrl.isNotEmpty) {
      // VAP-family animations may play their own embedded AAC — skip
      // soundUrl only when the resolved file actually carries an audio
      // track. Match the URL too: the format tag can be stale while the
      // player keys off the extension.
      final fmt = widget.animation.format.toLowerCase();
      final urlLc = widget.animation.url.toLowerCase();
      if (fmt == 'vap' || fmt == 'vpa' || fmt == 'mp4' || fmt == 'pag' ||
          urlLc.contains('.vap') || urlLc.contains('.vpa') ||
          urlLc.contains('.mp4') || urlLc.contains('.pag')) {
        if (_isDisposed) return;
        // Resolve exactly what _VapNetworkPlayer will play (local asset
        // override first), then verify its audio track.
        final String url = widget.animation.url.trim();
        final String effectiveGId = widget.animation.giftId.isNotEmpty
            ? widget.animation.giftId
            : widget.animation.id;
        final localVap = SvgaParserUtil.getLocalVapPath(url,
            giftId: effectiveGId, giftName: widget.animation.giftName);
        final local = await VapAnimation.preCache(localVap ?? url);
        if (_isDisposed) return;
        if (local != null && await mp4HasAudioTrack(local)) return;
        // File has no audio track (or couldn't be read): fall through and
        // play soundUrl so the gift isn't silent.
      }
      try {
        if (_isDisposed) return;
        if (soundUrl.startsWith('http')) {
          await _GiftAudioPool.playUrl(soundUrl);
        } else if (soundUrl.startsWith('assets/')) {
          await _GiftAudioPool.playAsset(soundUrl);
        }
      } catch (e) {
        debugPrint("[GiftAudio] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
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

    // Build the format-specific player directly without blurry aura
    return _buildFormatPlayer(url, lowerUrl, fmt, hasCustomSound);
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
    if (
        (lowerUrl.contains('.vap') ||
        lowerUrl.contains('.vpa') ||
        lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.pag') ||
        fmt == 'vap' ||
        fmt == 'vpa' ||
        fmt == 'mp4' ||
        fmt == 'pag')) {
      final effectiveGId = widget.animation.giftId.isNotEmpty ? widget.animation.giftId : widget.animation.id;
      final localVap = SvgaParserUtil.getLocalVapPath(url, giftId: effectiveGId, giftName: giftName);
      return _VapNetworkPlayer(
        key: ValueKey('${widget.animation.id}_vap'),
        animationId: widget.animation.id,
        url: localVap ?? url,
        fallbackImageUrl: widget.animation.imageUrl,
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
  final String? animationId;
  final String? fallbackImageUrl;
  final int durationMs;
  /// If > 0, hold player alive for at least this long (luxury/medium full duration).
  final int holdMs;
  final VoidCallback onComplete;
  final VoidCallback onError;
  final VoidCallback? onStart;

  const _VapNetworkPlayer({
    super.key,
    required this.url,
    this.animationId,
    this.fallbackImageUrl,
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
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    final bool isLocal = !widget.url.startsWith('http');
    final int baseMs = widget.durationMs > 0
        ? widget.durationMs
        : (widget.holdMs > 0 ? widget.holdMs : 6000);
    final int startupMs = isLocal ? baseMs + 800 : math.max(baseMs + 2000, 5000);
    _timer = Timer(Duration(milliseconds: startupMs), () {
      if (mounted) setState(() => _opacity = 0.0);
      widget.onComplete();
    });
  }

  void _onStart() {
    if (mounted && _opacity != 1.0) {
      setState(() => _opacity = 1.0);
    }
    widget.onStart?.call();
    _timer?.cancel();
    // Safety watchdog: only triggers if native VAP player fails to send onVideoComplete.
    final int expected = widget.durationMs > 0
        ? widget.durationMs
        : (widget.holdMs > 0 ? widget.holdMs : 6000);
    final int ms = expected + 1500;
    _timer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _opacity = 0.0);
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: _opacity,
        child: VapAnimation(
          key: ValueKey('vap_anim_${widget.animationId ?? widget.url}'),
          assetPath: widget.url,
          fallbackImageUrl: widget.fallbackImageUrl,
          onComplete: () {
            if (mounted) setState(() => _opacity = 0.0);
            widget.onComplete();
          },
          onError: () {
            if (mounted) setState(() => _opacity = 0.0);
            widget.onError();
          },
          onStart: _onStart,
        ),
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
          // 1. Floating sparkles / stars around gift
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
                color: Colors.white.withValues(alpha: 0.5),
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
      durationMs + 1200,
      widget.holdMs > 0 ? widget.holdMs + 1000 : 0,
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
    final audio = preparedAudios.first;
    if (audio.delayMs > 0) {
      final timer = Timer(Duration(milliseconds: audio.delayMs), () async {
        if (!_isDisposed && mounted) {
          await _GiftAudioPool.playFile(audio.file.path);
        }
      });
      _audioTimers.add(timer);
    } else {
      _GiftAudioPool.playFile(audio.file.path);
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
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
                      : img.startsWith('assets/')
                          ? Image.asset(
                              img,
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
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
      durationMs + 1200,
      widget.holdMs > 0 ? widget.holdMs + 1000 : 0,
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
        durationMs + 1200,
        widget.holdMs > 0 ? widget.holdMs + 1000 : 0,
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
    final audio = preparedAudios.first;
    if (audio.delayMs > 0) {
      final timer = Timer(Duration(milliseconds: audio.delayMs), () async {
        if (!_isDisposed && mounted) {
          await _GiftAudioPool.playFile(audio.file.path);
        }
      });
      _audioTimers.add(timer);
    } else {
      _GiftAudioPool.playFile(audio.file.path);
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

  // Remote mixkit URLs return 403 Forbidden and stall audio; use empty map
  static const Map<String, String> _lottieGiftSounds = {};

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
          await _GiftAudioPool.playFile(file.path);
        }
      } catch (e) {
        debugPrint("[LottiePlayer] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
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
          await _GiftAudioPool.playFile(file.path);
        }
      } catch (e) {
        debugPrint("[LottieLocalPlayer] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
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
