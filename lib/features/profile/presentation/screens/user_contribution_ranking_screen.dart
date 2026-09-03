import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:intl/intl.dart';

class UserContributionRankingScreen extends ConsumerStatefulWidget {
  final String targetUid;
  final String targetUserName;

  const UserContributionRankingScreen({
    super.key,
    required this.targetUid,
    required this.targetUserName,
  });

  @override
  ConsumerState<UserContributionRankingScreen> createState() => _UserContributionRankingScreenState();
}

class _UserContributionRankingScreenState extends ConsumerState<UserContributionRankingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['daily', 'weekly', 'monthly', 'total'];
  final List<String> _tabLabels = ['Daily', 'Weekly', 'Monthly', 'Overall'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.targetUserName.isNotEmpty ? "${widget.targetUserName}'s Top Senders" : "Contribution Ranking",
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          indicatorColor: Colors.black87,
          indicatorWeight: 3,
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((period) => _buildRankingList(period)).toList(),
      ),
    );
  }

  Widget _buildRankingList(String period) {
    final rankingAsync = ref.watch(userSenderRankingsProvider((targetUid: widget.targetUid, period: period)));

    return rankingAsync.when(
      data: (senders) {
        if (senders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  "No top senders for this period yet",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const BouncingScrollPhysics(),
          itemCount: senders.length,
          itemBuilder: (context, index) {
            final sender = senders[index];
            final rank = index + 1;
            return _buildRankTile(sender, rank);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
      error: (err, _) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent))),
    );
  }

  Widget _buildRankTile(Map<String, dynamic> sender, int rank) {
    final name = sender['displayName'] ?? 'User';
    final photoUrl = sender['profilePhotoUrl'] ?? '';
    final amount = (sender['amount'] as num? ?? 0).toInt();
    final gender = sender['gender'] ?? 'male';
    final level = (sender['level'] as num? ?? 1).toInt();
    final vipTier = sender['vipTier'] ?? 'none';
    final formattedAmount = NumberFormat('#,###').format(amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          _buildRankBadge(rank),
          const SizedBox(width: 12),

          // User Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
            child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),

          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      gender == 'female' ? Icons.female_rounded : Icons.male_rounded,
                      color: gender == 'female' ? Colors.pinkAccent : Colors.blueAccent,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8E54E9), Color(0xFF4776E6)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Lv.$level",
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (vipTier != 'none' && vipTier.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          vipTier.toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Diamond Amount
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedAmount,
                style: const TextStyle(color: Color(0xFFFF9100), fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(width: 4),
              const PremiumDiamond(size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFFFD700),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x66FFD700), blurRadius: 6)],
        ),
        alignment: Alignment.center,
        child: const Text("1", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
      );
    } else if (rank == 2) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFC0C0C0),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text("2", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
      );
    } else if (rank == 3) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFCD7F32),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text("3", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
      );
    }

    return SizedBox(
      width: 28,
      child: Text(
        "$rank",
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
