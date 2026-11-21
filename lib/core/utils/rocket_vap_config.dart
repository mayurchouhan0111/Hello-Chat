import '../widgets/vap_player.dart';

class RocketVapConfig {
  RocketVapConfig._();

  static const List<String> levelToLetter = ['a', 'b', 'c', 'd', 'e'];

  /// Returns the letter group for a given rocket code level (0-4).
  static String letterForLevel(int level) {
    final clamped = level.clamp(0, 4);
    return levelToLetter[clamped];
  }

  /// VAP animation asset path for a given code level.
  /// [variant]: 1=full(59-70f), 2=short(15f), 3=extended(70-71f)
  static String vapAssetPath(int level, {int variant = 1}) {
    final letter = letterForLevel(level);
    return 'assets/animations/VAP/$letter ($variant).mp4';
  }

  /// SVGA icon asset path for a given code level (replacement for old .1.svga).
  static String svgaIconPath(int level) {
    final letter = letterForLevel(level);
    return 'assets/animations/VAP/$letter (1).svga';
  }

  /// Optimize memory and decoder performance by pre-caching only active and next level assets.
  static final Set<String> _cachedPaths = {};

  static Future<void> preloadActiveAndNext(int currentLevel) async {
    final activeLevel = currentLevel.clamp(0, 4);
    final nextLevel = (activeLevel + 1).clamp(0, 4);

    final pathsToKeep = <String>{
      vapAssetPath(activeLevel, variant: 1),
      vapAssetPath(activeLevel, variant: 2),
      vapAssetPath(activeLevel, variant: 3),
      if (nextLevel != activeLevel) ...[
        vapAssetPath(nextLevel, variant: 1),
        vapAssetPath(nextLevel, variant: 2),
      ],
    };

    _cachedPaths.removeWhere((p) => !pathsToKeep.contains(p));

    for (final path in pathsToKeep) {
      if (!_cachedPaths.contains(path)) {
        try {
          await VapAnimation.preCache(path);
          _cachedPaths.add(path);
        } catch (_) {}
      }
    }
  }
}
