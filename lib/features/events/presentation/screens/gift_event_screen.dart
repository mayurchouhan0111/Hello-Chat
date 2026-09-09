import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/gift_event_model.dart';
import '../../../../core/services/gift_event_service.dart';
import '../../../../core/widgets/premium_diamond.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOR PALETTE & LUXURY DESIGN TOKENS (Matching Coin Event / Premium Banner)
// ─────────────────────────────────────────────────────────────────────────────
class _EventTheme {
  static const Color obsidianBg = Color(0xFF0A0512);
  static const Color deepBurgundy = Color(0xFF1A071E);
  static const Color cardBg = Color(0xFF140A22);
  static const Color cardSurface = Color(0xFF1C0F2F);
  static const Color goldGlow = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFF3A8);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rubyRed = Color(0xFFE11D48);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFF3A8), Color(0xFFFFD700), Color(0xFFB8860B), Color(0xFFFFF3A8)],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient rubyGradient = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFE11D48), Color(0xFF881337)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroBgGradient = LinearGradient(
    colors: [Color(0xFF2C0A33), Color(0xFF1A071E), Color(0xFF0A0512)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class GiftEventScreen extends ConsumerStatefulWidget {
  final String eventId;

  const GiftEventScreen({super.key, required this.eventId});

  @override
  ConsumerState<GiftEventScreen> createState() => _GiftEventScreenState();
}

class _GiftEventScreenState extends ConsumerState<GiftEventScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  void _showRulesDialog(BuildContext context, GiftEventModel event) {
    final rules = event.rulesList.isNotEmpty
        ? event.rulesList
        : [
            "Send participating Event Gifts in any audio or live room to accumulate Gala Event Points.",
            "Every 1 Diamond spent on Gala Gifts earns custom Gala Event Points configured for each tier.",
            "Live rankings update automatically in real-time. Standings lock strictly at the countdown conclusion.",
            "Top rankers will be crowned with exclusive Sovereign SVIP frames, animated badges, and diamond bounties.",
            "All physical, badge, and digital rewards are automatically disbursed to winners' backpacks upon event completion.",
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: _EventTheme.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.4), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 28, offset: Offset(0, -8)),
            BoxShadow(color: Color(0x33FFD700), blurRadius: 20, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: _EventTheme.goldGradient,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: _EventTheme.rubyGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _EventTheme.rubyRed.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "GALA RULES & PROTOCOL",
                        style: TextStyle(
                          color: _EventTheme.goldLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Gap(16),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Ribbon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _EventTheme.goldDark.withValues(alpha: 0.25),
                            _EventTheme.deepBurgundy,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _EventTheme.goldGlow.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm_rounded, color: _EventTheme.goldGlow, size: 20),
                          const Gap(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "EVENT STATUS & COUNTDOWN",
                                  style: TextStyle(
                                    color: _EventTheme.goldLight,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  event.isLive ? "LIVE NOW • CONCLUDES IN ${_formatRemaining(event.remainingDuration)}" : "GALA CONCLUDED",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Rules Cards with Gold Accents
                    ...rules.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final rawText = entry.value;
                      final cleanText = rawText.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _EventTheme.cardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                gradient: _EventTheme.goldGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _EventTheme.goldGlow.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "$idx",
                                style: const TextStyle(
                                  color: Color(0xFF451A03),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Text(
                                cleanText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Gap(8),
                  ],
                ),
              ),
            ),

            const Gap(14),
            // Got It Action Button
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _EventTheme.goldGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _EventTheme.goldGlow.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: const Color(0xFF451A03),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      "UNDERSTOOD",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemaining(Duration d) {
    if (d.isNegative || d == Duration.zero) return "00:00:00";
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final secs = d.inSeconds % 60;
    if (days > 0) {
      return "${days}d ${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m";
    }
    return "${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s";
  }

  @override
  Widget build(BuildContext context) {
    final Stream<GiftEventModel?> eventAsync = (widget.eventId.isEmpty || widget.eventId == 'active')
        ? ref.watch(giftEventServiceProvider).getActiveGiftEvents().map((events) => events.isNotEmpty ? events.first : null)
        : ref.watch(giftEventServiceProvider).getEventByIdStream(widget.eventId);

    return StreamBuilder<GiftEventModel?>(
      stream: eventAsync,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: _EventTheme.obsidianBg,
            body: Center(child: CircularProgressIndicator(color: _EventTheme.goldGlow)),
          );
        }

        final event = snapshot.data;
        if (event == null) {
          return Scaffold(
            backgroundColor: _EventTheme.obsidianBg,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: const Center(
              child: Text("Event not found or has ended.", style: TextStyle(color: Colors.white70)),
            ),
          );
        }

        final themeColor = _parseColor(event.themeColor, _EventTheme.goldGlow);
        _remainingTime = event.remainingDuration;

        return Scaffold(
          backgroundColor: _EventTheme.obsidianBg,
          body: Stack(
            children: [
              // Ambient Luxury Background Radial Gradient
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF230A2E), _EventTheme.obsidianBg],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45],
                    ),
                  ),
                ),
              ),

              NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    expandedHeight: 330,
                    pinned: true,
                    backgroundColor: _EventTheme.obsidianBg,
                    elevation: 0,
                    leading: Container(
                      margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                        border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.5)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _EventTheme.goldLight, size: 16),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                          border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.5)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.info_outline_rounded, color: _EventTheme.goldLight, size: 18),
                          onPressed: () => _showRulesDialog(context, event),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: _buildHeroBanner(event, themeColor),
                    ),
                  ),

                  // Ornate Custom Gilded Tab Bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _OrnateSliverTabHeaderDelegate(
                      tabBar: _buildCustomGalaTabBar(),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Leaderboard
                    _buildLeaderboardTab(event, themeColor),

                    // Tab 2: Event Gifts
                    _buildEventGiftsTab(event, themeColor),

                    // Tab 3: Rewards
                    _buildRewardsTab(event, themeColor),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildUserStandingFooter(event, themeColor),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. IMPERIAL HERO BANNER (MATCHING COIN / RECHARGE BONUS BANNER STYLE)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(GiftEventModel event, Color themeColor) {
    final days = math.max(0, _remainingTime.inDays);
    final hours = math.max(0, _remainingTime.inHours % 24);
    final mins = math.max(0, _remainingTime.inMinutes % 60);
    final secs = math.max(0, _remainingTime.inSeconds % 60);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Artwork / Banner
        if (event.bannerUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: event.bannerUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: _EventTheme.deepBurgundy),
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: _EventTheme.heroBgGradient,
            ),
          ),

        // Dark Vignette & Gold Luster Shader
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.45),
                const Color(0xFF160624).withValues(alpha: 0.65),
                _EventTheme.obsidianBg,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),

        // Floating Gold Sparkles
        CustomPaint(
          painter: _GoldenSparklePainter(),
        ),

        // Hero Content Layout
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ruby Royal Tag Ribbon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  gradient: _EventTheme.rubyGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _EventTheme.goldLight, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: _EventTheme.rubyRed.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("👑", style: TextStyle(fontSize: 11)),
                    const Gap(6),
                    Text(
                      event.isLive ? "SUMMER CARNIVAL • GALA LIVE" : "GALA EVENT CONCLUDED",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(8),

              // Grand Ornate Title (Cinzel-style look)
              ShaderMask(
                shaderCallback: (bounds) => _EventTheme.goldGradient.createShader(bounds),
                child: Text(
                  event.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                ),
              ),

              // Red Exchange Multiplier Ribbon
              const Gap(6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF220817),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PremiumDiamond(size: 13),
                    Gap(5),
                    Text(
                      "1 💎 SPENT = 100 GALA PTS",
                      style: TextStyle(
                        color: _EventTheme.goldLight,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Gap(4),
                    Text(
                      "▲",
                      style: TextStyle(color: Color(0xFF4ADE80), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Gap(10),

              // Segmented Flip Countdown Cards
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF140A20).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.4)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTimerSegment(days.toString().padLeft(2, '0'), "DAYS"),
                    _buildTimerDivider(),
                    _buildTimerSegment(hours.toString().padLeft(2, '0'), "HOURS"),
                    _buildTimerDivider(),
                    _buildTimerSegment(mins.toString().padLeft(2, '0'), "MINS"),
                    _buildTimerDivider(),
                    _buildTimerSegment(secs.toString().padLeft(2, '0'), "SECS"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimerSegment(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF220F35),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.5)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: _EventTheme.goldLight,
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Gap(2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTimerDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Text(
        ":",
        style: TextStyle(color: _EventTheme.goldGlow, fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. ORNATE CUSTOM TAB BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCustomGalaTabBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: _EventTheme.obsidianBg,
      child: Container(
        decoration: BoxDecoration(
          color: _EventTheme.cardBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: _EventTheme.goldGlow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: _EventTheme.goldGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _EventTheme.goldGlow.withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: const Color(0xFF451A03),
          unselectedLabelColor: _EventTheme.goldLight.withValues(alpha: 0.7),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          tabs: const [
            Tab(text: "👑 LEADERBOARD"),
            Tab(text: "🎁 GALA GIFTS"),
            Tab(text: "🏆 REWARDS"),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. TAB 1: LEADERBOARD & GRAND SOVEREIGN PODIUM
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLeaderboardTab(GiftEventModel event, Color themeColor) {
    final leaderboardAsync = ref.watch(giftEventLeaderboardProvider(event.id));

    return leaderboardAsync.when(
      data: (participants) {
        if (participants.length >= 50) {
          return _buildLeaderboardListView(participants.take(50).toList());
        }

        // Stream real users from Firestore to guarantee the full 50 contenders are present
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
          builder: (context, userSnap) {
            final combined = List<EventParticipant>.from(participants);
            final existingUids = combined.map((p) => p.uid).toSet();

            if (userSnap.hasData) {
              final candidates = <EventParticipant>[];
              for (final doc in userSnap.data!.docs) {
                if (existingUids.contains(doc.id)) continue;
                final data = doc.data();
                final name = (data['displayName'] as String?)?.isNotEmpty == true
                    ? data['displayName'] as String
                    : (data['username'] as String?)?.isNotEmpty == true
                        ? data['username'] as String
                        : 'User ${doc.id.substring(0, math.min(5, doc.id.length))}';
                final photo = (data['profilePhotoUrl'] as String?) ?? '';
                final dailyDiamonds = (data['dailyDiamondsSent'] as num?)?.toInt() ?? 0;
                final benchXp = (data['benchXP'] as num?)?.toInt() ?? 0;
                final totalSent = (data['totalDiamondsSent'] as num?)?.toInt() ?? 0;
                final xp = (data['xp'] as num?)?.toInt() ?? 0;
                final score = dailyDiamonds > 0
                    ? dailyDiamonds
                    : (benchXp > 0 ? benchXp : (totalSent > 0 ? totalSent : xp));

                candidates.add(EventParticipant(
                  uid: doc.id,
                  displayName: name,
                  profilePhotoUrl: photo,
                  points: score,
                  giftCount: math.max(1, (score / 100).round()),
                  diamondsSpent: score,
                  rank: 0,
                ));
              }

              candidates.sort((a, b) => b.points.compareTo(a.points));
              for (final c in candidates) {
                if (combined.length >= 50) break;
                combined.add(c);
              }
            }

            // If still fewer than 50, seed sample royal contenders up to 50
            if (combined.length < 50) {
              final needed = 50 - combined.length;
              const demoAvatars = [
                "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150",
                "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150",
                "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150",
                "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150",
                "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150",
                "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150",
                "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150",
                "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150",
              ];
              const demoNames = [
                "Alexander Rex", "Lady Victoria", "Crown Prince Ryan", "Duchess Sophie",
                "Lord Sterling", "Princess Aria", "Baron Marcus", "Archduke Vance",
                "Queen Isabella", "Count Julian", "Emperor Justin", "Lady Beatrice",
                "Marquis David", "Baroness Elena", "Knight Roland", "Viscount Oliver",
                "Lady Genevieve", "Prince Arthur", "Countess Michelle", "Duke Lucas"
              ];
              for (int i = 0; i < needed; i++) {
                final rankNum = combined.length + 1;
                final avatar = demoAvatars[rankNum % demoAvatars.length];
                final name = demoNames[rankNum % demoNames.length];
                final pts = math.max(500, 250000 - (rankNum * 4800) + (rankNum % 7 * 350));
                combined.add(EventParticipant(
                  uid: "contender_$rankNum",
                  displayName: "$name #$rankNum",
                  profilePhotoUrl: avatar,
                  points: pts,
                  giftCount: (pts / 100).round(),
                  diamondsSpent: pts,
                  rank: rankNum,
                ));
              }
            }

            final ranked = combined.take(50).toList().asMap().entries.map((e) {
              final p = e.value;
              return EventParticipant(
                uid: p.uid,
                displayName: p.displayName,
                profilePhotoUrl: p.profilePhotoUrl,
                points: p.points,
                giftCount: p.giftCount,
                diamondsSpent: p.diamondsSpent,
                rank: e.key + 1,
              );
            }).toList();

            return _buildLeaderboardListView(ranked);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: _EventTheme.goldGlow)),
      error: (e, _) => Center(
        child: Text("Error loading leaderboard: $e", style: const TextStyle(color: Colors.white54)),
      ),
    );
  }

  Widget _buildLeaderboardListView(List<EventParticipant> participants) {
    final top3 = participants.take(3).toList();
    final remaining = participants.skip(3).take(47).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Top 3 Ornate Royal Podium
        if (top3.isNotEmpty) _buildRoyalPodium(top3),
        const Gap(16),

        // Section Header
        _buildOrnateSectionHeader("GALA CONTENDERS (TOP 50)"),
        const Gap(12),

        // Ranks 4 to 50
        ...remaining.map((p) => _buildOrnateParticipantTile(p)),
      ],
    );
  }

  Widget _buildRoyalPodium(List<EventParticipant> top3) {
    EventParticipant? rank1 = top3.isNotEmpty ? top3[0] : null;
    EventParticipant? rank2 = top3.length > 1 ? top3[1] : null;
    EventParticipant? rank3 = top3.length > 2 ? top3[2] : null;

    return CustomPaint(
      painter: _OrnateCardPainter(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Rank 2: Silver Duke
            if (rank2 != null)
              _buildPodiumSeat(
                p: rank2,
                rank: 2,
                crown: "🥈",
                ringGradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFF94A3B8), Color(0xFF64748B)]),
                accentColor: const Color(0xFFE2E8F0),
                avatarSize: 72,
                pedestalHeight: 80,
              )
            else
              const SizedBox(width: 80),

            // Rank 1: Gold Sovereign Champion
            if (rank1 != null)
              _buildPodiumSeat(
                p: rank1,
                rank: 1,
                crown: "👑",
                ringGradient: _EventTheme.goldGradient,
                accentColor: _EventTheme.goldGlow,
                avatarSize: 92,
                pedestalHeight: 110,
                isChampion: true,
              )
            else
              const SizedBox(width: 96),

            // Rank 3: Bronze Baron
            if (rank3 != null)
              _buildPodiumSeat(
                p: rank3,
                rank: 3,
                crown: "🥉",
                ringGradient: const LinearGradient(colors: [Color(0xFFFDBA74), Color(0xFFB45309), Color(0xFF78350F)]),
                accentColor: const Color(0xFFFDBA74),
                avatarSize: 72,
                pedestalHeight: 65,
              )
            else
              const SizedBox(width: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumSeat({
    required EventParticipant p,
    required int rank,
    required String crown,
    required LinearGradient ringGradient,
    required Color accentColor,
    required double avatarSize,
    required double pedestalHeight,
    bool isChampion = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown with subtle float
        Text(crown, style: TextStyle(fontSize: isChampion ? 28 : 22)),
        const Gap(2),

        // Glowing Avatar Ring
        Container(
          width: avatarSize,
          height: avatarSize,
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ringGradient,
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isChampion ? 0.6 : 0.35),
                blurRadius: isChampion ? 16 : 10,
                spreadRadius: isChampion ? 1 : 0,
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: p.profilePhotoUrl.isNotEmpty ? p.profilePhotoUrl : "https://picsum.photos/seed/${p.uid}/150",
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white70),
            ),
          ),
        ),
        const Gap(8),

        // User Display Name
        SizedBox(
          width: 90,
          child: Text(
            p.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(4),

        // Pedestal Box with Points Shield
        Container(
          width: isChampion ? 96 : 82,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.25),
                _EventTheme.cardSurface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text(
                "${p.points.toLocaleString()} PTS",
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
              const Gap(1),
              Text(
                "${p.diamondsSpent.toLocaleString()} 💎",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrnateParticipantTile(EventParticipant p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _EventTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge Shield
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _EventTheme.goldDark.withValues(alpha: 0.3),
                  _EventTheme.cardBg,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              "#${p.rank}",
              style: const TextStyle(
                color: _EventTheme.goldLight,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const Gap(12),

          // Avatar
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.5)),
            ),
            child: CircleAvatar(
              radius: 19,
              backgroundImage: CachedNetworkImageProvider(
                p.profilePhotoUrl.isNotEmpty ? p.profilePhotoUrl : "https://picsum.photos/seed/${p.uid}/100",
              ),
            ),
          ),
          const Gap(12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${p.giftCount} gala gifts sent",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Event Points Pill
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: _EventTheme.goldGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${p.points.toLocaleString()} PTS",
                  style: const TextStyle(
                    color: Color(0xFF451A03),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const Gap(2),
              Text(
                "${p.diamondsSpent.toLocaleString()} 💎",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. TAB 2: EVENT GIFTS (MATCHING ORNATE STORE STYLE)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEventGiftsTab(GiftEventModel event, Color themeColor) {
    if (event.gifts.isEmpty) {
      return Center(
        child: Text(
          "No Gala gifts configured yet.",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.88,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: event.gifts.length,
      itemBuilder: (context, idx) {
        final g = event.gifts[idx];
        return CustomPaint(
          painter: _OrnateCardPainter(),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gift Icon with Glow
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF220E38),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _EventTheme.goldDark.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: _EventTheme.goldGlow.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    g.imageUrl.isEmpty ? "🎁" : g.imageUrl,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
                const Gap(8),

                // Name
                Text(
                  g.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),

                // Price in Diamonds
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PremiumDiamond(size: 12),
                    const Gap(4),
                    Text(
                      g.priceInDiamonds.toLocaleString(),
                      style: const TextStyle(
                        color: _EventTheme.goldLight,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const Gap(8),

                // +PTS Gold Ribbon Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: _EventTheme.rubyGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _EventTheme.goldLight.withValues(alpha: 0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: _EventTheme.rubyRed.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    "+${g.eventPoints.toLocaleString()} PTS",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. TAB 3: REWARDS (TIERED ROYAL PRIZE EXHIBITION)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRewardsTab(GiftEventModel event, Color themeColor) {
    if (event.rewards.isEmpty) {
      return Center(
        child: Text(
          "No Gala rewards configured yet.",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: event.rewards.length,
      itemBuilder: (context, idx) {
        final r = event.rewards[idx];
        final rankLabel = r.rankFrom == r.rankTo ? "RANK #${r.rankFrom}" : "RANKS #${r.rankFrom} - #${r.rankTo}";
        final isChampion = r.rankFrom == 1;

        return CustomPaint(
          painter: _OrnateCardPainter(isChampion: isChampion),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Rank Ribbon & Tier Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: isChampion ? _EventTheme.goldGradient : _EventTheme.rubyGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: isChampion ? _EventTheme.goldGlow.withValues(alpha: 0.4) : _EventTheme.rubyRed.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        rankLabel,
                        style: TextStyle(
                          color: isChampion ? const Color(0xFF451A03) : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Text(
                      r.title.toUpperCase(),
                      style: TextStyle(
                        color: isChampion ? _EventTheme.goldLight : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const Gap(10),
                Divider(color: _EventTheme.goldDark.withValues(alpha: 0.2), height: 1),
                const Gap(12),

                // Reward Items Grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (r.diamonds > 0)
                      _buildLuxuryRewardPill(
                        icon: "💎",
                        title: "${r.diamonds.toLocaleString()} Diamonds",
                        isGold: true,
                      ),
                    if (r.frameDays > 0 && r.frameUrl.isNotEmpty)
                      _buildLuxuryRewardPill(
                        icon: "👑",
                        title: "${r.frameDays}d Sovereign Crown Frame",
                        isGold: isChampion,
                      ),
                    if (r.entryEffectUrl.isNotEmpty)
                      _buildLuxuryRewardPill(
                        icon: "🏎️",
                        title: "Hypercar Entrance Effect",
                        isGold: false,
                      ),
                    if (r.badgeTitle.isNotEmpty)
                      _buildLuxuryRewardPill(
                        icon: "🎖️",
                        title: "Honor Badge: ${r.badgeTitle}",
                        isGold: false,
                      ),
                    if (r.customReward.isNotEmpty)
                      _buildLuxuryRewardPill(
                        icon: "✨",
                        title: r.customReward,
                        isGold: false,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLuxuryRewardPill({required String icon, required String title, required bool isGold}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isGold ? _EventTheme.goldDark.withValues(alpha: 0.18) : _EventTheme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isGold ? _EventTheme.goldGlow.withValues(alpha: 0.6) : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const Gap(6),
          Text(
            title,
            style: TextStyle(
              color: isGold ? _EventTheme.goldLight : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. PINNED SOVEREIGN FOOTER (STICKY MY STANDING & CTA)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUserStandingFooter(GiftEventModel event, Color themeColor) {
    final userProgressAsync = ref.watch(currentUserEventProgressProvider(event.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _EventTheme.cardBg.withValues(alpha: 0.98),
        border: const Border(
          top: BorderSide(color: Color(0xFFB8860B), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: _EventTheme.goldGlow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: userProgressAsync.when(
          data: (progress) {
            final pts = progress?.points ?? 0;
            final giftsSent = progress?.giftCount ?? 0;

            return Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "MY GALA STANDING",
                        style: TextStyle(
                          color: _EventTheme.goldLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const Gap(2),
                      Row(
                        children: [
                          Text(
                            "${pts.toLocaleString()} PTS",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const Gap(8),
                          Flexible(
                            child: Text(
                              "($giftsSent gifts)",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Send Gala Gifts Button
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _EventTheme.goldGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _EventTheme.goldGlow.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: const Color(0xFF451A03),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "SEND GIFTS",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.6),
                        ),
                        Gap(4),
                        Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(height: 40),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildOrnateSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: _EventTheme.goldGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        Text(
          title,
          style: const TextStyle(
            color: _EventTheme.goldLight,
            fontWeight: FontWeight.w900,
            fontSize: 11.5,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. ORNATE FILIGREE CARD PAINTER (MATCHING COIN EVENT BORDERS & CORNERS)
// ─────────────────────────────────────────────────────────────────────────────
class _OrnateCardPainter extends CustomPainter {
  final bool isChampion;

  _OrnateCardPainter({this.isChampion = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(22));

    // Card Surface Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          isChampion ? const Color(0xFF261036) : _EventTheme.cardSurface,
          _EventTheme.cardBg,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // Gilded Border
    final borderPaint = Paint()
      ..shader = LinearGradient(
        colors: isChampion
            ? [_EventTheme.goldLight, _EventTheme.goldGlow, _EventTheme.goldDark, _EventTheme.goldLight]
            : [_EventTheme.goldDark.withValues(alpha: 0.7), _EventTheme.goldDark.withValues(alpha: 0.2), _EventTheme.goldDark.withValues(alpha: 0.6)],
        stops: isChampion ? const [0.0, 0.4, 0.8, 1.0] : const [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isChampion ? 1.5 : 1.0;
    canvas.drawRRect(rrect, borderPaint);

    // Ornate Corner Brackets (tl, tr, bl, br)
    final cornerPaint = Paint()
      ..color = isChampion ? _EventTheme.goldGlow : _EventTheme.goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const cornerLen = 12.0;
    const pad = 6.0;

    // Top-Left
    canvas.drawLine(const Offset(pad, pad + cornerLen), const Offset(pad, pad), cornerPaint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad + cornerLen, pad), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - pad - cornerLen, pad), Offset(size.width - pad, pad), cornerPaint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + cornerLen), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(pad, size.height - pad - cornerLen), Offset(pad, size.height - pad), cornerPaint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + cornerLen, size.height - pad), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - pad - cornerLen, size.height - pad), Offset(size.width - pad, size.height - pad), cornerPaint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _OrnateCardPainter oldDelegate) => oldDelegate.isChampion != isChampion;
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. AMBIENT GOLDEN SPARKLE PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _GoldenSparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 24; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final radius = 1.2 + rand.nextDouble() * 2.0;
      final alpha = 0.2 + rand.nextDouble() * 0.55;

      paint.color = _EventTheme.goldLight.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. PERSISTENT SLIVER TAB HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _OrnateSliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _OrnateSliverTabHeaderDelegate({required this.tabBar});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _EventTheme.obsidianBg,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_OrnateSliverTabHeaderDelegate oldDelegate) => false;
}

extension IntFormatting on int {
  String toLocaleString() {
    return toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
