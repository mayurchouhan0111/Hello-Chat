import 'package:flutter/material.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/models/room_theme_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import 'administrator_sheet.dart';
import 'room_music_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';

class RoomSettingsSheet extends ConsumerStatefulWidget {
  final RoomModel room;
  const RoomSettingsSheet({super.key, required this.room});

  @override
  ConsumerState<RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends ConsumerState<RoomSettingsSheet> {
  late TextEditingController _nameController;
  late TextEditingController _noticeController;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _noticeController = TextEditingController(text: widget.room.notice);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noticeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(String roomId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _isUploadingImage = true);
      try {
        final coverUrl = await ref.read(cloudinaryServiceProvider).uploadImage(pickedFile.path);
        await _update(roomId, "coverUrl", coverUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Cover image updated successfully!")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Upload failed: $e")));
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _update(String roomId, String field, dynamic value) async {
    try {
      await ref.read(roomServiceProvider).updateRoomSettings(roomId, {field: value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Error: $e")));
      }
    }
  }

  void _showPasswordDialog(RoomModel room) {
    final controller = TextEditingController(text: room.passwordHash);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Room Password"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new password (empty to unlock)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final pwd = controller.text.trim();
              await _update(room.roomId, "passwordHash", pwd);
              await _update(room.roomId, "isPrivate", pwd.isNotEmpty);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Set"),
          ),
        ],
      ),
    );
  }

  void _showCapacityDialog(RoomModel room) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: kRoomCapacityOptions.map((cap) => ListTile(
            title: Text("$cap Seats"),
            onTap: () async {
              await _update(room.roomId, "capacity", cap);
              if (mounted) Navigator.pop(sheetContext);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showMicModeDialog(RoomModel room) {
     showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["Free", "Lock"].map((mode) => ListTile(
            title: Text(mode),
            onTap: () async {
              await _update(room.roomId, "micMode", mode.toLowerCase());
              if (mounted) Navigator.pop(sheetContext);
            },
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.room.roomId));
    
    return roomAsync.when(
      data: (room) {
        if (room == null) return const Center(child: Text("Room not found"));
        final isOwner = uid != null && uid == room.ownerUid;
        final isAdmin = uid != null && (room.isUserAdmin(uid) || room.admins.contains(uid));
        if (!isOwner && !isAdmin) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Gap(12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
              const Gap(8),
              const Text("Room Setting", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Gap(16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(room.coverUrl.isEmpty ? "https://picsum.photos/seed/${room.roomId}/200" : room.coverUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () => _pickAndUploadImage(room.roomId), 
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: _isUploadingImage
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(24),
                      
                      _buildLabel("Room Name"),
                      _buildTextField(_nameController, "name", room.roomId),
                      const Gap(16),
                      
                      _buildLabel("Room Notice"),
                      _buildTextField(_noticeController, "notice", room.roomId),
                      const Gap(12),

                      _buildSettingRow("Room Welcome Message", 
                        value: room.welcomeMessage.isNotEmpty ? room.welcomeMessage : "",
                        onTap: () {
                          Navigator.pop(context);
                          context.push(AppRoutes.roomWelcomeMessage, extra: room);
                        },
                      ),
                      const Gap(12),
                      
                      _buildSettingRow("Mic mode", 
                        value: room.micMode.capitalize(), 
                        onTap: () => _showMicModeDialog(room)
                      ),
                      _buildSettingRow("Wheat mode (Capacity)", 
                        value: "${room.capacity} seats", 
                        onTap: () => _showCapacityDialog(room)
                      ),
                      _buildSettingRow("Background Music", 
                        value: room.backgroundMusic ? "ON" : "OFF",
                        onTap: () => _update(room.roomId, "backgroundMusic", !room.backgroundMusic)
                      ),
                      _buildSettingRow("Public Screen Setting", value: "Standard"),
                      
                      const Gap(30),
                      
                      SizedBox(
                        height: 80,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            if (room.ownerUid == uid || room.admins.contains(uid)) ...[
                              _buildBottomAction(
                                Icons.cleaning_services_rounded,
                                "Clear Chat",
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E1E1E),
                                      title: const Text("Clear Room Messages", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      content: const Text(
                                        "Are you sure you want to clear all displayed chat messages for everyone in this room?",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text("Clear", style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    final r = roomAsync.value;
                                    if (r == null) return;
                                    await ref.read(roomServiceProvider).clearRoomMessages(r.roomId);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("All room messages cleared!")),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                            ],
                            _buildBottomAction(Icons.image_outlined, "Theme", onTap: () => _showThemePicker(room)),
                            if (room.ownerUid == uid || room.admins.contains(uid)) ...[
                              const SizedBox(width: 6),
                              _buildBottomAction(
                                Icons.music_note_rounded, 
                                "Music", 
                                onTap: () {
                                  Navigator.pop(context);
                                  _showMusicSheet(room);
                                }
                              ),
                            ],
                            const SizedBox(width: 6),
                            _buildBottomAction(
                              room.isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded, 
                              "Lock", 
                              onTap: () => _showPasswordDialog(room)
                            ),
                            if (room.ownerUid == uid) ...[
                              const SizedBox(width: 6),
                              _buildBottomAction(Icons.admin_panel_settings_outlined, "Admin", onTap: () => _showAdminPanel(room)),
                            ],
                            if (room.bannedUids.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _buildBottomAction(Icons.block, "Bans", onTap: () => _showBannedUsers(room)),
                            ],
                          ],
                        ),
                      ),
                      const Gap(40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
      error: (e, __) => Center(child: Text("Error: $e")),
    );
  }

  void _showThemePicker(RoomModel room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DefaultTabController(
        length: 3,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF141729), Color(0xFF0A0C16)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(12),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.palette_rounded, color: Color(0xFF818CF8), size: 18),
                      ),
                      const Gap(10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Room Background Theme",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Gap(2),
                          Text(
                            "Ambient visual style (Cover photo remains untouched)",
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const Gap(14),

              // Segmented Tabs
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1E34),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.brush_rounded, size: 14),
                          Gap(6),
                          Text("Normal"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFD700)),
                          Gap(6),
                          Text("Luxury VIP"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded, size: 14, color: Color(0xFF38BDF8)),
                          Gap(6),
                          Text("Official"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(14),

              // Grids
              Expanded(
                child: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildThemeGrid(room, RoomThemeCatalog.normalThemes, sheetContext),
                    _buildThemeGrid(room, RoomThemeCatalog.luxuryThemes, sheetContext),
                    _buildThemeGrid(room, RoomThemeCatalog.officialThemes, sheetContext),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeGrid(RoomModel room, List<RoomTheme> themes, BuildContext sheetContext) {
    final activeThemeId = room.theme.toLowerCase();

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final t = themes[index];
        final isSelected = activeThemeId == t.id.toLowerCase() || activeThemeId == t.name.toLowerCase();

        final Color borderColor = isSelected
            ? const Color(0xFFFFD700)
            : (t.category == RoomThemeCategory.official
                ? const Color(0xFF38BDF8).withValues(alpha: 0.35)
                : (t.isLuxury
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.12)));

        return GestureDetector(
          onTap: () async {
            // Theme selection updates theme & backgroundUrl ONLY. Cover photo is 100% separate.
            final chosenAsset = t.assetPath ?? t.imageUrl ?? '';
            await _update(room.roomId, "theme", t.id);
            await _update(room.roomId, "backgroundUrl", chosenAsset);
            if (mounted) {
              Navigator.pop(sheetContext);
              AppToast.showSuccess(
                context,
                "Applied ${t.name} ambient theme",
                title: "Theme Updated ✨",
              );
            }
          },
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    gradient: LinearGradient(
                      colors: t.gradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      if (isSelected)
                        const BoxShadow(
                          color: Color(0x77FFD700),
                          blurRadius: 12,
                          spreadRadius: 1,
                          offset: Offset(0, 2),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Wallpaper Preview (Local Asset takes priority)
                      if (t.assetPath != null && t.assetPath!.isNotEmpty)
                        Positioned.fill(
                          child: Image.asset(
                            t.assetPath!,
                            fit: BoxFit.cover,
                            cacheWidth: 320,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: t.gradient,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (t.imageUrl != null && t.imageUrl!.isNotEmpty)
                        Positioned.fill(
                          child: Image.network(
                            t.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: t.gradient,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Vignette Gradient on bottom of card
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),

                      // Badge Indicator
                      if (t.badge != null)
                        Positioned(
                          top: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: t.category == RoomThemeCategory.official
                                    ? [const Color(0xFF0284C7), const Color(0xFF0369A1)]
                                    : [const Color(0xFFFFD700), const Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                            child: Text(
                              t.badge!,
                              style: TextStyle(
                                color: t.category == RoomThemeCategory.official ? Colors.white : Colors.black87,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),

                      // Active Selected Checkmark
                      if (isSelected)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded, size: 12, color: Colors.black87),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Gap(6),
              Text(
                t.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      width: 0.6,
                    ),
                  ),
                  child: const Text(
                    "ACTIVE",
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showMusicSheet(RoomModel room) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isAdmin = room.ownerUid == uid || room.admins.contains(uid);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoomMusicSheet(room: room, isAdmin: isAdmin),
    );
  }

  void _showAdminPanel(RoomModel room) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (room.ownerUid != uid) {
      ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Only the room owner can manage administrators")),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AdministratorSheet(room: room),
    );
  }

  void _showBannedUsers(RoomModel room) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = room.ownerUid == uid;
    final isAdmin = room.admins.contains(uid);
    if (!isOwner && !isAdmin) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const Gap(12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            const Gap(16),
            Text("Banned Users (${room.bannedUids.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Gap(4),
            Text("Permanent bans shown without expiry", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const Gap(12),
            Expanded(
              child: room.bannedUids.isEmpty
                ? Center(child: Text("No banned users", style: TextStyle(color: Colors.grey[400])))
                : ListView.builder(
                    itemCount: room.bannedUids.length,
                    itemBuilder: (context, index) {
                      final buid = room.bannedUids[index];
                      final expiry = room.banExpiries?[buid];
                      final expiryDate = expiry != null ? (expiry as dynamic).toDate() as DateTime? : null;
                      final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
                      final expiryStr = expiryDate != null
                        ? (isExpired ? "Expired" : "Expires: ${_formatBanExpiry(expiryDate)}")
                        : "Permanent";

                      return Consumer(
                        builder: (context, ref, child) {
                          final userAsync = ref.watch(userProfileProvider(buid));
                          return userAsync.when(
                            data: (user) {
                              final displayName = user?.displayName ?? "User";
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    (user?.profilePhotoUrl ?? "").isNotEmpty
                                      ? user!.profilePhotoUrl
                                      : 'https://picsum.photos/seed/$buid/100'
                                  ),
                                ),
                                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(expiryStr, style: TextStyle(fontSize: 12, color: isExpired ? Colors.green : Colors.red[400])),
                                trailing: IconButton(
                                  icon: const Icon(Icons.person_remove_alt_1, color: Colors.orange),
                                  onPressed: () async {
                                    await ref.read(roomServiceProvider).unbanUser(room.roomId, buid);
                                    if (sheetContext.mounted) {
                                      ScaffoldMessenger.of(sheetContext).showSnackBar(TopSnackBar(context: sheetContext, content: Text("$displayName unbanned"))
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                            loading: () => ListTile(
                              leading: const CircleAvatar(child: CircularProgressIndicator()),
                              title: const Text("Loading..."),
                            ),
                            error: (_, __) => ListTile(
                              title: Text("User: $buid"),
                              subtitle: Text(expiryStr),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove_alt_1, color: Colors.orange),
                                onPressed: () async {
                                  await ref.read(roomServiceProvider).unbanUser(room.roomId, buid);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBanExpiry(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h ${diff.inMinutes % 60}m";
    return "${diff.inDays}d ${diff.inHours % 24}h";
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String field, String roomId) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
        onSubmitted: (val) => _update(roomId, field, val.trim()),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          suffixIcon: IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.primary),
            onPressed: () {
              FocusScope.of(context).unfocus();
              _update(roomId, field, controller.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(TopSnackBar(context: context, content: Text("Updated successfully!")));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, {String? value, VoidCallback? onTap}) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) 
                Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w900)),
              const Gap(4),
              const Icon(Icons.chevron_right_rounded, color: Colors.black12),
            ],
          ),
          onTap: onTap,
        ),
        const Divider(height: 1, color: Colors.black12),
      ],
    );
  }

  Widget _buildBottomAction(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const Gap(6),
            Text(
              label, 
              style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold), 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
