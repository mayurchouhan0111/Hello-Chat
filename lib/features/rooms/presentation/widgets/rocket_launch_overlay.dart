import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'vap_rocket_test_overlay.dart';

class RocketLaunchOverlay extends StatefulWidget {
  final int level;
  final VoidCallback onComplete;
  final bool useVapTest;

  const RocketLaunchOverlay({
    super.key, 
    required this.level,
    required this.onComplete,
    this.useVapTest = true, // Default to true for testing VAP
  });

  @override
  State<RocketLaunchOverlay> createState() => _RocketLaunchOverlayState();
}

class _RocketLaunchOverlayState extends State<RocketLaunchOverlay> with TickerProviderStateMixin {
  SVGAAnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    if (!widget.useVapTest) {
      _animationController = SVGAAnimationController(vsync: this);
      _loadAnimation();
    }
  }

  void _loadAnimation() async {
    if (widget.useVapTest) return;
    // level is 0-indexed in the logic, so level + 1
    final svgaPath = 'assets/rocket/rocket_set_svga/${widget.level + 1}_3.svga';
    try {
      final videoItem = await SVGAParser.shared.decodeFromAssets(svgaPath);
      if (mounted) {
        setState(() {
          _animationController?.videoItem = videoItem;
          _animationController?.forward().whenComplete(() {
            Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
          });
        });
      }
    } catch (e) {
      debugPrint("Error loading Launch SVGA: $e");
      // Fallback to completion if animation fails
      Future.delayed(const Duration(seconds: 3), widget.onComplete);
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useVapTest) {
      return VapRocketTestOverlay(onComplete: widget.onComplete);
    }

    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // SVGA Rocket Launch Animation
          if (_animationController?.videoItem != null)
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: SVGAImage(_animationController!),
            )
          else
            // Fallback during load or if failed
            const Icon(
              Icons.rocket_launch_rounded,
              color: Color(0xFFFFD700),
              size: 150,
            ).animate()
              .moveY(begin: 500, end: -800, duration: 2500.ms, curve: Curves.easeInQuart)
              .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5)),
          
          // Announcement Text
          Positioned(
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "LEVEL ${widget.level + 1} ROCKET",
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "LAUNCHED!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms).scale(),
          ),
        ],
      ),
    );
  }
}
