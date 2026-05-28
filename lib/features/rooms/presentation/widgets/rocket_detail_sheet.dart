import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:flutter_vap_plugin/flutter_vap_plugin.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';

class RocketDetailSheet extends ConsumerStatefulWidget {
  final RoomModel room;
  const RocketDetailSheet({super.key, required this.room});

  @override
  ConsumerState<RocketDetailSheet> createState() => _RocketDetailSheetState();
}

class _RocketDetailSheetState extends ConsumerState<RocketDetailSheet> with TickerProviderStateMixin {
  int _selectedLevel = 0; // 0-indexed
  final FlutterVapController _mainVapController = FlutterVapController();
  
  Timer? _countdownTimer;
  String _timeString = "00:00:00";
  bool _isInitialized = false;
  final Map<int, String> _tempFilePaths = {};

  final List<String> _vapFiles = [
    'assets/rocket/VAP/1-a.mp4',
    'assets/rocket/VAP/2-a.mp4',
    'assets/rocket/VAP/3-a.mp4',
    'assets/rocket/VAP/4-a.mp4',
    'assets/rocket/VAP/5-a.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.room.rocketLevel.clamp(0, 4);
    _startCountdown();
    
    // Start initialization
    _initializeAndPlay();
  }

  Future<void> _initializeAndPlay() async {
    await _prepareTempFiles();
    if (mounted) {
      setState(() => _isInitialized = true);
      // Give native view a moment to attach to the tree
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadMainAnimation();
        }
      });
    }
  }

  Future<void> _prepareTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      for (int i = 0; i < _vapFiles.length; i++) {
        final vapPath = _vapFiles[i];
        // Use rootBundle directly for more reliability
        final byteData = await rootBundle.load(vapPath);
        final bytes = byteData.buffer.asUint8List();
        final tempFile = File('${tempDir.path}/rocket_${i + 1}_a.mp4');
        await tempFile.writeAsBytes(bytes);
        _tempFilePaths[i] = tempFile.path;
        debugPrint("SUCCESS: Prepared temp file $i: ${tempFile.path}");
      }
    } catch (e) {
      debugPrint("FATAL ERROR preparing VAP files: $e");
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final diff = tomorrow.difference(now);
      
      setState(() {
        _timeString = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
      });
    });
  }

  Future<void> _loadMainAnimation() async {
    if (!mounted) return;
    final path = _tempFilePaths[_selectedLevel];
    if (path == null) {
      debugPrint("ERROR: No temp file path for level $_selectedLevel");
      return;
    }
    
    try {
      await _mainVapController.stop();
      if (!mounted) return;
      debugPrint("PLAYING VAP: $path for level $_selectedLevel");
      await _mainVapController.play(
        path: path,
        sourceType: VapSourceType.file,
        repeatCount: 9999, 
      );
    } catch (e) {
      debugPrint("Main VAP Play Error: $e");
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _mainVapController.stop();
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
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.room.roomId));
    final room = roomAsync.value ?? widget.room;
    
    final target = _getTargetForLevel(_selectedLevel);
    final fuel = _selectedLevel == room.rocketLevel ? room.rocketFuel : (_selectedLevel < room.rocketLevel ? target : 0);
    final progress = (fuel / target).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF1E0045).withOpacity(0.8),
            const Color(0xFF0F0025),
          ],
          stops: const [0.0, 0.25, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const Gap(20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLevelSelector(room),
                    Expanded(child: _buildMainRocketDisplay(room)),
                    _buildRightControls(progress),
                  ],
                ),
              ),
              _buildBottomPanel(room),
            ],
          ),
          Positioned(
            top: 20, right: 20,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector(RoomModel room) {
    return Container(
      width: 65,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final isSelected = _selectedLevel == index;
          final isCurrent = room.rocketLevel == index;
          
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!mounted) return;
              setState(() {
                _selectedLevel = index;
                _loadMainAnimation();
              });
            },
            child: Container(
              height: 60,
              width: 50,
              margin: const EdgeInsets.only(bottom: 6),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFCC00FF).withOpacity(0.3) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFFCC00FF) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dynamic SVGA Rocket Level Logo
                  _RocketLevelSvgaButton(level: index),
                  
                  if (isCurrent)
                    Positioned(
                      top: 1, right: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFCC00FF), borderRadius: BorderRadius.circular(3)),
                        child: const Text("LVL", style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMainRocketDisplay(RoomModel room) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // VAP Animation Layer - Shifted down with same total height
        Positioned(
          top: -10,
          bottom: -110,
          left: -40,
          right: -40,
          child: _isInitialized 
            ? FlutterVapView(
                controller: _mainVapController,
                scaleType: VapScaleType.fitXY,
                onVideoFinish: () {
                  if (mounted) _loadMainAnimation();
                },
              )
            : const Center(child: CircularProgressIndicator(color: Color(0xFFCC00FF))),
        ),

        // Level Badge Layer
        Positioned(
          top: 0, left: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCC00FF), width: 2),
              gradient: const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFFCC00FF)]),
            ),
            child: Text(
              "${_selectedLevel + 1}",
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),

        // Multiplier Badge
        Positioned(
          top: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCC00FF).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00FFFF).withOpacity(0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                Text(
                  "Reward: ${_getMultiplierForLevel(_selectedLevel)}",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds),
        ),

        // Cooldown Banner Overlay
        if (room.rocketStatus == "cooldown" && 
            room.rocketCooldownUntil != null &&
            room.rocketCooldownUntil!.isAfter(DateTime.now()))
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20)
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "SYSTEM COOLDOWN",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                          const Gap(8),
                          _buildCooldownTimerDetail(room.rocketCooldownUntil!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getMultiplierForLevel(int level) {
    switch (level) {
      case 0: return "1x";
      case 1: return "2x";
      case 2: return "4x";
      case 3: return "8x";
      case 4: return "15x";
      default: return "1x";
    }
  }

  Widget _buildRightControls(double progress) {
    const double trackHeight = 200; // Even shorter height as requested
    
    return Container(
      width: 50,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end, // Align everything to the bottom
        children: [
          SizedBox(
            height: trackHeight,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // Futuristic Glass Track
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFCC00FF).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFCC00FF).withOpacity(0.15),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // Subtle metallic reflection layer
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.1),
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: progress * trackHeight,
                    width: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8E54E9),
                          Color(0xFFCC00FF),
                          Color(0xFF00FFFF), // Cyan for that cyberpunk neon pop
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCC00FF).withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Internal energy pulse
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                      ],
                    ),
                  ),
                ),

                // Floating Glowing Tip (Bloom)
                if (progress > 0.05)
                  Positioned(
                    bottom: (progress * trackHeight) - 4,
                    child: Container(
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFFF).withOpacity(0.8),
                            blurRadius: 15,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 1.seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),

                // Futuristic Percentage Tag
                Positioned(
                  bottom: (progress * trackHeight) - 10,
                  right: -15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00FFFF).withOpacity(0.5), width: 1),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00FFFF).withOpacity(0.3), blurRadius: 8),
                      ],
                    ),
                    child: Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(
                        color: Color(0xFF00FFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 3.seconds),
                ),
              ],
            ),
          ),
          const Gap(12),
          _buildCircleIcon(Icons.help_outline_rounded, const Color(0xFFCC00FF)),
          const Gap(8),
          _buildCircleIcon(Icons.assignment_rounded, const Color(0xFFCC00FF)),
          const Gap(20),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _buildBottomPanel(RoomModel room) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0045),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Text(
            "Reset countdown: $_timeString",
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const Gap(10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFFCC00FF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text("My Reward", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
          const Gap(10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ["Top1", "Top2", "Top3", "In Room"].map((tab) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: tab == "Top1" ? const Color(0xFFCC00FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFCC00FF)),
              ),
              child: Text(tab, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            )).toList(),
          ),
          const Gap(12),
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Rocket king", style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w900)),
                  Text("last / this week", style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
              const Spacer(),
              _buildRankingAvatars(room),
              const Gap(10),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankingAvatars(RoomModel room) {
    final contributions = room.rocketContributions ?? {};
    final sortedUids = contributions.keys.toList()
      ..sort((a, b) => contributions[b]!.compareTo(contributions[a]!));
    final top3Uids = sortedUids.take(3).toList();

    return Row(
      children: List.generate(3, (index) {
        final color = index == 0 ? Colors.amber : (index == 1 ? Colors.grey : Colors.brown);
        final uid = index < top3Uids.length ? top3Uids[index] : null;
        
        return Container(
          margin: const EdgeInsets.only(left: 8),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (uid != null)
                Consumer(
                  builder: (context, ref, child) {
                    final userAsync = ref.watch(userProfileProvider(uid));
                    return userAsync.when(
                      data: (user) => AppAvatar(
                        radius: 20,
                        imageUrl: user?.profilePhotoUrl ?? "",
                        showFrame: true,
                        tags: user?.tags,
                      ),
                      loading: () => const AppAvatar(radius: 20, imageUrl: "", showFrame: true),
                      error: (_, __) => const AppAvatar(radius: 20, imageUrl: "", showFrame: true),
                    );
                  },
                )
              else
                const AppAvatar(
                  radius: 20,
                  imageUrl: "",
                  showFrame: true,
                ),
              Positioned(
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: color, size: 12),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCooldownTimerDetail(DateTime until) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final diff = until.difference(now);
        if (diff.isNegative) return const SizedBox.shrink();
        
        final m = diff.inMinutes.toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        
        return Text(
          "$m:$s",
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
        );
      },
    );
  }
}

class _RocketLevelSvgaButton extends StatefulWidget {
  final int level;
  const _RocketLevelSvgaButton({required this.level});

  @override
  State<_RocketLevelSvgaButton> createState() => _RocketLevelSvgaButtonState();
}

class _RocketLevelSvgaButtonState extends State<_RocketLevelSvgaButton> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }

  Future<void> _loadAnimation() async {
    try {
      final svgaPath = 'assets/rocket/VAP/1 (${widget.level + 1}).svga';
      final videoItem = await SVGAParser.shared.decodeFromAssets(svgaPath);
      if (mounted) {
        setState(() {
          _controller?.videoItem = videoItem;
          _controller?.repeat();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading SVGA for level ${widget.level}: $e");
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
    return SizedBox(
      width: 45,
      height: 45,
      child: _isLoading
          ? const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)))
          : (_controller?.videoItem != null)
              ? SVGAImage(_controller!)
              : const Icon(Icons.rocket_launch_rounded, color: Colors.white24, size: 24),
    );
  }
}
