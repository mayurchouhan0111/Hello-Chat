import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';

import '../../../../core/providers/profile_provider.dart';

import '../../../../core/services/profile_service.dart';

class PropWarehouseScreen extends ConsumerStatefulWidget {
  const PropWarehouseScreen({super.key});

  @override
  ConsumerState<PropWarehouseScreen> createState() => _PropWarehouseScreenState();
}

class _PropWarehouseScreenState extends ConsumerState<PropWarehouseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("PROP WAREHOUSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          indicatorWeight: 3,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white24,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5),
          tabs: const [
            Tab(text: "MY PROPS"),
            Tab(text: "MOUNTS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPersonalWarehouse('prop', "Avatar Frames & Bubbles"),
          _buildPersonalWarehouse('mount', "Cars & Steeds"),
        ],
      ),
    );
  }

  Widget _buildPersonalWarehouse(String category, String subtitle) {
    final itemsAsync = ref.watch(warehouseItemsProvider(category));

    return Column(
       children: [
         const Gap(20),
         Text(subtitle.toUpperCase(), style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 4)),
         const Gap(20),
         Expanded(
           child: itemsAsync.when(
             data: (items) {
               if (items.isEmpty) return _buildEmptyState();
               return ListView.separated(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                 itemCount: items.length,
                 separatorBuilder: (context, index) => const Gap(16),
                 itemBuilder: (context, index) {
                   final item = items[index];
                   return _buildWarehouseItem(
                     item['name'] ?? 'Elite Item',
                     item['type'] ?? 'Exclusive',
                     item['imageUrl'] ?? '',
                     item['expiryDate'] ?? 'Life-time', // Usually a string like "12 Days" or a timestamp
                     item['isEquipped'] ?? false,
                     item['id'],
                     category,
                   );
                 },
               );
             },
             loading: () => const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
             error: (_, __) => _buildEmptyState(),
           ),
         ),
       ],
    );
  }

  Widget _buildWarehouseItem(String name, String type, String url, String expiry, bool equipped, String id, String cat) {
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: const Color(0xFF1A1A1A),
         borderRadius: BorderRadius.circular(24),
         border: Border.all(color: equipped ? Colors.tealAccent.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
       ),
       child: Row(
         children: [
           Container(
             width: 80, height: 80,
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
             child: Center(
               child: CachedNetworkImage(imageUrl: url, width: 60, fit: BoxFit.contain, errorWidget: (c, e, s) => const Icon(Icons.inventory_2_rounded, color: Colors.white10)),
             ),
           ),
           const Gap(20),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                 Text(type.toUpperCase(), style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 8)),
                 const Gap(10),
                 Text(expiry, style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.w900)),
               ],
             ),
           ),
           _buildEquipBtn(equipped, id, cat),
         ],
       ),
     ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildEquipBtn(bool equipped, String id, String cat) {
    return GestureDetector(
      onTap: () async {
         HapticFeedback.heavyImpact();
         await ref.read(profileServiceProvider).equipItem(id, cat);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: equipped ? Colors.tealAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: equipped ? Colors.tealAccent : Colors.transparent),
        ),
        child: Text(
          equipped ? "EQUIPPED" : "EQUIP",
          style: TextStyle(
            color: equipped ? Colors.tealAccent : Colors.white, 
            fontWeight: FontWeight.w900, 
            fontSize: 9
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
     return SingleChildScrollView(
       child: Opacity(
         opacity: 0.5,
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             const Gap(100),
             const Icon(Icons.inventory_2_outlined, color: Colors.white10, size: 80),
             const Gap(30),
             const Text("YOUR WAREHOUSE IS EMPTY", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
             const Gap(10),
             const Text("Exclusive frames and mounts will appear here.", style: TextStyle(color: Colors.white10, fontSize: 10, fontWeight: FontWeight.bold)),
             const Gap(40),
             SizedBox(
               width: 200,
               child: OutlinedButton(
                 onPressed: () => context.push(AppRoutes.prestigeStore),
                 style: OutlinedButton.styleFrom(
                   side: const BorderSide(color: Colors.white10),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   padding: const EdgeInsets.symmetric(vertical: 14),
                 ),
                 child: const Text("SHOP NOW", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)),
               ),
             ),
           ],
         ),
       ),
     );
  }
}
