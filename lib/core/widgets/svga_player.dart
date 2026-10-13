import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

import 'package:hello_chat/core/utils/svga_parser_util.dart';

class _SkeletonShimmer extends StatefulWidget {
  final BoxFit fit;
  const _SkeletonShimmer({required this.fit});

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _shimmerController.value, 0),
              end: Alignment(-0.5 + 2.0 * _shimmerController.value, 0),
              colors: const [
                Color(0x0DFFFFFF), // white 0.05
                Color(0x26FFFFFF), // white 0.15
                Color(0x0DFFFFFF), // white 0.05
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class SvgaPlayer extends StatefulWidget {
  final String? assetPath;
  final String? url;
  final BoxFit fit;
  final bool loop;
  final String? fallbackImagePath;
  final double? maxFps;
  final Size? maxRenderSize;
  final bool pauseWhenInvisible;
  final bool playAudio;

  const SvgaPlayer({
    super.key,
    this.assetPath,
    this.url,
    this.fit = BoxFit.contain,
    this.loop = true,
    this.fallbackImagePath,
    this.maxFps,
    this.maxRenderSize,
    this.pauseWhenInvisible = false,
    this.playAudio = false,
  });

  @override
  State<SvgaPlayer> createState() => _SvgaPlayerState();
}

class _SvgaPlayerState extends State<SvgaPlayer> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  SVGAAnimationController? _controller;
  bool _hasError = false;
  bool _isLoading = true;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !mounted) return;
    if (state == AppLifecycleState.resumed) {
      if (widget.loop && !_controller!.isAnimating && !_isScrolling) {
        _controller!.repeat();
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_controller!.isAnimating) {
        _controller!.stop();
      }
    }
  }

  Future<void> _loadAnimation() async {
    if (!mounted) return;

    final hasAsset = widget.assetPath != null && widget.assetPath!.trim().isNotEmpty;
    final hasUrl = widget.url != null && widget.url!.trim().isNotEmpty;

    if (!hasAsset && !hasUrl) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      MovieEntity? videoItem;
      if (hasAsset) {
        videoItem = await SvgaParserUtil.decodeSafeFromAssets(widget.assetPath!);
      } else if (hasUrl) {
        videoItem = await SvgaParserUtil.decodeSafeFromUrl(widget.url!);
      }

      if (!mounted) return;
      final ctrl = _controller;
      if (ctrl == null) return;

      if (videoItem != null) {
        try {
          ctrl.videoItem = videoItem;
          if (widget.loop) {
            ctrl.repeat();
          } else {
            ctrl.forward();
          }
          if (widget.playAudio) {
            final effectiveFps = videoItem.params.fps > 0 ? videoItem.params.fps : 30;
            final key = widget.assetPath ?? widget.url ?? '';
            SvgaParserUtil.getPreparedAudios(videoItem, key, effectiveFps).then((audios) {
              if (mounted && audios.isNotEmpty) {
                _playPreparedAudios(audios);
              }
            });
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        } catch (e) {
          debugPrint("🚨 SVGA PLAYER PLAYBACK ERROR: $e");
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e, stack) {
      debugPrint("🚨 SVGA PLAYER ERROR: Failed to load ${widget.assetPath ?? widget.url}. Error: $e");
      debugPrint(stack.toString());
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  AudioPlayer? _audioPlayer;
  final List<Timer> _audioTimers = [];

  void _playPreparedAudios(List<PreparedSvgaAudio> preparedAudios) {
    if (!widget.playAudio || preparedAudios.isEmpty || !mounted) return;
    _audioPlayer ??= AudioPlayer();
    try {
      _audioPlayer!.setAudioContext(
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
    } catch (_) {}

    for (final audio in preparedAudios) {
      if (audio.delayMs > 0) {
        final timer = Timer(Duration(milliseconds: audio.delayMs), () async {
          if (mounted && _audioPlayer != null) {
            try {
              await _audioPlayer!.setVolume(1.0);
              await _audioPlayer!.play(DeviceFileSource(audio.file.path), volume: 1.0);
            } catch (ae) {
              debugPrint("[SvgaPlayer] Error playing SVGA audio: $ae");
            }
          }
        });
        _audioTimers.add(timer);
      } else {
        try {
          _audioPlayer!.setVolume(1.0);
          _audioPlayer!.play(DeviceFileSource(audio.file.path), volume: 1.0);
        } catch (ae) {
          debugPrint("[SvgaPlayer] Error playing SVGA audio: $ae");
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant SvgaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath || oldWidget.url != widget.url || oldWidget.loop != widget.loop) {
      _controller?.stop();
      _controller?.videoItem = null;
      for (final timer in _audioTimers) {
        timer.cancel();
      }
      _audioTimers.clear();
      _audioPlayer?.stop();
      _loadAnimation();
    } else if (_controller?.videoItem == null) {
      _loadAnimation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _audioTimers) {
      timer.cancel();
    }
    _audioTimers.clear();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    try {
      _controller?.stop();
      _controller?.dispose();
    } catch (e) {
      debugPrint("⚠️ SVGA controller dispose error: $e");
    }
    _controller = null;
    super.dispose();
  }

  Widget _buildFallback() {
    if (_hasError) {
      if (widget.fallbackImagePath != null && widget.fallbackImagePath!.isNotEmpty) {
        return Image.asset(
          widget.fallbackImagePath!,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return const SizedBox.shrink();
    }
    return _SkeletonShimmer(fit: widget.fit);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _controller == null || _controller!.videoItem == null || _isLoading) {
      return _buildFallback();
    }

    final playerWidget = RepaintBoundary(
      child: SVGAImage(
        _controller!,
        fit: widget.fit,
        preferredSize: widget.maxRenderSize,
      ),
    );

    if (!widget.pauseWhenInvisible) {
      return playerWidget;
    }

    // Zero-overhead scroll-aware animation governor
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (!mounted || _controller == null) return false;
        
        if (scrollNotification is ScrollStartNotification || scrollNotification is UserScrollNotification) {
          if (!_isScrolling) {
            _isScrolling = true;
            if (_controller!.isAnimating) {
              _controller!.stop();
            }
          }
        } else if (scrollNotification is ScrollEndNotification) {
          _isScrolling = false;
          if (widget.loop && !_controller!.isAnimating) {
            _controller!.repeat();
          }
        }
        return false;
      },
      child: playerWidget,
    );
  }
}
