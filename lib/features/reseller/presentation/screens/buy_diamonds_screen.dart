import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/services/reseller_service.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';

class BuyDiamondsScreen extends ConsumerStatefulWidget {
  const BuyDiamondsScreen({super.key});

  @override
  ConsumerState<BuyDiamondsScreen> createState() => _BuyDiamondsScreenState();
}

class _BuyDiamondsScreenState extends ConsumerState<BuyDiamondsScreen> {
  bool _isPurchasing = false;

  Future<void> _handleBuy(String packageId, String price) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text("Confirm Stock Refill", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("Deduct $price from your wallet to buy this package?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text("CONFIRM", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPurchasing = true);
    try {
      final res = await ref.read(resellerServiceProvider).buyDiamondPackage(packageId);
      if (res['success'] == true) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully Refilled Stock!"), backgroundColor: Color(0xFF10B981)));
           ref.refresh(currentUserProfileProvider);
           Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DIAMOND BOUTIQUE',
          style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ref.watch(resellerServiceProvider).getResellerPackages(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final packages = snapshot.data ?? [];
              if (packages.isEmpty) return const Center(child: Text("No packages available currently."));

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: packages.length,
                itemBuilder: (context, index) => _buildPackageCard(packages[index]),
              );
            },
          ),
          if (_isPurchasing)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleBuy(pkg['id'], "\$${pkg['price']}"),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              children: [
                const Text("💎", style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  "${pkg['diamonds']}",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1),
                ),
                const Text(
                  "DIAMONDS",
                  style: TextStyle(color: Colors.black26, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "\$${pkg['price']}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
