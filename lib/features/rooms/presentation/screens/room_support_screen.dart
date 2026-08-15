import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/room_support_provider.dart';
import '../../../../core/models/room_model.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/widgets/app_avatar.dart';
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
    _cycleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final roomId = _resolvedRoomId;
        if (roomId != null) {
          final cycle = ref.read(roomSupportCycleProvider(roomId)).valueOrNull;
          _updateCountdown(cycle);
        } else {
          _updateCountdown(null);
        }
      }
    });
  }

  void _updateCountdown(Map<String, dynamic>? cycle) {
    final now = DateTime.now().toUtc();
    DateTime lockAt;
    if (cycle != null && cycle['lockAt'] != null) {
      lockAt = (cycle['lockAt'] as Timestamp).toDate().toUtc();
    } else {
      final daysUntilSunday = (7 - now.weekday) % 7;
      final nextSunday = now.add(Duration(days: daysUntilSunday));
      lockAt = DateTime.utc(nextSunday.year, nextSunday.month, nextSunday.day, 23, 59, 59);
    }

    DateTime distributeAt;
    if (cycle != null && cycle['distributeAt'] != null) {
      distributeAt = (cycle['distributeAt'] as Timestamp).toDate().toUtc();
    } else {
      distributeAt = lockAt.add(const Duration(days: 2, seconds: 1));
    }

    DateTime nextCycleAt;
    final daysUntilMonday = (8 - now.weekday) % 7;
    final nextMonday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    nextCycleAt = DateTime.utc(nextMonday.year, nextMonday.month, nextMonday.day, 0, 0, 0);

    setState(() {
      if (now.isBefore(lockAt)) {
        _phaseText = "Cycle Locks in";
        _timeLeft = lockAt.difference(now);
      } else if (now.isBefore(distributeAt)) {
        _phaseText = "Distributing in";
        _timeLeft = distributeAt.difference(now);
      } else {
        _phaseText = "New Cycle starts in";
        _timeLeft = nextCycleAt.difference(now);
      }
    });
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
            _buildTopNavBar(),
            
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
  Widget _buildTopNavBar() {
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
            onPressed: () => _showHistoryBottomSheet(),
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

    final roomAsync = roomId != null ? ref.watch(currentRoomStreamProvider(roomId)) : const AsyncLoading<RoomModel?>();
    final room = roomAsync.valueOrNull;
    final isOwner = room != null && ref.watch(currentUserProfileProvider).value?.uid == room.ownerUid;

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

          // Cycle Timer Bar
          if (_phaseText.isNotEmpty) _buildCountdownPhaseCard(),

          const Gap(18),

          // Partner Assignment Grid Card (+ Add slots)
          if (roomId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _buildPartnerGridCard(roomId, isOwner),
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

          // Rules Section
          _buildRulesSection(),
        ],
      ),
    );
  }

  // ─── 3. ULTRA-PREMIUM HERO BANNER (TOP-TO-BOTTOM OPACITY FADE) ─────────────
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: const BorderRadius.vertical(
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

  // ─── 3D METALLIC GOLD TITLE BADGE (OUTSIDE IMAGE) ──────────────────────────
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
              shadows: [
                const Shadow(color: Colors.white70, blurRadius: 1, offset: Offset(0, 1)),
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

  Widget _buildSparkle(double size) {
    return Icon(Icons.star_rounded, color: textGoldBright.withOpacity(0.4), size: size);
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

    final isFillIn = _phaseText.toLowerCase().contains("distribute") || _phaseText.toLowerCase().contains("fill");

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
                Icon(isFillIn ? Icons.edit_note_rounded : Icons.access_time_filled_rounded, color: const Color(0xFF2A1D04), size: 18),
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

    int visitors = (cycle['visitorCount'] as num?)?.toInt() ?? 0;
    if (visitors == 0 && room != null) {
      visitors = room.currentUsersCount;
    }

    int roomLevel = cycle['level'] ?? 0;
    if (roomLevel == 0 && totalCoins > 0) {
      final levels = _full20Levels();
      for (final lvl in levels) {
        if (totalCoins >= (lvl['coinsTarget'] as num).toInt()) {
          roomLevel = lvl['level'] as int;
          break;
        }
      }
    }

    int rewardCoins = (cycle['predictedRewardCoins'] as num?)?.toInt() ?? 0;
    if (rewardCoins == 0 && roomLevel > 0) {
      final levels = _full20Levels();
      final targetLvl = levels.firstWhere((l) => l['level'] == roomLevel, orElse: () => levels.last);
      rewardCoins = (targetLvl['totalReward'] as num).toInt();
    }

    final lastWeek = historyDocs.isNotEmpty ? historyDocs.first : {};
    final lastWeekCoins = (lastWeek['totalCoins'] as num?)?.toInt() ?? 0;
    final lastWeekReward = (lastWeek['rewardCoins'] as num?)?.toInt() ?? 0;
    final lastWeekVisitors = (lastWeek['visitorCount'] as num?)?.toInt() ?? 0;
    final lastWeekLevel = (lastWeek['level'] as num?)?.toInt() ?? 0;

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
                    _buildCell("$roomLevel"),
                    _buildCell(_formatNum(rewardCoins)),
                    _buildCell(_formatNum(visitors)),
                    _buildCell(_formatNum(totalCoins)),
                  ],
                ),
                // Last week
                TableRow(
                  decoration: const BoxDecoration(color: tableRowBgOdd),
                  children: [
                    _buildCell("Last week"),
                    _buildCell("$lastWeekLevel"),
                    _buildCell(_formatNum(lastWeekReward)),
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

  // ─── 6. TARGET & REWARD CARD MATRIX ───────────────────────────────────────
  Widget _buildTargetAndRewardCard() {
    final configAsync = ref.watch(roomSupportConfigProvider);
    final config = configAsync.valueOrNull;
    final levels = (config?['levels'] as List<dynamic>?) ?? _full20Levels();

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
                  2: FixedColumnWidth(68),  // Number of Partners
                  3: FixedColumnWidth(105), // Owner Coins
                  4: FixedColumnWidth(100), // Partner Coins
                  5: FixedColumnWidth(115), // Total Coins
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
                  // Rows Level 31 down to 1
                  ...levels.map((lvl) {
                    final l = lvl as Map<String, dynamic>;
                    final levelNum = l['level'] ?? 1;
                    final coinsTarget = (l['coinsTarget'] as num?)?.toInt() ?? 0;
                    final partnerSlots = l['partnerSlots'] ?? 4;
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

  // ─── 7. PARTNER MANAGEMENT CARD ───────────────────────────────────────────
  Widget _buildPartnerManagementCard(String roomId) {
    final partnersAsync = ref.watch(roomSupportPartnersProvider(roomId));
    final partners = partnersAsync.valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGold, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: textGoldBright, size: 18),
              const Gap(8),
              Text(
                "Salary Partners Assignment",
                style: GoogleFonts.cinzel(color: textGoldBright, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: borderGold.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${partners.length} Assigned",
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Gap(10),
          Text(
            "Assign Salary Partners during Monday & Tuesday window to distribute rewards on Wednesday.",
            style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 11),
          ),
          const Gap(14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _showPartnerPickerDialog(roomId),
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF221603)),
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

  // ─── PARTNER AVATAR SLOT GRID CARD (+ ADD SLOTS) ──────────────────────────
  Widget _buildPartnerGridCard(String roomId, bool isOwner) {
    final partnersAsync = ref.watch(roomSupportPartnersProvider(roomId));
    final partners = partnersAsync.valueOrNull ?? [];
    const maxSlots = 10; // 3x4 grid matching Photo 3 reference

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGold, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: maxSlots,
            itemBuilder: (context, index) {
              if (index < partners.length) {
                final p = partners[index];
                final partnerUid = p['partnerUid'] as String? ?? p['id'] as String;
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(partnerUid).snapshots(),
                  builder: (context, snap) {
                    final u = snap.data?.data() as Map<String, dynamic>? ?? {};
                    final name = u['displayName'] as String? ?? p['displayName'] as String? ?? 'Partner';
                    final photoUrl = u['profilePhotoUrl'] as String? ?? p['photoUrl'] as String? ?? '';

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAvatar(imageUrl: photoUrl, radius: 24, showFrame: false),
                        const Gap(4),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(color: textGoldHeader, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                );
              } else {
                return GestureDetector(
                  onTap: isOwner ? () => _showPartnerPickerDialog(roomId) : null,
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
        ],
      ),
    );
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
                  "Rankings updates automatically as rooms accumulate weekly coins.",
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
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: rank <= 3 ? borderGold.withOpacity(0.25) : cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: rank <= 3 ? textGoldBright : borderGold),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: rank <= 3
                          ? Icon(
                              Icons.emoji_events_rounded,
                              color: rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32),
                              size: 22,
                            )
                          : Text("#$rank", style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontWeight: FontWeight.bold)),
                    ),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        r['roomName'] ?? 'Room ${r['roomId']}',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Text(
                      "${_formatNum((r['totalCoins'] as num?)?.toInt() ?? 0)} Coins",
                      style: GoogleFonts.plusJakartaSans(color: textGoldBright, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ],
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

  // ─── HISTORY BOTTOM SHEET ─────────────────────────────────────────────────
  void _showHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Weekly Distribution History", style: GoogleFonts.cinzel(color: textGoldBright, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(10),
            Text("Historical distributions are processed every Wednesday at 00:00 UTC.", style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12)),
            const Gap(20),
            Center(
              child: Text("No previous cycle distributions recorded.", style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13)),
            ),
            const Gap(20),
          ],
        ),
      ),
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

  // 20-tier dataset matching client specification
  List<Map<String, dynamic>> _full20Levels() {
    return [
      {'level': 1, 'coinsTarget': 100000, 'partnerSlots': 4, 'ownerReward': 11250, 'partnerReward': 1875, 'totalReward': 15000},
      {'level': 2, 'coinsTarget': 300000, 'partnerSlots': 4, 'ownerReward': 32850, 'partnerReward': 4050, 'totalReward': 45000},
      {'level': 3, 'coinsTarget': 500000, 'partnerSlots': 4, 'ownerReward': 49700, 'partnerReward': 5075, 'totalReward': 70000},
      {'level': 4, 'coinsTarget': 1000000, 'partnerSlots': 5, 'ownerReward': 96600, 'partnerReward': 8680, 'totalReward': 140000},
      {'level': 5, 'coinsTarget': 2000000, 'partnerSlots': 5, 'ownerReward': 200000, 'partnerReward': 18000, 'totalReward': 290000},
      {'level': 6, 'coinsTarget': 3500000, 'partnerSlots': 6, 'ownerReward': 360000, 'partnerReward': 30000, 'totalReward': 540000},
      {'level': 7, 'coinsTarget': 5000000, 'partnerSlots': 6, 'ownerReward': 525000, 'partnerReward': 45000, 'totalReward': 795000},
      {'level': 8, 'coinsTarget': 8000000, 'partnerSlots': 7, 'ownerReward': 840000, 'partnerReward': 70000, 'totalReward': 1330000},
      {'level': 9, 'coinsTarget': 12000000, 'partnerSlots': 7, 'ownerReward': 1280000, 'partnerReward': 100000, 'totalReward': 1980000},
      {'level': 10, 'coinsTarget': 18000000, 'partnerSlots': 8, 'ownerReward': 1950000, 'partnerReward': 150000, 'totalReward': 3150000},
      {'level': 11, 'coinsTarget': 25000000, 'partnerSlots': 8, 'ownerReward': 2750000, 'partnerReward': 200000, 'totalReward': 4350000},
      {'level': 12, 'coinsTarget': 35000000, 'partnerSlots': 9, 'ownerReward': 3900000, 'partnerReward': 280000, 'totalReward': 6420000},
      {'level': 13, 'coinsTarget': 50000000, 'partnerSlots': 9, 'ownerReward': 5600000, 'partnerReward': 400000, 'totalReward': 9200000},
      {'level': 14, 'coinsTarget': 75000000, 'partnerSlots': 10, 'ownerReward': 8500000, 'partnerReward': 600000, 'totalReward': 14500000},
      {'level': 15, 'coinsTarget': 100000000, 'partnerSlots': 10, 'ownerReward': 11500000, 'partnerReward': 850000, 'totalReward': 20000000},
      {'level': 16, 'coinsTarget': 150000000, 'partnerSlots': 11, 'ownerReward': 17500000, 'partnerReward': 1250000, 'totalReward': 31250000},
      {'level': 17, 'coinsTarget': 200000000, 'partnerSlots': 11, 'ownerReward': 23500000, 'partnerReward': 1700000, 'totalReward': 42200000},
      {'level': 18, 'coinsTarget': 300000000, 'partnerSlots': 12, 'ownerReward': 35500000, 'partnerReward': 2500000, 'totalReward': 65500000},
      {'level': 19, 'coinsTarget': 450000000, 'partnerSlots': 12, 'ownerReward': 54000000, 'partnerReward': 3800000, 'totalReward': 99600000},
      {'level': 20, 'coinsTarget': 600000000, 'partnerSlots': 12, 'ownerReward': 72000000, 'partnerReward': 5000000, 'totalReward': 132000000},
    ];
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

    // Draw central pedestal for trophy
    final centerRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 20),
      width: 100,
      height: 30,
    );
    canvas.drawRect(centerRect, fillPaint);
    canvas.drawRect(centerRect, paint);

    // Draw Left Lion Silhouette / Shield
    final leftPath = Path()
      ..moveTo(size.width / 2 - 110, size.height - 10)
      ..lineTo(size.width / 2 - 80, size.height - 70)
      ..lineTo(size.width / 2 - 50, size.height - 10)
      ..close();
    canvas.drawPath(leftPath, fillPaint);
    canvas.drawPath(leftPath, paint);

    // Draw Right Lion Silhouette / Shield
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
class _PartnerPicker extends StatefulWidget {
  final String roomId;
  const _PartnerPicker({required this.roomId});

