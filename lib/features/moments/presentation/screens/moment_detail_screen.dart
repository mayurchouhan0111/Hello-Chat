import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/router/app_router.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text("Detail", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black54, size: 22), onPressed: () {}),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linear Header: User Info
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: profileAsync.when(
                          data: (user) => _buildCompactHeader(user as UserModel),
                          loading: () => const SizedBox(height: 50),
                          error: (_, __) => const SizedBox(),
                        ),
                      ),

                      // Caption
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(
                          media['caption'] ?? "",
                          style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w400),
                        ),
                      ),
                      
                      // Timestamp (compacted)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(
                          timeago.format(createdAt),
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ),

                      // Image (more compact padding)
                      if (media['imageUrl'] != null)
                        GestureDetector(
                          onTap: () => _showFullImage(context, media['imageUrl']),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: media['imageUrl'],
                                width: double.infinity,
                                height: 320,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.grey[50]),
                              ),
                            ),
                          ),
                        ),

                      // Interaction Stats Bar (Compact & Sleek)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildCompactStat(isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded, "${media['likesCount'] ?? 0}", isLiked ? Colors.redAccent : Colors.grey[400]!),
                            const SizedBox(width: 32),
                            _buildCompactStat(Icons.chat_bubble_outline_rounded, "${media['commentsCount'] ?? 0}", AppColors.cyanAccent, isActive: true),
                            const Spacer(),
                            _buildCompactStat(Icons.card_giftcard_rounded, "${media['giftCount'] ?? 0}", Colors.grey[400]!),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1, thickness: 0.3, color: Color(0xFFEEEEEE)),

                      // Comments List (Compact Rows)
                      commentsAsync.when(
                        data: (comments) => _buildCompactCommentsList(comments),
                        loading: () => const SizedBox(),
                        error: (err, __) => const SizedBox(),
                      ),
                    ],
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
        CircleAvatar(radius: 22, backgroundImage: CachedNetworkImageProvider(user.profilePhotoUrl)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(width: 6),
                  _buildCompactGenderBadge(user.gender),
                ],
              ),
            ],
          ),
        ),
        _buildCompactPlusButton(),
      ],
    );
  }

  Widget _buildCompactPlusButton() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cyanAccent, width: 1),
      ),
      child: const Icon(Icons.add, color: AppColors.cyanAccent, size: 16),
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

  Widget _buildCompactStat(IconData icon, String count, Color color, {bool isActive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 5),
            Text(count, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        if (isActive)
          Container(height: 2.5, width: 28, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))
        else
          const SizedBox(height: 2.5),
      ],
    );
  }

  Widget _buildCompactCommentsList(List<Map<String, dynamic>> comments) {
    if (comments.isEmpty) return const SizedBox();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        final profileAsync = ref.watch(userProfileProvider(comment['userId']));
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: profileAsync.when(
            data: (user) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 17, backgroundImage: CachedNetworkImageProvider((user as UserModel).profilePhotoUrl)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text((user).displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.primary)),
                          Text(
                            timeago.format((comment['createdAt'] as dynamic)?.toDate() ?? DateTime.now(), locale: 'en_short'),
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(comment['text'] ?? "", style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.25)),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        );
      },
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
          Icon(Icons.favorite_border_rounded, color: Colors.grey[350]!, size: 26),
          const SizedBox(width: 10),
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
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : _sendComment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6CF6F6), Color(0xFF4AC4FF)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: _isSending 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Send", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
           _buildCompactGiftIcon(),
        ],
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
        boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
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
