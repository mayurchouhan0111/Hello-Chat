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

  // Fintech Palette
  static const Color primaryNavy = Color(0xFF00246B);
  static const Color softBlue = Color(0xFFCADCFC);
  static const Color creamColor = Color(0xFFFDFBF7);
  static const Color textSub = Color(0xFFCADCFC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF001A4D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: creamColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "TRANSACTION HISTORY",
          style: GoogleFonts.plusJakartaSans(color: softBlue, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('withdrawals')
            .where('uid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: softBlue));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, color: softBlue.withOpacity(0.2), size: 64),
                  const Gap(16),
                  Text(
                    "No transactions found",
                    style: GoogleFonts.plusJakartaSans(color: softBlue.withOpacity(0.5), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
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
    final status = data['status'] ?? 'pending';
    final method = data['method'] ?? 'Bank Transfer';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isAgency = data['isAgency'] ?? false;

    // 1000 Beans = $10
    final usdAmount = (amount / 100).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 20),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method,
                      style: GoogleFonts.plusJakartaSans(color: creamColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (isAgency) ...[
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: softBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text("AGENCY", style: GoogleFonts.plusJakartaSans(color: softBlue, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const Gap(4),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt),
                  style: GoogleFonts.plusJakartaSans(color: textSub.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "\$$usdAmount",
                style: GoogleFonts.plusJakartaSans(color: creamColor, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const Gap(4),
              Text(
                status.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(color: _getStatusColor(status), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orangeAccent;
      case 'approved': return Colors.blueAccent;
      case 'completed': return Colors.greenAccent;
      case 'rejected': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Icons.hourglass_empty_rounded;
      case 'approved': return Icons.check_circle_outline_rounded;
      case 'completed': return Icons.verified_user_rounded;
      case 'rejected': return Icons.cancel_outlined;
      default: return Icons.help_outline_rounded;
    }
  }
}
