import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello_chat/core/widgets/vap_player.dart';
import 'bell_winning_dialog.dart';
import '../../../../core/utils/app_persistent_cache.dart';
import '../../../../core/models/gift_model.dart';
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
  List<GiftModel> _gifts = [];

  @override
  void initState() {
    super.initState();
  }

  void _preloadGifts() async {
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
          if (url.toLowerCase().contains('.svga')) {
            final localPath = SvgaParserUtil.getLocalGiftSvgaPath(url);
            if (localPath != null) {
              SvgaParserUtil.decodeSafeFromAssets(localPath);
            }
          } else {
            final localLottie = SvgaParserUtil.getLocalLottiePath(url);
            if (localLottie != null) {
              LottieCache.preloadLocal(localLottie);
            }
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
        
        final giftUrl = msg.animationUrl!.trim();
        String? imageUrl;
        String? soundUrl;
        String format = 'json';
        String category = 'Normal';
        String giftName = '';

        try {
          final matchedGift = _gifts.firstWhere(
            (g) => g.lottieAssetPath.trim() == giftUrl || g.imageUrl.trim() == giftUrl,
          );
          imageUrl = matchedGift.imageUrl;
          soundUrl = matchedGift.soundUrl;
          format = matchedGift.animationFormat;
          category = matchedGift.category;
          giftName = matchedGift.name;
        } catch (_) {
          // Fallback inference if gift not preloaded
          if (giftUrl.toLowerCase().contains('.svga')) format = 'svga';
          else if (giftUrl.toLowerCase().contains('.vpa') || giftUrl.toLowerCase().contains('.mp4')) format = 'mp4';
          else if (giftUrl.toLowerCase().contains('.png') || giftUrl.toLowerCase().contains('.jpg') || giftUrl.toLowerCase().contains('.webp') || giftUrl.toLowerCase().contains('.gif')) format = 'image';
        }

        final qty = msg.quantity;
        for (int i = 0; i < qty; i++) {
          final anim = _ActiveGiftAnimation(
            id: "${msg.msgId}_$i",
            url: msg.animationUrl!,
            senderUid: msg.uid,
            text: msg.text,
            imageUrl: imageUrl,
            soundUrl: soundUrl,
            format: format,
            giftCategory: category,
            giftName: giftName,
          );
          
          // Prevent queue from growing indefinitely (cap at 50 items for spam protection)
          if (_pendingQueue.length < 50) {
            _pendingQueue.add(anim);
            changed = true;
          }
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
        if (_currentAnimation != null)
          Positioned.fill(
            child: _buildAnimationItem(_currentAnimation!),
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
            // Full screen animation player (Lottie, SVGA, VAP, MP4, Image, Sound)
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
  final String? imageUrl;
  final String? soundUrl;
  final String format;
  final String giftCategory;
  final String giftName;
  final String? targetUid;

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
  });
}

class _GiftNotificationBanner extends ConsumerWidget {
  final String uid;
  final String text;

  const _GiftNotificationBanner({required this.uid, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(cachedUserProfileProvider(uid));

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
  bool _hasError = false;
  AudioPlayer? _audioPlayer;

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
        if (soundUrl.startsWith('http')) {
          await _audioPlayer?.play(UrlSource(soundUrl));
        } else if (soundUrl.startsWith('assets/')) {
          await _audioPlayer?.play(AssetSource(soundUrl.replaceFirst('assets/', '')));
        }
      } catch (e) {
        debugPrint("[GiftAudio] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _handleError() {
    if (mounted) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _FallbackImagePlayer(
        imageUrl: widget.animation.imageUrl,
        onComplete: widget.onComplete,
      );
    }

    final url = widget.animation.url.trim();
    final lowerUrl = url.toLowerCase();
    final fmt = widget.animation.format.toLowerCase();

    // 1. SVGA Animation Format
    if (lowerUrl.endsWith('.svga') || fmt == 'svga') {
      final localPath = SvgaParserUtil.getLocalGiftSvgaPath(url);
      if (localPath != null) {
        return _SvgaLocalPlayer(
          assetPath: localPath,
          onComplete: widget.onComplete,
          onError: _handleError,
        );
      }
      return _SvgaNetworkPlayer(
        url: url,
        onComplete: widget.onComplete,
        onError: _handleError,
      );
    }

    // 2. VPA / MP4 Video Format
    if (lowerUrl.endsWith('.vpa') || lowerUrl.endsWith('.mp4') || fmt == 'vpa' || fmt == 'mp4') {
      return _VapNetworkPlayer(
        url: url,
        onComplete: widget.onComplete,
        onError: _handleError,
      );
    }

    // 3. Static / Animated Image Format (PNG, JPG, WEBP, GIF)
    if (lowerUrl.endsWith('.png') || lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg') || lowerUrl.endsWith('.gif') || lowerUrl.endsWith('.webp') || fmt == 'image') {
      return _ImageGiftPlayer(
        imageUrl: url.isNotEmpty ? url : (widget.animation.imageUrl ?? ''),
        onComplete: widget.onComplete,
      );
    }

    // 4. Lottie JSON Format (Default)
    final localLottiePath = SvgaParserUtil.getLocalLottiePath(url);
    if (localLottiePath != null) {
      return Center(
        child: _LottieLocalPlayer(
          assetPath: localLottiePath,
          originalUrl: url,
          onComplete: widget.onComplete,
          onError: _handleError,
        ),
      );
    }

    return Center(
      child: _LottieNetworkPlayer(
        url: url,
        onComplete: widget.onComplete,
        onError: _handleError,
      ),
    );
  }
}

class _VapNetworkPlayer extends StatefulWidget {
  final String url;
  final VoidCallback onComplete;
  final VoidCallback onError;

  const _VapNetworkPlayer({
    required this.url,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<_VapNetworkPlayer> createState() => _VapNetworkPlayerState();
}

class _VapNetworkPlayerState extends State<_VapNetworkPlayer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Safety completion timer for VAP video duration (default 4.5 seconds)
    _timer = Timer(const Duration(milliseconds: 4500), widget.onComplete);
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
        assetPath: widget.url,
        onComplete: widget.onComplete,
      ),
    );
  }
}

