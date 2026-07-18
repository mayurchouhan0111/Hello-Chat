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
                    loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                    error: (e, __) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                // Category Tiles
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _buildMiniCategoryCard("Contribution", const LinearGradient(colors: [Color(0xFFFF9A8B), Color(0xFFFF6A88)]), 0, "users", "benchXP"),
                        const SizedBox(width: 6),
                        _buildMiniCategoryCard("Charm", const LinearGradient(colors: [Color(0xFF8BC6EC), Color(0xFF9599E2)]), 1, "users", "princeXP"),
                        const SizedBox(width: 6),
                        _buildMiniCategoryCard("Room", const LinearGradient(colors: [Color(0xFF21D4FD), Color(0xFFB721FF)]), 2, "rooms", "activeUsers"),
                        const SizedBox(width: 6),
                        _buildMiniCategoryCard("Best", const LinearGradient(colors: [Color(0xFFFACC15), Color(0xFFEAB308)]), 3, "users", "totalXP"),
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
                    loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: CachedNetworkImageProvider(banner.imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.5), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              banner.title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _handleBannerAction(context, banner),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEA00),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      banner.buttonText ?? "Join a Room >>>", // Matching image text
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCategoryCard(String title, LinearGradient gradient, int tabIndex, String collection, String field) {
    final avatarsAsync = ref.watch(topRankedAvatarsProvider((collection: collection, field: field)));
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          context.push(AppRoutes.leaderboard);
        }, 
        child: Container(
          height: 54, // Reduced from 60
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12), // Slightly smaller radius
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
              ),
              avatarsAsync.when(
                data: (urls) {
                  return Row(
                    children: urls.take(3).map((url) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 0.5),
                        image: url.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover) : null,
                      ),
                    )).toList(),
                  );
                },
                loading: () => Row(
                  children: List.generate(2, (index) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  )),
                ),
                error: (e, __) => const SizedBox(height: 14),
              ),
            ],
          ),
        ),
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
      case 'profile':
        if (banner.actionValue != null && banner.actionValue!.isNotEmpty) {
          context.push('/user-profile', extra: {'uid': banner.actionValue});
        }
        break;
      case 'external_url':
        // handled elsewhere if needed
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
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF5F5F8) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedOpacity(
                              opacity: isSelected ? 1.0 : 0.55,
                              duration: const Duration(milliseconds: 120),
                              child: _buildSvgIcon(item.svg, 24),
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
                            color: isSelected ? _activeColor : _inactiveColor,
                            fontSize: 8.5, // Reduced from 10
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
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
                color: const Color(0xFF3B82F6),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.25),
                    blurRadius: 12,
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

