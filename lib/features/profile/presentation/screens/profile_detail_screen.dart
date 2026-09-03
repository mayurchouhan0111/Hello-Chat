import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/dino_provider.dart';
import '../../../../core/models/dino_model.dart';
import '../../../../core/models/vip_tier_model.dart';
import '../../../../core/widgets/pet_icon.dart';
import 'package:hello_chat/core/constants/app_spacing.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/providers/user_provider.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/utils/number_formatter.dart';
import 'package:hello_chat/utils/level_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../chats/presentation/screens/private_chat_screen.dart';
import '../../../../core/services/report_service.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/providers/vip_provider.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/widgets/user_badge.dart';
import '../../../../core/utils/badge_utils.dart';
import '../../../../core/widgets/user_profile_card.dart';
import '../../../../core/providers/relationship_provider.dart';
import '../../../../core/services/relationship_service.dart';
import '../../../../core/models/relationship_model.dart';

class ProfileDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<ProfileDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasRecordedVisit = false;
  bool _isActionLoading = false;

  void _showCuteSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const Gap(12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider(widget.userId));

    return userAsync.when(
      loading: () => _buildProfileDetailShimmerLoading(),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (userData) {
        if (userData == null) return const Scaffold(body: Center(child: Text("User not found")));
        
        final vipLevel = _getVipLevel(userData.vipTier);
        final hasVipBg = vipLevel == 1 || vipLevel == 2 || (vipLevel >= 3 && vipLevel <= 8);
        final textColor = hasVipBg ? Colors.white : Colors.black87;
        final subTextColor = hasVipBg ? Colors.white70 : Colors.black45;
        
        // Dynamic Visit Tracking (Run once post-frame to maintain 60 FPS transition)
        if (!_hasRecordedVisit) {
          _hasRecordedVisit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final me = ref.read(currentUserProfileProvider).value;
            if (me != null && me.uid != userData.uid) {
              ref.read(profileServiceProvider).recordProfileVisit(userData.uid, me.profilePhotoUrl);
            }
          });
        }
        
        return Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: RepaintBoundary(child: ProfileBottomBarWidget(userData: userData)),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Photo with Overlay Actions
                RepaintBoundary(child: _buildCoverPhoto(context, userData)),

                RepaintBoundary(
                  child: UserProfileCard(
                    user: userData,
                    borderRadius: BorderRadius.zero,
                    boxShadow: const [],
                    optimizeCrown: true,
                    staticDecor: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 64),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Side: Identity & Stats
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildIdentity(context, userData, textColor, subTextColor),
                                  const SizedBox(height: 12),
                                  _buildStats(context, userData, textColor, subTextColor),
                                ],
                              ),
                            ),
                            
                            // Right Side: Premium Badges & Level Shield
                            _buildRightSideBadges(userData, textColor),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 3. Badge/Achievement Chips (Restored)
                      RepaintBoundary(
                        child: _buildBadgeChips(context, userData),
                      ),

                      const SizedBox(height: 12),

                      // 4. Info Cards Horizontal Scroll (Family, Battle, Agency, Contribution)
                      RepaintBoundary(child: _buildInfoCardsScrollable(context, userData)),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

                const SizedBox(height: 12),

                // SECTION SEPARATION (Minimum Gap)
                const Divider(height: 6, thickness: 6, color: Color(0xFFF1F5F9)),

                // 6. Lower Container (White Section)
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      RepaintBoundary(child: _buildTabs(context)),
                      RepaintBoundary(child: _buildTabContent(context, userData)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverPhoto(BuildContext context, UserModel userData) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 260,
          color: const Color(0xFF1E1B4B),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (userData.profilePhotoUrl.isNotEmpty)
                (userData.profilePhotoUrl.startsWith('assets/')
                    ? Image.asset(userData.profilePhotoUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                    : CachedNetworkImage(
                        imageUrl: userData.profilePhotoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: 720,
                        memCacheHeight: 520,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      )),
              Container(
                color: Colors.black.withOpacity(0.35),
                child: Center(
                  child: AppAvatar(
                    imageUrl: userData.profilePhotoUrl,
                    radius: 50,
                    vipTier: userData.vipTier,
                    frameUrl: userData.profileFrame,
                    userLevel: userData.level,
                    frameMultiplier: 2.0,
                    staticFrame: false,
                    maxFps: 24.0,
                    maxRenderSize: const Size(200, 200),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Gradient overlay for readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.4, 0.9],
              ),
            ),
          ),
        ),
        // Top Buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
                if (userData.uid != FirebaseAuth.instance.currentUser?.uid)
                  Row(
                    children: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.share_rounded, color: Colors.white)),
                      IconButton(
                        onPressed: () => _showMoreOptions(context, userData),
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white)
                      ),
                    ],
                  )
                else
                  IconButton(
                    onPressed: () => context.push(AppRoutes.editProfile),
                    icon: const Icon(Icons.edit_rounded, color: Colors.white)
                  ),
              ],
            ),
          ),
        ),
        // Visitor Badge (Dynamic)
        Positioned(
          bottom: 24,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Last few visitor avatars
                if (userData.recentVisitors.isNotEmpty)
                  Row(
                    children: userData.recentVisitors.take(3).map((url) {
                      final isValidUrl = url.isNotEmpty && Uri.tryParse(url)?.hasAbsolutePath == true;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: ClipOval(
                            child: isValidUrl 
                              ? CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white30, size: 8),
                                )
                              : const Icon(Icons.person, color: Colors.white30, size: 8),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const Icon(Icons.visibility_outlined, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  "visited: ${formatCount(userData.visitorCount)}", 
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentity(BuildContext context, UserModel userData, Color textColor, Color subTextColor) {
    final vipLevel = _getVipLevel(userData.vipTier);
    final hasVipBg = vipLevel == 1 || vipLevel == 2 || (vipLevel >= 3 && vipLevel <= 8);
    final bool hasCP = userData.partnerUid != null && userData.partnerUid!.isNotEmpty;
    final bool hasBestie = userData.bestFriendName != null && userData.bestFriendName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line 1: User Display Name + Verified Icon + Gender Pill
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              userData.displayName.isEmpty ? "User" : userData.displayName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
            if (userData.isVerified == true) ...[
              const Icon(Icons.verified_rounded, color: Color(0xFF00ACC1), size: 18),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: userData.gender.toLowerCase() == 'male' 
                    ? const Color(0xFF2196F3).withOpacity(0.12) 
                    : const Color(0xFFE91E63).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                userData.gender.toLowerCase() == 'male' ? Icons.male_rounded : Icons.female_rounded,
                color: userData.gender.toLowerCase() == 'male' ? const Color(0xFF1E88E5) : const Color(0xFFD81B60),
                size: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Line 2: ID Pill + Country
        Row(
          children: [
            GestureDetector(
              onTap: () {
                if (userData.helloId != null) {
                  Clipboard.setData(ClipboardData(text: userData.displayId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Copied to Clipboard")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID is still pending...")));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: hasVipBg ? Colors.white.withOpacity(0.15) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "ID: ${userData.displayId}", 
                      style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w800, fontFamily: 'monospace')
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy_rounded, color: subTextColor, size: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                userData.country.isEmpty ? 'Global' : userData.country,
                style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),

        // Dedicated Partner Component Block (PRD Section 4)
        if (hasCP) ...[
          _buildPartnerComponentBlock(context, userData),
        ],

        if (hasBestie && !hasCP) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF00BCD4)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_alt_rounded, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text("🤝 Bestie: ${userData.bestFriendName}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPartnerComponentBlock(BuildContext context, UserModel userData) {
    final partnerUid = userData.partnerUid!;
    final partnerAvatar = userData.partnerAvatar ?? '';
    final partnerName = userData.partnerName ?? 'Partner';
    final anniversary = userData.anniversaryDate ?? DateTime.now().toString().split(' ')[0];

    return Consumer(
      builder: (context, ref, child) {
        final partnerUserAsync = ref.watch(userProfileProvider(partnerUid));
        final partnerDisplayId = partnerUserAsync.valueOrNull?.displayId ?? partnerUid.substring(0, 6);

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF331526), Color(0xFF1E0B19)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.pinkAccent.withOpacity(0.4), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.pink.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.userProfile, extra: partnerUid),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.pinkAccent, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.pink.withOpacity(0.2),
                    backgroundImage: partnerAvatar.isNotEmpty ? CachedNetworkImageProvider(partnerAvatar) : null,
                    child: partnerAvatar.isEmpty ? const Icon(Icons.favorite, color: Colors.pinkAccent, size: 18) : null,
                  ),
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 12),
                        const Gap(4),
                        Flexible(
                          child: Text(
                            partnerName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      "UID: $partnerDisplayId",
                      style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    ),
                    const Gap(2),
                    Text(
                      "Anniversary: $anniversary",
                      style: const TextStyle(color: Color(0xFFFF80AB), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 18),
                onPressed: () => context.push(AppRoutes.userProfile, extra: partnerUid),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 12),
    );
  }

  Widget _buildHeaderChip(String label, IconData icon, Color color, {VoidCallback? onTap, String? iconUrl}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Pill
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.fromLTRB(20, 3, 10, 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ),
          // Overlapping Badge
          Positioned(
            left: -6,
            top: -8,
            child: Container(
              width: 32, // Increased size
              height: 32,
              child: (iconUrl != null && iconUrl.isNotEmpty)
                  ? (iconUrl.startsWith('assets/')
                      ? Image.asset(
                          iconUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 16),
                        )
                      : (Uri.tryParse(iconUrl)?.hasAbsolutePath == true)
                          ? CachedNetworkImage(
                              imageUrl: iconUrl, 
                              fit: BoxFit.contain,
                              memCacheWidth: 64,
                              memCacheHeight: 64,
                              placeholder: (_, __) => Icon(icon, color: color, size: 16),
                              errorWidget: (_, __, ___) => Icon(icon, color: color, size: 16),
                            )
                          : Icon(icon, color: color, size: 16))
                  : Icon(icon, color: color, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, UserModel userData, Color textColor, Color subTextColor) {
    return IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: _buildStatClickableItem(
                context, userData.followerCount, "Fans", textColor, subTextColor,
                onTap: () => context.push(AppRoutes.followList, extra: {'type': 'Followers', 'targetUid': userData.uid})
              ),
            ),
            VerticalDivider(color: textColor.withOpacity(0.2), thickness: 1, indent: 4, endIndent: 4, width: 20),
            Flexible(
              child: _buildStatClickableItem(
                context, userData.followingCount, "Following", textColor, subTextColor,
                onTap: () => context.push(AppRoutes.followList, extra: {'type': 'Following', 'targetUid': userData.uid})
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildStatClickableItem(BuildContext context, num count, String label, Color textColor, Color subTextColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatCount(count), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
          Text(label, style: TextStyle(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBadgeChips(BuildContext context, UserModel userData) {
    final rawBadges = getBadgesForUser(userData);
    if (rawBadges.isEmpty) return const SizedBox.shrink();

    final badges = rawBadges.map((b) {
       return b is UserBadge ? UserBadge(
         label: b.label,
         type: b.type,
         prefix: b.prefix,
         icon: b.icon,
         imageAsset: b.imageAsset,
         customFrameAsset: b.customFrameAsset,
         preferStaticFrame: true,
         margin: EdgeInsets.zero,
       ) : b;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: badges,
      ),
    );
  }

  Widget _buildRightSideBadges(UserModel user, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Large Level Shield only
        _buildLevelShield(user, textColor),
      ],
    );
  }

  static final TextStyle _cinzelBaseStyle = GoogleFonts.cinzel(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    shadows: const [
      Shadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 0.5)),
    ],
  );

  Widget _buildLevelShield(UserModel user, [Color textColor = Colors.black87]) {
    int level = LevelUtils.calculateLevel(user.xp);
    int index = 0;
    if (level >= 80) index = 5;
    else if (level >= 50) index = 4;
    else if (level >= 30) index = 3;
    else if (level >= 20) index = 2;
    else if (level >= 10) index = 1;
    else index = 0;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.levelDetail),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            "assets/images/levels/level_badge_$index.png",
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
          const SizedBox(height: 4),
          Text(
            "Lv.$level",
            style: _cinzelBaseStyle.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }


  int _getVipLevel(String vipTierName) {
    final clean = vipTierName.toLowerCase().replaceAll(' ', '');
    if (clean.startsWith('vip')) {
      final numStr = clean.substring(3);
      final val = int.tryParse(numStr);
      if (val != null) return val;
    }
    return 0;
  }

  Widget _buildChipIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 14),
    );
  }

  Widget _buildLevelTag(int level) {
    return UserBadge(
      label: "Lv.$level",
      type: BadgeType.level,
      customFrameAsset: LevelUtils.getLevelFrameAsset(level),
      icon: Icons.shield_rounded,
      margin: EdgeInsets.zero,
    );
  }

  Widget _buildInfoCardsScrollable(BuildContext context, UserModel userData) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 0. Family Badge Card (if user is in a family)
          if (userData.familyId != null) ...[
            _buildFamilyBadgeCard(userData),
            const SizedBox(width: 10),
          ],

          // 1. Contribution Card (Top List)
          _buildContributionCard(userData),
        ],
      ),
    );
  }

  // ... (Other methods) ...

  Widget _buildContributionCard(UserModel userData) {
    final contributorsAsync = ref.watch(topContributorsProvider(userData.uid));
    
    return contributorsAsync.when(
      data: (contributors) {
        return GestureDetector(
          onTap: () => context.push(
            AppRoutes.userContributionRanking,
            extra: {
              'targetUid': userData.uid,
              'targetUserName': userData.displayName,
            },
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 145, maxWidth: 175),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1A2E),
                  Color(0xFF101422),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF818CF8).withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF818CF8).withOpacity(0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (contributors.isEmpty)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF818CF8).withOpacity(0.2),
                          const Color(0xFF6366F1).withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4), width: 1),
                    ),
                    child: const Center(
                      child: Icon(Icons.stars_rounded, color: Color(0xFF818CF8), size: 18),
                    ),
                  )
                else
                  SizedBox(
                    height: 28,
                    width: 44,
                    child: Stack(
                      children: List.generate(contributors.length.clamp(0, 3), (index) {
                        final c = contributors[index];
                        final avatar = c['photoUrl'] ?? c['avatarUrl'] ?? "";
                        final ringColors = [
                          const Color(0xFFFFD700),
                          const Color(0xFFE2E8F0),
                          const Color(0xFFCD7F32),
                        ];
                        return Positioned(
                          left: index * 10.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ringColors[index % ringColors.length],
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF1E293B),
                              backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                              child: avatar.isEmpty
                                  ? const Icon(Icons.person, size: 12, color: Colors.white54)
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Top List",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF818CF8), size: 14),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF131A26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8))),
            SizedBox(width: 6),
            Text("Top List", style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }


  Widget _buildFamilyCard(BuildContext context, String? logoUrl, String title, String sub, bool isClickable) {
    return GestureDetector(
      onTap: isClickable ? () => context.push(AppRoutes.familyPortal) : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF161E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            if (logoUrl != null)
              ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: logoUrl, width: 32, height: 32))
            else
              Container(
                padding: const EdgeInsets.all(6), 
                decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), 
                child: const Icon(Icons.shield_rounded, color: Color(0xFFFFD700), size: 20)
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(sub, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isClickable) const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyBadgeCard(UserModel userData) {
    if (userData.familyId == null) return const SizedBox.shrink();
    final familyAsync = ref.watch(familyStreamProvider(userData.familyId!));
    final isOwner = userData.uid == FirebaseAuth.instance.currentUser?.uid;

    return familyAsync.when(
      data: (family) {
        if (family == null) return const SizedBox.shrink();
        final themeIdx = FamilyModel.themeIndexForLevel(family.level);
        final badgeColor = _themeBadgeColor(themeIdx);

        return GestureDetector(
          onTap: () => context.push(
            isOwner ? AppRoutes.familyPortal : AppRoutes.familyDetail,
            extra: isOwner ? null : family.id,
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 215),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B2232),
                  Color(0xFF0F1420),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Gold Avatar Frame
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: family.avatarUrl != null && family.avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: family.avatarUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 120,
                            memCacheHeight: 120,
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF0F172A),
                              child: const Icon(Icons.shield_rounded, color: Color(0xFFFFD700), size: 16),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF0F172A),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFFFFD700), size: 16),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Clan Name & Tier Pill
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        family.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2.5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  badgeColor,
                                  badgeColor.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: badgeColor.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              'Lv${family.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              family.rankName,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Combat Power (CP) & Chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700), size: 10),
                        const SizedBox(width: 2),
                        Text(
                          '${_formatCompactCP(family.totalCombatPoints)} CP',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFFFD700), size: 13),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF131A26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatCompactCP(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Color _themeBadgeColor(int idx) {
    switch (idx) {
      case 1: return AppColors.familyThemeBBadge;
      case 2: return AppColors.familyThemeCBadge;
      case 3: return AppColors.familyThemeDBadge;
      default: return AppColors.familyThemeABadge;
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  Widget _buildTabs(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black26,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(
            icon: Icon(Icons.account_circle_outlined, size: 22),
            text: "Profile",
          ), 
          Tab(
            icon: Icon(Icons.auto_awesome_mosaic_outlined, size: 22),
            text: "Moments",
          ),
          Tab(
            icon: Icon(Icons.pets_outlined, size: 20),
            text: "Dino",
          ),
          Tab(
            icon: Icon(Icons.military_tech_outlined, size: 22),
            text: "Level",
          )
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, UserModel userData) {
    if (_tabController.index == 1) {
      return _buildMomentsTab(context, userData);
    }
    
    if (_tabController.index == 2) {
      return _buildDinoTab(context, userData);
    }

    if (_tabController.index == 3) {
      return _buildLevelTab(context, userData);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Level Progress Section (Commented out as requested)
          // _buildLevelProgressCard(userData),
          // const Gap(20),

          // 2. Relationship / Partner Section (If exists)
          if (userData.partnerUid != null) ...[
            _buildPartnerCard(userData),
            const Gap(20),
          ],

          // 3. Biography Section
          const Text("Biography", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            userData.bio.isEmpty ? "No biography shared yet." : userData.bio,
            style: const TextStyle(color: Colors.black54, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),

          // 4. Tags Section
          if (userData.tags.isNotEmpty) ...[
            const Text("Clan Badges", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const Gap(12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: userData.tags.map((tag) => _buildSimpleBorderChip(tag, AppColors.primary)).toList(),
            ),
            const Gap(24),
          ],

          // 5. Basic Info Grid
          const Text("Basic information", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.location_on_rounded, userData.country.isEmpty ? "Global" : userData.country),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.calendar_month_rounded, "Join: ${_formatDateShort(userData.createdAt)}"),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHobbyIcon(Icons.emoji_emotions_rounded),
              _buildHobbyIcon(Icons.music_note_rounded),
              _buildHobbyIcon(Icons.sports_soccer_rounded),
              _buildHobbyIcon(Icons.videogame_asset_rounded),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLevelTab(BuildContext context, UserModel userData) {
    final progress = LevelUtils.getLevelProgress(userData.xp);
    final color = LevelUtils.getLevelColor(userData.level);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Gap(20),
          _buildLevelShield(userData),
          const Gap(16),
          Text(
            "Level ${userData.level}",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const Gap(8),
          Text(
            LevelUtils.getXPProgressText(userData.xp),
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const Gap(24),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const Gap(40),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.levelDetail),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: color.withOpacity(0.4),
            ),
            child: const Text("View Level Rewards & Medals", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Gap(60),
        ],
      ),
    );
  }

  Widget _buildLevelProgressCard(UserModel userData) {
    // Mock progress calculation
    double progress = (userData.xp % 1000) / 1000.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text("Lv.${userData.level}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary)),
               Text("Combat Pwr: ${userData.combatPoints}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.accent)),
            ],
          ),
          const Gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const Gap(8),
          const Center(child: Text("342 XP to next level", style: TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(UserModel userData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2), // Light Pink
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECDD3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 20),
          ),
          const Gap(12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Partner", style: TextStyle(color: Colors.pinkAccent, fontSize: 9, fontWeight: FontWeight.w900)),
              Text(userData.partnerName ?? "Sweetheart", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(12)),
            child: Text("Lv.${userData.cpLevel}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBorderChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }

  String _formatDateShort(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  Widget _buildMomentsTab(BuildContext context, UserModel userData) {
    final momentsAsync = ref.watch(userMediaStoreProvider((uid: userData.uid, tag: 'moment')));
    
    return momentsAsync.when(
      data: (moments) {
        if (moments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text("No moments shared yet", style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: moments.length,
          itemBuilder: (context, index) {
            final moment = moments[index];
            return GestureDetector(
              onTap: () => context.push(AppRoutes.momentDetail, extra: {
                'ownerUid': userData.uid,
                'mediaId': moment['mediaId'],
              }),
              child: CachedNetworkImage(
                imageUrl: moment['imageUrl'] ?? "",
                fit: BoxFit.cover,
                memCacheWidth: 360,
                memCacheHeight: 360,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text("Error loading moments: $e")),
    );
  }

  Widget _buildDinoTab(BuildContext context, UserModel userData) {
    final dinoAsync = ref.watch(dinoStreamProvider(userData.uid));
    final currentAuthUser = ref.watch(authStateProvider).value;
    final isMe = currentAuthUser?.uid == userData.uid;

    return dinoAsync.when(
      data: (dino) {
        if (dino == null) {
          return _buildNoDinoState(context, userData, isMe);
        }
        
        final activeDino = dino.calculateCurrentStats();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              _buildPetHeader(activeDino),
              const Gap(24),
              _buildPetCharacterCard(activeDino),
              const Gap(32),
              _buildPetStatusBars(activeDino),
              const Gap(40),
              if (isMe) _buildPetInteractions(context, activeDino),
              const Gap(40),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildNoDinoState(BuildContext context, UserModel userData, bool isMe) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                color: Colors.white, 
                shape: BoxShape.circle, 
                boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)]
              ),
              child: const Icon(Icons.egg_rounded, size: 80, color: Colors.amber),
            ).animate().shimmer(duration: 3.seconds).shake(hz: 1, curve: Curves.easeInOut),
            const Gap(32),
            const Text("Your Companion Awaits", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)),
            const Gap(12),
            const Text(
              "Every great explorer needs a companion. Adopt your own prehistoric friend and start your journey together!", 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)
            ),
            if (isMe) ...[
              const Gap(40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => ref.read(dinoServiceProvider).initializeDino(userData.uid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 10,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: const Text("ADOPT FREE EGG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPetHeader(DinoModel dino) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.pets_rounded, color: Color(0xFF9333EA), size: 20),
              ),
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dino.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                  Text("Stage: ${dino.stage}", style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, fontSize: 11)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFF4776E6)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF4776E6).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Text("LV.${dino.level}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCharacterCard(DinoModel dino) {
    final stageColor = dino.stage == 'Adult' ? Colors.orange :
                       dino.stage == 'Teen' ? Colors.blue :
                       dino.stage == 'Baby' ? Colors.amber :
                       AppColors.primary;

    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [stageColor.withOpacity(0.05), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: stageColor.withOpacity(0.1), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow effect
          Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: stageColor.withOpacity(0.2), blurRadius: 60, spreadRadius: 20)
              ],
            ),
          ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PetIcon(size: 180),
              const Gap(16),
              if (dino.stage == 'Egg')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text("HATCHING SOON", style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ).animate().shimmer(duration: 2.seconds)
              else
                const Text("STAP ON DINO TO INTERACT", style: TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ).animate().slideY(begin: 0, end: -0.05, duration: 2.seconds, curve: Curves.easeInOut),
        ],
      ),
    );
  }

  Widget _buildPetStatusBars(DinoModel dino) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CORE VITALS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black26, letterSpacing: 1.5)),
          const Gap(20),
          _buildStatBar("HEALTH", dino.health, Colors.redAccent, Icons.favorite_rounded),
          const Gap(16),
          _buildStatBar("ENERGY", dino.energy, Colors.orangeAccent, Icons.bolt_rounded),
          const Gap(16),
          _buildStatBar("EXP", (dino.xp % 100) / 100, Colors.blueAccent, Icons.auto_awesome_rounded),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, double progress, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Row(
               children: [
                 Icon(icon, size: 14, color: color),
                 const Gap(6),
                 Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black54)),
               ],
             ),
             Text("${(progress * 100).toInt()}%", style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900)),
          ],
        ),
        const Gap(8),
        Stack(
          children: [
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(5)),
            ),
            AnimatedContainer(
              duration: 500.ms,
              height: 10,
              width: MediaQuery.of(context).size.width * 0.75 * progress, // Approximation for the bar width
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(5),
                boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
              ),
            ).animate().shimmer(duration: 2.seconds, color: Colors.white24),
          ],
        ),
      ],
    );
  }

  Widget _buildPetInteractions(BuildContext context, DinoModel dino) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("CARE ACTIONS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black26, letterSpacing: 1.5)),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: "FEED",
                icon: Icons.restaurant_rounded,
                color: Colors.orange,
                onTap: _isActionLoading ? () {} : () async {
                  setState(() => _isActionLoading = true);
                  try {
                    await ref.read(dinoServiceProvider).feedDino(dino.ownerUid);
                    _showCuteSnackBar("Dino fed successfully! 🍖 XP +10");
                  } catch (e) {
                    _showCuteSnackBar("Oops! $e", isError: true);
                  } finally {
                    if (mounted) setState(() => _isActionLoading = false);
                  }
                },
                subtitle: "10 DIAMS",
              ),
            ),
            const Gap(16),
            Expanded(
              child: _buildActionButton(
                label: "PLAY",
                icon: Icons.sports_esports_rounded,
                color: Colors.blue,
                onTap: _isActionLoading ? () {} : () async {
                  setState(() => _isActionLoading = true);
                  try {
                    await ref.read(dinoServiceProvider).playWithDino(dino.ownerUid);
                    _showCuteSnackBar("Played with Dino! 🎮 Happy levels increased!");
                  } catch (e) {
                     _showCuteSnackBar("Oops! $e", isError: true);
                  } finally {
                    if (mounted) setState(() => _isActionLoading = false);
                  }
                },
                subtitle: "BOOST XP",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap, required String subtitle}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: _isActionLoading 
                ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 28),
            ),
            const Gap(12),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14, letterSpacing: 0.5)),
            const Gap(2),
            Text(subtitle, style: TextStyle(color: color.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: Colors.black38, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHobbyIcon(IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.black38, size: 18),
    );
  }

  void _showMoreOptions(BuildContext context, UserModel userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            ListTile(
              leading: _isActionLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.block_rounded, color: Colors.black87),
              title: const Text("Block User", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: _isActionLoading ? null : () async {
                final confirm = await _showConfirm(context, "Block ${userData.username}?", "You will no longer see their messages or rooms.");
                if (confirm) {
                   setState(() => _isActionLoading = true);
                   try {
                     await ref.read(reportServiceProvider).blockUser(userData.uid);
                     _showCuteSnackBar("User ${userData.username} has been blocked.");
                     if (context.mounted) Navigator.pop(context);
                   } catch (e) {
                     _showCuteSnackBar("Failed to block: $e", isError: true);
                   } finally {
                     if (mounted) setState(() => _isActionLoading = false);
                   }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent),
              title: const Text("Report User", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context, userData);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, UserModel userData) {
    final reasons = ["Harassment", "Spam", "Nudity", "Hate Speech", "Fake Account"];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Report user", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Select a reason for reporting", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: reasons.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(reasons[i]),
                  trailing: _isActionLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right_rounded),
                  onTap: _isActionLoading ? null : () async {
                    setState(() => _isActionLoading = true);
                    try {
                      await ref.read(reportServiceProvider).submitReport(targetUid: userData.uid, reason: reasons[i]);
                      _showCuteSnackBar("Thanks for reporting! Our team will review this user.");
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      _showCuteSnackBar("Report failed: $e", isError: true);
                    } finally {
                      if (mounted) setState(() => _isActionLoading = false);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirm(BuildContext context, String title, String msg) async {
    return await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Confirm")),
        ],
      )
    ) ?? false;
  }

  Widget _buildProfileDetailShimmerLoading() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cover photo shimmer placeholder
            Container(
              width: double.infinity,
              height: 280,
              color: Colors.grey.shade200,
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const Gap(16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Display Name & Level Shield Shimmer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 160, height: 22, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                          const Gap(8),
                          Container(width: 110, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                        ],
                      ),
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                    ],
                  ),
                  const Gap(20),

                  // 3. Stats Row Shimmer
                  Row(
                    children: [
                      Container(width: 70, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                      const Gap(24),
                      Container(width: 70, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                      const Gap(24),
                      Container(width: 70, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                  const Gap(20),

                  // 4. Badge Chips Shimmer
                  Row(
                    children: List.generate(4, (index) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 76,
                      height: 26,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    )),
                  ),
                  const Gap(24),

                  // 5. Info Card Scrollable Shimmer
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
                  ),
                  const Gap(24),

                  // 6. Tabs Bar Shimmer
                  Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                  ),
                  const Gap(20),

                  // 7. Bio Lines Shimmer
                  Container(width: 220, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                  const Gap(8),
                  Container(width: 160, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white70),
    );
  }

}


