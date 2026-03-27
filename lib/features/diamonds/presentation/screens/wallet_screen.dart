import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String _activeTab = "Diamonds";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Wallet", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _buildTabItem("Diamonds"),
                  const SizedBox(width: 30),
                  _buildTabItem("Beans"),
                ],
              ),
            ),

            // Balance Card
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFF3E0),
                    const Color(0xFFFFCCBC),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.diamond_rounded, color: Colors.amber, size: 40),
                          const SizedBox(width: 12),
                          const Text(
                            "0",
                            style: TextStyle(
                              color: Color(0xFF4E342E),
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            "Account Balance",
                            style: TextStyle(color: Color(0xFF8D6E63), fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const Icon(Icons.chevron_right, color: Color(0xFF8D6E63), size: 18),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      children: [
                        _buildHeaderAction(Icons.description_outlined),
                        const SizedBox(width: 12),
                        _buildHeaderAction(Icons.account_balance_wallet_outlined),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: NetworkImage("https://picsum.photos/seed/yummy/800/400"),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black12,
                ),
                alignment: Alignment.center,
                child: const Text(
                  "YUMMY",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

            // Recharge Location
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  const Text("Recharge by", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const Spacer(),
                  const Icon(Icons.location_on, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  const Text("Malaysia", style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),

            // Action Items
            _buildActionItem(
              icon: Icons.swap_horizontal_circle_outlined,
              title: "Beans Exchange to Diamonds",
              iconColor: Colors.orange,
              showChevron: true,
            ),
            _buildActionItem(
              icon: Icons.person_add_alt_1_outlined,
              title: "Reseller Recharge",
              subtitle: "1 💎 ≈ 0.020",
              iconColor: Colors.cyan,
              showChevron: true,
            ),

            // Payment Divider
            Container(
              height: 8,
              width: double.infinity,
              color: const Color(0xFFF3F4F6),
            ),

            // VISA Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.credit_card, color: Colors.blue, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("VISA/Master Card", style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Text("1 💎 ≈ 0.090 MYR", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                SizedBox(width: 8),
                                Text("💎 +5", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "VISA/MASTERCARD/Diners Club/Discover/American Express card & UnionP...",
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_up, color: AppColors.textTertiary),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Packages Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _buildPackageCard("262", "USD 5.99"),
                      _buildPackageCard("890", "USD 19.99", bonus: "+5", oldPrice: "USD 20.35", isBigDeal: true),
                      _buildPackageCard("2,255", "USD 49.99", bonus: "+5"),
                      _buildPackageCard("4,562", "USD 99.99", bonus: "+5"),
                      _buildPackageCard("9,205", "USD 199.99", bonus: "+5"),
                      _buildEnterAmountCard(),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String text) {
    bool isActive = _activeTab == text;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = text),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 18,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF4E342E), size: 20),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required bool showChevron,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (showChevron)
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildPackageCard(String amount, String price, {String? bonus, String? oldPrice, bool isBigDeal = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.diamond_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    amount,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (bonus != null)
                    Text(
                      bonus,
                      style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (oldPrice != null)
                Text(
                  oldPrice,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, decoration: TextDecoration.lineThrough),
                ),
              Text(
                price,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        if (isBigDeal)
          Positioned(
            top: -10,
            left: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text("BIG DEAL", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildEnterAmountCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text(
              "Enter Amount",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Icon(Icons.check_circle, color: Colors.red.withOpacity(0.5), size: 12),
          ),
        ],
      ),
    );
  }
}
