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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(16),
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (userData) {
        if (userData == null) return const Scaffold(body: Center(child: Text("User not found")));
        
        // Dynamic Visit Tracking (Run once per screen view)
        if (!_hasRecordedVisit) {
          Future.microtask(() async {
            final me = ref.read(currentUserProfileProvider).value;
            if (me != null && me.uid != userData.uid) {
              setState(() => _hasRecordedVisit = true);
              await ref.read(profileServiceProvider).recordProfileVisit(userData.uid, me.profilePhotoUrl);
            }
          });
        }
        
        return Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: _buildBottomBar(context, userData),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Photo with Overlay Actions
                _buildCoverPhoto(context, userData),

                const SizedBox(height: 12),

                // 2. Identity & Badges Row (Optimized for right-side empty space)
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
                            _buildIdentity(context, userData),
                            const SizedBox(height: 12),
                            _buildStats(context, userData),
                          ],
                        ),
                      ),
                      
                      // Right Side: Premium Badges & Level Shield
                      _buildRightSideBadges(userData),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Badge/Achievement Chips (Restored)
                _buildBadgeChips(context, userData),

                const SizedBox(height: 12),

                // 4. Info Cards Horizontal Scroll (Family, Battle, Agency, Contribution)
                _buildInfoCardsScrollable(context, userData),

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
                      _buildTabs(context),
                      _buildTabContent(context, userData),
                    ],
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, UserModel userData) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid == userData.uid) return const SizedBox.shrink();

    final followingAsync = ref.watch(followingStreamProvider(currentUid));
    final followersAsync = ref.watch(followersStreamProvider(currentUid));
    
    return followingAsync.when(
      data: (followingList) {
        final isFollowing = followingList.contains(userData.uid);
        final isFollower = followersAsync.value?.contains(userData.uid) ?? false;
        final isFriends = isFollowing && isFollower;
        
        final buttonLabel = isFriends ? "Friends" : (isFollowing ? "Following" : "Follow");
        final bgColor = (isFollowing || isFriends) ? Colors.grey[200] : AppColors.primary;
        final fgColor = (isFollowing || isFriends) ? Colors.black87 : Colors.white;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isActionLoading ? null : () async {
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bgColor,
                    foregroundColor: fgColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: (isFollowing || isFriends) ? 0 : 2,
                  ),
                  child: _isActionLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      final chatService = ref.read(chatServiceProvider);
                      final chatId = await chatService.getOrCreateChat(currentUid, userData.uid);
                      if (context.mounted) {
                         Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (c) => PrivateChatScreen(chatId: chatId, otherUid: userData.uid)
                          )
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error opening chat: $e")));
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
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

  Widget _buildCoverPhoto(BuildContext context, UserModel userData) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: screenHeight * 0.40, // Reduced from 0.45
          child: Stack(
            alignment: Alignment.center,
            children: [
              AppAvatar(
                imageUrl: userData.profilePhotoUrl,
                radius: 50,
                vipTier: userData.vipTier,
                frameUrl: userData.profileFrame,
                frameMultiplier: 2.0,
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
          bottom: 16,
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

  Widget _buildIdentity(BuildContext context, UserModel userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("🌹 ", style: TextStyle(fontSize: 16)),
              Text(userData.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text(" 🔥", style: TextStyle(fontSize: 16)),
              const Gap(6),
              Icon(
                userData.gender.toLowerCase() == 'male' ? Icons.male_rounded : Icons.female_rounded,
                color: userData.gender.toLowerCase() == 'male' ? Colors.blue : Colors.pink,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "ID: ${userData.displayId}", 
                        style: const TextStyle(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w900)
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, color: Colors.black38, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),
          Row(
            children: [
              Text(userData.country.isEmpty ? 'India' : userData.country, style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w500)),
              const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 14),
            ],
          ),
        ],
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
                  ? CachedNetworkImage(
                      imageUrl: iconUrl, 
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Icon(icon, color: color, size: 16),
                      errorWidget: (_, __, ___) => Icon(icon, color: color, size: 16),
                    )
                  : Icon(icon, color: color, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, UserModel userData) {
    return IntrinsicHeight(
        child: Row(
          children: [
            _buildStatClickableItem(
              context, userData.followerCount, "Fans", 
              onTap: () => context.push(AppRoutes.followList, extra: {'type': 'Followers', 'targetUid': userData.uid})
            ),
            const VerticalDivider(color: Colors.black12, thickness: 1, indent: 4, endIndent: 4, width: 20),
            _buildStatClickableItem(
              context, userData.followingCount, "Following",
              onTap: () => context.push(AppRoutes.followList, extra: {'type': 'Following', 'targetUid': userData.uid})
            ),
            const VerticalDivider(color: Colors.black12, thickness: 1, indent: 4, endIndent: 4, width: 20),
            // _buildStatClickableItem(context, userData.beansBalance, "Beans"),
            // const VerticalDivider(color: Colors.black12, thickness: 1, indent: 4, endIndent: 4, width: 20),
            // _buildStatClickableItem(context, userData.diamondBalance, "Diamonds"),
          ],
        ),
    );
  }

  Widget _buildStatClickableItem(BuildContext context, num count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatCount(count), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBadgeChips(BuildContext context, UserModel userData) {
    final rawBadges = getBadgesForUser(userData);
    if (rawBadges.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate width for 4 items: (Width - Padding - Spacings) / 4
    final itemWidth = (screenWidth - 32 - 12) / 4; 

    final badges = rawBadges.map((b) {
       return SizedBox(
         width: itemWidth,
         child: b is UserBadge ? UserBadge(
           label: b.label,
           type: b.type,
           prefix: b.prefix,
           icon: b.icon,
           imageAsset: b.imageAsset,
           margin: EdgeInsets.zero,
         ) : b,
       );
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 4,
        runSpacing: 8,
        children: badges,
      ),
    );
  }

  Widget _buildRightSideBadges(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Large Level Shield only
        _buildLevelShield(user),
      ],
    );
  }

  Widget _buildLevelShield(UserModel user) {
    int level = user.level;
    int index = LevelUtils.getLevelBadgeIndex(level);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.levelDetail),
      child: Container(
        height: 70, // Prominent sizing
        width: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              "assets/images/levels/level_badge_$index.png", 
              fit: BoxFit.contain,
            ),
            Positioned(
              bottom: 16,
              child: Text(
                "Lv.$level",
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 10, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                    Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, -1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildChipIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 14),
    );
  }

  Widget _buildLevelTag(int level) {
    final color = LevelUtils.getLevelColor(level);
    int index = LevelUtils.getLevelBadgeIndex(level);
    final assetPath = "assets/images/levels/level_badge_$index.png";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          // Inner Glow effect
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 2,
            spreadRadius: -1,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(assetPath, width: 16, height: 16, fit: BoxFit.contain),
              const Gap(4),
              Text(
                "Lv.$level",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCardsScrollable(BuildContext context, UserModel userData) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Battle Card
          SizedBox(
            width: 160,
            child: _buildBattleCard(userData),
          ),
          const SizedBox(width: 8),

          // 2. Contribution Card (Top List)
          SizedBox(
            width: 160,
            child: _buildContributionCard(userData),
          ),
        ],
      ),
    );
  }

  // ... (Other methods) ...

  Widget _buildContributionCard(UserModel userData) {
    debugPrint("Building contribution card for: ${userData.uid}");
    final contributorsAsync = ref.watch(topContributorsProvider(userData.uid));
    
    return contributorsAsync.when(
      data: (contributors) {
        return GestureDetector(
          onTap: () => context.push(AppRoutes.leaderboard),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                if (contributors.isEmpty)
                   Container(
                     padding: const EdgeInsets.all(4),
                     decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle),
                     child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                   )
                else
                  SizedBox(
                    height: 24,
                    width: 40,
                    child: Stack(
                      children: List.generate(contributors.length.clamp(0, 3), (index) {
                        final c = contributors[index];
                        final avatar = c['photoUrl'] ?? c['avatarUrl'] ?? "";
                        return Positioned(
                          left: index * 10.0,
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                            child: CircleAvatar(
                              radius: 11, 
                              backgroundColor: Colors.grey[100],
                              backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                              child: avatar.isEmpty ? const Icon(Icons.person, size: 10, color: Colors.grey) : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text("Top List", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black87), overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 14),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.05))),
        child: const Row(children: [SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text("Loading...", style: TextStyle(fontSize: 10))]),
      ),
      error: (e, s) {
        debugPrint("Error loading contributors: $e");
        return const SizedBox.shrink();
      },
    );
  }


  Widget _buildFamilyCard(BuildContext context, String? logoUrl, String title, String sub, bool isClickable) {
    return GestureDetector(
      onTap: isClickable ? () => context.push(AppRoutes.familyPortal) : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            if (logoUrl != null)
              ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: logoUrl, width: 32, height: 32))
            else
              Container(
                padding: const EdgeInsets.all(6), 
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), 
                child: const Icon(Icons.groups_rounded, color: Colors.blue, size: 20)
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(sub, style: const TextStyle(color: Colors.black45, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isClickable) const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleCard(UserModel userData) {
    final hasFamily = userData.familyId != null;
    
    return GestureDetector(
      onTap: () => context.push(hasFamily ? AppRoutes.familyList : AppRoutes.familyPortal),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasFamily ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasFamily ? Colors.red.withOpacity(0.1) : Colors.black.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6), 
              decoration: BoxDecoration(
                color: hasFamily ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(6)
              ), 
              child: Icon(
                hasFamily ? Icons.local_fire_department_rounded : Icons.bolt_rounded, 
                color: hasFamily ? Colors.red : Colors.grey, 
                size: 20
              )
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("FAMILY BATTLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Text(
                    hasFamily ? "Ranked: #12" : "Join to compete", 
                    style: TextStyle(color: hasFamily ? Colors.redAccent : Colors.black45, fontSize: 9, fontWeight: hasFamily ? FontWeight.bold : FontWeight.normal)
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds).shake(hz: 1, curve: Curves.easeInOut),
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
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds),
          
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
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds)
              else
                const Text("STAP ON DINO TO INTERACT", style: TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(begin: 0, end: -0.05, duration: 2.seconds, curve: Curves.easeInOut),
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