  @override
  State<_PartnerPicker> createState() => _PartnerPickerState();
}

class _PartnerPickerState extends State<_PartnerPicker> {
  final _searchController = TextEditingController();
  final _db = FirebaseFirestore.instance;

  static const Color textGoldBright = Color(0xFFFFE58F);
  static const Color borderGold = Color(0xFF4A3A16);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: textGoldBright.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
          const Gap(14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: textGoldBright, size: 20),
              const Gap(8),
              Text('Select a Salary Partner', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Gap(14),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search partner display name...',
              hintStyle: TextStyle(color: textGoldBright.withOpacity(0.3)),
              prefixIcon: Icon(Icons.search, color: textGoldBright.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF19140B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderGold)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderGold.withOpacity(0.5))),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => setState(() {}),
          ),
          const Gap(12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _searchController.text.trim().length < 2
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Type at least 2 characters', style: GoogleFonts.plusJakartaSans(color: textGoldBright.withOpacity(0.4), fontSize: 13)),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('users')
                        .where('displayName_lowercase', isGreaterThanOrEqualTo: _searchController.text.trim().toLowerCase())
                        .where('displayName_lowercase', isLessThanOrEqualTo: '${_searchController.text.trim().toLowerCase()}\uf8ff')
                        .limit(15)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: textGoldBright));
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('No users found', style: GoogleFonts.plusJakartaSans(color: textGoldBright.withOpacity(0.4), fontSize: 13)),
                        );
                      }
                      final myUid = FirebaseAuth.instance.currentUser?.uid;
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => Divider(color: borderGold.withOpacity(0.2), height: 1),
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final uid = docs[i].id;
                          final isMe = uid == myUid;
                          return ListTile(
                            dense: true,
                            leading: AppAvatar(
                              imageUrl: data['profilePhotoUrl'] as String? ?? '',
                              radius: 18,
                              frameUrl: data['profileFrame'] as String?,
                              vipTier: data['vipTier'] as String?,
                              tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
                              userLevel: data['level'] as int? ?? 1,
                            ),
                            title: Text(
                              data['displayName'] as String? ?? 'Unknown',
                              style: TextStyle(color: isMe ? textGoldBright : Colors.white, fontWeight: FontWeight.bold),
                            ),
                            trailing: isMe
                                ? const Text('You', style: TextStyle(color: Colors.white38))
                                : IconButton(
                                    icon: const Icon(Icons.person_add_rounded, color: textGoldBright),
                                    onPressed: () => _assignPartner(uid, data['displayName'] as String? ?? uid),
                                  ),
                          );
                        },
                      );
                    },
                  ),
          ),
          const Gap(16),
        ],
      ),
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
            backgroundColor: borderGold,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
