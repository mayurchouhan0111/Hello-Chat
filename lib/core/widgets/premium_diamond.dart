import 'package:flutter/material.dart';

class PremiumDiamond extends StatelessWidget {
  final double size;
  final List<Color>? colors;

  const PremiumDiamond({
    super.key,
    this.size = 24,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DiamondGemPainter(facetColors: colors),
      ),
    );
  }
}

class DiamondGemPainter extends CustomPainter {
  final List<Color>? facetColors;

  DiamondGemPainter({this.facetColors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Use custom colors if provided, otherwise the standard Golden palette
    final topColor = facetColors != null && facetColors!.isNotEmpty ? facetColors![0] : const Color(0xFFFFEB3B);
    final centerColor = facetColors != null && facetColors!.length > 1 ? facetColors![1] : const Color(0xFFFFD700);
    final sideColor = facetColors != null && facetColors!.length > 2 ? facetColors![2] : const Color(0xFFFBC02D);
    final bottomColor = facetColors != null && facetColors!.length > 2 ? facetColors![2] : const Color(0xFFF9A825);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // 1. Bottom Triangle (Main Body)
    final Path bottomPath = Path();
    bottomPath.moveTo(w * 0.5, h);             // Bottom point
    bottomPath.lineTo(0, h * 0.4);              // Middle left point
    bottomPath.lineTo(w, h * 0.4);              // Middle right point
    bottomPath.close();
    paint.color = bottomColor;
    canvas.drawPath(bottomPath, paint);

    // 2. Middle Left Triangle
    final Path midLeftPath = Path();
    midLeftPath.moveTo(w * 0.5, h);
    midLeftPath.lineTo(0, h * 0.4);
    midLeftPath.lineTo(w * 0.5, h * 0.4);
    midLeftPath.close();
    paint.color = sideColor;
    canvas.drawPath(midLeftPath, paint);

    // 3. Top Trapezoid (Lower part)
    final Path topPath = Path();
    topPath.moveTo(0, h * 0.4);
    topPath.lineTo(w * 0.2, 0);
    topPath.lineTo(w * 0.8, 0);
    topPath.lineTo(w, h * 0.4);
    topPath.close();
    paint.color = topColor;
    canvas.drawPath(topPath, paint);

    // 4. Inner Facets (Defining the classic look)
    final Path innerFacets = Path();
    // Center rectangle/trapezoid
    innerFacets.moveTo(w * 0.2, 0);
    innerFacets.lineTo(w * 0.8, 0);
    innerFacets.lineTo(w * 0.5, h * 0.4);
    innerFacets.close();
    paint.color = centerColor;
    canvas.drawPath(innerFacets, paint);

    // 5. Left Top Facet highlight
    final Path leftTopFacet = Path();
    leftTopFacet.moveTo(0, h * 0.4);
    leftTopFacet.lineTo(w * 0.2, 0);
    leftTopFacet.lineTo(w * 0.5, h * 0.4);
    leftTopFacet.close();
    paint.color = sideColor;
    canvas.drawPath(leftTopFacet, paint);

    // Shine / Border detail
    final Path border = Path();
    border.moveTo(w * 0.2, 0);
    border.lineTo(w * 0.8, 0);
    border.lineTo(w, h * 0.4);
    border.lineTo(w * 0.5, h);
    border.lineTo(0, h * 0.4);
    border.close();
    
    final Paint linePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawPath(border, linePaint);
    
    // Draw facet lines
    canvas.drawLine(Offset(w * 0.5, h * 0.4), Offset(w * 0.5, h), linePaint);
    canvas.drawLine(Offset(w * 0.2, 0), Offset(w * 0.5, h * 0.4), linePaint);
    canvas.drawLine(Offset(w * 0.8, 0), Offset(w * 0.5, h * 0.4), linePaint);
    canvas.drawLine(Offset(0, h * 0.4), Offset(w, h * 0.4), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Re-paint on color change
}
