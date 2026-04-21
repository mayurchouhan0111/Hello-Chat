import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/widgets/premium_diamond.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/router/app_router.dart';

class PrestigeStoreScreen extends ConsumerStatefulWidget {
  const PrestigeStoreScreen({super.key});

  @override
  ConsumerState<PrestigeStoreScreen> createState() => _PrestigeStoreScreenState();
}

class _PrestigeStoreScreenState extends ConsumerState<PrestigeStoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          _buildEliteGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildBoutiqueAppBar(),
                _buildBoutiqueTabs(),
                Expanded(
                  child: profileAsync.when(
                    data: (user) {
                      if (user == null) return const Center(child: Text("Sync Error"));
                      return TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildStoreGrid('frame'),
                          _buildStoreGrid('bubble'),
                          _buildStoreGrid('mount'),
                          _buildStoreGrid('animation'),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
                    error: (_, __) => _buildErrorState(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEliteGlow() {
    return Positioned(
      top: -100, right: -50,
      child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.tealAccent.withOpacity(0.08), Colors.transparent])),
      ),
    );
  }

  Widget _buildBoutiqueAppBar() {
    final user = ref.watch(currentUserProfileProvider).value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20)),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ELITE BOUTIQUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2), overflow: TextOverflow.ellipsis),
                Text("OFFICIAL ADMIN CONTROLLED", style: TextStyle(color: Colors.tealAccent, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PremiumDiamond(size: 13),
                const Gap(8),
                Text("${user?.diamondBalance ?? 0}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoutiqueTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 44,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(14)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(10)),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white24,
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: "FRAMES"), Tab(text: "BUBBLES"), Tab(text: "MOUNTS"), Tab(text: "EFFECTS")],
      ),
    );
  }

  Widget _buildStoreGrid(String cat) {
    final storeItemsAsync = ref.watch(prestigeItemsProvider);

    return storeItemsAsync.when(
      data: (allItems) {
        final items = allItems.where((i) => i['category'] == cat).toList();
        if (items.isEmpty) return _buildEmptyStore();
        
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.75,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _buildStoreCard(items[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      error: (_, __) => _buildErrorState(),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 90, padding: const EdgeInsets.all(12),
            child: CachedNetworkImage(imageUrl: item['imageUrl'], fit: BoxFit.contain, errorWidget: (_,__,___) => const Icon(Icons.inventory_2_rounded, color: Colors.white10, size: 40)),
          ),
          const Gap(12),
          Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
          const Gap(4),
          Text("${item['validityDays']} DAYS", style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          const Gap(12),
          GestureDetector(
            onTap: () => _handlePurchase(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumDiamond(size: 12),
                  const Gap(8),
                  Text("${item['price']}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  void _handlePurchase(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("ACQUIRE ${item['name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        content: Text("Purchase ${item['name']} for ${item['price']} diamonds?\nDuration: ${item['validityDays']} days.", style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white24))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(profileServiceProvider).purchasePrestigeItem(item['id']);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Successfully acquired: ${item['name']}")));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Purchase failed: $e")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
            child: const Text("PURCHASE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminControlBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: TextButton(
        onPressed: () async {
           await ref.read(profileServiceProvider).feedPrestigeItems();
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Admin: Boutique Inventory Synchronized!")));
        },
        child: const Text("INITIALIZE ADMIN REPOSITORY", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildEmptyStore() => const Center(child: Opacity(opacity: 0.3, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_bag_outlined, color: Colors.white24, size: 60), Gap(16), Text("INVENTORY EMPTY", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 2))])));
  Widget _buildErrorState() => const Center(child: Text("Boutique Connection Failed."));
}
