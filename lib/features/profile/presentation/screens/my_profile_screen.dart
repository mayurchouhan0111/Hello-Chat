import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/utils/number_formatter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

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
                _buildStatsRow(userData),
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
                      onPressed: () {},
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
                frameMultiplier: 2.0,
              ),
            ),
          ),
          const Gap(16),
          Text(
            userData.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
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

  Widget _buildStatsRow(UserModel userData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Friends", formatCount(userData.friendsCount)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildShortcutCard(
            label: "Lv.${userData.level}",
            icon: Icons.auto_awesome_outlined,
            color: const Color(0xFFF0FDFA),
            iconColor: const Color(0xFF0D9488),
            onTap: () {},
          ),
          const Gap(10),
          _buildShortcutCard(
            label: "VIP Center",
            icon: Icons.workspace_premium_outlined,
            color: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFEA580C),
            onTap: () => context.push(AppRoutes.vipShop),
          ),
          const Gap(10),
          _buildShortcutCard(
            label: "Family",
            icon: Icons.groups_2_outlined,
            color: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            onTap: () => context.push(userData.familyId != null ? AppRoutes.familyList : AppRoutes.familyPortal),
          ),
          const Gap(10),
          _buildShortcutCard(
            label: "Earnings",
            icon: Icons.monetization_on_outlined,
            color: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            onTap: () => context.push(AppRoutes.invite),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard({
    required String label,
    required IconData icon,
    required Color color,
    required Color iconColor,
    bool isFamily = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isFamily)
                const Icon(Icons.groups_rounded, color: Color(0xFFFFB300), size: 30)
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              const Gap(8),
              Text(
                label,
                style: TextStyle(
                  color: iconColor.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, UserModel userData) {
    return Column(
      children: [
        _buildMenuTile(
          icon: Icons.insights_outlined,
          label: "Creator Center",
          iconColor: const Color(0xFF0EA5E9),
          onTap: () {},
        ),
        _buildMenuTile(
          icon: Icons.celebration_outlined,
          label: "Event Center",
          iconColor: const Color(0xFFF43F5E),
          trailing: _buildEventBanner(),
          onTap: () {},
        ),
        const Gap(12),
        _buildMenuTile(
          icon: Icons.payments_outlined,
          label: "My Wallet",
          iconColor: const Color(0xFFF59E0B),
          onTap: () => context.push(AppRoutes.wallet),
        ),
        if (userData.isReseller)
          _buildMenuTile(
            icon: Icons.storefront_outlined,
            label: "Reseller Center",
            iconColor: const Color(0xFF10B981),
            onTap: () => context.push(AppRoutes.resellerCenter),
          ),
        _buildMenuTile(
          icon: Icons.inventory_2_outlined,
          label: "Item Bag",
          iconColor: const Color(0xFF8B5CF6),
          count: 1,
          onTap: () => context.push(AppRoutes.propWarehouse),
        ),
        _buildMenuTile(
          icon: Icons.dynamic_feed_outlined,
          label: "My Posts",
          iconColor: const Color(0xFF64748B),
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
