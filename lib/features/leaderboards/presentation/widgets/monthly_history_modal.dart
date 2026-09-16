import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/widgets/app_avatar.dart';
import 'top_list_podium.dart';

class MonthlyHistoryModal extends ConsumerStatefulWidget {
  const MonthlyHistoryModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MonthlyHistoryModal(),
    );
  }

  @override
  ConsumerState<MonthlyHistoryModal> createState() => _MonthlyHistoryModalState();
}

class _MonthlyHistoryModalState extends ConsumerState<MonthlyHistoryModal> {
  int _selectedMonthIndex = 0; // 0: Month 1, 1: Month 2, 2: Month 3
  bool _isSending = true; // true = Contribution (Senders), false = Charm (Receivers)

  static const List<String> _monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  /// Computes the exact 3 separate rolling months (Month 1, Month 2, Month 3)
  late final List<Map<String, String>> _threeMonths;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _threeMonths = List.generate(3, (i) {
      // Month 1: 1 month ago, Month 2: 2 months ago, Month 3: 3 months ago
      final targetDate = DateTime.utc(now.year, now.month - (i + 1), 1);
      final key = "${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}";
      final label = "${_monthNames[targetDate.month - 1]} ${targetDate.year}";
      final shortLabel = "Month ${i + 1}";
      return {
        "key": key,
        "label": label,
        "shortLabel": shortLabel,
      };
    });

    _triggerSyncIfNeeded();
  }

  Future<void> _triggerSyncIfNeeded() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('monthly_leaderboard_history')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        FirebaseFunctions.instance.httpsCallable('syncMonthlyLeaderboardHistory').call().then((_) {}, onError: (e) {
          debugPrint("MonthlyHistoryModal sync call handled: $e");
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final activeMonth = _threeMonths[_selectedMonthIndex];

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with Title & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Color(0xFFFFD700), size: 22),
                    SizedBox(width: 8),
                    Text(
                      "History (Last 3 Months)",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 3-Month Separate Tabs (Month 1, Month 2, Month 3)
          _buildThreeMonthTabs(),

          const SizedBox(height: 8),

          // Contribution / Charm Switcher
          _buildCategoryPills(),

          const Divider(color: Colors.white10, height: 16),

          // History Content for the selected month
          Expanded(
            child: _buildMonthContent(activeMonth['key']!, activeMonth['label']!),
          ),
        ],
      ),
    );
  }

  /// 3 Separate Month Tabs
  Widget _buildThreeMonthTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF191426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: List.generate(_threeMonths.length, (idx) {
          final item = _threeMonths[idx];
          final isSelected = _selectedMonthIndex == idx;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMonthIndex = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFFFEA79), Color(0xFFFFB300)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['shortLabel']!,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF2E1700) : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['label']!,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF4A2B04) : Colors.white38,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Toggle between Contribution (Top Senders) & Charm (Top Receivers)
  Widget _buildCategoryPills() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSending = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isSending ? const Color(0xFF2C1A3E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isSending ? const Color(0xFFFFD700) : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("💎 ", style: TextStyle(fontSize: 12)),
                    Text(
                      "Top Senders",
                      style: TextStyle(
                        color: _isSending ? const Color(0xFFFFD700) : Colors.white54,
                        fontWeight: _isSending ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSending = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_isSending ? const Color(0xFF2C1A3E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !_isSending ? const Color(0xFFFFD700) : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("🫘 ", style: TextStyle(fontSize: 12)),
                    Text(
                      "Top Receivers",
                      style: TextStyle(
                        color: !_isSending ? const Color(0xFFFFD700) : Colors.white54,
                        fontWeight: !_isSending ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fetches and renders the history for the selected month
  Widget _buildMonthContent(String monthKey, String monthName) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('monthly_leaderboard_history')
          .doc(monthKey)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }

        final docData = snapshot.data?.data();
        List<dynamic> rawList = [];
        if (docData != null) {
          rawList = _isSending
              ? (docData['topSenders'] as List? ?? [])
              : (docData['topReceivers'] as List? ?? []);
        }

        if (rawList.isEmpty) {
          // Fallback: If snapshot hasn't completed or is current month, query user documents directly
          return _buildFallbackLiveQuery(monthName);
        }

        final podiumUsers = <PodiumUserData>[];
        for (final item in rawList) {
          if (item is Map) {
            final score = (item['score'] as num?) ?? 0;
            if (score <= 0) continue;
            podiumUsers.add(PodiumUserData(
              uid: (item['uid'] as String?) ?? '',
              displayName: (item['displayName'] as String?) ?? 'User',
              photoUrl: (item['photoUrl'] as String?) ?? '',
              score: score,
              countryCode: item['countryCode'] as String?,
              vipTier: item['vipTier'] as String?,
              level: (item['level'] as num?)?.toInt(),
              profileFrame: item['profileFrame'] as String?,
            ));
          }
        }

        podiumUsers.sort((a, b) => b.score.compareTo(a.score));

        if (podiumUsers.isEmpty) {
          return _buildEmptyState(monthName);
        }

        return _buildRankingList(podiumUsers);
      },
    );
  }

  /// Fallback query if history snapshot doc is pending
  Widget _buildFallbackLiveQuery(String monthName) {
    final queryField = _isSending ? "monthlyDiamondsSent" : "monthlyBeansReceived";
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy(queryField, descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }

        final docs = snap.data?.docs ?? [];
        final podiumUsers = <PodiumUserData>[];
        for (final d in docs) {
          final data = d.data();
          final num score = (data[queryField] as num?) ?? 0;
          if (score <= 0) continue;
          podiumUsers.add(PodiumUserData(
            uid: d.id,
            displayName: (data['displayName'] as String?) ?? (data['username'] as String?) ?? 'User',
            photoUrl: (data['profilePhotoUrl'] as String?) ?? '',
            score: score,
            countryCode: data['country'] as String?,
            vipTier: data['vipTier'] as String?,
            level: (data['level'] as num?)?.toInt(),
            profileFrame: data['profileFrame'] as String?,
          ));
        }

        podiumUsers.sort((a, b) => b.score.compareTo(a.score));

        if (podiumUsers.isEmpty) {
          return _buildEmptyState(monthName);
        }

        return _buildRankingList(podiumUsers);
      },
    );
  }

  Widget _buildRankingList(List<PodiumUserData> users) {
    final top3 = users.take(3).toList();
    final remaining = users.skip(3).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: TopListPodium(
            topUsers: top3,
            isSendingTab: _isSending,
            isRoomTab: false,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final user = remaining[index];
                final rank = index + 4;
                final rankString = rank < 10 ? "0$rank" : "$rank";

                return InkWell(
                  onTap: () {
                    context.push(AppRoutes.userProfile, extra: user.uid);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14101E).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            rankString,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: AppAvatar(
                            imageUrl: user.photoUrl,
                            radius: 18,
                            frameUrl: user.profileFrame,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.score >= 1000000
                                  ? "${(user.score / 1000000).toStringAsFixed(1)}M"
                                  : user.score >= 1000
                                      ? "${(user.score / 1000).toStringAsFixed(1)}k"
                                      : user.score.toString(),
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const GoldenCoinIcon(size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: remaining.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }

  Widget _buildEmptyState(String monthName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1528),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.history_rounded, size: 40, color: Color(0xFFFFD700)),
            ),
            const SizedBox(height: 14),
            Text(
              "No History for $monthName",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Rankings for this month will appear once gift transactions are recorded.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
