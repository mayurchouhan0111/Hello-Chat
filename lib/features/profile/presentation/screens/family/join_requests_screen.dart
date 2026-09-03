import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/family_join_request_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/constants/family_light_theme.dart';
import 'package:go_router/go_router.dart';

class JoinRequestsScreen extends ConsumerWidget {
  final String familyId;
  const JoinRequestsScreen({super.key, required this.familyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider(familyId));

    return Scaffold(
      backgroundColor: FamilyLight.pageBg,
      appBar: AppBar(
        backgroundColor: FamilyLight.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: FamilyLight.fill,
              shape: BoxShape.circle,
              border: Border.all(color: FamilyLight.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: FamilyLight.ink, size: 16),
          ),
        ),
        title: const Text('Join Requests',
            style: TextStyle(
                color: FamilyLight.ink, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
                child: Text('No pending requests',
                    style: TextStyle(color: FamilyLight.muted)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Gap(12),
            itemBuilder: (context, index) => _RequestTile(request: requests[index]),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: FamilyLight.gold)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: FamilyLight.red))),
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
      decoration: FamilyLight.cardDeco(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: request.userAvatar.isNotEmpty ? CachedNetworkImageProvider(request.userAvatar) : null,
            child: request.userAvatar.isEmpty
                ? const Icon(Icons.person, color: FamilyLight.faint)
                : null,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.userName,
                  style: const TextStyle(color: FamilyLight.ink, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(request.userId,
                  style: const TextStyle(color: FamilyLight.faint, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Text(DateFormat('MMM dd, yyyy').format(request.createdAt),
                  style: const TextStyle(color: FamilyLight.muted, fontSize: 11),
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
                    icon: const Icon(Icons.close, size: 20, color: FamilyLight.red),
                    style: IconButton.styleFrom(
                      backgroundColor: FamilyLight.redSoft,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(8),
                    ),
                    tooltip: 'Reject',
                  ),
                  const Gap(8),
                  IconButton(
                    onPressed: () => ref.read(familyServiceProvider).approveRequest(request),
                    icon: const Icon(Icons.check, size: 20, color: FamilyLight.green),
                    style: IconButton.styleFrom(
                      backgroundColor: FamilyLight.greenSoft,
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
