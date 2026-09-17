import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/room_support_provider.dart';
import '../../../../core/models/salary_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/router/app_router.dart';
import '../../../../services/room_support_service.dart';

class RoomSupportScreen extends ConsumerStatefulWidget {
  final String? roomId;
  const RoomSupportScreen({super.key, this.roomId});

  @override
  ConsumerState<RoomSupportScreen> createState() => _RoomSupportScreenState();
}

class _RoomSupportScreenState extends ConsumerState<RoomSupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _cycleTimer;
  Duration _timeLeft = Duration.zero;
  String _phaseText = "";
  bool _isAssignmentOpen = false;
  String? _resolvedRoomId;
  bool _isResolving = false;

  // Ultra-Luxury Gold Design System
  static const Color darkBg = Color(0xFF070604);
  static const Color cardBg = Color(0xFF13100B);
  static const Color tableRowBgEven = Color(0xFF1B1710);
  static const Color tableRowBgOdd = Color(0xFF13100B);
  static const Color borderGold = Color(0xFF4A3A16);
  static const Color borderGoldLight = Color(0xFF7E6327);
  static const Color textGoldHeader = Color(0xFFF7E7B4);
  static const Color textGoldSub = Color(0xFFD8B65C);
  static const Color textGoldBright = Color(0xFFFFE58F);

  // 3D Metallic Gold Gradient Palette
  static const LinearGradient goldHeaderGradient = LinearGradient(
    colors: [
      Color(0xFFE5C058),
      Color(0xFFB38728),
      Color(0xFFFBF5B7),
      Color(0xFFDAA520),
      Color(0xFFA67C1E),
    ],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient metallicBadgeGradient = LinearGradient(
    colors: [
      Color(0xFFFFF1B8),
      Color(0xFFD4AF37),
      Color(0xFFAA7C11),
      Color(0xFFF3E5AB),
      Color(0xFF8A6D1C),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.roomId == null) {
      _resolveRoomId();
    } else {
      _resolvedRoomId = widget.roomId;
    }
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant RoomSupportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roomId != oldWidget.roomId && widget.roomId != null) {
      setState(() => _resolvedRoomId = widget.roomId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cycleTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveRoomId() async {
    setState(() => _isResolving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isResolving = false);
        return;
      }
      final snap = await FirebaseFirestore.instance
          .collection('rooms')
          .where('ownerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        setState(() => _resolvedRoomId = snap.docs.first.id);
      }
    } catch (_) {}
    if (mounted) setState(() => _isResolving = false);
  }

  void _startTimer() {
    _updateCountdown();
    _cycleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now().toUtc();
    // Monday = 1, Tuesday = 2, ..., Sunday = 7
    final isMonOrTue = (now.weekday == DateTime.monday || now.weekday == DateTime.tuesday);

    if (isMonOrTue) {
      // Assignment window: ends Tuesday 23:59:59 UTC
      final daysUntilTueEnd = (now.weekday == DateTime.monday) ? 1 : 0;
      final deadline = DateTime.utc(now.year, now.month, now.day + daysUntilTueEnd, 23, 59, 59);
      final diff = deadline.difference(now);
      setState(() {
        _phaseText = "fill in countdown";
        _timeLeft = diff.isNegative ? Duration.zero : diff;
        _isAssignmentOpen = true;
      });
    } else {
      // Weekly accumulation window: ends Sunday 23:59:59 UTC
      final daysUntilSunEnd = (7 - now.weekday) % 7;
      final deadline = DateTime.utc(now.year, now.month, now.day + daysUntilSunEnd, 23, 59, 59);
      final diff = deadline.difference(now);
      setState(() {
        _phaseText = "this week countdown";
        _timeLeft = diff.isNegative ? Duration.zero : diff;
        _isAssignmentOpen = false;
      });
    }
  }

  List<Map<String, dynamic>> _configLevels() {
    final config = ref.watch(roomSupportConfigProvider).valueOrNull;
    final raw = (config?['levels'] as List<dynamic>?) ?? _defaultLevels();
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int _calculateLevel(int totalCoins, List<Map<String, dynamic>> levels) {
    int level = 0;
    for (final l in levels) {
      final lvl = (l['level'] as num?)?.toInt() ?? 0;
      final target = (l['coinsTarget'] as num?)?.toInt() ?? 0;
      if (totalCoins >= target && lvl > level) level = lvl;
    }
    return level;
  }

  int _getRequiredPartners(int level) {
    if (level >= 6) return 7;
    if (level == 5) return 6;
    if (level == 4) return 5;
    if (level >= 1) return 4;
    return 4; // Default minimum slots for visual grid
  }

  @override
  Widget build(BuildContext context) {
    final roomId = _resolvedRoomId;

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Luxury Top Header Bar
            _buildTopNavBar(roomId),
            
            // Body Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRoomSupportTab(roomId),
                  _buildRankingTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 1. TOP NAV BAR WITH LUXURY HIGHLIGHT ───────────────────────────────────
  Widget _buildTopNavBar(String? roomId) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: darkBg,
        border: Border(bottom: BorderSide(color: Color(0xFF221B0E), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 240,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: textGoldBright,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  labelColor: textGoldBright,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.normal),
                  tabs: const [
                    Tab(text: "Room Support"),
                    Tab(text: "Ranking"),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: textGoldSub, size: 22),
            onPressed: () => _showHistoryBottomSheet(roomId),
          ),
        ],
      ),
    );
  }

  // ─── 2. ROOM SUPPORT TAB CONTENT ───────────────────────────────────────────
  Widget _buildRoomSupportTab(String? roomId) {
    if (_isResolving) {
      return const Center(child: CircularProgressIndicator(color: textGoldBright));
    }

    if (roomId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_outlined, color: textGoldSub, size: 48),
            const Gap(12),
            Text(
              'No active room found',
              style: GoogleFonts.plusJakartaSans(color: textGoldSub, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final roomAsync = ref.watch(currentRoomStreamProvider(roomId));
    final room = roomAsync.valueOrNull;

    if (roomAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: textGoldBright));
    }

    if (roomAsync.hasError) {
      return Center(
        child: Text(
          'Failed to load room',
          style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontSize: 14),
        ),
      );
    }
    final isOwner = room != null && ref.watch(currentUserProfileProvider).value?.uid == room.ownerUid;

    final cycle = ref.watch(roomSupportCycleProvider(roomId)).valueOrNull ?? {};
    int totalCoins = (cycle['totalCoins'] as num?)?.toInt() ?? room?.weeklyEarnings ?? 0;
    // Ensure totalCoins is never negative
    totalCoins = totalCoins < 0 ? 0 : totalCoins;
    final currentLevel = _calculateLevel(totalCoins, _configLevels());
    int lastWeekLevel = (cycle['lastWeekLevel'] as num?)?.toInt() ?? 0;
    lastWeekLevel = lastWeekLevel < 0 ? 0 : lastWeekLevel;
    final activeLevelForPartners = _isAssignmentOpen ? (lastWeekLevel > 0 ? lastWeekLevel : currentLevel) : currentLevel;
    final requiredSlots = _getRequiredPartners(activeLevelForPartners);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          // Ultra-Premium Hero Banner with Top-to-Bottom Opacity Fade & Outside Title Badge
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _buildHeroBanner(),
              ),
              Positioned(
                bottom: -18,
                child: _buildTitleBadge(),
              ),
            ],
          ),
          
          const Gap(32),

          // 🌟 Room Support & Target Summary Header Card
          _buildTargetSummaryHeaderCard(totalCoins, currentLevel),

          const Gap(18),

          // Cycle Timer Bar
          if (_phaseText.isNotEmpty) _buildCountdownPhaseCard(),

          const Gap(18),

          // Salary Partners Assignment Grid Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildPartnerManagementCard(roomId, isOwner, activeLevelForPartners, requiredSlots),
          ),

          const Gap(18),

          // "My Room" Table Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildMyRoomCard(roomId, isOwner),
          ),

          const Gap(18),

          // "Target & Reward" Table Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildTargetAndRewardCard(),
          ),

          const Gap(24),

          // Rules Section (1 to 6)
          _buildRulesSection(),
        ],
      ),
    );
  }

  // ─── 3. ULTRA-PREMIUM HERO BANNER ──────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(16),
        ),
      ),
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.black,
              Colors.black87,
              Colors.black38,
              Colors.transparent,
            ],
            stops: [0.0, 0.35, 0.65, 0.88, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          'assets/images/room_support_hero.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.4),
                  radius: 0.95,
                  colors: [
                    Color(0xFF4A3710),
                    Color(0xFF1F1608),
                    darkBg,
                  ],
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 130,
                  child: CustomPaint(
                    painter: _HeroIllustrationPainter(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── 3D METALLIC GOLD TITLE BADGE ───────────────────────────────────────────
  Widget _buildTitleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
      decoration: BoxDecoration(
        gradient: metallicBadgeGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFF9E6), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 15, offset: const Offset(0, 6)),
          BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Room Support",
            style: GoogleFonts.cinzel(
              color: const Color(0xFF2A1D04),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              shadows: const [
                Shadow(color: Colors.white70, blurRadius: 1, offset: Offset(0, 1)),
              ],
            ),
          ),
          const Gap(8),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFB026FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0xFFD47AFF), blurRadius: 8, spreadRadius: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3B. TARGET SUMMARY HEADER CARD ──────────────────────────────────────────
  int _getWeeklyTargetCoins(int level, List<Map<String, dynamic>> levels) {
    if (levels.isEmpty) return 0;
    final idx = level.clamp(0, levels.length - 1);
    return (levels[idx]['coinsTarget'] as num?)?.toInt() ?? 0;
  }

  Widget _buildTargetSummaryHeaderCard(int totalCoins, int currentLevel) {
    final targetCoins = _getWeeklyTargetCoins(currentLevel, _configLevels());
    final progress = targetCoins > 0 ? (totalCoins / targetCoins).clamp(0.0, 1.0) : 0.0;
    final pctText = (progress * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGoldLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.12),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ROOM SUPPORT COUNT",
                    style: GoogleFonts.cinzel(
                      color: textGoldSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Gap(4),
                  Row(
                    children: [
                      Text(
                        _formatNum(totalCoins),
                        style: GoogleFonts.plusJakartaSans(
                          color: textGoldBright,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Gap(6),
                      Text(
                        "Coins",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: metallicBadgeGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6),
                  ],
                ),
                child: Text(
                  "Level $currentLevel",
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFF2A1D04),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Gap(14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Weekly Target: ${_formatNum(targetCoins)} Coins",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "$pctText%",
                style: GoogleFonts.plusJakartaSans(
                  color: textGoldBright,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Gap(8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFF221B0F),
              valueColor: const AlwaysStoppedAnimation<Color>(textGoldBright),
            ),
          ),
          const Gap(6),
          Text(
            "${_formatNum(totalCoins)} / ${_formatNum(targetCoins)} Coins",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. COUNTDOWN PHASE CARD ───────────────────────────────────────────────
  Widget _buildCountdownPhaseCard() {
    String timeText = "";
    if (_timeLeft.inDays > 0) {
      timeText = "${_timeLeft.inDays}Day ${_timeLeft.inHours.remainder(24).toString().padLeft(2, '0')}:${_timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0')}:${_timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    } else {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      timeText = "${twoDigits(_timeLeft.inHours)}:${twoDigits(_timeLeft.inMinutes.remainder(60))}:${twoDigits(_timeLeft.inSeconds.remainder(60))}";
    }

    final isFillIn = _isAssignmentOpen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGold, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              gradient: metallicBadgeGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFillIn ? Icons.edit_note_rounded : Icons.access_time_filled_rounded,
                  color: const Color(0xFF2A1D04),
                  size: 18,
                ),
                const Gap(8),
                Text(
                  isFillIn ? "fill in countdown $timeText" : "this week countdown $timeText",
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF2A1D04), fontSize: 13.5, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const Gap(10),
          Text(
            "Last week Room Partner can be fill in from every Monday 00:00 to Tuesday 24:00 (UTC+0), rewards will be sent every Wednesday",
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ─── 5. MY ROOM CARD ───────────────────────────────────────────────────────
  Widget _buildMyRoomCard(String? roomId, bool isOwner) {
    final cycle = roomId != null ? ref.watch(roomSupportCycleProvider(roomId)).valueOrNull ?? {} : {};
    final roomAsync = roomId != null ? ref.watch(currentRoomStreamProvider(roomId)) : null;
    final room = roomAsync?.valueOrNull;
    final historyAsync = roomId != null ? ref.watch(roomSupportHistoryProvider(roomId)) : null;
    final historyDocs = historyAsync?.valueOrNull ?? [];

    int totalCoins = (cycle['totalCoins'] as num?)?.toInt() ?? 0;
    if (totalCoins == 0 && room != null) {
      totalCoins = room.weeklyEarnings;
    }
    // Ensure totalCoins is never negative
    totalCoins = totalCoins < 0 ? 0 : totalCoins;

    int visitors = (cycle['visitorCount'] as num?)?.toInt() ?? 0;
    if (visitors == 0 && room != null) {
      visitors = room.currentUsersCount;
    }
    // Ensure visitors is never negative
    visitors = visitors < 0 ? 0 : visitors;

    int roomLevel = (cycle['level'] as num?)?.toInt() ?? _calculateLevel(totalCoins, _configLevels());

    int rewardCoins = (cycle['predictedRewardCoins'] as num?)?.toInt() ?? 0;
    if (rewardCoins == 0 && roomLevel > 0) {
      final levels = _defaultLevels();
      final targetLvl = levels.firstWhere((l) => l['level'] == roomLevel, orElse: () => levels.first);
      rewardCoins = (targetLvl['totalReward'] as num).toInt();
    }
    // Ensure rewardCoins is never negative
    rewardCoins = rewardCoins < 0 ? 0 : rewardCoins;

    final lastWeek = historyDocs.isNotEmpty ? historyDocs.first : {};
    int lastWeekCoins = (lastWeek['totalCoins'] as num?)?.toInt() ?? (cycle['lastWeekCoins'] as num?)?.toInt() ?? 0;
    lastWeekCoins = lastWeekCoins < 0 ? 0 : lastWeekCoins;
    int lastWeekReward = (lastWeek['totalReward'] as num?)?.toInt() ?? (cycle['lastWeekReward'] as num?)?.toInt() ?? 0;
    lastWeekReward = lastWeekReward < 0 ? 0 : lastWeekReward;
    int lastWeekVisitors = (lastWeek['visitorCount'] as num?)?.toInt() ?? 0;
    lastWeekVisitors = lastWeekVisitors < 0 ? 0 : lastWeekVisitors;
    final lastWeekLevel = (lastWeek['achievedLevel'] as num?)?.toInt() ?? (cycle['lastWeekLevel'] as num?)?.toInt() ?? _calculateLevel(lastWeekCoins, _configLevels());

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGold, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // Metallic Gold Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              gradient: goldHeaderGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: Text(
                "My Room",
                style: GoogleFonts.cinzel(
                  color: const Color(0xFF241804),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Data Grid
          Padding(
            padding: const EdgeInsets.all(10),
            child: Table(
              border: TableBorder.all(color: borderGold, width: 0.8),
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.0),
                2: FlexColumnWidth(1.1),
                3: FlexColumnWidth(1.1),
                4: FlexColumnWidth(1.1),
              },
              children: [
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFF221B0F)),
                  children: [
                    _buildCell("", isHeader: true),
                    _buildCell("Room Level", isHeader: true),
                    _buildCell("Reward Coins", isHeader: true),
                    _buildCell("Room Visitors", isHeader: true),
                    _buildCell("Room Coins", isHeader: true),
                  ],
                ),
                // This week
                TableRow(
                  decoration: const BoxDecoration(color: tableRowBgEven),
                  children: [
                    _buildCell("This week"),
                    _buildCell("$roomLevel", isGold: roomLevel > 0),
                    _buildCell(_formatNum(rewardCoins), isGold: rewardCoins > 0),
                    _buildCell(_formatNum(visitors)),
                    _buildCell(_formatNum(totalCoins)),
                  ],
                ),
                // Last week
                TableRow(
                  decoration: const BoxDecoration(color: tableRowBgOdd),
                  children: [
                    _buildCell("Last week"),
                    _buildCell("$lastWeekLevel", isGold: lastWeekLevel > 0),
                    _buildCell(_formatNum(lastWeekReward), isGold: lastWeekReward > 0),
                    _buildCell(_formatNum(lastWeekVisitors)),
                    _buildCell(_formatNum(lastWeekCoins)),
                  ],
                ),
              ],
            ),
          ),

          // Subtext
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "This week's rewards will be sent next Wednesday",
              style: GoogleFonts.plusJakartaSans(
                color: textGoldSub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 6. TARGET & REWARD CARD MATRIX (7 OFFICIAL LEVELS) ─────────────────────
  Widget _buildTargetAndRewardCard() {
    final configAsync = ref.watch(roomSupportConfigProvider);
    final config = configAsync.valueOrNull;
    final raw = (config?['levels'] as List<dynamic>?) ?? _defaultLevels();
    final levels = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGold, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // Metallic Gold Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              gradient: goldHeaderGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: Text(
                "Target & Reward",
                style: GoogleFonts.cinzel(
                  color: const Color(0xFF241804),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Grouped Matrix Table
          Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(color: borderGold, width: 0.8),
                columnWidths: const {
                  0: FixedColumnWidth(48),  // Level
                  1: FixedColumnWidth(96),  // Room Coins
                  2: FixedColumnWidth(74),  // Number of Partners
                  3: FixedColumnWidth(100), // Owner Coins
                  4: FixedColumnWidth(100), // Partner Coins
                  5: FixedColumnWidth(110), // Total Coins
                },
                children: [
                  // Dual Group Header
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF2A2010)),
                    children: [
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          alignment: Alignment.center,
                          child: Text("Target", style: GoogleFonts.cinzel(color: textGoldHeader, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox.shrink(),
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          alignment: Alignment.center,
                          child: Text("Reward", style: GoogleFonts.cinzel(color: textGoldHeader, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox.shrink(),
                      const SizedBox.shrink(),
                      const SizedBox.shrink(),
                    ],
                  ),
                  // Column Names
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF1E170B)),
                    children: [
                      _buildCell("Level", isHeader: true),
                      _buildCell("Room Coins", isHeader: true),
                      _buildCell("Number of Partners", isHeader: true),
                      _buildCell("Owner Coins", isHeader: true),
                      _buildCell("Partner Coins", isHeader: true),
                      _buildCell("Total Coins", isHeader: true),
                    ],
                  ),
                  // Rows Level 1 to 7
                  ...levels.map((lvl) {
                    final l = Map<String, dynamic>.from(lvl);
                    final levelNum = (l['level'] as num?)?.toInt() ?? 1;
                    final coinsTarget = (l['coinsTarget'] as num?)?.toInt() ?? 0;
                    final partnerSlots = (l['partnerSlots'] as num?)?.toInt() ?? 4;
                    final ownerReward = (l['ownerReward'] as num?)?.toInt() ?? 0;
                    final partnerReward = (l['partnerReward'] as num?)?.toInt() ?? 0;
                    final totalReward = (l['totalReward'] as num?)?.toInt() ?? (ownerReward + (partnerReward * partnerSlots));

                    final isEven = levelNum % 2 == 0;

                    return TableRow(
                      decoration: BoxDecoration(color: isEven ? tableRowBgEven : tableRowBgOdd),
                      children: [
                        _buildCell("$levelNum", isGold: true),
                        _buildCell("≥${_formatNum(coinsTarget)}"),
                        _buildCell("$partnerSlots"),
                        _buildCell(_formatNum(ownerReward)),
                        _buildCell(_formatNum(partnerReward)),
                        _buildCell(_formatNum(totalReward), isGold: true),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 7. SALARY PARTNER ASSIGNMENT CARD ──────────────────────────────────────
  Widget _buildPartnerManagementCard(String roomId, bool isOwner, int activeLevel, int requiredSlots) {
    final partnersAsync = ref.watch(roomSupportPartnersProvider(roomId));
    final partners = partnersAsync.valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGold, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: textGoldBright, size: 18),
              const Gap(8),
              Expanded(
                child: Text(
                  "SALARY PARTNERS ASSIGNMENT",
                  style: GoogleFonts.cinzel(color: textGoldBright, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: metallicBadgeGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${partners.length} / $requiredSlots Assigned",
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF221603), fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            "Assign Salary Partners during Monday & Tuesday window to distribute rewards on Wednesday.",
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11.5, height: 1.3),
          ),
          const Gap(16),

          // Partner Slots Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: requiredSlots,
            itemBuilder: (context, index) {
              if (index < partners.length) {
                final p = partners[index];
                final partnerUid = p['partnerUid']?.toString() ?? p['uid']?.toString() ?? p['id']?.toString() ?? '';
                if (partnerUid.isEmpty) return const SizedBox.shrink();
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(partnerUid).snapshots(),
                  builder: (context, snap) {
                    final rawUserData = snap.data?.data();
                    final u = rawUserData is Map ? Map<String, dynamic>.from(rawUserData) : <String, dynamic>{};
                    final name = u['displayName'] as String? ?? p['displayName'] as String? ?? 'Partner';
                    final photoUrl = u['profilePhotoUrl'] as String? ?? p['photoUrl'] as String? ?? '';

                    return GestureDetector(
                      onTap: () {
                        if (isOwner && _isAssignmentOpen) {
                          _showPartnerActionModal(roomId, partnerUid, name);
                        } else {
                          context.push(AppRoutes.userProfile, extra: partnerUid);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: textGoldBright, width: 1.5),
                                ),
                                child: AppAvatar(imageUrl: photoUrl, radius: 22, showFrame: false),
                              ),
                              if (isOwner && _isAssignmentOpen)
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                                ),
                            ],
                          ),
                          const Gap(4),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(color: textGoldHeader, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                );
              } else {
                return GestureDetector(
                  onTap: () => _handleSlotTap(roomId, isOwner, activeLevel, partners.length, requiredSlots),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: textGoldSub.withOpacity(0.5), width: 1.5),
                          color: Colors.black38,
                        ),
                        child: const Icon(Icons.add_rounded, color: textGoldBright, size: 22),
                      ),
                      const Gap(4),
                      Text(
                        "Add",
                        style: GoogleFonts.plusJakartaSans(color: textGoldSub, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }
            },
          ),

          const Gap(14),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _handleSlotTap(roomId, isOwner, activeLevel, partners.length, requiredSlots),
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF221603), size: 20),
              label: Text(
                "ASSIGN SALARY PARTNER",
                style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF221603)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: textGoldBright,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSlotTap(String roomId, bool isOwner, int activeLevel, int currentPartners, int requiredSlots) {
    if (!isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only the Room Owner can assign salary partners."),
          backgroundColor: borderGold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isAssignmentOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Partner assignment is only open Monday 00:00 to Tuesday 23:59 (UTC+0)."),
          backgroundColor: borderGold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (activeLevel < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Room must reach at least Level 1 (>= 10M coins) to assign salary partners."),
          backgroundColor: borderGold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (currentPartners >= requiredSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Maximum $requiredSlots salary partners already assigned."),
          backgroundColor: borderGold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _showPartnerPickerDialog(roomId);
  }

  void _showPartnerActionModal(String roomId, String partnerUid, String displayName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: textGoldBright.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
              const Gap(16),
              Text(displayName, style: GoogleFonts.cinzel(color: textGoldBright, fontSize: 18, fontWeight: FontWeight.bold)),
              const Gap(16),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: textGoldBright),
                title: const Text("View Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.userProfile, extra: partnerUid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                title: const Text("Remove Salary Partner", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  _confirmRemovePartner(roomId, partnerUid, displayName);
                },
              ),
              const Gap(10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemovePartner(String roomId, String partnerUid, String displayName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text("Remove Partner", style: GoogleFonts.cinzel(color: textGoldBright, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to remove $displayName as a salary partner?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Remove", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final service = ref.read(roomSupportServiceProvider);
        await service.removePartner(roomId, partnerUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$displayName removed from salary partners."),
              backgroundColor: borderGold,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: ${e.toString().replaceFirst('Exception: ', '')}"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ─── RULES SECTION (1 TO 6) ──────────────────────────────────────────────
  Widget _buildRulesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Rules:",
            style: GoogleFonts.cinzel(color: textGoldBright, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const Gap(12),
          _buildRuleItem(1, "Weekly Room Coins is counted from ", "Monday 00:00 to Sunday 23:59 (UTC+0)", ";"),
          _buildRuleItem(2, "Reaching the Room Level need to ", "Room Coins target", ";"),
          _buildRuleItem(3, "Room Owner need to fill in ", "Room Partner from Monday 00:00 to Tuesday 24:00 (UTC+0)", ", otherwise the reward will expire;"),
          _buildRuleItem(4, "Rewards will be sent ", "every Wednesday", ";"),
          _buildRuleItem(5, "Each user can only receive 1 reward per week, the reward will be sent according to the highest target reached by the user, whether it is Owner or Partner, for example: the user is both the Owner of his room and a Partner in other rooms, or Partner in multiple rooms at the same time, the reward with the most coins will be sent.", "", ""),
          _buildRuleItem(6, "Cheating and violations are prohibited. Once discovered, all rewards will be cancelled.", "", ""),
        ],
      ),
    );
  }

  Widget _buildRuleItem(int index, String textBefore, String goldText, String textAfter) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$index. ", style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12, height: 1.4),
                children: [
                  TextSpan(text: textBefore),
                  if (goldText.isNotEmpty)
                    TextSpan(text: goldText, style: const TextStyle(color: textGoldBright, fontWeight: FontWeight.bold)),
                  if (textAfter.isNotEmpty)
                    TextSpan(text: textAfter),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 8. RANKING TAB ───────────────────────────────────────────────────────
  Widget _buildRankingTab() {
    final rankingsAsync = ref.watch(roomSupportRankingsProvider);
    final rankings = rankingsAsync.valueOrNull ?? [];

    return rankings.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_outlined, color: textGoldSub.withOpacity(0.5), size: 48),
                const Gap(14),
                Text(
                  "No Weekly Ranking Data Yet",
                  style: GoogleFonts.cinzel(color: textGoldBright, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Gap(6),
                Text(
                  "Rankings update automatically as rooms accumulate weekly coins.",
                  style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              final rank = index + 1;
              final r = rankings[index];
              final totalCoins = (r['totalCoins'] as num?)?.toInt() ?? 0;
              final level = (r['level'] as num?)?.toInt() ?? _calculateLevel(totalCoins, _configLevels());
              final coverUrl = r['coverUrl'] as String? ?? '';
              final roomName = r['roomName']?.toString() ?? 'Room ${r['roomId'] ?? ''}';

              return GestureDetector(
                onTap: () {
                  final targetRoomId = r['roomId'] as String?;
                  if (targetRoomId != null) {
                    context.push('/room/$targetRoomId');
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: rank <= 3 ? borderGold.withOpacity(0.25) : cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: rank <= 3 ? textGoldBright : borderGold),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: rank <= 3
                            ? Icon(
                                Icons.emoji_events_rounded,
                                color: rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32),
                                size: 24,
                              )
                            : Text("#$rank", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const Gap(10),
                      AppAvatar(imageUrl: coverUrl, radius: 20, showFrame: false),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              roomName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const Gap(2),
                            Text(
                              "Level $level",
                              style: GoogleFonts.plusJakartaSans(color: textGoldSub, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "${_formatNum(totalCoins)} Coins",
                        style: GoogleFonts.plusJakartaSans(color: textGoldBright, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // ─── HELPER CELL WIDGET ───────────────────────────────────────────────────
  Widget _buildCell(String text, {bool isHeader = false, bool isGold = false}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: isHeader
                ? textGoldHeader
                : isGold
                    ? textGoldBright
                    : Colors.white70,
            fontSize: 10.5,
            fontWeight: isHeader || isGold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── HISTORY BOTTOM SHEET (CALENDAR ICON) ──────────────────────────────────
  void _showHistoryBottomSheet(String? roomId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            final historyAsync = roomId != null ? ref.watch(roomSupportHistoryProvider(roomId)) : null;
            final historyDocs = historyAsync?.valueOrNull ?? [];

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: textGoldBright.withOpacity(0.4), borderRadius: BorderRadius.circular(2)))),
                  const Gap(14),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: textGoldBright, size: 22),
                      const Gap(8),
                      Text("Weekly Distribution History", style: GoogleFonts.cinzel(color: textGoldBright, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Gap(6),
                  Text("Historical distributions are processed every Wednesday at 00:00 UTC.", style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12)),
                  const Gap(16),
                  Expanded(
                    child: historyDocs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_rounded, color: textGoldSub.withOpacity(0.4), size: 40),
                                const Gap(10),
                                Text("No previous cycle distributions recorded.", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: historyDocs.length,
                            separatorBuilder: (_, __) => const Gap(10),
                            itemBuilder: (context, i) {
                              final doc = historyDocs[i];
                              final totalCoins = (doc['totalCoins'] as num?)?.toInt() ?? 0;
                              final level = (doc['achievedLevel'] as num?)?.toInt() ?? 0;
                              final ownerReward = (doc['ownerReward'] as num?)?.toInt() ?? 0;
                              final partnerReward = (doc['partnerReward'] as num?)?.toInt() ?? 0;
                              final status = doc['distributionStatus'] as String? ?? 'pending';

                              Color statusColor = Colors.amber;
                              String statusLabel = 'Pending';
                              if (status == 'distributed') {
                                statusColor = Colors.greenAccent;
                                statusLabel = 'Distributed';
                              } else if (status == 'expired') {
                                statusColor = Colors.redAccent;
                                statusLabel = 'Expired';
                              } else if (status == 'no_target_met') {
                                statusColor = Colors.grey;
                                statusLabel = 'No Target';
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: darkBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderGold.withOpacity(0.6)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Level $level Achieved", style: GoogleFonts.cinzel(color: textGoldBright, fontWeight: FontWeight.bold, fontSize: 14)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: statusColor, width: 0.8),
                                          ),
                                          child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const Gap(6),
                                    Text("Room Coins: ${_formatNum(totalCoins)}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    const Gap(2),
                                    Text("Owner Reward: ${_formatNum(ownerReward)} 💎  |  Partner Reward: ${_formatNum(partnerReward)} 💎", style: const TextStyle(color: textGoldSub, fontSize: 11.5)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── PARTNER PICKER DIALOG ────────────────────────────────────────────────
  void _showPartnerPickerDialog(String roomId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: darkBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PartnerPicker(roomId: roomId),
    );
  }

  String _formatNum(num n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(0)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  List<Map<String, dynamic>> _defaultLevels() {
    final levels = SalaryLevel.allLevels.map((salaryLevel) {
      final target = salaryLevel.targetBeans;
      final ownerReward = salaryLevel.hostShare.toInt();
      final partnerReward = salaryLevel.agencyShare.toInt();
      final totalReward = (salaryLevel.hostShare + salaryLevel.agencyShare).toInt();
      return {
        'level': salaryLevel.level,
        'coinsTarget': target,
        'partnerSlots': 4,
        'ownerReward': ownerReward,
        'partnerReward': partnerReward,
        'totalReward': totalReward,
      };
    }).toList(growable: false);
    return levels.take(7).toList();
  }
}

// ─── HERO ILLUSTRATION CUSTOM PAINTER ───────────────────────────────────────
class _HeroIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = const Color(0xFF2A1F0B)
      ..style = PaintingStyle.fill;

    // Pedestal
    final centerRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 20),
      width: 100,
      height: 30,
    );
    canvas.drawRect(centerRect, fillPaint);
    canvas.drawRect(centerRect, paint);

    // Left Silhouette
    final leftPath = Path()
      ..moveTo(size.width / 2 - 110, size.height - 10)
      ..lineTo(size.width / 2 - 80, size.height - 70)
      ..lineTo(size.width / 2 - 50, size.height - 10)
      ..close();
    canvas.drawPath(leftPath, fillPaint);
    canvas.drawPath(leftPath, paint);

    // Right Silhouette
    final rightPath = Path()
      ..moveTo(size.width / 2 + 50, size.height - 10)
      ..lineTo(size.width / 2 + 80, size.height - 70)
      ..lineTo(size.width / 2 + 110, size.height - 10)
      ..close();
    canvas.drawPath(rightPath, fillPaint);
    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── PARTNER PICKER WIDGET ──────────────────────────────────────────────────
// ─── PARTNER PICKER WIDGET (Image 6 & Image 7 Flow) ─────────────────────────
class _PartnerPicker extends StatefulWidget {
  final String roomId;
  const _PartnerPicker({required this.roomId});

  @override
  State<_PartnerPicker> createState() => _PartnerPickerState();
}

class _PartnerPickerState extends State<_PartnerPicker> {
  final _searchController = TextEditingController();
  final _db = FirebaseFirestore.instance;
  bool _isSearching = false;
  List<DocumentSnapshot> _searchResults = [];
  bool _dontRemindAgain = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final List<DocumentSnapshot> results = [];
      final parsedInt = int.tryParse(query);

      // 1. Direct UID lookup
      try {
        final uidDoc = await _db.collection('users').doc(query).get();
        if (uidDoc.exists) {
          results.add(uidDoc);
        }
      } catch (_) {}

      // 2. Query by helloId (integer)
      if (parsedInt != null) {
        try {
          final helloSnap = await _db
              .collection('users')
              .where('helloId', isEqualTo: parsedInt)
              .limit(10)
              .get();
          results.addAll(helloSnap.docs);
        } catch (_) {}
      }

      // 3. Query by helloId (string) / displayId / username
      if (results.isEmpty) {
        try {
          final stringHelloSnap = await _db
              .collection('users')
              .where('helloId', isEqualTo: query)
              .limit(10)
              .get();
          results.addAll(stringHelloSnap.docs);
        } catch (_) {}
      }

      if (results.isEmpty) {
        try {
          final displaySnap = await _db
              .collection('users')
              .where('displayId', isEqualTo: query)
              .limit(10)
              .get();
          results.addAll(displaySnap.docs);
        } catch (_) {}
      }

      if (results.isEmpty) {
        try {
          final usernameSnap = await _db
              .collection('users')
              .where('username', isEqualTo: query)
              .limit(10)
              .get();
          results.addAll(usernameSnap.docs);
        } catch (_) {}
      }

      // 4. Query by displayName prefix
      if (results.isEmpty) {
        try {
          final nameSnap = await _db
              .collection('users')
              .where('displayName', isGreaterThanOrEqualTo: query)
              .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
              .limit(15)
              .get();
          results.addAll(nameSnap.docs);
        } catch (_) {}
      }

      // Deduplicate by ID
      final seenIds = <String>{};
      final uniqueResults = results.where((doc) => seenIds.add(doc.id)).toList();

      if (mounted) {
        setState(() {
          _searchResults = uniqueResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Gap(12),
          // Top Bar with Back Arrow and Title (Image 6)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              const Gap(4),
              Text(
                'Add Room Partner',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Gap(14),
          // Search Input Capsule with clear (x) and Search button (Image 6)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF334155), width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onSubmitted: (_) => _performSearch(),
                    onChanged: (val) {
                      setState(() {});
                      if (val.trim().isNotEmpty) {
                        _performSearch();
                      } else {
                        setState(() => _searchResults = []);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search user ID or name...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 19),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 17),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const Gap(10),
              GestureDetector(
                onTap: _performSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    'Search',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),
          // Results Section (Image 6)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : _searchResults.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            _searchController.text.trim().isEmpty
                                ? 'Enter an ID or name to search'
                                : 'No users found',
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final rawData = _searchResults[i].data();
                          final data = rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{};
                          final uid = _searchResults[i].id;
                          final displayName = data['displayName'] as String? ?? 'User';
                          final helloId = data['helloId']?.toString() ?? data['displayId']?.toString() ?? uid;
                          final photoUrl = data['profilePhotoUrl'] as String? ?? '';
                          final myUid = FirebaseAuth.instance.currentUser?.uid;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Row(
                              children: [
                                AppAvatar(
                                  imageUrl: photoUrl,
                                  radius: 22,
                                  frameUrl: data['profileFrame'] as String?,
                                  showFrame: false,
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Gap(2),
                                      Text(
                                        'ID:$helloId',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (uid == myUid)
                                  const Text('You', style: TextStyle(color: Colors.white38))
                                else
                                  GestureDetector(
                                    onTap: () => _confirmAddPartner(uid, displayName),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF08A),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        'Add',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const Gap(16),
        ],
      ),
    );
  }

  // ─── CONFIRMATION DIALOG (Image 7) ─────────────────────────────────────────
  void _confirmAddPartner(String partnerUid, String displayName) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Gap(8),
                    Text(
                      'Whether to add $displayName as your Room Partner, modification is not allowed after adding',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const Gap(22),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(dialogCtx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              _assignPartner(partnerUid, displayName);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF86EFAC), Color(0xFF2DD4BF)],
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x442DD4BF), blurRadius: 8),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Confirm',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    GestureDetector(
                      onTap: () {
                        setDialogState(() => _dontRemindAgain = !_dontRemindAgain);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _dontRemindAgain ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: _dontRemindAgain ? const Color(0xFF2DD4BF) : Colors.white38,
                            size: 16,
                          ),
                          const Gap(6),
                          Text(
                            "Don't remind again",
                            style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _assignPartner(String partnerUid, String displayName) async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final service = container.read(roomSupportServiceProvider);
      await service.assignPartner(widget.roomId, partnerUid);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName added as salary partner!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
