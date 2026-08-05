import 'package:flutter/material.dart';

/// UniformTagBadge enforces a consistent, compact, and elegant design for all profile/ID tags
/// across the platform (User Profile, ID Cards, Live Rooms, Global Chat, Leaderboards).
class UniformTagBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;

  const UniformTagBadge({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor = const Color(0xFF6C5CE7),
    this.textColor = Colors.white,
    this.gradientColors,
    this.onTap,
  });

  /// Standardized dimensions for all tags
  static const double tagHeight = 20.0;
  static const double borderRadius = 10.0;
  static const EdgeInsets tagPadding = EdgeInsets.symmetric(horizontal: 7.0, vertical: 1.0);
  static const double defaultSpacing = 4.0;

  /// Utility constructor for dynamic hex color strings (e.g. "#FF5733" or "0xFFFF5733")
  factory UniformTagBadge.fromHex({
    Key? key,
    required String label,
    IconData? icon,
    required String hexColor,
    Color textColor = Colors.white,
    VoidCallback? onTap,
  }) {
    Color color;
    try {
      String cleanHex = hexColor.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      color = Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      color = const Color(0xFF6C5CE7);
    }

    return UniformTagBadge(
      key: key,
      label: label,
      icon: icon,
      backgroundColor: color,
      textColor: textColor,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Container(
      height: tagHeight,
      padding: tagPadding,
      decoration: BoxDecoration(
        color: gradientColors == null ? backgroundColor : null,
        gradient: gradientColors != null && gradientColors!.length >= 2
            ? LinearGradient(
                colors: gradientColors!,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2.0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11.0,
              color: textColor,
            ),
            const SizedBox(width: 3.0),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      );
    }

    return child;
  }
}

/// Utility Widget to render a horizontal row of tags with guaranteed equal spacing and alignment.
class UniformTagGroup extends StatelessWidget {
  final List<Widget> tags;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;

  const UniformTagGroup({
    super.key,
    required this.tags,
    this.spacing = UniformTagBadge.defaultSpacing,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final List<Widget> children = [];
    for (int i = 0; i < tags.length; i++) {
      children.add(tags[i]);
      if (i < tags.length - 1) {
        children.add(SizedBox(width: spacing));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      crossAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}
