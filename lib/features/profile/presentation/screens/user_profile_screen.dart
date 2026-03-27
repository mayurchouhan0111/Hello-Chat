import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../utils/number_formatter.dart';
import '../../../chats/presentation/screens/private_chat_screen.dart';

class UserProfileScreen extends ConsumerWidget {
  final String uid;
  const UserProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = currentUid == uid;

    return profileAsync.when(
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: Text("User not found")));
        final userData = user as UserModel;

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, userData),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(userData.displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Gap(4),
                      Text("@${userData.username}", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      const Gap(24),
                      
                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(userData.followerCount, "Fans"),
                          _buildStatItem(userData.followingCount, "Follows"),
                          _buildStatItem(userData.level, "Level"),
                        ],
                      ),
                      const Gap(32),

                      // Action Buttons
                      if (!isMe)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text("Follow", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final chatId = await ref.read(chatServiceProvider).getOrCreateChat(currentUid!, uid);
                                  if (context.mounted) {
                                    Navigator.push(
                                      context, 
                                      MaterialPageRoute(builder: (c) => PrivateChatScreen(chatId: chatId, otherUid: uid))
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: AppColors.primary),
                                ),
                                child: const Text("Message", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      
                      const Gap(40),
                      // Mock Momments/Media below...
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, __) => Scaffold(body: Center(child: Text("Error: $e"))),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, UserModel user) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: user.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${user.uid}/600/600" : user.profilePhotoUrl,
              fit: BoxFit.cover,
            ),
            Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black54, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(int count, String label) {
    return Column(
      children: [
        Text(formatCount(count), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
  }
}
