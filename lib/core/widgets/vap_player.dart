import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tancent_vap/tancent_vap.dart';
import 'package:path_provider/path_provider.dart';

class VapAnimation extends StatefulWidget {
  final String assetPath;
  final String? profileImageUrl;
  final Uint8List? profileImageBytes;
  final String? fallbackImageUrl;
  final BoxFit fit;
  final bool loop;
  final VoidCallback? onComplete;
  final VoidCallback? onError;
  final VoidCallback? onStart;

  const VapAnimation({
    super.key,
    required this.assetPath,
    this.profileImageUrl,
    this.profileImageBytes,
    this.fallbackImageUrl,
    this.fit = BoxFit.contain,
    this.loop = false,
    this.onComplete,
    this.onError,
    this.onStart,
  });

  static final Map<String, String> _extractedCache = {};
  // De-duplicates concurrent downloads/extractions of the same asset.
  static final Map<String, Future<String?>> _inFlight = {};
  static String? _cachedTempDirPath;

  static Future<String?> preCache(String assetPath) {
    final cached = _extractedCache[assetPath];
    if (cached != null && File(cached).existsSync()) return Future.value(cached);

    if (_inFlight.containsKey(assetPath)) {
      return _inFlight[assetPath]!;
    }

    const loadTimeout = Duration(seconds: 8);
    final future = _load(assetPath).timeout(
      loadTimeout,
      onTimeout: () {
        debugPrint('[VAP_TRACE] preCache TIMEOUT: asset="$assetPath" after ${loadTimeout.inSeconds}s');
        _inFlight.remove(assetPath);
        return null;
      },
    ).catchError((e, st) {
      debugPrint('[VAP_TRACE] preCache error: asset="$assetPath", error=$e\n$st');
      _inFlight.remove(assetPath);
      return null;
    }).whenComplete(() {
      _inFlight.remove(assetPath);
    });

    _inFlight[assetPath] = future;
    return future;
  }

  static Future<String?> _load(String assetPath) async {
    try {
      debugPrint('[VAP_TRACE] _load start: asset="$assetPath"');
      if (_cachedTempDirPath == null) {
        final tempDir = await getTemporaryDirectory();
        _cachedTempDirPath = tempDir.path;
      }
      final tempDirPath = _cachedTempDirPath!;
      final safeName = assetPath.replaceAll(RegExp(r'[^\w.]'), '_');
      final target = File('$tempDirPath/$safeName');

      if (await target.exists() && await target.length() > 0) {
        debugPrint('[VAP_TRACE] _load cache hit: asset="$assetPath", path="${target.path}"');
        return _extractedCache[assetPath] = target.path;
      }
      debugPrint('[VAP_TRACE] _load cache miss, extracting off UI thread: asset="$assetPath"');

      // Write to a .part file and rename, so a crash never leaves a truncated "valid" file.
      final part = File('${target.path}.part');
      final bool isRemote = assetPath.startsWith('http://') || assetPath.startsWith('https://');

      if (isRemote) {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        try {
          final request = await client.getUrl(Uri.parse(assetPath));
          final response = await request.close();
          if (response.statusCode != 200) {
            throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(assetPath));
          }
          await response.pipe(part.openWrite());
        } finally {
          client.close(force: true);
        }
        if (await part.exists() && await part.length() > 0) {
          if (await target.exists()) await target.delete();
          await part.rename(target.path);
          debugPrint('[VAP_TRACE] _load download complete: asset="$assetPath", path="${target.path}"');
          return _extractedCache[assetPath] = target.path;
        }
      } else {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

        // File extraction/copy off the UI thread in a background worker isolate
        final partPath = part.path;
        final targetPath = target.path;
        final bool written = await Isolate.run(() {
          final p = File(partPath);
          p.writeAsBytesSync(bytes, flush: true);
          if (p.existsSync() && p.lengthSync() > 0) {
            final t = File(targetPath);
            if (t.existsSync()) t.deleteSync();
            p.renameSync(targetPath);
            return true;
          }
          return false;
        });

        if (written && await target.exists() && await target.length() > 0) {
          debugPrint('[VAP_TRACE] _load asset extraction complete: asset="$assetPath", path="${target.path}", size=${await target.length()}');
          return _extractedCache[assetPath] = target.path;
        }
      }
    } catch (e, st) {
      debugPrint('[VAP_TRACE] _load exception: asset="$assetPath", error=$e\n$st');
    }
    return null;
  }

  @override
  State<VapAnimation> createState() => _VapAnimationState();
}

