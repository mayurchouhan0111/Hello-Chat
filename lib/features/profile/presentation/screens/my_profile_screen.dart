import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/constants/app_spacing.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/providers/user_provider.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/utils/number_formatter.dart';
import 'dart:ui';

import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/vip_provider.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (userData) {
        if (userData == null) return const Scaffold(body: Center(child: Text("Not logged in")));
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Column(
              children: [
                // 1. Header Hero with Radial Gradient
                _buildHeader(context, userData),

                const SizedBox(height: 8),

                // 2. Stats
                _buildStats(context, userData),
                _buildLevelProgress(userData),

                const SizedBox(height: 12),

                // 3. Quick Action Row
                _buildQuickActions(context, userData),

                const SizedBox(height: 12),

                // 4. Menu List
                _buildMenuList(context, userData, ref),

                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, UserModel userData) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFFE0F2FE), Colors.white],
          center: Alignment(0, -0.6),
          radius: 1.2,
        ),
      ),
      child: Stack(
        children: [
          // App Bar Area Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 36, 16, 12), // Reduced top to 36
            child: Column(
              children: [
                // Top Bar Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.userProfile, extra: userData.uid),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced padding
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Text("Profile Setup", style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12)), // Scaled down
                            Icon(Icons.chevron_right_rounded, color: Color(0xFF00E5FF), size: 14),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.settings_outlined, color: Colors.black45, size: 22),
                        const SizedBox(width: 12),
                        const Icon(Icons.person_add_outlined, color: Colors.black45, size: 22),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12), // Reduced from 20

                // Avatar with Frame
                GestureDetector(
                  onTap: () => context.push(AppRoutes.userProfile, extra: userData.uid),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 76, // Reduced from 80
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: userData.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${userData.uid}/200" : userData.profilePhotoUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (userData.profileFrame.isNotEmpty)
                        SizedBox(
                          width: 96, // Reduced from 100
                          height: 96,
                          child: Image.network(userData.profileFrame, fit: BoxFit.contain),
                        ),
                      if (userData.profileFrame.isEmpty)
                        const SizedBox(width: 96, height: 96),
                    ],
                  ),
                ),

                const SizedBox(height: 6), // Reduced from 8

                // Username with Emojis
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("🌹 ", style: TextStyle(fontSize: 14)),
                    Text(
                      userData.displayName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87), // Muted for better scale
                    ),
                    const Text(" 🔥", style: TextStyle(fontSize: 14)),
                  ],
                ),
                Text("@${userData.username}", style: const TextStyle(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.bold)),
                if (userData.vipTier != 'none')
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.orange, Colors.amber]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(userData.vipTier, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, UserModel userData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20), // Reduced from 40
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(userData.followerCount, "Friends"),
          _buildStatItem(userData.followingCount, "Following"),
          _buildStatItem(userData.followerCount, "Fans"),
        ],
      ),
    );
  }

  Widget _buildStatItem(int count, String label) {
    return Column(
      children: [
        Text(formatCount(count), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 2), 
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLevelProgress(UserModel userData) {
    const int xpPerLevel = 1000;
    final int currentLevelXP = userData.xp % xpPerLevel;
    final double percentage = (currentLevelXP / xpPerLevel).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Level ${userData.level}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              Text("${currentLevelXP}/${xpPerLevel} XP", style: const TextStyle(color: Colors.black45, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.cyan.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, UserModel userData) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildQuickActionItem(
            icon: Icons.shield_rounded, 
            label: "Lv.${userData.level}", 
            color: const Color(0xFFE0F7FA), 
            iconColor: Colors.cyan,
          ),
          const SizedBox(width: 8), // Reduced from 12
          GestureDetector(
            onTap: () => context.push(AppRoutes.vipShop),
            child: _buildQuickActionItem(
              icon: Icons.workspace_premium_rounded, 
              label: "Purchase VIP", 
              color: const Color(0xFFFFF7ED), 
              iconColor: Colors.orange,
            ),
          ),
          const SizedBox(width: 8), // Reduced from 12
          _buildQuickActionItem(
            icon: Icons.gamepad_rounded, 
            label: "JOY AGENCY", 
            color: const Color(0xFFEEF2FF), 
            iconColor: Colors.indigo,
          ),
          const SizedBox(width: 8), // Reduced from 12
          GestureDetector(
            onTap: () => context.push(AppRoutes.salaryHistory),
            child: _buildQuickActionItem(
              icon: Icons.auto_awesome_rounded, 
              label: "Earn Money", 
              color: const Color(0xFFFDF2F8), 
              iconColor: Colors.pink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({required IconData icon, required String label, required Color color, required Color iconColor}) {
    return Container(
      width: 68, // Reduced from 76
      height: 64, 
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4), // Reduced internal padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 21), 
          const SizedBox(height: 4), 
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center, maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, UserModel userData, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildMenuTile(
            Icons.videogame_asset_outlined, "Fun Plaza", 
            color: Colors.orange, 
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.library_books_rounded, color: Colors.orange, size: 16), // Scaled
                const Text(" x1", style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              ],
            ),
          ),
          _buildMenuTile(Icons.trending_up_rounded, "Creator Center", color: Colors.teal),
          _buildMenuTile(
            Icons.campaign_outlined, "Event Center", 
            color: Colors.lightBlue,
            trailing: const CircleAvatar(radius: 10, backgroundImage: NetworkImage("https://picsum.photos/seed/event/100")),
          ),
          _buildMenuTile(
            Icons.account_balance_wallet_outlined, "Wallet", 
            color: Colors.pinkAccent,
            onTap: () => context.push(AppRoutes.wallet),
          ),
          _buildMenuTile(
            Icons.inventory_2_outlined, "Item Bag", 
            color: Colors.amber, 
            trailing: const Text("3", style: TextStyle(color: Colors.black26, fontSize: 12, fontWeight: FontWeight.bold)),
            onTap: () => context.push(AppRoutes.prestigeStore),
          ),
          
          // ADMIN SECTION
          if (userData.tags.contains("Admin") || userData.tags.contains("SuperAdmin"))
            _buildAdminSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text("ADMIN TOOLS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black26, letterSpacing: 1.5)),
        ),
        _buildMenuTile(
          Icons.settings_suggest_rounded, 
          "🔧 Feed Sample VIP Tiers", 
          color: Colors.redAccent,
          onTap: () async {
            try {
              await ref.read(vipServiceProvider).feedSampleTiers();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sample VIP Tiers Updated!")));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildMenuTile(IconData icon, String label, {required Color color, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(6), // Reduced from 8
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18), // Reduced from 20
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)), // Reduced from 15
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing,
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // Tight vertical
      visualDensity: const VisualDensity(vertical: -2), // Maximum vertical density
    );
  }
}
