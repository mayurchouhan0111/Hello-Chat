import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/models/room_theme_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/constants/app_colors.dart';
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cover image updated successfully!")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
                            _buildBottomAction(Icons.cleaning_services_rounded, "Clear Screen", onTap: () async {
                               final room = roomAsync.value;
                               if (room == null) return;
                               await ref.read(roomServiceProvider).clearRoomMessages(room.roomId);
                               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat cleared!")));
                            }),
                            const SizedBox(width: 6),
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
        length: 2,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Gap(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Room Background Theme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const Text(
                "Customize the ambient room background. Cover photo remains untouched.",
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const Gap(14),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black87,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: "Normal Themes"),
                    Tab(text: "✨ Luxury Themes"),
                  ],
                ),
              ),
              const Gap(16),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildThemeGrid(room, RoomThemeCatalog.normalThemes, sheetContext),
                    _buildThemeGrid(room, RoomThemeCatalog.luxuryThemes, sheetContext),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final t = themes[index];
        final isSelected = activeThemeId == t.id.toLowerCase() || activeThemeId == t.name.toLowerCase();

        return GestureDetector(
          onTap: () async {
            // Theme selection updates theme & backgroundUrl ONLY. Cover photo is 100% separate.
            await _update(room.roomId, "theme", t.id);
            await _update(room.roomId, "backgroundUrl", t.imageUrl ?? t.assetPath ?? '');
            if (mounted) {
              Navigator.pop(sheetContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Theme updated: ${t.name}"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFFD700) : (t.isLuxury ? Colors.amber.withOpacity(0.4) : Colors.black12),
                      width: isSelected ? 3 : 1,
                    ),
                    gradient: LinearGradient(
                      colors: t.gradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: isSelected
                        ? [const BoxShadow(color: Color(0x66FFD700), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (t.assetPath != null && t.assetPath!.isNotEmpty)
                        Positioned.fill(
                          child: Image.asset(t.assetPath!, fit: BoxFit.cover),
                        )
                      else if (t.imageUrl != null && t.imageUrl!.isNotEmpty)
                        Positioned.fill(
                          child: Image.network(t.imageUrl!, fit: BoxFit.cover),
                        ),
                      if (t.isLuxury)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "LUXURY",
                              style: TextStyle(color: Colors.black87, fontSize: 8, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 12, color: Colors.black87),
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only the room owner can manage administrators")),
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
                                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                                        SnackBar(content: Text("$displayName unbanned"))
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated successfully!")));
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
