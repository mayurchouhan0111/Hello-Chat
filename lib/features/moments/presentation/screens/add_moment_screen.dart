import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/profile_provider.dart';
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

      // Create Firestore doc for the moment/media
      await ref.read(profileServiceProvider).createMediaPost(
        uid: user.uid,
        imageUrl: imageUrl,
        tag: _selectedTag,
        caption: _captionController.text.trim(),
      );

      // Invalidate the moments provider to show new post immediately
      ref.invalidate(momentsProvider(user.uid));
      if (_selectedTag == 'moment') {
        ref.invalidate(globalMomentsProvider);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post synced to Firebase!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Create Post", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          TextButton(
            onPressed: (_image == null || _isUploading) ? null : _upload,
            child: _isUploading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Post", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null,
                ),
                child: _image == null 
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text("Select Photo", style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : null,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _captionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Post to:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                _buildTagChip("moment", "Square (Feed)"),
                const SizedBox(width: 8),
                _buildTagChip("normal", "Profile Only"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, String label) {
    bool isSelected = _selectedTag == tag;
    return GestureDetector(
      onTap: () => setState(() => _selectedTag = tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
