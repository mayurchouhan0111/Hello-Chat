import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/report_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FollowListScreen extends ConsumerWidget {
  final String type; // "Followers", "Following", or "Blocked"
  final String? targetUid; 
  
  const FollowListScreen({super.key, required this.type, this.targetUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAuthUser = ref.watch(authStateProvider).value;
    final effectiveUid = targetUid ?? currentAuthUser?.uid;

    if (effectiveUid == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    // Stream the list of UIDs
    late final AsyncValue<List<String>> uidsAsync;
    
    if (type == "Blocked") {
      final profile = ref.watch(currentUserProfileProvider);
      uidsAsync = profile.when(
        data: (user) => AsyncValue.data(user?.blockedUids ?? []),
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
    } else {
      uidsAsync = type == "Followers" 
        ? ref.watch(followersStreamProvider(effectiveUid))
        : ref.watch(followingStreamProvider(effectiveUid));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(type, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: uidsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (uids) {
          if (uids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type == "Blocked" ? Icons.block_rounded : Icons.people_outline_rounded, 
                    size: 64, 
                    color: Colors.grey[300]
                  ),
                  const SizedBox(height: 16),
                  Text(
                    type == "Blocked" ? "No blocked users" : "No one here yet", 
                    style: TextStyle(color: Colors.grey[500])
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: uids.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              return _FollowUserCard(uid: uids[index], type: type);
            },
          );
        },
      ),
    );
  }
}

class _FollowUserCard extends ConsumerWidget {
  final String uid;
  final String type;
  const _FollowUserCard({required this.uid, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));

    return profileAsync.when(
      loading: () => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: const Text("Loading...", style: TextStyle(color: Colors.grey)),
      ),
      error: (err, stack) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final userData = profile as UserModel;
        return InkWell(
          onTap: () => context.push(AppRoutes.userProfile, extra: userData.uid),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 1. Safe Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: userData.profilePhotoUrl.isNotEmpty && Uri.tryParse(userData.profilePhotoUrl)?.hasAbsolutePath == true
                      ? CachedNetworkImage(
                          imageUrl: userData.profilePhotoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey),
                        )
                      : const Icon(Icons.person, color: Colors.grey, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                // 2. Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _safeString(userData.displayName), 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "ID: ${_safeString(userData.username)}", 
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 3. Action
                Container(
                  constraints: const BoxConstraints(minWidth: 80, maxWidth: 100),
                  height: 32,
                  child: _buildActionButton(context, ref, userData.uid),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _safeString(String? input) {
    if (input == null || input.isEmpty) return "User";
    try {
      return input.trim();
    } catch (e) {
      return "User";
    }
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, String targetUid) {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return const SizedBox.shrink();
    
    final isBlockedType = type == "Blocked";
    
    if (isBlockedType) {
      return OutlinedButton(
        onPressed: () async {
          try {
            await ref.read(reportServiceProvider).unblockUser(targetUid);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User unblocked.")));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
            }
          }
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Text("Unblock", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
      );
    }

    // Dynamic Friend / Following / Follow Logic
    final followingList = ref.watch(followingStreamProvider(currentUser.uid)).value ?? [];
    final followersList = ref.watch(followersStreamProvider(currentUser.uid)).value ?? [];

    final isFollowing = followingList.contains(targetUid);
    final isFollower = followersList.contains(targetUid);
    final isFriends = isFollowing && isFollower;

    String buttonText = "Follow";
    bool shouldUnfollow = false;

    if (isFriends) {
      buttonText = "Friends";
      shouldUnfollow = true;
    } else if (isFollowing) {
      buttonText = "Following"; // Change from Unfollow to Following to match profile
      shouldUnfollow = true;
    } else {
      buttonText = "Follow";
      shouldUnfollow = false;
    }

    // Colors matching standard UI UX logic
    final bgColor = shouldUnfollow ? Colors.grey[200] : AppColors.primary;
    final fgColor = shouldUnfollow ? Colors.black87 : Colors.white;

    return ElevatedButton(
      onPressed: () async {
        try {
          if (shouldUnfollow) {
            await ref.read(profileServiceProvider).unfollowUser(currentUser.uid, targetUid);
          } else {
            await ref.read(profileServiceProvider).followUser(currentUser.uid, targetUid);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: shouldUnfollow ? 0 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(buttonText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}
