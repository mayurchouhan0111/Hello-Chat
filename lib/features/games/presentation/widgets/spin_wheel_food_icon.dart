import 'package:flutter/material.dart';

/// Food artwork extracted from the client-provided Greedy BIGO reference.
///
/// Keeping the ten icons in one sprite guarantees that the same source pixels,
/// proportions, and color treatment are used everywhere in the game.
class SpinWheelFoodIcon extends StatelessWidget {
  const SpinWheelFoodIcon({
    super.key,
    required this.food,
    required this.size,
    this.semanticLabel,
  });

  static const spriteAsset = 'assets/games/icons/greedy_bigo_food_sprite.png';
  static const _columns = 5;
  static const _rows = 2;

  final String food;
  final double size;
  final String? semanticLabel;

  static int spriteIndexFor(String name) {
    final norm = name.trim().toLowerCase();
    if (norm.contains('tomato') || norm == '🍅') return 1;
    if (norm.contains('kebab') || norm.contains('skewer') || norm == '🍢') {
      return 2;
    }
    if (norm.contains('chicken') ||
        norm.contains('drumstick') ||
        norm.contains('ham') ||
        norm == '🍗') {
      return 3;
    }
    if (norm.contains('steak') || norm.contains('meat') || norm == '🥩') {
      return 4;
    }
    if (norm.contains('carrot') || norm == '🥕') return 5;
    if (norm.contains('corn') || norm == '🌽') return 6;
    if (norm.contains('cabbage') ||
        norm.contains('leaf') ||
        norm.contains('veg') ||
        norm == '🥬') {
      return 7;
    }
    if (norm.contains('salad') || norm == '🥗') return 8;
    if (norm.contains('pizza') || norm == '🍕') return 9;
    return 0;
  }

  /// Canonical human-readable display name guaranteed to match the sprite icon.
  static String cleanDisplayName(String foodName) {
    final norm = foodName.trim().toLowerCase();
    if (norm.contains('hot dog') || norm.contains('hotdog') || norm == '🌭') {
      return 'Hot Dog';
    }
    if (norm.contains('tomato') || norm == '🍅') return 'Tomato';
    if (norm.contains('kebab') || norm.contains('skewer') || norm == '🍢') {
      return 'Skewer';
    }
    if (norm.contains('chicken') ||
        norm.contains('drumstick') ||
        norm.contains('ham') ||
        norm == '🍗') {
      return 'Ham';
    }
    if (norm.contains('steak') || norm.contains('meat') || norm == '🥩') {
      return 'Steak';
    }
    if (norm.contains('carrot') || norm == '🥕') return 'Carrot';
    if (norm.contains('corn') || norm == '🌽') return 'Corn';
    if (norm.contains('cabbage') ||
        norm.contains('leaf') ||
        norm.contains('veg') ||
        norm == '🥬') {
      return 'Cabbage';
    }
    if (norm.contains('salad') || norm == '🥗') return 'Salad';
    if (norm.contains('pizza') || norm == '🍕') return 'Pizza';
    return foodName.isNotEmpty ? foodName : 'Winner';
  }

  /// Retained for callers/tests that only need the source asset.
  static String assetFor(String _) => spriteAsset;

  @override
  Widget build(BuildContext context) {
    final index = spriteIndexFor(food);
    final column = index % _columns;
    final row = index ~/ _columns;
    final alignmentX = -1 + (2 * column / (_columns - 1));
    final alignmentY = row == 0 ? -1.0 : 1.0;

    return Semantics(
      image: true,
      label: semanticLabel ?? food,
      child: SizedBox.square(
        dimension: size,
        child: RepaintBoundary(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment(alignmentX, alignmentY),
              minWidth: size * _columns,
              maxWidth: size * _columns,
              minHeight: size * _rows,
              maxHeight: size * _rows,
              child: Image.asset(
                spriteAsset,
                width: size * _columns,
                height: size * _rows,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
