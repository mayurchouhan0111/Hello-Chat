import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/services/room_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'safe_youtube_player.dart';

class YouTubeRoomPlayer extends ConsumerStatefulWidget {
  final RoomModel room;
  const YouTubeRoomPlayer({super.key, required this.room});

  @override
  ConsumerState<YouTubeRoomPlayer> createState() => _YouTubeRoomPlayerState();
}

class _YouTubeRoomPlayerState extends ConsumerState<YouTubeRoomPlayer> {
  YoutubePlayerController? _controller;
  int _currentVolume = 100;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.room.youtubeVideoId != null && widget.room.youtubeVideoId!.isNotEmpty) {
      _initController(widget.room.youtubeVideoId!);
    }
  }

  void _initController(String videoId) {
    if (_controller != null) {
      _controller!.load(videoId);
    } else {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false, 
          hideControls: true, 
          disableDragSeek: false,
          useHybridComposition: true, 
        ),
      )..addListener(_onPlayerStateChange);
    }
    if (mounted) setState(() {});
  }

  void _onPlayerStateChange() {
    if (mounted) setState(() {});
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    final web = _controller!.value.webViewController;
    if (web == null) return;

    final currentPos = _controller!.value.position;
    final newSeconds = (currentPos.inSeconds + seconds).clamp(0, _controller!.metadata.duration.inSeconds);
    
    web.evaluateJavascript(source: 'player.seekTo($newSeconds, true);');
    _startHideTimer();
  }

  void _adjustVolume(int delta) {
    if (_controller == null) return;
    final web = _controller!.value.webViewController;
    if (web == null) return;

    setState(() {
      _currentVolume = (_currentVolume + delta).clamp(0, 100);
      web.evaluateJavascript(source: 'player.unMute(); player.setVolume($_currentVolume);');
      _startHideTimer();
    });
  }

  @override
  void didUpdateWidget(YouTubeRoomPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.room.youtubeVideoId != oldWidget.room.youtubeVideoId && 
        widget.room.youtubeVideoId != null && 
        widget.room.youtubeVideoId!.isNotEmpty) {
      _initController(widget.room.youtubeVideoId!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Timer? _hideTimer;

  void _showControlsPermanently() {
    _hideTimer?.cancel();
    setState(() => _showControls = true);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_showControls) {
       _hideTimer?.cancel();
       setState(() => _showControls = false);
    } else {
       _showControlsPermanently();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.room.isYoutubeActive || widget.room.youtubeVideoId == null || _controller == null) {
      return const SizedBox.shrink();
    }

    final myUid = ref.watch(authStateProvider).value?.uid;
    final isOwner = myUid == widget.room.ownerUid;

    return Container(
      key: ValueKey("yt_player_${widget.room.roomId}"),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 📺 THE PLAYER SURFACE
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: _showControlsPermanently,
            onLongPress: _showControlsPermanently,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SafeYoutubePlayer(
                      controller: _controller!,
                      videoId: widget.room.youtubeVideoId ?? '',
                    ),
                  ),
                ),
                
                // 🛠️ SIMPLE CONTROL BAR (ONLY IF OWNER)
                if (_showControls && isOwner)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // BACK 10s
                        _buildActionIcon(Icons.replay_10_rounded, () => _seekRelative(-10)),
                        const Gap(8),
                        
                        // PLAY / PAUSE
                        _buildActionIcon(
                          _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          () {
                            final web = _controller!.value.webViewController;
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                              web?.evaluateJavascript(source: 'player.pauseVideo();');
                            } else {
                              _controller!.play();
                              web?.evaluateJavascript(source: 'player.playVideo();');
                            }
                            _startHideTimer();
                            setState(() {});
                          },
                          isPrimary: true,
                        ),
                        const Gap(8),

                        // FORWARD 20s
                        _buildActionIcon(Icons.forward_30_rounded, () => _seekRelative(20)),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(height: 24, child: VerticalDivider(color: Colors.white24, width: 1)),
                        ),

                        // VOLUME DOWN
                        _buildActionIcon(Icons.volume_down_rounded, () => _adjustVolume(-10)),
                        
                        // VOLUME UP
                        _buildActionIcon(Icons.volume_up_rounded, () => _adjustVolume(10)),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(height: 24, child: VerticalDivider(color: Colors.white24, width: 1)),
                        ),

                        // CLOSE
                        _buildActionIcon(
                          Icons.close_rounded,
                          () => ref.read(roomServiceProvider).stopYoutube(widget.room.roomId),
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap, {bool isPrimary = false, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 12 : 8),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: isPrimary ? 32 : 24),
      ),
    );
  }
}
