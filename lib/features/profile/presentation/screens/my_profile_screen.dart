import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/utils/number_formatter.dart';
import 'package:hello_chat/utils/level_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'dart:ui';

import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_avatar.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (userData) {
          if (userData == null) return const Center(child: Text("Not logged in"));
          
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(context, userData),
                const Gap(12),
                _buildStatsRow(userData, context),
                const Gap(16),
                _buildShortcutCards(context, userData),
                const Gap(16),
                _buildMenuList(context, userData),
                const Gap(60), // Bottom nav spacer
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel userData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE0F7FA), // Light cyan
            Color(0xFFF3E5F5), // Light purple
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildProfileSetupPill(context, userData),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.black87, size: 22),
                      onPressed: () => context.push(AppRoutes.settings),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add_outlined, color: Colors.black87, size: 22),
                      onPressed: () => context.push(AppRoutes.friendRequests),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(8),
          GestureDetector(
            onTap: () => context.push(AppRoutes.userProfile, extra: userData.uid),
            child: Hero(
              tag: 'profile_avatar',
              child: AppAvatar(
                imageUrl: userData.profilePhotoUrl,
                radius: 46,
                vipTier: userData.vipTier,
                frameUrl: userData.profileFrame,
                userLevel: userData.level,
                frameMultiplier: 2.0,
              ),
            ),
          ),
          const Gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                userData.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              if (userData.isVerified == true) ...[
                const Gap(6),
                const Icon(Icons.verified_rounded, color: Color(0xFF00ACC1), size: 18),
              ],
              if (userData.isReseller) ...[
                const Gap(6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Text("RESELLER", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSetupPill(BuildContext context, UserModel userData) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.userProfile, extra: userData.uid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4DD0E1), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Profile Setup",
              style: TextStyle(
                color: Color(0xFF00ACC1),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(2),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF00ACC1)),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.pinkAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(UserModel userData, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () => context.push(AppRoutes.friendList),
            child: _buildStatItem("Friends", formatCount(userData.friendsCount)),
          ),
          _buildStatItem("Following", formatCount(userData.followingCount)),
          _buildStatItem("Fans", formatCount(userData.followerCount)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF212121),
            letterSpacing: -0.5,
          ),
        ),
        const Gap(4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9E9E9E),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutCards(BuildContext context, UserModel userData) {
    int level = userData.level;
    int index = 0;
    if (level >= 80) index = 5;
    else if (level >= 50) index = 4;
    else if (level >= 30) index = 3;
    else if (level >= 20) index = 2;
    else if (level >= 10) index = 1;
    else index = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildShortcutCard(
            label: "Lv.$level",
            imageAsset: "assets/images/levels/level_badge_$index.png",
            color: LevelUtils.getLevelColor(level),
            iconColor: Colors.white,
            isLevel: true,
            onTap: () => context.push(AppRoutes.levelDetail),
          ),
          const Gap(8),
          _buildShortcutCard(
            label: "VIP",
            icon: Icons.workspace_premium_outlined,
            color: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFEA580C),
            onTap: () => context.push(AppRoutes.vipShop),
          ),
          const Gap(8),
          _buildShortcutCard(
            label: "Withdraw",
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            onTap: () => context.push(AppRoutes.withdrawBeans),
          ),
          const Gap(8),
          _buildShortcutCard(
            label: "Family",
            icon: Icons.groups_2_outlined,
            color: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            onTap: () => context.push(userData.familyId != null ? AppRoutes.familyList : AppRoutes.familyPortal),
          ),
          const Gap(8),
          _buildShortcutCard(
            label: "Invite",
            icon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFFFFF1F2),
            iconColor: const Color(0xFFE11D48),
            onTap: () => context.push(AppRoutes.invite),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard({
    required String label,
    IconData? icon,
    String? imageAsset,
    required Color color,
    required Color iconColor,
    bool isFamily = false,
    bool isLevel = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: isLevel ? null : color,
            gradient: isLevel ? LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isLevel ? [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 2,
                spreadRadius: -1,
                offset: const Offset(0, 1),
              ),
            ] : null,
            border: isLevel ? Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: isLevel ? ImageFilter.blur(sigmaX: 4, sigmaY: 4) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imageAsset != null)
                    SizedBox(
                      height: 40, 
                      width: 40,
                      child: Image.asset(imageAsset, fit: BoxFit.contain),
                    )
                  else if (isFamily)
                    const Icon(Icons.groups_rounded, color: Color(0xFFFFB300), size: 30)
                  else
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isLevel ? Colors.white.withOpacity(0.2) : Colors.white,
                      child: Icon(icon, color: isLevel ? Colors.white : iconColor, size: 20),
                    ),
                  const Gap(8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isLevel ? Colors.white : iconColor.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      shadows: isLevel ? [
                        const Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
                      ] : null,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, UserModel userData) {
    return Column(
      children: [
        _buildMenuTile(
          icon: Icons.shield_outlined,
          label: userData.isVerified == true ? "Account Verified" : "Identity Verification",
          iconColor: userData.isVerified == true ? const Color(0xFF4CAF50) : const Color(0xFF00ACC1),
          trailing: userData.isVerified == true 
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20)
            : _buildNotificationDot(color: Colors.cyan),
          onTap: () => context.push(AppRoutes.verification),
        ),
        if (userData.isReseller) ...[
          _buildMenuTile(
            icon: Icons.store_rounded,
            label: "Reseller Portal",
            iconColor: const Color(0xFF4CAF50),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text("Active", style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            onTap: () => context.push(AppRoutes.resellerCenter),
          ),
        ],
        _buildMenuTile(
          icon: Icons.add_card_rounded,
          label: "Recharge",
          iconColor: const Color(0xFF2196F3),
          onTap: () => context.push(AppRoutes.wallet),
        ),
        _buildMenuTile(
          icon: Icons.card_giftcard_rounded,
          label: "Invite get coins",
          iconColor: const Color(0xFFFFB300),
          onTap: () => context.push(AppRoutes.invite),
        ),
        _buildMenuTile(
          icon: Icons.account_balance_wallet_rounded,
          label: "Wallet (Withdraw)",
          iconColor: const Color(0xFFF06292),
          onTap: () => context.push(AppRoutes.wallet),
        ),
        _buildMenuTile(
          icon: Icons.favorite_rounded,
          label: "Love House",
          iconColor: const Color(0xFFF06292),
          onTap: () => context.push(AppRoutes.loveHouse),
        ),
        _buildMenuTile(
          icon: Icons.people_alt_rounded,
          label: "Friendship Hall",
          iconColor: const Color(0xFF2196F3),
          onTap: () => context.push(AppRoutes.friendshipPortal),
        ),
        _buildMenuTile(
          icon: Icons.people_alt_rounded,
          label: "CP Level",
          iconColor: const Color(0xFF9575CD),
          onTap: () => context.push(AppRoutes.cpLevel),
        ),
        _buildMenuTile(
          icon: Icons.inventory_2_rounded,
          label: "Prop Warehouse",
          iconColor: const Color(0xFFFFF176),
          onTap: () => context.push(AppRoutes.propWarehouse),
        ),
        _buildMenuTile(
          icon: Icons.account_balance_wallet_rounded,
          label: "Salary History",
          iconColor: Colors.amber[700]!,
          onTap: () => context.push(AppRoutes.salaryHistory),
        ),
        _buildMenuTile(
          icon: Icons.stars_rounded,
          label: "Prestige Store",
          iconColor: const Color(0xFFFFD54F),
          onTap: () => context.push(AppRoutes.prestigeStore),
        ),
        _buildMenuTile(
          icon: Icons.military_tech_rounded,
          label: "Medal",
          iconColor: const Color(0xFFFFB74D),
          onTap: () {},
        ),
        _buildMenuTile(
          icon: Icons.emoji_events_rounded,
          label: "Noble Hall",
          iconColor: const Color(0xFFFFF176),
          trailing: _buildNotificationDot(color: Colors.amber),
          onTap: () => context.push(AppRoutes.nobleHall),
        ),
        _buildMenuTile(
          icon: Icons.account_balance_rounded,
          label: "Prestige Vault",
          iconColor: const Color(0xFF64B5F6),
          onTap: () => context.push(AppRoutes.prestigeVault),
        ),
        _buildMenuTile(
          icon: Icons.stars_rounded,
          label: "SVIP Privileges",
          iconColor: const Color(0xFFFFD54F),
          onTap: () => context.push(AppRoutes.svipPrivileges),
        ),
        _buildMenuTile(
          icon: Icons.block_rounded,
          label: "Blocked List",
          iconColor: const Color(0xFFEF5350),
          count: 0,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required Color iconColor,
    Widget? trailing,
    int? count,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null)
              Text(
                count.toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            if (trailing != null) trailing,
            const Gap(4),
            const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      ),
    );
  }

  Widget _buildLevelBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFBA68C8), Color(0xFFE91E63)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildVIPBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF00BCD4)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.yellow, size: 10),
          const Gap(2),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationDot({required Color color}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildEventBanner() {
    return Container(
      width: 60,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        image: const DecorationImage(
          image: NetworkImage("https://picsum.photos/seed/event/200"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