// CUSTOM ROUNDED INDICATOR
class RoundUnderlineTabIndicator extends Decoration {
  final BorderSide borderSide;
  final double width;

  const RoundUnderlineTabIndicator({
    this.borderSide = const BorderSide(width: 4.0, color: Colors.black87),
    this.width = 24.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _RoundUnderlinePainter(this, onChanged);
  }
}

class _RoundUnderlinePainter extends BoxPainter {
  final RoundUnderlineTabIndicator decoration;

  _RoundUnderlinePainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final Paint paint = decoration.borderSide.toPaint()..strokeCap = StrokeCap.round;
    
    // Position it at the bottom middle of the label
    final double xPos = rect.left + (rect.width / 2);
    final double yPos = rect.bottom - (decoration.borderSide.width / 2);
    canvas.drawLine(
      Offset(xPos - (decoration.width / 2), yPos),
      Offset(xPos + (decoration.width / 2), yPos),
      paint,
    );
  }
}

class ProfileBottomBarWidget extends ConsumerStatefulWidget {
  final UserModel userData;
  const ProfileBottomBarWidget({super.key, required this.userData});

  @override
  ConsumerState<ProfileBottomBarWidget> createState() => _ProfileBottomBarWidgetState();
}

class _ProfileBottomBarWidgetState extends ConsumerState<ProfileBottomBarWidget> {
  bool _isActionLoading = false;
  bool _isSendingFriendReq = false;
  bool _isSendingCPReq = false;
  final Set<String> _sentFriendReqs = {};

