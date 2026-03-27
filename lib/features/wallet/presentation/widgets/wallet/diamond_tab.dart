import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'recharge_option_tile.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'balance_card.dart';

class DiamondTab extends ConsumerWidget {
  final int diamondBalance;
  const DiamondTab({super.key, required this.diamondBalance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        const SizedBox(height: 16),
        
        // 1. Balance Card (Diamond)
        BalanceCard(
          isDiamond: true, 
          balance: diamondBalance,
          onHistoryTap: () {}, // Navigate to history
          onTransferTap: () {}, // Navigate to gift
        ),

        const SizedBox(height: 16),

        // 2. CRASH Banner
        _buildCrashBanner(),

        const SizedBox(height: 12),

        // 3. Recharge by Row
        _buildRechargeByRow(),

        // 4. Recharge Options List
        _buildRechargeOptions(context, ref),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildCrashBanner() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(image: NetworkImage("https://picsum.photos/seed/crash/600/200"), fit: BoxFit.cover),
      ),
      child: const Center(child: Text("")),
    );
  }

  Widget _buildRechargeByRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Recharge by", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal)),
          Row(
            children: const [
              Icon(Icons.location_on_rounded, color: Colors.grey, size: 14),
              SizedBox(width: 4),
              Text("Global", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeOptions(BuildContext context, WidgetRef ref) {
    final rechargeAction = ref.watch(walletActionProvider);

    return Column(
      children: [
        RechargeOptionTile(
          title: "Beans Exchange to Diamonds",
          icon: _buildBeansToDiamondsIcon(),
          onTap: () {},
        ),
        RechargeOptionTile(
          title: "Touch 'n Go eWallet (Sandbox)",
          subtitle: "1◈ = 0.078 MYR",
          icon: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle), child: const Center(child: Text("TNG", style: TextStyle(fontSize: 10)))),
          bonus: "+1",
          isExpandable: true,
          rechargeOptions: const [60, 300, 600, 1500, 3000],
          onAmountSelected: (amt) => _recharge(context, ref, amt),
        ),
        RechargeOptionTile(
          title: "VISA/Master Card (Sandbox)",
          subtitle: "1◈ = 0.090 MYR",
          icon: const Icon(Icons.credit_card_rounded, color: Colors.grey, size: 32),
          bonus: "+1",
          isExpandable: true,
          rechargeOptions: const [100, 500, 1000, 2500],
          onAmountSelected: (amt) => _recharge(context, ref, amt),
        ),
        if (rechargeAction.isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  void _recharge(BuildContext context, WidgetRef ref, int amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Recharge"),
        content: Text("Purchase ◈ $amount now? (Simulation)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Recharge", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(walletActionProvider.notifier).simulateRecharge(amount);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Successfully recharged ◈ $amount!")));
      }
    }
  }

  Widget _buildBeansToDiamondsIcon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text("🫘", style: TextStyle(fontSize: 16)),
        Icon(Icons.arrow_forward_rounded, size: 10, color: Colors.grey),
        Text("💎", style: TextStyle(fontSize: 14)),
      ],
    );
  }
}
