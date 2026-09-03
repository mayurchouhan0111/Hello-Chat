import 'dart:async';
import 'package:flutter/material.dart';
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
        ctrl.videoItem = videoItem;
        if (widget.loop) {
          ctrl.repeat();
        } else {
          ctrl.forward();
        }
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
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

  @override
  void didUpdateWidget(covariant SvgaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath || oldWidget.url != widget.url || oldWidget.loop != widget.loop) {
      _controller?.stop();
      _controller?.videoItem = null;
      _loadAnimation();
    } else if (_controller?.videoItem == null) {
      _loadAnimation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.stop();
    _controller?.dispose();
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
