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

}
