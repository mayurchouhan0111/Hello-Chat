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
      web.evaluateJavascript(source: 'player.setVolume($_currentVolume);');
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player Surface
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: _showControlsPermanently,
            onLongPress: _showControlsPermanently,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SafeYoutubePlayer(
                      controller: _controller!,
                      videoId: widget.room.youtubeVideoId ?? '',
                    ),
                  ),
                ),
                
                // Control Overlay (Center)
                if (_showControls && isOwner)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildControlButton(Icons.replay_10_rounded, () {
                              _startHideTimer();
                              _seekRelative(-10);
                            }),
                            const Gap(24),
                            _buildControlButton(
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
                              size: 44,
                            ),
                            const Gap(24),
                            _buildControlButton(Icons.forward_30_rounded, () {
                              _startHideTimer();
                              _seekRelative(20);
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Top Utilities
                if (_showControls && isOwner)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMiniIconButton(Icons.volume_down_rounded, () {
                            _startHideTimer();
                            _adjustVolume(-10);
                          }),
                          const Gap(12),
                          _buildMiniIconButton(Icons.volume_up_rounded, () {
                            _startHideTimer();
                            _adjustVolume(10);
                          }),
                          const Gap(12),
                          const VerticalDivider(color: Colors.white24, width: 1, indent: 4, endIndent: 4),
                          const Gap(12),
                          _buildMiniIconButton(Icons.power_settings_new_rounded, () {
                            ref.read(roomServiceProvider).stopYoutube(widget.room.roomId);
                          }, color: Colors.redAccent),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap, {double size = 28}) {
    return GestureDetector(
      onTap: onTap, // Important: Intercept tap so it doesn't close the overlay
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10)
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  Widget _buildMiniIconButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 20),
    );
  }
}
