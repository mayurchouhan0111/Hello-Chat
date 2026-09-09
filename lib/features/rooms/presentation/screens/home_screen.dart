import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/constants/app_spacing.dart';
import 'package:hello_chat/core/constants/app_text_styles.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/providers/room_filter_provider.dart';
import 'package:hello_chat/core/services/banner_service.dart';
import 'package:hello_chat/core/models/banner_model.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/providers/ranking_preview_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import 'package:hello_chat/core/utils/room_navigation_helper.dart';

import '../../../profile/presentation/screens/my_profile_screen.dart';
import '../../../moments/presentation/screens/square_screen.dart';
import '../../../leaderboards/presentation/screens/celebrity_ranking_screen.dart';

import '../../../chats/presentation/screens/chat_list_screen.dart';
import '../../../../core/providers/chat_provider.dart';

import '../../../../core/services/broadcast_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/gift_event_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0; 
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingRoute();
    });
  }

  void _checkPendingRoute() {
    final route = NotificationService.pendingRoute;
    if (route != null) {
      NotificationService.clearPendingRoute();
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildLiveTab(), // Home / Live
          const SquareScreen(), // Square / Party
          const Center(child: Text("Video Screen (Coming Soon)")), 
          const ChatListScreen(), // Chat Tab (Month 5)
          const MyProfileScreen(), // Me / Profile
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 2) {
            final activeRoom = ref.read(userActiveRoomStreamProvider).value;
            if (activeRoom != null) {
              RoomNavigationHelper.joinRoom(context, ref, activeRoom.roomId, preloadedRoom: activeRoom);
            } else {
              context.push(AppRoutes.createRoom);
            }
          } else {
            setState(() => _currentIndex = i);
          }
        },
        unreadCount: ref.watch(unreadTotalProvider).value ?? 0,
      ),
    );
  }

  Widget _buildBroadcastTicker() {
    return ref.watch(activeBroadcastsProvider).when(
      data: (announcements) {
        if (announcements.isEmpty) return const SizedBox.shrink();
        final msg = announcements.first.message;

        return Container(
          width: double.infinity,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      child: const Icon(Icons.volume_up_rounded, size: 14, color: Color(0xFF00838F)),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          "hello everyone", // Placeholder from image
                          style: TextStyle(
                            color: Color(0xFF075E6F),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLiveTab() {
    final activeFilter = ref.watch(roomFilterProvider);
    
    return SafeArea(
      child: Column(
        children: [
          _buildBroadcastTicker(),
          // 1. Header with Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildHeaderText("Following", RoomFilter.following, activeFilter == RoomFilter.following),
                        const SizedBox(width: 14),
                        _buildPopularHeader(activeFilter == RoomFilter.popular),
                        const SizedBox(width: 14),
                        _buildHeaderText("Recommended", RoomFilter.recommended, activeFilter == RoomFilter.recommended),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => context.push(AppRoutes.search),
                  icon: const Icon(Icons.search_rounded, color: Colors.black87, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),

                const SizedBox(width: 12),
                _buildAddHomeIcon(24),
              ],
            ),
          ),

          Expanded(
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                // Banner Section
                SliverToBoxAdapter(
                  child: ref.watch(activeBannersStreamProvider).when(
                    data: (banners) {
                      if (banners.isEmpty) return const SizedBox.shrink();
                      return Container(
                        height: 100, // Compact height
                        margin: const EdgeInsets.only(top: 0),
                        child: CarouselSlider(
                          options: CarouselOptions(
                            height: 100,
                            viewportFraction: 1.0,
                            enlargeCenterPage: false,
                            autoPlay: true,
                            onPageChanged: (index, reason) => setState(() => _currentBannerIndex = index),
                          ),
                          items: banners.map((banner) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildBannerCard(banner),
                          )).toList(),
                        ),
                      );
                    },
                    loading: () => _buildBannerShimmer(),
                    error: (e, __) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                // Live Gift Event Entry Banner (appears when an event is live)
                SliverToBoxAdapter(
                  child: _buildLiveGiftEventBanner(),
                ),
                // Blinkit-Style Premium Category Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        _buildBlinkitCategoryCard(
                          title: "Contribution",
                          subtitle: "Top Senders",
                          badgeIcon: "👑",
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3366), Color(0xFFFF6B4A), Color(0xFFFFA000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          glowColor: const Color(0xFFFF3366),
                          collection: "users",
                          field: "dailyDiamondsSent",
                          tabIndex: 0,
                        ),
                        const SizedBox(width: 5),
                        _buildBlinkitCategoryCard(
                          title: "Charm",
                          subtitle: "Top Receivers",
                          badgeIcon: "💖",
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7928CA), Color(0xFFB800E6), Color(0xFFFF0080)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          glowColor: const Color(0xFFB800E6),
                          collection: "users",
                          field: "dailyBeansReceived",
                          tabIndex: 1,
                        ),
                        const SizedBox(width: 5),
                        _buildBlinkitCategoryCard(
                          title: "Room",
                          subtitle: "Hot Voice",
                          badgeIcon: "🎙️",
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00B4D8), Color(0xFF0077B6), Color(0xFF06D6A0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          glowColor: const Color(0xFF00B4D8),
                          collection: "rooms",
                          field: "currentUsersCount",
                          tabIndex: 2,
                        ),
                        const SizedBox(width: 5),
                        _buildBlinkitCategoryCard(
                          title: "Best",
                          subtitle: "All-Stars",
                          badgeIcon: "🏆",
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8F00), Color(0xFFFFB300), Color(0xFFFFD54F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          glowColor: const Color(0xFFFFB300),
                          collection: "users",
                          field: "totalDiamondsSent",
                          tabIndex: 0,
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Room Grid (Dynamically Bound to filteredRoomsProvider)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  sliver: ref.watch(filteredRoomsProvider).when(
                    data: (rooms) {
                      if (rooms.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  activeFilter == RoomFilter.following 
                                    ? "No rooms from people you follow"
                                    : "No live rooms found",
                                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.85, // More compact card aspect
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildImageGridItem(rooms[index]),
                          childCount: rooms.length,
                        ),
                      );
                    },
                    loading: () => _buildRoomGridShimmer(),
                    error: (e, __) => SliverToBoxAdapter(child: Center(child: Text("Error: $e"))),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderText(String text, RoomFilter filter, bool isActive) {
    return GestureDetector(
      onTap: () => ref.read(roomFilterProvider.notifier).state = filter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.grey[400],
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  Widget _buildPopularHeader(bool isActive) {
    return GestureDetector(
      onTap: () => ref.read(roomFilterProvider.notifier).state = RoomFilter.popular,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny_rounded, color: Color(0xFF00E5FF), size: 16),
          const SizedBox(width: 4),
          Text(
            "Popular",
            style: TextStyle(
              color: isActive ? Colors.black : Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddHomeIcon(double size) {
    final activeRoomAsync = ref.watch(userActiveRoomStreamProvider);
    
    return activeRoomAsync.when(
      data: (activeRoom) => GestureDetector(
        onTap: () {
          if (activeRoom != null) {
            RoomNavigationHelper.joinRoom(context, ref, activeRoom.roomId, preloadedRoom: activeRoom);
          } else {
            context.push(AppRoutes.createRoom);
          }
        },
        child: Icon(
          activeRoom != null ? Icons.house_rounded : Icons.add_home_work_rounded, 
          color: const Color(0xFF00E5FF), 
          size: size
        ),
      ),
      loading: () => SizedBox(width: size, height: size, child: const CircularProgressIndicator(strokeWidth: 2)),
      error: (e, __) => GestureDetector(
        onTap: () => context.push(AppRoutes.createRoom),
        child: Icon(Icons.add_home_work_rounded, color: const Color(0xFF00E5FF), size: size),
      ),
    );
  }

  Widget _buildBannerCard(BannerModel banner) {
    final showButton = banner.buttonText != null && banner.buttonText!.isNotEmpty;

    return GestureDetector(
      onTap: () => _handleBannerAction(context, banner),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9900).withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          image: DecorationImage(
            image: CachedNetworkImageProvider(banner.imageUrl),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.2),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showButton)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFEA00), Color(0xFFFF9900)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9900).withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      banner.buttonText!,
                      style: const TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveGiftEventBanner() {
    final activeEvent = ref.watch(primaryActiveGiftEventProvider);
    if (activeEvent == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/gift-event/${activeEvent.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE94057).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('🏆', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LIVE EVENT',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            activeEvent.formattedTimeRemaining,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeEvent.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Join',
                        style: TextStyle(
                          color: Color(0xFFE94057),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFE94057)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBlinkitCategoryCard({
    required String title,
    required String subtitle,
    required String badgeIcon,
    required LinearGradient gradient,
    required Color glowColor,
    required String collection,
    required String field,
    int tabIndex = 0,
  }) {
    final avatarsAsync = ref.watch(topRankedAvatarsProvider((collection: collection, field: field)));
    
    // High-resolution fallback avatars guaranteed to render if Firestore is empty
    const List<String> fallbackAvatars = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&q=80',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
    ];

    return Expanded(
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.leaderboard, extra: tabIndex),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: gradient,
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Angled Glassmorphism Sheen & Cyber Tech Panel Lines
                Positioned(
                  right: -15,
                  top: -20,
                  child: Transform.rotate(
                    angle: -0.35,
                    child: Container(
                      width: 45,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.04),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                // Subtle floating low-poly micro facet
                Positioned(
                  left: -6,
                  bottom: -6,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Micro bokeh particle
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title & Badge Header
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                title,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(badgeIcon, style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                      // Overlapping Avatar Stack with Metallic Glow Rings
                      avatarsAsync.when(
                        data: (urls) {
                          final List<String> displayUrls = [];
                          displayUrls.addAll(urls.where((u) => u.isNotEmpty));
                          for (int i = displayUrls.length; i < 3; i++) {
                            displayUrls.add(fallbackAvatars[i % fallbackAvatars.length]);
                          }

                          return SizedBox(
                            height: 20,
                            child: Row(
                              children: displayUrls.take(3).toList().asMap().entries.map((entry) {
                                final idx = entry.key;
                                final url = entry.value;

                                return Transform.translate(
                                  offset: Offset(-4.0 * idx, 0),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.2),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 3),
                                      ],
                                      image: DecorationImage(
                                        image: CachedNetworkImageProvider(url),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                        loading: () => SizedBox(
                          height: 20,
                          child: Row(
                            children: fallbackAvatars.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final url = entry.value;

                              return Transform.translate(
                                offset: Offset(-4.0 * idx, 0),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.2),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(url),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        error: (e, __) => SizedBox(
                          height: 20,
                          child: Row(
                            children: fallbackAvatars.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final url = entry.value;

                              return Transform.translate(
                                offset: Offset(-4.0 * idx, 0),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.2),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(url),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerShimmer() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white70);
  }

  Widget _buildRoomGridShimmer() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white70),
        childCount: 6,
      ),
    );
  }

  Widget _buildImageGridItem(RoomModel room) {
    return GestureDetector(
      onTap: () => RoomNavigationHelper.joinRoom(context, ref, room.roomId, preloadedRoom: room),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20), // Increased for cuteness
                  child: CachedNetworkImage(
                    imageUrl: room.coverUrl.isEmpty ? "https://picsum.photos/seed/${room.roomId}/400" : room.coverUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // User Count Top Right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bar_chart, color: Colors.white, size: 9),
                        Text(" ${room.currentUsersCount}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                // Title Overlay Bottom
                Positioned(
                  bottom: 12,
                  left: 8,
                  right: 8,
                  child: Text(
                    "Welcome",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6), // Minimal gap
          Row(
            children: [
              Container(
                width: 12, // Minimalized
                height: 12,
                decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.name.split(' ').length > 3 
                    ? '${room.name.split(' ').take(3).join(' ')}...' 
                    : room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, fontSize: 10.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBannerAction(BuildContext context, BannerModel banner) {
    switch (banner.actionType) {
      case 'room_support':
        final activeRoom = ref.read(currentUserProfileProvider).value?.activeRoomId;
        context.push('/room-support', extra: {'roomId': activeRoom});
        break;
      case 'room':
        if (banner.actionValue != null && banner.actionValue!.isNotEmpty) {
          RoomNavigationHelper.joinRoom(context, ref, banner.actionValue!);
        }
        break;
      case 'recharge':
        context.push('/wallet');
        break;
      case 'recharge_event':
        context.push(AppRoutes.rechargeEventDetail);
        break;
      case 'gift_event':
      case 'event':
        final eventId = banner.actionValue;
        if (eventId != null && eventId.isNotEmpty) {
          context.push('/gift-event/$eventId');
        } else {
          context.push('/gift-event/active');
        }
        break;
      case 'profile':
        if (banner.actionValue != null && banner.actionValue!.isNotEmpty) {
          context.push('/user-profile', extra: {'uid': banner.actionValue});
        }
        break;
      case 'external_url':
        break;
    }
  }
}

// ─────────────────────────────────────────────
// CUSTOM BOTTOM NAV BAR
// ─────────────────────────────────────────────
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadCount;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCount = 0,
  });

  static const _activeColor = Color(0xFF111111);
  static const _inactiveColor = Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 58, // Reduced from 64
          child: Row(
            children: List.generate(5, (index) {
              if (index == 2) return _buildCenterFab(context);
              final item = _getNavItem(index);
              final isSelected = currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.06) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform: Matrix4.identity()..scale(isSelected ? 1.12 : 1.0),
                              transformAlignment: Alignment.center,
                              child: _buildSvgIcon(item.svg, 24)
                                  .animate(target: isSelected ? 1.0 : 0.0)
                                  .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.15, 1.15), duration: 250.ms, curve: Curves.elasticOut)
                                  .shimmer(duration: 400.ms, color: Colors.white70),
                            ),
                            if (index == 3 && unreadCount > 0)
                              Positioned(
                                top: -4,
                                right: -5,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE24B4A),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                  child: Text(
                                    "$unreadCount",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF4F46E5) : _inactiveColor,
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 12,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF00E5FF)]),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 1)),
                              ],
                            ),
                          ).animate().scaleX(begin: 0, end: 1, duration: 200.ms),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSvgIcon(String svg, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(svg),
    );
  }

  Widget _buildCenterFab(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(2),
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -10),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF00E5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: SvgPicture.string(
                  '''<svg width="56" height="56" viewBox="0 0 56 56" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <rect x="16" y="19" width="24" height="18" rx="3" fill="#F8FAFC"/>
                    <circle cx="28" cy="28" r="7" fill="#1E40AF"/>
                    <circle cx="28" cy="28" r="4" fill="#E0F2FE"/>
                    <path d="M34 21 L37 21 L35 18 Z" fill="#F1F5F9"/>
                  </svg>''',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _NavItemData _getNavItem(int index) {
    switch (index) {
      case 0:
        return _NavItemData(
          label: 'Live',
          svg: '''<svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M3 9L12 2L21 9V20C21 21.1046 20.1046 22 19 22H5C3.89543 22 3 21.1046 3 20V9Z" fill="#4F9EFF" stroke="#1E5BBF" stroke-width="2"/>
            <polyline points="9 22 9 12 15 12 15 22" fill="#FFEB3B" stroke="#1E5BBF" stroke-width="1.5"/>
          </svg>''',
        );
      case 1:
        return _NavItemData(
          label: 'Party',
          svg: '''<svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 2 L5 21 L19 21 Z" fill="#FF4E8C" stroke="#C81E5E" stroke-width="1.5"/>
            <path d="M12 2 L7.5 18" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>
            <rect x="5" y="20" width="14" height="2.5" rx="1" fill="#FF9F43" stroke="#C81E5E"/>
            <circle cx="12" cy="3.5" r="2.2" fill="#FFEB3B" stroke="#F59E0B"/>
            <circle cx="8" cy="11" r="0.9" fill="#22D3EE"/>
            <circle cx="16" cy="13" r="0.8" fill="#A78BFA"/>
          </svg>''',
        );
      case 3:
        return _NavItemData(
          label: 'Chats',
          svg: '''<svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M21 15C21 16.1046 20.1046 17 19 17H7L3 21V5C3 3.89543 3.89543 3 5 3H19C20.1046 3 21 3.89543 21 5V15Z" 
                  fill="#14B8A6" stroke="#0F766E" stroke-width="1.8"/>
            <path d="M7 8H17" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/>
            <path d="M7 11.5H14" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/>
          </svg>''',
        );
      case 4:
      default:
        return _NavItemData(
          label: 'Me',
          svg: '''<svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="12" cy="13.5" r="9.2" fill="#FCE7C8" stroke="#1F2A37" stroke-width="1.8"/>
            <path d="M6 7 L4 3 L9 6 Z" fill="#FCE7C8" stroke="#1F2A37" stroke-width="1.8"/>
            <path d="M18 7 L20 3 L15 6 Z" fill="#FCE7C8" stroke="#1F2A37" stroke-width="1.8"/>
            <path d="M6.5 6 L5.5 4 L8.5 5.5 Z" fill="#FF6B6B"/>
            <ellipse cx="8.8" cy="13" rx="1.5" ry="2" fill="#1F2A37"/>
            <ellipse cx="15.2" cy="13" rx="1.5" ry="2" fill="#1F2A37"/>
            <ellipse cx="12" cy="15.5" rx="1" ry="0.8" fill="#1F2A37"/>
            <ellipse cx="6.5" cy="16.5" rx="1.9" ry="1.1" fill="#FF9EBE" opacity="0.7"/>
            <ellipse cx="17.5" cy="16.5" rx="1.9" ry="1.1" fill="#FF9EBE" opacity="0.7"/>
          </svg>''',
        );
    }
  }
}

class _NavItemData {
  final String label;
  final String svg;
  const _NavItemData({required this.label, required this.svg});
}

