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
    final currentPos = _controller!.value.position;
    final newPos = currentPos + Duration(seconds: seconds);
    _controller!.seekTo(newPos);
  }

  void _adjustVolume(int delta) {
    if (_controller == null) return;
    setState(() {
      _currentVolume = (_currentVolume + delta).clamp(0, 100);
      _controller!.setVolume(_currentVolume);
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

  @override
  Widget build(BuildContext context) {
    if (!widget.room.isYoutubeActive || widget.room.youtubeVideoId == null || _controller == null) {
      return const SizedBox.shrink();
    }

    final myUid = ref.watch(authStateProvider).value?.uid;
    final isOwner = myUid == widget.room.ownerUid;

    return Container(
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
          GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
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
                if (_showControls && isOwner)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildControlButton(Icons.replay_10_rounded, () => _seekRelative(-10)),
                              const Gap(20),
                              _buildControlButton(
                                _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                () => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play(),
                                size: 48,
                              ),
                              const Gap(20),
                              _buildControlButton(Icons.forward_30_rounded, () => _seekRelative(20)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_showControls)
                  Positioned(
                    top: 10, right: 10,
                    child: Column(
                      children: [
                        if (isOwner) _buildMiniButton(Icons.volume_up_rounded, () => _adjustVolume(10)),
                        const Gap(8),
                        if (isOwner) _buildMiniButton(Icons.volume_down_rounded, () => _adjustVolume(-10)),
                        const Gap(8),
                        if (isOwner) _buildMiniButton(Icons.close_rounded, () {
                          ref.read(roomServiceProvider).stopYoutube(widget.room.roomId);
                        }, color: Colors.redAccent),
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

  Widget _buildControlButton(IconData icon, VoidCallback onTap, {double size = 32}) {
    return Material(
      color: Colors.white10,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }

  Widget _buildMiniButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}
