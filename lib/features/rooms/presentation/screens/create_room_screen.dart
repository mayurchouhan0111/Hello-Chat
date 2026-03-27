import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/cloudinary_service.dart';
import 'package:gap/gap.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _nameController = TextEditingController();
  String _selectedTheme = "Casual Chat";
  bool _isPrivate = false;
  final _passwordController = TextEditingController();
  int _capacity = 10;
  bool _bgMusic = false;
  bool _isLoading = false;
  File? _selectedImage;

  final List<String> _themes = [
    "Casual Chat", "Karaoke", "Birthday Party", "Game Room", "PK Battle", "Poetry", "Movie/YouTube", "Gossip"
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a room name")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? coverUrl;
      if (_selectedImage != null) {
        coverUrl = await ref.read(cloudinaryServiceProvider).uploadImage(_selectedImage!.path);
      }

      final roomId = await ref.read(roomServiceProvider).createRoom(
        name: name,
        theme: _selectedTheme,
        isPrivate: _isPrivate,
        password: _isPrivate ? _passwordController.text : null,
        capacity: _capacity,
        backgroundMusic: _bgMusic,
        coverUrl: coverUrl,
      );
      if (mounted) {
        context.pushReplacement(AppRoutes.liveRoom, extra: roomId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to create room: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Create Room", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Upload
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    image: _selectedImage != null 
                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _selectedImage == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: Colors.grey[400], size: 30),
                            const Gap(8),
                            Text("Room Cover", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const Gap(30),

            const Text("Room Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Gap(10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: "Enter room name...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const Gap(20),
            const Text("Select Theme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Gap(10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _themes.map((theme) {
                final isSelected = _selectedTheme == theme;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTheme = theme),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.cyanAccent : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected ? Border.all(color: AppColors.cyanAccent) : null,
                    ),
                    child: Text(
                      theme,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Gap(25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Private Room", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Switch(
                  value: _isPrivate,
                  onChanged: (val) => setState(() => _isPrivate = val),
                  activeColor: AppColors.cyanAccent,
                ),
              ],
            ),
            if (_isPrivate) ...[
              const Gap(10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Enter password",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
            const Gap(20),
            const Text("Room Capacity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Gap(10),
            Row(
              children: [10, 12, 16].map((cap) {
                final isSelected = _capacity == cap;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text("$cap Seats"),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _capacity = cap),
                    selectedColor: AppColors.cyanAccent,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  ),
                );
              }).toList(),
            ),
            const Gap(20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Background Music", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Switch(
                  value: _bgMusic,
                  onChanged: (val) => setState(() => _bgMusic = val),
                  activeColor: AppColors.cyanAccent,
                ),
              ],
            ),
            const Gap(40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyanAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create Live Room", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
