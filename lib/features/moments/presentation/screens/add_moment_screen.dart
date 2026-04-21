import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../providers/user_provider.dart';

class AddMomentScreen extends ConsumerStatefulWidget {
  const AddMomentScreen({super.key});

  @override
  ConsumerState<AddMomentScreen> createState() => _AddMomentScreenState();
}

class _AddMomentScreenState extends ConsumerState<AddMomentScreen> {
  File? _image;
  final _captionController = TextEditingController();
  String _selectedTag = "moment";
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _upload() async {
    if (_image == null) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isUploading = true);
    try {
      final imageUrl = await ref.read(profileServiceProvider).uploadMediaPhoto(
        user.uid, 
        _image!, 
        _selectedTag
      );

      await ref.read(profileServiceProvider).createMediaPost(
        uid: user.uid,
        imageUrl: imageUrl,
        tag: _selectedTag,
        caption: _captionController.text.trim(),
      );

      // Refresh providers
      ref.invalidate(momentsProvider(user.uid));
      if (_selectedTag == 'moment') {
        ref.invalidate(globalMomentsProvider);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Post shared successfully!"), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("CREATE POST", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              onPressed: (_image == null || _isUploading) ? null : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isUploading 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Post", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePickerSection(),
            const Gap(32),
            _buildSectionHeader("CAPTION"),
            const Gap(12),
            _buildCaptionInput(),
            const Gap(32),
            _buildSectionHeader("VISIBILITY"),
            const Gap(12),
            _buildVisibilitySelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: 300.ms,
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.04), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
          ],
          image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null,
        ),
        child: _image == null 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.add_photo_alternate_rounded, size: 40, color: AppColors.primary),
                ),
                const Gap(16),
                const Text("Add spectacular content", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const Gap(4),
                Text("Tap to select from storage", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            )
          : Stack(
              children: [
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                        Gap(6),
                        Text("Tap to Change", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title, 
      style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)
    );
  }

  Widget _buildCaptionInput() {
    return TextField(
      controller: _captionController,
      maxLines: 5,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: "Write a captivating caption...",
        hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.black.withOpacity(0.04))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.all(20),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildVisibilitySelector() {
    return Row(
      children: [
        Expanded(child: _buildVisibilityCard("moment", Icons.public_rounded, "Global Feed")),
        const Gap(12),
        Expanded(child: _buildVisibilityCard("normal", Icons.lock_outline_rounded, "Profile Only")),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildVisibilityCard(String tag, IconData icon, String label) {
    bool isSelected = _selectedTag == tag;
    return GestureDetector(
      onTap: () => setState(() => _selectedTag = tag),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.04)),
          boxShadow: [
            if (isSelected) BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 24),
            const Gap(8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
