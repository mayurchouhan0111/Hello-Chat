import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/constants/app_colors.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _noticeController = TextEditingController();
  JoinMode _joinMode = JoinMode.free;
  int _levelRequirement = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _noticeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'ESTABLISH CLAN',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
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
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 2),
                ),
                child: const Icon(Icons.groups_rounded, size: 40, color: AppColors.textTertiary),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const Gap(8),
          const Text("Upload Emblem", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.textPrimary, letterSpacing: 0.5)),
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textTertiary),
            ],
          ),
          const Gap(4),
          Text(description, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
          const Gap(12),
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.normal),
              border: InputBorder.none,
              counterText: '',
              isCollapsed: true,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: AppColors.textPrimary)),
            Text(description, style: const TextStyle(fontSize: 9, color: AppColors.textTertiary)),
            const Gap(6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textPrimary)),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textTertiary),
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
          color: const Color(0xFFFACC15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(4, 4), blurRadius: 0),
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
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SELECT JOIN MODE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Gap(16),
            ...JoinMode.values.map((mode) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(mode.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(mode == JoinMode.free ? "Anyone can join instantly" : "Leader must approve requests"),
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
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ENTRY REQUIREMENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Gap(16),
            Expanded(
              child: ListView.builder(
                itemCount: 11,
                itemBuilder: (context, index) {
                  final lvl = index * 5;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Level $lvl+', style: const TextStyle(fontWeight: FontWeight.w900)),
                    trailing: _levelRequirement == lvl ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
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
    
    // Validations
    if (_nameController.text.length < 4) {
      _showError("Family Name must be at least 4 characters.");
      return;
    }
    if (_tagController.text.length < 3) {
      _showError("Family Tag must be at least 3 characters.");
      return;
    }

    try {
      await ref.read(familyServiceProvider).createFamily(
        ownerId: user.uid,
        name: _nameController.text,
        tag: _tagController.text.toUpperCase(),
        description: _noticeController.text,
        notice: _noticeController.text,
        joinMode: _joinMode,
        levelRequirement: _levelRequirement,
      );
      if (mounted) _showSuccessDialog();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF16A34A)),
            ),
            const Gap(24),
            const Text("CLAN ESTABLISHED!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Gap(12),
            Text(
              "Congratulations! \"${_nameController.text}\" is now official. Start recruiting members to dominate the charts.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 13, height: 1.5),
            ),
            const Gap(32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.pop(); // Close dialog
                  context.pop(); // Go back to portal
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
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
