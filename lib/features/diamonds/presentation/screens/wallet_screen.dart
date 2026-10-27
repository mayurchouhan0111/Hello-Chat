import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/premium_bean.dart';
import '../../../../core/widgets/premium_diamond.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../wallet/presentation/screens/transaction_history_screen.dart';
import '../../../wallet/presentation/screens/official_recharge_history_screen.dart';
import '../../../wallet/presentation/screens/bean_exchange_screen.dart';

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
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                  MaterialPageRoute(builder: (_) => const OfficialRechargeHistoryScreen()),
                                ),
                                child: _buildHeaderAction(Icons.receipt_long_rounded),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                                ),
                                child: _buildHeaderAction(Icons.history_rounded),
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

                // 4. Options Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(
                    children: [
                      Text(
                        _activeTab == "Diamonds" ? "Recharge by" : "Exchange by",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(Icons.location_on_rounded, color: Colors.grey, size: 14),
                      const SizedBox(width: 4),
                      Text(user?.country ?? "Malaysia", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

                // 5. Exclusive Action Groups per Section
                if (_activeTab == "Diamonds") ...[
                  // Diamond Section: Official Recharge options
                  _buildActionBlock([
                    _buildRefinedTile(
                      icon: Icons.face_retouching_natural_rounded,
                      iconColor: Colors.cyan[300],
                      title: "Reseller Recharge",
                      subtitle: "1 💎 ≈ 0.020",
                      onTap: () => context.push(AppRoutes.resellerList),
                    ),
                    _buildRefinedTile(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF00E5FF),
                      title: "Official Recharge History",
                      subtitle: "View successful recharges & bonus breakdown (90 days)",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OfficialRechargeHistoryScreen()),
                      ),
                    ),
                  ]),
                ] else ...[
                  // Bean Section: Keep ONLY the official Bean Exchange option
                  _buildActionBlock([
                    _buildRefinedTile(
                      customIcon: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("🫘", style: TextStyle(fontSize: 14)),
                          Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Colors.grey),
                          Icon(Icons.diamond_rounded, size: 14, color: Color(0xFFFFD700)),
                        ],
                      ),
                      title: "Beans Exchange",
                      subtitle: "Exchange Beans to Diamonds",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BeanExchangeScreen())),
                    ),
                  ]),
                ],

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
}

