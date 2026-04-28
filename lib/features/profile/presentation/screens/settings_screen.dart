import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Icons.lock_outline_rounded,
            "Reset Password",
            onTap: () => context.push(AppRoutes.resetPassword),
          ),
          const Gap(24),
          _buildSectionHeader("PREFERENCES"),
          const Gap(12),
          _buildSettingsTile(context, Icons.notifications_none_rounded, "Notifications"),
          _buildSettingsTile(context, Icons.privacy_tip_outlined, "Privacy"),
          _buildSettingsTile(context, Icons.language_rounded, "Language"),
          const Gap(24),
          _buildSectionHeader("SUPPORT"),
          const Gap(12),
          _buildSettingsTile(context, Icons.help_outline_rounded, "Help Center"),
          _buildSettingsTile(context, Icons.info_outline_rounded, "About Hello Chat"),
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

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
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
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
        content: const Text("Are you sure you want to leave? You'll need to verify your phone number again next time.", style: TextStyle(fontSize: 13, color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
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
