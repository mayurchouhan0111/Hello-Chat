import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/user_badge.dart';

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
  int index = 0;
  if (level >= 80) index = 5;
  else if (level >= 50) index = 4;
  else if (level >= 30) index = 3;
  else if (level >= 20) index = 2;
  else if (level >= 10) index = 1;
  else index = 0;

  badges.add(UserBadge(
    label: "Lv.$level", 
    type: BadgeType.level, 
    imageAsset: "assets/images/levels/level_badge_$index.png"
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
  final ageInDays = DateTime.now().difference(user.createdAt).inDays;
  if (ageInDays > 180) {
    badges.add(const UserBadge(label: "Veteran", type: BadgeType.role, icon: Icons.history));
  }

  return badges;
}
