import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/router/app_router.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'private_chat_screen.dart';
import '../../../../core/widgets/app_avatar.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListStreamProvider);
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: AppColors.background, // Matches Home/Party screen background
      appBar: AppBar(
        backgroundColor: Colors.transparent, // More premium feel
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text("Chats", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Colors.black, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: chatsAsync.when(
        data: (chats) {
          if (chats.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Standardized padding
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Gap(8), // Spacing instead of divider
            itemBuilder: (context, index) {
              final chat = chats[index];
              final participants = chat['participants'] as List<dynamic>;
              final otherUid = participants.firstWhere((id) => id != currentUid);
              
              return _ChatListItem(
                chat: chat,
                otherUid: otherUid,
                currentUid: currentUid!,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const Gap(24),
          const Text(
            "No messages yet",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Gap(8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Start a conversation with your friends. Your chat history will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Gap(32),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero, // No padding to the button
              minimumSize: const Size(160, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              "Start Chatting",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends ConsumerWidget {
  final Map<String, dynamic> chat;
  final String otherUid;
  final String currentUid;

  const _ChatListItem({
    required this.chat,
    required this.otherUid,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(otherUid));
    final unreadCount = (chat['unreadCounts'] as Map<String, dynamic>?)?[currentUid] ?? 0;
    final lastTime = (chat['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now();

    return InkWell(
      onTap: () {
        ref.read(chatServiceProvider).markAsRead(chat['chatId'], currentUid);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrivateChatScreen(
              chatId: chat['chatId'],
              otherUid: otherUid,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // 1. Avatar
            profileAsync.when(
              data: (user) => AppAvatar(
                imageUrl: user?.profilePhotoUrl ?? '',
                radius: 24,
                vipTier: user?.vipTier,
                frameUrl: user?.profileFrame,
                userLevel: user?.level,
                tags: user?.tags,
              ),
              loading: () => CircleAvatar(radius: 24, backgroundColor: Colors.grey[100]),
              error: (_, __) => const CircleAvatar(radius: 24, child: Icon(Icons.person)),
            ),
            const Gap(14),
            // 2. Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  profileAsync.when(
                    data: (user) => Text(
                      user?.displayName ?? "Hello Chat User",
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    loading: () => Container(width: 80, height: 14, color: Colors.grey[100]),
                    error: (_, __) => const Text("Unknown User", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Gap(4),
                  Text(
                    chat['lastMessage'] ?? "New chat started",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unreadCount > 0 ? Colors.black87 : Colors.grey[500],
                      fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
            // 3. Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeago.format(lastTime, locale: 'en_short'), 
                  style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w500)
                ),
                const Gap(6),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$unreadCount", 
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)
                    ),
                  )
                else
                  const SizedBox(height: 16), // Placeholder to keep height stable
              ],
            ),
          ],
        ),
      ),
    );
  }
}
