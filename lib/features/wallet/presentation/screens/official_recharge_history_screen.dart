import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/profile_provider.dart';

class OfficialRechargeHistoryScreen extends ConsumerStatefulWidget {
  const OfficialRechargeHistoryScreen({super.key});

  @override
  ConsumerState<OfficialRechargeHistoryScreen> createState() => _OfficialRechargeHistoryScreenState();
}

class _OfficialRechargeHistoryScreenState extends ConsumerState<OfficialRechargeHistoryScreen> {
  String _selectedMonthFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userProfile = ref.watch(currentUserProfileProvider).value;
    final uid = currentUser?.uid ?? userProfile?.uid;

    if (uid == null || uid.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F121A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF141926),
          title: const Text("Official Recharge History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text("Please login to view recharge history", style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    // 90-day retention window (most recent 3 months)
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));

    return Scaffold(
      backgroundColor: const Color(0xFF0D111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A29),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Official Recharge History",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF101622),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF00E5FF), size: 16),
                const SizedBox(width: 8),
                const Text(
                  "Showing records for the last 3 months (90 days)",
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "3-Month Retention",
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('official_recharges')
            .orderBy('rechargeDateTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Unable to load recharge records: ${snapshot.error}",
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Filter out docs older than 90 days in client just in case
          final docs = allDocs.where((doc) {
            final data = doc.data();
            DateTime? dt;
            final rdt = data['rechargeDateTime'] ?? data['createdAt'] ?? data['timestamp'];
            if (rdt is Timestamp) {
              dt = rdt.toDate();
            } else if (rdt is String) {
              dt = DateTime.tryParse(rdt);
            }
            if (dt == null) return true;
            return dt.isAfter(ninetyDaysAgo);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, size: 36, color: Colors.white24),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No Official Recharges Yet",
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Successful official diamond purchases will be recorded here",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          // Extract unique months for day/month filter
          final monthSet = <String>{};
          for (final doc in docs) {
            final data = doc.data();
            final dt = _extractDateTime(data);
            if (dt != null) {
              monthSet.add(DateFormat('MMM yyyy').format(dt));
            }
          }
          final availableMonths = ['All', ...monthSet];

          // Filter docs by selected month if not All
          final filteredDocs = docs.where((doc) {
            if (_selectedMonthFilter == 'All') return true;
            final dt = _extractDateTime(doc.data());
            if (dt == null) return true;
            return DateFormat('MMM yyyy').format(dt) == _selectedMonthFilter;
          }).toList();

          // Group by Day (yyyy-MM-dd)
          final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groupedByDay = {};
          for (final doc in filteredDocs) {
            final dt = _extractDateTime(doc.data());
            final dayKey = dt != null ? DateFormat('EEEE, MMM d, yyyy').format(dt) : 'Recent Recharges';
            groupedByDay.putIfAbsent(dayKey, () => []).add(doc);
          }

          return Column(
            children: [
              // Month Filter Chips
              if (availableMonths.length > 2)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableMonths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final month = availableMonths[index];
                      final isSelected = month == _selectedMonthFilter;
                      return ChoiceChip(
                        label: Text(month),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedMonthFilter = month);
                        },
                        selectedColor: const Color(0xFF00E5FF),
                        backgroundColor: const Color(0xFF161F30),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
                        ),
                      );
                    },
                  ),
                ),

              // Grouped Records List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: groupedByDay.length,
                  itemBuilder: (context, index) {
                    final dayKey = groupedByDay.keys.elementAt(index);
                    final dayDocs = groupedByDay[dayKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Day Header
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dayKey,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${dayDocs.length} ${dayDocs.length == 1 ? 'transaction' : 'transactions'}",
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ),

                        // Day Cards
                        ...dayDocs.map((doc) => _buildRechargeCard(doc.data(), userProfile?.displayId ?? '')),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime? _extractDateTime(Map<String, dynamic> data) {
    final rdt = data['rechargeDateTime'] ?? data['createdAt'] ?? data['timestamp'];
    if (rdt is Timestamp) return rdt.toDate();
    if (rdt is String) return DateTime.tryParse(rdt);
    return null;
  }

  Widget _buildRechargeCard(Map<String, dynamic> data, String fallbackUserDisplayId) {
    final status = (data['status'] ?? 'SUCCESS').toString().toUpperCase();
    final isSuccess = status == 'SUCCESS';

    final totalDiamonds = data['totalDiamonds'] ?? data['diamondsReceived'] ?? 0;
    final baseDiamonds = data['diamondsReceived'] ?? 0;
    final bonusDiamonds = data['bonusDiamonds'] ?? 0;
    final rechargeAmount = data['rechargeAmount'] ?? 0.0;
    final costString = data['costString'] ?? 'Cost: \$$rechargeAmount';
    final provider = data['provider'] ?? 'Official Recharge';
    final orderId = data['transactionId'] ?? data['orderId'] ?? 'N/A';
    final userId = data['userHelloId']?.toString() ?? data['userId']?.toString() ?? fallbackUserDisplayId;

    final dt = _extractDateTime(data);
    final dateStr = dt != null ? DateFormat('yyyy.MM.dd HH:mm:ss').format(dt) : 'Recent';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141926),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Cost/Provider Header & Total Diamonds
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      costString,
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider,
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "+${_formatNumber(totalDiamonds)}",
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        "💎",
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Breakdown: Base Coin Price & Event Giveaway
          if (baseDiamonds > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.monetization_on_rounded, size: 12, color: Color(0xFF00E5FF)),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Base Coin Price:",
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    "+${_formatNumber(baseDiamonds)}",
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          if (bonusDiamonds > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9100).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, size: 12, color: Color(0xFFFF9100)),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Event Giveaway:",
                    style: TextStyle(color: Color(0xFFFFB74D), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    "+${_formatNumber(bonusDiamonds)}",
                    style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Footer: Order Id, User ID, Date/Time, Status
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order Id: $orderId",
                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "User ID: $userId • $dateStr",
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSuccess
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isSuccess ? const Color(0xFF34D399) : Colors.redAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic number) {
    if (number == null) return "0";
    final n = int.tryParse(number.toString()) ?? 0;
    return NumberFormat("#,###").format(n);
  }
}
