import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'app_persistent_cache.dart';

class SvgaParserUtil {
  // Cache of raw bytes to avoid redundant file I/O
  static final Map<String, Uint8List> _byteCache = {};
  static final List<String> _cacheKeys = [];
  static const int _maxCacheSize = 60;

  // Cache of parsed MovieEntity objects to avoid CPU-heavy parsing & image decoding on every load
  static final Map<String, MovieEntity> _movieCache = {};
  static final List<String> _movieCacheKeys = [];
  static const int _maxMovieCacheSize = 80;

  // Track pending loads to prevent concurrent duplicate reads
  static final Map<String, Future<Uint8List>> _pendingLoads = {};

  /// Returns filtered SVGA bytes (non-image assets removed) on a background isolate.
  /// Each call produces fresh bytes so SVGAParser always returns a new MovieEntity.
  static Future<Uint8List> getFilteredBytes(List<int> rawBytes) async {
    return Uint8List.fromList(rawBytes);
  }

  /// Maps remote SVGA gift URLs to local SVGA asset paths if available
  static String? getLocalGiftSvgaPath(String urlOrFile) {
    final lower = urlOrFile.toLowerCase();
    if (lower.contains('mystic_rings') || lower.contains('mystic_ring')) {
      return 'assets/svga/mystic_rings.svga';
    }
    if (lower.contains('235.svga') || lower.contains('royal_carriage')) {
      return 'assets/svga/235.svga';
    }
    if (lower.contains('100_optimized') || lower.contains('crystal_palace') || lower.contains('100.svga')) {
      return 'assets/svga/100_optimized.svga';
    }
    return null;
  }

  /// Maps remote Lottie gift URLs to local Lottie asset paths if available
  static String? getLocalLottiePath(String urlOrFile) {
    final lower = urlOrFile.toLowerCase();
    if (lower.contains('rose.json') || lower.contains('rose')) {
      return 'assets/animations/lottie/Rose.json';
    }
    if (lower.contains('balloon.json') || lower.contains('balloon')) {
      return 'assets/animations/lottie/balloon.json';
    }
    if (lower.contains('pink cake.json') || lower.contains('pink_cake') || lower.contains('cake')) {
      return 'assets/animations/lottie/pink cake.json';
    }
    if (lower.contains('red diamond.json') || lower.contains('red_diamond') || lower.contains('diamond')) {
      return 'assets/animations/lottie/Red Diamond.json';
    }
    if (lower.contains('cat.json') || lower.contains('lucky_cat') || lower.contains('cat')) {
      return 'assets/animations/lottie/cat.json';
    }
    if (lower.contains('premium gold.json') || lower.contains('gold_crown') || lower.contains('crown')) {
      return 'assets/animations/lottie/Premium Gold.json';
    }
    if (lower.contains('celebration.json') || lower.contains('celebration')) {
      return 'assets/animations/lottie/Celebration.json';
    }
    if (lower.contains('rocket loader.json') || lower.contains('rocket_loader') || lower.contains('rocket')) {
      return 'assets/animations/lottie/Rocket loader.json';
    }
    if (lower.contains('red car.json') || lower.contains('red_car') || lower.contains('car')) {
      return 'assets/animations/lottie/Red Car.json';
    }
    if (lower.contains('airplane.json') || lower.contains('airplane')) {
      return 'assets/animations/lottie/airplane.json';
    }
    return null;
  }

  /// Returns a cached MovieEntity, or decodes it and caches it.
  /// movie.autorelease is set to false to prevent automatic disposal by individual controllers.
  static Future<MovieEntity> decodeSafeFromAssets(String assetPath) async {
    final cleanPath = assetPath.trim();
    if (_movieCache.containsKey(cleanPath)) {
      return _movieCache[cleanPath]!;
    }

    final bytes = await _loadBytes(cleanPath);
    final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
    movie.autorelease = false;

    _movieCache[cleanPath] = movie;
    _movieCacheKeys.add(cleanPath);
    if (_movieCacheKeys.length > _maxMovieCacheSize) {
      final oldest = _movieCacheKeys.removeAt(0);
      final evicted = _movieCache.remove(oldest);
      evicted?.dispose();
    }

    return movie;
  }

  static Future<MovieEntity> decodeSafeFromUrl(String url) async {
    final cleanUrl = url.trim();
    
    // Auto-intercept remote gift URLs mapping to local assets
    final localPath = getLocalGiftSvgaPath(cleanUrl);
    if (localPath != null) {
      print("🚀 SvgaParserUtil: Intercepted remote SVGA URL ($cleanUrl), loading local asset instead: $localPath");
      return decodeSafeFromAssets(localPath);
    }

    if (_movieCache.containsKey(cleanUrl)) {
      return _movieCache[cleanUrl]!;
    }

    final bytes = await _loadUrlBytes(cleanUrl);
    final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
    movie.autorelease = false;

    _movieCache[cleanUrl] = movie;
    _movieCacheKeys.add(cleanUrl);
    if (_movieCacheKeys.length > _maxMovieCacheSize) {
      final oldest = _movieCacheKeys.removeAt(0);
      final evicted = _movieCache.remove(oldest);
      evicted?.dispose();
    }

    return movie;
  }

  static Future<Uint8List> _loadBytes(String cleanPath) async {
    if (_byteCache.containsKey(cleanPath)) {
      return _byteCache[cleanPath]!;
    }
    if (_pendingLoads.containsKey(cleanPath)) {
      return _pendingLoads[cleanPath]!;
    }

    final future = Future(() async {
      final data = await rootBundle.load(cleanPath);
      final raw = data.buffer.asUint8List();
      final filtered = await getFilteredBytes(raw);

      _byteCache[cleanPath] = filtered;
      _cacheKeys.add(cleanPath);
      if (_cacheKeys.length > _maxCacheSize) {
        final oldest = _cacheKeys.removeAt(0);
        _byteCache.remove(oldest);
      }
      return filtered;
    });

    _pendingLoads[cleanPath] = future;
    try {
      return await future;
    } finally {
      _pendingLoads.remove(cleanPath);
    }
  }