  void _showCuteSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const Gap(12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendFriendRequest(String targetUid) async {
    setState(() => _isSendingFriendReq = true);
    try {
      await ref.read(relationshipServiceProvider).sendFriendRequest(targetUid);
      setState(() => _sentFriendReqs.add(targetUid));
      _showCuteSnackBar("Friend request sent! 💌");
    } catch (e) {
      _showCuteSnackBar("$e", isError: true);
    }
    if (mounted) setState(() => _isSendingFriendReq = false);
  }

  Future<void> _sendCPRequest(UserModel targetUser) async {
    final me = ref.read(currentUserProfileProvider).valueOrNull;
    if ((me?.partnerUid != null && me!.partnerUid!.isNotEmpty) ||
        (targetUser.partnerUid != null && targetUser.partnerUid!.isNotEmpty)) {
      _showCuteSnackBar("You or the recipient already have an active CP relationship.", isError: true);
      return;
    }

    setState(() => _isSendingCPReq = true);
    try {
      await ref.read(relationshipServiceProvider).sendCPInvite(targetUser.uid);
      _showCuteSnackBar("CP invite sent! 💕");
    } catch (e) {
      _showCuteSnackBar("$e", isError: true);
    }
    if (mounted) setState(() => _isSendingCPReq = false);
  }

  @override
  Widget build(BuildContext context) {
    final userData = widget.userData;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid == userData.uid) return const SizedBox.shrink();

    final followingAsync = ref.watch(followingStreamProvider(currentUid));
    final followersAsync = ref.watch(followersStreamProvider(currentUid));
    final currentUserAsync = ref.watch(currentUserProfileProvider);
    
    return followingAsync.when(
      data: (followingList) {
        final isFollowing = followingList.contains(userData.uid);
        final isFollower = followersAsync.value?.contains(userData.uid) ?? false;
        final isFriends = isFollowing && isFollower;
        final isPartner = currentUserAsync.valueOrNull?.partnerUid == userData.uid;
        final friendReqSent = _sentFriendReqs.contains(userData.uid);
        
        final buttonLabel = isFriends ? "Friends" : (isFollowing ? "Following" : "Follow");

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          ),
          child: Row(
            children: [
              // 1. Primary Action Button: Follow / Following / Friends
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: _isActionLoading ? null : () async {
                    setState(() => _isActionLoading = true);
                    try {
                      if (isFollowing) {
                        await ref.read(profileServiceProvider).unfollowUser(currentUid, userData.uid);
                        _showCuteSnackBar("Unfollowed ${userData.displayName} ✨");
                      } else {
                        await ref.read(profileServiceProvider).followUser(currentUid, userData.uid);
                        _showCuteSnackBar("Success! You are now following ${userData.displayName} 💖");
                      }
                    } catch (e) {
                      _showCuteSnackBar("Oops! $e", isError: true);
                    } finally {
                      if (mounted) setState(() => _isActionLoading = false);
                    }
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: (isFollowing || isFriends)
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: (isFollowing || isFriends) ? Colors.grey[100] : null,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: (isFollowing || isFriends)
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _isActionLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isFriends ? Icons.people_alt_rounded : (isFollowing ? Icons.check_circle_rounded : Icons.person_add_alt_1_rounded),
                                  color: (isFollowing || isFriends) ? Colors.black87 : Colors.white,
                                  size: 19,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  buttonLabel,
                                  style: TextStyle(
                                    color: (isFollowing || isFriends) ? Colors.black87 : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Direct Chat Button (Vibrant Indigo Disc)
              GestureDetector(
                onTap: () async {
                  try {
                    final chatService = ref.read(chatServiceProvider);
                    final chatId = await chatService.getOrCreateChat(currentUid, userData.uid);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => PrivateChatScreen(chatId: chatId, otherUid: userData.uid),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error opening chat: $e")));
                    }
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Friendship Request Button (Emerald Disc)
              GestureDetector(
                onTap: friendReqSent || _isSendingFriendReq ? null : () => _sendFriendRequest(userData.uid),
                child: Tooltip(
                  message: friendReqSent ? "Friendship Request Sent" : "Send Friend Request",
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: friendReqSent
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: friendReqSent ? Colors.amber.withOpacity(0.15) : null,
                      shape: BoxShape.circle,
                      boxShadow: friendReqSent
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                      border: friendReqSent ? Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5) : null,
                    ),
                    child: _isSendingFriendReq
                        ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : Icon(
                            friendReqSent ? Icons.hourglass_bottom_rounded : Icons.diversity_3_rounded,
                            color: friendReqSent ? Colors.amber[800] : Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 4. CP (Couple Partner) Request Button (Rose Gold Disc)
              GestureDetector(
                onTap: isPartner || _isSendingCPReq ? null : () => _sendCPRequest(userData),
                child: Tooltip(
                  message: isPartner ? "Active CP Partner ❤️" : "Send CP Invite 💕",
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isPartner
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isPartner ? Colors.pink.withOpacity(0.18) : null,
                      shape: BoxShape.circle,
                      boxShadow: isPartner
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFFEC4899).withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                      border: isPartner ? Border.all(color: Colors.pink.withOpacity(0.4), width: 1.5) : null,
                    ),
                    child: _isSendingCPReq
                        ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : Icon(
                            isPartner ? Icons.favorite_rounded : Icons.volunteer_activism_rounded,
                            color: isPartner ? Colors.pink[700] : Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
