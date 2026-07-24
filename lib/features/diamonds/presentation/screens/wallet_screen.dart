import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/premium_bean.dart';
import '../../../../core/widgets/premium_diamond.dart';
import '../../../../core/widgets/visa_icon.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../wallet/presentation/screens/transaction_history_screen.dart';
import '../../../wallet/presentation/screens/bean_exchange_screen.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../core/models/transaction_model.dart';
import '../../../../core/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String _activeTab = "Diamonds";
  bool _isWalletExpanded = true;

  void _showWalletTopUpSheet(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Payment Integration", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF97316))),
        content: const Text(
          "Direct wallet deposits are disabled until the payment gateway is fully integrated and certified in production.",
          style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleWalletBalancePurchase(UserModel user, int diamonds, double price) async {
    if (user.walletBalance < price) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Insufficient Balance", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
          content: Text("Your wallet balance (\$${user.walletBalance.toStringAsFixed(2)}) is insufficient to purchase this package (\$${price.toStringAsFixed(2)}). Please top-up first."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showWalletTopUpSheet(user);
              },
              child: const Text("TOP-UP NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Confirm Purchase", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("Deduct \$${price.toStringAsFixed(2)} from your wallet to buy $diamonds Diamonds?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("PURCHASE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
      );

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('purchaseDiamondsWithWallet');
      await callable.call({
        'diamonds': diamonds,
        'price': price,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        _showSuccessDialog(diamonds);
        ref.refresh(currentUserProfileProvider);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  Widget _buildWalletBalanceRechargeTile(UserModel user) {
    return Column(
      children: [
        ListTile(
          onTap: () {
            setState(() {
              _isWalletExpanded = !_isWalletExpanded;
            });
          },
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 54,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF97316), size: 20),
            ),
          ),
          title: const Text("Wallet Balance", style: TextStyle(color: Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w800)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              "Balance: \$${user.walletBalance.toStringAsFixed(2)}",
              style: const TextStyle(color: Color(0xFFF97316), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          trailing: Icon(_isWalletExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: const Color(0xFFD1D5DB), size: 18),
        ),
        if (_isWalletExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 60),
                  child: Text(
                    "Pay instantly using your Hello Chat Wallet balance.",
                    style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 9, fontWeight: FontWeight.w400),
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
                    _buildPackageItem("262", "USD 5.99", onTap: () => _handleWalletBalancePurchase(user, 262, 5.99)),
                    _buildPackageItem("890", "USD 19.99", bonus: "+5", isBigDeal: true, onTap: () => _handleWalletBalancePurchase(user, 890, 19.99)),
                    _buildPackageItem("2,255", "USD 49.99", bonus: "+5", onTap: () => _handleWalletBalancePurchase(user, 2255, 49.99)),
                    _buildPackageItem("4,562", "USD 99.99", bonus: "+5", onTap: () => _handleWalletBalancePurchase(user, 4562, 99.99)),
                    _buildPackageItem("9,205", "USD 199.99", bonus: "+5", onTap: () => _handleWalletBalancePurchase(user, 9205, 199.99)),
                    _buildCustomAmountItem(),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFF58A4C)))),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (user) {
        final balance = _activeTab == "Diamonds" ? (user?.diamondBalance ?? 0) : (user?.beansBalance ?? 0);

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
                      if (user != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                                ),
                                child: _buildHeaderAction(Icons.history_rounded),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showWalletTopUpSheet(user),
                                child: _buildHeaderAction(Icons.account_balance_wallet_rounded),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 3. Invite & Earn Promo Banner
                GestureDetector(
                  onTap: () => context.push(AppRoutes.invite),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFEA580C).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("INVITE FRIENDS & EARN WEALTH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                              Text("Get 100 free Beans for every friend who joins!", style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Text("CLAIM", style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.w900, fontSize: 10)),
                        ),
                      ],
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

                // 4.5 Wallet Balance Recharge Block
                if (user != null) ...[
                  _buildActionBlock([
                    _buildWalletBalanceRechargeTile(user),
                  ]),
                  const SizedBox(height: 6),
                ],

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
                    onTap: () {}, // Simulation Disabled
                  ),
                ]),

                const SizedBox(height: 6),

                _buildActionBlock([
                  _buildRefinedTile(
                    imageUrl: "https://img.icons8.com/color/96/wallet.png",
                    title: "Touch 'n Go",
                    subtitle: "1 ${_activeTab == "Diamonds" ? "💎" : "🫘"} ≈ 0.076 MYR",
                    bonus: "+1",
                    onTap: () {}, // Simulation Disabled
                  ),
                  const Divider(height: 1, thickness: 0.3, indent: 76),
                  _buildExpandableRefinedTile(
                    customIcon: VisaIcon(size: 28),
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
                    subtitle: "1 ${_activeTab == "Diamonds" ? "💎" : "𫰘"} ≈ 0.12 MYR",
                    bonus: "+1",
                    onTap: () {}, // Simulation Disabled
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
      behavior: HitTestBehavior.opaque,
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
                color: const Color(0xFFF97316),
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
    String? imageUrl,
    Widget? customIcon,
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
          customIcon: customIcon,
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
                  _buildPackageItem("262", "USD 5.99", method: "Stripe"),
                  _buildPackageItem("890", "USD 19.99", bonus: "+5", isBigDeal: true, method: "Stripe"),
                  _buildPackageItem("2,255", "USD 49.99", bonus: "+5", method: "Stripe"),
                  _buildPackageItem("4,562", "USD 99.99", bonus: "+5", method: "Stripe"),
                  _buildPackageItem("9,205", "USD 199.99", bonus: "+5", method: "Stripe"),
                  _buildCustomAmountItem(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageItem(String amount, String price, {String? bonus, bool isBigDeal = false, String method = "Default", VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
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

  void _showSuccessDialog(int amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              "Purchase Successful!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              "◈ $amount Diamonds have been added to your account.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Awesome!", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
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
}

class _WalletTopUpSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const _WalletTopUpSheet({super.key, required this.user});

  @override
  ConsumerState<_WalletTopUpSheet> createState() => _WalletTopUpSheetState();
}

class _WalletTopUpSheetState extends ConsumerState<_WalletTopUpSheet> {
  double _selectedAmount = 20.0;
  final List<double> _amountOptions = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0];
  String _paymentMethod = "VISA/Master";
  bool _isProcessing = false;
  final TextEditingController _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _handleTopUp() async {
    double depositAmount = _selectedAmount;
    if (_customAmountController.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_customAmountController.text.trim());
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid amount"), backgroundColor: Colors.redAccent));
        return;
      }
      depositAmount = parsed;
    }

    setState(() => _isProcessing = true);

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('simulateWalletTopUp');
      await callable.call({
        'amount': depositAmount,
        'paymentMethod': _paymentMethod,
      });

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context);
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text("Top-Up Successful!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  "\$${depositAmount.toStringAsFixed(2)} has been added to your wallet balance.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.refresh(currentUserProfileProvider);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text("AWESOME!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionStreamProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: const BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.all(Radius.circular(2))))),
            const SizedBox(height: 20),
            Row(
              children: const [
                Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF97316), size: 28),
                SizedBox(width: 12),
                Text("Wallet Top-Up", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 20),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CURRENT BALANCE", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                    "\$${widget.user.walletBalance.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("USER ID: ${widget.user.displayName}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold)),
                      const Icon(Icons.stars, color: Colors.amberAccent, size: 16),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Text("SELECT DEPOSIT AMOUNT", style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 12),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: _amountOptions.map((amount) {
                bool isSel = _selectedAmount == amount && _customAmountController.text.trim().isEmpty;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAmount = amount;
                      _customAmountController.clear();
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSel ? const Color(0xFFF97316) : const Color(0xFFEEEEEE), width: isSel ? 2 : 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "\$${amount.toInt()}",
                      style: TextStyle(color: isSel ? const Color(0xFFF97316) : const Color(0xFF333333), fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            TextField(
              controller: _customAmountController,
              decoration: InputDecoration(
                labelText: "Or Enter Custom USD Amount",
                prefixText: "\$ ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                setState(() {});
              },
            ),
            
            const SizedBox(height: 24),
            const Text("PAYMENT METHOD", style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentMethod = "VISA/Master"),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == "VISA/Master" ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _paymentMethod == "VISA/Master" ? const Color(0xFFF97316) : const Color(0xFFEEEEEE), width: _paymentMethod == "VISA/Master" ? 2 : 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.credit_card, color: Colors.blueAccent, size: 16),
                          SizedBox(width: 8),
                          Text("Card", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentMethod = "Touch 'n Go"),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == "Touch 'n Go" ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _paymentMethod == "Touch 'n Go" ? const Color(0xFFF97316) : const Color(0xFFEEEEEE), width: _paymentMethod == "Touch 'n Go" ? 2 : 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.account_balance_wallet_rounded, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Text("Touch 'n Go", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handleTopUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("TOP-UP NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
              ),
            ),
            
            const SizedBox(height: 30),
            
            const Text("TOP-UP HISTORY", style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 10),
            
            transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text("Error loading history: $err")),
              data: (txs) {
                final topUps = txs.where((t) => t.type == TransactionType.recharge && t.description.contains("Wallet Deposit")).toList();
                if (topUps.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No top-up records found.", style: TextStyle(color: Colors.grey, fontSize: 12))),
                  );
                }
                return Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: topUps.length,
                    itemBuilder: (context, index) {
                      final tx = topUps[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.arrow_downward, color: Colors.blue, size: 16)),
                        title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(tx.timestamp.toLocal().toString().split('.').first, style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          "+\$${tx.amount.toDouble().toStringAsFixed(2)}",
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
