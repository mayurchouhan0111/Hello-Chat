import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/room_provider.dart';

class AdminSearchScreen extends ConsumerStatefulWidget {
  final RoomModel room;
  final String initialRole; // "admin" or "moderator"
  const AdminSearchScreen({super.key, required this.room, this.initialRole = 'admin'});

  @override
  ConsumerState<AdminSearchScreen> createState() => _AdminSearchScreenState();
}

class _AdminSearchScreenState extends ConsumerState<AdminSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  UserModel? _searchedUser;
  String _errorMessage = '';

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _errorMessage = '';
      _searchedUser = null;
    });

    try {
      final helloId = int.tryParse(query);
      if (helloId != null) {
        final snap = await FirebaseFirestore.instance.collection('users').where('helloId', isEqualTo: helloId).limit(1).get();
        if (snap.docs.isNotEmpty) {
          setState(() {
            _searchedUser = UserModel.fromMap(snap.docs.first.data());
          });
        } else {
          setState(() {
            _errorMessage = 'User not found';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid ID format';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _addAdmin() async {
    if (_searchedUser == null) return;

    final isAdminRole = widget.initialRole == 'admin';
    final list = isAdminRole ? widget.room.admins : widget.room.moderators;
    final maxLimit = isAdminRole ? 12 : 999;

    if (list.length >= maxLimit) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAdminRole ? "Maximum 12 administrators" : "Maximum moderators reached")));
      return;
    }

    if (list.contains(_searchedUser!.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User is already a${isAdminRole ? 'n administrator' : ' moderator'}")));
      return;
    }

    if (isAdminRole) {
      await ref.read(roomServiceProvider).addModerator(widget.room.roomId, _searchedUser!.uid);
    } else {
      await ref.read(roomServiceProvider).addRoomModerator(widget.room.roomId, _searchedUser!.uid);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAdminRole ? "Administrator added" : "Moderator added")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter user ID',
              prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 20),
              suffixIcon: _searchController.text.isNotEmpty ? IconButton(
                icon: const Icon(Icons.cancel, color: Colors.black26, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() { _searchedUser = null; _errorMessage = ''; });
                },
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (val) => setState(() {}),
            onSubmitted: (_) => _performSearch(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _searchController.text.isNotEmpty ? _performSearch : null,
            child: const Text('Search', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isSearching
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
          : _searchedUser != null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(_searchedUser!.profilePhotoUrl.isNotEmpty ? _searchedUser!.profilePhotoUrl : 'https://picsum.photos/200'),
                          ),
                          title: Text(_searchedUser!.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("ID:${_searchedUser!.displayId}", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ),
                        Positioned(
                          right: 0,
                          top: 10,
                          child: InkWell(
                            onTap: () => setState(() => _searchedUser = null),
                            child: const Icon(Icons.close, color: Colors.black26, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (widget.room.admins.length >= 12)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text("A maximum of 12 administrators can be added", style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ),
                    InkWell(
                      onTap: _addAdmin,
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
                        child: Text(widget.initialRole == 'admin' ? "Add Admin" : "Add Moderator", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const Gap(20),
                  ],
                ),
              )
            : const SizedBox.shrink(),
    );
  }
}
