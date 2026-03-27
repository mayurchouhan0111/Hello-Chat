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
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:ui';

import '../../../profile/presentation/screens/my_profile_screen.dart';
import '../../../moments/presentation/screens/square_screen.dart';
import '../../../leaderboards/presentation/screens/leaderboard_screen.dart';

import '../../../chats/presentation/screens/chat_list_screen.dart';
import '../../../../core/providers/chat_provider.dart';

import '../../../../core/services/broadcast_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0; 
  int _currentBannerIndex = 0;

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
        onTap: (i) => setState(() => _currentIndex = i),
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
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.15)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                  child: const Icon(Icons.volume_up_rounded, size: 16, color: Color(0xFF00838F)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Color(0xFF075E6F),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
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
// (skipping unchanged code)
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
                  onPressed: () {},
                  icon: const Icon(Icons.search_rounded, color: Colors.black87, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                _buildAddHomeIcon(26),
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
                        height: 120,
                        margin: const EdgeInsets.only(top: 0),
                        child: CarouselSlider(
                          options: CarouselOptions(
                            height: 120,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        _buildMiniCategoryCard("Contribution", const LinearGradient(colors: [Color(0xFFFF9A8B), Color(0xFFFF6A88)])),
                        const SizedBox(width: 8),
                        _buildMiniCategoryCard("Charm", const LinearGradient(colors: [Color(0xFF8BC6EC), Color(0xFF9599E2)])),
                        const SizedBox(width: 8),
                        _buildMiniCategoryCard("Room", const LinearGradient(colors: [Color(0xFF21D4FD), Color(0xFFB721FF)])),
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
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
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
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? Colors.black : Colors.grey[500],
          fontSize: 18,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPopularHeader(bool isActive) {
    return GestureDetector(
      onTap: () => ref.read(roomFilterProvider.notifier).state = RoomFilter.popular,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny_rounded, color: Color(0xFF00E5FF), size: 20),
          const SizedBox(width: 4),
          Text(
            "Popular",
            style: TextStyle(
              color: isActive ? Colors.black : Colors.grey[500],
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddHomeIcon(double size) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.createRoom),
      child: Icon(Icons.add_home_work_rounded, color: const Color(0xFF00E5FF), size: size),
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
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                      banner.buttonText ?? "Go to Recharge >>>",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildMiniCategoryCard(String title, LinearGradient gradient) {
    return Expanded(
      child: Container(
        height: 60, // Reduced from 72
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20), // More "cute" rounded corners
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10), // Reduced from 12
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title, 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
            ),
            Row(
              children: List.generate(3, (index) => Container(
                margin: const EdgeInsets.only(right: 6),
                width: 14, // Shrink internal elements
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGridItem(RoomModel room) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.liveRoom, extra: room.roomId),
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
                        const Icon(Icons.bar_chart, color: Colors.white, size: 10),
                        Text(" ${room.currentUsersCount}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                    "Welcome", // Compacted text
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
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
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBannerAction(BuildContext context, BannerModel banner) async {
    // Action Logic
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

  static const _activeColor = Color(0xFF534AB7);
  static const _inactiveColor = Color(0xFF888780);

  static const _items = [
    _NavItem(label: 'Home', painter: _HomePainter()),
    _NavItem(label: 'Party', painter: _PartyPainter()),
    _NavItem(label: 'Video', painter: _VideoPainter()),
    _NavItem(label: 'Chat', painter: _ChatPainter()),
    _NavItem(label: 'Profile', painter: _ProfilePainter()),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x26000000), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68, 
          child: Row(
            children: List.generate(_items.length, (i) {
              final isActive = i == currentIndex;
              final color = isActive ? _activeColor : _inactiveColor;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Permanent Highlight Circle for Video Tab (Index 2)
                      if (i == 2)
                        Container(
                          width: 62, // Increased from 52
                          height: 62,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.35),
                            shape: BoxShape.circle,
                          ),
                        ),
                      // Chat Unread Badge (Index 3)
                      if (i == 3 && unreadCount > 0)
                        Positioned(
                          top: 10,
                          right: 18,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              "$unreadCount", 
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: 26,
                            height: 26,
                            child: CustomPaint(
                              painter: _items[i].painter.withColor(color),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: color,
                              letterSpacing: 0.2,
                            ),
                            child: Text(_items[i].label),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 4 : 0,
                            height: isActive ? 4 : 0,
                            decoration: BoxDecoration(
                              color: _activeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final _NavIconPainter painter;
  const _NavItem({required this.label, required this.painter});
}

abstract class _NavIconPainter extends CustomPainter {
  final Color color;
  const _NavIconPainter({this.color = const Color(0xFF888780)});
  _NavIconPainter withColor(Color c);
  Paint get strokePaint => Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round;
  Paint get fillPaint => Paint()..color = color..style = PaintingStyle.fill;
  void scaleCanvas(Canvas canvas, Size size) { canvas.scale(size.width / 24, size.height / 24); }
  @override bool shouldRepaint(covariant _NavIconPainter old) => old.color != color;
}

class _HomePainter extends _NavIconPainter {
  const _HomePainter({super.color});
  @override _HomePainter withColor(Color c) => _HomePainter(color: c);
  @override void paint(Canvas canvas, Size size) {
    scaleCanvas(canvas, size);
    final path = Path()..moveTo(3, 9.5)..lineTo(12, 3)..lineTo(21, 9.5)..lineTo(21, 20)..cubicTo(21, 20.55, 20.55, 21, 20, 21)..lineTo(15, 21)..lineTo(15, 15)..lineTo(9, 15)..lineTo(9, 21)..lineTo(4, 21)..cubicTo(3.45, 21, 3, 20.55, 3, 20)..close();
    canvas.drawPath(path, strokePaint);
  }
}

class _PartyPainter extends _NavIconPainter {
  const _PartyPainter({super.color});
  @override _PartyPainter withColor(Color c) => _PartyPainter(color: c);
  @override void paint(Canvas canvas, Size size) {
    scaleCanvas(canvas, size);
    final popper = Path()..moveTo(5.5, 19.5)..lineTo(3, 21)..lineTo(4.5, 18.5)..lineTo(13, 7)..lineTo(16, 10)..close();
    canvas.drawPath(popper, strokePaint);
    final horn = Path()..moveTo(13, 7)..cubicTo(13, 7, 14, 4, 17, 4)..cubicTo(17, 4, 17, 7, 14.5, 8);
    canvas.drawPath(horn, strokePaint);
    canvas.drawCircle(const Offset(19, 5), 1.0, fillPaint);
    canvas.drawCircle(const Offset(20.5, 8.5), 0.8, fillPaint);
    canvas.drawCircle(const Offset(16, 2.5), 0.8, fillPaint);
    final sp = strokePaint..strokeWidth = 1.5;
    canvas.drawLine(const Offset(7, 6), const Offset(8, 4), sp);
    canvas.drawLine(const Offset(10, 4), const Offset(11, 2), sp);
    canvas.drawLine(const Offset(13, 6), const Offset(14, 4), sp);
  }
}

class _VideoPainter extends _NavIconPainter {
  const _VideoPainter({super.color});
  @override _VideoPainter withColor(Color c) => _VideoPainter(color: c);
  @override void paint(Canvas canvas, Size size) {
    scaleCanvas(canvas, size);
    final rrect = RRect.fromRectAndRadius(const Rect.fromLTWH(2, 5, 15, 14), const Radius.circular(2));
    canvas.drawRRect(rrect, strokePaint);
    final cam = Path()..moveTo(17, 9)..lineTo(22, 6.5)..lineTo(22, 17.5)..lineTo(17, 15)..close();
    canvas.drawPath(cam, strokePaint);
  }
}

class _ChatPainter extends _NavIconPainter {
  const _ChatPainter({super.color});
  @override _ChatPainter withColor(Color c) => _ChatPainter(color: c);
  @override void paint(Canvas canvas, Size size) {
    scaleCanvas(canvas, size);
    final bubble = Path()..moveTo(4, 4)..lineTo(20, 4)..cubicTo(20.55, 4, 21, 4.45, 21, 5)..lineTo(21, 16)..cubicTo(21, 16.55, 20.55, 17, 20, 17)..lineTo(7, 17)..lineTo(3, 21)..lineTo(3, 5)..cubicTo(3, 4.45, 3.45, 4, 4, 4)..close();
    canvas.drawPath(bubble, strokePaint);
    canvas.drawCircle(const Offset(8.5, 10.5), 1.0, fillPaint);
    canvas.drawCircle(const Offset(12, 10.5), 1.0, fillPaint);
    canvas.drawCircle(const Offset(15.5, 10.5), 1.0, fillPaint);
  }
}

class _ProfilePainter extends _NavIconPainter {
  const _ProfilePainter({super.color});
  @override _ProfilePainter withColor(Color c) => _ProfilePainter(color: c);
  @override void paint(Canvas canvas, Size size) {
    scaleCanvas(canvas, size);
    canvas.drawCircle(const Offset(12, 8), 4, strokePaint);
    final shoulder = Path()..moveTo(4, 20)..cubicTo(4, 17.24, 7.58, 15, 12, 15)..cubicTo(16.42, 15, 20, 17.24, 20, 20);
    canvas.drawPath(shoulder, strokePaint..strokeCap = StrokeCap.round);
  }
}
