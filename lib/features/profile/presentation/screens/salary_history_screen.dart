import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/salary_service.dart';
import '../../../../core/models/salary_model.dart';
import 'package:gap/gap.dart';

class SalaryHistoryScreen extends ConsumerWidget {
  const SalaryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text("Please Login")));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Salary & Rewards", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Trigger a refresh of the providers
          ref.invalidate(salaryStatusProvider(uid));
          ref.invalidate(payoutHistoryProvider(uid));
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: const Color(0xFF6366F1),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Current Progress Header
            SliverToBoxAdapter(
              child: _buildProgressHeader(ref, uid),
            ),
  
            // 2. Transaction List Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  "Payout History",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
              ),
            ),
  
            // 3. Transaction List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: ref.watch(payoutHistoryProvider(uid)).when(
                data: (payouts) {
                  if (payouts.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPayoutCard(payouts[index]),
                      childCount: payouts.length,
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
                ),
                error: (err, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const Gap(12),
                        Text("Failed to load: $err", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Gap(40)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader(WidgetRef ref, String uid) {
    return ref.watch(salaryStatusProvider(uid)).when(
      data: (status) {
        final currentLv = status?.currentLevel ?? 0;
        final nextLv = currentLv + 1;
        final salaryLevel = SalaryLevel.getLevel(nextLv <= 10 ? nextLv : 10);
        final totalBeans = status?.totalBeansEarned ?? 0;
        final progress = (totalBeans / salaryLevel.targetBeans).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3), 
                blurRadius: 20, 
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TOTAL BEANS EARNED", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const Gap(4),
                      Text("◈ ${NumberFormat.decimalPattern().format(totalBeans)}", 
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2), 
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text("Lv.$currentLv", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ],
              ),
              const Gap(30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text("Next Milestone: ${salaryLevel.label}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                   Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              const Gap(10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const Gap(14),
               Text(
                "${NumberFormat.decimalPattern().format(salaryLevel.targetBeans - totalBeans)} beans remaining for Level $nextLv reward",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 180,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.2)),
          const Gap(16),
          const Text("No payouts yet", style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 16)),
          const Gap(8),
          const Text("Reach Lv.1 targets to start receiving rewards!", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(SalaryPayout payout) {
    final isPaid = payout.status == 'paid';
    final date = DateFormat('MMM dd, yyyy').format(payout.scheduledDate);
    final color = payout.type == 'host' ? const Color(0xFF3B82F6) : (payout.type == 'agency' ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02), 
            blurRadius: 15, 
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  payout.type == 'host' ? Icons.person_rounded : (payout.type == 'agency' ? Icons.business_rounded : Icons.admin_panel_settings_rounded),
                  color: color,
                  size: 22,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Level ${payout.level} ${payout.type.toUpperCase()} Share", 
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1F2937)),
                    ),
                    const Gap(2),
                    Text(
                      isPaid ? "Received on $date" : "Release Date: $date",
                      style: TextStyle(color: isPaid ? const Color(0xFF10B981) : const Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "◈ ${NumberFormat.decimalPattern().format(payout.amount.toInt())}",
                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      payout.status.toUpperCase(),
                      style: TextStyle(
                        color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
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
          if (!isPaid) ...[
            const Gap(16),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const Gap(12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                const Gap(8),
                Expanded(
                  child: Text(
                    payout.type == 'host' 
                      ? "Host share (60%) will be added to your wallet tomorrow."
                      : "Agency share (30%) is distributed every 15 days.",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