  static Future<Uint8List> _loadUrlBytes(String cleanUrl) async {
    if (_byteCache.containsKey(cleanUrl)) {
      return _byteCache[cleanUrl]!;
    }
    if (_pendingLoads.containsKey(cleanUrl)) {
      return _pendingLoads[cleanUrl]!;
    }

    final future = Future(() async {
      final file = await AppPersistentCache.getFile(cleanUrl);
      final raw = await file.readAsBytes();
      final filtered = await getFilteredBytes(raw);

      _byteCache[cleanUrl] = filtered;
      _cacheKeys.add(cleanUrl);
      if (_cacheKeys.length > _maxCacheSize) {
        final oldest = _cacheKeys.removeAt(0);
        _byteCache.remove(oldest);
      }
      return filtered;
    });

    _pendingLoads[cleanUrl] = future;
    try {
      return await future;
    } finally {
      _pendingLoads.remove(cleanUrl);
    }
  }

  /// Preloads and parses VIP asset MovieEntity objects into cache for instant playback on startup
  static void preloadVipAssets() {
    Future(() async {
      try {
        print("🚀 SvgaParserUtil: Preloading and parsing local VIP assets into memory cache...");
        
        final assetsToPreload = [
          // VIP 1
          'assets/VIP/VIP 1/Frame.svga',
          'assets/VIP/VIP 1/Entry.svga',
          'assets/VIP/VIP 1/Strip.svga',
          'assets/VIP/VIP 1/Badge.svga',
          'assets/VIP/VIP 1/Sound Waives.svga',

          // VIP 2
          'assets/VIP/VIP 2/VIP 2/Frame.svga',
          'assets/VIP/VIP 2/VIP 2/Entry.svga',
          'assets/VIP/VIP 2/VIP 2/Strip.svga',
          'assets/VIP/VIP 2/VIP 2/Badge.svga',
          'assets/VIP/VIP 2/VIP 2/Mic Waives.svga',

          // VIP 3
          'assets/VIP/VIP 3/VIP 3/Frame.svga',
          'assets/VIP/VIP 3/VIP 3/Entry.svga',
          'assets/VIP/VIP 3/VIP 3/Strip.svga',
          'assets/VIP/VIP 3/VIP 3/Badge.svga',
          'assets/VIP/VIP 3/VIP 3/Mic Waives.svga',

          // VIP 4
          'assets/VIP/VIP 4/VIP 4/Frame.svga',
          'assets/VIP/VIP 4/VIP 4/Entry.svga',
          'assets/VIP/VIP 4/VIP 4/Strip.svga',
          'assets/VIP/VIP 4/VIP 4/Badge.svga',
          'assets/VIP/VIP 4/VIP 4/Mic Waives.svga',

          // VIP 5
          'assets/VIP/VIP 5/VIP 5/User Frame.svga',
          'assets/VIP/VIP 5/VIP 5/Entry.svga',
          'assets/VIP/VIP 5/VIP 5/Strip.svga',
          'assets/VIP/VIP 5/VIP 5/Badge.svga',
          'assets/VIP/VIP 5/VIP 5/Mic Waives.svga',

          // VIP 6
          'assets/VIP/VIP 6/VIP 6/User Frame.svga',
          'assets/VIP/VIP 6/VIP 6/VIP 6 Entry.svga',
          'assets/VIP/VIP 6/VIP 6/Strip.svga',
          'assets/VIP/VIP 6/VIP 6/Badge.svga',
          'assets/VIP/VIP 6/VIP 6/Mic Waives.svga',

          // VIP 7
          'assets/VIP/VIP 7/VIP 7/Frame.svga',
          'assets/VIP/VIP 7/VIP 7/Entry.svga',
          'assets/VIP/VIP 7/VIP 7/Strip.svga',
          'assets/VIP/VIP 7/VIP 7/Badge.svga',
          'assets/VIP/VIP 7/VIP 7/Mic Waives.svga',

          // VIP 8
          'assets/VIP/VIP 8/VIP 8/User Frame.svga',
          'assets/VIP/VIP 8/VIP 8/VIP 8 Entry Effect.svga',
          'assets/VIP/VIP 8/VIP 8/Badge.svga',
          'assets/VIP/VIP 8/VIP 8/Mic Waives.svga',

          // VIP Crowns
          'assets/VIP/VIP 1/Crown 1.svga',
          'assets/VIP/VIP 3/VIP 3/Crown 1.svga',
          'assets/VIP/VIP 4/VIP 4/Crown 1.svga',
          'assets/VIP/VIP 5/VIP 5/Crown 1.svga',
          'assets/VIP/VIP 6/VIP 6/Crown 1.svga',
          'assets/VIP/VIP 7/VIP 7/Crown 1.svga',
          'assets/VIP/VIP 8/VIP 8/VIP 8 Crown 1.svga',
        ];

        for (final assetPath in assetsToPreload) {
          try {
            await decodeSafeFromAssets(assetPath);
          } catch (pe) {
            print("⚠️ SvgaParserUtil: Failed to preload/parse SVGA asset ($assetPath): $pe");
          }
        }

        print("✅ SvgaParserUtil: All local VIP assets preloaded and decoded successfully!");
      } catch (e) {
        print("⚠️ SvgaParserUtil: Failed to preload local VIP assets: $e");
      }
    });
  }
}
