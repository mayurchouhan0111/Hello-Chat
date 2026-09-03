import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WithdrawalHistoryScreen extends ConsumerWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            "Please log in to view history",
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 15),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "SETTLEMENT HISTORY",
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query without composite index requirement, sorted client-side
        stream: FirebaseFirestore.instance
            .collection('withdrawals')
            .where('uid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                    const Gap(12),
                    Text(
                      "Unable to load transactions",
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Gap(4),
                    Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            );
          }

          final rawDocs = snapshot.data?.docs ?? [];
          
          // Sort descending by createdAt in-memory to prevent index errors
          final docs = List<QueryDocumentSnapshot>.from(rawDocs);
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>? ?? {};
            final bData = b.data() as Map<String, dynamic>? ?? {};
            final aTime = (aData['createdAt'] as Timestamp?)?.toDate();
            final bTime = (bData['createdAt'] as Timestamp?)?.toDate();
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0).withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF94A3B8), size: 48),
                  ),
                  const Gap(16),
                  Text(
                    "No Settlement History Yet",
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const Gap(6),
                  Text(
                    "When you request a payout, it will appear here.",
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildHistoryItem(data, index);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> data, int index) {
    final amount = data['amount'] ?? 0;
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final method = data['method'] ?? 'Bank Wire';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isAgency = data['isAgency'] ?? false;

    // 1000 Beans = $10 USD
    final usdAmount = (amount * 0.01).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 22),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        method,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (isAgency) ...[
                      const Gap(6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "AGENCY",
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF0284C7),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Gap(4),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "\$$usdAmount USD",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Gap(3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$amount Beans",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.05, end: 0);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'approved':
      case 'processing':
        return const Color(0xFF0284C7);
      case 'completed':
      case 'success':
        return const Color(0xFF16A34A);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'approved':
      case 'processing':
        return Icons.sync_rounded;
      case 'completed':
      case 'success':
        return Icons.check_circle_rounded;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }
}
