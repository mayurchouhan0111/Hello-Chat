import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pod_player/pod_player.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import 'package:gap/gap.dart';

class YouTubeRoomPlayer extends ConsumerStatefulWidget {
  final RoomModel room;
  final String? myUid;

  const YouTubeRoomPlayer({super.key, required this.room, this.myUid});

  @override
  ConsumerState<YouTubeRoomPlayer> createState() => _YouTubeRoomPlayerState();
}

class _YouTubeRoomPlayerState extends ConsumerState<YouTubeRoomPlayer> {
  PodPlayerController? _controller;
  String? _currentVideoId;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isOwner = false;
  bool _isDisposed = false;
  bool _isLoading = false;
  int _lastSyncedSeekTime = -1;
  late final _roomService = ref.read(roomServiceProvider);

  @override
  void initState() {
    super.initState();
    _isOwner = (widget.myUid ?? ref.read(authStateProvider).value?.uid) == widget.room.ownerUid;
    _initPlayer(widget.room.youtubeVideoId);
  }

  @override
  void didUpdateWidget(YouTubeRoomPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final newId = widget.room.youtubeVideoId;
    if (newId != oldWidget.room.youtubeVideoId) {
      _initPlayer(newId);
    } else if (_controller != null && _controller!.isInitialised && !_isOwner) {
      // Sync for guests
      final room = widget.room;
      
      // Sync Play/Pause
      final isPlaying = _controller!.isVideoPlaying;
      if (room.youtubeStatus == 'playing' && !isPlaying) {
        _controller!.play();
      } else if (room.youtubeStatus == 'paused' && isPlaying) {
        _controller!.pause();
      }

      // Sync Seek
      if (room.youtubeSeekTime != _lastSyncedSeekTime) {
        _lastSyncedSeekTime = room.youtubeSeekTime;
        final localPosition = _controller!.currentVideoPosition.inSeconds;
        final roomPosition = room.youtubeSeekTime;
        if ((roomPosition - localPosition).abs() > 3) {
          _controller!.videoSeekTo(Duration(seconds: roomPosition));
        }
      }
    }
  }

  Future<void> _initPlayer(String? videoId) async {
    if (videoId == null || videoId.isEmpty || _isLoading || _isDisposed) return;
    
    if (_currentVideoId == videoId && _controller != null) return;

    setState(() {
      _isLoading = true;
    });
    
    _currentVideoId = videoId;

    try {
      // 1. Detach old controller first
      if (_controller != null) {
        final oldController = _controller;
        _controller = null;
        // Small delay to let the widget tree rebuild without the old controller
        await Future.delayed(const Duration(milliseconds: 100));
        oldController!.dispose();
      }

      final controller = PodPlayerController(
        playVideoFrom: PlayVideoFrom.youtube('https://www.youtube.com/watch?v=$videoId'),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
          videoQualityPriority: [1080, 720, 360],
        ),
      );
      
      _controller = controller;
      await (_controller!.initialise() as dynamic);
      
      if (_isDisposed) {
        _controller?.dispose();
        return;
      }

      // Initial mute
      _controller!.mute(); 

      if (mounted) {
        setState(() => _isLoading = false);
      }
      _scheduleHide();
    } catch (e) {
      debugPrint('❌ [PodPlayer] Init error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scheduleHide() {
    if (_isDisposed) return;
    _hideTimer?.cancel();
    setState(() => _showControls = true);
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDisposed) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _hideTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      _scheduleHide();
    }
  }

  void _togglePlayPause() async {
    if (_controller == null || !_controller!.isInitialised || !_isOwner) return;
    
    final isPlaying = _controller!.isVideoPlaying;

    if (isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }

    // Sync to Firestore
    final position = _controller!.currentVideoPosition.inSeconds;
    _roomService.updateRoomSettings(widget.room.roomId, {
      'youtubeStatus': isPlaying ? 'paused' : 'playing',
      'youtubeSeekTime': position,
    });

    if (mounted) setState(() {}); // Update local UI
    _scheduleHide();
  }

  void _seekRelative(int seconds) async {
    if (_controller == null || !_controller!.isInitialised || !_isOwner) return;
    
    final currentPos = _controller!.currentVideoPosition;
    final newPos = currentPos + Duration(seconds: seconds);
    
    _controller!.videoSeekTo(newPos);

    // Sync to Firestore
    _roomService.updateRoomSettings(widget.room.roomId, {
      'youtubeSeekTime': newPos.inSeconds,
    });

    if (mounted) setState(() {});
    _scheduleHide();
  }

  void _toggleMute() {
    if (_controller == null || !_controller!.isInitialised) return;
    if (_controller!.isMute) {
      _controller!.unMute();
    } else {
      _controller!.mute();
    }
    if (mounted) setState(() {}); 
    _scheduleHide();
  }

  void _stopVideo() {
    _roomService.setYoutubeVideo(widget.room.roomId, '');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.room.youtubeVideoId.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_controller == null || _isLoading || !_controller!.isInitialised) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
              Gap(12),
              Text("Synchronizing...", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            // 📺 The Video Player
            Positioned.fill(
              child: AbsorbPointer(
                child: Center(
                  child: PodVideoPlayer(
                    controller: _controller!,
                    frameAspectRatio: 16 / 9,
                    videoAspectRatio: 16 / 9,
                    alwaysShowProgressBar: false,
                    podProgressBarConfig: const PodProgressBarConfig(
                      playingBarColor: Colors.red,
                      circleHandlerColor: Colors.red,
                    ),
                    podPlayerLabels: const PodPlayerLabels(
                      play: "",
                      pause: "",
                      error: "",
                    ),
                    // Completely replace the native overlay with an empty widget
                    overlayBuilder: (options) => const SizedBox.shrink(),
                    // Disable default UI elements where possible
                    onToggleFullScreen: (isFullScreen) async {},
                  ),
                ),
              ),
            ),

            // 🖱️ Interaction Layer (Toggles Controls)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),

            // 🎛️ Controls Overlay
            if (_showControls)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Bar: Mute & Label
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("LIVE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                              _controlIcon(
                                _controller!.isMute ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                _toggleMute,
                                size: 24,
                              ),
                            ],
                          ),
                        ),

                        // Center: Play/Pause/Seek (For Owner only)
                        if (_isOwner)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _controlIcon(Icons.replay_10_rounded, () => _seekRelative(-10), size: 28),
                              const Gap(40),
                              _controlIcon(
                                _controller!.isVideoPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                _togglePlayPause,
                                size: 50,
                              ),
                              const Gap(40),
                              _controlIcon(Icons.forward_30_rounded, () => _seekRelative(30), size: 28),
                            ],
                          ),

                        // Bottom Bar: Progress & Close
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildProgressBar(),
                              ),
                              if (_isOwner) ...[
                                const Gap(16),
                                _controlIcon(Icons.close_rounded, _stopVideo, color: Colors.white, size: 24),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final current = _controller!.currentVideoPosition;
        final total = _controller!.totalVideoLength;
        final progress = total.inSeconds > 0 ? current.inSeconds / total.inSeconds : 0.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 3,
            ),
            const Gap(6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(current), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                Text(_formatDuration(total), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${duration.inHours}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _controlIcon(IconData icon, VoidCallback onTap, {double size = 24, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}