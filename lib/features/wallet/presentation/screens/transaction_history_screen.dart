import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/transaction_model.dart';
import '../../../../core/providers/profile_provider.dart';
import 'official_recharge_history_screen.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionStreamProvider);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0D14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF131A29),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Transaction History",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfficialRechargeHistoryScreen()),
              ),
              icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF00E5FF), size: 16),
              label: const Text(
                "Official",
                style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Color(0xFF00E5FF),
            labelColor: Color(0xFF00E5FF),
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
            tabs: [
              Tab(text: "ALL"),
              Tab(text: "RECHARGE"),
              Tab(text: "BONUSES"),
              Tab(text: "GIFTS"),
              Tab(text: "DIAMONDS"),
              Tab(text: "BEANS"),
            ],
          ),
        ),
        body: transactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
          error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
          data: (transactions) {
            return TabBarView(
              children: [
                // 1. ALL Transactions
                _TransactionListView(
                  transactions: transactions,
                  emptyMessage: "No transaction records found",
                ),
                // 2. Official Recharges
                _TransactionListView(
                  transactions: transactions.where((tx) => tx.isOfficialRecharge).toList(),
                  emptyMessage: "No official recharge transactions yet",
                  headerWidget: _buildOfficialRechargeBanner(context),
                ),
                // 3. Event Bonuses
                _TransactionListView(
                  transactions: transactions.where((tx) => tx.isEventBonus).toList(),
                  emptyMessage: "No event bonus transactions yet",
                ),
                // 4. Gifts (Sent & Received)
                _TransactionListView(
                  transactions: transactions.where((tx) => tx.isGiftTransaction).toList(),
                  emptyMessage: "No gift transactions yet",
                ),
                // 5. Diamonds
                _TransactionListView(
                  transactions: transactions.where((tx) => tx.isDiamondTransaction).toList(),
                  emptyMessage: "No diamond transactions yet",
                ),
                // 6. Beans
                _TransactionListView(
                  transactions: transactions.where((tx) => tx.isBeanTransaction).toList(),
                  emptyMessage: "No beans earned yet",
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOfficialRechargeBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2B48), Color(0xFF131A29)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF00E5FF), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Official Recharge History",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  "Organized by Day & Month (90-day retention)",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OfficialRechargeHistoryScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("View", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _TransactionListView extends StatelessWidget {
  final List<WalletTransaction> transactions;
  final String emptyMessage;
  final Widget? headerWidget;

  const _TransactionListView({
    required this.transactions,
    required this.emptyMessage,
    this.headerWidget,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = headerWidget != null;

    if (transactions.isEmpty) {
      return Column(
        children: [
          if (hasHeader) headerWidget!,
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_rounded, size: 64, color: Colors.white10),
                  const SizedBox(height: 16),
                  Text(emptyMessage, style: const TextStyle(color: Colors.white24, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: transactions.length + (hasHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) {
          return headerWidget!;
        }
        final tx = transactions[hasHeader ? index - 1 : index];
        return _TransactionTile(
          tx: tx,
          isBeanTab: emptyMessage.contains("beans"),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  final bool isBeanTab;
  const _TransactionTile({required this.tx, required this.isBeanTab});

  @override
  Widget build(BuildContext context) {
    // Show amount based on context: Beans or Diamonds
    final int amountToShow = (isBeanTab && tx.receivedAmount != null)
        ? tx.amount // Beans side (the negative amount)
        : (tx.receivedAmount ?? tx.amount); // Diamond side

    final bool isIncoming = amountToShow > 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isIncoming ? Colors.greenAccent.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isIncoming ? Colors.greenAccent : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.name.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx.description,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isIncoming ? '+' : '-'}${amountToShow.abs()} ${isBeanTab ? '☕' : '💎'}",
                style: TextStyle(
                  color: isIncoming ? Colors.greenAccent : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, HH:mm').format(tx.timestamp),
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
