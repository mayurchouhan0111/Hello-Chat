import 'package:flutter/material.dart';
import 'balance_card.dart';
import 'email_bind_banner.dart';
import 'beans_info_section.dart';

class BeansTab extends StatefulWidget {
  final int beansBalance;
  const BeansTab({super.key, required this.beansBalance});

  @override
  State<BeansTab> createState() => _BeansTabState();
}

class _BeansTabState extends State<BeansTab> {
  bool _emailBannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 16),
        
        // 1. Balance Card (Beans/Earnings)
        BalanceCard(
          isDiamond: false, 
          balance: widget.beansBalance,
          estimatedEarnings: widget.beansBalance / 100.0, // Simulation: 100 beans = 1 USD
          onHistoryTap: () {},
        ),

        const SizedBox(height: 16),

        // 2. Action List
        _buildActionList(),

        const SizedBox(height: 16),

        // 3. Bind Email Banner
        if (!_emailBannerDismissed)
          EmailBindBanner(onDismiss: () => setState(() => _emailBannerDismissed = true)),

        // 4. Info Section
        const BeansInfoSection(),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildActionList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildActionItem(
            icon: "🏅", 
            title: "Earn rewards",
            trailing: const Icon(Icons.stars, color: Colors.blue, size: 24),
          ),
          const Divider(height: 1, thickness: 0.5, indent: 64, endIndent: 16),
          _buildActionItem(icon: "💎", title: "exchange diamonds"),
          const Divider(height: 1, thickness: 0.5, indent: 64, endIndent: 16),
          _buildActionItem(icon: "💰", title: "exchange rewards"),
          const Divider(height: 1, thickness: 0.5, indent: 64, endIndent: 16),
          _buildActionItem(icon: "🕒", title: "Withdrawal History"),
        ],
      ),
    );
  }

  Widget _buildActionItem({required String icon, required String title, Widget? trailing}) {
    return ListTile(
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: Colors.grey[50], shape: BoxShape.circle),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black87)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing,
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
