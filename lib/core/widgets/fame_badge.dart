import 'package:flutter/material.dart';
import '../models/fame_model.dart';

class FameBadge extends StatelessWidget {
  final int points;
  final bool compact;

  const FameBadge({super.key, required this.points, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final tier = FameCatalog.tierFor(points);
    final color = Color(tier.colorValue);
    final foreground =
        color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    final label =
        compact ? 'Fame ${tier.level}' : 'Fame ${tier.level} · ${tier.title}';

    return Semantics(
      label: 'Fame level ${tier.level}, ${tier.title}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10, vertical: compact ? 2 : 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.35), width: 0.8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded,
                  size: compact ? 11 : 14, color: foreground),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
