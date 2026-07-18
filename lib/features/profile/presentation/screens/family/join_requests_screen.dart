import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/family_join_request_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';

class JoinRequestsScreen extends ConsumerWidget {
  final String familyId;
  const JoinRequestsScreen({super.key, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider(familyId));

    return Scaffold(
      backgroundColor: AppColors.familyBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.familyText, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Join Requests', style: TextStyle(color: AppColors.familyText, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests', style: TextStyle(color: AppColors.familyTextSecondary)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Gap(12),
            itemBuilder: (context, index) => _RequestTile(request: requests[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.familyGold)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.familyRed))),
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
        color: AppColors.familySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: request.userAvatar.isNotEmpty ? CachedNetworkImageProvider(request.userAvatar) : null,
            child: request.userAvatar.isEmpty ? const Icon(Icons.person, color: AppColors.familyTextSecondary) : null,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.userName,
                  style: const TextStyle(color: AppColors.familyText, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(request.userId,
                  style: TextStyle(color: AppColors.familyTextSecondary.withOpacity(0.5), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Text(DateFormat('MMM dd, yyyy').format(request.createdAt),
                  style: const TextStyle(color: AppColors.familyTextSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Gap(8),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => ref.read(familyServiceProvider).rejectRequest(request.id),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.familyRed),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.familyRed.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(8),
                    ),
                    tooltip: 'Reject',
                  ),
                  const Gap(8),
                  IconButton(
                    onPressed: () => ref.read(familyServiceProvider).approveRequest(request),
                    icon: const Icon(Icons.check, size: 20, color: AppColors.success),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.success.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(8),
                    ),
                    tooltip: 'Accept',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