class _ImageGiftPlayer extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onComplete;

  const _ImageGiftPlayer({
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<_ImageGiftPlayer> createState() => _ImageGiftPlayerState();
}

class _ImageGiftPlayerState extends State<_ImageGiftPlayer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3500), widget.onComplete);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Center(
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox(),
        errorWidget: (_, __, ___) => const SizedBox(),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fade(),
    );
  }
}

class _SvgaLocalPlayer extends StatefulWidget {
  final String assetPath;
  final VoidCallback onComplete;
  final VoidCallback onError;
  const _SvgaLocalPlayer({
    required this.assetPath,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<_SvgaLocalPlayer> createState() => _SvgaLocalPlayerState();
}

class _SvgaLocalPlayerState extends State<_SvgaLocalPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;
  Timer? _completeTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Timer> _audioTimers = [];

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }

  void _loadAnimation() async {
    try {
      final videoItem = await SvgaParserUtil.decodeSafeFromAssets(widget.assetPath);
      if (mounted) {
        setState(() {
          _controller?.videoItem = videoItem;
          _isLoading = false;
          _controller?.forward(from: 0.0);
        });

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

        _playEmbeddedAudios(videoItem, fps);

        final int durationMs = (frames > 0 && fps > 0)
            ? ((frames / fps) * 1000).toInt()
            : 6500;

        debugPrint("[SVGAPlayer] Playing local SVGA: ${widget.assetPath} for duration: ${durationMs}ms (frames: $frames, fps: $fps)");

        _completeTimer?.cancel();
        _completeTimer = Timer(Duration(milliseconds: durationMs), () {
          if (mounted) {
            widget.onComplete();
          }
        });
      }
    } catch (e) {
      debugPrint("Error parsing local SVGA: $e");
      widget.onError();
    }
  }

