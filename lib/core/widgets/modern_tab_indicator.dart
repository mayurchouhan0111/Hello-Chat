import 'package:flutter/material.dart';

class ModernTabIndicator extends Decoration {
  final Color color;
  final double width;
  final double height;
  final double radius;

  const ModernTabIndicator({
    required this.color,
    this.width = 16,
    this.height = 4,
    this.radius = 10,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _ModernTabPainter(this, onChanged);
  }
}

class _ModernTabPainter extends BoxPainter {
  final ModernTabIndicator decoration;

  _ModernTabPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final centerX = configuration.size!.width / 2 + offset.dx;
    final bottomY = configuration.size!.height + offset.dy - 6;

    final paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: Offset(centerX, bottomY),
      width: decoration.width,
      height: decoration.height,
    );

    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(decoration.radius)), paint);
  }
}
