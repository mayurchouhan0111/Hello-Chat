import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import '../../../../core/models/room_model.dart';
import './rocket_detail_sheet.dart';

class RocketProgressWidget extends StatefulWidget {
  final RoomModel room;
  const RocketProgressWidget({super.key, required this.room});

  @override
  State<RocketProgressWidget> createState() => _RocketProgressWidgetState();
}

class _RocketProgressWidgetState extends State<RocketProgressWidget> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;
  int _currentLevel = -1;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }

  @override
  void didUpdateWidget(RocketProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.rocketLevel != widget.room.rocketLevel) {
      _loadAnimation();
    }
  }

  Future<void> _loadAnimation() async {
    final level = widget.room.rocketLevel;
    if (level == _currentLevel && !_isLoading) return;

    setState(() => _isLoading = true);
    _currentLevel = level;

    try {
      final displayLevel = level.clamp(0, 4);
      final svgaPath = RocketVapConfig.svgaIconPath(displayLevel);
      final videoItem = await SvgaParserUtil.decodeSafeFromAssets(svgaPath);
      
      if (mounted) {
        _controller?.videoItem = videoItem;
        _controller?.repeat();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading Rocket Logo SVGA: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  int _getTargetForLevel(int level) {
    switch (level) {
      case 0: return 1000000;
      case 1: return 2000000;
      case 2: return 3000000;
      case 3: return 5000000;
      case 4: return 10000000;
      default: return 10000000;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _getTargetForLevel(widget.room.rocketLevel);
    final progress = (widget.room.rocketFuel / target).clamp(0.0, 1.0);
    final isCooldown = widget.room.rocketStatus == "cooldown" && 
                       widget.room.rocketCooldownUntil != null &&
                       widget.room.rocketCooldownUntil!.isAfter(DateTime.now());

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RocketDetailSheet(room: widget.room),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCooldown ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: isCooldown ? Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5) : null,
          boxShadow: isCooldown ? [
            BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rocket & Progress Stack
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCooldown)
                  _buildCooldownTimer()
                else ...[
                  // Dynamic SVGA Rocket Logo
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: _isLoading
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : (_controller?.videoItem != null)
                            ? SVGAImage(_controller!)
                            : const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 40),
                  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
                  
                  const SizedBox(height: 6),

                  // Slim Progress Bar
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF00)),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCooldownTimer() {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final until = widget.room.rocketCooldownUntil!;
        final diff = until.difference(now);
        
        if (diff.isNegative) return const SizedBox.shrink();

        final minutes = diff.inMinutes.toString().padLeft(2, '0');
        final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

        return Column(
          children: [
            const Text(
              "COOLDOWN",
              style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ).animate(onPlay: (c) => c.repeat()).fade(duration: 1.seconds, begin: 0.5, end: 1).then().fade(duration: 1.seconds, begin: 1, end: 0.5),
            Text(
              "$minutes:$seconds",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ],
        );
      },
    );
  }
}
