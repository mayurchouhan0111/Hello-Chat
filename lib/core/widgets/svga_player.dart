import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

import 'package:hello_chat/core/utils/svga_parser_util.dart';

class SvgaPlayer extends StatefulWidget {
  final String? assetPath;
  final String? url;
  final BoxFit fit;
  final bool loop;
  final String? fallbackImagePath;

  const SvgaPlayer({
    super.key,
    this.assetPath,
    this.url,
    this.fit = BoxFit.contain,
    this.loop = true,
    this.fallbackImagePath,
  }) : assert(assetPath != null || url != null, 'Either assetPath or url must be provided');

  @override
  State<SvgaPlayer> createState() => _SvgaPlayerState();
}

class _SvgaPlayerState extends State<SvgaPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadAnimation();
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
        print("✅✅✅ SVGA PLAYER: Loaded successfully: ${widget.assetPath ?? widget.url}");
        setState(() {
          _isLoading = false;
        });
      } else {
        print("❌❌❌ SVGA PLAYER: Video item null for ${widget.assetPath ?? widget.url}");
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      print("🚨🚨🚨 SVGA PLAYER ERROR: Failed to load ${widget.assetPath ?? widget.url}. Error: $e");
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
    _controller?.stop();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _controller == null || _controller!.videoItem == null) {
      if (widget.fallbackImagePath != null) {
        return Image.asset(
          widget.fallbackImagePath!,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      // Try to deduce png/webp fallback from assetPath
      if (widget.assetPath != null) {
        final lowerPath = widget.assetPath!.toLowerCase();
        final fallbackExt = lowerPath.contains('badge') ? '.webp' : '.png';
        final inferredFallback = widget.assetPath!.replaceAll(RegExp(r'\.svga$', caseSensitive: false), fallbackExt);
        return Image.asset(
          inferredFallback,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      // Show static fallback preview while loading SVGA to prevent blank frames
      if (widget.fallbackImagePath != null) {
        return Image.asset(widget.fallbackImagePath!, fit: widget.fit, errorBuilder: (_, __, ___) => const SizedBox.shrink());
      }
      if (widget.assetPath != null) {
        final lowerPath = widget.assetPath!.toLowerCase();
        final fallbackExt = lowerPath.contains('badge') ? '.webp' : '.png';
        final inferredFallback = widget.assetPath!.replaceAll(RegExp(r'\.svga$', caseSensitive: false), fallbackExt);
        return Image.asset(
          inferredFallback,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
      return const SizedBox.shrink();
    }

    return SVGAImage(_controller!, fit: widget.fit);
  }
}
