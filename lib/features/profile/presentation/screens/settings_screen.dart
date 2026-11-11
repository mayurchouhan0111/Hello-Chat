import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/overlay_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(currentUserProfileProvider).valueOrNull;
    final hasPassword = userProfile?.hasPassword == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("SETTINGS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader("ACCOUNT"),
          const Gap(12),
          _buildSettingsTile(
            context,
            Icons.person_outline_rounded,
            "Edit Profile",
            onTap: () => context.push(AppRoutes.editProfile),
          ),
          _buildSettingsTile(
            context,
            hasPassword ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
            hasPassword ? "Change Password" : "Set Up Password",
            subtitle: hasPassword
                ? "Password login active and protecting account"
                : "Not set · Enable instant password login",
            trailingWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasPassword
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasPassword
                          ? const Color(0xFF81C784)
                          : const Color(0xFFFFB74D),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    hasPassword ? "Active" : "Recommended",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasPassword
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    ),
                  ),
                ),
                const Gap(6),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
              ],
            ),
            onTap: () {
              if (hasPassword) {
                context.push(AppRoutes.resetPassword);
              } else {
                context.push(
                  AppRoutes.setPassword,
                  extra: {
                    'phone': userProfile?.phoneNumber,
                    'isReset': false,
                    'canSkip': true,
                  },
                );
              }
            },
          ),
          const Gap(24),
          _buildSectionHeader("PREFERENCES"),
          const Gap(12),
          _buildSettingsTile(
            context,
            Icons.notifications_none_rounded,
            "Notifications",
            onTap: () => context.push(AppRoutes.inbox),
          ),
          _buildSettingsTile(
            context,
            Icons.privacy_tip_outlined,
            "Privacy",
            onTap: () => context.push(AppRoutes.privacySettings),
          ),
          _buildSettingsTile(
            context,
            Icons.language_rounded,
            "Language",
            onTap: () => context.push(AppRoutes.languageSettings),
          ),
          const Gap(24),
          _buildSectionHeader("SUPPORT"),
          const Gap(12),
          _buildSettingsTile(
            context,
            Icons.help_outline_rounded,
            "Help Center",
            onTap: () => context.push(AppRoutes.helpCenter),
          ),
          _buildSettingsTile(
            context,
            Icons.info_outline_rounded,
            "About Hello Chat",
            onTap: () => context.push(AppRoutes.about),
          ),
          const Gap(40),
          _buildLogoutButton(ref, context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary, size: 20),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey[600]))
            : null,
        trailing: trailingWidget ?? const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLogoutButton(WidgetRef ref, BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showLogoutConfirmation(context, ref),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFF1F1),
        foregroundColor: Colors.red,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, size: 20),
          Gap(10),
          Text("LOG OUT OF ACCOUNT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log Out?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to log out? You can log back in anytime with your phone and password.", style: TextStyle(fontSize: 13, color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              ref.read(roomOverlayProvider.notifier).clear();
              ref.read(authServiceProvider).logout();
              // The global router will handle the redirect to Login
            },
            child: const Text("LOG OUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
