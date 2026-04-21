import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/router/app_router.dart';
import 'package:gap/gap.dart';
import 'package:like_button/like_button.dart';
import 'package:hello_chat/core/services/profile_service.dart';
import 'package:hello_chat/features/rooms/presentation/widgets/gift_panel.dart';

class MomentDetailScreen extends ConsumerStatefulWidget {
  final String ownerUid;
  final String mediaId;

  const MomentDetailScreen({
    super.key,
    required this.ownerUid,
    required this.mediaId,
  });

  @override
  ConsumerState<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends ConsumerState<MomentDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    setState(() => _isSending = true);
    try {
      await ref.read(profileServiceProvider).addComment(
        ownerUid: widget.ownerUid,
        mediaId: widget.mediaId,
        commenterUid: currentUser.uid,
        text: text,
        isMoment: true,
      );
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaId.isEmpty) return const Scaffold(body: Center(child: Text("Invalid Media ID")));

    final mediaAsync = ref.watch(mediaStreamProvider(widget.mediaId));
    final profileAsync = ref.watch(userProfileProvider(widget.ownerUid));
    final commentsAsync = ref.watch(commentsStreamProvider((ownerUid: widget.ownerUid, mediaId: widget.mediaId)));
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background, // Matches other refined screens
      appBar: AppBar(
        backgroundColor: Colors.transparent, // More premium feel
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Detail", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black54, size: 20), onPressed: () {}),
        ],
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (media) {
          if (media.isEmpty) return const Center(child: Text("Moment not found...", style: TextStyle(color: Colors.grey)));

          final createdAt = (media['createdAt'] as dynamic)?.toDate() ?? DateTime.now();
          final isLiked = currentUser != null 
            ? ref.watch(isMediaLikedProvider((ownerUid: widget.ownerUid, mediaId: widget.mediaId, likerUid: currentUser.uid))).value ?? false
            : false;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linear Header: User Info
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: profileAsync.when(
                            data: (user) => _buildCompactHeader(user as UserModel),
                            loading: () => const SizedBox(height: 40),
                            error: (_, __) => const SizedBox(),
                          ),
                        ),

                        // Caption
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(
                            media['caption'] ?? "",
                            style: const TextStyle(fontSize: 13.5, height: 1.3, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w400),
                          ),
                        ),
                        
                        // Timestamp (compacted)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          child: Text(
                            timeago.format(createdAt),
                            style: TextStyle(color: Colors.grey[400], fontSize: 9.5),
                          ),
                        ),

                        // Image (more compact padding)
                        if (media['imageUrl'] != null)
                          GestureDetector(
                            onTap: () => _showFullImage(context, media['imageUrl']),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: media['imageUrl'],
                                  width: double.infinity,
                                  height: 280, // Reduced from 320
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                                ),
                              ),
                            ),
                          ),

                        // Interaction Stats Bar (Compact & Sleek)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              LikeButton(
                                size: 18,
                                isLiked: isLiked,
                                likeCount: media['likesCount'] ?? 0,
                                countPostion: CountPostion.right,
                                likeBuilder: (bool isLiked) {
                                  return Icon(
                                    isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                    color: isLiked ? Colors.redAccent : Colors.grey[300],
                                    size: 18,
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
                                    ownerUid: widget.ownerUid, 
                                    mediaId: widget.mediaId, 
                                    likerUid: currentUser.uid, 
                                    isMoment: true,
                                  );
                                  return !isLiked;
                                },
                              ),
                              const Gap(24),
                              _buildCompactStat(Icons.chat_bubble_outline_rounded, "${media['commentsCount'] ?? 0}", Colors.grey[300]!),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _showGiftPanel(),
                                child: _buildCompactStat(Icons.card_giftcard_rounded, "${media['giftCount'] ?? 0}", Colors.grey[300]!),
                              ),
                            ],
                          ),
                        ),
                        
                        const Divider(height: 1, thickness: 0.3, color: Color(0xFFEEEEEE)),

                        // Comments List (Compact Rows)
                        commentsAsync.when(
                          data: (comments) {
                            if (comments.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: Text("No comments yet", style: TextStyle(color: Colors.grey, fontSize: 13))),
                              );
                            }
                            return _buildCompactCommentsList(comments);
                          },
                          loading: () => const Center(child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )),
                          error: (err, __) => Center(child: Text("Error loading comments: $err", style: const TextStyle(fontSize: 10))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Input Bar (Refined & Compact)
              _buildCompactInputBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactHeader(UserModel user) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.push(AppRoutes.userProfile, extra: user.uid),
          child: CircleAvatar(radius: 18, backgroundImage: CachedNetworkImageProvider(user.profilePhotoUrl)),
        ),
        const Gap(8),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.userProfile, extra: user.uid),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    const Gap(6),
                    _buildCompactGenderBadge(user.gender),
                  ],
                ),
              ],
            ),
          ),
        ),
        _buildCompactPlusButton(user.uid),
      ],
    );
  }

  Widget _buildCompactPlusButton(String targetUid) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.userProfile, extra: targetUid),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: AppColors.cyanAccent, size: 14),
      ),
    );
  }

  Widget _buildCompactGenderBadge(String gender) {
    final isFemale = gender.toLowerCase() == 'female';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isFemale ? const Color(0xFFFF69B4).withOpacity(0.9) : Colors.blue.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isFemale ? Icons.female : Icons.male, color: Colors.white, size: 9),
          const SizedBox(width: 2),
          const Text("1", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const Gap(5),
        Text(count, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildCompactCommentsList(List<Map<String, dynamic>> comments) {
    return Column(
      children: comments.map((comment) => _buildCommentItem(comment)).toList(),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final profileAsync = ref.watch(userProfileProvider(comment['userId']));
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: profileAsync.when(
        data: (user) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 15, backgroundImage: CachedNetworkImageProvider((user as UserModel).profilePhotoUrl)),
            const Gap(8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text((user).displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.primary)),
                      Text(
                        timeago.format((comment['createdAt'] as dynamic)?.toDate() ?? DateTime.now(), locale: 'en_short'),
                        style: TextStyle(color: Colors.grey[400], fontSize: 9),
                      ),
                    ],
                  ),
                  const Gap(2),
                  Text(comment['text'] ?? "", style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.2)),
                ],
              ),
            ),
          ],
        ),
        loading: () => Row(
          children: [
            CircleAvatar(radius: 15, backgroundColor: Colors.grey[100]),
            const Gap(8),
            Container(width: 100, height: 10, color: Colors.grey[100]),
          ],
        ),
        error: (_, __) => const Text("Unknown User", style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildCompactInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_border_rounded, color: Colors.grey[350]!, size: 22),
          const Gap(10),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _commentController,
                style: const TextStyle(fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: "Say something...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const Gap(10),
          GestureDetector(
            onTap: _isSending ? null : _sendComment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6CF6F6), Color(0xFF4AC4FF)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isSending 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Send", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const Gap(8),
           GestureDetector(
             onTap: () => _showGiftPanel(),
             child: _buildCompactGiftIcon(),
           ),
        ],
      ),
    );
  }

  void _showGiftPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftPanel(
        roomId: widget.mediaId, // Context identifier
        targetUid: widget.ownerUid, // Post owner receives the gift
        isMoment: true,
      ),
    );
  }
  
  Widget _buildCompactGiftIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFF6CF6F6), Color(0xFF4AC4FF)]),
        boxShadow: const [], // No shadow
      ),
      child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2.seconds);
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
}
