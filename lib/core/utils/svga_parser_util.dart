import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'app_persistent_cache.dart';

class PreparedSvgaAudio {
  final File file;
  final int delayMs;
  PreparedSvgaAudio({required this.file, required this.delayMs});
}

class SvgaParserUtil {
  static Directory? _tempAudioDir;

  static final Map<String, List<PreparedSvgaAudio>> _preparedAudioCache = {};

  /// Extracts and verifies embedded audio tracks in [videoItem] into temp storage.
  /// Pre-extracting audio before starting animation playback guarantees that audio
  /// and visual frames start in 100% lockstep synchronization with zero startup delay.
  static Future<List<PreparedSvgaAudio>> getPreparedAudios(dynamic videoItem, String sourceKey, int fps) async {
    // Check in-memory prepared audio cache first
    final cached = _preparedAudioCache[sourceKey];
    if (cached != null && cached.isNotEmpty && cached.every((a) => a.file.existsSync())) {
      return cached;
    }

    final List<PreparedSvgaAudio> list = [];
    try {
      MovieEntity? movieItem;
      if (videoItem is MovieEntity) {
        movieItem = videoItem;
      } else if (videoItem != null) {
        try {
          final dynamic dyn = videoItem;
          if (dyn.movieItem is MovieEntity) {
            movieItem = dyn.movieItem as MovieEntity;
          }
        } catch (_) {}
        if (movieItem == null && videoItem is MovieEntity) {
          movieItem = videoItem;
        }
      }
      if (movieItem == null) return list;

      final audios = movieItem.audios;
      final images = movieItem.images;
      final int effectiveFps = fps > 0 ? fps : (movieItem.params.fps > 0 ? movieItem.params.fps : 30);

      if (audios.isNotEmpty && images.isNotEmpty && effectiveFps > 0) {
        if (_tempAudioDir == null) {
          try {
            _tempAudioDir = await getTemporaryDirectory();
          } catch (_) {
            _tempAudioDir = Directory.systemTemp;
          }
        }
        final tempDir = _tempAudioDir!;
        final assetHash = sourceKey.hashCode.abs();

        for (final audio in audios) {
          final String audioKey = audio.audioKey;
          final dynamic rawBytes = images[audioKey];
          if (rawBytes != null) {
            final List<int> bytes = rawBytes is List<int> ? rawBytes : List<int>.from(rawBytes);
            if (bytes.isNotEmpty) {
              String ext = 'mp3';
              if (bytes.length >= 4) {
                if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
                  ext = 'mp3';
                } else if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
                  ext = 'wav';
                } else if (bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53) {
                  ext = 'ogg';
                } else if (bytes[0] == 0xFF && (bytes[1] & 0xF6) == 0xF0) {
                  ext = 'aac';
                } else if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
                  ext = 'mp3';
                }
              }

              final tempFile = File('${tempDir.path}/svga_audio_${assetHash}_$audioKey.$ext');
              if (!await tempFile.exists() || (await tempFile.length()) != bytes.length) {
                await tempFile.writeAsBytes(bytes, flush: true);
              }

              final int delayMs = (audio.startFrame / effectiveFps * 1000).toInt();
              list.add(PreparedSvgaAudio(file: tempFile, delayMs: delayMs));
            }
          }
        }
      }
      if (list.isNotEmpty) {
        _preparedAudioCache[sourceKey] = list;
      }
    } catch (e) {
      debugPrint("[SvgaParserUtil] Error preparing embedded audio: $e");
    }
    return list;
  }
  // Cache of raw bytes to avoid redundant file I/O
  static final Map<String, Uint8List> _byteCache = {};
  static final List<String> _cacheKeys = [];
  static const int _maxCacheSize = 60;

  // Cache of parsed MovieEntity objects to avoid CPU-heavy parsing & image decoding on every load
  static final Map<String, MovieEntity> _movieCache = {};
  static final List<String> _movieCacheKeys = [];
  static const int _maxMovieCacheSize = 120;
  // Protected assets (e.g. preloaded VIP frames/badges/entry effects) that must never be evicted
  static final Set<String> _protectedAssetKeys = {};

  // Track pending loads to prevent concurrent duplicate reads
  static final Map<String, Future<Uint8List>> _pendingLoads = {};

  /// Returns filtered SVGA bytes (non-image assets removed) on a background isolate.
  /// Each call produces fresh bytes so SVGAParser always returns a new MovieEntity.
  static Future<Uint8List> getFilteredBytes(List<int> rawBytes) async {
    return Uint8List.fromList(rawBytes);
  }

  /// Maps remote SVGA gift URLs to local SVGA asset paths if available
  /// Filename of a remote URL with scheme/host/query stripped, lowercased.
  static String _remoteFileName(String url) {
    String lower = url.toLowerCase();
    final int q = lower.indexOf('?');
    if (q >= 0) lower = lower.substring(0, q);
    final int slash = lower.lastIndexOf('/');
    return slash >= 0 ? lower.substring(slash + 1) : lower;
  }

  static String? getLocalGiftSvgaPath(String urlOrFile, {String? giftId, String? giftName}) {
    final lower = urlOrFile.toLowerCase();
    final lowerId = (giftId ?? '').toLowerCase();
    final lowerName = (giftName ?? '').toLowerCase();
    if (urlOrFile.startsWith('assets/') && lower.endsWith('.svga')) {
      return urlOrFile;
    }

    // Check Cloudinary hashes, gift IDs, gift names, or filename patterns
    if (lower.contains('qmoxmf6o8n03nxklpk8d') ||
        lower.contains('mystic_rings') ||
        lower.contains('mystic_ring') ||
        lowerId.contains('mystic_rings') ||
        lowerName.contains('mystic ring')) {
      return 'assets/svga/mystic_rings.svga';
    }
    if (lower.contains('omoseg3av1jq44ttwh8y') ||
        lower.contains('100_optimized') ||
        lower.contains('100.svga') ||
        lower.contains('crystal_palace') ||
        lowerId.contains('crystal_palace') ||
        lowerName.contains('crystal palace')) {
      return 'assets/svga/100_optimized.svga';
    }
    if (lower.contains('lec9nqerf5xwsk2enf05') ||
        lower.contains('235.svga') ||
        lower.contains('royal_carriage') ||
        lowerId.contains('royal_carriage') ||
        lowerName.contains('royal carriage')) {
      return 'assets/svga/235.svga';
    }
    if (lower.contains('cat_gift.svga') ||
        lower.contains('cat_gift') ||
        lowerId.contains('cat_gift') ||
        lowerName.contains('cat gift')) {
      return 'assets/svga/cat_gift.svga';
    }
    if (lower.contains('1790953721172_138') ||
        lower.contains('138.svga') ||
        lower.contains('moonlight_panda') ||
        lower.contains('panda') ||
        lowerId == 'vegroup' ||
        lowerId == 'vegswq5detbzuyvslocg' ||
        lowerName.contains('moonlight panda')) {
      return 'assets/animations/gifts/138.svga';
    }
    if (lower.contains('1790955395700') ||
        lower.contains('love you.svga') ||
        lower.contains('love%20you') ||
        lower.contains('love_you') ||
        lowerId == 'tgwg0fbzv9lbcochupko' ||
        lowerName.contains('love you')) {
      return 'assets/animations/gifts/Love You.svga';
    }

    // Remote URLs: exact known filenames fallback
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final String name = _remoteFileName(lower);
      if (name.endsWith('cat_gift.svga')) return 'assets/svga/cat_gift.svga';
      if (name.endsWith('mystic_rings.svga')) return 'assets/svga/mystic_rings.svga';
      if (name.endsWith('235.svga')) return 'assets/svga/235.svga';
      if (name.endsWith('100_optimized.svga')) return 'assets/svga/100_optimized.svga';
      if (name.endsWith('138.svga')) return 'assets/animations/gifts/138.svga';
      if (name.endsWith('love you.svga') || name.endsWith('love_you.svga')) {
        return 'assets/animations/gifts/Love You.svga';
      }
      return null;
    }
    return null;
  }

  /// Maps remote Lottie gift URLs or IDs to local Lottie asset paths if available
  static String? getLocalLottiePath(String urlOrFile, {String? giftId, String? giftName}) {
    final lower = urlOrFile.toLowerCase();
    final lowerId = (giftId ?? '').toLowerCase();
    final lowerName = (giftName ?? '').toLowerCase();
    if (urlOrFile.startsWith('assets/') && lower.endsWith('.json')) {
      return urlOrFile;
    }

    if (lower.contains('r3bwgs65eoklpc7uwcqc') ||
        lower.contains('rose.json') ||
        lowerId == 'rose' ||
        lowerName == 'rose') {
      return 'assets/animations/lottie/Rose.json';
    }
    if (lower.contains('pucdrkh5wlymjygjpmj2') ||
        lower.contains('balloon.json') ||
        lowerId == 'balloon' ||
        lowerName.contains('balloon')) {
      return 'assets/animations/lottie/balloon.json';
    }
    if (lower.contains('dqvyi6mzfdihmswi5urq') ||
        lower.contains('celebration.json') ||
        lowerId == 'cake' ||
        lowerId == 'celebration' ||
        lowerName.contains('celebration')) {
      return 'assets/animations/lottie/Celebration.json';
    }
    if (lower.contains('pink cake.json') ||
        lower.contains('pink_cake') ||
        lowerName.contains('pink cake')) {
      return 'assets/animations/lottie/pink cake.json';
    }
    if (lower.contains('oky1znbm0zkuj6fwfzgb') ||
        lower.contains('red car.json') ||
        lower.contains('red_car') ||
        lowerId == 'car_king' ||
        lowerName.contains('car king')) {
      return 'assets/animations/lottie/Red Car.json';
    }
    if (lower.contains('ioet2naw5dskdk1iyi1q') ||
        lower.contains('premium gold.json') ||
        lower.contains('premium_gold') ||
        lowerId == 'crown' ||
        lowerName.contains('gold crown') ||
        lowerName.contains('crown')) {
      return 'assets/animations/lottie/Premium Gold.json';
    }
    if (lower.contains('nc7tzgz2ndzt79nh8ohr') ||
        lower.contains('rocket loader.json') ||
        lower.contains('rocket_loader') ||
        lowerId == 'rocket' ||
        lowerName.contains('rocket')) {
      return 'assets/animations/lottie/Rocket loader.json';
    }
    if (lower.contains('nagmuqanks91xjmfsb2i') ||
        lowerId == 'lucky_bell' ||
        lowerName.contains('lucky bell')) {
      return 'assets/animations/lottie/Celebration.json';
    }
    if (lower.contains('tkp5fxoqwtt9bawozve4') ||
        lowerId == 'lucky_chest' ||
        lowerName.contains('lucky chest')) {
      return 'assets/animations/lottie/Premium Gold.json';
    }
    if (lower.contains('k9cyi5upbb4utkbwfp3u') ||
        lowerId == 'lucky_fruit' ||
        lowerName.contains('lucky fruit')) {
      return 'assets/animations/lottie/pink cake.json';
    }
    if (lower.contains('ev9navcp1u5g3ninsfv6') ||
        lowerId == 'lucky_star' ||
        lowerName.contains('lucky star')) {
      return 'assets/animations/lottie/Celebration.json';
    }
    if (lower.contains('airplane.json') ||
        lowerId == 'airplane' ||
        lowerName.contains('airplane')) {
      return 'assets/animations/lottie/airplane.json';
    }
    if (lower.contains('cat.json') ||
        lowerId == 'cat' ||
        lowerName == 'cat') {
      return 'assets/animations/lottie/cat.json';
    }
    if (lower.contains('red diamond.json') ||
        lower.contains('red_diamond') ||
        lowerId == 'red_diamond' ||
        lowerName.contains('red diamond')) {
      return 'assets/animations/lottie/Red Diamond.json';
    }
    if (lower.contains('1790955469796') ||
        lower.contains('data.json') ||
        lowerId == 'f06asjhevb74ssizmfgr') {
      return 'assets/animations/gifts/data.json';
    }

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final String name = _remoteFileName(lower);
      if (name.endsWith('rose.json')) return 'assets/animations/lottie/Rose.json';
      if (name.endsWith('balloon.json')) return 'assets/animations/lottie/balloon.json';
      if (name.endsWith('pink cake.json') || name.endsWith('pink_cake.json')) {
        return 'assets/animations/lottie/pink cake.json';
      }
      if (name.endsWith('red diamond.json') || name.endsWith('red_diamond.json')) {
        return 'assets/animations/lottie/Red Diamond.json';
      }
      if (name.endsWith('cat.json')) return 'assets/animations/lottie/cat.json';
      if (name.endsWith('premium gold.json') || name.endsWith('premium_gold.json')) {
        return 'assets/animations/lottie/Premium Gold.json';
      }
      if (name.endsWith('celebration.json')) return 'assets/animations/lottie/Celebration.json';
      if (name.endsWith('rocket loader.json') || name.endsWith('rocket_loader.json')) {
        return 'assets/animations/lottie/Rocket loader.json';
      }
      if (name.endsWith('red car.json') || name.endsWith('red_car.json')) {
        return 'assets/animations/lottie/Red Car.json';
      }
      if (name.endsWith('airplane.json')) return 'assets/animations/lottie/airplane.json';
      return null;
    }
    return null;
  }

  /// Maps remote VAP / MP4 gift URLs or IDs to local VAP asset paths if available
  static String? getLocalVapPath(String urlOrFile, {String? giftId, String? giftName}) {
    final lower = urlOrFile.toLowerCase();
    final lowerId = (giftId ?? '').toLowerCase();
    final lowerName = (giftName ?? '').toLowerCase();

    if (urlOrFile.startsWith('assets/') && (lower.endsWith('.mp4') || lower.endsWith('.vap'))) {
      return urlOrFile;
    }

    if (lower.contains('1790956334312') ||
        lower.contains('golden_dates') ||
        lower.contains('golden dates') ||
        lowerId == '1kh8e0sllu6tmyt7xysw' ||
        lowerName.contains('golden dates')) {
      return 'assets/animations/gifts/normal gift/lucky gift dates/video.mp4';
    }
    if (lower.contains('1790956201919') ||
        lower.contains('golden_bell') ||
        lower.contains('golden bell') ||
        lowerId == 'adsj76giqxisyoupuihjb' ||
        lowerName.contains('golden bell')) {
      return 'assets/animations/gifts/lucky gifts bell vap/lucky gifts bell vap/video.mp4';
    }
    if (lower.contains('1790955592582') ||
        lower.contains('grand_piano') ||
        lower.contains('grand piano') ||
        lower.contains('169522') ||
        lowerId == 'klpyorcpmkbibdplre5g' ||
        lowerName.contains('grand piano')) {
      return 'assets/animations/gifts/169522/video.mp4';
    }
    if (lower.contains('1790955912123') ||
        lower.contains('gourmet_feast') ||
        lower.contains('gourmet feast') ||
        lower.contains('2529') ||
        lowerId == 'apojwtxo9pfkbjz0asiv' ||
        lowerName.contains('gourmet feast')) {
      return 'assets/animations/gifts/2529/video.mp4';
    }
    if (lower.contains('1790955821224') ||
        lower.contains('sweet_romance') ||
        lower.contains('sweet romance') ||
        lower.contains('251779') ||
        lowerId == '4kov1uz5bqfxjkvikscs' ||
        lowerName.contains('sweet romance')) {
      return 'assets/animations/gifts/251779/video.mp4';
    }
    if (lower.contains('1790956012255') ||
        lower.contains('ruby_excalibur') ||
        lower.contains('flame_excalibur') ||
        lower.contains('excalibur') ||
        lower.contains('256006') ||
        lowerId == 'x8mo9guuiz5xrstpjykl' ||
        lowerName.contains('excalibur')) {
      return 'assets/animations/gifts/256006/video.mp4';
    }
    if (lower.contains('1790955699875') ||
        lower.contains('crystal_princess') ||
        lower.contains('crystal princess') ||
        lower.contains('219667') ||
        lowerId == 'bdmkvlhqdmrvvoxonxln' ||
        lowerName.contains('crystal princess')) {
      return 'assets/animations/gifts/219667/video.mp4';
    }
    if (lower.contains('1790956102727') ||
        lower.contains('crystal_windchime') ||
        lower.contains('crystal windchime') ||
        lower.contains('tencent-vap-music') ||
        lowerId == 'pzjkxr8gmffdyfj4qsae' ||
        lowerName.contains('crystal windchime')) {
      return 'assets/animations/gifts/tencent-VAP-music/video.mp4';
    }

    return null;
  }

  /// Returns in-memory pre-decoded MovieEntity if available, allowing instant frame-0 rendering.
  static MovieEntity? getCachedMovie(String assetPath) {
    return _movieCache[assetPath.trim()];
  }

  /// Returns in-memory prepared audio tracks if available.
  static List<PreparedSvgaAudio>? getCachedPreparedAudios(String sourceKey) {
    final cached = _preparedAudioCache[sourceKey];
    if (cached != null && cached.isNotEmpty && cached.every((a) => a.file.existsSync())) {
      return cached;
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
    if (!_protectedAssetKeys.contains(cleanPath)) {
      _movieCacheKeys.remove(cleanPath);
      _movieCacheKeys.add(cleanPath);
      if (_movieCacheKeys.length > _maxMovieCacheSize) {
        final oldest = _movieCacheKeys.removeAt(0);
        _movieCache.remove(oldest);
        // CRITICAL: Do NOT call evicted?.dispose() here! Calling dispose() on a MovieEntity deletes its
        // underlying native textures immediately. If an active painter or SvgaPlayer is rendering it,
        // it causes a native SIGSEGV use-after-free crash. Removing from _movieCache allows Dart GC to
        // safely reclaim it once all active players release references.
      }
    }

    return movie;
  }

  static Future<MovieEntity> decodeSafeFromUrl(String url) async {
    final cleanUrl = url.trim();
    
    // Auto-intercept remote gift URLs mapping to local assets
    final localPath = getLocalGiftSvgaPath(cleanUrl);
    if (localPath != null) {
      debugPrint("🚀 SvgaParserUtil: Intercepted remote SVGA URL ($cleanUrl), loading local asset instead: $localPath");
      return decodeSafeFromAssets(localPath);
    }

    if (_movieCache.containsKey(cleanUrl)) {
      return _movieCache[cleanUrl]!;
    }

    final bytes = await _loadUrlBytes(cleanUrl);
    final movie = await SVGAParser.shared.decodeFromBuffer(bytes);
    movie.autorelease = false;

    _movieCache[cleanUrl] = movie;
    if (!_protectedAssetKeys.contains(cleanUrl)) {
      _movieCacheKeys.remove(cleanUrl);
      _movieCacheKeys.add(cleanUrl);
      if (_movieCacheKeys.length > _maxMovieCacheSize) {
        final oldest = _movieCacheKeys.removeAt(0);
        _movieCache.remove(oldest);
        // CRITICAL: Do NOT call evicted?.dispose() for safe GC reclamation.
      }
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
        debugPrint("🚀 SvgaParserUtil: Preloading and parsing local VIP assets into memory cache...");
        
        final assetsToPreload = [
          // Primary Role & System Frames
          'assets/Helo chat/Superadmin.svga',
          'assets/Helo chat/Agency.svga',
          'assets/Helo chat/Official.svga',
          'assets/Helo chat/1.svga',
          'assets/Helo chat/2.svga',
          'assets/Helo chat/3.svga',
          'assets/Helo chat/Rockeet_SVGA.svga',
          'assets/Helo chat/Top 1.svga',
          'assets/Helo chat/Top 2.svga',
          'assets/Helo chat/Top 3.svga',
          'assets/images/super/admin.svga',
          'assets/images/super/reseller.svga',

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

        // Protect preloaded core system & VIP assets from ever being evicted during cache churn
        _protectedAssetKeys.addAll(assetsToPreload.map((e) => e.trim()));

        // Parallelize: load in small batches of 3 with 200ms delay to avoid main thread I/O lockup
        const batchSize = 3;
        for (int i = 0; i < assetsToPreload.length; i += batchSize) {
          final batch = assetsToPreload.skip(i).take(batchSize).toList();
          await Future.wait(
            batch.map((assetPath) async {
              try {
                await decodeSafeFromAssets(assetPath);
              } catch (pe) {
                // Silently ignore missing optional local SVGA assets
              }
            }),
            eagerError: true,
          );
          await Future.delayed(const Duration(milliseconds: 200));
        }

        debugPrint("✅ SvgaParserUtil: All local VIP assets preloaded and decoded successfully!");
      } catch (e) {
        debugPrint("⚠️ SvgaParserUtil: Failed to preload local VIP assets: $e");
      }
    });
  }
}
