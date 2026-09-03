import 'package:flutter/material.dart';
import 'package:hello_chat/core/widgets/premium_bean.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:hello_chat/core/widgets/visa_icon.dart';
import 'balance_card.dart';
import 'beans_info_section.dart';
import '../../screens/withdraw_beans_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/providers/wallet_provider.dart';

class BeansTab extends ConsumerStatefulWidget {
  final int beansBalance;
  const BeansTab({super.key, required this.beansBalance});

  @override
  ConsumerState<BeansTab> createState() => _BeansTabState();
}

class _BeansTabState extends ConsumerState<BeansTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 16),
        
        // 1. Balance Card (Beans)
        BalanceCard(
          isDiamond: false, 
          balance: widget.beansBalance,
          onHistoryTap: () {
            // Navigate to history
          },
          onTransferTap: () {
            // Navigate to wallet/transfer
          },
        ),

        const SizedBox(height: 12),

        // 1.5 Redeem Button (Added)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WithdrawBeansScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.orange[400],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  "Redeem Beans (Withdraw)",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Banner
        _buildFisherBanner(),

        const SizedBox(height: 20),

        // 3. Recharge by Section
        _buildRechargeHeader(),
        _buildRechargeOptions(),

        const SizedBox(height: 20),

        // 4. Bean Packages
        _buildBeanPackages(),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildFisherBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        image: const DecorationImage(
          image: NetworkImage("https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=800&q=80"), // Underwater theme
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.black.withOpacity(0.2),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 30),
        child: const Text(
          "FISHER",
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildRechargeHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Recharge by",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          Row(
            children: const [
              Icon(Icons.location_on_rounded, color: Colors.grey, size: 14),
              SizedBox(width: 4),
              Text("Malaysia", style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeOptions() {
    return Column(
      children: [
        _buildMethodItem(
          iconWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              PremiumBean(size: 14),
              SizedBox(width: 2),
              PremiumDiamond(size: 12),
            ],
          ),
          title: "Beans Exchange",
          onTap: () {}, // Simulation Disabled
        ),
        _buildMethodItem(
          iconWidget: const Icon(Icons.face_retouching_natural_rounded, color: Colors.cyan, size: 24),
          title: "Reseller Recharge",
          subtitle: "1 Bean ≈ 0.020",
          onTap: () {}, // Simulation Disabled
        ),
        _buildMethodItem(
          iconWidget: const Icon(Icons.account_balance_wallet_rounded, color: Colors.orange, size: 24),
          title: "Touch 'n Go",
          subtitle: "1 Bean ≈ 0.076 MYR",
          hasBonus: true,
          onTap: () {}, // Simulation Disabled
        ),
        _buildMethodItem(
          iconWidget: VisaIcon(size: 24),
          title: "VISA/Master",
          subtitle: "1 Bean ≈ 0.089 MYR",
          hasBonus: true,
          isExpanded: true,
          onTap: () {}, // Simulation Disabled
        ),
      ],
    );
  }

  Widget _buildMethodItem({
    required Widget iconWidget,
    required String title,
    String? subtitle,
    bool hasBonus = false,
    bool isExpanded = false,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: SizedBox(width: 40, child: Center(child: iconWidget)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasBonus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: const [
                      PremiumBean(size: 10),
                      Text("+1", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Icon(isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 64),
          child: Divider(height: 1, thickness: 0.5),
        ),
      ],
    );
  }

  Widget _buildBeanPackages() {
    final packages = [
      {'beans': 262, 'price': 'USD 5.99'},
      {'beans': 890, 'bonus': 5, 'price': 'USD 19.99', 'isHot': true},
      {'beans': 2255, 'bonus': 5, 'price': 'USD 49.99'},
    ];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: packages.length,
      itemBuilder: (context, index) {
        final pkg = packages[index];
        return _buildPackageItem(
          amount: pkg['beans'] as int,
          bonus: pkg['bonus'] as int?,
          price: pkg['price'] as String,
          isHot: pkg['isHot'] as bool? ?? false,
        );
      },
    );
  }

  Widget _buildPackageItem({required int amount, int? bonus, required String price, bool isHot = false}) {
    return GestureDetector(
      onTap: () {}, // Simulation Disabled
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50], 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.02)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const PremiumBean(size: 14),
                    const SizedBox(width: 4),
                    Text("$amount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (bonus != null)
                      Text("+$bonus", style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(price, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          if (isHot)
            Positioned(
              top: 0, left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomRight: Radius.circular(8)),
                ),
                child: const Text("BIG DEAL", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  // _handleSimulation removed — recharge simulation is permanently disabled.
  // All recharges must go through production payment gateways.
}
