import 'package:flutter/material.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:hello_chat/core/widgets/premium_bean.dart';

class BalanceCard extends StatelessWidget {
  final bool isDiamond;
  final int balance;
  final double? estimatedEarnings;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onTransferTap;

  const BalanceCard({
    super.key,
    required this.isDiamond,
    required this.balance,
    this.estimatedEarnings,
    this.onHistoryTap,
    this.onTransferTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E0), // Peach/Light orange
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF0E0).withOpacity(0.95),
            const Color(0xFFFDDAB7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainBalanceUI(),
              const SizedBox(height: 12),
              _buildBottomLink(),
            ],
          ),
          Positioned(
            top: 4,
            right: 0,
            child: Row(
              children: [
                _buildSmallIconBox(Icons.history_rounded, onTap: onHistoryTap),
                const SizedBox(width: 12),
                _buildSmallIconBox(Icons.account_balance_wallet_rounded, onTap: onTransferTap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBalanceUI() {
    return Row(
      children: [
        if (isDiamond) 
          const PremiumDiamond(size: 38) 
        else 
          const PremiumBean(size: 38),
        const SizedBox(width: 8),
        Text(
          "$balance",
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildBottomLink() {
    return GestureDetector(
      onTap: onHistoryTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            "Account Balance",
            style: TextStyle(color: Color(0xFFF57C00), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: Color(0xFFF57C00), size: 16),
        ],
      ),
    );
  }

  Widget _buildSmallIconBox(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFF57C00), size: 20),
      ),
    );
  }
}
