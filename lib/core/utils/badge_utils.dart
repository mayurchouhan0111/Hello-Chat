import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/svip_level_model.dart';
import '../widgets/user_badge.dart';
import '../../utils/level_utils.dart';

List<Widget> getBadgesForUser(UserModel user) {
  final List<Widget> badges = [];

  // 1. Wealth (Diamond Tycoon)
  if (user.diamondBalance > 10000) {
    badges.add(const UserBadge(label: "Diamond King", type: BadgeType.wealth, icon: Icons.diamond_rounded));
  }

  // 2. Popularity (Rising Star)
  if (user.followerCount > 1000) {
    badges.add(const UserBadge(label: "Rising Star", type: BadgeType.popularity, icon: Icons.auto_awesome));
  }

  // 3. Level Badge
  int level = user.level;
  int frameIndex = LevelUtils.getLevelBadgeIndex(level);

  badges.add(UserBadge(
    label: "Lv.$level", 
    type: BadgeType.level, 
    customFrameAsset: "assets/images/levels_new/level_badge_$frameIndex.webp",
    icon: Icons.shield_rounded,
  ));

  // 3.5 Room Admin Badge (Cyan)
  if (user.isAdmin) {
    badges.add(const UserBadge(label: "Admin", type: BadgeType.admin, icon: Icons.admin_panel_settings_rounded));
  }

  if (user.vipTier != 'none') {
    String? customBadge;
    final level = _getVipLevel(user.vipTier);
    if (level >= 1 && level <= 8) {
      if (level == 1) {
        customBadge = 'assets/VIP/VIP 1/Badge.webp';
      } else if (level == 2 || level == 5 || level == 7) {
        customBadge = 'assets/VIP/VIP $level/VIP $level/Badge.png';
      } else {
        customBadge = 'assets/VIP/VIP $level/VIP $level/Badge.webp';
      }
    } else if (user.badgeIcon.isNotEmpty) {
      final lowerBadge = user.badgeIcon.toLowerCase();
      if (lowerBadge.startsWith('http') && lowerBadge.contains('vip/')) {
        for (int i = 1; i <= 8; i++) {
          if (lowerBadge.contains('vip%20$i/') || lowerBadge.contains('vip $i/')) {
            customBadge = (i == 1)
                ? 'assets/VIP/VIP 1/Badge.webp'
                : ((i == 2 || i == 5 || i == 7)
                    ? 'assets/VIP/VIP $i/VIP $i/Badge.png'
                    : 'assets/VIP/VIP $i/VIP $i/Badge.webp');
            break;
          }
        }
      }
      if (customBadge == null && user.badgeIcon.startsWith('assets/')) {
        customBadge = user.badgeIcon;
      }
    }
    badges.add(UserBadge(
      label: user.vipTier.toUpperCase(),
      type: BadgeType.vip,
      icon: customBadge == null ? Icons.workspace_premium : null,
      customFrameAsset: customBadge,
    ));
  }

  // 4.5 Room / System Admin Badge
  if (user.role == 'admin' || user.tags.contains('admin')) {
    badges.add(const UserBadge(label: "Admin", type: BadgeType.role, icon: Icons.admin_panel_settings_rounded));
  }

  // 5. Certified Reseller
  if (user.isReseller) {
    badges.add(const UserBadge(label: "Reseller", type: BadgeType.role, icon: Icons.verified));
  }

  // 6. Family Head
  if (user.isFamilyOwner) {
    badges.add(const UserBadge(label: "Family Head", type: BadgeType.family, icon: Icons.home_rounded));
  }

  // 7. Agency Owner
  if (user.isAgencyOwner) {
    badges.add(const UserBadge(label: "Agency Owner", type: BadgeType.agency, icon: Icons.business_center));
  }

  // 8. Wealth Tier (SVIP)
  if ((user.svipLevel ?? 0) > 0) {
    final svipModel = SVIPLevelModel.getLevelByTier(user.svipLevel ?? 1);
    badges.add(UserBadge(
      label: "SVIP ${user.svipLevel}", 
      type: BadgeType.noble, 
      customFrameAsset: svipModel.badgeTagAsset,
      icon: Icons.stars,
    ));
  }

  // 9. Jackpot King
  if (user.badges.contains('jackpot_winner')) {
    badges.add(const UserBadge(label: "Jackpot King", type: BadgeType.achievement, icon: Icons.casino));
  }

  // 10. Loyal Veteran
  if (user.createdAt != null) {
    final ageInDays = DateTime.now().difference(user.createdAt).inDays;
    if (ageInDays > 180) {
      badges.add(const UserBadge(label: "Veteran", type: BadgeType.role, icon: Icons.history));
    }
  }

  return badges;
}

int _getVipLevel(String vipTierName) {
  final clean = vipTierName.toLowerCase().replaceAll(' ', '');
  if (clean.startsWith('vip')) {
    final numStr = clean.substring(3);
    final val = int.tryParse(numStr);
    if (val != null) return val;
  }
  return 0;
}
