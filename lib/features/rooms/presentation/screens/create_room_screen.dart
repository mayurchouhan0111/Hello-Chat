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
      // UX Check: Immediate feedback if owner of another room
      // (The service also enforces this, but we catch it here for cleaner handling)
      
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
        String message = e.toString();
        if (message.contains("Exception:")) message = message.split("Exception:").last.trim();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text("Create Live Room", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary, size: 28),
          onPressed: () => Navigator.of(context).pop(),
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
            const Text("SELECT THEME", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 1.2)),
            const Gap(12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _themes.map((theme) {
                final isSelected = _selectedTheme == theme;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTheme = theme),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected ? const LinearGradient(colors: AppColors.primaryGradient) : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected ? [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                      ] : null,
                    ),
                    child: Text(
                      theme,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
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
                  activeColor: AppColors.primary,
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
                    selectedColor: AppColors.primary,
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
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const Gap(40),
            Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(29),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Launch Your Room", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
