import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/relationship_provider.dart';
import '../../../../core/constants/app_colors.dart';

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.value?.uid;
    if (uid == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Friend Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
      ),
      body: ref.watch(friendRequestProvider(uid)).when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_disabled, color: Colors.white24, size: 56),
                  Gap(16),
                  Text("No pending requests", style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) => _RequestTile(request: requests[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.diamond)),
        error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final Map<String, dynamic> request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderName = request['senderName'] as String? ?? 'Unknown';
    final senderAvatar = request['senderAvatar'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: senderAvatar.isNotEmpty
                ? CachedNetworkImageProvider(senderAvatar)
                : null,
            child: senderAvatar.isEmpty
                ? const Icon(Icons.person, color: Colors.white38)
                : null,
          ),
          const Gap(12),
          Expanded(
            child: Text(
              senderName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () async {
              try {
                await ref.read(relationshipServiceProvider).acceptFriendRequest(request['id']);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Friend request accepted!"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.diamond.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text("Accept", style: TextStyle(color: AppColors.diamond, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
          const Gap(8),
          GestureDetector(
            onTap: () async {
              try {
                await ref.read(relationshipServiceProvider).rejectFriendRequest(request['id']);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Request rejected"), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text("Decline", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
