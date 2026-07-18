import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class FamilyProgressBar extends StatelessWidget {
  final double ratio;
  final double height;
  final Color? fillColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const FamilyProgressBar({
    super.key,
    required this.ratio,
    this.height = 10,
    this.fillColor,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.familyCard,
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
        border: Border.all(
          color: AppColors.familyGold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
        child: FractionallySizedBox(
          widthFactor: clampedRatio,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  fillColor ?? AppColors.familyGold,
                  (fillColor ?? AppColors.familyGold).withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FamilyRankProgressBar extends StatelessWidget {
  final int currentPoints;
  final int requiredPoints;
  final double height;
  final Color? fillColor;

  const FamilyRankProgressBar({
    super.key,
    required this.currentPoints,
    required this.requiredPoints,
    this.height = 12,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = requiredPoints > 0 ? (currentPoints / requiredPoints).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FamilyProgressBar(ratio: ratio, height: height, fillColor: fillColor),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatNumber(currentPoints),
              style: TextStyle(
                color: fillColor ?? AppColors.familyGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _formatNumber(requiredPoints),
              style: const TextStyle(
                color: AppColors.familyTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}
