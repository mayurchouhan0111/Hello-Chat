import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../providers/room_provider.dart';
import '../providers/profile_provider.dart';
import '../router/app_router.dart';
import 'package:hello_chat/core/utils/room_navigation_helper.dart';

class GlobalEngagementBanner extends ConsumerStatefulWidget {
  const GlobalEngagementBanner({super.key});

  @override
  ConsumerState<GlobalEngagementBanner> createState() => _GlobalEngagementBannerState();
}

class _GlobalEngagementBannerState extends ConsumerState<GlobalEngagementBanner> {
  StreamSubscription? _subscription;
  Map<String, dynamic>? _activeEvent;
  bool _isVisible = false;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _subscription = FirebaseFirestore.instance
        .collection('global_messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final data = snapshot.docs.first.data();
      if (data['type'] == 'rocket_launch') {
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) return;

        final diff = DateTime.now().difference(createdAt).inSeconds.abs();
        
        // Show if message is fresh (last 5 minutes)
        if (diff < 300) {
          _showBanner(data);
        }
      }
    });
  }

  void _showBanner(Map<String, dynamic> data) {
    _autoHideTimer?.cancel();
    
    // Check if user is already in this room
    final userProfile = ref.read(currentUserProfileProvider).value;
    if (userProfile?.activeRoomId == data['roomId']) {
      setState(() => _isVisible = false);
      return;
    }

    // Delay showing the banner until the main rocket animation (~7-8s) finishes
    Future.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      
      setState(() {
        _activeEvent = data;
        _isVisible = true;
      });

      // Auto-hide after 30 seconds of engagement
      _autoHideTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _isVisible = false);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _activeEvent == null) return const SizedBox.shrink();

    final roomId = _activeEvent!['roomId'] as String;
    final roomAsync = ref.watch(currentRoomStreamProvider(roomId));
    final userProfile = ref.watch(currentUserProfileProvider).value;

    // Auto-hide if user joins the room while banner is visible
    if (userProfile?.activeRoomId == roomId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isVisible) setState(() => _isVisible = false);
      });
      return const SizedBox.shrink();
    }

    return roomAsync.when(
      data: (room) {
        if (room == null || room.status != 'active') {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -100 * (1 - value)),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () {
                  setState(() => _isVisible = false);
                  RoomNavigationHelper.joinRoom(context, ref, roomId);
                },
                  child: Container(
                    height: 70,
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E1B4B).withOpacity(0.95),
                          const Color(0xFF312E81).withOpacity(0.95),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCC00FF).withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.5), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      color: Colors.transparent,
                      child: Stack(
                        children: [
                          // Animated Background Element
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Icon(
                              Icons.rocket_outlined,
                              size: 100,
                              color: Colors.white.withOpacity(0.05),
                            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 10.seconds),
                          ),
    
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Level Badge
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCC00FF).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 24)
                                      .animate(onPlay: (c) => c.repeat())
                                      .shimmer(duration: 2.seconds)
                                      .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), curve: Curves.easeInOutSine),
                                ),
                                const SizedBox(width: 12),
                                
                                // Text Info
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "🚀 LEVEL ${_activeEvent!['level']} ROCKET LAUNCHED!",
                                        style: const TextStyle(
                                          color: Color(0xFFCC00FF),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "🔥 ${room.currentUsersCount} users are joining in ${room.name}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
    
                                // Join Button
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCC00FF),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.4), blurRadius: 8),
                                    ],
                                  ),
                                  child: const Text(
                                    "JOIN",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                                  ),
                                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 800.ms),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
