import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/router/app_router.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _hideOnlineStatus = false;
  bool _stealthMode = false;
  bool _hideLocation = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _hideOnlineStatus = data['hideOnlineStatus'] as bool? ?? false;
          _stealthMode = data['stealthMode'] as bool? ?? false;
          _hideLocation = data['hideLocation'] as bool? ?? false;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrivacySetting(String key, bool value) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Privacy settings updated"), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("PRIVACY SETTINGS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionHeader("VISIBILITY & STATUS"),
                const Gap(12),
                _buildSwitchTile(
                  title: "Hide Online Status",
                  subtitle: "Don't show when you are active in app or rooms",
                  icon: Icons.visibility_off_outlined,
                  value: _hideOnlineStatus,
                  onChanged: (val) {
                    setState(() => _hideOnlineStatus = val);
                    _updatePrivacySetting('hideOnlineStatus', val);
                  },
                ),
                _buildSwitchTile(
                  title: "Stealth Room Entry",
                  subtitle: "Hide your room entrance announcement banner",
                  icon: Icons.shield_outlined,
                  value: _stealthMode,
                  onChanged: (val) {
                    setState(() => _stealthMode = val);
                    _updatePrivacySetting('stealthMode', val);
                  },
                ),
                _buildSwitchTile(
                  title: "Hide Location",
                  subtitle: "Hide country flag and city on profile card",
                  icon: Icons.location_off_outlined,
                  value: _hideLocation,
                  onChanged: (val) {
                    setState(() => _hideLocation = val);
                    _updatePrivacySetting('hideLocation', val);
                  },
                ),
                const Gap(24),
                _buildSectionHeader("BLOCK & INTERACTIONS"),
                const Gap(12),
                _buildNavigationTile(
                  title: "Blocked Users",
                  subtitle: "Manage accounts you have blocked from messaging",
                  icon: Icons.block_rounded,
                  onTap: () {
                    final uid = ref.read(authServiceProvider).currentUser?.uid;
                    context.push(AppRoutes.followList, extra: {'type': 'Blocked', 'targetUid': uid});
                  },
                ),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: SwitchListTile(
        activeColor: AppColors.primary,
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        secondary: Icon(icon, color: AppColors.primary, size: 22),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
