import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_toast.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _nameController = TextEditingController(text: "Chit-Chat & Vibes ✨");
  final _passwordController = TextEditingController();
  
  String _selectedTheme = "Casual Chat";
  bool _isPrivate = false;
  int _capacity = 9;
  bool _bgMusic = true;
  bool _hdAudio = true;
  bool _isLoading = false;
  File? _selectedImage;

  final List<Map<String, dynamic>> _themesData = [
    {
      "name": "Casual Chat",
      "icon": Icons.chat_bubble_rounded,
      "tag": "VIBES",
      "gradient": [Color(0xFF6366F1), Color(0xFF4F46E5)],
      "glow": Color(0xFF6366F1),
    },
    {
      "name": "Karaoke Night",
      "icon": Icons.mic_external_on_rounded,
      "tag": "MUSIC",
      "gradient": [Color(0xFFEC4899), Color(0xFFD946EF)],
      "glow": Color(0xFFEC4899),
    },
    {
      "name": "Birthday Party",
      "icon": Icons.cake_rounded,
      "tag": "CELEBRATE",
      "gradient": [Color(0xFFF59E0B), Color(0xFFD97706)],
      "glow": Color(0xFFF59E0B),
    },
    {
      "name": "Game Arena",
      "icon": Icons.sports_esports_rounded,
      "tag": "GAMING",
      "gradient": [Color(0xFF10B981), Color(0xFF059669)],
      "glow": Color(0xFF10B981),
    },
    {
      "name": "PK Battle",
      "icon": Icons.flash_on_rounded,
      "tag": "BATTLE",
      "gradient": [Color(0xFFEF4444), Color(0xFFDC2626)],
      "glow": Color(0xFFEF4444),
    },
    {
      "name": "Poetry & Vibes",
      "icon": Icons.auto_stories_rounded,
      "tag": "SHAYARI",
      "gradient": [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
      "glow": Color(0xFF8B5CF6),
    },
    {
      "name": "Movie & Chill",
      "icon": Icons.movie_filter_rounded,
      "tag": "CINEMA",
      "gradient": [Color(0xFF06B6D4), Color(0xFF0891B2)],
      "glow": Color(0xFF06B6D4),
    },
    {
      "name": "Tea & Gossip",
      "icon": Icons.local_cafe_rounded,
      "tag": "TALKS",
      "gradient": [Color(0xFFF97316), Color(0xFFEA580C)],
      "glow": Color(0xFFF97316),
    },
  ];

  final List<Map<String, dynamic>> _seatPresets = [
    {"count": 6, "label": "6 Pod", "subtitle": "Intimate"},
    {"count": 9, "label": "9 Stage", "subtitle": "Popular"},
    {"count": 12, "label": "12 Lounge", "subtitle": "Party"},
    {"count": 16, "label": "16 Arena", "subtitle": "Mega PK"},
  ];

  final List<String> _quickIdeas = [
    "Late Night Talks 🌙",
    "Sing With Me 🎤",
    "Friendly PK Battle 🔥",
    "Chill & Lo-Fi Beats 🎧",
    "Truth or Dare 🎲",
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.showError(context, "Please enter a room title 🎙️");
      return;
    }

    if (_isPrivate && _passwordController.text.trim().isEmpty) {
      AppToast.showError(context, "Please set a passcode for your private room 🔒");
      return;
    }

    HapticFeedback.mediumImpact();
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
        password: _isPrivate ? _passwordController.text.trim() : null,
        capacity: _capacity,
        backgroundMusic: _bgMusic,
        coverUrl: coverUrl,
      );

      if (!mounted) return;
      context.pushReplacementNamed(AppRoutes.liveRoom, pathParameters: {'roomId': roomId});
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (message.contains("Exception:")) message = message.split("Exception:").last.trim();
        AppToast.showError(context, message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final userData = userAsync.valueOrNull;

    final currentTheme = _themesData.firstWhere(
      (t) => t['name'] == _selectedTheme,
      orElse: () => _themesData.first,
    );
    final themeColor = (currentTheme['gradient'] as List<Color>).first;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withOpacity(0.6), blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
            const Gap(8),
            Text(
              "BROADCAST STUDIO",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. Ambient Dynamic Glow Backdrop
          Positioned(
            top: -100,
            left: -50,
            right: -50,
            height: 450,
            child: Opacity(
              opacity: 0.3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      themeColor.withOpacity(0.5),
                      AppColors.secondary.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Main Scroll Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LIVE STAGE PREVIEW CARD (Interactive feed mockup)
                  _buildLiveStagePreview(userData, currentTheme),
                  const Gap(24),

                  // ROOM TITLE INPUT
                  _buildStudioLabel("ROOM TITLE", Icons.edit_rounded),
                  const Gap(10),
                  _buildTitleInput(),
                  const Gap(10),
                  _buildQuickIdeaPills(),
                  const Gap(24),

                  // CATEGORY / THEME CAROUSEL
                  _buildStudioLabel("BROADCAST THEME", Icons.auto_awesome_rounded),
                  const Gap(10),
                  _buildThemeSelector(),
                  const Gap(24),

                  // SEAT CAPACITY ARCHITECTURE
                  _buildStudioLabel("STAGE CAPACITY", Icons.group_work_rounded),
                  const Gap(10),
                  _buildSeatSelector(),
                  const Gap(24),

                  // STUDIO AUDIO & PRIVACY PREFERENCES
                  _buildStudioLabel("BROADCAST CONTROLS", Icons.tune_rounded),
                  const Gap(10),
                  _buildStudioPreferences(),
                  const Gap(32),

                  // LAUNCH CTA BUTTON
                  _buildLaunchButton(currentTheme),
                  const Gap(24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Hero Live Stage Preview
  Widget _buildLiveStagePreview(dynamic userData, Map<String, dynamic> currentTheme) {
    final List<Color> gradient = currentTheme['gradient'] as List<Color>;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Stage Top Header Banner
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradient.first.withOpacity(0.85), gradient.last.withOpacity(0.95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Live Status Badge & Change Cover Pill
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Gap(6),
                      Text(
                        "LIVE PREVIEW",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                        const Gap(5),
                        Text(
                          _selectedImage == null ? "Add Cover" : "Change",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Stage Info Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Host Avatar
                if (userData != null)
                  AppAvatar(
                    imageUrl: userData.profilePhotoUrl,
                    radius: 24,
                    vipTier: userData.vipTier,
                    frameUrl: userData.profileFrame,
                    userLevel: userData.level,
                    frameMultiplier: 1.6,
                    maxRenderSize: const Size(80, 80),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 24),
                  ),

                const Gap(14),

                // Title & Attributes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.isEmpty ? "Untitled Live Room" : _nameController.text,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(6),
                      Row(
                        children: [
                          // Theme Tag Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: gradient.first.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: gradient.first.withOpacity(0.35)),
                            ),
                            child: Text(
                              _selectedTheme,
                              style: GoogleFonts.plusJakartaSans(
                                color: gradient.first,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Gap(8),

                          // Seat Count Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.airline_seat_recline_normal_rounded, color: AppColors.textSecondary, size: 11),
                                const Gap(3),
                                Text(
                                  "$_capacity Seats",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_isPrivate) ...[
                            const Gap(8),
                            const Icon(Icons.lock_rounded, color: Color(0xFFFBBF24), size: 13),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  // 2. Title Input Field
  Widget _buildTitleInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _nameController,
        maxLength: 35,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: "Enter catchy room title...",
          hintStyle: GoogleFonts.plusJakartaSans(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 22),
          suffixIcon: _nameController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary, size: 18),
                  onPressed: () => setState(() => _nameController.clear()),
                )
              : null,
          filled: false,
          counterStyle: GoogleFonts.plusJakartaSans(color: AppColors.textTertiary, fontSize: 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // 3. Quick Title Suggestions
  Widget _buildQuickIdeaPills() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _quickIdeas.length,
        separatorBuilder: (_, __) => const Gap(6),
        itemBuilder: (context, idx) {
          final idea = _quickIdeas[idx];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _nameController.text = idea);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                idea,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 4. Themes Grid Selector
  Widget _buildThemeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _themesData.map((t) {
        final String themeName = t['name'] as String;
        final IconData icon = t['icon'] as IconData;
        final List<Color> gradient = t['gradient'] as List<Color>;
        final isSelected = _selectedTheme == themeName;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedTheme = themeName);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.white.withOpacity(0.4) : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: gradient.first.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isSelected ? Colors.white : gradient.first),
                const Gap(8),
                Text(
                  themeName,
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 5. Stage Capacity Selector
  Widget _buildSeatSelector() {
    return Row(
      children: _seatPresets.map((preset) {
        final int count = preset['count'] as int;
        final String label = preset['label'] as String;
        final String subtitle = preset['subtitle'] as String;
        final isSelected = _capacity == count;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _capacity = count);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: isSelected ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Colors.white.withOpacity(0.5) : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.airline_seat_recline_extra_rounded,
                      size: 20,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                    const Gap(6),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.white70 : AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 6. Broadcast Preferences
  Widget _buildStudioPreferences() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Private Mode
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFF59E0B), size: 18),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Private Room",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "Require 4-6 digit passcode to join",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPrivate,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _isPrivate = v);
                },
                activeColor: AppColors.primary,
                inactiveTrackColor: AppColors.divider,
              ),
            ],
          ),

          if (_isPrivate) ...[
            const Gap(12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: TextField(
                controller: _passwordController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: "Enter passcode (e.g. 1234)",
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: AppColors.textTertiary,
                    letterSpacing: 0,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFFF59E0B), size: 18),
                  counterText: "",
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.divider),
          ),

          // Spatial Ambient Beats
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note_rounded, color: Color(0xFF06B6D4), size: 18),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Background Music & Beats",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "Enable live audio stream & ambient mix",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _bgMusic,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _bgMusic = v);
                },
                activeColor: AppColors.primary,
                inactiveTrackColor: AppColors.divider,
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.divider),
          ),

          // AI Noise Suppression
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AI Noise Shield & 48kHz HD Voice",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      "Agora studio-grade spatial acoustic engine",
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hdAudio,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _hdAudio = v);
                },
                activeColor: AppColors.primary,
                inactiveTrackColor: AppColors.divider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 7. Launch CTA Button
  Widget _buildLaunchButton(Map<String, dynamic> currentTheme) {
    final List<Color> gradient = currentTheme['gradient'] as List<Color>;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient.first,
            const Color(0xFFEC4899),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                  const Gap(10),
                  Text(
                    "START LIVE BROADCAST",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStudioLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const Gap(6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
