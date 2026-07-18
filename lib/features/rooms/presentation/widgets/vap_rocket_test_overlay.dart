import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';

class VapRocketTestOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const VapRocketTestOverlay({
    super.key,
    required this.onComplete,
  });

  @override
  State<VapRocketTestOverlay> createState() => _VapRocketTestOverlayState();
}

class _VapRocketTestOverlayState extends State<VapRocketTestOverlay> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadAndPlay();
  }

  Future<void> _loadAndPlay() async {
    try {
      final videoItem = await SvgaParserUtil.decodeSafeFromAssets('assets/rocket/Rocket set SVGA/1.3.svga');
      if (mounted) {
        setState(() {
          _controller?.videoItem = videoItem;
          _isLoaded = true;
        });
        _controller?.forward().whenComplete(() {
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 500), widget.onComplete);
          }
        });
      }
    } catch (e) {
      debugPrint("Test SVGA Error: $e");
      if (mounted) widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isLoaded && _controller?.videoItem != null)
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: SVGAImage(_controller!),
            ),

          Positioned(
            bottom: 50,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    _controller?.forward(from: 0);
                  },
                  child: const Text("Replay SVGA"),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: widget.onComplete,
                  child: const Text("Close Test"),
                ),
              ],
            ),
          ),

          const Positioned(
            top: 100,
            child: Text(
              "SVGA ANIMATION TEST MODE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
