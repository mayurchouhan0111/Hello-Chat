import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/svga_player.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_provider.dart';

class PropWarehouseScreen extends ConsumerStatefulWidget {
  const PropWarehouseScreen({super.key});

  @override
  ConsumerState<PropWarehouseScreen> createState() => _PropWarehouseScreenState();
}

class _PropWarehouseScreenState extends ConsumerState<PropWarehouseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _loadingItemId;

  // Track selected item per tab index
  final Map<int, Map<String, dynamic>> _selectedItems = {};

  // Local state for mock equipped items
  String _equippedMockId = 'none';
  String _equippedMockAperture = 'none';
  String _equippedMockTheme = 'none';
  String _equippedMockCrown = 'none';
  String _equippedMockOfficial = 'none';

  final List<String> _tabsList = [
    "ID",
    "Frame",
    "Entry",
    "Mic Waves",
    "Messages Bubble",
    "Personal Page",
    "Crowns",
    "Official Items"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabsList.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to update bottom action button for selected item of new tab
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool isVipActive(UserModel? user) {
    if (user == null) return false;
    if (user.vipTier == null || user.vipTier == 'none' || user.vipTier!.isEmpty) return false;
    if (user.vipExpiry == null) return false;
    return user.vipExpiry!.isAfter(DateTime.now());
  }

  void _initializeSelection(int tabIndex, List<Map<String, dynamic>> items) {
    if (!_selectedItems.containsKey(tabIndex) && items.isNotEmpty) {
      final equipped = items.firstWhere((item) => item['isEquipped'] == true, orElse: () => items.first);
      _selectedItems[tabIndex] = equipped;
    }
  }

  String tabIndexToCategory(int index) {
    if (index == 1) return 'frame';
    if (index == 2) return 'mount';
    if (index == 4) return 'bubble';
    if (index == 0) return 'id';
    if (index == 3) return 'aperture';
    if (index == 5) return 'personal_page';
    if (index == 6) return 'crown';
    if (index == 7) return 'official_frame';
    return '';
  }

  List<Map<String, dynamic>> _getMockIdItems() {
    return [
      {
        'id': 'none',
        'name': 'Default ID',
        'type': 'Standard',
        'imageUrl': '',
        'idText': '827361',
        'category': 'id',
        'isEquipped': _equippedMockId == 'none',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'mock_id_6',
        'name': 'Elite 6-Digit ID',
        'type': 'VIP Package',
        'imageUrl': '',
        'idText': '888888',
        'category': 'id',
        'isEquipped': _equippedMockId == 'mock_id_6',
        'expiryDate': '30 Days'
      },
      {
        'id': 'mock_id_5',
        'name': 'Royal 5-Digit ID',
        'type': 'VIP Package',
        'imageUrl': '',
        'idText': '99999',
        'category': 'id',
        'isEquipped': _equippedMockId == 'mock_id_5',
        'expiryDate': '30 Days'
      },
      {
        'id': 'mock_id_4',
        'name': 'Godly 4-Digit ID',
        'type': 'VIP Package',
        'imageUrl': '',
        'idText': '7777',
        'category': 'id',
        'isEquipped': _equippedMockId == 'mock_id_4',
        'expiryDate': '30 Days'
      }
    ];
  }

  List<Map<String, dynamic>> _getMockApertureItems() {
    return [
      {
        'id': 'none',
        'name': 'Default Mic',
        'type': 'Standard',
        'imageUrl': '',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'none',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'vip1_mic_wave',
        'name': 'VIP 1 Sound Wave',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 1/Sound Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'vip1_mic_wave',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip2_mic_wave',
        'name': 'VIP 2 Sound Wave',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 2/VIP 2/Mic Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'vip2_mic_wave',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip3_mic_wave',
        'name': 'VIP 3 Mic Wave',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 3/VIP 3/Mic Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'vip3_mic_wave',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip4_mic_wave',
        'name': 'VIP 4 Mic Wave',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 4/VIP 4/Mic Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'vip4_mic_wave',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip5_mic_wave',
        'name': 'VIP 5 Mic Wave',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 5/VIP 5/Mic Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'vip5_mic_wave',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip6_mic_wave',
        'name': 'VIP 6 Mic Wave',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 6/VIP 6/Mic Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'vip6_mic_wave',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip7_mic_wave',
        'name': 'VIP 7 Mic Wave',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 7/VIP 7/Mic Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'vip7_mic_wave',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip8_mic_wave',
        'name': 'VIP 8 Mic Wave',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 8/VIP 8/Mic Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'vip8_mic_wave',
        'expiryDate': '30 Days'
      }
    ];
  }

  List<Map<String, dynamic>> _getMockThemeItems() {
    return [
      {
        'id': 'none',
        'name': 'Default Theme',
        'type': 'Standard',
        'imageUrl': '',
        'category': 'personal_page',
        'isEquipped': _equippedMockTheme == 'none',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'mock_theme_1',
        'name': 'Starlight Theme',
        'type': 'VIP Package',
        'imageUrl': '',
        'category': 'personal_page',
        'isEquipped': _equippedMockTheme == 'mock_theme_1',
        'expiryDate': '30 Days'
      },
      {
        'id': 'mock_theme_2',
        'name': 'Royal Garden',
        'type': 'VIP Package',
        'imageUrl': '',
        'category': 'personal_page',
        'isEquipped': _equippedMockTheme == 'mock_theme_2',
        'expiryDate': '30 Days'
      }
    ];
  }

  List<Map<String, dynamic>> _getMockCrownItems() {
    return [
      {
        'id': 'none',
        'name': 'No Crown',
        'type': 'Standard',
        'imageUrl': '',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'none',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'vip1_crown_1',
        'name': 'VIP 1 Crown',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 1/Crown 1.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'vip1_crown_1',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip2_crown_1',
        'name': 'VIP 2 Crown',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 2/VIP 2/Crown 1.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'vip2_crown_1',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip3_crown_1',
        'name': 'VIP 3 Crown',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 3/VIP 3/Crown 1.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'vip3_crown_1',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip4_crown_1',
        'name': 'VIP 4 Crown',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 4/VIP 4/Crown 1.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'vip4_crown_1',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip5_crown_1',
        'name': 'VIP 5 Crown',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 5/VIP 5/Crown 1.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'vip5_crown_1',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip6_crown_1',
        'name': 'VIP 6 Crown',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 6/VIP 6/Crown 1.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'vip6_crown_1',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip7_crown_1',
        'name': 'VIP 7 Crown',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 7/VIP 7/Crown 1.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'vip7_crown_1',
        'expiryDate': '30 Days'
      },
      {
        'id': 'vip8_crown_1',
        'name': 'VIP 8 Crown',
        'type': 'VIP Package',
        'imageUrl': 'assets/VIP/VIP 8/VIP 8/VIP 8 Crown 1.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'vip8_crown_1',
        'expiryDate': '30 Days'
      },
    ];
  }

  List<Map<String, dynamic>> _getMockOfficialItems() {
    return [
      {
        'id': 'none',
        'name': 'Default Frame',
        'type': 'Standard',
        'imageUrl': '',
        'category': 'official_frame',
        'isEquipped': _equippedMockOfficial == 'none',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'official_frame_super',
        'name': 'Super Admin Frame',
        'type': 'Official',
        'imageUrl': 'assets/images/super/super-admin.svga',
        'category': 'official_frame',
        'isEquipped': _equippedMockOfficial == 'official_frame_super',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'official_frame_admin',
        'name': 'Admin Frame',
        'type': 'Official',
        'imageUrl': 'assets/images/super/admin.svga',
        'category': 'official_frame',
        'isEquipped': _equippedMockOfficial == 'official_frame_admin',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'official_frame_reseller',
        'name': 'Reseller Frame',
        'type': 'Official',
        'imageUrl': 'assets/images/super/reseller.svga',
        'category': 'official_frame',
        'isEquipped': _equippedMockOfficial == 'official_frame_reseller',
        'expiryDate': 'Permanent'
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Decoration",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () => context.push(AppRoutes.vipShop),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Text(
                    "Mine",
                    style: TextStyle(color: Colors.purple[700], fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Gap(4),
                  Icon(Icons.stars, color: Colors.purple[700], size: 16),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          dividerColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          indicator: const RoundedUnderlineTabIndicator(
            borderSide: BorderSide(color: Color(0xFF6366F1), width: 3),
            width: 18,
          ),
          tabs: _tabsList.map((title) => Tab(text: title)).toList(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMockWarehouse(0, _getMockIdItems(), "ID Packages"),
                _buildRealWarehouse(1, 'frame', "Avatar Frames"),
                _buildRealWarehouse(2, 'mount', "Entry Effects"),
                _buildMockWarehouse(3, _getMockApertureItems(), "Mic Waves"),
                _buildRealWarehouse(4, 'bubble', "Messages Bubbles"),
                _buildMockWarehouse(5, _getMockThemeItems(), "Profile Page Themes"),
                _buildMockWarehouse(6, _getMockCrownItems(), "Crowns"),
                _buildMockWarehouse(7, _getMockOfficialItems(), "Official Items"),
              ],
            ),
          ),
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildRealWarehouse(int tabIndex, String category, String subtitle) {
    final itemsAsync = ref.watch(warehouseItemsProvider(category));
    final user = ref.watch(currentUserProfileProvider).value;

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) return _buildEmptyState();

        _initializeSelection(tabIndex, items);
        final selectedItem = _selectedItems[tabIndex];

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.82,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = selectedItem != null && selectedItem['id'] == item['id'];
            return _buildItemCard(item, isSelected, tabIndex, category, user);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      error: (_, __) => _buildEmptyState(),
    );
  }

  Widget _buildMockWarehouse(int tabIndex, List<Map<String, dynamic>> items, String subtitle) {
    final user = ref.watch(currentUserProfileProvider).value;
    _initializeSelection(tabIndex, items);
    final selectedItem = _selectedItems[tabIndex];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedItem != null && selectedItem['id'] == item['id'];
        return _buildItemCard(item, isSelected, tabIndex, item['category'] ?? 'id', user);
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isSelected, int tabIndex, String category, UserModel? user) {
    final isEquipped = item['isEquipped'] ?? false;
    final String name = item['name'] ?? 'Elite Item';
    final String type = item['type'] ?? 'Exclusive';
    final String url = item['imageUrl'] ?? '';
    final String expiry = _resolveItemExpiry(item);

    final bool isVip = user?.isVipActive ?? false;
    final bool isVipItem = item['id'].toString().startsWith('vip_') || type == 'VIP Package';
    final bool showLock = isVipItem && !isVip;
    final int remainingDays = user?.vipRemainingDays ?? 0;
    final String displayExpiry = isVipItem && isVip ? '$remainingDays day${remainingDays == 1 ? '' : 's'}' : expiry;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedItems[tabIndex] = item;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFF3E8FF), Color(0xFFE0E7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF6366F1) 
                : (isEquipped ? Colors.purpleAccent.withOpacity(0.3) : Colors.transparent),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 36),
                child: Center(
                  child: _buildItemPreview(item, category, user),
                ),
              ),
            ),

            if (isEquipped)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Using",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

            if (isVipItem && isVip)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => _showVipRemainingDays(context, remainingDays),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 13,
                    ),
                  ),
                ),
              ),

            if (url.toLowerCase().endsWith('.svga'))
              Positioned(
                top: 10,
                right: isVipItem && isVip ? 38 : 10,
                child: GestureDetector(
                  onTap: () => _playSvgaPreview(item),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFF6366F1),
                      size: 16,
                    ),
                  ),
                ),
              ),

            if (showLock)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const Gap(4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          color: Colors.black45,
                          size: 8,
                        ),
                        const Gap(3),
                        Text(
                          displayExpiry,
                          style: TextStyle(
                            color: isVipItem && isVip ? Colors.blue.shade700 : Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildItemPreview(Map<String, dynamic> item, String category, UserModel? user) {
    final String url = item['imageUrl'] ?? '';
    final String id = item['id'] ?? '';

    if (category == 'frame') {
      if (id == 'none') {
        return CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white30,
          backgroundImage: user?.profilePhotoUrl.isNotEmpty == true 
              ? NetworkImage(user!.profilePhotoUrl) 
              : null,
          child: user?.profilePhotoUrl.isEmpty == true 
              ? const Icon(Icons.person, color: Colors.black54) 
              : null,
        );
      }
      return Center(
        child: AppAvatar(
          imageUrl: user?.profilePhotoUrl ?? '',
          frameUrl: url,
          radius: 26,
          showFrame: true,
        ),
      );
    }

    if (category == 'bubble') {
      if (id == 'none') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: const Text(
            "Default Bubble",
            style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        );
      }

      final bubblePng = getStaticFallbackPath(url, 'bubble');
      return Container(
        width: 130,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: bubblePng.startsWith('assets/')
                ? AssetImage(bubblePng) as ImageProvider
                : CachedNetworkImageProvider(bubblePng),
            fit: BoxFit.fill,
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "Hi, welcome!",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (category == 'mount') {
      if (id == 'none') {
        return const Icon(Icons.directions_run, color: Colors.black38, size: 40);
      }

      final entryPng = getStaticFallbackPath(url, 'mount');
      return Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.35),
        ),
        child: Center(
          child: Image.asset(
            entryPng,
            width: 55,
            height: 55,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.rocket_launch, color: Colors.indigo, size: 30),
          ),
        ),
      );
    }

    if (category == 'id') {
      if (id == 'none') {
        return Text(
          item['idText'] ?? '827361',
          style: const TextStyle(
            color: Colors.black38,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Text(
          item['idText'] ?? '888888',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
      );
    }

    if (category == 'aperture') {
      if (id == 'none') {
        return const Icon(Icons.mic_none, color: Colors.black26, size: 35);
      }
      if (url.toLowerCase().endsWith('.svga')) {
        return SizedBox(
          width: 70,
          height: 70,
          child: SvgaPlayer(assetPath: url, fit: BoxFit.contain),
        );
      }
      return Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: id == 'mock_aperture_1' ? Colors.amber : Colors.cyanAccent,
            width: 3.5,
          ),
          boxShadow: [
            BoxShadow(
              color: id == 'mock_aperture_1' ? Colors.amber.withOpacity(0.4) : Colors.cyanAccent.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: const Icon(Icons.person, color: Colors.grey, size: 24),
        ),
      );
    }

    if (category == 'personal_page') {
      if (id == 'none') {
        return const Icon(Icons.wallpaper, color: Colors.black26, size: 35);
      }
      return Container(
        width: 100,
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: id == 'mock_theme_1'
              ? const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)])
              : const LinearGradient(colors: [Color(0xFFF7971E), Color(0xFFFFD200)]),
        ),
        child: const Center(
          child: Icon(Icons.palette_outlined, color: Colors.white, size: 20),
        ),
      );
    }

    if (category == 'crown') {
      if (id == 'none') {
        return const Icon(Icons.workspace_premium_outlined, color: Colors.black26, size: 35);
      }
      return SizedBox(
        width: 80,
        height: 80,
        child: url.endsWith('.svga')
          ? SvgaPlayer(assetPath: url, fit: BoxFit.contain)
          : Image.asset(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 40)),
      );
    }

    if (category == 'official_frame') {
      if (id == 'none') {
        return CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white30,
          backgroundImage: user?.profilePhotoUrl.isNotEmpty == true 
              ? NetworkImage(user!.profilePhotoUrl) 
              : null,
          child: user?.profilePhotoUrl.isEmpty == true 
              ? const Icon(Icons.person, color: Colors.black54) 
              : null,
        );
      }
      return Center(
        child: AppAvatar(
          imageUrl: user?.profilePhotoUrl ?? '',
          frameUrl: url,
          radius: 26,
          showFrame: true,
        ),
      );
    }

    return const Icon(Icons.inventory_2_outlined, color: Colors.black26, size: 35);
  }

  Widget _buildBottomActionBar() {
    final activeTabIdx = _tabController.index;
    final selectedItem = _selectedItems[activeTabIdx];

    if (selectedItem == null) {
      return const SizedBox.shrink();
    }

    final isEquipped = selectedItem['isEquipped'] ?? false;
    final String category = tabIndexToCategory(activeTabIdx);
    final String id = selectedItem['id'] ?? '';

    final buttonText = isEquipped ? "Cancel" : "Use";

    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: _loadingItemId != null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ElevatedButton(
                    onPressed: () => _onActionButtonPressed(selectedItem, category),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(
                      buttonText.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _onActionButtonPressed(Map<String, dynamic> item, String category) async {
    final isEquipped = item['isEquipped'] ?? false;
    final String id = item['id'] ?? '';
    final String type = item['type'] ?? '';
    final bool isVipItem = id.startsWith('vip_') || type == 'VIP Package';

    final user = ref.read(currentUserProfileProvider).value;
    final isVip = isVipActive(user);
    final uid = ref.read(authStateProvider).value?.uid;

    if (uid == null) return;

    HapticFeedback.heavyImpact();

    if (isEquipped) {
      setState(() => _loadingItemId = id);
      try {
        if (category == 'id' || category == 'aperture' || category == 'personal_page' || category == 'crown' || category == 'official_frame') {
          setState(() {
            if (category == 'id') _equippedMockId = 'none';
            if (category == 'aperture') _equippedMockAperture = 'none';
            if (category == 'personal_page') _equippedMockTheme = 'none';
            if (category == 'crown') _equippedMockCrown = 'none';
            if (category == 'official_frame') _equippedMockOfficial = 'none';
          });
        } else {
          await ref.read(profileServiceProvider).equipItem('none', category);
        }
      } finally {
        setState(() => _loadingItemId = null);
      }
    } else {
      if (category == 'official_frame') {
        final bool isAuthorized = user?.isAdmin == true || user?.isSuperAdmin == true || user?.isAgencyOwner == true;
        if (!isAuthorized) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You do not have official authorization to use this item.")),
          );
          return;
        }
      }

      if (isVipItem && !isVip) {
        _showVipPrompt();
        return;
      }

      setState(() => _loadingItemId = id);
      try {
        if (category == 'id' || category == 'aperture' || category == 'personal_page' || category == 'crown' || category == 'official_frame') {
          setState(() {
            if (category == 'id') _equippedMockId = id;
            if (category == 'aperture') _equippedMockAperture = id;
            if (category == 'personal_page') _equippedMockTheme = id;
            if (category == 'crown') _equippedMockCrown = id;
            if (category == 'official_frame') _equippedMockOfficial = id;
          });
        } else {
          if (id.startsWith('vip_')) {
            final field = category == 'bubble' ? 'chatBubble' : (category == 'mount' ? 'entryAnimation' : 'profileFrame');
            await ref.read(profileServiceProvider).updateProfileFields(uid, {
              field: item['imageUrl'],
            });
          } else {
            await ref.read(profileServiceProvider).equipItem(id, category);
          }
        }
      } finally {
        setState(() => _loadingItemId = null);
      }
    }
  }

  void _showVipPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.stars, color: Colors.amber, size: 24),
            Gap(8),
            Text("Unlock VIP decoration", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "You need an active VIP subscription to use this decoration package. Get VIP today to access all premium frames, entry effects, and chat bubbles!",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(AppRoutes.vipShop);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Buy VIP", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVipRemainingDays(BuildContext context, int remainingDays) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 22),
            Gap(8),
            Text("VIP Subscription", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              remainingDays > 0
                  ? "Your VIP subscription has $remainingDays day${remainingDays == 1 ? '' : 's'} remaining."
                  : "Your VIP subscription has expired.",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: remainingDays > 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    remainingDays > 0 ? Icons.check_circle : Icons.cancel,
                    color: remainingDays > 0 ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      remainingDays > 0
                          ? "You can use this decoration while your VIP is active."
                          : "Renew your VIP to continue using this decoration.",
                      style: TextStyle(
                        fontSize: 12,
                        color: remainingDays > 0 ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
          ),
          if (remainingDays <= 0)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push(AppRoutes.vipShop);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Renew VIP", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  void _playSvgaPreview(Map<String, dynamic> item) {
    final String url = item['imageUrl'] ?? '';
    if (!url.toLowerCase().endsWith('.svga')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No animation preview available for this item.")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Gap(20),
              Text(
                item['name']?.toString().toUpperCase() ?? "PREVIEW",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2),
              ),
              const Gap(10),
              const Text(
                "ANIMATED PREVIEW",
                style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const Gap(40),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: SizedBox(
                    width: 230,
                    height: 230,
                    child: SvgaPlayer(
                      key: ValueKey(url),
                      assetPath: url,
                    ),
                  ),
                ),
              ),
              const Gap(40),
            ],
          ),
        );
      },
    );
  }

  String getStaticFallbackPath(String resolvedUrl, String category) {
    if (!resolvedUrl.startsWith('assets/VIP/')) return resolvedUrl;

    final level = _getVipLevelFromPath(resolvedUrl);
    if (level == 0) return resolvedUrl;

    if (category == 'frame') {
      if (level == 1) return 'assets/VIP/VIP 1/Frame.png';
      if (level == 2) return 'assets/VIP/VIP 2/VIP 2/Frame 2.png';
      if (level == 3) return 'assets/VIP/VIP 3/VIP 3/Frame 3.png';
      if (level == 4) return 'assets/VIP/VIP 4/VIP 4/Frame 4.png';
      if (level == 5) return 'assets/VIP/VIP 5/VIP 5/User Frame 5.png';
      if (level == 6) return 'assets/VIP/VIP 6/VIP 6/User Frame 6.png';
      if (level == 7) return 'assets/VIP/VIP 7/VIP 7/Frame 7.png';
      if (level == 8) return 'assets/VIP/VIP 8/VIP 8/User Frame 8.png';
    } else if (category == 'mount') {
      if (level == 1) return 'assets/VIP/VIP 1/Entry.png';
      if (level == 2) return 'assets/VIP/VIP 2/VIP 2/Entry.png';
      if (level == 3) return 'assets/VIP/VIP 3/VIP 3/Entry.png';
      if (level == 4) return 'assets/VIP/VIP 4/VIP 4/Entry.png';
      if (level == 5) return 'assets/VIP/VIP 5/VIP 5/Entry.png';
      if (level == 6) return 'assets/VIP/VIP 6/VIP 6/VIP 6 Entry.png';
      if (level == 7) return 'assets/VIP/VIP 7/VIP 7/Entry.png';
      if (level == 8) return 'assets/VIP/VIP 8/VIP 8/VIP 8 Entry Effect.png';
    } else if (category == 'bubble') {
      if (level == 1) return 'assets/VIP/VIP 1/Chat Bubble.png';
      return 'assets/VIP/VIP $level/VIP $level/Chat Bubble.png';
    }

    return resolvedUrl;
  }

  int _getVipLevelFromPath(String path) {
    final parts = path.split('/');
    for (final part in parts) {
      if (part.toLowerCase().startsWith('vip ')) {
        final numStr = part.substring(4);
        final val = int.tryParse(numStr);
        if (val != null) return val;
      } else if (part.toLowerCase().startsWith('vip') && part.length > 3) {
        final numStr = part.substring(3);
        final val = int.tryParse(numStr);
        if (val != null) return val;
      }
    }
    return 0;
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Opacity(
        opacity: 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Gap(100),
            const Icon(Icons.inventory_2_outlined, color: Colors.black26, size: 80),
            const Gap(30),
            const Text("YOUR WAREHOUSE IS EMPTY", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
            const Gap(10),
            const Text("Exclusive frames and mounts will appear here.", style: TextStyle(color: Colors.black12, fontSize: 10, fontWeight: FontWeight.bold)),
            const Gap(40),
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: () => context.push(AppRoutes.vipShop),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("SHOP NOW", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Resolves display expiry string for an item, handling expiresAt Timestamp from server
  String _resolveItemExpiry(Map<String, dynamic> item) {
    // 1. Check expiresAt (Timestamp from server-side vault entries, e.g. rocket frame)
    if (item['expiresAt'] != null) {
      final expiresAt = item['expiresAt'];
      DateTime? expiryDate;
      if (expiresAt is Timestamp) {
        expiryDate = expiresAt.toDate();
      } else if (expiresAt is String) {
        expiryDate = DateTime.tryParse(expiresAt);
      }
      if (expiryDate != null) {
        final now = DateTime.now();
        if (expiryDate.isBefore(now)) return 'Expired';
        final remaining = expiryDate.difference(now);
        if (remaining.inDays > 0) return '${remaining.inDays}d ${remaining.inHours % 24}h';
        if (remaining.inHours > 0) return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
        if (remaining.inMinutes > 0) return '${remaining.inMinutes}m';
        return 'Expiring';
      }
    }
    // 2. Fall back to expiryDate string (used by VIP/admin/mock items)
    if (item['expiryDate'] != null && (item['expiryDate'] as String).isNotEmpty) {
      return item['expiryDate'] as String;
    }
    // 3. Default
    return 'Life-time';
  }
}

class RoundedUnderlineTabIndicator extends Decoration {
  final BorderSide borderSide;
  final double width;

  const RoundedUnderlineTabIndicator({
    this.borderSide = const BorderSide(width: 3.0, color: Color(0xFF6366F1)),
    this.width = 18.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _RoundedUnderlinePainter(this, onChanged);
  }
}

class _RoundedUnderlinePainter extends BoxPainter {
  final RoundedUnderlineTabIndicator decorator;

  _RoundedUnderlinePainter(this.decorator, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final double xOffset = rect.left + (rect.width - decorator.width) / 2;
    final double yOffset = rect.bottom - decorator.borderSide.width;
    
    final Paint paint = Paint()
      ..color = decorator.borderSide.color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeWidth = decorator.borderSide.width;

    canvas.drawLine(
      Offset(xOffset, yOffset),
      Offset(xOffset + decorator.width, yOffset),
      paint,
    );
  }
}
