import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class AssetPrecacheService {
  /// Dynamically builds all VIP 1 to VIP 8 image assets
  static List<String> get allVipImageAssets {
    final List<String> paths = [];
    
    // VIP 1
    paths.addAll([
      'assets/VIP/VIP 1/Crown 1.png',
      'assets/VIP/VIP 1/Frame.png',
      'assets/VIP/VIP 1/Badge.webp',
      'assets/VIP/VIP 1/Tag.png',
      'assets/VIP/VIP 1/Strip.png',
      'assets/VIP/VIP 1/Entry.png',
    ]);

    // VIP 2 to VIP 7
    for (int i = 2; i <= 7; i++) {
      paths.addAll([
        'assets/VIP/VIP $i/VIP $i/Crown 1.png',
        'assets/VIP/VIP $i/VIP $i/Frame.png',
        'assets/VIP/VIP $i/VIP $i/Badge.webp',
        'assets/VIP/VIP $i/VIP $i/Tag.png',
        'assets/VIP/VIP $i/VIP $i/Strip.png',
        'assets/VIP/VIP $i/VIP $i/Entry.png',
      ]);
    }

    // VIP 8
    paths.addAll([
      'assets/VIP/VIP 8/VIP 8/VIP 8 Crown 1.png',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Frame.png',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Badge.webp',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Tag.png',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Strip.png',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Entry.png',
    ]);

    return paths;
  }

  /// Dynamically builds all VIP & Special Role SVGA animations
  static List<String> get allSvgaAssets {
    final List<String> paths = [
      'assets/Helo chat/Rockeet_SVGA.svga',
      'assets/Helo chat/Superadmin.svga',
      'assets/images/super/admin.svga',
      'assets/images/super/reseller.svga',
      'assets/Helo chat/Agency.svga',
      'assets/Helo chat/Official.svga',
      'assets/Helo chat/1.svga',
      'assets/Helo chat/2.svga',
      'assets/Helo chat/3.svga',
      'assets/Helo chat/Top 1.svga',
      'assets/Helo chat/Top 2.svga',
      'assets/Helo chat/Top 3.svga',
      'assets/VIP/VIP 1/Crown 1.svga',
      'assets/VIP/VIP 1/Frame.svga',
      'assets/VIP/VIP 1/Badge.svga',
      'assets/VIP/VIP 1/Entry.svga',
    ];

    for (int i = 2; i <= 7; i++) {
      paths.addAll([
        'assets/VIP/VIP $i/VIP $i/Crown 1.svga',
        'assets/VIP/VIP $i/VIP $i/Frame.svga',
        'assets/VIP/VIP $i/VIP $i/Badge.svga',
        'assets/VIP/VIP $i/VIP $i/Entry.svga',
      ]);
    }

    paths.addAll([
      'assets/VIP/VIP 8/VIP 8/VIP 8 Crown 1.svga',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Crown 1.svga',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Frame.svga',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Badge.svga',
      'assets/VIP/VIP 8/VIP 8/VIP 8 Entry.svga',
    ]);

    return paths;
  }

  static final Set<String> _cachedPaths = {};
  static bool _isBackgroundRunning = false;

  /// Precaches ONLY the logged-in user's active VIP badge, crown, entry, and role tag instantly (<10ms).
  static Future<void> precacheUserAssets(BuildContext context, {int? vipLevel, String? role}) async {
    PaintingBinding.instance.imageCache.maximumSize = 500;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;

    final parser = SVGAParser.shared;

    // 1. User role SVGA if applicable
    if (role != null) {
      final roleLower = role.toLowerCase().trim();
      if (roleLower.contains('super')) {
        await precacheOnDemand('assets/images/super/admin.svga');
      } else if (roleLower.contains('reseller')) {
        await precacheOnDemand('assets/images/super/reseller.svga');
      } else if (roleLower.contains('agency')) {
        await precacheOnDemand('assets/Helo chat/Agency.svga');
      } else if (roleLower.contains('official')) {
        await precacheOnDemand('assets/Helo chat/Official.svga');
      }
    }

    // 2. User VIP assets if applicable
    if (vipLevel != null && vipLevel >= 1 && vipLevel <= 8) {
      final prefix = (vipLevel == 1)
          ? 'assets/VIP/VIP 1'
          : 'assets/VIP/VIP $vipLevel/VIP $vipLevel';
      
      final svgaBadge = '$prefix/Badge.svga';
      final svgaCrown = (vipLevel == 8) ? '$prefix/VIP 8 Crown 1.svga' : '$prefix/Crown 1.svga';
      final svgaEntry = '$prefix/Entry.svga';

      await precacheOnDemand(svgaBadge);
      await precacheOnDemand(svgaCrown);
      await precacheOnDemand(svgaEntry);
    }
  }

  /// Instantly precaches a single SVGA asset on demand when needed by a widget
  static Future<void> precacheOnDemand(String svgaPath) async {
    if (_cachedPaths.contains(svgaPath)) return;
    _cachedPaths.add(svgaPath);
    try {
      await SVGAParser.shared.decodeFromAssets(svgaPath);
    } catch (_) {}
  }

  /// Warm up remaining SVGA assets slowly in the background with a 150ms micro-sleep between items
  static void startBackgroundPrecache() async {
    if (_isBackgroundRunning) return;
    _isBackgroundRunning = true;

    final parser = SVGAParser.shared;
    for (final svgaPath in allSvgaAssets) {
      if (!_cachedPaths.contains(svgaPath)) {
        _cachedPaths.add(svgaPath);
        try {
          await parser.decodeFromAssets(svgaPath);
        } catch (_) {}
        // Micro-sleep to yield UI thread control and prevent ANR
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
    _isBackgroundRunning = false;
  }

  /// Deprecated legacy entry point: redirect to non-blocking background queue
  static Future<void> precacheAll(BuildContext context) async {
    startBackgroundPrecache();
  }
}
