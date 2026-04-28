import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    // No longer manually generating fallback ID.
    // The field will be populated via ref.listen when the backend assigns it.
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _setupProfile() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: User session not found.")),
      );
      return;
    }

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in your name")),
      );
      return;
    }

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a profile photo")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 0. Get the profile to access the helloId
      final profile = ref.read(currentUserProfileProvider).value;
      final finalUsername = username.isNotEmpty 
          ? username 
          : (profile?.displayId ?? "user_${user.uid.substring(0, 5)}");

      // 1. Upload photo first
      final photoUrl = await ref.read(profileServiceProvider).uploadProfilePhoto(user.uid, _imageFile!);

      // 2. Setup user profile in Firestore
      await ref.read(profileServiceProvider).setupUserProfile(
        uid: user.uid,
        username: finalUsername,
        displayName: name,
        bio: bio,
        country: "IN",
        profilePhotoUrl: photoUrl,
      );
      
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Setup Failed: ${e.toString().replaceAll("Exception:", "")}")),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Avatar Picker
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 64,
                      backgroundColor: Colors.grey[100],
                      backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                      child: _imageFile == null 
                        ? const Icon(Icons.person_add_rounded, size: 48, color: AppColors.textTertiary)
                        : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              AppTextField(
                controller: _nameController,
                label: "Display Name *",
                hintText: "What should people call you?",
              ),
              const SizedBox(height: 16),
              
              AppTextField(
                controller: _bioController,
                label: "Bio (Optional)",
                hintText: "Tell us a bit about yourself",
                maxLines: 3,
              ),
              
              const SizedBox(height: 48),
              
              AppButton(
                onPressed: _isLoading ? null : _setupProfile,
                text: _isLoading ? "SAVING PROFILE..." : "GET STARTED",
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
