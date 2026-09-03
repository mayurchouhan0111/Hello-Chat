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
import '../../../../core/models/svip_level_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/svga_static_util.dart';

enum AssetAccessStatus {
  unlocked,
  lockedVip,
  lockedSvip,
  lockedOfficial,
  lockedStore,
}

class AssetAccessInfo {
  final bool isUnlocked;
  final String requirementText;
  final AssetAccessStatus status;

  const AssetAccessInfo({
    required this.isUnlocked,
    required this.requirementText,
    required this.status,
  });
}

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

  int _parseVipLevel(String vipTier) {
    final clean = vipTier.toLowerCase().replaceAll(' ', '');
    if (clean.startsWith('vip')) {
      final numStr = clean.substring(3);
      final val = int.tryParse(numStr);
      if (val != null) return val;
    }
    return 0;
  }

  int _parseSvipLevelFromItem(Map<String, dynamic> item) {
    final String id = (item['id'] ?? '').toString().toLowerCase();
    final String name = (item['name'] ?? '').toString().toLowerCase();
    final String type = (item['type'] ?? '').toString().toLowerCase();
    final String combined = '$id $name $type';

    final RegExp regex = RegExp(r'svip[_\s]?(\d)');
    final match = regex.firstMatch(combined);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    return 1;
  }

  int _parseVipLevelFromItem(Map<String, dynamic> item) {
    final String id = (item['id'] ?? '').toString().toLowerCase();
    final String name = (item['name'] ?? '').toString().toLowerCase();
    final String type = (item['type'] ?? '').toString().toLowerCase();
    final String combined = '$id $name $type';

    final RegExp regex = RegExp(r'vip[_\s]?(?:frame|entry|bubble|crown|mic_wave)?[_\s]?(\d)');
    final match = regex.firstMatch(combined);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    return 1;
  }

  AssetAccessInfo _getItemAccessInfo(Map<String, dynamic> item, UserModel? user) {
    final String id = (item['id'] ?? '').toString();
    final String name = (item['name'] ?? '').toString();
    final String type = (item['type'] ?? '').toString();
    final String category = (item['category'] ?? '').toString();

    // 1. Standard / Default Items
    if (id == 'none' || type == 'Standard' || id == 'default') {
      return const AssetAccessInfo(
        isUnlocked: true,
        requirementText: "Unlocked",
        status: AssetAccessStatus.unlocked,
      );
    }

    // 2. SVIP Package Items
    final bool isSvipItem = id.startsWith('svip') || type == 'SVIP Package' || name.contains('SVIP');
    if (isSvipItem) {
      final int requiredSvipLevel = _parseSvipLevelFromItem(item);
      final int userSvipLevel = user?.svipLevel ?? 0;
      final bool isUnlocked = userSvipLevel >= requiredSvipLevel && userSvipLevel > 0;
      return AssetAccessInfo(
        isUnlocked: isUnlocked,
        requirementText: isUnlocked ? "SVIP Level $requiredSvipLevel" : "Requires SVIP $requiredSvipLevel",
        status: isUnlocked ? AssetAccessStatus.unlocked : AssetAccessStatus.lockedSvip,
      );
    }

    // 3. VIP Package Items
    final bool isVipItem = id.startsWith('vip') || type == 'VIP Package' || name.contains('VIP');
    if (isVipItem) {
      final int requiredVipLevel = _parseVipLevelFromItem(item);
      final bool vipActive = isVipActive(user);
      final int userVipLevel = _parseVipLevel(user?.vipTier ?? '');
      final bool isUnlocked = vipActive && userVipLevel >= requiredVipLevel;
      return AssetAccessInfo(
        isUnlocked: isUnlocked,
        requirementText: isUnlocked ? "VIP Tier $requiredVipLevel" : "Requires VIP $requiredVipLevel",
        status: isUnlocked ? AssetAccessStatus.unlocked : AssetAccessStatus.lockedVip,
      );
    }

    // 4. Official Staff, CP & Prestige Ranking Items
    final bool isOfficialItem = category == 'official_frame' || type.contains('Official') || type.contains('Couple') || type.contains('Leaderboard') || type.contains('Rocket');
    if (isOfficialItem) {
      final bool isSuperAdmin = user?.isSuperAdmin == true || (user?.tags ?? []).contains('SuperAdmin');
      final bool isAdmin = user?.isAdmin == true || (user?.tags ?? []).contains('Admin');
      final bool isAgency = user?.isAgencyOwner == true || (user?.tags ?? []).contains('Agency');
      final bool isReseller = (user?.tags ?? []).contains('Reseller');
      final bool isOfficial = (user?.tags ?? []).contains('Official');
      final bool hasActiveCP = user?.partnerUid != null && user!.partnerUid!.isNotEmpty;

      bool isUnlocked = false;
      String req = "Requires Official Role";
      if (id.contains('superadmin') || name.contains('Super Admin')) {
        isUnlocked = isSuperAdmin;
        req = "SuperAdmin Role Only";
      } else if (id.contains('admin') || name.contains('Admin')) {
        isUnlocked = isAdmin || isSuperAdmin;
        req = "Admin Role Only";
      } else if (id.contains('agency') || name.contains('Agency')) {
        isUnlocked = isAgency || isSuperAdmin;
        req = "Agency Owner Only";
      } else if (id.contains('official') || name.contains('Official ID')) {
        isUnlocked = isOfficial || isSuperAdmin;
        req = "Official ID Only";
      } else if (id.contains('reseller') || name.contains('Reseller')) {
        isUnlocked = isReseller || isSuperAdmin;
        req = "Reseller Role Only";
      } else if (id.contains('cp_frame_1') || name.contains('Tier 1')) {
        isUnlocked = hasActiveCP;
        req = "Active CP Pair Required";
      } else if (id.contains('cp_frame_2') || name.contains('Tier 2')) {
        isUnlocked = hasActiveCP && (user?.cpLevel ?? 0) >= 5;
        req = "Requires CP Level 5";
      } else if (id.contains('cp_frame_3') || name.contains('Tier 3')) {
        isUnlocked = hasActiveCP && (user?.cpLevel ?? 0) >= 10;
        req = "Requires CP Level 10";
      } else if (id.contains('rocket') || name.contains('Rocket')) {
        isUnlocked = true;
        req = "Rocket Event Reward";
      } else if (id.contains('top1') || name.contains('#1')) {
        isUnlocked = isSuperAdmin || (user?.level ?? 0) >= 50;
        req = "Leaderboard Top 1 Rank";
      } else if (id.contains('top2') || name.contains('#2')) {
        isUnlocked = isSuperAdmin || (user?.level ?? 0) >= 30;
        req = "Leaderboard Top 2 Rank";
      } else if (id.contains('top3') || name.contains('#3')) {
        isUnlocked = isSuperAdmin || (user?.level ?? 0) >= 20;
        req = "Leaderboard Top 3 Rank";
      } else {
        isUnlocked = isSuperAdmin || isAdmin || isAgency || isOfficial || isReseller || hasActiveCP;
        req = "Special Privilege Required";
      }

      return AssetAccessInfo(
        isUnlocked: isUnlocked,
        requirementText: isUnlocked ? "Unlocked Privilege" : req,
        status: isUnlocked ? AssetAccessStatus.unlocked : AssetAccessStatus.lockedOfficial,
      );
    }

    // 5. Database Purchased / Vault Items
    bool isUnlocked = true;
    if (item.containsKey('isUnlocked')) {
      isUnlocked = item['isUnlocked'] == true;
    } else if (item.containsKey('isPurchased')) {
      isUnlocked = item['isPurchased'] == true;
    } else if (item.containsKey('owned')) {
      isUnlocked = item['owned'] == true;
    }

    return AssetAccessInfo(
      isUnlocked: isUnlocked,
      requirementText: isUnlocked ? "Purchased" : "Access Required",
      status: isUnlocked ? AssetAccessStatus.unlocked : AssetAccessStatus.lockedStore,
    );
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
      },
      {
        'id': 'svip1_mic_wave',
        'name': 'SVIP 1 Sound Ring',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 1/SVIP 1 Ring.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'svip1_mic_wave',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip2_mic_wave',
        'name': 'SVIP 2 Sound Ring',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 2/svip 2.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'svip2_mic_wave',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip3_mic_wave',
        'name': 'SVIP 3 Mic Wave',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 3/mic_wave_svip3.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'svip3_mic_wave',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip4_mic_wave',
        'name': 'SVIP 4 Mic Wave',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 4/mic_wave_svip4.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'svip4_mic_wave',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip5_mic_wave',
        'name': 'SVIP 5 Mic Wave',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 5/mic_wave_svip4_SVGA.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'svip5_mic_wave',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip6_mic_wave',
        'name': 'SVIP 6 Mic Wave',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/SVIP 6/SVIP 6 Sound Waives.svga',
        'category': 'aperture',
        'isEquipped': _equippedMockAperture == 'svip6_mic_wave',
        'expiryDate': '60 Days'
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
      {
        'id': 'svip1_crown',
        'name': 'SVIP 1 Crown',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 1/SVIP 1 Crown.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'svip1_crown',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip2_crown',
        'name': 'SVIP 2 Crown',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 2/SVIP 2 Crown.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'svip2_crown',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip3_crown',
        'name': 'SVIP 3 Crown',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 3/SVIP 3 Crown.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'svip3_crown',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip4_crown',
        'name': 'SVIP 4 Crown',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 4/Crown 1_SVGA.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'svip4_crown',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip5_crown',
        'name': 'SVIP 5 Crown',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/svip 5/Crown 1_SVGA_SVGA.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'svip5_crown',
        'expiryDate': '60 Days'
      },
      {
        'id': 'svip6_crown',
        'name': 'SVIP 6 Crown',
        'type': 'SVIP Package',
        'imageUrl': 'assets/SVIP Kit/SVIP 6/VIP 8 Crown.svga',
        'category': 'crown',
        'isEquipped': _equippedMockCrown == 'svip6_crown',
        'expiryDate': '60 Days'
      }
    ];
  }

  List<Map<String, dynamic>> _getMockOfficialItems(UserModel? user) {
    final String equippedFrame = user?.profileFrame ?? '';
    final bool isNoneEquipped = equippedFrame.isEmpty || equippedFrame.toLowerCase() == 'none';
    final bool hasActiveCP = user?.partnerUid != null && user!.partnerUid!.isNotEmpty;

    final Map<String, String> adminFrames = ref.watch(adminFramesProvider).value ?? {};

    final List<Map<String, dynamic>> list = [
      {
        'id': 'none',
        'name': 'Default Frame',
        'type': 'Standard',
        'imageUrl': '',
        'category': 'official_frame',
        'isEquipped': isNoneEquipped && _equippedMockOfficial == 'none',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'official_frame_super',
        'name': 'Super Admin Frame',
        'type': 'Official',
        'imageUrl': adminFrames['super-admin'] ?? 'assets/Helo chat/Superadmin.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == (adminFrames['super-admin'] ?? 'assets/Helo chat/Superadmin.svga') || _equippedMockOfficial == 'official_frame_super',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'official_frame_admin',
        'name': 'Admin Frame',
        'type': 'Official',
        'imageUrl': adminFrames['admin'] ?? 'assets/images/super/admin.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == (adminFrames['admin'] ?? 'assets/images/super/admin.svga') || _equippedMockOfficial == 'official_frame_admin',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'official_frame_agency',
        'name': 'Agency Frame',
        'type': 'Official',
        'imageUrl': adminFrames['agency'] ?? 'assets/Helo chat/Agency.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == (adminFrames['agency'] ?? 'assets/Helo chat/Agency.svga') || _equippedMockOfficial == 'official_frame_agency',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'official_frame_official',
        'name': 'Official ID Frame',
        'type': 'Official',
        'imageUrl': adminFrames['official'] ?? 'assets/Helo chat/Official.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == (adminFrames['official'] ?? 'assets/Helo chat/Official.svga') || _equippedMockOfficial == 'official_frame_official',
        'expiryDate': 'Permanent'
      },
      {
        'id': 'official_frame_reseller',
        'name': 'Reseller Frame',
        'type': 'Official',
        'imageUrl': adminFrames['reseller'] ?? 'assets/images/super/reseller.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == (adminFrames['reseller'] ?? 'assets/images/super/reseller.svga') || _equippedMockOfficial == 'official_frame_reseller',
        'expiryDate': 'Permanent'
      },
    ];

    // Restrict visibility: CP Frames are ONLY shown if user has an active CP
    if (hasActiveCP) {
      list.addAll([
        {
          'id': 'cp_frame_1',
          'name': 'CP Eternal Love (Tier 1)',
          'type': 'Couple Pair',
          'imageUrl': adminFrames['cp'] ?? 'assets/Helo chat/1.svga',
          'category': 'official_frame',
          'isEquipped': equippedFrame == (adminFrames['cp'] ?? 'assets/Helo chat/1.svga') || _equippedMockOfficial == 'cp_frame_1',
          'expiryDate': 'Active CP'
        },
        {
          'id': 'cp_frame_2',
          'name': 'CP Golden Romance (Tier 2)',
          'type': 'Couple Pair',
          'imageUrl': 'assets/Helo chat/2.svga',
          'category': 'official_frame',
          'isEquipped': equippedFrame == 'assets/Helo chat/2.svga' || _equippedMockOfficial == 'cp_frame_2',
          'expiryDate': 'CP Lv. 5'
        },
        {
          'id': 'cp_frame_3',
          'name': 'CP Royal Heart (Tier 3)',
          'type': 'Couple Pair',
          'imageUrl': 'assets/Helo chat/3.svga',
          'category': 'official_frame',
          'isEquipped': equippedFrame == 'assets/Helo chat/3.svga' || _equippedMockOfficial == 'cp_frame_3',
          'expiryDate': 'CP Lv. 10'
        },
      ]);
    }

    list.addAll([
      {
        'id': 'rocket_frame_launch',
        'name': 'Rocket Launch Frame',
        'type': 'Rocket Event',
        'imageUrl': 'assets/Helo chat/Rockeet_SVGA.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == 'assets/Helo chat/Rockeet_SVGA.svga' || _equippedMockOfficial == 'rocket_frame_launch',
        'expiryDate': 'Special Event'
      },
      {
        'id': 'leaderboard_top1',
        'name': 'Champion Crown (#1)',
        'type': 'Leaderboard',
        'imageUrl': 'assets/Helo chat/Top 1.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == 'assets/Helo chat/Top 1.svga' || _equippedMockOfficial == 'leaderboard_top1',
        'expiryDate': 'Rank #1'
      },
      {
        'id': 'leaderboard_top2',
        'name': 'Runner-Up Crown (#2)',
        'type': 'Leaderboard',
        'imageUrl': 'assets/Helo chat/Top 2.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == 'assets/Helo chat/Top 2.svga' || _equippedMockOfficial == 'leaderboard_top2',
        'expiryDate': 'Rank #2'
      },
      {
        'id': 'leaderboard_top3',
        'name': 'Bronze Elite (#3)',
        'type': 'Leaderboard',
        'imageUrl': 'assets/Helo chat/Top 3.svga',
        'category': 'official_frame',
        'isEquipped': equippedFrame == 'assets/Helo chat/Top 3.svga' || _equippedMockOfficial == 'leaderboard_top3',
        'expiryDate': 'Rank #3'
      },
    ]);

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
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
                _PropWarehouseTabPage(child: _buildMockWarehouse(0, _getMockIdItems(), "ID Packages")),
                _PropWarehouseTabPage(child: _buildRealWarehouse(1, 'frame', "Avatar Frames")),
                _PropWarehouseTabPage(child: _buildRealWarehouse(2, 'mount', "Entry Effects")),
                _PropWarehouseTabPage(child: _buildMockWarehouse(3, _getMockApertureItems(), "Mic Waves")),
                _PropWarehouseTabPage(child: _buildRealWarehouse(4, 'bubble', "Messages Bubbles")),
                _PropWarehouseTabPage(child: _buildMockWarehouse(5, _getMockThemeItems(), "Profile Page Themes")),
                _PropWarehouseTabPage(child: _buildMockWarehouse(6, _getMockCrownItems(), "Crowns")),
                _PropWarehouseTabPage(child: _buildMockWarehouse(7, _getMockOfficialItems(user), "Official Items")),
              ],
            ),
          ),
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSvipWarehouseItems(String category, int svipLevel, UserModel? user) {
    final List<Map<String, dynamic>> items = [];

    if (category == 'frame') {
      final String equippedFrame = user?.profileFrame ?? '';
      items.add({
        'id': 'none',
        'name': 'Default Frame',
        'type': 'Standard',
        'imageUrl': '',
        'category': 'frame',
        'isEquipped': equippedFrame.isEmpty || equippedFrame.toLowerCase() == 'none',
        'expiryDate': 'Permanent'
      });
      for (int i = 1; i <= 6; i++) {
        final svipModel = SVIPLevelModel.getLevelByTier(i);
        final asset = svipModel.frameAsset;
        items.add({
          'id': 'svip_${i}_frame',
          'name': 'SVIP $i Frame',
          'type': 'SVIP Package',
          'imageUrl': asset,
          'category': 'frame',
          'isEquipped': equippedFrame == asset,
          'expiryDate': '60 Days'
        });
      }
    } else if (category == 'mount') {
      final String equippedEntry = user?.entryAnimation ?? '';
      items.add({
        'id': 'none',
        'name': 'Default Entry',
        'type': 'Standard',
        'imageUrl': '',
        'category': 'mount',
        'isEquipped': equippedEntry.isEmpty || equippedEntry.toLowerCase() == 'none',
        'expiryDate': 'Permanent'
      });
      for (int i = 1; i <= 6; i++) {
        final svipModel = SVIPLevelModel.getLevelByTier(i);
        final asset = svipModel.entryAnimationAsset;
        items.add({
          'id': 'svip_${i}_entry',
          'name': 'SVIP $i Entry',
          'type': 'SVIP Package',
          'imageUrl': asset,
          'category': 'mount',
          'isEquipped': equippedEntry == asset,
          'expiryDate': '60 Days'
        });
      }
    }
    return items;
  }

  Widget _buildRealWarehouse(int tabIndex, String category, String subtitle) {
    final itemsAsync = ref.watch(warehouseItemsProvider(category));
    final user = ref.watch(currentUserProfileProvider).value;
    final svipLevel = user?.svipLevel ?? 0;
    final svipItems = _getSvipWarehouseItems(category, svipLevel, user);

    return itemsAsync.when(
      data: (vaultItems) {
        final Map<String, Map<String, dynamic>> combinedMap = {};
        for (var item in svipItems) {
          combinedMap[item['id']] = item;
        }
        for (var item in vaultItems) {
          combinedMap[item['id']] = item;
        }
        final items = combinedMap.values.toList();

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
      error: (_, __) {
        if (svipItems.isNotEmpty) {
          _initializeSelection(tabIndex, svipItems);
          final selectedItem = _selectedItems[tabIndex];
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.82,
            ),
            itemCount: svipItems.length,
            itemBuilder: (context, index) {
              final item = svipItems[index];
              final isSelected = selectedItem != null && selectedItem['id'] == item['id'];
              return _buildItemCard(item, isSelected, tabIndex, category, user);
            },
          );
        }
        return _buildEmptyState();
      },
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
    final access = _getItemAccessInfo(item, user);
    final isEquipped = item['isEquipped'] ?? false;
    final String name = item['name'] ?? 'Elite Item';
    final String url = item['imageUrl'] ?? '';
    final String expiry = _resolveItemExpiry(item);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedItems[tabIndex] = item;
          });
        },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: access.isUnlocked
              ? const LinearGradient(
                  colors: [Color(0xFFF3E8FF), Color(0xFFE0E7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade200, Colors.grey.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: isSelected 
                ? (access.isUnlocked ? const Color(0xFF6366F1) : Colors.amber.shade800) 
                : (isEquipped ? Colors.purpleAccent.withOpacity(0.3) : Colors.transparent),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: (access.isUnlocked ? const Color(0xFF6366F1) : Colors.amber.shade800).withOpacity(0.2),
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
            // Preview Image Container with lock dimming
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 36),
                child: Center(
                  child: Opacity(
                    opacity: access.isUnlocked ? 1.0 : 0.60,
                    child: _buildItemPreview(item, category, user),
                  ),
                ),
              ),
            ),

            // Top Left: "Using" Badge if equipped
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

            // Top Right: Lock Badge if locked
            if (!access.isUnlocked)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.shade700.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: Colors.white, size: 10),
                      Gap(3),
                      Text(
                        "LOCKED",
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),

            // SVGA Preview Play Button
            if (url.toLowerCase().endsWith('.svga'))
              Positioned(
                top: 10,
                left: isEquipped ? 54 : 10,
                child: GestureDetector(
                  onTap: () => _playSvgaPreview(item),
                  child: Container(
                    width: 24,
                    height: 24,
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
                      size: 15,
                    ),
                  ),
                ),
              ),

            // Bottom Name and Expiry / Access Requirement Pill
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: access.isUnlocked ? Colors.black87 : Colors.grey.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const Gap(4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: access.isUnlocked 
                          ? Colors.black.withOpacity(0.06)
                          : Colors.amber.shade100.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: access.isUnlocked ? null : Border.all(color: Colors.amber.shade400, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          access.isUnlocked ? Icons.access_time_filled : Icons.lock_outline_rounded,
                          color: access.isUnlocked ? Colors.black45 : Colors.amber.shade900,
                          size: 9,
                        ),
                        const Gap(3),
                        Flexible(
                          child: Text(
                            access.isUnlocked ? expiry : access.requirementText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: access.isUnlocked ? Colors.black54 : Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
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
    ),
  );
}

  Widget _buildItemPreview(Map<String, dynamic> item, String category, UserModel? user) {
    final String url = item['imageUrl'] ?? '';
    final String id = item['id'] ?? '';
    final String staticUrl = getStaticFallbackPath(url, category);

    if (category == 'frame' || category == 'official_frame') {
      if (id == 'none' || url.isEmpty) {
        return CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white30,
          backgroundImage: user?.profilePhotoUrl.isNotEmpty == true 
              ? CachedNetworkImageProvider(user!.profilePhotoUrl) 
              : null,
          child: user?.profilePhotoUrl.isEmpty == true 
              ? const Icon(Icons.person, color: Colors.black54) 
              : null,
        );
      }
      return RepaintBoundary(
        child: Center(
          child: AppAvatar(
            imageUrl: user?.profilePhotoUrl ?? '',
            frameUrl: url.isNotEmpty ? url : staticUrl,
            radius: 26,
            showFrame: true,
            staticFrame: true,
          ),
        ),
      );
    }

    if (category == 'bubble') {
      if (id == 'none' || url.isEmpty) {
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
      final bool isStaticImage = bubblePng.endsWith('.png') || bubblePng.endsWith('.webp') || bubblePng.endsWith('.jpg') || bubblePng.endsWith('.jpeg');

      if (isStaticImage) {
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

      return Container(
        width: 130,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
          ],
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
      if (id == 'none' || url.isEmpty) {
        return const Icon(Icons.directions_run, color: Colors.black38, size: 40);
      }

      final entryPng = getStaticFallbackPath(url, 'mount');
      if (entryPng.endsWith('.png') || entryPng.endsWith('.webp') || entryPng.endsWith('.jpg')) {
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

      if (url.toLowerCase().endsWith('.svga')) {
        return RepaintBoundary(
          child: SizedBox(
            width: 75,
            height: 75,
            child: SvgaPlayer(key: ValueKey(url), assetPath: url, fit: BoxFit.contain),
          ),
        );
      }

      return Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.indigo.withOpacity(0.12),
        ),
        child: const Center(
          child: Icon(Icons.rocket_launch_rounded, color: Color(0xFF6366F1), size: 36),
        ),
      );
    }

    if (category == 'id') {
      if (id == 'none' || url.isEmpty) {
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
      if (id == 'none' || url.isEmpty) {
        return const Icon(Icons.mic_none, color: Colors.black26, size: 35);
      }
      final staticAperture = getStaticFallbackPath(url, 'aperture');
      final bool isStatic = staticAperture.endsWith('.png') || staticAperture.endsWith('.webp') || staticAperture.endsWith('.jpg');
      return Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF6366F1),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: isStatic
              ? Image.asset(
                  staticAperture,
                  width: 45,
                  height: 45,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.graphic_eq_rounded, color: Color(0xFF6366F1), size: 24),
                )
              : const Icon(Icons.graphic_eq_rounded, color: Color(0xFF6366F1), size: 24),
        ),
      );
    }

    if (category == 'personal_page') {
      if (id == 'none' || url.isEmpty) {
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
      if (id == 'none' || url.isEmpty) {
        return const Icon(Icons.workspace_premium_outlined, color: Colors.black26, size: 35);
      }
      final crownPng = getStaticFallbackPath(url, 'crown');
      if (crownPng.endsWith('.png') || crownPng.endsWith('.webp') || crownPng.endsWith('.jpg')) {
        return Image.asset(
          crownPng,
          width: 65,
          height: 65,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 40),
        );
      }
      if (url.toLowerCase().endsWith('.svga')) {
        return RepaintBoundary(
          child: SizedBox(
            width: 65,
            height: 65,
            child: SvgaPlayer(key: ValueKey(url), assetPath: url, fit: BoxFit.contain),
          ),
        );
      }
      return const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 42);
    }

    return const Icon(Icons.inventory_2_outlined, color: Colors.black26, size: 35);
  }

  Widget _buildBottomActionBar() {
    final activeTabIdx = _tabController.index;
    final selectedItem = _selectedItems[activeTabIdx];

    if (selectedItem == null) {
      return const SizedBox.shrink();
    }

    final user = ref.watch(currentUserProfileProvider).value;
    final access = _getItemAccessInfo(selectedItem, user);
    final isEquipped = selectedItem['isEquipped'] ?? false;
    final String category = tabIndexToCategory(activeTabIdx);

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
                    gradient: access.isUnlocked
                        ? const LinearGradient(
                            colors: [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : LinearGradient(
                            colors: [Colors.amber.shade700, Colors.deepOrange.shade600],
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!access.isUnlocked) ...[
                          const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                          const Gap(8),
                        ],
                        Text(
                          access.isUnlocked
                              ? (isEquipped ? "CANCEL" : "USE")
                              : access.requirementText.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _onActionButtonPressed(Map<String, dynamic> item, String category) async {
    final user = ref.read(currentUserProfileProvider).value;
    final access = _getItemAccessInfo(item, user);

    HapticFeedback.heavyImpact();

    // 🔒 RESTRICT EQUIPPING IF LOCKED / NOT AUTHORIZED
    if (!access.isUnlocked) {
      _showAccessRequiredDialog(item, access);
      return;
    }

    final isEquipped = item['isEquipped'] ?? false;
    final String id = item['id'] ?? '';
    final uid = ref.read(authStateProvider).value?.uid;

    if (uid == null) return;

    // Map category to the exact Firestore UserModel field
    final Map<String, String> fieldMap = {
      'frame': 'profileFrame',
      'official_frame': 'profileFrame',
      'mount': 'entryAnimation',
      'bubble': 'chatBubble',
      'aperture': 'equippedMicWave',
      'crown': 'equippedCrown',
      'personal_page': 'profileTheme',
      'id': 'prettyId',
    };
    final String targetField = fieldMap[category] ?? category;

    setState(() => _loadingItemId = id);
    try {
      if (isEquipped) {
        // UNEQUIP ITEM
        setState(() {
          if (category == 'id') _equippedMockId = 'none';
          if (category == 'aperture') _equippedMockAperture = 'none';
          if (category == 'personal_page') _equippedMockTheme = 'none';
          if (category == 'crown') _equippedMockCrown = 'none';
          if (category == 'official_frame') _equippedMockOfficial = 'none';
        });

        final unequipMap = <String, dynamic>{
          targetField: '',
        };
        if (category == 'crown') {
          unequipMap['badgeIcon'] = '';
          unequipMap['equippedCrown'] = '';
        }
        await ref.read(profileServiceProvider).updateProfileFields(uid, unequipMap);
        await ref.read(profileServiceProvider).equipItem('none', category);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.remove_circle_outline_rounded, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Removed ${item['name'] ?? 'Decoration'}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // EQUIP ITEM
        final String itemUrl = (item['imageUrl'] ?? '').toString();
        final String valueToSave = itemUrl.isNotEmpty ? itemUrl : id;

        setState(() {
          if (category == 'id') _equippedMockId = id;
          if (category == 'aperture') _equippedMockAperture = id;
          if (category == 'personal_page') _equippedMockTheme = id;
          if (category == 'crown') _equippedMockCrown = id;
          if (category == 'official_frame') _equippedMockOfficial = id;
        });

        final equipMap = <String, dynamic>{
          targetField: valueToSave,
        };
        if (category == 'crown') {
          equipMap['badgeIcon'] = valueToSave;
          equipMap['equippedCrown'] = valueToSave;
        }
        await ref.read(profileServiceProvider).updateProfileFields(uid, equipMap);
        await ref.read(profileServiceProvider).equipItem(valueToSave, category);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Applied ${item['name'] ?? 'Decoration'} successfully!",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update decoration: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.invalidate(currentUserProfileProvider);
        setState(() => _loadingItemId = null);
      }
    }
  }

  void _showAccessRequiredDialog(Map<String, dynamic> item, AssetAccessInfo access) {
    String title = "Access Required";
    String description = "You do not have access to equip this item. Access must be unlocked before it can be used.";
    String buttonText = "OK";
    VoidCallback? onAction;

    if (access.status == AssetAccessStatus.lockedSvip) {
      title = "SVIP Privilege Required";
      description = "This item requires ${access.requirementText}. Visit the SVIP Center to upgrade your tier and unlock exclusive perks!";
      buttonText = "SVIP CENTER";
      onAction = () => context.push(AppRoutes.svipPrivileges);
    } else if (access.status == AssetAccessStatus.lockedVip) {
      title = "VIP Subscription Required";
      description = "This decoration package requires ${access.requirementText}. Subscribe to VIP to gain instant access to premium frames, badges, and entry effects!";
      buttonText = "GET VIP";
      onAction = () => context.push(AppRoutes.vipShop);
    } else if (access.status == AssetAccessStatus.lockedOfficial) {
      title = "Official Staff Restricted";
      description = "This item is reserved exclusively for official staff members (${access.requirementText}). Standard accounts cannot equip official badges.";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: Colors.amber.shade700, size: 24),
            const Gap(10),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
          ),
          if (onAction != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                onAction!();
              },
              child: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
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
    return SvgaStaticUtil.staticPathForSvga(resolvedUrl, category: category);
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

class _PropWarehouseTabPage extends StatefulWidget {
  final Widget child;
  const _PropWarehouseTabPage({required this.child});

  @override
  State<_PropWarehouseTabPage> createState() => _PropWarehouseTabPageState();
}

class _PropWarehouseTabPageState extends State<_PropWarehouseTabPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
