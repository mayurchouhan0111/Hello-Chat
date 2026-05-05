import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class SafeYoutubePlayer extends StatefulWidget {
  final YoutubePlayerController controller;
  final String videoId;
  final void Function(YoutubeMetaData metaData)? onEnded;
  final void Function(int errorCode)? onError;

  const SafeYoutubePlayer({
    super.key,
    required this.controller,
    required this.videoId,
    this.onEnded,
    this.onError,
  });

  @override
  State<SafeYoutubePlayer> createState() => _SafeYoutubePlayerState();
}

class _SafeYoutubePlayerState extends State<SafeYoutubePlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onPlayerStateChange);
  }

  void _onPlayerStateChange() {
    final value = _controller.value;
    if (value.playerState == PlayerState.ended) {
      widget.onEnded?.call(_controller.metadata);
    }
    if (value.errorCode != 0 && value.errorCode != null) {
      widget.onError?.call(value.errorCode!);
    }
  }

  @override
  void didUpdateWidget(SafeYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoId != oldWidget.videoId) {
      _controller.load(widget.videoId);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      showVideoProgressIndicator: false,
      progressIndicatorColor: Colors.red,
      onEnded: (metaData) {
        widget.onEnded?.call(metaData);
      },
    );
  }
}