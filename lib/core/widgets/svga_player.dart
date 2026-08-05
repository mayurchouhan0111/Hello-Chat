import 'dart:async';
import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:hello_chat/core/utils/svga_static_util.dart';

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
  }) : assert(assetPath != null || url != null, 'Either assetPath or url must be provided');

  @override
  State<SvgaPlayer> createState() => _SvgaPlayerState();
}

class _SvgaPlayerState extends State<SvgaPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _hasError = false;
  bool _isLoading = true;
  bool _isVisibleInViewport = true;
  double _lastTickTime = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    if (widget.maxFps != null && widget.maxFps! > 0) {
      _controller?.addListener(_onControllerTick);
    }
    _loadAnimation();
  }

  void _onControllerTick() {
    if (widget.maxFps == null || widget.maxFps! <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final interval = 1.0 / widget.maxFps!;
    if (now - _lastTickTime < interval) {
      // Throttle rapid sub-frame repaints
      return;
    }
    _lastTickTime = now;
  }

  Future<void> _loadAnimation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      MovieEntity? videoItem;
      if (widget.assetPath != null) {
        videoItem = await SvgaParserUtil.decodeSafeFromAssets(widget.assetPath!);
      } else if (widget.url != null) {
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
      debugPrint("🚨🚨🚨 SVGA PLAYER ERROR: Failed to load ${widget.assetPath ?? widget.url}. Error: $e");
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
    _controller?.removeListener(_onControllerTick);
    _controller?.stop();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildFallback() {
    if (widget.fallbackImagePath != null) {
      return Image.asset(
        widget.fallbackImagePath!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    if (widget.assetPath != null) {
      final staticFallback = SvgaStaticUtil.staticPathForSvga(widget.assetPath);
      return Image.asset(
        staticFallback,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
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

    // Scrollable Visibility Optimization
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (!mounted) return false;
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final bounds = renderBox.localToGlobal(Offset.zero) & renderBox.size;
          final screenHeight = MediaQuery.of(context).size.height;
          final isVisible = bounds.bottom > 0 && bounds.top < screenHeight;
          if (isVisible != _isVisibleInViewport) {
            _isVisibleInViewport = isVisible;
            if (isVisible) {
              if (widget.loop && !_controller!.isAnimating) _controller!.repeat();
            } else {
              if (_controller!.isAnimating) _controller!.stop();
            }
          }
        }
        return false;
      },
      child: playerWidget,
    );
  }
}
