import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/premium_bean.dart';
import '../../../../core/widgets/premium_diamond.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../wallet/presentation/screens/transaction_history_screen.dart';
import '../../../wallet/presentation/screens/bean_exchange_screen.dart';
import '../../../../core/services/payment_service.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String _activeTab = "Diamonds";

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFF58A4C)))),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (user) {
        final balance = _activeTab == "Diamonds" ? (user?.diamondBalance ?? 0) : (user?.beansBalance ?? 0);
        final currencyIcon = _activeTab == "Diamonds" ? Icons.diamond_rounded : Icons.coffee_rounded;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text("Wallet", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Precise Tabs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      _buildTabItem("Diamonds"),
                      const SizedBox(width: 24),
                      _buildTabItem("Beans"),
                    ],
                  ),
                ),

                // 2. Compact & Cute Balance Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFF9F5), // Softer light peach
                        Color(0xFFFFE0D0), // Softer warm peach
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(32), // More "cute" rounded corners
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9E7D).withOpacity(0.1),
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_activeTab == "Diamonds")
                                const PremiumDiamond(size: 32)
                              else
                                const PremiumBean(size: 32),
                              const SizedBox(width: 8),
                              Text(
                                "$balance",
                                style: const TextStyle(
                                  color: Color(0xFF333333),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                "Account Balance",
                                style: TextStyle(color: Color(0xFFF97316), fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, color: Color(0xFFF97316), size: 16),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          children: [
                            _buildHeaderAction(Icons.history_rounded),
                            const SizedBox(width: 8),
                            _buildHeaderAction(Icons.account_balance_wallet_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Compact Banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  height: 90, // More compact
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: const DecorationImage(
                      image: NetworkImage("https://images.unsplash.com/photo-1544551763-46a013bb70d5?q=80&w=800&auto=format&fit=crop"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.black26,
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Text(
                      "FISHER",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                // 4. Recharge By Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(
                    children: [
                      Text("Recharge by", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const Icon(Icons.location_on_rounded, color: Colors.grey, size: 14),
                      const SizedBox(width: 4),
                      Text(user?.country ?? "Malaysia", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

                // 5. Compact Action Groups
                _buildActionBlock([
                  _buildRefinedTile(
                    customIcon: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text("🫘", style: TextStyle(fontSize: 14)),
                        Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Colors.grey),
                        Icon(Icons.diamond_rounded, size: 14, color: Color(0xFFFFD700)),
                      ],
                    ),
                    title: "Beans Exchange",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BeanExchangeScreen())),
                  ),
                ]),

                const SizedBox(height: 6),

                _buildActionBlock([
                  _buildRefinedTile(
                    icon: Icons.face_retouching_natural_rounded,
                    iconColor: Colors.cyan[300],
                    title: "Reseller Recharge",
                    subtitle: "1 ${_activeTab == "Diamonds" ? "💎" : "🫘"} ≈ 0.020",
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 6),

                _buildActionBlock([
                  _buildRefinedTile(
                    imageUrl: "https://img.icons8.com/color/96/wallet.png",
                    title: "Touch 'n Go",
                    subtitle: "1 ${_activeTab == "Diamonds" ? "💎" : "🫘"} ≈ 0.076 MYR",
                    bonus: "+1",
                    onTap: () {},
                  ),
                  const Divider(height: 1, thickness: 0.3, indent: 76),
                  _buildExpandableRefinedTile(
                    imageUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d6/Visa_2021.svg/512px-Visa_2021.svg.png",
                    title: "VISA/Master",
                    subtitle: "1 ${_activeTab == "Diamonds" ? "💎" : "🫘"} ≈ 0.089 MYR",
                    bonus: "+1",
                    description: "Supports VISA/Master/Amex and more...",
                    onTap: () {},
                  ),
                  const Divider(height: 1, thickness: 0.3, indent: 76),
                  _buildRefinedTile(
                    imageUrl: "https://img.icons8.com/color/96/google-wallet.png",
                    title: "Google Wallet",
                    subtitle: "1 ${_activeTab == "Diamonds" ? "💎" : "🫘"} ≈ 0.12 MYR",
                    bonus: "+1",
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
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
              color: isActive ? Colors.black : const Color(0xFF9CA3AF),
              fontSize: 16,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316), // Use brand orange for indicator
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFFF97316), size: 16),
    );
  }

  Widget _buildActionBlock(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildRefinedTile({
    Widget? customIcon,
    IconData? icon,
    Color? iconColor,
    String? imageUrl,
    required String title,
    String? subtitle,
    String? bonus,
    bool isExpanded = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 54,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: imageUrl != null
              ? Image.network(imageUrl, width: 22, height: 22, fit: BoxFit.contain)
              : (customIcon ?? Icon(icon, color: iconColor, size: 20)),
        ),
      ),
      title: Text(title, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w800)),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Text(subtitle, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11, fontWeight: FontWeight.w500)),
                  if (bonus != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_activeTab == "Diamonds")
                            const PremiumDiamond(size: 9)
                          else
                            const PremiumBean(size: 9),
                          const SizedBox(width: 1),
                          Text(bonus, style: const TextStyle(color: Color(0xFFFFB347), fontSize: 9, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )
          : null,
      trailing: Icon(isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: const Color(0xFFD1D5DB), size: 18),
    );
  }

  Widget _buildExpandableRefinedTile({
    required String imageUrl,
    required String title,
    required String subtitle,
    required String bonus,
    required String description,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        _buildRefinedTile(
          imageUrl: imageUrl,
          title: title,
          subtitle: subtitle,
          bonus: bonus,
          isExpanded: true,
          onTap: onTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Text(
                  description,
                  style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 9, fontWeight: FontWeight.w400),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.25,
                children: [
                  _buildPackageItem("262", "USD 5.99", onTap: () => _handleRecharge("262", "5.99")),
                  _buildPackageItem("890", "USD 19.99", bonus: "+5", isBigDeal: true, onTap: () => _handleRecharge("890", "19.99")),
                  _buildPackageItem("2,255", "USD 49.99", bonus: "+5", onTap: () => _handleRecharge("2,255", "49.99")),
                  _buildPackageItem("4,562", "USD 99.99", bonus: "+5", onTap: () => _handleRecharge("4,562", "99.99")),
                  _buildPackageItem("9,205", "USD 199.99", bonus: "+5", onTap: () => _handleRecharge("9,205", "199.99")),
                  _buildCustomAmountItem(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageItem(String amount, String price, {String? bonus, bool isBigDeal = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16), // Softer corners for packages
          border: Border.all(color: const Color(0xFFEEEEEE)),
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
                      if (_activeTab == "Diamonds")
                        const PremiumDiamond(size: 11)
                      else
                        const PremiumBean(size: 11),
                      Text(" $amount", style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w900, fontSize: 12)),
                      if (bonus != null) Text(bonus, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Text(price, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (isBigDeal)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomRight: Radius.circular(8))),
                  child: const Text("BIG DEAL", style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleRecharge(String amount, String price) async {
    try {
      final session = await ref.read(paymentServiceProvider).initializeStripePayment(
        diamondAmount: int.parse(amount.replaceAll(',', '')),
        priceInUSD: double.parse(price),
      );
      // Native SDK payment bridge call would trigger here
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing stripe payment...")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Recharge error: $e")));
    }
  }

  Widget _buildCustomAmountItem() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.1)),
      ),
      child: const Center(
        child: Text("Enter\nAmount", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w900)),
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
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_activeTab == "Diamonds")
                    const PremiumDiamond(size: 14)
                  else
                    const PremiumBean(size: 14),
                  const SizedBox(width: 4),
                  Text(amount, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, fontWeight: FontWeight.w800)),
                  if (bonus != null)
                    Text(bonus, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 4),
              if (oldPrice != null)
                Text(oldPrice, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9, decoration: TextDecoration.lineThrough)),
              Text(price, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (isBigDeal)
          Positioned(
            top: -6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE04F5F), borderRadius: BorderRadius.circular(4)),
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
        border: Border.all(color: const Color(0xFFE04F5F).withOpacity(0.2)),
      ),
      child: const Center(
        child: Text("Enter\nAmount", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFE04F5F), fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
