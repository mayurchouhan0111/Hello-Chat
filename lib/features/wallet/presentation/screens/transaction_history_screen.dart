import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/transaction_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/constants/app_colors.dart';

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
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121212),
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
          bottom: const TabBar(
            indicatorColor: Color(0xFFFFD700),
            labelColor: Color(0xFFFFD700),
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
            tabs: [
              Tab(text: "DIAMONDS"),
              Tab(text: "BEANS"),
            ],
          ),
        ),
        body: transactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
          error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
          data: (transactions) {
            return TabBarView(
              children: [
                // Diamonds Tab History
                _TransactionListView(
                  transactions: transactions.where((tx) => tx.isDiamondTransaction).toList(),
                  emptyMessage: "No diamond transactions yet",
                ),
                // Beans Tab History
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
}

class _TransactionListView extends StatelessWidget {
  final List<WalletTransaction> transactions;
  final String emptyMessage;

  const _TransactionListView({
    required this.transactions,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded, size: 64, color: Colors.white10),
            const SizedBox(height: 16),
            Text(emptyMessage, style: const TextStyle(color: Colors.white24, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return _TransactionTile(
          tx: transactions[index],
          isBeanTab: emptyMessage.contains("beans"),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label, 
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFD700) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: isActive ? null : Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
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
