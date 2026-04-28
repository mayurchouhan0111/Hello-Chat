import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// A production-ready replacement for the internal RawYoutubePlayer 
/// to fix the Oppo/ColorOS "int is not a subtype of String" crash.
class SafeYoutubePlayer extends StatefulWidget {
  final YoutubePlayerController controller;
  final String videoId;
  final void Function(YoutubeMetaData metaData)? onEnded;

  const SafeYoutubePlayer({
    super.key,
    required this.controller,
    required this.videoId,
    this.onEnded,
  });

  @override
  State<SafeYoutubePlayer> createState() => _SafeYoutubePlayerState();
}

class _SafeYoutubePlayerState extends State<SafeYoutubePlayer> with WidgetsBindingObserver {
  bool _isPlayerReady = false;
  bool _onLoadStopCalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_handleControllerCommands);
  }

  void _handleControllerCommands() {
    if (!_isPlayerReady) return;
    
    final value = widget.controller.value;
    final web = value.webViewController;
    if (web == null) return;

    // 1. Playback State Sync
    if (value.isPlaying) {
      web.evaluateJavascript(source: 'player.playVideo();');
    } else {
      web.evaluateJavascript(source: 'player.pauseVideo();');
    }
  }

  int _safeInt(dynamic value, {int defaultValue = -1}) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  double _safeDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  void didUpdateWidget(SafeYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleControllerCommands);
      widget.controller.addListener(_handleControllerCommands);
    }
    
    final oldId = oldWidget.videoId;
    final newId = widget.videoId;
    if (newId != oldId && _isPlayerReady) {
      widget.controller.value.webViewController?.evaluateJavascript(
        source: 'player.loadVideoById("$newId");'
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerCommands);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: true,
          child: InAppWebView(
            initialData: InAppWebViewInitialData(
              data: _getPlayerHtml(),
              encoding: 'utf-8',
              baseUrl: WebUri.uri(Uri.https('youtube.com')),
              mimeType: 'text/html',
            ),
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              transparentBackground: true,
              disableContextMenu: true,
              supportZoom: false,
              allowsInlineMediaPlayback: true,
              useHybridComposition: widget.controller.flags.useHybridComposition,
            ),
            onWebViewCreated: (webController) {
              widget.controller.updateValue(
                widget.controller.value.copyWith(webViewController: webController),
              );

              webController
                ..addJavaScriptHandler(
                  handlerName: 'Ready',
                  callback: (_) {
                    if (mounted) {
                      setState(() => _isPlayerReady = true);
                    }
                    if (_onLoadStopCalled) {
                      widget.controller.updateValue(widget.controller.value.copyWith(isReady: true));
                    }
                  },
                )
                ..addJavaScriptHandler(
                  handlerName: 'StateChange',
                  callback: (args) {
                    if (!mounted) return;
                    final state = _safeInt(args.first);
                    switch (state) {
                      case -1:
                        widget.controller.updateValue(widget.controller.value.copyWith(playerState: PlayerState.unStarted, isLoaded: true));
                        break;
                      case 0:
                        widget.onEnded?.call(widget.controller.metadata);
                        widget.controller.updateValue(widget.controller.value.copyWith(playerState: PlayerState.ended));
                        break;
                      case 1:
                        widget.controller.updateValue(widget.controller.value.copyWith(playerState: PlayerState.playing, isPlaying: true, hasPlayed: true, errorCode: 0));
                        break;
                      case 2:
                        widget.controller.updateValue(widget.controller.value.copyWith(playerState: PlayerState.paused, isPlaying: false));
                        break;
                      case 3:
                        widget.controller.updateValue(widget.controller.value.copyWith(playerState: PlayerState.buffering));
                        break;
                      case 5:
                        widget.controller.updateValue(widget.controller.value.copyWith(playerState: PlayerState.cued));
                        break;
                    }
                  },
                )
                ..addJavaScriptHandler(
                  handlerName: 'PlaybackQualityChange',
                  callback: (args) {
                    if (!mounted) return;
                    widget.controller.updateValue(
                      widget.controller.value.copyWith(playbackQuality: args.first.toString()),
                    );
                  },
                )
                ..addJavaScriptHandler(
                  handlerName: 'PlaybackRateChange',
                  callback: (args) {
                    if (!mounted) return;
                    widget.controller.updateValue(
                      widget.controller.value.copyWith(playbackRate: _safeDouble(args.first)),
                    );
                  },
                )
                ..addJavaScriptHandler(
                  handlerName: 'Errors',
                  callback: (args) {
                    if (!mounted) return;
                    final errorCode = _safeInt(args.first);
                    widget.controller.updateValue(widget.controller.value.copyWith(errorCode: errorCode));
                  },
                )
                ..addJavaScriptHandler(
                  handlerName: 'VideoData',
                  callback: (args) {
                    if (!mounted) return;
                    try {
                      final data = args.first;
                      widget.controller.updateValue(
                        widget.controller.value.copyWith(
                            metaData: YoutubeMetaData.fromRawData(data)),
                      );
                    } catch (e) {
                      debugPrint("SafePlayer: Metadata error: $e");
                    }
                  },
                )
                ..addJavaScriptHandler(
                  handlerName: 'VideoTime',
                  callback: (args) {
                    if (!mounted) return;
                    final position = _safeDouble(args.first) * 1000;
                    final buffered = _safeDouble(args.last);
                    widget.controller.updateValue(
                      widget.controller.value.copyWith(
                        position: Duration(milliseconds: position.floor()),
                        buffered: buffered,
                      ),
                    );
                  },
                );
            },
            onLoadStop: (_, __) {
              if (mounted) {
                setState(() => _onLoadStopCalled = true);
              }
              if (_isPlayerReady) {
                widget.controller.updateValue(widget.controller.value.copyWith(isReady: true));
              }
            },
          ),
        ),
        if (!_isPlayerReady || !_onLoadStopCalled)
          const Center(
            child: CircularProgressIndicator(color: Colors.redAccent),
          ),
      ],
    );
  }

  String _getPlayerHtml() {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>html,body {margin: 0;padding: 0;background-color: #000;overflow: hidden;position: fixed;height: 100%;width: 100%;pointer-events: none;}</style>
        <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>
    </head>
    <body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
            var player;
            var timerId;
            function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                    height: '100%', width: '100%',
                    videoId: '${widget.videoId}',
                    playerVars: { 
                      'controls': 0, 
                      'playsinline': 1, 
                      'enablejsapi': 1, 
                      'fs': 0, 
                      'rel': 0, 
                      'modestbranding': 1, 
                      'origin': 'https://youtube.com',
                      'autoplay': ${widget.controller.flags.autoPlay ? 1 : 0},
                      'mute': ${widget.controller.flags.mute ? 1 : 0}
                    },
                    events: {
                        onReady: function(e) { 
                          window.flutter_inappwebview.callHandler('Ready'); 
                          // Send initial metadata
                          sendVideoData(player);
                        },
                        onStateChange: function(e) { 
                          window.flutter_inappwebview.callHandler('StateChange', e.data); 
                          if (e.data == 1) {
                            startTimer(); 
                          } else {
                            stopTimer();
                          }
                        },
                        onPlaybackQualityChange: function(e) { window.flutter_inappwebview.callHandler('PlaybackQualityChange', e.data); },
                        onPlaybackRateChange: function(e) { window.flutter_inappwebview.callHandler('PlaybackRateChange', e.data); },
                        onError: function(e) { window.flutter_inappwebview.callHandler('Errors', e.data); }
                    }
                });
            }

            function startTimer() {
              stopTimer();
              timerId = setInterval(function() {
                window.flutter_inappwebview.callHandler('VideoTime', player.getCurrentTime(), player.getVideoLoadedFraction());
              }, 500);
            }

            function stopTimer() {
              clearInterval(timerId);
            }

            function sendVideoData(p) {
              var data = {
                'duration': p.getDuration(),
                'title': p.getVideoData().title,
                'author': p.getVideoData().author,
                'videoId': p.getVideoData().video_id
              };
              window.flutter_inappwebview.callHandler('VideoData', data);
            }
        </script>
    </body>
    </html>
    ''';
  }
}
