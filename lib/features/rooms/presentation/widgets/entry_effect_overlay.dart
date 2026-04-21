import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/participant_model.dart';
import '../../../../core/widgets/app_avatar.dart';
import 'dart:async';


class EntryEffectOverlay extends StatefulWidget {
  final Participant participant;
  final VoidCallback onEnd;

  const EntryEffectOverlay({
    super.key,
    required this.participant,
    required this.onEnd,
  });

  @override
  State<EntryEffectOverlay> createState() => _EntryEffectOverlayState();
}

class _EntryEffectOverlayState extends State<EntryEffectOverlay> with SingleTickerProviderStateMixin {
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
    final String vip = widget.participant.vipTier;
    final String noble = widget.participant.nobleTier;
    final String name = widget.participant.displayName;
    final String photo = widget.participant.profilePhotoUrl;
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // 1. Determine Prestige Level
    bool isHighRank = vip.contains('5') || vip.contains('6') || vip.contains('7') || 
                      noble == 'Duke' || noble == 'King' || noble == 'Emperor' || 
                      widget.participant.isAdmin;

    // 2. Select Asset & Colors
    String lottieAsset = 'assets/animations/lottie/Celebration.json'; // Default
    Color accentColor = const Color(0xFFFFD700);
    bool useVehicle = false;

    if (isHighRank) {
       useVehicle = true;
       lottieAsset = (noble == 'Emperor' || vip.contains('7')) 
          ? 'assets/animations/lottie/airplane.json' 
          : 'assets/animations/lottie/Red Car.json';
       accentColor = (noble == 'Emperor') ? const Color(0xFFE91E63) : const Color(0xFFFFD700);
    }

    // Centering calculation: 
    final double bannerWidth = 320; // Increased width for better name fit
    final double assetWidth = useVehicle ? 400 : bannerWidth;
    final double endPosition = (screenWidth - assetWidth) / 2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Map original slide to center alignment
        final double currentSlide = -400 + (_controller.value * (endPosition + 400));
        
        return Positioned(
          left: currentSlide,
          top: useVehicle ? (MediaQuery.of(context).size.height * 0.28) : 180,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: useVehicle 
              ? _buildVehicleEntry(lottieAsset, name, photo, accentColor, assetWidth)
              : _buildBannerEntry(vip, noble, name, photo, accentColor, bannerWidth),
          ),
        );
      },
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


  Widget _buildBannerEntry(String vip, String noble, String name, String photo, Color accent, double width) {
    final String displayTag = noble != 'Civilian' ? noble : vip.toUpperCase();
    final String displayName = name.trim().isEmpty ? "GUEST" : name;
    
    return Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(1.0), accent.withOpacity(0.7), Colors.transparent],
        ),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
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
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2),
              ),
              Text(
                displayName,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.2),
              ),
            ],
          ),
          const Spacer(),
          Text(
            "Joined Room",
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
