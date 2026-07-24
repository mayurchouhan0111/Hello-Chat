import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/constants/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(content, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("ABOUT HELLO CHAT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
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
          const Gap(20),
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.forum_rounded, color: AppColors.primary, size: 44),
                ),
                const Gap(16),
                const Text(
                  "Hello Chat",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const Gap(4),
                const Text(
                  "Version 2.4.0 (Production Build 1082)",
                  style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Gap(40),
          _buildInfoTile(
            context,
            "Terms of Service",
            Icons.article_outlined,
            onTap: () => _showPolicyDialog(
              context,
              "Terms of Service",
              "Welcome to Hello Chat. By accessing or using our application, you agree to be bound by these Terms of Service. Hello Chat provides live audio room social networking, messaging, and virtual gift exchanges. Users must respect community guidelines and refrain from inappropriate conduct, harassment, or unlawful activity. All virtual items, diamonds, and noble titles remain the property of the platform.",
            ),
          ),
          _buildInfoTile(
            context,
            "Privacy Policy",
            Icons.privacy_tip_outlined,
            onTap: () => _showPolicyDialog(
              context,
              "Privacy Policy",
              "Hello Chat respects your privacy. We collect minimal personal information necessary to provide authentication, real-time messaging, and profile customization. Your data is encrypted in transit and at rest. We do not sell your personal data to third parties. You may manage your visibility, stealth mode, and blocked users in Privacy Settings at any time.",
            ),
          ),
          _buildInfoTile(
            context,
            "Open Source Licenses",
            Icons.code_rounded,
            onTap: () => showLicensePage(context: context, applicationName: "Hello Chat", applicationVersion: "2.4.0"),
          ),
          const Gap(40),
          const Center(
            child: Text(
              "© 2026 Hello Chat Inc. All rights reserved.",
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String title, IconData icon, {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary, size: 20),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
