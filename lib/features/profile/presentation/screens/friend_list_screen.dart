import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/relationship_provider.dart';
import '../../../../core/services/relationship_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../utils/number_formatter.dart';

class FriendListScreen extends ConsumerStatefulWidget {
  const FriendListScreen({super.key});

  @override
  ConsumerState<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends ConsumerState<FriendListScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Set<String> _loadingUids = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final result = await ref.read(relationshipServiceProvider).searchUsers(query.trim());
      setState(() => _searchResults = List<Map<String, dynamic>>.from(result['users'] as List? ?? []));
    } catch (_) {
      setState(() => _searchResults = []);
    }
    setState(() => _isSearching = false);
  }

  Future<void> _addFriend(String targetUid) async {
    setState(() => _loadingUids = {..._loadingUids, targetUid});
    try {
      await ref.read(relationshipServiceProvider).sendFriendRequest(targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Friend request sent!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _loadingUids = _loadingUids.difference({targetUid}));
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text("Friends", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 22),
            onPressed: () => context.push(AppRoutes.friendshipPortal),
            tooltip: "Friendship Hall",
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white70, size: 22),
            onPressed: () => context.push(AppRoutes.friendRequests),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_searchResults.isNotEmpty) _buildSearchResults(),
          Expanded(
            child: ref.watch(friendsStreamProvider(uid)).when(
              data: (friendUids) {
                if (friendUids.isEmpty) {
                  return _buildEmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: friendUids.length,
                  itemBuilder: (context, index) => _FriendTile(uid: friendUids[index]),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.diamond),
              ),
              error: (err, _) => Center(
                child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _searchUsers,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search by username or name...",
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchUsers('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 56),
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          final isSelf = user['uid'] == ref.read(authStateProvider).value?.uid;
          final isLoading = _loadingUids.contains(user['uid']);
          return ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: (user['profilePhotoUrl'] as String? ?? '').isNotEmpty
                  ? CachedNetworkImageProvider(user['profilePhotoUrl'] as String)
                  : null,
              child: (user['profilePhotoUrl'] as String? ?? '').isEmpty
                  ? const Icon(Icons.person, color: Colors.white38, size: 20)
                  : null,
            ),
            title: Text(
              user['displayName'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '@${user['username'] as String? ?? ''}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: isSelf
                ? const Text("You", style: TextStyle(color: Colors.white24, fontSize: 11))
                : SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () => _addFriend(user['uid'] as String),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.diamond.withOpacity(0.15),
                        foregroundColor: AppColors.diamond,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.diamond))
                          : const Text("Add", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
            child: const Icon(Icons.people_outline, color: Colors.white24, size: 56),
          ),
          const Gap(16),
          const Text("No friends yet", style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
          const Gap(8),
          const Text("Search for users by name above\nto send a friend request.", style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  final String uid;
  const _FriendTile({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));
    return profileAsync.when(
      data: (user) {
        if (user == null) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(AppRoutes.userProfile, extra: uid),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: user.profilePhotoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.profilePhotoUrl)
                        : null,
                    child: user.profilePhotoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white38)
                        : null,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName.isNotEmpty ? user.displayName : user.username,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (user.displayName.isNotEmpty && user.username.isNotEmpty)
                          Text("@${user.username}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (user.status == 'online')
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox(),
    );
  }
}
