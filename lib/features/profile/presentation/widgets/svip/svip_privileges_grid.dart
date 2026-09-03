import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../../../../../core/models/user_model.dart';
import '../../widgets/cp_lock_dialog.dart';
import '../../widgets/mystery_man_profile_modal.dart';
import '../../widgets/temp_id_target_sheet.dart';

class SvipPrivilegesGrid extends StatelessWidget {
  final UserModel? user;
  final int selectedTier;
  final Function(String msg) onShowToast;

  const SvipPrivilegesGrid({
    super.key,
    required this.user,
    required this.selectedTier,
    required this.onShowToast,
  });

  @override
  Widget build(BuildContext context) {
    final currentLevel = user?.svipLevel ?? 0;
    final effectiveLevel = currentLevel > 0 ? currentLevel : selectedTier;

    final privileges = _getPrivilegeList(effectiveLevel, currentLevel);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 20),
                  const Gap(8),
                  Text(
                    "SVIP EXCLUSIVE PRIVILEGES",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFFE58F),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                "Tier $effectiveLevel Benefits",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF00E5FF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Gap(14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: privileges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (context, index) {
              final priv = privileges[index];
              return _buildPrivilegeCard(context, priv, currentLevel);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegeCard(BuildContext context, _PrivilegeItem priv, int currentLevel) {
    final isUnlocked = currentLevel >= priv.minLevel;

    return GestureDetector(
      onTap: () {
        if (!isUnlocked) {
          onShowToast("This privilege unlocks at SVIP ${priv.minLevel}");
          return;
        }
        priv.onTap?.call(context, user);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF13100B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? const Color(0xFF7E6327).withValues(alpha: 0.8)
                : Colors.white12,
            width: isUnlocked ? 1.2 : 0.8,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: isUnlocked
                        ? const LinearGradient(
                            colors: [Color(0xFFFFE082), Color(0xFFFF8F00)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2E2E2E), Color(0xFF1C1C1C)],
                          ),
                    shape: BoxShape.circle,
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    priv.icon,
                    color: isUnlocked ? Colors.black : Colors.white38,
                    size: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUnlocked ? const Color(0xFF064E3B) : Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                    border: isUnlocked
                        ? Border.all(color: const Color(0xFF10B981), width: 0.6)
                        : null,
                  ),
                  child: Text(
                    isUnlocked ? "ACTIVE" : "SVIP ${priv.minLevel}",
                    style: GoogleFonts.plusJakartaSans(
                      color: isUnlocked ? const Color(0xFF34D399) : Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  priv.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: isUnlocked ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(2),
                Text(
                  priv.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: isUnlocked ? const Color(0xFFFFE58F) : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_PrivilegeItem> _getPrivilegeList(int effectiveLevel, int currentLevel) {
    return [
      _PrivilegeItem(
        title: "Room Kick Protection",
        subtitle: effectiveLevel >= 4
            ? "Kick & Mute Immunity active"
            : "Immunity in voice rooms",
        icon: Icons.shield_rounded,
        minLevel: 4,
        onTap: (ctx, u) => _showInfoDialog(ctx, "Voice Room Kick Protection",
            "SVIP 4, 5, and 6 members possess full kick and mute immunity in all voice rooms. Room owners and moderators cannot kick or silence you."),
      ),
      _PrivilegeItem(
        title: "Mystery Man Profile",
        subtitle: effectiveLevel >= 6
            ? "Self + 10 IDs hidden"
            : (effectiveLevel >= 5
                ? "Self + 2 IDs hidden"
                : (effectiveLevel >= 4 ? "Self hidden" : "Hidden avatar & name")),
        icon: Icons.visibility_off_rounded,
        minLevel: 4,
        onTap: (ctx, u) => MysteryManProfileModal.show(ctx),
      ),
      _PrivilegeItem(
        title: "Friend Hide ID",
        subtitle: effectiveLevel >= 6
            ? "25 IDs hidden + Star"
            : (effectiveLevel >= 3 ? "2 IDs hidden" : "Hide IDs in friend list"),
        icon: Icons.person_off_rounded,
        minLevel: 3,
        onTap: (ctx, u) => _showInfoDialog(ctx, "Friend List Hide ID",
            "Allows you to conceal designated friends' IDs from your public profile ranking and friend list."),
      ),
      _PrivilegeItem(
        title: "CP Lock Duration",
        subtitle: effectiveLevel >= 5
            ? "Permanent CP Lock"
            : (effectiveLevel >= 4
                ? "Up to 30 Days"
                : (effectiveLevel >= 3 ? "24h, 72h, 7 Days" : "Lock CP relation")),
        icon: Icons.favorite_rounded,
        minLevel: 3,
        onTap: (ctx, u) {
          CPLockDialog.show(
            ctx,
            cpId: 'user_cp_${u?.uid ?? ""}',
            targetUid: u?.uid ?? "",
          );
        },
      ),
      _PrivilegeItem(
        title: "Temporary ID Swap",
        subtitle: effectiveLevel >= 2
            ? "72h duration, 7 IDs"
            : "24h duration, 5 IDs",
        icon: Icons.badge_rounded,
        minLevel: 1,
        onTap: (ctx, u) => TempIdTargetSheet.show(ctx),
      ),
      _PrivilegeItem(
        title: "Global Room Kick",
        subtitle: effectiveLevel >= 6
            ? "Kick non-SVIP6 anywhere"
            : "Cross-room kick authority",
        icon: Icons.gavel_rounded,
        minLevel: 6,
        onTap: (ctx, u) => _showInfoDialog(ctx, "SVIP 6 Global Kick",
            "Absolute voice authority: SVIP 6 members can kick disruptive users from any room across the platform."),
      ),
      _PrivilegeItem(
        title: "Delegated Protection",
        subtitle: effectiveLevel >= 6
            ? "10 users for 30 Days"
            : (effectiveLevel >= 5 ? "5 users for 30 Days" : "Protect friends"),
        icon: Icons.verified_user_rounded,
        minLevel: 5,
        onTap: (ctx, u) => _showInfoDialog(ctx, "Delegated Protection",
            "As an SVIP 5/6, grant 30-day voice room kick & mute immunity to your closest friends and agency hosts."),
      ),
      _PrivilegeItem(
        title: "VIP Special Entrance",
        subtitle: "Luxury 3D arrival wave",
        icon: Icons.auto_awesome_rounded,
        minLevel: 1,
        onTap: (ctx, u) => _showInfoDialog(ctx, "Special Room Entrance",
            "Broadcast an exclusive golden metallic banner when entering any voice room."),
      ),
      _PrivilegeItem(
        title: "Family Name & Logo",
        subtitle: effectiveLevel >= 2
            ? "Edit Name & Logo"
            : "Edit Family Name",
        icon: Icons.groups_rounded,
        minLevel: 1,
        onTap: (ctx, u) => _showInfoDialog(ctx, "Family Battle Privilege",
            "Change your family battle battle name and upload custom guild logos directly."),
      ),
      _PrivilegeItem(
        title: "Exclusive Frame & Chat",
        subtitle: "Gleaming golden chat bubble",
        icon: Icons.chat_bubble_rounded,
        minLevel: 2,
        onTap: (ctx, u) => _showInfoDialog(ctx, "Exclusive Frame & Chat",
            "Unlocks SVIP custom chat bubble styling and dynamic animated avatar frames."),
      ),
    ];
  }

  void _showInfoDialog(BuildContext context, String title, String desc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13100B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF4A3A16), width: 1.2),
        ),
        title: Text(
          title,
          style: GoogleFonts.cinzel(
            color: const Color(0xFFFFE58F),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          desc,
          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "OK",
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivilegeItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final int minLevel;
  final void Function(BuildContext ctx, UserModel? user)? onTap;

  _PrivilegeItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.minLevel,
    this.onTap,
  });
}
