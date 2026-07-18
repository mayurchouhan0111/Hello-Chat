import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import 'administrator_sheet.dart';
import 'room_music_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          children: [10, 12, 16].map((cap) => ListTile(
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
                      const Gap(20),
                      
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
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildBottomAction(Icons.cleaning_services_rounded, "Clear Screen", onTap: () async {
                             final room = roomAsync.value;
                             if (room == null) return;
                             await ref.read(roomServiceProvider).clearRoomMessages(room.roomId);
                             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat cleared!")));
                          }),
                          _buildBottomAction(Icons.image_outlined, "Theme", onTap: () => _showThemePicker(room)),
                          if (room.ownerUid == uid || room.admins.contains(uid))
                            _buildBottomAction(
                              Icons.music_note_rounded, 
                              "Music", 
                              onTap: () {
                                Navigator.pop(context);
                                _showMusicSheet(room);
                              }
                            ),
                          _buildBottomAction(
                            room.isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded, 
                            "Lock", 
                            onTap: () => _showPasswordDialog(room)
                          ),
                          _buildBottomAction(Icons.admin_panel_settings_outlined, "Admin", onTap: () => _showAdminPanel(room)),
                          if (room.bannedUids.isNotEmpty)
                            _buildBottomAction(Icons.block, "Bans", onTap: () => _showBannedUsers(room)),
                        ],
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
    final themes = [
      {'name': 'Default', 'color': Colors.deepPurple, 'img': ''},
      {'name': 'Ocean', 'color': Colors.blue, 'img': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500'},
      {'name': 'Sunset', 'color': Colors.orange, 'img': 'https://images.unsplash.com/photo-1502481851512-e9e2529bfbf9?w=500'},
      {'name': 'Neon', 'color': Colors.pinkAccent, 'img': 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=500'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Room Theme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Gap(20),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: themes.length,
                separatorBuilder: (_, __) => const Gap(16),
                itemBuilder: (context, index) {
                  final t = themes[index];
                  final isSelected = room.theme == t['name'];
                  return GestureDetector(
                    onTap: () async {
                      await _update(room.roomId, "theme", t['name']);
                      if (t['img'] != null && (t['img'] as String).isNotEmpty) {
                        await _update(room.roomId, "coverUrl", t['img']);
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: t['color'] as Color,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected ? Border.all(color: AppColors.primary, width: 3) : null,
                            image: (t['img'] as String).isNotEmpty 
                              ? DecorationImage(image: NetworkImage(t['img'] as String), fit: BoxFit.cover) 
                              : null,
                          ),
                          child: isSelected ? const Icon(Icons.check_circle, color: Colors.white) : null,
                        ),
                        const Gap(8),
                        Text(t['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        onSubmitted: (val) => _update(roomId, field, val.trim()),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const Gap(6),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
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
