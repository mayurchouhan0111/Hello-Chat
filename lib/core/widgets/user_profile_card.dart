import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'svga_player.dart';

class UserProfileCard extends StatelessWidget {
  final UserModel user;
  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;
  final Color backgroundColor;

  const UserProfileCard({
    super.key,
    required this.user,
    required this.child,
    this.borderRadius,
    this.padding,
    this.boxShadow,
    this.backgroundColor = Colors.white,
  });

  int _getVipLevel(String vipTierName) {
    final clean = vipTierName.toLowerCase().replaceAll(' ', '');
    if (clean.startsWith('vip')) {
      final numStr = clean.substring(3);
      final val = int.tryParse(numStr);
      if (val != null) return val;
    }
    return 0;
  }

  String? _getVipCrownPath(int level) {
    if (level == 1 || level == 2) return 'assets/VIP/VIP 1/Crown 1.svga';
    if (level >= 3 && level <= 7) return 'assets/VIP/VIP $level/VIP $level/Crown 1.svga';
    if (level == 8) return 'assets/VIP/VIP 8/VIP 8/VIP 8 Crown 1.svga';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final vipLevel = _getVipLevel(user.vipTier);
    final crownPath = _getVipCrownPath(vipLevel);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        boxShadow: boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          if (crownPath != null)
            Positioned.fill(
              child: IgnorePointer(
                child: SvgaPlayer(
                  key: ValueKey(crownPath),
                  assetPath: crownPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