class _VapAnimationState extends State<VapAnimation> {
  VapController? _controller;
  bool _hasError = false;
  bool _completed = false;

  @override
  void didUpdateWidget(VapAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileImageUrl != widget.profileImageUrl ||
        oldWidget.profileImageBytes != widget.profileImageBytes) {
      _setProfileTag();
    }
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        c.setAnimListener(onVideoComplete: null, onFailed: null);
      } catch (_) {}
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _setProfileTag() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty) {
        await ctrl.setVapTagContent('user', ImageURLContent(widget.profileImageUrl!));
      } else if (widget.profileImageBytes != null) {
        await ctrl.setVapTagContent('user', ImageBase64Content(base64Encode(widget.profileImageBytes!)));
      }
    } catch (e) {
      debugPrint('VapAnimation: Failed to set profile tag - $e');
    }
  }

  ScaleType _mapFit(BoxFit fit) => switch (fit) {
        BoxFit.cover => ScaleType.centerCrop,
        BoxFit.fill => ScaleType.fitXY,
        _ => ScaleType.fitCenter,
      };

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const SizedBox.shrink();

    // Audio is enabled (mute: false). RepaintBoundary isolates the
    // PlatformView layer from the parent's repaints.
    return RepaintBoundary(
      child: VapView(
        key: widget.key ?? ValueKey('vap_${widget.assetPath}'),
        scaleType: _mapFit(widget.fit),
        repeat: widget.loop ? 99999 : 0,
        mute: false,
        onViewCreated: _onViewCreated,
      ),
    );
  }

  void _fail([String? reason]) {
    debugPrint('[VAP_TRACE] [VapPlayer] onFail: asset="${widget.assetPath}", reason=${reason ?? "unknown error"}');
    if (!mounted || _hasError) return;
    setState(() => _hasError = true);
    widget.onError?.call();
  }

  Future<void> _onViewCreated(VapController controller) async {
    _controller = controller;

    controller.setAnimListener(
      onVideoStart: () {
        debugPrint('[VAP_TRACE] [VapPlayer] onStart: asset="${widget.assetPath}"');
        if (mounted) widget.onStart?.call();
      },
      onVideoComplete: () {
        debugPrint('[VAP_TRACE] [VapPlayer] onComplete: asset="${widget.assetPath}"');
        // Native fires complete from both decoder and watchdog; report once.
        if (!mounted || _completed) return;
        _completed = true;
        widget.onComplete?.call();
      },
      onFailed: (code, type, msg) {
        debugPrint('[VAP_TRACE] [VapPlayer] onFail: asset="${widget.assetPath}", code=$code, type=$type, msg=$msg');
        _fail('native error code $code ($msg)');
      },
    );

    try {
      await _setProfileTag();
    } catch (e) {
      debugPrint('⚠️ [VapPlayer] Error setting profile tag: $e');
    }

    try {
      final path = await VapAnimation.preCache(widget.assetPath);
      if (path == null) {
        debugPrint('[VAP_TRACE] [VapPlayer] playFile REFUSED: asset="${widget.assetPath}", reason=preCache returned null');
        throw StateError('Failed to prepare ${widget.assetPath}');
      }
      if (!mounted || _controller != controller) {
        debugPrint('[VAP_TRACE] [VapPlayer] playFile REFUSED: asset="${widget.assetPath}", reason=controller unmounted or changed');
        return;
      }

      if (widget.loop) await controller.setLoop(99999);
      debugPrint('[VAP_TRACE] [VapPlayer] playFile requested: asset="${widget.assetPath}", path="$path"');
      await controller.playFile(path, widget.key?.toString() ?? widget.assetPath);
    } catch (e, st) {
      debugPrint('[VAP_TRACE] [VapPlayer] playFile exception: asset="${widget.assetPath}", error=$e\n$st');
      _fail('exception: $e');
    }
  }
}
