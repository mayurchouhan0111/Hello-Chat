import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/router/app_router.dart';
import 'package:flutter/services.dart';
import 'package:like_button/like_button.dart';
import 'package:hello_chat/core/services/profile_service.dart';

import '../../../../core/providers/moment_filter_provider.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/gift_panel.dart';
import 'package:gap/gap.dart';

class SquareScreen extends ConsumerStatefulWidget {
  const SquareScreen({super.key});

  @override
  ConsumerState<SquareScreen> createState() => _SquareScreenState();
}

class _SquareScreenState extends ConsumerState<SquareScreen> {
  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(momentFilterProvider);
    final momentsAsync = ref.watch(
      activeFilter == MomentFilter.square 
        ? momentsStreamProvider 
        : followingMomentsProvider
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            _buildTabItem("Square", MomentFilter.square, activeFilter == MomentFilter.square),
            Gap(16),
            _buildTabItem("Follow", MomentFilter.following, activeFilter == MomentFilter.following),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black, size: 28),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.black, size: 28), // Compacted
            onPressed: () => context.push(AppRoutes.addMoment),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: momentsAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => momentsAsync.hasValue 
          ? _buildCombinedList(momentsAsync.value!, activeFilter)
          : _buildSquareShimmerLoading(),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (moments) => _buildCombinedList(moments, activeFilter),
      ),
    );
  }

  Widget _buildCombinedList(List<Map<String, dynamic>> moments, MomentFilter filter) {
    return CustomScrollView(
      slivers: [
        if (moments.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(filter))
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildMomentCard(moments[index]).animate().fadeIn(
                    duration: 400.ms, 
                    delay: (index * 100).clamp(0, 1000).ms
                  ).moveY(begin: 20, end: 0, curve: Curves.easeOutBack);
                },
                childCount: moments.length,
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildMomentCard(Map<String, dynamic> moment) {
    final userId = moment['userId'] as String;
    final profileAsync = ref.watch(userProfileProvider(userId));
    final createdAt = (moment['createdAt'] as dynamic)?.toDate() ?? DateTime.now();
    final currentUser = ref.watch(authStateProvider).value;
    
    final isLiked = currentUser != null 
      ? ref.watch(isMediaLikedProvider((ownerUid: userId, mediaId: moment['mediaId'], likerUid: currentUser.uid))).value ?? false
      : false;

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.momentDetail,
        extra: {
          'ownerUid': moment['userId'],
          'mediaId': moment['mediaId'],
        },
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), // Compacted from 12
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // Balanced cute
          boxShadow: const [], // Flat design
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6), // Compacted
              child: Row(
                children: [
                  profileAsync.when(
                    data: (user) {
                      final profileUrl = (user as UserModel).profilePhotoUrl;
                      return GestureDetector(
                        onTap: () => context.push(AppRoutes.userProfile, extra: user.uid),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundImage: profileUrl.isNotEmpty 
                            ? CachedNetworkImageProvider(profileUrl) 
                            : null,
                          child: profileUrl.isEmpty ? const Icon(Icons.person, size: 18) : null,
                        ),
                      );
                    },
                    loading: () => const CircleAvatar(radius: 16, backgroundColor: Color(0xFFEEEEEE)), // Compacted
                    error: (_, __) => const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
                  ),
                  Gap(8), // Reduced from 12
                  Expanded(
                    child: GestureDetector(
                      onTap: () => profileAsync.whenData((user) => context.push(AppRoutes.userProfile, extra: (user as UserModel).uid)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          profileAsync.when(
                            data: (user) => Text(
                              (user as UserModel).displayName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), // Reduced from 14
                            ).animate().fadeIn(),
                            loading: () => Container(width: 50, height: 8, color: const Color(0xFFEEEEEE)),
                            error: (_, __) => const Text("User"),
                          ),
                          Text(
                            timeago.format(createdAt),
                            style: TextStyle(color: Colors.grey[400], fontSize: 9.5), // Reduced from 11
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Icon(Icons.more_horiz, color: Colors.black12, size: 18),
                ],
              ),
            ),

            // Caption
            if (moment['caption'] != null && moment['caption'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  moment['caption'],
                  style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.3),
                ),
              ),

            // Image
            if (moment['imageUrl'] != null && (moment['imageUrl'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GestureDetector(
                  onTap: () => _showFullImage(context, moment['imageUrl']),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: moment['imageUrl'],
                      width: double.infinity,
                      height: 260, // Compacted from 300
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[100]),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
              ),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), // Compacted
              child: Row(
                children: [
                  LikeButton(
                    size: 20,
                    isLiked: isLiked,
                    likeCount: moment['likesCount'] ?? 0,
                    countPostion: CountPostion.right,
                    likeBuilder: (bool isLiked) {
                      return Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        color: isLiked ? Colors.redAccent : Colors.grey[300],
                        size: 20,
                      );
                    },
                    countBuilder: (int? count, bool isLiked, String text) {
                      return Text(
                        text,
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                    onTap: (isLiked) async {
                      HapticFeedback.mediumImpact();
                      if (currentUser == null) return !isLiked;
                      ref.read(profileServiceProvider).toggleLike(
                        ownerUid: moment['userId'], 
                        mediaId: moment['mediaId'], 
                        likerUid: currentUser.uid, 
                        isMoment: true,
                      );
                      return !isLiked;
                    },
                  ),
                  Gap(16),
                  _buildAction(
                    Icons.chat_bubble_outline_rounded, 
                    "${moment['commentsCount'] ?? 0}", 
                    Colors.grey[200]!,
                    onTap: () => context.push(
                      AppRoutes.momentDetail,
                      extra: {
                        'ownerUid': moment['userId'],
                        'mediaId': moment['mediaId'],
                      },
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showGiftPanel(moment['mediaId'], moment['userId']),
                    child: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 18)
                      .animate()
                      .scale(delay: 1.seconds, duration: 2.seconds)
                      .fadeIn(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftPanel(String mediaId, String ownerUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftPanel(
        roomId: mediaId,
        targetUid: ownerUid,
        isMoment: true,
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: const Text("1/1", style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String count, Color iconColor, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          Gap(6),
          Text(count, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(MomentFilter filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.auto_awesome_motion_rounded, size: 80, color: AppColors.primary.withOpacity(0.1)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            filter == MomentFilter.following 
              ? "No moments from people you follow"
              : "No moments yet",
            style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, MomentFilter filter, bool isActive) {
    return GestureDetector(
      onTap: () => ref.read(momentFilterProvider.notifier).state = filter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.grey[400],
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  Widget _buildSquareShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                ),
                const Gap(10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 100, height: 12, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                    const Gap(6),
                    Container(width: 60, height: 8, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ],
            ),
            const Gap(14),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white70),
    );
  }
}
