import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../screens/admin_search_screen.dart';

class AdministratorSheet extends ConsumerWidget {
  final RoomModel room;
  const AdministratorSheet({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const Gap(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Administrator(${room.admins.length}/12)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Gap(8),
              const Icon(Icons.help_outline, color: Colors.black54, size: 18),
            ],
          ),
          const Gap(16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Administrator rights include: Quiet Mic, Block Mic, Kick People, Invite People, Play music",
              style: TextStyle(color: Colors.black54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(20),
          Expanded(
            child: room.admins.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.lightBlueAccent,
                      ),
                      child: const Center(
                        child: Icon(Icons.support_agent, size: 80, color: Colors.white),
                      ),
                    ),
                    const Gap(16),
                    const Text("No administrator", style: TextStyle(color: Colors.black54, fontSize: 14)),
                  ],
                )
              : ListView.builder(
                  itemCount: room.admins.length,
                  itemBuilder: (context, index) {
                    final adminUid = room.admins[index];
                    return Consumer(
                      builder: (context, ref, child) {
                        final userAsync = ref.watch(userProfileProvider(adminUid));
                        return userAsync.when(
                          data: (user) {
                            if (user == null) return const SizedBox.shrink();
                            return ListTile(
                              leading: CircleAvatar(backgroundImage: NetworkImage(user.profilePhotoUrl.isNotEmpty ? user.profilePhotoUrl : 'https://picsum.photos/200')),
                              title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("ID: ${user.displayId}", style: const TextStyle(fontSize: 12)),
                              trailing: room.ownerUid == adminUid 
                                ? const Text("Owner", style: TextStyle(fontSize: 12, color: Colors.black54))
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
                      }
                    );
                  },
                ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: InkWell(
              onTap: () {
                Navigator.pop(context); // Close the sheet
                Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSearchScreen(room: room)));
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
                child: const Text("Add", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
