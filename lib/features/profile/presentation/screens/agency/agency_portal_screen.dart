import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/agency_provider.dart';
import 'package:hello_chat/core/models/agency_model.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/router/app_router.dart';
import 'package:hello_chat/core/widgets/app_toast.dart';
import 'package:hello_chat/features/wallet/presentation/screens/withdraw_beans_screen.dart';

// ─────────────────────────────────────────────
//  User Control / Agency Theme Tokens
// ─────────────────────────────────────────────
class UserControlTheme {
  static const bgGradientTop    = Color(0xFF032626);
  static const bgGradientMid    = Color(0xFF011717);
  static const bgGradientBottom = Color(0xFF010D0D);

  static const cardBg           = Color(0xFF033B39);
  static const cardBgDark       = Color(0xFF022424);
  static const cardBorder       = Color(0xFF0E5D59);

  static const activeIndicator  = Color(0xFFEAB308); // Yellow/gold indicator from screenshot
  static const activePillBorder = Color(0xFF2DD4BF); // Teal active border
  static const activePillBg     = Color(0xFF0D3B39);
  static const inactivePillBg   = Color(0xFF062222);

  static const primaryGreen     = Color(0xFF4ADE80); // Lime green action button
  static const primaryGreenEnd  = Color(0xFF86EFAC);
  static const primaryGreenDark = Color(0xFF052E16);

  static const textWhite        = Colors.white;
  static const textMuted        = Color(0xFF80A6A4);
  static const textTeal         = Color(0xFF2DD4BF);
  static const coinYellow       = Color(0xFFFBBF24);
}

// ─────────────────────────────────────────────
//  User Control Screen (Agency / Host Portal)
// ─────────────────────────────────────────────
class AgencyPortalScreen extends ConsumerStatefulWidget {
  const AgencyPortalScreen({super.key});

  @override
  ConsumerState<AgencyPortalScreen> createState() => _AgencyPortalScreenState();
}

class _AgencyPortalScreenState extends ConsumerState<AgencyPortalScreen> {
  String _selectedStatsMonth = '';
  Map<String, dynamic>? _agencyStatsData;
  bool _statsLoading = false;

