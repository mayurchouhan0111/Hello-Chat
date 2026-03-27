import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hello_chat/core/constants/app_colors.dart';
import 'package:hello_chat/core/constants/app_spacing.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/providers/user_provider.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/utils/number_formatter.dart';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../chats/presentation/screens/private_chat_screen.dart';

class ProfileDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<ProfileDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider(widget.userId));

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (userData) {
        if (userData == null) return const Scaffold(body: Center(child: Text("User not found")));
        
        return Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: _buildBottomBar(context, userData),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Photo with Overlay Actions
                _buildCoverPhoto(context, userData),

                const SizedBox(height: 12),

                // 2. Identity Row
                _buildIdentity(context, userData),

                const SizedBox(height: 12),

                // 3. Stats Row
                _buildStats(context, userData),

                const SizedBox(height: 12),

                // 4. Badge/Achievement Chips
                _buildBadgeChips(context, userData),

                const SizedBox(height: 12),

                // 5. Agency/Contribution Cards
                _buildAgencyRow(context, userData),

                const SizedBox(height: 12),

                // SECTION SEPARATION (Minimum Gap)
                const Divider(height: 6, thickness: 6, color: Color(0xFFF1F5F9)),

                // 6. Lower Container (White Section)
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      _buildTabs(context),
                      _buildTabContent(context, userData),
                    ],
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, UserModel userData) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == userData.uid) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("Follow", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: () async {
                final chatId = await ref.read(chatServiceProvider).getOrCreateChat(currentUid!, userData.uid);
                if (context.mounted) {
                   Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (c) => PrivateChatScreen(chatId: chatId, otherUid: userData.uid)
                    )
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPhoto(BuildContext context, UserModel userData) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: screenHeight * 0.40, // Reduced from 0.45
          child: CachedNetworkImage(
            imageUrl: userData.profilePhotoUrl.isEmpty ? "https://picsum.photos/seed/${userData.uid}/600" : userData.profilePhotoUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[200]),
          ),
        ),
        // Gradient overlay for readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.4, 0.9],
              ),
            ),
          ),
        ),
        // Top Buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
                Row(
                  children: [
                    IconButton(onPressed: () {}, icon: const Icon(Icons.share_rounded, color: Colors.white)),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Visitor Badge
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_outlined, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                const Text("visitor: 428", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentity(BuildContext context, UserModel userData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("🌹 ", style: TextStyle(fontSize: 16)),
              Text(userData.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text(" 🔥", style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              _buildBadgeIcon(Icons.verified_rounded, Colors.cyan),
              const SizedBox(width: 4),
              _buildBadgeIcon(Icons.male_rounded, Colors.blue),
            ],
          ),
          const SizedBox(height: 2), // Reduced from 4
          Row(
            children: [
              Text("ID: ${userData.username}", style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded, color: Colors.black26, size: 12),
              const VerticalDivider(color: Colors.black12, thickness: 1, indent: 4, endIndent: 4),
              const Text(" Bangladesh", style: TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w500)),
              const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 12),
    );
  }

  Widget _buildStats(BuildContext context, UserModel userData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _buildStatItem(userData.followerCount, "Fans"),
            const VerticalDivider(color: Colors.black12, thickness: 1, indent: 4, endIndent: 4, width: 20),
            _buildStatItem(userData.followingCount, "Following"),
            const VerticalDivider(color: Colors.black12, thickness: 1, indent: 4, endIndent: 4, width: 20),
            _buildStatItem(464, "Beans"),
            const VerticalDivider(color: Colors.black12, thickness: 1, indent: 4, endIndent: 4, width: 20),
            _buildStatItem(userData.diamondBalance, "Diamonds"),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(num count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatCount(count), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBadgeChips(BuildContext context, UserModel userData) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip("💎 ${userData.level}", const Color(0xFFE0F7FA), Colors.cyan),
          const SizedBox(width: 8),
          _buildChip("🏆 Achiever", const Color(0xFFFFF7ED), Colors.orange),
          const SizedBox(width: 8),
          _buildChip("Lv.1", const Color(0xFFF0FDF4), Colors.green),
          const SizedBox(width: 8),
          _buildChipIcon(Icons.shield_rounded, Colors.cyan),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildChipIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 14),
    );
  }

  Widget _buildAgencyRow(BuildContext context, UserModel userData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildAgencyCard(
              "https://picsum.photos/seed/agency/100", 
              "JOY AGENCY", 
              "🏆 Challeng..."
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildContributionCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildAgencyCard(String logoUrl, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedNetworkImage(imageUrl: logoUrl, width: 32, height: 32)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                Text(sub, style: const TextStyle(color: Colors.black45, fontSize: 9)),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, color: Colors.orange, size: 24),
        ],
      ),
    );
  }

  Widget _buildContributionCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(3, (index) => Transform.translate(
              offset: Offset(index * -8.0, 0),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                child: CircleAvatar(radius: 12, backgroundImage: NetworkImage("https://picsum.photos/seed/${index+20}/50")),
              ),
            )),
          ),
          const Text(" Contribution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), // Minimal 4px top padding
      child: Row(
        children: [
          const Icon(Icons.settings_outlined, color: Colors.black45, size: 24),
          const Spacer(),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black38,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const RoundUnderlineTabIndicator(
              borderSide: BorderSide(width: 4, color: Colors.black87),
              width: 18, 
            ),
            indicatorWeight: 4,
            dividerColor: Colors.transparent,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: const [Tab(text: "Profile"), Tab(text: "Dino")],
          ),
        ],
      ),
    );
  }
}

// CUSTOM ROUNDED INDICATOR
class RoundUnderlineTabIndicator extends Decoration {
  final BorderSide borderSide;
  final double width;

  const RoundUnderlineTabIndicator({
    this.borderSide = const BorderSide(width: 4.0, color: Colors.black87),
    this.width = 24.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _RoundUnderlinePainter(this, onChanged);
  }
}

class _RoundUnderlinePainter extends BoxPainter {
  final RoundUnderlineTabIndicator decoration;

  _RoundUnderlinePainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final Paint paint = decoration.borderSide.toPaint()..strokeCap = StrokeCap.round;
    
    // Position it at the bottom middle of the label
    final double xPos = rect.left + (rect.width / 2);
    final double yPos = rect.bottom - (decoration.borderSide.width / 2);
    
    canvas.drawLine(
      Offset(xPos - (decoration.width / 2), yPos),
      Offset(xPos + (decoration.width / 2), yPos),
      paint,
    );
  }
}
  Widget _buildTabContent(BuildContext context, UserModel userData) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Basic information", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.location_on_rounded, "Bangladesh 🇧🇩"),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.language_rounded, "English"),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHobbyIcon(Icons.emoji_emotions_rounded),
              _buildHobbyIcon(Icons.music_note_rounded),
              _buildHobbyIcon(Icons.sports_soccer_rounded),
            ],
          ),
          const SizedBox(height: 24),
          
          // Banner Card
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF475569)]),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Life Restart Test", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text("Start a new life", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  child: Image.network("https://picsum.photos/seed/character/100"), // Placeholder for character
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Audio Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.black54),
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Icon(Icons.volume_up_rounded, color: Colors.black54, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: Colors.black38, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHobbyIcon(IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.black38, size: 18),
    );
  }
