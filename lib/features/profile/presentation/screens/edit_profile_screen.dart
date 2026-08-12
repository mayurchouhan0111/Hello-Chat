import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/router/app_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _hometownController;
  late TextEditingController _languagesController;
  late TextEditingController _ethnicityController;
  late TextEditingController _personalLabelController;
  
  String _selectedGender = 'male';
  DateTime? _selectedBirthday;
  String? _selectedHeight;
  String? _selectedWeight;
  
  bool _isLoading = false;
  String? _currentUserPhotoUrl;
  File? _newImageFile;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _hometownController = TextEditingController();
    _languagesController = TextEditingController();
    _ethnicityController = TextEditingController();
    _personalLabelController = TextEditingController();
  }

  void _initializeData(UserModel? profile) {
    if (profile == null) return;
    if (!_isInitialized) {
      _nameController.text = profile.displayName;
      _bioController.text = profile.bio;
      _hometownController.text = profile.hometown ?? "";
      _languagesController.text = (profile.languages).join(", ");
      _ethnicityController.text = profile.ethnicity ?? "";
      _personalLabelController.text = profile.personalLabel ?? "";
      
      _selectedGender = profile.gender;
      _selectedBirthday = profile.birthday;
      _selectedHeight = profile.height;
      _selectedWeight = profile.weight;
      
      _currentUserPhotoUrl = profile.profilePhotoUrl;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _hometownController.dispose();
    _languagesController.dispose();
    _ethnicityController.dispose();
    _personalLabelController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _newImageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      String? finalPhotoUrl = _currentUserPhotoUrl;
      if (_newImageFile != null) {
        finalPhotoUrl = await ref.read(profileServiceProvider).uploadProfilePhoto(user.uid, _newImageFile!);
      }

      final List<String> langList = _languagesController.text.split(",")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await ref.read(profileServiceProvider).updateUserProfile(
        uid: user.uid,
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        profilePhotoUrl: finalPhotoUrl,
        gender: _selectedGender,
        birthday: _selectedBirthday,
        height: _selectedHeight,
        weight: _selectedWeight,
        hometown: _hometownController.text.trim(),
        languages: langList,
        ethnicity: _ethnicityController.text.trim(),
        personalLabel: _personalLabelController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user != null) {
      final profile = ref.watch(userProfileProvider(user.uid)).value as UserModel?;
      _initializeData(profile);
      
      if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text("Edit Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Save", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const Gap(20),
              _buildPhotoSection(user),
              const Gap(10),
              
              _buildSectionHeader("Display Information"),
              _buildModernListTile("Name", _nameController.text, onTap: () => _editField("Name", _nameController)),
              _buildModernListTile("About Me", _bioController.text.isEmpty ? "Share a bit about yourself" : _bioController.text, onTap: () => _editField("About Me", _bioController, maxLines: 3)),
              
              _buildSectionHeader("Basic Attributes"),
              _buildModernListTile("Gender", _selectedGender.toUpperCase(), onTap: () => _showGenderPicker()),
              _buildModernListTile(
                "Birthday", 
                _selectedBirthday != null ? "${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}" : "Add your birthday", 
                onTap: () => _showBirthdayPicker()
              ),
              _buildModernListTile("Height", _selectedHeight ?? "Choose your height", onTap: () => _showPicker("Height", ["140cm", "150cm", "160cm", "170cm", "180cm", "190cm+"])),
              _buildModernListTile("Weight", _selectedWeight ?? "Choose your weight", onTap: () => _showPicker("Weight", ["40kg", "50kg", "60kg", "70kg", "80kg", "90kg+"])),
              
              _buildSectionHeader("Personal Details"),
              _buildModernListTile("Hometown", _hometownController.text.isEmpty ? "Places you call home" : _hometownController.text, onTap: () => _editField("Hometown", _hometownController)),
              _buildModernListTile("Languages", _languagesController.text.isEmpty ? "Languages you speak" : _languagesController.text, onTap: () => _editField("Languages", _languagesController, hint: "English, Hindi, etc.")),
              _buildModernListTile("Ethnicity", _ethnicityController.text.isEmpty ? "Choose your ethnicity" : _ethnicityController.text, onTap: () => _editField("Ethnicity", _ethnicityController)),
              _buildModernListTile("Personal Label", _personalLabelController.text.isEmpty ? "Add a life motto" : _personalLabelController.text, onTap: () => _editField("Personal Label", _personalLabelController)),
              
              _buildSectionHeader("Account Transparency"),
              _buildModernListTile(
                "Hello ID", 
                profile.displayId, 
                showArrow: false,
                isReadOnly: true,
              ),
              _buildModernListTile(
                "Official Organization", 
                profile.company ?? "Not assigned", 
                showArrow: false,
                isReadOnly: true,
              ),
              _buildModernListTile("Location", profile.country.isEmpty ? "Unknown" : profile.country, showArrow: false, isReadOnly: true),
              
              _buildSectionHeader("Exclusive Features"),
              _buildModernListTile(
                "Level 50+ Custom Gift", 
                "Submit MP4 Video", 
                onTap: () => context.push(AppRoutes.customGiftRequest),
              ),
              
              const Gap(60),
            ],
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: Text("Please log in")));
  }

  void _editField(String label, TextEditingController controller, {int maxLines = 1, String? hint}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Edit $label", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const Gap(16),
              _buildModernTextField(controller: controller, label: label, icon: Icons.edit_note_rounded, maxLines: maxLines, hint: hint),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
              const Gap(12),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(12),
            _buildGenderCard('male', Icons.male_rounded, "Male"),
            _buildGenderCard('female', Icons.female_rounded, "Female"),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  void _showBirthdayPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000),
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  void _showPicker(String title, List<String> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Gap(12),
            ...options.map((opt) => ListTile(
              title: Center(child: Text(opt, style: const TextStyle(fontWeight: FontWeight.bold))),
              onTap: () {
                setState(() {
                  if (title == "Height") _selectedHeight = opt;
                  if (title == "Weight") _selectedWeight = opt;
                });
                Navigator.pop(context);
              },
            )),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? progress}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1.5)),
          const Spacer(),
          if (progress != null) 
            Text("+$progress%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.cyan)),
        ],
      ),
    );
  }

  Widget _buildModernListTile(String label, String value, {VoidCallback? onTap, bool showArrow = true, bool isReadOnly = false}) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            onTap: isReadOnly ? null : onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Row(
              children: [
                SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54))),
                Expanded(
                  child: Text(
                    value, 
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w900,
                      color: (value.contains("Add") || value.contains("Choose") || value.contains("Share") || value.contains("speak") || value.contains("home") || value.contains("motto")) 
                        ? Colors.black26 
                        : (isReadOnly ? Colors.black45 : Colors.black87),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: showArrow ? const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.black12) : null,
          ),
          const Divider(height: 1, indent: 20, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(var user) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: ClipOval(
                    child: _newImageFile != null
                        ? Image.file(_newImageFile!, fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: _currentUserPhotoUrl != null && _currentUserPhotoUrl!.isNotEmpty 
                              ? _currentUserPhotoUrl! 
                              : "https://picsum.photos/seed/${user?.uid}/240",
                            fit: BoxFit.cover,
                          ),
                  ),
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
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          ),
          const Gap(12),
          Text(user?.displayName ?? "User", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const Text("TAP TO CHANGE PHOTO", style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon,
    String? hint,
    int maxLines = 1
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        labelStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildGenderCard(String value, IconData icon, String label) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedGender = value);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.05), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.grey[100], shape: BoxShape.circle),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
            ),
            const Gap(16),
            Text(label, style: TextStyle(color: isSelected ? AppColors.primary : Colors.black87, fontWeight: FontWeight.w900, fontSize: 16)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
