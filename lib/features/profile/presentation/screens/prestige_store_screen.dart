import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/providers/user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Prestige Store", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: "Frames"),
            Tab(text: "Badges"),
            Tab(text: "Effects"),
          ],
        ),
      ),
      body: profileAsync.when(
        data: (user) => TabBarView(
          controller: _tabController,
          children: [
            _buildFramesGrid(user!),
            _buildBadgesGrid(user),
            _buildEffectsGrid(user),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildFramesGrid(UserModel user) {
    // Demo Frames
    final frames = [
      {'id': 'vip1', 'url': 'https://example.com/frames/vip1.png', 'name': 'Silver VIP'},
      {'id': 'vip3', 'url': 'https://example.com/frames/vip3.png', 'name': 'Gold VIP'},
      {'id': 'legend', 'url': 'https://example.com/frames/legend.png', 'name': 'Legendary'},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: frames.length,
      itemBuilder: (context, index) {
        final f = frames[index];
        final isActive = user.profileFrame == f['url'];
        return _buildItemCard(f['name']!, f['url']!, isActive, () => _updateFrame(f['url']!));
      },
    );
  }

  Widget _buildBadgesGrid(UserModel user) {
    final badges = [
      {'id': 'top_sender', 'label': 'Top Sender'},
      {'id': 'founding_user', 'label': 'Founding User'},
      {'id': 'verified', 'label': 'Verified'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final b = badges[index];
        return ListTile(
          title: Text(b['label']!, style: const TextStyle(color: Colors.white)),
          leading: const Icon(Icons.verified_rounded, color: Colors.blue),
          trailing: const Icon(Icons.lock_rounded, color: Colors.white24),
        );
      },
    );
  }

  Widget _buildEffectsGrid(UserModel user) {
    return const Center(child: Text("Entry Effects coming soon", style: TextStyle(color: Colors.white54)));
  }

  Widget _buildItemCard(String name, String url, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.amber : Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.portrait_rounded, color: Colors.white30, size: 60),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.amber : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isActive ? "Selected" : "Equip", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _updateFrame(String url) async {
    final uid = ref.read(currentUserStreamProvider).value?.uid;
    if (uid == null) return;
    
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'profileFrame': url,
    });
  }
}
