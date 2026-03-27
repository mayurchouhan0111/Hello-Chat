import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';

class FollowListScreen extends ConsumerWidget {
  final String type; // "Followers" or "Following"
  const FollowListScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    // Stream the list of UIDs
    final uidsAsync = type == "Followers" 
      ? ref.watch(followersStreamProvider(user.uid))
      : ref.watch(followingStreamProvider(user.uid));

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
                  Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No one here yet", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: uids.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              return _FollowUserCard(uid: uids[index]);
            },
          );
        },
      ),
    );
  }
}

class _FollowUserCard extends ConsumerWidget {
  final String uid;
  const _FollowUserCard({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));

    return profileAsync.when(
      loading: () => const ListTile(title: Text("Loading...")),
      error: (err, stack) => ListTile(title: Text("Error: $err")),
      data: (profile) {
        final userData = profile as UserModel;
        return ListTile(
          onTap: () => context.push(AppRoutes.userProfile, extra: userData.uid),
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: userData.profilePhotoUrl.isNotEmpty 
                ? NetworkImage(userData.profilePhotoUrl) 
                : null,
            child: userData.profilePhotoUrl.isEmpty 
                ? const Icon(Icons.person) 
                : null,
          ),
          title: Text(userData.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("ID: ${userData.username}"),
          trailing: _buildActionButton(context, ref, userData.uid),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, String targetUid) {
    final currentUser = ref.read(authStateProvider).value;
    
    return OutlinedButton(
      onPressed: () async {
        if (currentUser == null) return;
        try {
          await ref.read(profileServiceProvider).unfollowUser(currentUser.uid, targetUid);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text("Unfollow", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    );
  }
}
