import 'package:flutter/material.dart';

class PremiumBean extends StatelessWidget {
  final double size;
  const PremiumBean({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      "https://img.icons8.com/emoji/96/beans-emoji.png",
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Text(
        "🫘",
        style: TextStyle(fontSize: size * 0.8),
      ),
    );
  }
}
