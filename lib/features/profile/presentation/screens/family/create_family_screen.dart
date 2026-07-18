import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/cloudinary_service.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _noticeController = TextEditingController();
  final _countryController = TextEditingController();
  final _picker = ImagePicker();
  JoinMode _joinMode = JoinMode.free;
  int _levelRequirement = 0;
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _noticeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.familyBg,
      appBar: AppBar(
        backgroundColor: AppColors.familyBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.familyText, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'ESTABLISH CLAN',
          style: TextStyle(color: AppColors.familyText, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const Gap(24),
            _buildAvatarPicker(),
            const Gap(32),
            _buildBlinkitInput(
              label: 'FAMILY NAME',
              description: 'This is your clan\'s official identity. 4-20 chars.',
              hint: 'e.g. Shadow Warriors',
              controller: _nameController,
              maxLength: 20,
            ),
            const Gap(16),
            _buildBlinkitInput(
              label: 'FAMILY TAG',
              description: 'A unique 3-8 char short ID shown next to names.',
              hint: 'e.g. SHDW',
              controller: _tagController,
              maxLength: 8,
            ),
            const Gap(16),
            _buildBlinkitInput(
              label: 'COUNTRY',
              description: 'Your family\'s country of origin.',
              hint: 'e.g. Bangladesh',
              controller: _countryController,
              maxLength: 30,
            ),
            const Gap(16),
            _buildBlinkitInput(
              label: 'NOTICE BOARD',
              description: 'A message for potential recruits and rivals.',
              hint: 'Tell the world about your clan...',
              controller: _noticeController,
              maxLength: 500,
              maxLines: 4,
            ),
            const Gap(16),
            _buildSettingGrid(),
            const Gap(32),
            _buildCreateButton(),
            const Gap(40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.familySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.familyGold.withOpacity(0.3), width: 2),
                    image: _selectedImage != null
                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _selectedImage == null
                      ? const Icon(Icons.groups_rounded, size: 40, color: AppColors.familyTextSecondary)
                      : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.familyGold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.familyBg, width: 3),
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              _selectedImage != null ? "Emblem Selected" : "Upload Emblem",
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.familyTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlinkitInput({
    required String label, 
    required String description,
    required String hint, 
    required TextEditingController controller, 
    required int maxLength, 
    int maxLines = 1
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.familySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.familyGold.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.familyText, letterSpacing: 0.5)),
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.familyTextSecondary),
            ],
          ),
          const Gap(4),
          Text(description, style: const TextStyle(fontSize: 10, color: AppColors.familyTextSecondary, fontWeight: FontWeight.w500)),
          const Gap(12),
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.familyText),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.familyTextSecondary, fontWeight: FontWeight.normal),
              border: InputBorder.none,
              counterText: '',
              isCollapsed: true,
              filled: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildSmallSetting(
            label: 'JOIN MODE',
            description: 'Free or Approval',
            value: _joinMode.name.toUpperCase(),
            onTap: _showJoinModePicker,
          ),
        ),
        const Gap(12),
        Expanded(
          child: _buildSmallSetting(
            label: 'ENTRY LVL',
            description: 'Min level to join',
            value: 'LVL $_levelRequirement',
            onTap: _showLevelPicker,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallSetting({required String label, required String description, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.familySurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.familyGold.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.familyText)),
            Text(description, style: const TextStyle(fontSize: 9, color: AppColors.familyTextSecondary)),
            const Gap(6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.familyText)),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.familyTextSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _handleCreate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.familyGold,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.familyGoldLight, width: 2),
          boxShadow: [
            BoxShadow(color: AppColors.familyGold.withOpacity(0.3), offset: const Offset(0, 4), blurRadius: 12),
          ],
        ),
        child: const Center(
          child: Text(
            'ESTABLISH CLAN',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black, letterSpacing: 1),
          ),
        ),
      ),
    );
  }

  void _showJoinModePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.familySurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SELECT JOIN MODE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.familyText)),
            const Gap(16),
            ...JoinMode.values.map((mode) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(mode.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.familyText)),
              subtitle: Text(mode == JoinMode.free ? "Anyone can join instantly" : "Leader must approve requests",
                style: const TextStyle(color: AppColors.familyTextSecondary)),
              trailing: Radio<JoinMode>(
                value: mode,
                groupValue: _joinMode,
                onChanged: (v) {
                   setState(() => _joinMode = v!);
                   Navigator.pop(context);
                },
              ),
              onTap: () {
                setState(() => _joinMode = mode);
                Navigator.pop(context);
              },
            )).toList(),
            const Gap(16),
          ],
        ),
      ),
    );
  }

  void _showLevelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.familySurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ENTRY REQUIREMENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.familyText)),
            const Gap(16),
            Expanded(
              child: ListView.builder(
                itemCount: 11,
                itemBuilder: (context, index) {
                  final lvl = index * 5;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Level $lvl+', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.familyText)),
                    trailing: _levelRequirement == lvl ? const Icon(Icons.check_circle_rounded, color: AppColors.familyGold) : null,
                    onTap: () {
                      setState(() => _levelRequirement = lvl);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreate() async {
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    if (_nameController.text.length < 4) {
      _showError("Family Name must be at least 4 characters.");
      return;
    }
    if (_tagController.text.length < 3) {
      _showError("Family Tag must be at least 3 characters.");
      return;
    }
    if (user.familyId != null) {
      _showError("You are already in a family.");
      return;
    }

    final exists = await ref.read(familyServiceProvider).checkDuplicateName(_nameController.text);
    if (exists) {
      _showError("A family with this name already exists.");
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await ref.read(cloudinaryServiceProvider).uploadImage(
          _selectedImage!.path,
          folder: "families/emblems",
        );
      }

      await ref.read(familyServiceProvider).createFamily(
        ownerId: user.uid,
        name: _nameController.text,
        tag: _tagController.text.toUpperCase(),
        description: _noticeController.text,
        notice: _noticeController.text,
        avatarUrl: avatarUrl,
        country: _countryController.text,
        joinMode: _joinMode,
        levelRequirement: _levelRequirement,
      );
      if (mounted) { setState(() => _isUploading = false); _showSuccessDialog(); }
    } catch (e) {
      setState(() => _isUploading = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.familySurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      )
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.familySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: const BorderSide(color: AppColors.familyGold, width: 1.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFF1B5E20), shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, size: 48, color: AppColors.success),
            ),
            const Gap(24),
            const Text("CLAN ESTABLISHED!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.familyText)),
            const Gap(12),
            Text(
              "Congratulations! \"${_nameController.text}\" is now official. Start recruiting members to dominate the charts.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.familyTextSecondary, fontSize: 13, height: 1.5),
            ),
            const Gap(32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.pop();
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.familyGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("ACCESS PORTAL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
