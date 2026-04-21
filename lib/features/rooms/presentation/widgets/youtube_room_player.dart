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
          hideControls: false, 
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: false,
          useHybridComposition: true, 
        ),
      )..addListener(_onPlayerStateChange);
    }
    if (mounted) setState(() {});
  }

  void _onPlayerStateChange() {
    if (_controller != null && _controller!.value.isPlaying) {
      debugPrint('YouTube Player: PLAYING state reached');
    }
  }

  @override
  void didUpdateWidget(YouTubeRoomPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final newId = widget.room.youtubeVideoId;
    final oldId = oldWidget.room.youtubeVideoId;
    final isActive = widget.room.isYoutubeActive;

    debugPrint('📺 [YouTubePlayer] Update: Active=$isActive, ID=$newId, PrevID=$oldId');

    if (newId != oldId && newId != null && newId.isNotEmpty) {
      debugPrint('📺 [YouTubePlayer] ID Changed. Initializing/Updating controller...');
      _initController(newId);
    }
    
    // Force initialization if active but controller is null
    if (isActive && _controller == null && newId != null && newId.isNotEmpty) {
      debugPrint('📺 [YouTubePlayer] System Active but Controller Null. Emergency Init.');
      _initController(newId);
    }
    
    if (!isActive && oldWidget.room.isYoutubeActive) {
      debugPrint('📺 [YouTubePlayer] System Deactivated. Pausing video.');
      _controller?.pause();
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

    final isOwner = ref.watch(authStateProvider).value?.uid == widget.room.ownerUid;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.live_tv_rounded, color: Colors.red, size: 16),
                    Gap(8),
                    Text("YouTube Shared Watch",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  onPressed: () =>
                      ref.read(roomServiceProvider).stopYoutube(widget.room.roomId),
                  icon: const Icon(Icons.power_settings_new_rounded,
                      color: Colors.redAccent, size: 18),
                ),
            ],
          ),
          SizedBox(
            height: 210,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: SafeYoutubePlayer(
                controller: _controller!,
                videoId: widget.room.youtubeVideoId ?? '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
