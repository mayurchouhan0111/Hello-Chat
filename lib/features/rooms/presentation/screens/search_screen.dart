import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/search_provider.dart';
import '../../../../core/router/app_router.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  int _selectedIndex = 0; // 0 for Users, 1 for Rooms

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFF1F5F9);
    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,

        titleSpacing: 0,
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(12), 
          ),
          child: Row(

            children: [
              const Icon(Icons.search_rounded, color: Colors.black26, size: 18),
              const Gap(8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  cursorColor: Colors.black38,
                  decoration: const InputDecoration(
                    hintText: "Rooms, User and UserId...",
                    hintStyle: TextStyle(color: Colors.black26, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.transparent,
                  ),


                  onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildToggleButton(),
          Expanded(
            child: _selectedIndex == 0 ? _buildUserResults() : _buildRoomResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white, // Match search input
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(child: _buildToggleItem("USERS", 0)),
          Expanded(child: _buildToggleItem("ROOMS", 1)),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, int index) {
    const screenGray = Color(0xFFF1F5F9);
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? screenGray : Colors.transparent, // Focus color matches screen
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.black26, 
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }


  Widget _buildUserResults() {

    final usersAsync = ref.watch(searchUsersProvider);
    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) return _buildEmptyState("search users by name or ID");
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              onTap: () => context.push(AppRoutes.userProfile, extra: user.uid),
              leading: CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(user.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${user.uid}/100" : user.profilePhotoUrl),
              ),

              title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("ID: ${user.uid.substring(0, 8)}...", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildRoomResults() {
    final roomsAsync = ref.watch(searchRoomsProvider);
    return roomsAsync.when(
      data: (rooms) {
         if (rooms.isEmpty) return _buildEmptyState("search rooms by name");
         return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final room = rooms[index];
            return ListTile(
              onTap: () => context.push(AppRoutes.liveRoom, extra: room.roomId),
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(image: NetworkImage(room.coverUrl.isEmpty ? "https://picsum.photos/seed/${room.roomId}/100" : room.coverUrl), fit: BoxFit.cover),
                ),
              ),
              title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${room.currentUsersCount} users online", style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
              trailing: const Icon(Icons.meeting_room_rounded, color: Colors.grey),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[200]),
          const Gap(16),
          Text(
            "Nothing found here",
            style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Gap(4),
          Text(msg, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
        ],
      ),
    );
  }
}
