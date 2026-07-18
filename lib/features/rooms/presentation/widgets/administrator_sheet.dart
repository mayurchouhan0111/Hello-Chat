import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../screens/admin_search_screen.dart';

class AdministratorSheet extends ConsumerStatefulWidget {
  final RoomModel room;
  const AdministratorSheet({super.key, required this.room});

  @override
  ConsumerState<AdministratorSheet> createState() => _AdministratorSheetState();
}

class _AdministratorSheetState extends ConsumerState<AdministratorSheet> with SingleTickerProviderStateMixin {
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
    final roomAsync = ref.watch(currentRoomStreamProvider(widget.room.roomId));
    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox.shrink();
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFFEFEFEF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Gap(12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
              const Gap(16),
              TabBar(
                controller: _tabController,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.black38,
                indicatorColor: Colors.lightBlueAccent,
                tabs: [
                  Tab(text: "Admins (${room.admins.length}/12)"),
                  Tab(text: "Moderators (${room.moderators.length})"),
                ],
              ),
              const Gap(8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _tabController.index == 0
                    ? "Full rights: mute, kick, ban, invite, play music"
                    : "Limited: kick only",
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const Gap(12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAdminList(room),
                    _buildModeratorList(room),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSearchScreen(room: room, initialRole: _tabController.index == 0 ? 'admin' : 'moderator')));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.lightBlueAccent, Colors.purpleAccent],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Text(_tabController.index == 0 ? "Add Admin" : "Add Moderator", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(height: 300, child: Center(child: Text("Error loading room"))),
    );
  }

  Widget _buildAdminList(RoomModel room) {
    if (room.admins.isEmpty) return _buildEmptyState(Icons.support_agent, "No administrators");
    return ListView.builder(
      itemCount: room.admins.length,
      itemBuilder: (context, index) {
        final uid = room.admins[index];
        return Consumer(
          builder: (context, ref, child) {
            final userAsync = ref.watch(userProfileProvider(uid));
            return userAsync.when(
              data: (user) {
                if (user == null) return const SizedBox.shrink();
                return ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(user.profilePhotoUrl.isNotEmpty ? user.profilePhotoUrl : 'https://picsum.photos/200')),
                  title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("ID: ${user.displayId}", style: const TextStyle(fontSize: 12)),
                  trailing: room.ownerUid == uid
                    ? const Text("Owner", style: TextStyle(fontSize: 12, color: Colors.black54))
                    : IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () async {
                          await ref.read(roomServiceProvider).removeModerator(room.roomId, uid);
                        },
                      ),
                );
              },
              loading: () => const ListTile(title: Text("Loading...")),
              error: (_, __) => const ListTile(title: Text("Error fetching user")),
            );
          }
        );
      },
    );
  }

  Widget _buildModeratorList(RoomModel room) {
    if (room.moderators.isEmpty) return _buildEmptyState(Icons.manage_accounts_outlined, "No moderators");
    return ListView.builder(
      itemCount: room.moderators.length,
      itemBuilder: (context, index) {
        final uid = room.moderators[index];
        return Consumer(
          builder: (context, ref, child) {
            final userAsync = ref.watch(userProfileProvider(uid));
            return userAsync.when(
              data: (user) {
                if (user == null) return const SizedBox.shrink();
                return ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(user.profilePhotoUrl.isNotEmpty ? user.profilePhotoUrl : 'https://picsum.photos/200')),
                  title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("ID: ${user.displayId} · Kick only", style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () async {
                      await ref.read(roomServiceProvider).removeRoomModerator(room.roomId, uid);
                    },
                  ),
                );
              },
              loading: () => const ListTile(title: Text("Loading...")),
              error: (_, __) => const ListTile(title: Text("Error fetching user")),
            );
          }
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.lightBlueAccent,
          ),
          child: Center(child: Icon(icon, size: 60, color: Colors.white)),
        ),
        const Gap(16),
        Text(message, style: const TextStyle(color: Colors.black54, fontSize: 14)),
      ],
    );
  }
}
