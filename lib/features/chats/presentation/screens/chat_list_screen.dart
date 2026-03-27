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
import 'private_chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListStreamProvider);
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("CHATS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: chatsAsync.when(
        data: (chats) {
          if (chats.isEmpty) return _buildEmptyState();

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey[200]),
          const Gap(16),
          Text("No messages yet", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          const Gap(24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Start Chatting"),
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

    return ListTile(
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: profileAsync.when(
        data: (user) => CircleAvatar(
          radius: 28,
          backgroundImage: (user as UserModel).profilePhotoUrl.isNotEmpty 
            ? CachedNetworkImageProvider(user.profilePhotoUrl) 
            : null,
          child: user.profilePhotoUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        loading: () => const CircleAvatar(radius: 28, backgroundColor: Color(0xFFEEEEEE)),
        error: (_, __) => const CircleAvatar(radius: 28, child: Icon(Icons.person)),
      ),
      title: profileAsync.when(
        data: (user) => Text(
          (user as UserModel).displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        loading: () => Container(width: 100, height: 14, color: Colors.grey[100]),
        error: (_, __) => const Text("Unknown User"),
      ),
      subtitle: Text(
        chat['lastMessage'] ?? "New chat started",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unreadCount > 0 ? Colors.black87 : Colors.grey,
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeago.format(lastTime), style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          const Gap(4),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              child: Text("$unreadCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
