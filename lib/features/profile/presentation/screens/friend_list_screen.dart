import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/relationship_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../utils/level_utils.dart';

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
  Set<String> _sentUids = {};
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _isLoadingSuggested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null) {
        _loadSuggestedUsers(uid);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedUsers(String currentUid) async {
    if (_suggestedUsers.isNotEmpty || _isLoadingSuggested) return;
    setState(() => _isLoadingSuggested = true);

    List<Map<String, dynamic>> results = [];
    try {
      // 1. Fetch from Firestore users collection
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(25)
          .get();
      for (final doc in snap.docs) {
        if (doc.id == currentUid) continue;
        results.add({'uid': doc.id, ...doc.data()});
      }
    } catch (_) {
      // 2. Fallback to publicUsers collection if users is locked
      try {
        final pubSnap = await FirebaseFirestore.instance
            .collection('publicUsers')
            .limit(25)
            .get();
        for (final doc in pubSnap.docs) {
          if (doc.id == currentUid) continue;
          results.add({'uid': doc.id, ...doc.data()});
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _suggestedUsers = results;
        _isLoadingSuggested = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result = await ref.read(relationshipServiceProvider).searchUsers(q);
      final users = List<Map<String, dynamic>>.from(result['users'] as List? ?? []);
      if (users.isNotEmpty) {
        if (mounted) setState(() => _searchResults = users);
      } else {
        final directResults = await _searchFirestoreUsers(q);
        if (mounted) setState(() => _searchResults = directResults);
      }
    } catch (_) {
      final directResults = await _searchFirestoreUsers(q);
      if (mounted) setState(() => _searchResults = directResults);
    }
    if (mounted) setState(() => _isSearching = false);
  }

  Future<List<Map<String, dynamic>>> _searchFirestoreUsers(String query) async {
    final lower = query.toLowerCase();
    final currentUid = ref.read(authStateProvider).value?.uid;
    List<Map<String, dynamic>> list = [];

    // Search publicUsers first
    try {
      final snap = await FirebaseFirestore.instance
          .collection('publicUsers')
          .where('username_lowercase', isGreaterThanOrEqualTo: lower)
          .where('username_lowercase', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(10)
          .get();
      for (final doc in snap.docs) {
        if (doc.id == currentUid) continue;
        list.add({'uid': doc.id, ...doc.data()});
      }
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // Fallback search in users
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lowercase', isGreaterThanOrEqualTo: lower)
          .where('username_lowercase', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(10)
          .get();
      for (final doc in snap.docs) {
        if (doc.id == currentUid) continue;
        list.add({'uid': doc.id, ...doc.data()});
      }
    } catch (_) {}

    return list;
  }

  Future<void> _addFriend(String targetUid) async {
    setState(() => _loadingUids = {..._loadingUids, targetUid});
    try {
      await ref.read(relationshipServiceProvider).sendFriendRequest(targetUid);
      if (mounted) {
        setState(() => _sentUids = {..._sentUids, targetUid});
        ScaffoldMessenger.of(context).showSnackBar(
          TopSnackBar(
            context: context,
            content: const Text("Friend request sent!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          TopSnackBar(
            context: context,
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUids = _loadingUids.difference({targetUid}));
      }
    }
  }

  Widget _buildLevelBadge(int level) {
    final color = LevelUtils.getLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 10, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            'Lv.$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserActionTile({
    required Map<String, dynamic> user,
    required String currentUid,
    bool isFriend = false,
  }) {
    final targetUid = user['uid'] as String? ?? '';
    final isSelf = targetUid == currentUid;
    final isLoading = _loadingUids.contains(targetUid);
    final isSent = _sentUids.contains(targetUid);
    final displayName = user['displayName'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final profilePhoto = user['profilePhotoUrl'] as String? ?? (user['photoUrl'] as String? ?? '');
    final level = (user['level'] as num?)?.toInt() ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: targetUid.isNotEmpty ? () => context.push(AppRoutes.userProfile, extra: targetUid) : null,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.surfaceLight,
              backgroundImage: profilePhoto.isNotEmpty
                  ? CachedNetworkImageProvider(profilePhoto)
                  : null,
              child: profilePhoto.isEmpty
                  ? const Icon(Icons.person, color: AppColors.textTertiary, size: 22)
                  : null,
            ),
          ),
          const Gap(12),
          Expanded(
            child: InkWell(
              onTap: targetUid.isNotEmpty ? () => context.push(AppRoutes.userProfile, extra: targetUid) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName.isNotEmpty ? displayName : (username.isNotEmpty ? username : 'User'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Gap(6),
                      _buildLevelBadge(level),
                    ],
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          const Gap(8),
          if (isSelf)
            const Text("You", style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold))
          else if (isFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("Friend", style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            )
          else if (isSent)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    "Sent",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _addFriend(targetUid),
                icon: isLoading
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.person_add_rounded, size: 14),
                label: Text(
                  isLoading ? "" : "Add",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.value?.uid;
    if (uid == null) return const SizedBox();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Friends", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_rounded, color: AppColors.textSecondary, size: 22),
            onPressed: () => context.push(AppRoutes.friendshipPortal),
            tooltip: "Friendship Hall",
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: AppColors.textSecondary, size: 22),
            onPressed: () => context.push(AppRoutes.friendRequests),
            tooltip: "Friend Requests",
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_isSearching)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: AppColors.primary,
            ),
          Expanded(
            child: ref.watch(friendsStreamProvider(uid)).when(
              data: (friendUids) {
                final friendSet = friendUids.toSet();
                final hasActiveSearch = _searchCtrl.text.trim().isNotEmpty;

                if (hasActiveSearch) {
                  return _buildSearchAndDiscoveryView(
                    currentUid: uid,
                    friendSet: friendSet,
                  );
                }

                if (friendUids.isEmpty) {
                  return _buildEmptyStateWithSuggestions(
                    currentUid: uid,
                    friendSet: friendSet,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        "MY FRIENDS (${friendUids.length})",
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    ...friendUids.map((friendUid) => _FriendTile(uid: friendUid)),
                    const Gap(16),
                    _buildSuggestedSection(
                      currentUid: uid,
                      friendSet: friendSet,
                      title: "DISCOVER MORE PEOPLE",
                    ),
                    const Gap(24),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                      const Gap(12),
                      const Text(
                        "Failed to load friends",
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Gap(8),
                      Text(
                        "$err",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                      const Gap(16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(friendsStreamProvider(uid)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Retry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
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
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search by username or name...",
          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textTertiary, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchUsers('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSearchAndDiscoveryView({
    required String currentUid,
    required Set<String> friendSet,
  }) {
    final query = _searchCtrl.text.trim();
    final suggested = _suggestedUsers
        .where((u) => u['uid'] != currentUid && !friendSet.contains(u['uid']))
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_searchResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              "SEARCH RESULTS (${_searchResults.length})",
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ..._searchResults.map((user) => _buildUserActionTile(
                user: user,
                currentUid: currentUid,
                isFriend: friendSet.contains(user['uid']),
              )),
          const Gap(16),
        ] else if (!_isSearching) ...[
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16, top: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, color: AppColors.textTertiary, size: 36),
                const Gap(8),
                Text(
                  "No users found for \"$query\"",
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Gap(4),
                const Text(
                  "Try a different name or discover new people below",
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
        if (suggested.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Icon(Icons.explore_rounded, size: 16, color: AppColors.primary),
                Gap(6),
                Text(
                  "SUGGESTED FRIENDS",
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          ...suggested.take(10).map((user) => _buildUserActionTile(
                user: user,
                currentUid: currentUid,
                isFriend: friendSet.contains(user['uid']),
              )),
        ],
        const Gap(24),
      ],
    );
  }

  Widget _buildEmptyStateWithSuggestions({
    required String currentUid,
    required Set<String> friendSet,
  }) {
    final suggested = _suggestedUsers
        .where((u) => u['uid'] != currentUid && !friendSet.contains(u['uid']))
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const Gap(12),
              const Text(
                "No friends yet",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(6),
              const Text(
                "Connect with people in Hello Chat, share moments, and explore live audio rooms together!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            ),
            const Gap(8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Discover People",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  "Suggested friends for you",
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Gap(12),
        if (_isLoadingSuggested)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (suggested.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: const Text(
              "No suggestions available at the moment.",
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          )
        else
          ...suggested.map((user) => _buildUserActionTile(
                user: user,
                currentUid: currentUid,
                isFriend: friendSet.contains(user['uid']),
              )),
        const Gap(24),
      ],
    );
  }

  Widget _buildSuggestedSection({
    required String currentUid,
    required Set<String> friendSet,
    required String title,
  }) {
    final suggested = _suggestedUsers
        .where((u) => u['uid'] != currentUid && !friendSet.contains(u['uid']))
        .toList();

    if (suggested.isEmpty && !_isLoadingSuggested) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.explore_rounded, size: 16, color: AppColors.primary),
            const Gap(6),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const Gap(8),
        if (_isLoadingSuggested)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary)))
        else
          ...suggested.take(10).map((user) => _buildUserActionTile(
                user: user,
                currentUid: currentUid,
                isFriend: friendSet.contains(user['uid']),
              )),
      ],
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: user.profilePhotoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.profilePhotoUrl)
                        : null,
                    child: user.profilePhotoUrl.isEmpty
                        ? const Icon(Icons.person, color: AppColors.textTertiary)
                        : null,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName.isNotEmpty ? user.displayName : user.username,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (user.displayName.isNotEmpty && user.username.isNotEmpty)
                          Text("@${user.username}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (user.status == 'online')
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
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
