import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../services/gift_service.dart';

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
  final List<_ActiveGiftAnimation> _pendingQueue = [];
  _ActiveGiftAnimation? _currentAnimation;
  bool _isPlaying = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _preloadGifts();
  }

  void _preloadGifts() async {
    try {
      final gifts = await ref.read(giftServiceProvider).getGiftsFuture();
      for (final gift in gifts) {
        final url = gift.lottieAssetPath.trim();
        if (url.isNotEmpty && url.startsWith('http')) {
          if (url.toLowerCase().contains('.svga')) {
            debugPrint("[GiftCache] Preloading SVGA gift: ${gift.name} from $url");
            SvgaCache.preload(url);
          } else {
            debugPrint("[GiftCache] Preloading Lottie gift: ${gift.name} from $url");
            // Warm cache composition for Lottie compositions
            AssetLottie(url).load();
          }
        }
      }
    } catch (e) {
      debugPrint("[GiftCache] Error preloading gifts: $e");
    }
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
        
        final anim = _ActiveGiftAnimation(
          id: msg.msgId,
          url: msg.animationUrl!,
          senderUid: msg.uid,
          text: msg.text,
        );
        
        // Prevent queue from growing indefinitely (cap at 8 items for spam protection)
        if (_pendingQueue.length < 8) {
          _pendingQueue.add(anim);
          changed = true;
        }
      }
      _processedMessageIds.add(msg.msgId);
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

    // Safety fallback: force complete after 12 seconds in case onComplete fails to trigger
    _animationTimer?.cancel();
    _animationTimer = Timer(const Duration(seconds: 12), () {
      if (_isPlaying && mounted) {
        debugPrint("[GiftCache] Safety fallback timer fired.");
        _onAnimationFinished();
      }
    });
  }

  void _onAnimationFinished() {
    if (mounted) {
      _animationTimer?.cancel();
      setState(() {
        _currentAnimation = null;
        _isPlaying = false;
      });
      
      // Small 200ms transition delay before playing the next gift
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _triggerNextAnimation();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roomMessagesProvider(widget.roomId), (previous, next) {
      if (next.hasValue && next.value != null) {
        _handleMessages(next.value!);
      }
    });

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _currentAnimation != null
                ? _buildAnimationItem(_currentAnimation!)
                : const SizedBox.shrink(key: ValueKey('empty_gift_overlay')),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimationItem(_ActiveGiftAnimation anim) {
    return SizedBox.expand(
      key: ValueKey(anim.id),
      child: IgnorePointer(
        child: Stack(
          children: [
            // Full screen animation player (Lottie or SVGA)
            _GiftAnimationPlayer(
              animation: anim,
              onComplete: _onAnimationFinished,
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
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 1),
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
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
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

class _GiftAnimationPlayer extends StatefulWidget {
  final _ActiveGiftAnimation animation;
  final VoidCallback onComplete;

  const _GiftAnimationPlayer({
    required this.animation,
    required this.onComplete,
  });

  @override
  State<_GiftAnimationPlayer> createState() => _GiftAnimationPlayerState();
}

class _GiftAnimationPlayerState extends State<_GiftAnimationPlayer> {
  @override
  Widget build(BuildContext context) {
    final url = widget.animation.url.trim();
    final isSvga = url.toLowerCase().contains('.svga');

    return Center(
      child: isSvga
          ? _SvgaNetworkPlayer(
              url: url,
              onComplete: widget.onComplete,
            )
          : Lottie.network(
              url,
              repeat: false,
              fit: BoxFit.contain,
              frameRate: FrameRate.composition,
              onLoaded: (composition) {
                // Play for the exact composition duration
                Future.delayed(composition.duration, () {
                  if (mounted) {
                    widget.onComplete();
                  }
                });
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint("Lottie error: $error");
                // Immediately call onComplete so the queue doesn't get stuck!
                widget.onComplete();
                return const SizedBox.shrink(); 
              },
            ),
    );
  }
}

class _SvgaNetworkPlayer extends StatefulWidget {
  final String url;
  final VoidCallback onComplete;
  const _SvgaNetworkPlayer({required this.url, required this.onComplete});

  @override
  State<_SvgaNetworkPlayer> createState() => _SvgaNetworkPlayerState();
}

class _SvgaNetworkPlayerState extends State<_SvgaNetworkPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;
  Timer? _completeTimer;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }

  void _loadAnimation() async {
    try {
      final videoItem = await SvgaCache.load(widget.url);
      if (mounted) {
        setState(() {
          _controller?.videoItem = videoItem;
          _isLoading = false;
          _controller?.forward();
        });

        // Calculate duration precisely from SVGA videoItem params (frames and fps)
        int frames = 0;
        int fps = 0;
        try {
          final params = (videoItem as dynamic).params;
          if (params != null) {
            frames = params.frames;
            fps = params.fps;
          }
        } catch (e) {
          debugPrint("[SVGAPlayer] Failed to get SVGA frames/fps from params: $e");
        }

        final int durationMs = (frames > 0 && fps > 0)
            ? ((frames / fps) * 1000).toInt()
            : 6500; // Generous 6.5s fallback

        debugPrint("[SVGAPlayer] Playing SVGA: ${widget.url} for duration: ${durationMs}ms (frames: $frames, fps: $fps)");

        _completeTimer?.cancel();
        _completeTimer = Timer(Duration(milliseconds: durationMs), () {
          if (mounted) {
            widget.onComplete();
          }
        });
      }
    } catch (e) {
      debugPrint("Error parsing network SVGA: $e");
      widget.onComplete(); // Immediately complete so the queue doesn't get stuck!
    }
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _controller?.videoItem == null) {
      return const SizedBox.shrink();
    }
    return SizedBox.expand(
      child: SVGAImage(_controller!),
    );
  }
}

// ⚡ Global SVGA Memory Cache & Concurrency Lock preloader
class SvgaCache {
  static final Map<String, dynamic> _cache = {};
  static final Set<String> _loading = {};

  static Future<dynamic> load(String url) async {
    final cleanUrl = url.trim();
    if (_cache.containsKey(cleanUrl)) {
      return _cache[cleanUrl]!;
    }
    // Concurrency lock to prevent multiple downloads of the same asset
    while (_loading.contains(cleanUrl)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_cache.containsKey(cleanUrl)) {
        return _cache[cleanUrl]!;
      }
    }
    
    _loading.add(cleanUrl);
    try {
      final videoItem = await SVGAParser.shared.decodeFromURL(cleanUrl);
      _cache[cleanUrl] = videoItem;
      return videoItem;
    } finally {
      _loading.remove(cleanUrl);
    }
  }

  static void preload(String url) {
    load(url).catchError((e) {
      debugPrint("Background SVGA preloading failed for $url: $e");
    });
  }
}
