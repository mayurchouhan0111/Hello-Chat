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

import '../../../../core/providers/moment_filter_provider.dart';

class SquareScreen extends ConsumerStatefulWidget {
  const SquareScreen({super.key});

  @override
  ConsumerState<SquareScreen> createState() => _SquareScreenState();
}

class _SquareScreenState extends ConsumerState<SquareScreen> {
  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(momentFilterProvider);
    final momentsAsync = ref.watch(filteredMomentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            _buildTabItem("Square", MomentFilter.square, activeFilter == MomentFilter.square),
            const SizedBox(width: 20),
            _buildTabItem("Follow", MomentFilter.following, activeFilter == MomentFilter.following),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black, size: 28),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.black, size: 32),
            onPressed: () => context.push(AppRoutes.addMoment),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: momentsAsync.when(
        skipLoadingOnRefresh: true, // This helps preserve state
        loading: () => momentsAsync.hasValue 
          ? _buildMomentList(momentsAsync.value!, activeFilter)
          : const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (moments) => _buildMomentList(moments, activeFilter),
      ),
    );
  }

  Widget _buildMomentList(List<Map<String, dynamic>> moments, MomentFilter filter) {
    if (moments.isEmpty) {
      return _buildEmptyState(filter);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: moments.length,
      itemBuilder: (context, index) {
        return _buildMomentCard(moments[index]);
      },
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
        margin: const EdgeInsets.only(bottom: 12), // Reduced from 20
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // More "cute"
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), // Tightened
              child: Row(
                children: [
                  profileAsync.when(
                    data: (user) {
                      final profileUrl = (user as UserModel).profilePhotoUrl;
                      return CircleAvatar(
                        radius: 18,
                        backgroundImage: profileUrl.isNotEmpty 
                          ? CachedNetworkImageProvider(profileUrl) 
                          : null,
                        child: profileUrl.isEmpty ? const Icon(Icons.person, size: 18) : null,
                      );
                    },
                    loading: () => const CircleAvatar(radius: 18, backgroundColor: Color(0xFFEEEEEE)),
                    error: (_, __) => const CircleAvatar(radius: 18, child: Icon(Icons.person)),
                  ),
                  const SizedBox(width: 10), // Reduced from 12
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        profileAsync.when(
                          data: (user) => Text(
                            (user as UserModel).displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), // Muted
                          ),
                          loading: () => Container(width: 60, height: 10, color: const Color(0xFFEEEEEE)),
                          error: (_, __) => const Text("User"),
                        ),
                        Text(
                          timeago.format(createdAt),
                          style: TextStyle(color: Colors.grey[400], fontSize: 11), // Scaled
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz, color: Colors.black12, size: 20),
                ],
              ),
            ),

            // Caption
            if (moment['caption'] != null && moment['caption'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  moment['caption'],
                  style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
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
                      height: 300,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[100]),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
              ),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), // Reduced
              child: Row(
                children: [
                  _buildAction(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                    "${moment['likesCount'] ?? 0}", 
                    isLiked ? Colors.redAccent : Colors.grey[300]!,
                    isActive: isLiked,
                    onTap: () {
                      if (currentUser == null) return;
                      ref.read(profileServiceProvider).toggleLike(
                        ownerUid: moment['userId'], 
                        mediaId: moment['mediaId'], 
                        likerUid: currentUser.uid, 
                        isMoment: true,
                      );
                    },
                  ),
                  const SizedBox(width: 16), // Reduced from 24
                  _buildAction(
                    Icons.chat_bubble_outline_rounded, 
                    "${moment['commentsCount'] ?? 0}", 
                    Colors.grey[200]!, // Subtler
                    onTap: () => context.push(
                      AppRoutes.momentDetail,
                      extra: {
                        'ownerUid': moment['userId'],
                        'mediaId': moment['mediaId'],
                      },
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 20).animate().scale(delay: 1.seconds, duration: 2.seconds).fadeIn(),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildAction(IconData icon, String count, Color iconColor, {required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22)
            .animate(target: isActive ? 1 : 0)
            .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: 200.ms, curve: Curves.elasticOut)
            .then()
            .scale(begin: const Offset(1.3, 1.3), end: const Offset(1, 1), duration: 200.ms),
          const SizedBox(width: 6),
          Text(count, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
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
          Row(
            children: [
              if (isActive && filter == MomentFilter.following) ...[
                 const Icon(Icons.insights_rounded, color: AppColors.cyanAccent, size: 16).animate(onPlay: (controller) => controller.repeat()).shake(),
                 const SizedBox(width: 4),
              ],
              Text(label, style: TextStyle(color: isActive ? Colors.black : Colors.grey[400], fontSize: isActive ? 18 : 15, fontWeight: isActive ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
