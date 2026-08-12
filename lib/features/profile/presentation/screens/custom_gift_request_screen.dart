import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/cloudinary_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';

class CustomGiftRequestScreen extends ConsumerStatefulWidget {
  const CustomGiftRequestScreen({super.key});

  @override
  ConsumerState<CustomGiftRequestScreen> createState() => _CustomGiftRequestScreenState();
}

class _CustomGiftRequestScreenState extends ConsumerState<CustomGiftRequestScreen> {
  final _nameController = TextEditingController();
  File? _selectedVideoFile;
  bool _isUploading = false;
  String? _uploadStatusText;

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() => _selectedVideoFile = file);
    }
  }

  Future<void> _submitCustomGift() async {
    final user = FirebaseAuth.instance.currentUser;
    final profile = ref.read(currentUserProfileProvider).value;

    if (user == null || profile == null) return;

    if (profile.level < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔒 Level 50 or above is required to submit a Custom Gift.")),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name for your Custom Gift.")),
      );
      return;
    }

    if (_selectedVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an MP4 video file (max 10 seconds).")),
      );
      return;
    }

    // Check if user already submitted before (5M Diamond fee for re-upload + 30-day cooldown)
    final existingSnap = await FirebaseFirestore.instance
        .collection('custom_gift_requests')
        .where('userId', isEqualTo: user.uid)
        .get();

    final isReupload = existingSnap.docs.isNotEmpty;

    if (isReupload) {
      final lastReq = existingSnap.docs.first.data();
      final lastDate = (lastReq['createdAt'] as Timestamp?)?.toDate();
      if (lastDate != null) {
        final daysDiff = DateTime.now().difference(lastDate).inDays;
        if (daysDiff < 30) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ You can change your Custom Gift video only once every 30 days. (${30 - daysDiff} days remaining)")),
          );
          return;
        }
      }

      if (profile.diamondBalance < 5000000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ 5,000,000 Diamonds required to change Custom Gift video.")),
        );
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _uploadStatusText = "Uploading MP4 Video...";
    });

    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final videoUrl = await cloudinary.uploadRaw(_selectedVideoFile!.path, folder: "gifts/custom");

      // If reupload, deduct 5M diamonds
      if (isReupload) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'diamondBalance': FieldValue.increment(-5000000),
        });
      }

      // Add to pending review queue for Admin Panel
      await FirebaseFirestore.instance.collection('custom_gift_requests').add({
        'userId': user.uid,
        'userName': profile.displayName,
        'userLevel': profile.level,
        'giftName': _nameController.text.trim(),
        'videoUrl': videoUrl,
        'status': 'pending',
        'isReupload': isReupload,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Custom Gift submitted successfully! Pending Admin review.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final isLevel50 = (profile?.level ?? 0) >= 50;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Custom Gift Application", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isLevel50 ? Colors.amber.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isLevel50 ? Colors.amber : Colors.redAccent),
              ),
              child: Row(
                children: [
                  Icon(isLevel50 ? Icons.workspace_premium : Icons.lock, color: isLevel50 ? Colors.amber : Colors.redAccent, size: 28),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLevel50 ? "Level 50+ Custom Gift Privileges Unlocked!" : "Level 50 Required",
                          style: TextStyle(color: isLevel50 ? Colors.amber : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          isLevel50 
                            ? "Submit your own 10-second MP4 video gift to be added to the official store!" 
                            : "Reach Level 50 to submit your custom video gift.",
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(24),

            const Text("Gift Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(8),
            TextField(
              controller: _nameController,
              enabled: isLevel50 && !_isUploading,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "e.g. Super Dragon Flame",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const Gap(20),

            const Text("Custom Gift Video (MP4, Max 10s)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(8),
            GestureDetector(
              onTap: isLevel50 && !_isUploading ? _pickVideo : null,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedVideoFile != null ? Icons.check_circle : Icons.cloud_upload,
                      color: _selectedVideoFile != null ? Colors.green : Colors.amber,
                      size: 40,
                    ),
                    const Gap(8),
                    Text(
                      _selectedVideoFile != null ? _selectedVideoFile!.path.split('/').last : "Tap to Select MP4 Video",
                      style: TextStyle(color: _selectedVideoFile != null ? Colors.greenAccent : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLevel50 ? Colors.amber : Colors.grey,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: (isLevel50 && !_isUploading) ? _submitCustomGift : null,
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                          const Gap(10),
                          Text(_uploadStatusText ?? "Uploading...", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Text("Submit Custom Gift Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
