import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'package:hello_chat/core/utils/svga_parser_util.dart';
import 'package:hello_chat/core/utils/rocket_vap_config.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import '../../../../core/models/room_model.dart';
import './rocket_detail_sheet.dart';

class RocketProgressWidget extends ConsumerStatefulWidget {
  final RoomModel room;
  const RocketProgressWidget({super.key, required this.room});

  @override
  ConsumerState<RocketProgressWidget> createState() => _RocketProgressWidgetState();
}

class _RocketProgressWidgetState extends ConsumerState<RocketProgressWidget> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final targetsAsync = ref.watch(rocketSettingsProvider);
    final targets = targetsAsync.valueOrNull ?? const [1000000, 2000000, 3000000, 5000000, 10000000];
    final levelIdx = widget.room.rocketLevel.clamp(0, 4);
    final target = levelIdx < targets.length ? targets[levelIdx] : 10000000;
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
          color: isCooldown
              ? const Color(0xFF0F172A).withOpacity(0.9)
              : Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCooldown
                ? Colors.cyanAccent.withOpacity(0.8)
                : const Color(0xFF8E54E9).withOpacity(0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isCooldown
                  ? Colors.cyanAccent.withOpacity(0.35)
                  : const Color(0xFF8E54E9).withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCooldown)
              _buildCooldownTimer()
            else ...[
              // Level Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E54E9), Color(0xFF4776E6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "LV.${levelIdx + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Dynamic SVGA Rocket Logo
              SizedBox(
                width: 44,
                height: 44,
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : (_controller?.videoItem != null)
                        ? SVGAImage(_controller!)
                        : const Icon(Icons.rocket_launch_rounded, color: Colors.amberAccent, size: 34),
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
              
              const SizedBox(height: 4),

              // Slim Gradient Progress Bar
              SizedBox(
                width: 52,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF87)),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                "ROCKET",
                style: TextStyle(
                  color: Color(0xFFB8C0FF),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ],
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
