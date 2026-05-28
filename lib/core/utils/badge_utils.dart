import 'package:flutter/material.dart';
import '../models/user_model.dart';
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

  // 4. VIP
  if (user.vipTier != 'none') {
    badges.add(UserBadge(label: user.vipTier.toUpperCase(), type: BadgeType.vip, icon: Icons.workspace_premium));
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
    badges.add(UserBadge(label: "Wealth ${user.svipLevel}", type: BadgeType.noble, icon: Icons.stars));
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
