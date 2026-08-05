import 'package:flutter/foundation.dart';

/// Helper utility to resolve bundled `.svga` paths to their corresponding
/// static `.png` / `.webp` asset paths for fast rendering without running SVGA loops.
class SvgaStaticUtil {
  SvgaStaticUtil._();

  static const Map<String, String> _exactSvgaToStaticMap = {
    // Helo chat / Special Assets
    'assets/Helo chat/Rockeet_SVGA.svga': 'assets/Helo chat/Rockeet.png',
    'assets/Helo chat/Superadmin.svga': 'assets/Helo chat/Superadmin.png',
    'assets/images/super/admin.svga': 'assets/images/super/admin.png',
    'assets/images/super/reseller.svga': 'assets/images/super/reseller.png',
    'assets/Helo chat/Agency.svga': 'assets/Helo chat/Agency.png',
    'assets/Helo chat/Official.svga': 'assets/Helo chat/Official.png',
    'assets/Helo chat/1.svga': 'assets/Helo chat/1.png',
    'assets/Helo chat/2.svga': 'assets/Helo chat/2.png',
    'assets/Helo chat/3.svga': 'assets/Helo chat/3.png',
    'assets/Helo chat/Top 1.svga': 'assets/Helo chat/TOP 1.png',
    'assets/Helo chat/Top 2.svga': 'assets/Helo chat/TOP 2.png',
    'assets/Helo chat/Top 3.svga': 'assets/Helo chat/TOP 3.png',
    'assets/Helo chat/Sound Waives.svga': 'assets/Helo chat/Sound Waives.png',

    // SVIP Kit SVGA assets
    'assets/SVIP Kit/svip 1/Crown.svga': 'assets/SVIP Kit/svip 1/SVIP 1 Crown.png',
    'assets/SVIP Kit/svip 1/Frame.svga': 'assets/SVIP Kit/svip 1/Frame.png',
    'assets/SVIP Kit/svip 1/Entry.svga': 'assets/SVIP Kit/svip 1/Entry.png',
    
    'assets/SVIP Kit/svip 2/Crown.svga': 'assets/SVIP Kit/svip 2/SVIP 2 Crown.png',
    'assets/SVIP Kit/svip 2/Frame.svga': 'assets/SVIP Kit/svip 2/Frame.png',
    'assets/SVIP Kit/svip 2/Entry.svga': 'assets/SVIP Kit/svip 2/Entry.png',
    
    'assets/SVIP Kit/svip 3/Crown.svga': 'assets/SVIP Kit/svip 3/SVIP 3 Crown.png',
    'assets/SVIP Kit/svip 3/Frame.svga': 'assets/SVIP Kit/svip 3/Frame.png',
    'assets/SVIP Kit/svip 3/Entry.svga': 'assets/SVIP Kit/svip 3/Entry.png',
    
    'assets/SVIP Kit/svip 4/Crown.svga': 'assets/SVIP Kit/svip 4/SVIP 4 Crown.png',
    'assets/SVIP Kit/svip 4/Frame.svga': 'assets/SVIP Kit/svip 4/Frame.png',
    'assets/SVIP Kit/svip 4/Entry.svga': 'assets/SVIP Kit/svip 4/entrance_svip4_SVGA (2).png',
    'assets/SVIP Kit/svip 4/entrance_svip4_SVGA_SVGA.svga': 'assets/SVIP Kit/svip 4/entrance_svip4_SVGA (2).png',

    'assets/SVIP Kit/svip 5/Crown.svga': 'assets/SVIP Kit/svip 5/SVIP 5 Crown.png',
    'assets/SVIP Kit/svip 5/Frame.svga': 'assets/SVIP Kit/svip 5/Frame.png',
    'assets/SVIP Kit/svip 5/Entry.svga': 'assets/SVIP Kit/svip 5/Entry.png',

    'assets/SVIP Kit/SVIP 6/Crown.svga': 'assets/SVIP Kit/SVIP 6/SVIP 6 Crown.png',
    'assets/SVIP Kit/SVIP 6/Frame.svga': 'assets/SVIP Kit/SVIP 6/Frame.png',
    'assets/SVIP Kit/SVIP 6/Entry.svga': 'assets/SVIP Kit/SVIP 6/Entry.png',
  };

