import 'package:flutter/material.dart';

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
      height: 85, // Reduced from 100
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14), // Milder rounded
        gradient: LinearGradient(
          colors: isDiamond 
              ? [const Color(0xFFFFF0E0), const Color(0xFFFFE4C4)]
              : [const Color(0xFFFFF8E1), const Color(0xFFFFF3CD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: isDiamond ? _buildDiamondLayout() : _buildBeansLayout(),
    );
  }

  Widget _buildDiamondLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Text("💎", style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  "$balance",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87), // Muted scaled
                ),
              ],
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: onHistoryTap,
              child: const Row(
                children: [
                  Text("Account Balance ", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right_rounded, color: Colors.orange, size: 14),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildIconButton(Icons.receipt_long_outlined, onHistoryTap),
            const SizedBox(width: 12),
            _buildIconButton(Icons.card_giftcard_rounded, onTransferTap),
          ],
        ),
      ],
    );
  }

  Widget _buildBeansLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Text("Current estimated total earnings", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 2),
                const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 13),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "≈ \$${estimatedEarnings?.toStringAsFixed(0) ?? '0'}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text("current beans ", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const Text("🫘", style: TextStyle(fontSize: 12)),
                Text(" $balance", style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        _buildIconButton(Icons.receipt_long_outlined, onHistoryTap),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Icon(icon, color: Colors.grey[700], size: 20),
      ),
    );
  }
}
