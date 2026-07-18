import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/svga_player.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';
import 'dart:async';


class EntryEffectOverlay extends ConsumerStatefulWidget {
  final Participant participant;
  final VoidCallback onEnd;

  const EntryEffectOverlay({
    super.key,
    required this.participant,
    required this.onEnd,
  });

  @override
  ConsumerState<EntryEffectOverlay> createState() => _EntryEffectOverlayState();
}

class _EntryEffectOverlayState extends ConsumerState<EntryEffectOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _slideAnimation = Tween<double>(begin: -300, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2, curve: Curves.easeIn)),
    );

    _controller.forward();
    
    // Auto remove
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onEnd());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(cachedUserProfileProvider(widget.participant.uid));
    final UserModel? u = userAsync.valueOrNull as UserModel?;

    final String vip = u?.vipTier ?? widget.participant.vipTier;
    final String frame = u?.profileFrame ?? widget.participant.profileFrame;
    final String noble = u?.nobleTier ?? widget.participant.nobleTier;
    final String name = (u?.displayName ?? widget.participant.displayName).trim().isEmpty ? "GUEST" : (u?.displayName ?? widget.participant.displayName);
    final String photo = u?.profilePhotoUrl ?? widget.participant.profilePhotoUrl;
    String customAnim = u?.entryAnimation ?? widget.participant.entryAnimation;
    final int vipLevel = _getVipLevel(vip);

    if (vipLevel >= 1 && vipLevel <= 8) {
      customAnim = _getVipEntryPath(vipLevel);
    } else if (customAnim.isNotEmpty) {
      final lowerAnim = customAnim.toLowerCase();
      for (int i = 1; i <= 8; i++) {
        if (lowerAnim.contains('vip/vip%20$i/') || 
            lowerAnim.contains('vip/vip $i/') || 
            lowerAnim.contains('vip_$i') || 
            lowerAnim.contains('vip$i')) {
          customAnim = _getVipEntryPath(i);
          break;
        }
      }
    }

    final bool hasVipEntry = customAnim.isNotEmpty && customAnim.startsWith('assets/') && customAnim.toLowerCase().endsWith('.svga');

    final double screenWidth = MediaQuery.of(context).size.width;
    
    // Determine if we show a vehicle animation
    bool useVehicle = false;
    String lottieAsset = 'assets/animations/lottie/Celebration.json';
    Color accentColor = const Color(0xFFFFD700);

    // Vehicles / High ranks (non-SVGA VIPs)
    bool isHighRank = noble == 'Duke' || noble == 'King' || noble == 'Emperor' || 
                      widget.participant.isAdmin;

    if (isHighRank) {
       useVehicle = true;
       lottieAsset = (noble == 'Emperor') 
          ? 'assets/animations/lottie/airplane.json' 
          : 'assets/animations/lottie/Red Car.json';
       accentColor = (noble == 'Emperor') ? const Color(0xFFE91E63) : const Color(0xFFFFD700);
    }

    final double bannerWidth = 320;
    final double assetWidth = useVehicle ? 400 : bannerWidth;
    final double endPosition = (screenWidth - assetWidth) / 2;

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Full-screen entry SVGA overlay for VIP 1-8
          if (hasVipEntry)
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: RepaintBoundary(
                  child: SvgaPlayer(
                    assetPath: customAnim,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          // 2. Sliding Welcome Banner Entry
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double currentSlide = -400 + (_controller.value * (endPosition + 400));
              
              return Positioned(
                left: currentSlide,
                top: useVehicle ? (MediaQuery.of(context).size.height * 0.28) : 180,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: RepaintBoundary(
                    child: useVehicle 
                      ? _buildVehicleEntry(lottieAsset, name, photo, accentColor, assetWidth)
                      : _buildBannerEntry(vip, noble, name, photo, accentColor, bannerWidth, hasVipEntry, frame),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSvgaEntry(String asset, String name, String photo, Color accent, double width) {
    return SizedBox(
      width: width,
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. The SVGA Background Animation
          Positioned.fill(
            child: SvgaPlayer(assetPath: asset),
          ),
          
          // 2. User Avatar
          Positioned(
            top: 65,
            child: AppAvatar(
              imageUrl: photo.isEmpty ? "https://picsum.photos/seed/${name}/100" : photo,
              frameUrl: widget.participant.profileFrame,
              vipTier: widget.participant.vipTier,
              radius: 24,
              showFrame: true,
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
          ),

          // 3. Floating Name Banner
          Positioned(
            bottom: 15,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.black.withOpacity(0.85), Colors.black.withOpacity(0.55)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.8), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: accent, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      name.toUpperCase(),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, shadows: [Shadow(color: accent, blurRadius: 4)]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "HAS ARRIVED!",
                      style: TextStyle(color: accent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildVehicleEntry(String asset, String name, String photo, Color accent, double width) {
    return SizedBox(
      width: width,
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. The Vehicle Lottie Background (Large)
          Lottie.asset(
            asset,
            width: width,
            fit: BoxFit.contain,
            frameRate: FrameRate.composition, // ⚡ Optimize Lottie frame rate!
          ),
          
          // 2. User Avatar
          Positioned(
            left: asset.contains('Car') ? (width * 0.28) : (width * 0.40),
            top: asset.contains('Car') ? 55 : 42,
            child: AppAvatar(
              imageUrl: photo.isEmpty ? "https://picsum.photos/seed/${name}/100" : photo,
              frameUrl: widget.participant.profileFrame,
              vipTier: widget.participant.vipTier,
              radius: 22,
              showFrame: true,
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
          ),

          // 3. Floating Name Banner
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.4)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.6), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: accent, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      name.toUpperCase(),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, shadows: [Shadow(color: accent, blurRadius: 4)]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "HAS ARRIVED!",
                      style: TextStyle(color: accent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBannerEntry(String vip, String noble, String name, String photo, Color accent, double width, bool hasVipEntry, String frame) {
    final String displayTag = noble != 'Civilian' ? noble : vip.toUpperCase();
    final String displayName = name.trim().isEmpty ? "GUEST" : name;
    final int vipLevel = _getVipLevel(vip);
    final bool isVip = vipLevel > 0;
    
    return Container(
      width: width,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: isVip
        ? const BoxDecoration(color: Colors.transparent)
        : hasVipEntry
            ? const BoxDecoration(color: Colors.transparent)
            : BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withOpacity(1.0), accent.withOpacity(0.7), Colors.transparent],
                ),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
      child: Stack(
        children: [
          if (isVip)
            Positioned.fill(
              child: Image.asset(
                'assets/VIP/VIP 1/Strip.png',
                fit: BoxFit.fill,
              ),
            )
          else if (hasVipEntry)
            Positioned.fill(
              child: SvgaPlayer(
                assetPath: _getVipStripPath(vipLevel),
                fit: BoxFit.fill,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: isVip
              ? Center(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 3),
                      ],
                    ),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                      ),
                      child: ClipOval(
                        child: AppAvatar(
                          imageUrl: photo.isEmpty ? "https://picsum.photos/seed/$name/100" : photo,
                          radius: 23,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTag == 'NONE' ? 'WELCOME' : displayTag,
                          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2),
                        ),
                        Text(
                          displayName,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.2),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      "Joined Room",
                      style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

int _getVipLevel(String vipTierName) {
  final clean = vipTierName.toLowerCase().replaceAll(' ', '');
  if (clean.startsWith('vip')) {
    final numStr = clean.substring(3);
    final val = int.tryParse(numStr);
    if (val != null) return val;
  }
  return 0;
}

String _getVipStripPath(int level) {
  if (level == 1) return 'assets/VIP/VIP 1/Strip.svga';
  if (level >= 2 && level <= 7) return 'assets/VIP/VIP $level/VIP $level/Strip.svga';
  if (level >= 8) return 'assets/VIP/VIP 7/VIP 7/Strip.svga'; // fallback
  return '';
}

String _getVipEntryPath(int level) {
  if (level == 1) return 'assets/VIP/VIP 1/Entry.svga';
  if (level == 2) return 'assets/VIP/VIP 2/VIP 2/Entry.svga';
  if (level == 3) return 'assets/VIP/VIP 3/VIP 3/Entry.svga';
  if (level == 4) return 'assets/VIP/VIP 4/VIP 4/Entry.svga';
  if (level == 5) return 'assets/VIP/VIP 5/VIP 5/Entry.svga';
  if (level == 6) return 'assets/VIP/VIP 6/VIP 6/VIP 6 Entry.svga';
  if (level == 7) return 'assets/VIP/VIP 7/VIP 7/Entry.svga';
  if (level == 8) return 'assets/VIP/VIP 8/VIP 8/VIP 8 Entry Effect.svga';
  return '';
}
