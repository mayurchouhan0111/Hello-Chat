import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'buy_diamonds_screen.dart';
import 'transfer_diamonds_screen.dart';
import 'reseller_transaction_history.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import '../providers/reseller_providers.dart';

class ResellerDashboardScreen extends ConsumerWidget {
  const ResellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Very light cool grey
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'RESELLER PORTAL',
          style: TextStyle(
            color: Colors.black, 
            fontSize: 14, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 2
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.black54),
            onPressed: () {},
          )
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null || !user.isReseller) {
            return const Center(child: Text("Access Restricted"));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(currentUserProfileProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildPremiumBalanceCard(user.walletBalance, user.diamondStock),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      "QUICK ACTIONS",
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 12, 
                        color: Colors.black45, 
                        letterSpacing: 1.5
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionGrid(context, user.uid),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildPremiumBalanceCard(double wallet, int diamonds) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.indigo.withOpacity(0.03),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildBalanceItem("Wallet Balance", "\$${wallet.toStringAsFixed(2)}", Icons.account_balance_wallet_rounded, Colors.indigo),
                      Container(width: 1, height: 60, color: Colors.black.withOpacity(0.05)),
                      _buildBalanceItem("Diamond Stock", diamonds.toString(), const PremiumDiamond(size: 20), Colors.blueAccent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value, dynamic icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          icon is Widget ? icon : Icon(icon as IconData, color: color.withOpacity(0.4), size: 18),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Colors.black, 
              fontSize: 18, 
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace'
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, String uid) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        _buildActionCard(
          "Buy Stock",
          "Add diamonds to stock",
          Icons.add_shopping_cart_rounded,
          Colors.indigo,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyDiamondsScreen())),
        ),
        _buildActionCard(
          "Transfer",
          "Send to User ID",
          Icons.send_rounded,
          const Color(0xFF10B981), // Emerald
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferDiamondsScreen())),
        ),
        _buildActionCard(
          "History",
          "Transaction logs",
          Icons.history_rounded,
          Colors.blueGrey,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResellerTransactionHistoryScreen(uid: uid))),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.black.withOpacity(0.03)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

}