  /// Given an SVGA asset path or network URL, return its static PNG or WebP fallback path.
  static String staticPathForSvga(String? svgaPath, {String? category}) {
    if (svgaPath == null || svgaPath.isEmpty) return svgaPath ?? '';

    // 1. Direct exact lookup
    if (_exactSvgaToStaticMap.containsKey(svgaPath)) {
      return _exactSvgaToStaticMap[svgaPath]!;
    }

    final lower = svgaPath.toLowerCase();

    // 2. VIP Asset special handling
    if (svgaPath.startsWith('assets/VIP/')) {
      final level = _getVipLevelFromPath(svgaPath);
      if (level > 0) {
        final cat = category?.toLowerCase();
        if (cat == 'frame') {
          if (level == 1) return 'assets/VIP/VIP 1/Frame.png';
          if (level == 2) return 'assets/VIP/VIP 2/VIP 2/Frame 2.png';
          if (level == 3) return 'assets/VIP/VIP 3/VIP 3/Frame 3.png';
          if (level == 4) return 'assets/VIP/VIP 4/VIP 4/Frame 4.png';
          if (level == 5) return 'assets/VIP/VIP 5/VIP 5/User Frame 5.png';
          if (level == 6) return 'assets/VIP/VIP 6/VIP 6/User Frame 6.png';
          if (level == 7) return 'assets/VIP/VIP 7/VIP 7/Frame 7.png';
          if (level == 8) return 'assets/VIP/VIP 8/VIP 8/User Frame 8.png';
        } else if (cat == 'mount') {
          if (level == 1) return 'assets/VIP/VIP 1/Entry.png';
          if (level == 2) return 'assets/VIP/VIP 2/VIP 2/Entry.png';
          if (level == 3) return 'assets/VIP/VIP 3/VIP 3/Entry.png';
          if (level == 4) return 'assets/VIP/VIP 4/VIP 4/Entry.png';
          if (level == 5) return 'assets/VIP/VIP 5/VIP 5/Entry.png';
          if (level == 6) return 'assets/VIP/VIP 6/VIP 6/VIP 6 Entry.png';
          if (level == 7) return 'assets/VIP/VIP 7/VIP 7/Entry.png';
          if (level == 8) return 'assets/VIP/VIP 8/VIP 8/VIP 8 Entry Effect.png';
        } else if (cat == 'bubble') {
          if (level == 1) return 'assets/VIP/VIP 1/Chat Bubble.png';
          return 'assets/VIP/VIP $level/VIP $level/Chat Bubble.png';
        } else if (cat == 'crown') {
          if (level == 1) return 'assets/VIP/VIP 1/Crown 2.webp';
          if (level == 5) return 'assets/VIP/VIP 5/VIP 5/5.webp';
          return 'assets/VIP/VIP $level/VIP $level/Crown 2.webp';
        }
      }
    }

    // 3. Fallback: replace .svga extension with .png or .webp
    if (lower.endsWith('.svga')) {
      final fallbackExt = (category?.toLowerCase() == 'crown' || lower.contains('crown') || lower.contains('badge'))
          ? '.webp'
          : '.png';
      return svgaPath.replaceAll(RegExp(r'\.svga$', caseSensitive: false), fallbackExt);
    }

    return svgaPath;
  }

  static int _getVipLevelFromPath(String path) {
    final parts = path.split('/');
    for (final part in parts) {
      final pLower = part.toLowerCase();
      if (pLower.startsWith('vip ')) {
        final numStr = pLower.substring(4);
        final val = int.tryParse(numStr);
        if (val != null) return val;
      } else if (pLower.startsWith('vip') && pLower.length > 3) {
        final numStr = pLower.substring(3);
        final val = int.tryParse(numStr);
        if (val != null) return val;
      }
    }
    return 0;
  }
}