  Future<void> _fetchAgencyStats(String agencyId, [String? month]) async {
    setState(() => _statsLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getAgencyRechargeStats');
      final res = await callable.call({
        'agencyId': agencyId,
        if (month != null && month.isNotEmpty) 'yearMonth': month,
      });
      final data = res.data as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _agencyStatsData = Map<String, dynamic>.from(data);
          _selectedStatsMonth = _agencyStatsData!['yearMonth']?.toString() ?? '';
          _statsLoading = false;
        });
      }
    } catch (_) {
      setState(() => _statsLoading = false);
    }
  }

  void _showHostRechargeRecords(BuildContext context, String agencyId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF032626),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final records = (_agencyStatsData?['recentRecords'] as List<dynamic>?) ?? [];
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              ),
              const Gap(16),
              const Text("Host Recharge Records", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const Gap(4),
              const Text("Individual recharge transactions for all hosts under this agency", style: TextStyle(color: Colors.white54, fontSize: 11)),
              const Gap(16),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text("No recharge transactions recorded for this period.", style: TextStyle(color: Colors.white54)))
                    : ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Gap(8),
                        itemBuilder: (c, idx) {
                          final r = records[idx] as Map;
                          final hName = r['hostName']?.toString() ?? 'Host';
                          final hHello = r['hostHelloId']?.toString() ?? '';
                          final usd = (r['usdAmount'] as num?)?.toDouble() ?? 0.0;
                          final dia = (r['diamonds'] as num?)?.toInt() ?? 0;
                          final day = r['day']?.toString() ?? '';
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFF063534), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0B4C4A))),
                            child: Row(
                              children: [
                                const CircleAvatar(backgroundColor: Color(0xFF042A27), child: Icon(Icons.person, color: Color(0xFF7DE2A0), size: 18)),
                                const Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(hName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text("ID: " + hHello + " • " + day, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("\$" + usd.toStringAsFixed(2), style: const TextStyle(color: Color(0xFF7DE2A0), fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                                    Text(dia.toString() + " 💎", style: const TextStyle(color: Colors.amber, fontSize: 11)),
                                  ],
                                ),
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
  }

  Widget _buildAgencyDataStatsCard(AgencyModel agency) {
    if (_agencyStatsData == null && !_statsLoading) {
      _fetchAgencyStats(agency.id);
    }

    final history = (_agencyStatsData?['monthlyHistory'] as List<dynamic>?) ?? [];
    final combinedTotal = (_agencyStatsData?['combinedTotalRechargeUSD'] as num?)?.toDouble() ?? 0.0;
    final hostCount = (_agencyStatsData?['hostCount'] as num?)?.toInt() ?? agency.hostUids.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF032626),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0E5D59)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Data & Statistics", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _showHostRechargeRecords(context, agency.id),
                icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF7DE2A0), size: 16),
                label: const Text("Recharge Records", style: TextStyle(color: Color(0xFF7DE2A0), fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Gap(8),
          // 3-Month Report History Chips
          if (history.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: history.map((m) {
                  final ym = (m as Map)['yearMonth']?.toString() ?? '';
                  final isSel = ym == (_selectedMonthOrCurrent());
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(ym, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      selected: isSel,
                      selectedColor: const Color(0xFF7DE2A0),
                      backgroundColor: const Color(0xFF063534),
                      onSelected: (_) => _fetchAgencyStats(agency.id, ym),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Gap(12),
          ],
          // Combined Total Recharge banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF022C22)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("COMBINED HOST RECHARGE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    const Gap(2),
                    Text(
                      "\$" + combinedTotal.toStringAsFixed(2),
                      style: const TextStyle(color: Color(0xFF7DE2A0), fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                Text(
                  hostCount.toString() + " Hosts Managed\nStarts at 0 on 1st of month",
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.3),
                ),
              ],
            ),
          ),
          const Gap(12),
          // 5 Stats: Day, Time, Beans, Target, Recharge
          Row(
            children: [
              Expanded(child: _buildMiniDataPill("Day", "Activity", Icons.calendar_today_rounded)),
              const Gap(6),
              Expanded(child: _buildMiniDataPill("Time", "Mic Hours", Icons.timer_outlined)),
              const Gap(6),
              Expanded(child: _buildMiniDataPill("Beans", agency.beansBalance.toString(), Icons.monetization_on_outlined)),
              const Gap(6),
              Expanded(child: _buildMiniDataPill("Target", "Targets", Icons.track_changes_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  String _selectedMonthOrCurrent() {
    if (_selectedStatsMonth.isNotEmpty) return _selectedStatsMonth;
    final now = DateTime.now();
    return now.year.toString() + "-" + now.month.toString().padLeft(2, '0');
  }

  Widget _buildMiniDataPill(String title, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF063534),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0B4C4A)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7DE2A0), size: 14),
          const Gap(3),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold)),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // Top level tabs: 0 = Agency, 1 = Host
  int _mainTab = 0;

  // Agency sub-tabs: 0 = Data, 1 = Wallet, 2 = Management
  int _agencySubTab = 0;

  // Member search input in Data tab
  final TextEditingController _memberSearchCtrl = TextEditingController();
  String _memberSearchQuery = '';

  // Live Task Countdown Timer (ticking to end of current month)
  late Timer _countdownTimer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final now = DateTime.now();
    // End of current month
    final nextMonth = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
    final diff = nextMonth.difference(now);
    if (mounted) {
      setState(() {
        _timeRemaining = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myAgencyAsync = ref.watch(myAgencyProvider);
    final userAsync = ref.watch(currentUserProfileProvider);
    final currentUser = userAsync.value;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              UserControlTheme.bgGradientTop,
              UserControlTheme.bgGradientMid,
              UserControlTheme.bgGradientBottom,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar: Back Button + "User Control" Title
              _buildTopBar(),

              // 2. Main Navigation Tabs: Agency | Host
              _buildMainTabs(),

              const Gap(12),

              // 3. Tab Body
              Expanded(
                child: _mainTab == 0
                    ? _buildAgencyTabContent(myAgencyAsync, currentUser)
                    : _buildHostTabContent(currentUser, myAgencyAsync.value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Top Header Bar ─────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          const Text(
            'User Control',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Main Tabs (Agency / Host) ──────────────────────────────
  Widget _buildMainTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMainTabItem(title: 'Agency', index: 0),
          _buildMainTabItem(title: 'Host', index: 1),
        ],
      ),
    );
  }

  Widget _buildMainTabItem({required String title, required int index}) {
    final bool isSelected = _mainTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _mainTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : UserControlTheme.textMuted,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const Gap(4),
          // Curved underline indicator from screenshot
          Container(
            width: 22,
            height: 3.5,
            decoration: BoxDecoration(
              color: isSelected ? UserControlTheme.activeIndicator : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Agency Tab Content ─────────────────────────────────────
  Widget _buildAgencyTabContent(AsyncValue<AgencyModel?> myAgencyAsync, UserModel? currentUser) {
    return myAgencyAsync.when(
      data: (agency) {
        // If user is not yet associated with an agency, show create/join state
        if (agency == null && currentUser?.isAgencyOwner != true) {
          return _buildNotAnAgencyOwnerView(currentUser);
        }

        // Active Agency Profile (or fallback preview for branch owner)
        final effectiveAgency = agency ?? AgencyModel(
          id: currentUser?.agencyId ?? '13266',
          name: '${currentUser?.displayName ?? "User"}\'s Agency',
          ownerUid: currentUser?.uid ?? '12478008',
          ownerName: currentUser?.displayName ?? 'Agency Owner',
          logoUrl: currentUser?.profilePhotoUrl ?? '',
          description: 'Official Agency Platform',
          hostUids: [currentUser?.uid ?? '12478008'],
          createdAt: DateTime(2025, 3, 25),
        );

        return Column(
          children: [
            // Agency Sub-Tabs: Data | Wallet | Management
            _buildAgencySubTabs(),

            const Gap(14),

            // Sub-Tab Content
            Expanded(
              child: Stack(
                children: [
                  _agencySubTab == 0
                      ? _buildDataSubTab(effectiveAgency, currentUser)
                      : _agencySubTab == 1
                          ? _buildWalletSubTab(effectiveAgency, currentUser)
                          : _buildManagementSubTab(effectiveAgency, currentUser),

                  // Floating "Host Invitation" button on Data tab (matching screenshot)
                  if (_agencySubTab == 0)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: _buildHostInvitationButton(effectiveAgency),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: UserControlTheme.primaryGreen)),
      error: (e, _) => Center(
        child: Text('Error loading agency data: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  // ── Agency Sub-Tabs Pills (Data / Wallet / Management) ─────────
  Widget _buildAgencySubTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildSubTabPill('Data', 0)),
          const Gap(10),
          Expanded(child: _buildSubTabPill('Wallet', 1)),
          const Gap(10),
          Expanded(child: _buildSubTabPill('Management', 2)),
        ],
      ),
    );
  }

  Widget _buildSubTabPill(String title, int index) {
    final bool isSelected = _agencySubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _agencySubTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? UserControlTheme.activePillBg : UserControlTheme.inactivePillBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? UserControlTheme.activePillBorder : Colors.white.withValues(alpha: 0.05),
            width: 1.2,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? UserControlTheme.textTeal : UserControlTheme.textMuted,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Sub-Tab 0: DATA (Screenshots 2 & 3) ───────────────────────
  Widget _buildDataSubTab(AgencyModel agency, UserModel? currentUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Agency Main Card
          _buildAgencyProfileCard(agency, currentUser),

          const Gap(12),

          // 2. Recharge Services Banner
          _buildRechargeServicesTile(),

          const Gap(14),

          // 3. 3 Stat Cards in a Row: Target | Owner Salary | Host Salary
          _buildStatCardsRow(agency),

          const Gap(14),

          // Monthly Data, Statistics & 3-Month Reports
          _buildAgencyDataStatsCard(agency),

          const Gap(12),

          // 4. Notice: "This month's salary is paid directly to the Host"
          const Center(
            child: Text(
              "This month's salary is paid directly to the Host",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          const Gap(14),

          // 5. Task Countdown time banner: [DD] days [HH] h [MM] min [SS] s
          _buildTaskCountdownBanner(),

          const Gap(14),

          // 6. Section Title: "This Month's Member Task Progress"
          const Center(
            child: Text(
              "This Month's Member Task Progress",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const Gap(12),

          // 7. Member ID Search Bar
          _buildMemberSearchBar(),

          const Gap(14),

          // 8. Member List Roster
          _buildMembersRosterList(agency),
        ],
      ),
    );
  }

  // ── Agency Profile Card (Screenshot 2) ────────────────────────
  Widget _buildAgencyProfileCard(AgencyModel agency, UserModel? currentUser) {
    final ownerId = currentUser?.displayId.isNotEmpty == true
        ? currentUser!.displayId
        : agency.ownerUid.length > 8
            ? agency.ownerUid.substring(0, 8)
            : agency.ownerUid;

    final createdStr = "${agency.createdAt.year}-${agency.createdAt.month.toString().padLeft(2, '0')}-${agency.createdAt.day.toString().padLeft(2, '0')}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UserControlTheme.cardBg, UserControlTheme.cardBgDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Circle
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(4),
                child: agency.logoUrl.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: agency.logoUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _defaultAgencyIcon(),
                        ),
                      )
                    : _defaultAgencyIcon(),
              ),

              const Gap(14),

              // Agency Name, ID, Members
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agency.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(3),
                    Text(
                      'Agency ID: ${agency.id}',
                      style: const TextStyle(color: UserControlTheme.textMuted, fontSize: 11.5),
                    ),
                    const Gap(1),
                    Text(
                      'Agency Members: ${agency.hostUids.length}',
                      style: const TextStyle(color: UserControlTheme.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),

              // Gear / Settings Icon
              GestureDetector(
                onTap: () => _showAgencySettingsSheet(agency),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                ),
              ),
            ],
          ),

          const Gap(14),

          // Owner ID Tile with chevron
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Agency Owner ID: $ownerId',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 20),
              ],
            ),
          ),

          const Gap(10),

          // Created Time
          Center(
            child: Text(
              'Created Time: $createdStr',
              style: const TextStyle(color: UserControlTheme.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAgencyIcon() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFDC2626),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  // ── Recharge Services Tile ────────────────────────────────────
  Widget _buildRechargeServicesTile() {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.wallet),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: UserControlTheme.cardBgDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: UserControlTheme.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, color: UserControlTheme.primaryGreen, size: 20),
            ),
            const Gap(12),
            const Expanded(
              child: Text(
                'Recharge Services',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 22),
          ],
        ),
      ),
    );
  }

  // ── 3 Stat Cards Row ──────────────────────────────────────────
  Widget _buildStatCardsRow(AgencyModel agency) {
    return Row(
      children: [
        // Target Card
        Expanded(
          child: _buildMetricCard(
            topValue: '0',
            bottomLabel: 'Target',
            showUmeCoin: true,
          ),
        ),
        const Gap(8),
        // Owner Salary Card
        Expanded(
          child: _buildMetricCard(
            topValue: '0 \$',
            bottomLabel: 'Owner Salary',
          ),
        ),
        const Gap(8),
        // Host Salary Card
        Expanded(
          child: _buildMetricCard(
            topValue: '0 \$',
            bottomLabel: 'Host Salary',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({required String topValue, required String bottomLabel, bool showUmeCoin = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF094E4D), Color(0xFF042F31)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            topValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showUmeCoin) ...[
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: UserControlTheme.coinYellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('U', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ),
                const Gap(4),
              ],
              Text(
                bottomLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Task Countdown Banner ─────────────────────────────────────
  Widget _buildTaskCountdownBanner() {
    final days = _timeRemaining.inDays.toString().padLeft(2, '0');
    final hours = (_timeRemaining.inHours % 24).toString().padLeft(2, '0');
    final mins = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Task Countdown time: ',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          _buildTimerChip(days),
          const Text(' days ', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
          _buildTimerChip(hours),
          const Text(' h ', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
          _buildTimerChip(mins),
          const Text(' min ', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
          _buildTimerChip(secs),
          const Text(' s', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _buildTimerChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: UserControlTheme.activePillBorder.withValues(alpha: 0.8), width: 1),
        color: Colors.black.withValues(alpha: 0.3),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: UserControlTheme.textTeal,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // ── Member Search Bar ─────────────────────────────────────────
  Widget _buildMemberSearchBar() {
    return Row(
      children: [
        const Text(
          'ID: ',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const Gap(6),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _memberSearchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: "Please enter the other party's UME ID",
                hintStyle: TextStyle(color: Colors.white30, fontSize: 11.5),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
              onChanged: (val) => setState(() => _memberSearchQuery = val.trim()),
            ),
          ),
        ),
        const Gap(10),
        GestureDetector(
          onTap: () {
            setState(() => _memberSearchQuery = _memberSearchCtrl.text.trim());
          },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UserControlTheme.primaryGreenEnd, UserControlTheme.primaryGreen],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Search',
              style: TextStyle(
                color: UserControlTheme.primaryGreenDark,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Members Roster List ───────────────────────────────────────
  Widget _buildMembersRosterList(AgencyModel agency) {
    final hostsAsync = ref.watch(agencyHostsProvider(agency.id));

    return hostsAsync.when(
      data: (hosts) {
        final filtered = hosts.where((h) {
          if (_memberSearchQuery.isEmpty) return true;
          return h.displayId.contains(_memberSearchQuery) ||
                 h.displayName.toLowerCase().contains(_memberSearchQuery.toLowerCase());
        }).toList();

        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.person_search_rounded, size: 40, color: Colors.white.withValues(alpha: 0.2)),
                  const Gap(8),
                  const Text('No members found', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Gap(12),
                  const Text('No more', style: TextStyle(color: Colors.white30, fontSize: 11)),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            ...filtered.map((host) => _buildMemberItemCard(host)),
            const Gap(12),
            const Text('No more', style: TextStyle(color: Colors.white30, fontSize: 11)),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: UserControlTheme.primaryGreen)),
      ),
      error: (_, __) => const Center(child: Text('Error loading hosts', style: TextStyle(color: Colors.redAccent))),
    );
  }

  Widget _buildMemberItemCard(UserModel host) {
    final lastLoginStr = DateTime.now().toString().substring(0, 10);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white12,
            backgroundImage: host.profilePhotoUrl.isNotEmpty ? CachedNetworkImageProvider(host.profilePhotoUrl) : null,
            child: host.profilePhotoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white70, size: 20)
                : null,
          ),

          const Gap(12),

          // Name & ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  host.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  'ID: ${host.displayId}',
                  style: const TextStyle(color: UserControlTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),

          // Task Income, Mic Days, Last Login
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Task Income ', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                  Text('${host.beansBalance}', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  const Gap(2),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: UserControlTheme.coinYellow, shape: BoxShape.circle),
                    child: const Center(child: Text('U', style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w900, color: Colors.black))),
                  ),
                ],
              ),
              const Gap(2),
              const Text('Mic Days: 0', style: TextStyle(color: Colors.white54, fontSize: 10)),
              const Gap(1),
              Text('Last Login: $lastLoginStr', style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Floating "Host Invitation" Button (Screenshot 2 & 3) ───────
  Widget _buildHostInvitationButton(AgencyModel agency) {
    return GestureDetector(
      onTap: () => _openHostInvitationModal(agency),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [UserControlTheme.primaryGreenEnd, UserControlTheme.primaryGreen],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: UserControlTheme.primaryGreen.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Host Invitation',
          style: TextStyle(
            color: UserControlTheme.primaryGreenDark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ── Sub-Tab 1: WALLET (Screenshot 1) ──────────────────────────
  Widget _buildWalletSubTab(AgencyModel agency, UserModel? currentUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 1. Ticket Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF044846), Color(0xFF022B2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.6), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Agency Beans: ',
                      style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      NumberFormat('#,##0').format(agency.beansBalance),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monetization_on, color: Colors.white, size: 12),
                          Gap(3),
                          Text(
                            'BEANS',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                Text(
                  '${(agency.commissionRate * 100).toInt()}% gift commission from ${agency.hostUids.length} active hosts',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
                ),
              ],
            ),
          ),

          const Gap(16),

          // 2. Recharge Services
          _buildRechargeServicesTile(),

          const Gap(18),

          // 3. 4 Action Grid items: Transfer | Withdraw | Pay Slips | Records
          Row(
            children: [
              Expanded(
                child: _buildWalletActionTile(
                  title: 'Transfer',
                  icon: Icons.monetization_on_outlined,
                  onTap: () {
                    AppToast.showOverlay(context, message: 'Transfer to host wallet available', type: ToastType.info);
                  },
                ),
              ),
              const Gap(12),
              Expanded(
                child: _buildWalletActionTile(
                  title: 'Withdraw',
                  icon: Icons.account_balance_outlined,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawBeansScreen()));
                  },
                ),
              ),
              const Gap(12),
              Expanded(
                child: _buildWalletActionTile(
                  title: 'Pay Slips',
                  icon: Icons.credit_card_rounded,
                  onTap: () {
                    _showPaySlipsModal(agency);
                  },
                ),
              ),
              const Gap(12),
              Expanded(
                child: _buildWalletActionTile(
                  title: 'Records',
                  icon: Icons.assignment_outlined,
                  onTap: () {
                    _showRecordsModal(agency);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: UserControlTheme.cardBgDark.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: UserControlTheme.primaryGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: UserControlTheme.primaryGreen, size: 24),
            ),
            const Gap(8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-Tab 2: MANAGEMENT ─────────────────────────────────────
  Widget _buildManagementSubTab(AgencyModel agency, UserModel? currentUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: UserControlTheme.cardBgDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AGENCY CONFIGURATION',
                  style: TextStyle(color: UserControlTheme.textTeal, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Gap(14),
                _buildConfigRow('Agency Name', agency.name),
                const Divider(color: Colors.white10),
                _buildConfigRow('Agency ID', agency.id),
                const Divider(color: Colors.white10),
                _buildConfigRow('Commission Rate', '${(agency.commissionRate * 100).toInt()}%'),
                const Divider(color: Colors.white10),
                _buildConfigRow('Supervised Hosts', '${agency.hostUids.length} active hosts'),
              ],
            ),
          ),
          const Gap(16),
          // Invite Host Action
          ElevatedButton.icon(
            onPressed: () => _openHostInvitationModal(agency),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Recruit & Invite Hosts', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: UserControlTheme.primaryGreen,
              foregroundColor: UserControlTheme.primaryGreenDark,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── TOP TAB: HOST VIEW ────────────────────────────────────────
  Widget _buildHostTabContent(UserModel? currentUser, AgencyModel? agency) {
    final hostBeans = currentUser?.beansBalance ?? 0;
    final target = currentUser?.monthlyTargetBeans ?? 50000;
    final progress = target > 0 ? (hostBeans / target).clamp(0.0, 1.0) : 0.0;
    final lastLoginStr = DateTime.now().toString().substring(0, 10);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Host Profile Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF044846), Color(0xFF022B2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: (currentUser?.profilePhotoUrl.isNotEmpty == true)
                      ? CachedNetworkImageProvider(currentUser!.profilePhotoUrl)
                      : null,
                  child: (currentUser?.profilePhotoUrl.isEmpty == true)
                      ? const Icon(Icons.person, color: Colors.white, size: 28)
                      : null,
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.displayName ?? 'Host',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Gap(2),
                      Text('UME ID: ${currentUser?.displayId ?? "N/A"}', style: const TextStyle(color: UserControlTheme.textMuted, fontSize: 12)),
                      Text('Affiliation: ${agency?.name ?? "Independent"}', style: const TextStyle(color: UserControlTheme.textTeal, fontSize: 12)),
                      const Gap(2),
                      Text('Last Login: $lastLoginStr', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Gap(16),

          // Countdown
          _buildTaskCountdownBanner(),

          const Gap(16),

          // Monthly Target Progress
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: UserControlTheme.cardBgDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly Target Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${(progress * 100).toInt()}%', style: const TextStyle(color: UserControlTheme.textTeal, fontWeight: FontWeight.w900)),
                  ],
                ),
                const Gap(10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(UserControlTheme.primaryGreen),
                  ),
                ),
                const Gap(12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Earned: $hostBeans Beans', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('Target: $target Beans', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          const Gap(16),

          // Host Statistics (Mic hours, income)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(topValue: '0', bottomLabel: 'Mic Days'),
              ),
              const Gap(10),
              Expanded(
                child: _buildMetricCard(topValue: '0 h', bottomLabel: 'Mic Hours'),
              ),
              const Gap(10),
              Expanded(
                child: _buildMetricCard(topValue: '$hostBeans', bottomLabel: 'Task Income', showUmeCoin: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Host Invitation Bottom Sheet (Screenshot 4) ───────────────
  void _openHostInvitationModal(AgencyModel agency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HostInvitationSheet(agency: agency),
    );
  }

  void _showAgencySettingsSheet(AgencyModel agency) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF042424),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agency Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(16),
            Text('Agency Name: ${agency.name}', style: const TextStyle(color: Colors.white70)),
            const Gap(8),
            Text('Owner ID: ${agency.ownerUid}', style: const TextStyle(color: Colors.white70)),
            const Gap(8),
            Text('Commission Split: ${(agency.commissionRate * 100).toInt()}%', style: const TextStyle(color: Colors.white70)),
            const Gap(24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: UserControlTheme.primaryGreen,
                foregroundColor: UserControlTheme.primaryGreenDark,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaySlipsModal(AgencyModel agency) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF042424),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Monthly Pay Slips', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Gap(16),
            Text('Current billing period: Paid directly to hosts per policy.', style: TextStyle(color: Colors.white70)),
            Gap(12),
            Text('No pending disputes.', style: TextStyle(color: UserControlTheme.textTeal)),
          ],
        ),
      ),
    );
  }

  void _showRecordsModal(AgencyModel agency) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF042424),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Agency Balance & Ledger', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: UserControlTheme.cardBgDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: UserControlTheme.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Beans Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${NumberFormat('#,##0').format(agency.beansBalance)} Beans',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Beans Earned', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${NumberFormat('#,##0').format(agency.totalBeansEarned)} Beans',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Agency Commission Rate', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${(agency.commissionRate * 100).toInt()}%',
                        style: const TextStyle(color: UserControlTheme.primaryGreen, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Roster Size', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${agency.hostUids.length} Hosts',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.tealAccent, size: 18),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'Commission rule: The agency earns a ${(agency.commissionRate * 100).toInt()}% bean share whenever any gift is received by an agency host.',
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: UserControlTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WithdrawBeansScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet, color: Colors.black87),
                label: const Text('Withdraw Beans', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Not an agency owner fallback ──────────────────────────────
  Widget _buildNotAnAgencyOwnerView(UserModel? currentUser) {
    final agencyNameCtrl = TextEditingController();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.business_center_rounded, color: UserControlTheme.primaryGreen, size: 54),
          const Gap(16),
          const Text('Become an Agency Partner', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Gap(8),
          const Text('Manage hosts, earn distribution commissions, and participate in agency events.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13)),
          const Gap(24),
          TextField(
            controller: agencyNameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter Agency Name',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: UserControlTheme.cardBgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const Gap(16),
          ElevatedButton(
            onPressed: () async {
              final name = agencyNameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(agencyServiceProvider).createAgency(name, 'Official Agency', '');
                if (!mounted) return;
                AppToast.showOverlay(context, message: 'Agency created successfully!', type: ToastType.success);
              } catch (e) {
                if (!mounted) return;
                AppToast.showOverlay(context, message: 'Failed: $e', type: ToastType.error);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: UserControlTheme.primaryGreen,
              foregroundColor: UserControlTheme.primaryGreenDark,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Create Agency', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Host Invitation Sheet (Screenshot 4)
// ─────────────────────────────────────────────
class _HostInvitationSheet extends ConsumerStatefulWidget {
  final AgencyModel agency;
  const _HostInvitationSheet({required this.agency});

  @override
  ConsumerState<_HostInvitationSheet> createState() => _HostInvitationSheetState();
}

class _HostInvitationSheetState extends ConsumerState<_HostInvitationSheet> {
  int _subTab = 0; // 0 = Members Management, 1 = Application Management
  final TextEditingController _idController = TextEditingController();
  bool _isInviting = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _handleInvite() async {
    final query = _idController.text.trim();
    if (query.isEmpty) {
      AppToast.showOverlay(context, message: 'Please enter a valid User ID', type: ToastType.info);
      return;
    }

    setState(() => _isInviting = true);
    try {
      await ref.read(agencyServiceProvider).addHostToAgency(widget.agency.id, query);
      if (mounted) {
        AppToast.showOverlay(context, message: 'Host invited successfully!', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showOverlay(context, message: 'Invitation failed: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: UserControlTheme.bgGradientMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header: Back Arrow + Title "Host Invitation"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const Text(
                  'Host Invitation',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Two Tabs: Members Management | Application Management
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildSubTab('Members Management', 0)),
                Expanded(child: _buildSubTab('Application Management', 1)),
              ],
            ),
          ),

          const Gap(16),

          Expanded(
            child: _subTab == 0
                ? _buildMembersManagementBody()
                : _buildApplicationManagementBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(String title, int index) {
    final bool isSelected = _subTab == index;
    return GestureDetector(
      onTap: () => setState(() => _subTab = index),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : UserControlTheme.textMuted,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const Gap(4),
          Container(
            width: 26,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? UserControlTheme.activeIndicator : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // Members Management Body (Screenshot 4)
  Widget _buildMembersManagementBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Dark Card Container for ID input
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: UserControlTheme.cardBgDark.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: UserControlTheme.cardBorder.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ID:',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Gap(8),
                TextField(
                  controller: _idController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: "Please enter the other party's ID",
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),

          const Gap(32),

          // Big Green Gradient Button: "Invitation"
          GestureDetector(
            onTap: _isInviting ? null : _handleInvite,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [UserControlTheme.primaryGreenEnd, UserControlTheme.primaryGreen],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: UserControlTheme.primaryGreen.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isInviting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text(
                      'Invitation',
                      style: TextStyle(
                        color: UserControlTheme.primaryGreenDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Application Management Body
  Widget _buildApplicationManagementBody() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.white24),
          Gap(12),
          Text('No pending host applications', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}
