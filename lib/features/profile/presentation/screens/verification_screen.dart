import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  File? _image;
  bool _isUploading = false;

  // Fintech Palette
  static const Color primaryNavy = Color(0xFF00246B);
  static const Color softBlue = Color(0xFFCADCFC);
  static const Color creamColor = Color(0xFFFDFBF7);
  static const Color textSub = Color(0xFFCADCFC);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _submitVerification() async {
    if (_image == null) return;

    setState(() => _isUploading = true);

    try {
      final user = ref.read(currentUserProfileProvider).value;
      if (user == null) return;

      // 1. Upload to Storage
      final refStorage = FirebaseStorage.instance
          .ref()
          .child('verifications')
          .child('${user.uid}_id.jpg');
      
      await refStorage.putFile(_image!);
      final downloadUrl = await refStorage.getDownloadURL();

      // 2. Update Firestore (Simulating for now, usually a Cloud Function)
      await ref.read(profileServiceProvider).updateProfileFields(user.uid, {
        'idPhotoUrl': downloadUrl,
        'verificationStatus': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification submitted successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF001A4D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: creamColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "IDENTITY VERIFICATION",
          style: GoogleFonts.plusJakartaSans(color: softBlue, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2),
        ),
      ),
      body: userAsync.when(
        data: (user) {
          final status = user?.verificationStatus ?? 'unverified';

          if (status == 'verified') return _buildVerifiedState();
          if (status == 'pending') return _buildPendingState();
          
          return _buildUploadState(status == 'rejected');
        },
        loading: () => const Center(child: CircularProgressIndicator(color: softBlue)),
        error: (e, __) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildVerifiedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 80).animate().scale(duration: 600.ms),
          const Gap(24),
          Text(
            "Account Verified",
            style: GoogleFonts.plusJakartaSans(color: creamColor, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Gap(12),
          Text(
            "Your identity has been confirmed.\nYou have full access to all features.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.access_time_filled_rounded, color: softBlue, size: 80).animate().shake(),
          const Gap(24),
          Text(
            "Under Review",
            style: GoogleFonts.plusJakartaSans(color: creamColor, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Gap(12),
          Text(
            "Our team is currently reviewing your documents.\nThis usually takes 24-48 hours.",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadState(bool isRejected) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRejected)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      "Previous submission was rejected. Please upload a clearer photo of your ID.",
                      style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          Text(
            "Submit Documents",
            style: GoogleFonts.plusJakartaSans(color: creamColor, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          Text(
            "Please upload a clear photo of your National ID or Passport to verify your account for withdrawals.",
            style: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 14),
          ),
          const Gap(40),
          
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: softBlue.withOpacity(0.2), width: 2, style: BorderStyle.solid),
              ),
              child: _image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_rounded, color: softBlue, size: 48),
                      const Gap(16),
                      Text(
                        "Tap to Upload Photo",
                        style: GoogleFonts.plusJakartaSans(color: softBlue, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
            ),
          ),

          const Gap(48),

          // Requirements
          _buildRequirementRow("ID must be clearly visible"),
          _buildRequirementRow("Photo must not be blurry"),
          _buildRequirementRow("All four corners must be in frame"),

          const Gap(60),

          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: (_image == null || _isUploading) ? null : _submitVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: softBlue,
                foregroundColor: primaryNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isUploading
                ? const CircularProgressIndicator(color: primaryNavy)
                : Text("SUBMIT FOR REVIEW", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: softBlue, size: 16),
          const Gap(12),
          Text(text, style: GoogleFonts.plusJakartaSans(color: textSub, fontSize: 12)),
        ],
      ),
    );
  }
}
