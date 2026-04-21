import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';

class RoomSettingsSheet extends ConsumerStatefulWidget {
  final RoomModel room;
  const RoomSettingsSheet({super.key, required this.room});

  @override
  ConsumerState<RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends ConsumerState<RoomSettingsSheet> {
  late TextEditingController _nameController;
  late TextEditingController _noticeController;

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
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [10, 12, 16].map((cap) => ListTile(
            title: Text("$cap Seats"),
            onTap: () async {
              await _update(room.roomId, "capacity", cap);
              if (mounted) Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showMicModeDialog(RoomModel room) {
     showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["Free", "Lock"].map((mode) => ListTile(
            title: Text(mode),
            onTap: () async {
              await _update(room.roomId, "micMode", mode.toLowerCase());
              if (mounted) Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                                onTap: () {}, 
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
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
                          _buildBottomAction(
                            room.backgroundMusic ? Icons.music_note_rounded : Icons.music_off_rounded, 
                            "Music", 
                            onTap: () => _update(room.roomId, "backgroundMusic", !room.backgroundMusic)
                          ),
                          _buildBottomAction(
                            room.isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded, 
                            "Lock", 
                            onTap: () => _showPasswordDialog(room)
                          ),
                          _buildBottomAction(Icons.admin_panel_settings_outlined, "Admin", onTap: () => _showAdminPanel(room)),
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

  void _showAdminPanel(RoomModel room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const Gap(12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            const Gap(20),
            const Text("Moderators", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Gap(10),
            const Text("Moderators can mute and kick users.", style: TextStyle(color: Colors.black54, fontSize: 13)),
            const Gap(20),
            Expanded(
              child: room.admins.isEmpty
                ? const Center(child: Text("No moderators set"))
                : ListView.builder(
                    itemCount: room.admins.length,
                    itemBuilder: (context, index) {
                      final adminUid = room.admins[index];
                      // Fetch user profile for display
                      final userAsync = ref.watch(userProfileProvider(adminUid));
                      return userAsync.when(
                        data: (user) {
                          if (user == null) return const SizedBox.shrink();
                          return ListTile(
                            leading: CircleAvatar(backgroundImage: NetworkImage(user.profilePhotoUrl)),
                            title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Level ${user.level}"),
                            trailing: room.ownerUid == adminUid 
                              ? const Chip(label: Text("Owner", style: TextStyle(fontSize: 10)))
                              : IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () async {
                                    await ref.read(roomServiceProvider).removeModerator(room.roomId, adminUid);
                                  },
                                ),
                          );
                        },
                        loading: () => const ListTile(title: Text("Loading...")),
                        error: (_, __) => const ListTile(title: Text("Error fetching user")),
                      );
                    },
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                     // In a real app, open a search dialog
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Search for users to add as mods")));
                  },
                  child: const Text("Add Moderator", style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
