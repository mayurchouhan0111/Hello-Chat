import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../utils/svga_parser_util.dart';

class ResourceLoggerService {
  static final ResourceLoggerService _instance = ResourceLoggerService._internal();
  factory ResourceLoggerService() => _instance;
  ResourceLoggerService._internal();

  Timer? _timer;
  bool _isRunning = false;

  /// Starts the 60-second periodic resource logger (debug/profile only).
  void start({Duration interval = const Duration(seconds: 60)}) {
    if (kReleaseMode && !kProfileMode) return;
    if (_isRunning) return;
    _isRunning = true;

    // Log immediately on start, then periodically
    _logResources();
    _timer = Timer.periodic(interval, (_) => _logResources());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  void _logResources() {
    // Only run in non-release or when explicitly profiling
    if (kReleaseMode && !kProfileMode) {
      return;
    }

    int threads = -1;
    int fds = -1;
    int rssBytes = 0;

    try {
      rssBytes = ProcessInfo.currentRss;
    } catch (_) {}

    try {
      if (Platform.isAndroid || Platform.isLinux) {
        final statusFile = File('/proc/self/status');
        if (statusFile.existsSync()) {
          final lines = statusFile.readAsLinesSync();
          for (final line in lines) {
            if (line.startsWith('Threads:')) {
              final parts = line.split(RegExp(r'\s+'));
              if (parts.length >= 2) {
                threads = int.tryParse(parts[1]) ?? -1;
              }
              break;
            }
          }
        }

        final fdDir = Directory('/proc/self/fd');
        if (fdDir.existsSync()) {
          try {
            fds = fdDir.listSync().length;
          } catch (_) {
            fds = -1;
          }
        }
      }
    } catch (_) {}

    int imgCacheCount = 0;
    int imgCacheBytes = 0;
    try {
      final cache = PaintingBinding.instance.imageCache;
      imgCacheCount = cache.currentSize;
      imgCacheBytes = cache.currentSizeBytes;
    } catch (_) {}

    final int svgaCount = SvgaParserUtil.movieCacheCount;
    final int svgaAudioCount = SvgaParserUtil.preparedAudioCacheCount;

    final double rssMB = rssBytes / (1024 * 1024);
    final double imgMB = imgCacheBytes / (1024 * 1024);

    debugPrint(
      '📊 [RESOURCE_LOGGER] '
      'threads=${threads >= 0 ? threads : "n/a"} '
      'fds=${fds >= 0 ? fds : "n/a"} '
      'rssMB=${rssMB.toStringAsFixed(1)} '
      'imgCache=$imgCacheCount (${imgMB.toStringAsFixed(1)}MB) '
      'svgaCache=$svgaCount '
      'svgaAudio=$svgaAudioCount',
    );
  }
}
