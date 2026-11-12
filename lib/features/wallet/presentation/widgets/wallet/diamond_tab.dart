import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/models/payment_package_model.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/features/wallet/presentation/screens/payment_gateway_checkout_screen.dart';
import 'package:hello_chat/providers/wallet_provider.dart';
import 'recharge_option_tile.dart';
import 'balance_card.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';

class DiamondTab extends ConsumerStatefulWidget {
  final int diamondBalance;
  const DiamondTab({super.key, required this.diamondBalance});

  @override
  ConsumerState<DiamondTab> createState() => _DiamondTabState();
}

class _DiamondTabState extends ConsumerState<DiamondTab> {
  int? _selectedDiamondAmount = 17;
  double? _selectedPrice = 1.5;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              const SizedBox(height: 16),
              BalanceCard(isDiamond: true, balance: widget.diamondBalance),
              const SizedBox(height: 16),
              _buildRechargeShortcut(),
              const SizedBox(height: 12),
              _buildFisherBanner(),
              const SizedBox(height: 12),
              _buildRechargeByRow(),
              _buildLargeActionTile(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text("🫘", style: TextStyle(fontSize: 16)),
                    Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.grey),
                    PremiumDiamond(size: 16),
                  ],
                ),
                title: "Beans Exchange to Diamonds",
                onTap: () {}, // Simulation Disabled
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
              _buildResellerTile(),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
              _buildSpeedyTile(),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
              _buildMoreResellerTile(),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
              _buildDuitnowHeader(),
              _buildDiamondGrid(),
              const SizedBox(height: 20),
              _buildRechargePack(),
              const SizedBox(height: 100),
            ],
          ),
        ),
        _buildBottomGetButton(),
      ],
    );
  }

  Widget _buildFisherBanner() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: const DecorationImage(
          image: NetworkImage("https://picsum.photos/seed/fisher/800/250"), 
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20, top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("FISHER", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeShortcut() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_card_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Recharge Diamonds", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Get diamonds instantly", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text("Recharge", style: TextStyle(color: Color(0xFF2196F3), fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
              Text("Malaysia", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeActionTile({required dynamic icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: const Color(0xFFFFF9C4).withOpacity(0.3), shape: BoxShape.circle),
        child: Center(child: icon is Widget ? icon : Text(icon.toString(), style: const TextStyle(fontSize: 14))),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFDDDDDD), size: 20),
    );
  }

  Widget _buildResellerTile() {
    return ListTile(
      onTap: () {}, // Simulation Disabled
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: const Color(0xFFFFF9C4).withOpacity(0.3), borderRadius: BorderRadius.circular(6)),
        child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFFFD700), size: 18),
      ),
      title: const Text("Reseller Recharge", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          PremiumDiamond(size: 10),
          Text(" 1 = 0.020", style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSpeedyTile() {
    return ListTile(
      onTap: () {}, // Simulation Disabled
      title: Row(
        children: const [
          Icon(Icons.bolt, color: Colors.orange, size: 16),
          Text(" Discount", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
      subtitle: Row(
        children: const [
          SizedBox(width: 8),
          Text("Speedy 💯 Got ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          PremiumDiamond(size: 14),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFDDDDDD), size: 20),
    );
  }

  Widget _buildMoreResellerTile() {
    return ListTile(
      title: const Center(child: Text("More reseller", style: TextStyle(fontSize: 14, color: Colors.grey))),
      onTap: () => context.push(AppRoutes.resellerList),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFDDDDDD), size: 20),
    );
  }

  Widget _buildDuitnowHeader() {
    return ListTile(
      leading: Image.network("https://img.icons8.com/color/48/bank-cards.png", width: 32, height: 32),
      title: const Text("Duitnow", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Row(
        children: const [
          Text("1 ", style: TextStyle(fontSize: 11, color: Colors.grey)),
          PremiumDiamond(size: 10),
          Text(" = 0.077 MYR 💛 +1 ~ 10", style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
      trailing: const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFFCCCCCC)),
    );
  }

  Widget _buildDiamondGrid() {
    final List<Map<String, dynamic>> items = [
      {'diamonds': 17, 'bonus': 1, 'price': 1.5},
      {'diamonds': 36, 'bonus': 1, 'price': 3.0},
      {'diamonds': 62, 'bonus': 10, 'price': 5.0},
      {'diamonds': 126, 'bonus': 10, 'price': 10.0, 'hot': true},
      {'diamonds': 645, 'bonus': 10, 'price': 50.0},
      {'diamonds': 1300, 'bonus': 10, 'price': 100.0},
      {'diamonds': 6509, 'bonus': 10, 'price': 500.0},
      {'diamonds': 13020, 'bonus': 10, 'price': 1000.0},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedDiamondAmount == item['diamonds'];
        return GestureDetector(
          onTap: () => setState(() {
            _selectedDiamondAmount = item['diamonds'];
            _selectedPrice = item['price'];
          }),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? Colors.red : Colors.transparent, width: 1.5),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const PremiumDiamond(size: 14),
                          Text(" ${item['diamonds']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text("+${item['bonus']}", style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Text("MYR ${item['price']}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ),
                if (item['hot'] == true)
                  Positioned(
                    top: 0, left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: const BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
                      child: const Text("HOT", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRechargePack() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recharge Pack", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPackItem(Icons.diamond, "x10"),
              _buildPackItem(Icons.favorite, "x10d"),
              _buildPackItem(Icons.directions_car_filled, "x10d"),
              _buildPackItem(Icons.local_florist, "x10d"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.pink[200], size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBottomGetButton() {
    final total = _selectedDiamondAmount != null ? (_selectedDiamondAmount! + 10) : 0;
    final price = _selectedPrice ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _openPaymentMethodSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            elevation: 0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Get ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const PremiumDiamond(size: 16, colors: [Colors.white, Colors.white, Colors.white]),
                  Text(" $total", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text("Total: MYR $price", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _openPaymentMethodSheet() {
    final int amount = _selectedDiamondAmount ?? 70;
    PaymentPackageModel package;
    if (amount <= 70) {
      package = const PaymentPackageModel(packageId: "pack_70", diamonds: 70, bonusDiamonds: 0, priceINR: 9900, priceUSD: 120);
    } else if (amount <= 350) {
      package = const PaymentPackageModel(packageId: "pack_350", diamonds: 350, bonusDiamonds: 20, priceINR: 49900, priceUSD: 599, tag: "HOT 🔥");
    } else if (amount <= 700) {
      package = const PaymentPackageModel(packageId: "pack_700", diamonds: 700, bonusDiamonds: 50, priceINR: 99900, priceUSD: 1199, tag: "POPULAR ⭐");
    } else if (amount <= 1400) {
      package = const PaymentPackageModel(packageId: "pack_1400", diamonds: 1400, bonusDiamonds: 150, priceINR: 199900, priceUSD: 2399, tag: "BEST VALUE 💎");
    } else if (amount <= 3500) {
      package = const PaymentPackageModel(packageId: "pack_3500", diamonds: 3500, bonusDiamonds: 500, priceINR: 499900, priceUSD: 5999);
    } else {
      package = const PaymentPackageModel(packageId: "pack_7000", diamonds: 7000, bonusDiamonds: 1200, priceINR: 999900, priceUSD: 11999, tag: "VIP ONLY 👑");
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _PaymentMethodSelectionSheet(
        package: package,
        onGatewaySelected: (gateway) async {
          Navigator.pop(sheetContext);
          final success = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentGatewayCheckoutScreen(
                package: package,
                gateway: gateway,
              ),
            ),
          );
          if (success == true && mounted) {
            ref.invalidate(walletBalanceProvider);
          }
        },
      ),
    );
  }

}

class _PaymentMethodSelectionSheet extends StatelessWidget {
  final PaymentPackageModel package;
  final Function(String gateway) onGatewaySelected;

  const _PaymentMethodSelectionSheet({
    required this.package,
    required this.onGatewaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13151D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Select Payment Gateway",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: Color(0xFF10B981), size: 12),
                      Gap(4),
                      Text("256-Bit SSL", style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(14),

            // Package Details summary pill
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1E2A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text("💎", style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${package.totalDiamonds} Diamonds",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          package.bonusDiamonds > 0
                              ? "Includes ${package.bonusDiamonds} bonus diamonds"
                              : "Standard recharge pack",
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    package.formattedINR,
                    style: const TextStyle(color: Color(0xFF86EFAC), fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
            ),
            const Gap(20),

            const Text(
              "AVAILABLE PAYMENT METHODS",
              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const Gap(10),

            // 1. Razorpay Option (India UPI / Cards)
            _buildGatewayTile(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF38BDF8),
              title: "Razorpay Gateway (India)",
              subtitle: "UPI (Google Pay, PhonePe, Paytm), Cards, NetBanking",
              badge: "RECOMMENDED ⚡",
              onTap: () => onGatewaySelected('razorpay'),
            ),
            const Gap(10),

            // 2. Stripe Option (International Cards)
            _buildGatewayTile(
              icon: Icons.credit_card_rounded,
              iconColor: const Color(0xFF818CF8),
              title: "Stripe Gateway (International)",
              subtitle: "Visa, Mastercard, Amex, Apple Pay, Google Pay",
              badge: null,
              onTap: () => onGatewaySelected('stripe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewayTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E212D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (badge != null) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Gap(2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }
}
