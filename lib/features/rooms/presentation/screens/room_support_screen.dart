import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class _RoomSupportScreenState extends ConsumerState<RoomSupportScreen> {
  Timer? _cycleTimer;
  Duration _timeLeft = Duration.zero;
  String _phaseText = "";
  String? _resolvedRoomId;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
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

  String get _effectiveRoomId => _resolvedRoomId ?? '';

  @override
  Widget build(BuildContext context) {
    final roomId = _resolvedRoomId;
    final roomAsync = roomId != null ? ref.watch(currentRoomStreamProvider(roomId)) : const AsyncLoading<RoomModel?>();
    final room = roomAsync.valueOrNull;
    final isOwner = room != null && ref.watch(currentUserProfileProvider).value?.uid == room.ownerUid;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, color: const Color(0xFFFFD700), size: 20),
            const Gap(8),
            const Text('Room Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: _isResolving
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)))
          : roomId == null
              ? _buildEmptyState()
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildGoldHeaderBanner(),
                          const Gap(16),
                          _buildCountdownBanner(),
                          const Gap(16),
                          _buildMyRoomSection(roomId, isOwner),
                          const Gap(16),
                          _buildWeeklyProgressSection(roomId),
                          const Gap(16),
                          _buildPartnerSlotsSection(roomId, isOwner),
                          const Gap(16),
                          _buildTargetTableSection(),
                          const Gap(16),
                          _buildRankingSection(),
                          const Gap(16),
                          _buildRewardDistributionSection(roomId),
                          const Gap(16),
                          _buildHistorySection(roomId),
                          const Gap(32),
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD700).withOpacity(0.08),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
            ),
            child: const Icon(Icons.meeting_room_outlined, color: Color(0xFFFFD700), size: 48),
          ),
          const Gap(20),
          const Text(
            'Join a room to view\nRoom Support',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
          const Gap(8),
          Text(
            'Room owners can manage salary partners\nand track weekly targets here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── Gold theme helpers ─────────────────────────────────
  static const Color _gold = Color(0xFFFFD700);
  static const Color _darkGold = Color(0xFFB8860B);
  static const Color _bgCard = Color(0xFF151515);
  static const Color _borderGold = Color(0xFF8C6E30);

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _borderGold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: _gold, size: 14),
          const Gap(8),
          Text(title, style: const TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildGoldCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGold.withOpacity(0.15)),
      ),
      child: child,
    );
  }

  Widget _buildGoldHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _borderGold.withOpacity(0.15),
            _bgCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderGold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_gold, Color(0xFFD4A017)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 12, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 32),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROOM SUPPORT',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: _gold.withOpacity(0.3), blurRadius: 8)],
                  ),
                ),
                const Gap(4),
                Text(
                  'Manage rewards, partners & targets',
                  style: TextStyle(color: _gold.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Countdown Banner ───────────────────────────────────
  Widget _buildCountdownBanner() {
    if (_phaseText.isEmpty) return const SizedBox.shrink();

    String timeText = "";
    if (_timeLeft.inDays > 0) {
      timeText = "${_timeLeft.inDays}d ${_timeLeft.inHours.remainder(24)}h ${_timeLeft.inMinutes.remainder(60)}m ${_timeLeft.inSeconds.remainder(60)}s";
    } else {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      timeText = "${twoDigits(_timeLeft.inHours)}h ${twoDigits(_timeLeft.inMinutes.remainder(60))}m ${twoDigits(_timeLeft.inSeconds.remainder(60))}s";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_bottom_rounded, color: _gold, size: 20),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _phaseText.toUpperCase(),
                  style: TextStyle(color: _gold.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
                const Gap(4),
                Text(
                  timeText,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── My Room Section ────────────────────────────────────
  Widget _buildMyRoomSection(String roomId, bool isOwner) {
    final cycleAsync = ref.watch(roomSupportCycleProvider(roomId));
    final cycle = cycleAsync.valueOrNull ?? {};
    final totalCoins = (cycle['totalCoins'] as num?)?.toInt() ?? 0;
    final roomLevel = cycle['level'] ?? 1;

    return _buildGoldCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('My Room'),
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                _buildTableRow('Room Level', 'Level $roomLevel', Icons.trending_up),
                Divider(color: _borderGold.withOpacity(0.15), height: 1),
                _buildTableRow('Weekly Room Coins', '${_formatNum(totalCoins)} 🪙', Icons.monetization_on_outlined),
                Divider(color: _borderGold.withOpacity(0.15), height: 1),
                _buildTableRow('Status', cycle['status'] == 'accumulating' ? '🟢 Accumulating' : '🔴 Closed', Icons.circle_outlined),
              ],
            ),
          ),
          if (isOwner) ...[
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  _buildTableRow('Owner Reward', '—', Icons.diamond_outlined),
                  if (cycle['weekStart'] != null) ...[
                    Divider(color: _borderGold.withOpacity(0.15), height: 1),
                    _buildTableRow('Cycle Start', _formatTimestamp(cycle['weekStart']), Icons.calendar_today),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: _gold.withOpacity(0.5), size: 16),
          const Gap(10),
          Text(label, style: TextStyle(color: _gold.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ─── Weekly Progress ────────────────────────────────────
  Widget _buildWeeklyProgressSection(String roomId) {
    final cycleAsync = ref.watch(roomSupportCycleProvider(roomId));
    final configAsync = ref.watch(roomSupportConfigProvider);
    final cycle = cycleAsync.valueOrNull ?? {};
    final config = configAsync.valueOrNull;
    final levels = (config?['levels'] as List<dynamic>?) ?? [];

    final totalCoins = (cycle['totalCoins'] as num?)?.toInt() ?? 0;
    final currentLevel = (cycle['level'] as num?)?.toInt() ?? 1;

    int nextTarget = 0;
    int currentTarget = 0;
    for (final lvl in levels) {
      final l = lvl as Map<String, dynamic>;
      final lvlNum = (l['level'] as num?)?.toInt() ?? 0;
      final target = (l['coinsTarget'] as num?)?.toInt() ?? 0;
      if (lvlNum == currentLevel) currentTarget = target;
      if (lvlNum == currentLevel + 1) nextTarget = target;
    }
    if (nextTarget == 0) nextTarget = currentTarget;

    final progress = currentTarget > 0 ? (totalCoins / currentTarget).clamp(0.0, 1.0) : 0.0;
    final remaining = (currentTarget - totalCoins).clamp(0, currentTarget);

    return _buildGoldCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Weekly Progress'),
          const Gap(16),
          Row(
            children: [
              Text('Level $currentLevel', style: const TextStyle(color: _gold, fontSize: 28, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('${(progress * 100).toInt()}%', style: TextStyle(color: _gold.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const Gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _borderGold.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(_gold),
              minHeight: 10,
            ),
          ),
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                _buildTableRow('Current', '${_formatNum(totalCoins)} 🪙', Icons.wallet),
                Divider(color: _borderGold.withOpacity(0.15), height: 1),
                _buildTableRow('Target', '${_formatNum(currentTarget)} 🪙', Icons.flag_outlined),
                if (remaining > 0) ...[
                  Divider(color: _borderGold.withOpacity(0.15), height: 1),
                  _buildTableRow('Remaining', '${_formatNum(remaining)} 🪙', Icons.trending_up),
                ],
                if (nextTarget > currentTarget) ...[
                  Divider(color: _borderGold.withOpacity(0.15), height: 1),
                  _buildTableRow('Next Level Target', '${_formatNum(nextTarget)} 🪙', Icons.auto_awesome),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Partner Slots ──────────────────────────────────────
  Widget _buildPartnerSlotsSection(String roomId, bool isOwner) {
    final cycleAsync = ref.watch(roomSupportCycleProvider(roomId));
    final configAsync = ref.watch(roomSupportConfigProvider);
    final partnersAsync = ref.watch(roomSupportPartnersProvider(roomId));
    final cycle = cycleAsync.valueOrNull ?? {};
    final config = configAsync.valueOrNull;
    final levels = (config?['levels'] as List<dynamic>?) ?? [];
    final partners = partnersAsync.valueOrNull ?? [];

    final currentLevel = (cycle['level'] as num?)?.toInt() ?? 1;
    final levelConfig = levels.where((l) => (l as Map)['level'] == currentLevel).firstOrNull as Map<String, dynamic>?;
    final maxSlots = (levelConfig?['partnerSlots'] as num?)?.toInt() ?? 4;
    final occupiedSlots = partners.length;
    final remainingSlots = (maxSlots - occupiedSlots).clamp(0, maxSlots);

    return _buildGoldCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Partner Slots'),
          const Gap(16),
          Row(
            children: [
              _buildSlotBadge('Available', maxSlots, _gold),
              const Gap(8),
              _buildSlotBadge('Occupied', occupiedSlots, const Color(0xFFD4A017)),
              const Gap(8),
              _buildSlotBadge('Remaining', remainingSlots, occupiedSlots >= maxSlots ? Colors.redAccent : Colors.greenAccent),
            ],
          ),
          const Gap(16),
          if (partners.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderGold.withOpacity(0.1)),
              ),
              child: const Text('No partners assigned yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            ...partners.map((p) => _buildPartnerRow(p, roomId, isOwner)),
          if (isOwner && remainingSlots > 0) ...[
            const Gap(12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showPartnerPickerDialog(roomId),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add Partner'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: const BorderSide(color: _gold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerRow(Map<String, dynamic> partner, String roomId, bool isOwner) {
    final uid = partner['id'] as String? ?? '';
    return Consumer(
      builder: (context, ref, child) {
        final userAsync = ref.watch(userProfileProvider(uid));
        return userAsync.when(
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderGold.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  AppAvatar(imageUrl: user.profilePhotoUrl, radius: 14, frameUrl: user.profileFrame, vipTier: user.vipTier, tags: user.tags, userLevel: user.level),
                  const Gap(8),
                  Expanded(child: Text(user.displayName, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('💰 ${_formatNum(partner['share'] ?? 0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (isOwner) ...[
                    const Gap(4),
                    GestureDetector(
                      onTap: () => _removePartnerConfirm(roomId, uid, user.displayName),
                      child: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  // ─── Target & Reward Table ──────────────────────────────
  Widget _buildTargetTableSection() {
    final configAsync = ref.watch(roomSupportConfigProvider);
    final config = configAsync.valueOrNull;
    final levels = (config?['levels'] as List<dynamic>?) ?? [];
    if (levels.isEmpty) return const SizedBox.shrink();

    return _buildGoldCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Target & Reward'),
          const Gap(16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_borderGold.withOpacity(0.2)),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              headingTextStyle: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.bold),
              dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 11),
              columns: const [
                DataColumn(label: Text('Lv')),
                DataColumn(label: Text('Target 🪙')),
                DataColumn(label: Text('Slots')),
                DataColumn(label: Text('Owner 💎')),
                DataColumn(label: Text('Partner 💎')),
                DataColumn(label: Text('Total 💎')),
              ],
              rows: levels.map((lvl) {
                final l = lvl as Map<String, dynamic>;
                return DataRow(cells: [
                  DataCell(Text('${l['level']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataCell(Text(_formatNum((l['coinsTarget'] as num?)?.toInt() ?? 0), style: const TextStyle(color: _gold))),
                  DataCell(Text('${l['partnerSlots']}')),
                  DataCell(Text(_formatNum((l['ownerReward'] as num?)?.toInt() ?? 0), style: const TextStyle(color: Colors.greenAccent))),
                  DataCell(Text(_formatNum((l['partnerReward'] as num?)?.toInt() ?? 0), style: const TextStyle(color: Colors.greenAccent))),
                  DataCell(Text(_formatNum((l['totalReward'] as num?)?.toInt() ?? 0), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ranking ────────────────────────────────────────────
  Widget _buildRankingSection() {
    final rankingsAsync = ref.watch(roomSupportRankingsProvider);
    final rankings = rankingsAsync.valueOrNull ?? [];

    return _buildGoldCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Ranking'),
          const Gap(16),
          if (rankings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderGold.withOpacity(0.1)),
              ),
              child: const Text('No ranking data yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            ...rankings.take(10).toList().asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final r = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: rank <= 3 ? _gold.withOpacity(0.08) : _gold.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: rank <= 3 ? Border.all(color: _gold.withOpacity(0.3)) : Border.all(color: _borderGold.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('#$rank', style: TextStyle(
                        color: rank == 1 ? _gold : rank == 2 ? const Color(0xFFC0C0C0) : rank == 3 ? const Color(0xFFCD7F32) : Colors.white38,
                        fontWeight: FontWeight.bold, fontSize: 12,
                      )),
                    ),
                    Text(r['roomName'] ?? 'Room', style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text('${_formatNum((r['totalCoins'] as num?)?.toInt() ?? 0)} 🪙', style: const TextStyle(color: _gold, fontSize: 11)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Reward Distribution ────────────────────────────────
  Widget _buildRewardDistributionSection(String roomId) {
    final cycleAsync = ref.watch(roomSupportCycleProvider(roomId));
    final configAsync = ref.watch(roomSupportConfigProvider);
    final cycle = cycleAsync.valueOrNull ?? {};
    final config = configAsync.valueOrNull;
    final levels = (config?['levels'] as List<dynamic>?) ?? [];

    final currentLevel = (cycle['level'] as num?)?.toInt() ?? 1;
    final totalCoins = (cycle['totalCoins'] as num?)?.toInt() ?? 0;

    int achievedOwnerReward = 0;
    int achievedPartnerReward = 0;
    for (final lvl in levels) {
      final l = lvl as Map<String, dynamic>;
      if ((l['level'] as num?)?.toInt() == currentLevel && totalCoins >= ((l['coinsTarget'] as num?)?.toInt() ?? 0)) {
        achievedOwnerReward = (l['ownerReward'] as num?)?.toInt() ?? 0;
        achievedPartnerReward = (l['partnerReward'] as num?)?.toInt() ?? 0;
      }
    }

    return _buildGoldCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Reward Distribution'),
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                _buildTableRow('Owner Reward', '${_formatNum(achievedOwnerReward)} 💎', Icons.diamond_outlined),
                Divider(color: _borderGold.withOpacity(0.15), height: 1),
                _buildTableRow('Partner Reward (each)', '${_formatNum(achievedPartnerReward)} 💎', Icons.groups_outlined),
              ],
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Icon(Icons.calendar_today, color: _gold.withOpacity(0.6), size: 14),
              const Gap(6),
              const Text('Next Distribution: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(_nextWednesday(), style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── History ────────────────────────────────────────────
  Widget _buildHistorySection(String roomId) {
    final historyAsync = ref.watch(roomSupportHistoryProvider(roomId));
    final history = historyAsync.valueOrNull ?? [];

    return _buildGoldCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Last Week History'),
          const Gap(16),
          if (history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderGold.withOpacity(0.1)),
              ),
              child: const Text('No history yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            ...history.take(5).map((h) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderGold.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildTableRow('Level', '${h['achievedLevel'] ?? '-'}', Icons.trending_up),
                  Divider(color: _borderGold.withOpacity(0.15), height: 1),
                  _buildTableRow('Coins', '${_formatNum((h['totalCoins'] as num?)?.toInt() ?? 0)} 🪙', Icons.monetization_on_outlined),
                  Divider(color: _borderGold.withOpacity(0.15), height: 1),
                  _buildTableRow('Owner Reward', '${_formatNum((h['ownerReward'] as num?)?.toInt() ?? 0)} 💎', Icons.diamond_outlined),
                  Divider(color: _borderGold.withOpacity(0.15), height: 1),
                  _buildTableRow('Status', h['distributionStatus'] == 'distributed' ? '✅ Distributed' : h['distributionStatus'] == 'pending' ? '⏳ Pending' : '❌ No Target', Icons.info_outline),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: _gold.withOpacity(0.6), fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGlassCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  // ─── Dialogs ────────────────────────────────────────────
  void _removePartnerConfirm(String roomId, String partnerUid, String displayName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Row(
          children: [
            const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20),
            const Gap(8),
            const Text('Remove Partner?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text('Remove $displayName as a salary partner?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final container = ProviderScope.containerOf(context, listen: false);
                await container.read(roomSupportServiceProvider).removePartner(roomId, partnerUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$displayName removed'), backgroundColor: const Color(0xFFD4A017), behavior: SnackBarBehavior.floating),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                  );
                }
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showPartnerPickerDialog(String roomId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PartnerPicker(roomId: roomId),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────
  String _formatNum(int n) {
    if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return n.toString();
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '-';
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day}/${d.month}/${d.year}';
    }
    return '$ts';
  }

  String _nextWednesday() {
    final now = DateTime.now();
    final daysUntilWednesday = (3 - now.weekday + 7) % 7;
    final next = now.add(Duration(days: daysUntilWednesday == 0 ? 7 : daysUntilWednesday));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${next.day} ${months[next.month - 1]} ${next.year}';
  }
}

// ─── Partner Picker Widget ──────────────────────────────────
class _PartnerPicker extends StatefulWidget {
  final String roomId;
  const _PartnerPicker({required this.roomId});

  @override
  State<_PartnerPicker> createState() => _PartnerPickerState();
}

class _PartnerPickerState extends State<_PartnerPicker> {
  final _searchController = TextEditingController();
  final _db = FirebaseFirestore.instance;

  static const Color _gold = Color(0xFFFFD700);
  static const Color _borderGold = Color(0xFF8C6E30);

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
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _gold.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const Gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: _gold, size: 20),
              const Gap(8),
              const Text('Select a Salary Partner', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Gap(4),
          Text('Search by display name', style: TextStyle(color: _gold.withOpacity(0.5), fontSize: 12)),
          const Gap(16),
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type a name...',
              hintStyle: TextStyle(color: _gold.withOpacity(0.3)),
              prefixIcon: Icon(Icons.search, color: _gold.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderGold.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderGold.withOpacity(0.15)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => setState(() {}),
          ),
          const Gap(12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _searchController.text.trim().length < 2
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Type at least 2 characters', style: TextStyle(color: _gold.withOpacity(0.3), fontSize: 13)),
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
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _gold));
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('No users found', style: TextStyle(color: _gold.withOpacity(0.3), fontSize: 13)),
                        );
                      }
                      final myUid = FirebaseAuth.instance.currentUser?.uid;
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => Divider(color: _borderGold.withOpacity(0.1), height: 1),
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
                              style: TextStyle(
                                color: isMe ? _gold : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: data['username'] != null
                                ? Text('@${data['username']}', style: const TextStyle(color: Colors.white38, fontSize: 11))
                                : null,
                            trailing: isMe
                                ? const Text('You', style: TextStyle(color: Colors.white24, fontSize: 11))
                                : IconButton(
                                    icon: Icon(Icons.person_add_rounded, color: _gold, size: 20),
                                    onPressed: () => _assignPartner(uid, data['displayName'] as String? ?? uid),
                                  ),
                            onTap: isMe ? null : () => _assignPartner(uid, data['displayName'] as String? ?? uid),
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
            backgroundColor: const Color(0xFFB8860B),
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