  void _playEmbeddedAudios(dynamic videoItem, int fps) async {
    try {
      final movieItem = (videoItem as dynamic).movieItem;
      if (movieItem == null) return;
      
      final audios = movieItem.audios;
      final images = movieItem.images;
      
      if (audios != null && audios.isNotEmpty && images != null && fps > 0) {
        final tempDir = await getTemporaryDirectory();
        for (final audio in audios) {
          final String audioKey = audio.audioKey;
          final bytes = images[audioKey];
          if (bytes != null && bytes.isNotEmpty) {
            final tempFile = File('${tempDir.path}/svga_audio_${audioKey}');
            if (!await tempFile.exists()) {
              await tempFile.writeAsBytes(bytes);
            }
            
            final int delayMs = (audio.startFrame / fps * 1000).toInt();
            if (delayMs > 0) {
              final timer = Timer(Duration(milliseconds: delayMs), () async {
                if (mounted && _controller?.isAnimating == true) {
                  try {
                    await _audioPlayer.stop();
                    await _audioPlayer.play(DeviceFileSource(tempFile.path));
                  } catch (ae) {
                    debugPrint("[SVGAPlayer] Error playing SVGA temp audio: $ae");
                  }
                }
              });
              _audioTimers.add(timer);
            } else {
              try {
                await _audioPlayer.stop();
                await _audioPlayer.play(DeviceFileSource(tempFile.path));
              } catch (ae) {
                debugPrint("[SVGAPlayer] Error playing SVGA temp audio: $ae");
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("[SVGAPlayer] Failed to extract/play embedded SVGA audio: $e");
    }
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    for (final timer in _audioTimers) {
      timer.cancel();
    }
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
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: SVGAImage(
        _controller!,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _FallbackImagePlayer extends StatefulWidget {
  final String? imageUrl;
  final VoidCallback onComplete;
  const _FallbackImagePlayer({required this.imageUrl, required this.onComplete});

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
  final VoidCallback onComplete;
  final VoidCallback onError;
  const _SvgaNetworkPlayer({
    required this.url,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<_SvgaNetworkPlayer> createState() => _SvgaNetworkPlayerState();
}

class _SvgaNetworkPlayerState extends State<_SvgaNetworkPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;
  Timer? _completeTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Timer> _audioTimers = [];

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
          _controller?.forward(from: 0.0);
        });

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

        _playEmbeddedAudios(videoItem, fps);

        final int durationMs = (frames > 0 && fps > 0)
            ? ((frames / fps) * 1000).toInt()
            : 6500;

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
      widget.onError();
    }
  }

  void _playEmbeddedAudios(dynamic videoItem, int fps) async {
    try {
      final movieItem = (videoItem as dynamic).movieItem;
      if (movieItem == null) return;
      
      final audios = movieItem.audios;
      final images = movieItem.images;
      
      if (audios != null && audios.isNotEmpty && images != null && fps > 0) {
        final tempDir = await getTemporaryDirectory();
        for (final audio in audios) {
          final String audioKey = audio.audioKey;
          final bytes = images[audioKey];
          if (bytes != null && bytes.isNotEmpty) {
            final tempFile = File('${tempDir.path}/svga_audio_${audioKey}');
            if (!await tempFile.exists()) {
              await tempFile.writeAsBytes(bytes);
            }
            
            final int delayMs = (audio.startFrame / fps * 1000).toInt();
            if (delayMs > 0) {
              final timer = Timer(Duration(milliseconds: delayMs), () async {
                if (mounted && _controller?.isAnimating == true) {
                  try {
                    await _audioPlayer.stop();
                    await _audioPlayer.play(DeviceFileSource(tempFile.path));
                  } catch (ae) {
                    debugPrint("[SVGAPlayer] Error playing SVGA temp audio: $ae");
                  }
                }
              });
              _audioTimers.add(timer);
            } else {
              try {
                await _audioPlayer.stop();
                await _audioPlayer.play(DeviceFileSource(tempFile.path));
              } catch (ae) {
                debugPrint("[SVGAPlayer] Error playing SVGA temp audio: $ae");
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("[SVGAPlayer] Failed to extract/play embedded SVGA audio: $e");
    }
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    for (final timer in _audioTimers) {
      timer.cancel();
    }
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
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: SVGAImage(
        _controller!,
        fit: BoxFit.contain,
      ),
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
  final VoidCallback onComplete;
  final VoidCallback onError;
  const _LottieNetworkPlayer({
    required this.url,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<_LottieNetworkPlayer> createState() => _LottieNetworkPlayerState();
}

class _LottieNetworkPlayerState extends State<_LottieNetworkPlayer> with SingleTickerProviderStateMixin {
  LottieComposition? _composition;
  bool _isLoading = true;
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
      if (mounted) {
        setState(() {
          _composition = composition;
          _isLoading = false;
          _controller.duration = composition.duration;
          _controller.forward().whenComplete(() {
            if (mounted) {
              widget.onComplete();
            }
          });
        });
        _playGiftSound();
      }
    } catch (e) {
      debugPrint("Error loading Lottie composition: $e");
      widget.onError();
    }
  }

  void _playGiftSound() async {
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
        await _audioPlayer.stop();
        final file = await AppPersistentCache.getFile(matchedSoundUrl);
        await _audioPlayer.play(DeviceFileSource(file.path));
      } catch (e) {
        debugPrint("[LottiePlayer] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
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
    return SizedBox.expand(
      child: Lottie(
        composition: _composition,
        controller: _controller,
        fit: BoxFit.contain,
        frameRate: FrameRate.composition,
      ),
    );
  }
}

class _LottieLocalPlayer extends StatefulWidget {
  final String assetPath;
  final String originalUrl;
  final VoidCallback onComplete;
  final VoidCallback onError;
  const _LottieLocalPlayer({
    required this.assetPath,
    required this.originalUrl,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<_LottieLocalPlayer> createState() => _LottieLocalPlayerState();
}

class _LottieLocalPlayerState extends State<_LottieLocalPlayer> with SingleTickerProviderStateMixin {
  LottieComposition? _composition;
  bool _isLoading = true;
  late final AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _loadAnimation();
  }

  void _loadAnimation() async {
    try {
      final composition = await LottieCache.loadLocal(widget.assetPath);
      if (mounted) {
        setState(() {
          _composition = composition;
          _isLoading = false;
          _controller.duration = composition.duration;
          _controller.forward().whenComplete(() {
            if (mounted) {
              widget.onComplete();
            }
          });
        });
        _playGiftSound();
      }
    } catch (e) {
      debugPrint("Error loading local Lottie composition: $e");
      widget.onError();
    }
  }

  void _playGiftSound() async {
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
        await _audioPlayer.stop();
        final file = await AppPersistentCache.getFile(matchedSoundUrl);
        await _audioPlayer.play(DeviceFileSource(file.path));
      } catch (e) {
        debugPrint("[LottieLocalPlayer] Error playing gift sound: $e");
      }
    }
  }

  @override
  void dispose() {
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
    return SizedBox.expand(
      child: Lottie(
        composition: _composition,
        controller: _controller,
        fit: BoxFit.contain,
        frameRate: FrameRate.composition,
      ),
    );
  }
}
