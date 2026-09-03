import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
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

class _YouTubeRoomPlayerState extends ConsumerState<YouTubeRoomPlayer> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _showVolumeSlider = false;
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _playerStateSubscription;
  StreamSubscription<YoutubeVideoState>? _videoStateSubscription;
  Duration _currentPosition = Duration.zero;
  String? _currentVideoId;
  bool _isDisposed = false;
  bool _isLoading = false;
  bool _hasAutoplayed = false;
  int _lastSyncedSeekTime = -1;
  DateTime? _lastSeekSyncTime;
  late final _roomService = ref.read(roomServiceProvider);
  YoutubeError _errorCode = YoutubeError.none;

  bool get _isOwner => (widget.myUid ?? ref.read(authStateProvider).value?.uid) == widget.room.ownerUid;
  int _lastSyncedVolume = 100;
  bool _lastSyncedMute = true;
  DateTime? _lastVolumeSyncTime;

  @override
  void initState() {
    super.initState();
    _initPlayer(widget.room.youtubeVideoId);
  }

  @override
  void didUpdateWidget(YouTubeRoomPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final newId = widget.room.youtubeVideoId;
    final oldId = oldWidget.room.youtubeVideoId;
    
    final newParsed = newId != null ? (YoutubePlayerController.convertUrlToId(newId) ?? newId) : null;
    final oldParsed = oldId != null ? (YoutubePlayerController.convertUrlToId(oldId) ?? oldId) : null;

    if (newParsed != oldParsed) {
      _initPlayer(newId);
    } else if (_controller != null) {
      final room = widget.room;
      
      // Sync Play/Pause
      final isPlaying = _controller!.value.playerState == PlayerState.playing;
      if (room.youtubeStatus == 'playing' && !isPlaying) {
        _controller!.playVideo();
      } else if (room.youtubeStatus == 'paused' && isPlaying) {
        _controller!.pauseVideo();
      }

      // Sync Seek
      if (room.youtubeSeekTime != _lastSyncedSeekTime) {
        _lastSyncedSeekTime = room.youtubeSeekTime;
        final localPosition = _currentPosition.inSeconds;
        final roomPosition = room.youtubeSeekTime;
        if ((roomPosition - localPosition).abs() > 3) {
          _controller!.seekTo(seconds: roomPosition.toDouble());
        }
      }

      // Sync Mute and Volume
      final shouldBeMuted = !room.backgroundMusic;
      if (shouldBeMuted != _lastSyncedMute) {
        _lastSyncedMute = shouldBeMuted;
        if (shouldBeMuted) {
          _controller!.mute();
        } else {
          _controller!.unMute();
          _controller!.setVolume(room.youtubeVolume);
        }
      }

      if (!shouldBeMuted && room.youtubeVolume != _lastSyncedVolume) {
        _lastSyncedVolume = room.youtubeVolume;
        _controller!.setVolume(room.youtubeVolume);
      }
    }
  }

  void _onPlayerStateChange(YoutubePlayerValue value) {
    if (!mounted || _isDisposed || _controller == null) return;
    
    final state = value.playerState;
    final isPlaying = state == PlayerState.playing;
    final hasError = value.hasError;
    final errorCode = value.error;
    
    debugPrint("📺 [YouTubeRoomPlayer] State Update: state=$state, isPlaying=$isPlaying, hasError=$hasError, errorCode=$errorCode");
    
    if (hasError) {
      _errorCode = errorCode;
    } else if (state == PlayerState.playing || state == PlayerState.buffering) {
      _errorCode = YoutubeError.none;
    }
    
    if (!_hasAutoplayed && (state == PlayerState.unStarted || state == PlayerState.cued)) {
      final shouldPlay = widget.room.youtubeStatus == 'playing' || widget.room.youtubeStatus == 'stopped';
      _hasAutoplayed = true;
      if (shouldPlay) {
        Future.microtask(() {
          if (_controller != null && mounted) {
            _controller!.playVideo();
            
            final shouldBeMuted = !widget.room.backgroundMusic;
            _lastSyncedMute = shouldBeMuted;
            if (shouldBeMuted) {
              _controller!.mute();
            } else {
              _controller!.unMute();
              _controller!.setVolume(widget.room.youtubeVolume);
            }
            
            if (widget.room.youtubeStatus != 'playing') {
              _roomService.updateRoomSettings(widget.room.roomId, {
                'youtubeStatus': 'playing',
                'youtubeSeekTime': _currentPosition.inSeconds,
              });
            }
            if (widget.room.youtubeSeekTime > 0) {
              _controller!.seekTo(seconds: widget.room.youtubeSeekTime.toDouble());
            }
          }
        });
      }
    }

    final newStatus = state == PlayerState.playing ? 'playing' : (state == PlayerState.paused ? 'paused' : null);
    if (newStatus != null && newStatus != widget.room.youtubeStatus) {
      _roomService.updateRoomSettings(widget.room.roomId, {
        'youtubeStatus': newStatus,
        'youtubeSeekTime': _currentPosition.inSeconds,
      });
    }
    
    setState(() {});
  }

  Future<void> _initPlayer(String? videoId) async {
    if (videoId == null || videoId.isEmpty || _isLoading || _isDisposed) return;
    
    final parsedId = YoutubePlayerController.convertUrlToId(videoId) ?? videoId;
    if (_currentVideoId == parsedId && _controller != null) return;

    setState(() {
      _isLoading = true;
      _currentPosition = Duration.zero;
      _errorCode = YoutubeError.none;
    });
    
    _currentVideoId = parsedId;

    try {
      final oldController = _controller;
      if (oldController != null) {
        _controller = null;
        _playerStateSubscription?.cancel();
        _videoStateSubscription?.cancel();
        await Future.delayed(const Duration(milliseconds: 100));
        oldController.close();
      }

      final controller = YoutubePlayerController.fromVideoId(
        videoId: parsedId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: false,
          mute: true,
          showVideoAnnotations: false,
          origin: 'https://www.youtube-nocookie.com',
          userAgent: 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
        ),
      );
      
      _controller = controller;
      
      _playerStateSubscription = _controller!.stream.listen((value) {
        _onPlayerStateChange(value);
      });
      
      _videoStateSubscription = _controller!.videoStateStream.listen((state) {
        if (!mounted || _isDisposed) return;
        
        final newPosition = state.position;
        
        if (_controller != null) {
          final diff = (newPosition.inSeconds - _currentPosition.inSeconds).abs();
          if (diff > 3) {
            final now = DateTime.now();
            if (_lastSeekSyncTime == null || now.difference(_lastSeekSyncTime!) > const Duration(milliseconds: 1000)) {
              _lastSeekSyncTime = now;
              _roomService.updateRoomSettings(widget.room.roomId, {
                'youtubeSeekTime': newPosition.inSeconds,
              });
            }
          }

          _controller!.volume.then((currentVol) {
            if (currentVol != widget.room.youtubeVolume && currentVol != _lastSyncedVolume) {
              final now = DateTime.now();
              if (_lastVolumeSyncTime == null || now.difference(_lastVolumeSyncTime!) > const Duration(milliseconds: 1000)) {
                _lastVolumeSyncTime = now;
                _lastSyncedVolume = currentVol;
                _roomService.updateRoomSettings(widget.room.roomId, {
                  'youtubeVolume': currentVol,
                });
              }
            }
          }).catchError((_) {});
        }
        
        setState(() {
          _currentPosition = newPosition;
        });
      });

      _hasAutoplayed = false;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [YoutubePlayer] Init error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _stopVideo() {
    _roomService.stopYoutube(widget.room.roomId);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playerStateSubscription?.cancel();
    _videoStateSubscription?.cancel();
    if (_controller != null) {
      final c = _controller;
      _controller = null;
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          c?.close();
        } catch (_) {}
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    if (widget.room.youtubeVideoId?.isEmpty ?? true) {
      return const SizedBox.shrink();
    }

    final parsedId = _currentVideoId ?? (widget.room.youtubeVideoId != null ? YoutubePlayerController.convertUrlToId(widget.room.youtubeVideoId!) : null);
    final thumbnailUrl = parsedId != null ? 'https://img.youtube.com/vi/$parsedId/hqdefault.jpg' : null;

    if (_controller == null || _isLoading) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          image: thumbnailUrl != null
              ? DecorationImage(
                  image: NetworkImage(thumbnailUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                )
              : null,
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
              Gap(12),
              Text("Synchronizing Video...", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        aspectRatio: 16 / 10,
        child: Stack(
          children: [
            Positioned.fill(
              child: YoutubePlayer(
                key: ValueKey(_currentVideoId),
                controller: _controller!,
                aspectRatio: 16 / 10,
              ),
            ),

            if (_errorCode != YoutubeError.none)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.95),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          size: 40,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        _getErrorMessage(_errorCode),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        _getErrorSubmessage(_errorCode),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      if (_isOwner) ...[
                        const Gap(24),
                        ElevatedButton.icon(
                          onPressed: _stopVideo,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text("Select Another Video", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (_isOwner)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    children: [
                      if (_showVolumeSlider)
                        Container(
                          width: 100,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                          ),
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: widget.room.youtubeVolume.toDouble(),
                              min: 0,
                              max: 100,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white24,
                              onChanged: (val) {
                                if (_controller != null) {
                                  _controller!.setVolume(val.toInt());
                                  _roomService.updateRoomSettings(widget.room.roomId, {
                                    'youtubeVolume': val.toInt(),
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showVolumeSlider = !_showVolumeSlider;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Icon(
                            widget.room.youtubeVolume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isOwner)
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: _stopVideo,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getErrorMessage(YoutubeError error) {
    switch (error) {
      case YoutubeError.notEmbeddable:
        return "Video Embedding Restricted (Error 150/101)";
      case YoutubeError.videoNotFound:
        return "Video Not Found (Error 100)";
      case YoutubeError.invalidParam:
        return "Invalid Video Parameter (Error 2)";
      case YoutubeError.html5Error:
        return "HTML5 Player Error (Error 5)";
      default:
        return "Playback Error Occurred";
    }
  }

  String _getErrorSubmessage(YoutubeError error) {
    switch (error) {
      case YoutubeError.notEmbeddable:
        return "The creator has restricted this video from being played in external apps. Please choose a different video.";
      case YoutubeError.videoNotFound:
        return "The video may have been deleted or set to private by the owner.";
      case YoutubeError.invalidParam:
        return "The video URL or ID is invalid. Please verify and try another link.";
      case YoutubeError.html5Error:
        return "This device's WebView failed to initialize the HTML5 player.";
      default:
        return "YouTube failed to load or play this video. Try another link.";
    }
  }
}