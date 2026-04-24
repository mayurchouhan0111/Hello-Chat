import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/services/reseller_service.dart';
import '../providers/reseller_providers.dart';

class ResellerTransactionHistoryScreen extends ConsumerWidget {
  final String uid;
  const ResellerTransactionHistoryScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(resellerHistoryProvider(uid));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'PLATINUM LEDGER',
          style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
      ),
      body: historyAsync.when(
        data: (txs) {
          if (txs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("∅", style: TextStyle(fontSize: 48, color: Colors.black12)),
                  const SizedBox(height: 16),
                  const Text("NO RECORDS FOUND", style: TextStyle(color: Colors.black12, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: txs.length,
            itemBuilder: (context, index) {
              return _buildPlatinumLedgerItem(txs[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.black12)),
        error: (e, __) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildPlatinumLedgerItem(Map<String, dynamic> tx) {
    final type = tx['type'] ?? 'UNKNOWN';
    final amount = tx['amount'] ?? 0;
    final currency = tx['currency'] ?? '';
    final rawTimestamp = tx['timestamp'];
    
    DateTime? timestamp;
    if (rawTimestamp is String) {
      timestamp = DateTime.tryParse(rawTimestamp);
    }

    final isCredit = type.toString().contains('CREDIT') || type.toString().contains('REFUND');
    
    IconData icon = Icons.receipt_long_outlined;
    if (type.contains('BUY')) icon = Icons.shopping_bag_outlined;
    else if (type.contains('TO_USER')) icon = Icons.arrow_outward_rounded;
    else if (type.contains('CREDIT')) icon = Icons.add_circle_outline_rounded;
    else if (type == 'CONNECTION_VERIFIED') icon = Icons.verified_user_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.black54, size: 20),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.toString().replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.1),
                ),
                const SizedBox(height: 6),
                Text(
                  timestamp != null ? "${timestamp.day}.${timestamp.month}.${timestamp.year} — ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}" : "RECORDS_PENDING",
                  style: const TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            "${isCredit ? '+' : ''}${currency == 'USD' ? '\$' : ''}$amount",
            style: TextStyle(
              fontWeight: FontWeight.w900, 
              color: isCredit ? const Color(0xFF10B981) : Colors.black, 
              fontSize: 18,
              fontFamily: 'monospace',
              letterSpacing: -1
            ),
          ),
        ],
      ),
    );
  }
}
