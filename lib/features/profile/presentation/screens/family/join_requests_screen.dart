import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/family_join_request_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:go_router/go_router.dart';

class JoinRequestsScreen extends ConsumerWidget {
  final String familyId;
  const JoinRequestsScreen({super.key, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider(familyId));

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Join Requests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests', style: TextStyle(color: Colors.white38)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Gap(12),
            itemBuilder: (context, index) => _RequestTile(request: requests[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFACC15))),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final FamilyJoinRequestModel request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: request.userAvatar.isNotEmpty ? CachedNetworkImageProvider(request.userAvatar) : null,
            child: request.userAvatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Gap(4),
                Text('Requested for join', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                onPressed: () => ref.read(familyServiceProvider).rejectRequest(request.id),
              ),
              const Gap(8),
              ElevatedButton(
                onPressed: () => ref.read(familyServiceProvider).approveRequest(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
