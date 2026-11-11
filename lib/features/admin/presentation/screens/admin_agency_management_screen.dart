import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_toast.dart';

class AdminAgencyManagementScreen extends ConsumerStatefulWidget {
  const AdminAgencyManagementScreen({super.key});

  @override
  ConsumerState<AdminAgencyManagementScreen> createState() =>
      _AdminAgencyManagementScreenState();
}

class _AdminAgencyManagementScreenState
    extends ConsumerState<AdminAgencyManagementScreen> {
  static const _bg = Color(0xFF0A0D14);
  static const _card = Color(0xFF131A29);
  static const _border = Color(0xFF273244);
  static const _accent = Color(0xFF6366F1);
  static const _gold = Color(0xFFF59E0B);

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _agencies = [];
  Map<String, dynamic>? _selectedAgency;
  List<Map<String, dynamic>> _hosts = [];
  String _search = '';
  String _statusFilter = 'all';
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgencies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<dynamic> _call(String name, [Map<String, dynamic>? data]) {
    return FirebaseFunctions.instance
        .httpsCallable(name)
        .call(data)
        .then((r) => r.data);
  }

  String _message(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? error.code;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _loadAgencies({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _call('listAgencies');
      final map = Map<String, dynamic>.from(result as Map);
      final list = (map['agencies'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _agencies = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _openAgency(String agencyId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _call('getAgency', {'agencyId': agencyId});
      final map = Map<String, dynamic>.from(result as Map);
      final agency = Map<String, dynamic>.from(map['agency'] as Map);
      final hosts = (map['hosts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _selectedAgency = agency;
        _hosts = hosts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(e);
      });
    }
  }

  void _backToList() {
    setState(() {
      _selectedAgency = null;
      _hosts = [];
      _error = null;
      _loading = false;
    });
  }

  Future<void> _act(Future<dynamic> Function() action, String success) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
      if (!mounted) return;
      AppToast.showOverlay(context, message: success, type: ToastType.success);
      final agencyId = _selectedAgency?['agencyId']?.toString();
      await _loadAgencies(showSpinner: false);
      if (agencyId != null && mounted) {
        await _openAgency(agencyId);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showOverlay(
          context,
          message: _message(e),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _appointAgency(UserModel user) async {
    final isPlainAdmin = _isPlainAdmin(user);
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AgencyFormDialog(
        title: 'Appoint Agency',
        submitLabel: 'Appoint Agency',
        isPlainAdmin: isPlainAdmin,
      ),
    );
    if (data == null) return;
    await _act(
      () => _call('createAgency', data),
      'Agency appointed successfully.',
    );
  }

    Future<void> _showAgencyReports(Map<String, dynamic> agency) async {
    final agencyId = agency['agencyId'].toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AgencyReportsSheet(
        agencyId: agencyId,
        agencyName: agency['name']?.toString() ?? 'Agency',
        call: _call,
      ),
    );
  }

  Future<void> _editAgency() async {
    final agency = _selectedAgency;
    if (agency == null) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AgencyFormDialog(
        title: 'Edit Agency',
        submitLabel: 'Save Changes',
        isPlainAdmin: true,
        initial: agency,
      ),
    );
    if (data == null) return;
    data['agencyId'] = agency['agencyId'];
    await _act(
      () => _call('updateAgency', data),
      'Agency updated successfully.',
    );
  }

  Future<void> _toggleAgencyStatus() async {
    final agency = _selectedAgency;
    if (agency == null) return;
    final isActive = agency['isActive'] != false;
    final nextStatus = isActive ? 'suspended' : 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text(
          isActive ? 'Suspend Agency?' : 'Activate Agency?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isActive
              ? '${agency['name']} and its hosts will lose agency access until reactivated.'
              : '${agency['name']} and its owner will regain agency access.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isActive ? 'Suspend' : 'Activate',
              style: TextStyle(
                  color: isActive ? Colors.redAccent : Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _act(
      () => _call('setAgencyStatus', {
        'agencyId': agency['agencyId'],
        'status': nextStatus,
      }),
      isActive ? 'Agency suspended.' : 'Agency activated.',
    );
  }

  Future<void> _recruitHost() async {
    final agency = _selectedAgency;
    if (agency == null) return;
    final identifier = await showDialog<String>(
      context: context,
      builder: (_) => const _TextPromptDialog(
        title: 'Recruit Host',
        label: 'Host Hello ID or UID',
        hint: 'e.g. 5621916410',
        submitLabel: 'Add to Agency',
      ),
    );
    if (identifier == null || identifier.trim().isEmpty) return;
    await _act(
      () => _call('addHost', {
        'agencyId': agency['agencyId'],
        'hostIdentifier': identifier.trim(),
      }),
      'Host added to agency.',
    );
  }

  Future<void> _removeHost(Map<String, dynamic> host) async {
    final agency = _selectedAgency;
    if (agency == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title:
            const Text('Release Host?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${host['displayName'] ?? 'This host'} will be removed from ${agency['name']}.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Release',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _act(
      () => _call('removeHost', {
        'agencyId': agency['agencyId'],
        'hostUid': host['uid'],
      }),
      'Host released from agency.',
    );
  }

  bool _isPlainAdmin(UserModel user) {
    return !user.isOwner &&
        !user.isSuperAdmin &&
        !user.tags.contains('SuperAdmin') &&
        user.role != 'superadmin';
  }

  List<Map<String, dynamic>> get _filteredAgencies {
    final term = _search.trim().toLowerCase();
    return _agencies.where((agency) {
      final active = agency['isActive'] != false;
      if (_statusFilter == 'active' && !active) return false;
      if (_statusFilter == 'suspended' && active) return false;
      if (term.isEmpty) return true;
      final haystack = [
        agency['name'],
        agency['ownerName'],
        agency['ownerHelloId'],
        agency['agencyId'],
        agency['code'],
      ].join(' ').toLowerCase();
      return haystack.contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    final inDetail = _selectedAgency != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1422),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: inDetail ? _backToList : () => context.pop(),
        ),
        title: Text(
          inDetail ? 'AGENCY DETAILS' : 'AGENCY MANAGEMENT',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _acting
                ? null
                : () {
                    final id = _selectedAgency?['agencyId']?.toString();
                    if (id != null) {
                      _openAgency(id);
                    } else {
                      _loadAgencies();
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: inDetail || _loading || user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _acting ? null : () => _appointAgency(user),
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Appoint Agency'),
            ),
      body: _buildBody(user),
    );
  }

  Widget _buildBody(UserModel? user) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: _gold, size: 52),
              const Gap(12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const Gap(16),
              ElevatedButton.icon(
                onPressed: () {
                  final id = _selectedAgency?['agencyId']?.toString();
                  if (id != null) {
                    _openAgency(id);
                  } else {
                    _loadAgencies();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_selectedAgency != null) {
      return _buildDetail();
    }
    return _buildList(user);
  }

  Widget _buildList(UserModel? user) {
    final filtered = _filteredAgencies;
    final totalHosts = _agencies.fold<int>(
      0,
      (sum, a) => sum + ((a['hostCount'] as num?)?.toInt() ?? 0),
    );
    final activeCount = _agencies.where((a) => a['isActive'] != false).length;

    return RefreshIndicator(
      onRefresh: _loadAgencies,
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.business_rounded,
                  color: _accent,
                  label: 'Agencies',
                  value: '${_agencies.length}',
                ),
              ),
              const Gap(10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  label: 'Active',
                  value: '$activeCount',
                ),
              ),
              const Gap(10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.groups_rounded,
                  color: _gold,
                  label: 'Hosts',
                  value: '$totalHosts',
                ),
              ),
            ],
          ),
          const Gap(18),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search agency, owner, Hello ID or code',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.white38),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
              filled: true,
              fillColor: _card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accent),
              ),
            ),
          ),
          const Gap(12),
          Row(
            children: [
              for (final filter in const ['all', 'active', 'suspended']) ...[
                ChoiceChip(
                  label: Text(
                    filter[0].toUpperCase() + filter.substring(1),
                    style: TextStyle(
                      color: _statusFilter == filter
                          ? Colors.white
                          : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selected: _statusFilter == filter,
                  selectedColor: _accent,
                  backgroundColor: _card,
                  side: const BorderSide(color: _border),
                  onSelected: (_) => setState(() => _statusFilter = filter),
                ),
                const Gap(8),
              ],
            ],
          ),
          const Gap(16),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.business_center_outlined,
                      color: _gold, size: 40),
                  const Gap(10),
                  Text(
                    _agencies.isEmpty
                        ? 'No agencies registered yet.'
                        : 'No agency matches this search.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (_agencies.isEmpty && user != null) ...[
                    const Gap(14),
                    ElevatedButton.icon(
                      onPressed: _acting ? null : () => _appointAgency(user),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Appoint First Agency'),
                    ),
                  ],
                ],
              ),
            )
          else
            for (final agency in filtered) ...[
              _AgencyCard(
                agency: agency,
                onTap: () => _openAgency(agency['agencyId'].toString()),
              ),
              const Gap(10),
            ],
        ],
      ),
    );
  }

  Widget _buildDetail() {
    final agency = _selectedAgency!;
    final active = agency['isActive'] != false;


    return RefreshIndicator(
      onRefresh: () => _openAgency(agency['agencyId'].toString()),
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    (agency['logoUrl'] != null && agency['logoUrl'].toString().isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              agency['logoUrl'].toString(),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.business_rounded,
                                    color: _gold, size: 28),
                              ),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.business_rounded,
                                color: _gold, size: 28),
                          ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  agency['name']?.toString() ?? 'Agency',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Gap(8),
                              _StatusBadge(active: active),
                            ],
                          ),
                          const Gap(4),
                          Text(
                            'Owner: ${agency['ownerName'] ?? 'Unknown'}  •  Hello ID: ${agency['ownerHelloId'] ?? 'N/A'}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                          if ((agency['code'] ?? '').toString().isNotEmpty)
                            Text(
                              'Agency Code: #${agency['code']}',
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(14),
                const Divider(color: Colors.white12, height: 1),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: _DetailStat(
                          label: 'Hosts',
                          value: '${agency['hostCount'] ?? _hosts.length}',
                          color: _accent),
                    ),
                    Expanded(
                      child: _DetailStat(
                          label: 'Beans Balance',
                          value: '${agency['beansBalance'] ?? 0}',
                          color: _gold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAgencyReports(agency),
                  icon: const Icon(Icons.analytics_rounded, size: 17),
                  label: const Text('Reports'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _acting ? null : _editAgency,
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _acting ? null : _toggleAgencyStatus,
                  icon: Icon(
                      active
                          ? Icons.pause_circle_rounded
                          : Icons.play_circle_rounded,
                      size: 17),
                  label: Text(active ? 'Suspend' : 'Activate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        active ? Colors.redAccent : Colors.greenAccent,
                    side: BorderSide(
                        color: active
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : Colors.greenAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          ElevatedButton.icon(
            onPressed: _acting ? null : _recruitHost,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Recruit Host'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const Gap(20),
          Row(
            children: [
              const Text(
                'HOST ROSTER',
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1),
              ),
              const Spacer(),
              Text(
                '${_hosts.length}',
                style: const TextStyle(
                    color: _accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Gap(10),
          if (_hosts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: const Text(
                'No hosts are assigned to this agency yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            for (final host in _hosts) ...[
              _HostCard(
                host: host,
                onTap: () => _showHostDetails(host),
                onRemove: _acting ? null : () => _removeHost(host),
              ),
              const Gap(8),
            ],
        ],
      ),
    );
  }

  void _showHostDetails(Map<String, dynamic> host) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                imageUrl: host['profilePhotoUrl']?.toString() ?? '',
                radius: 34,
              ),
              const Gap(12),
              Text(
                host['displayName']?.toString() ?? 'Host',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const Gap(4),
              Text(
                'Hello ID: ${host['helloId'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.white60),
              ),
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DetailStat(
                        label: 'Beans',
                        value: '${host['beansBalance'] ?? 0}',
                        color: _gold,
                      ),
                    ),
                    Expanded(
                      child: _DetailStat(
                        label: 'UID',
                        value: (host['uid'] ?? '')
                            .toString()
                            .split('')
                            .take(10)
                            .join(),
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _removeHost(host);
                  },
                  icon: const Icon(Icons.person_remove_rounded),
                  label: const Text('Release From Agency'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF273244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Gap(8),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
        const Gap(2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF10B981) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const Gap(4),
          Text(
            active ? 'Active' : 'Suspended',
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _AgencyCard extends StatelessWidget {
  const _AgencyCard({required this.agency, required this.onTap});

  final Map<String, dynamic> agency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = agency['isActive'] != false;

    return Material(
      color: const Color(0xFF131A29),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF273244)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  (agency['logoUrl'] != null && agency['logoUrl'].toString().isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            agency['logoUrl'].toString(),
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.business_rounded,
                                  color: Color(0xFFF59E0B), size: 22),
                            ),
                          ),
                        )
                      : Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.business_rounded,
                              color: Color(0xFFF59E0B), size: 22),
                        ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agency['name']?.toString() ?? 'Agency',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Owner: ${agency['ownerName'] ?? 'Unknown'}  •  ID: ${agency['ownerHelloId'] ?? 'N/A'}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  _StatusBadge(active: active),
                ],
              ),
              const Gap(12),
              Row(
                children: [
                  _Pill(
                      icon: Icons.groups_rounded,
                      text: '${agency['hostCount'] ?? 0} hosts'),
                  if ((agency['code'] ?? '').toString().isNotEmpty) ...[
                    const Gap(6),
                    _Pill(
                        icon: Icons.tag_rounded,
                        text: '#${agency['code']}'),
                  ],
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white38, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white54),
          const Gap(3),
          Text(
            text,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({
    required this.host,
    required this.onTap,
    required this.onRemove,
  });

  final Map<String, dynamic> host;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF131A29),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF273244)),
          ),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: host['profilePhotoUrl']?.toString() ?? '',
                radius: 20,
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host['displayName']?.toString() ?? 'Host',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Hello ID: ${host['helloId'] ?? 'N/A'}  •  Beans: ${host['beansBalance'] ?? 0}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.person_remove_rounded,
                    color: Colors.redAccent, size: 18),
                tooltip: 'Release host',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgencyFormDialog extends StatefulWidget {
  const _AgencyFormDialog({
    required this.title,
    required this.submitLabel,
    required this.isPlainAdmin,
    this.initial,
  });

  final String title;
  final String submitLabel;
  final bool isPlainAdmin;
  final Map<String, dynamic>? initial;

  @override
  State<_AgencyFormDialog> createState() => _AgencyFormDialogState();
}

class _AgencyFormDialogState extends State<_AgencyFormDialog> {
  late final TextEditingController _owner;
  late final TextEditingController _admin;
  late final TextEditingController _name;
  late final TextEditingController _country;
  late final TextEditingController _phone;
  late final TextEditingController _description;
  File? _logoFile;
  String? _logoUrl;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _owner = TextEditingController();
    _admin = TextEditingController();
    _name = TextEditingController(text: initial?['name']?.toString() ?? '');
    _logoUrl = initial?['logoUrl']?.toString();
    _country =
        TextEditingController(text: initial?['country']?.toString() ?? '');
    _phone =
        TextEditingController(text: initial?['contactPhone']?.toString() ?? '');
    _description =
        TextEditingController(text: initial?['description']?.toString() ?? '');
  }

  @override
  void dispose() {
    _owner.dispose();
    _admin.dispose();
    _name.dispose();
    _country.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked != null) {
        setState(() {
          _logoFile = File(picked.path);
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Could not access gallery: $e');
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final owner = _owner.text.trim();
    final admin = _admin.text.trim();
    if (widget.initial == null && owner.isEmpty) {
      setState(() => _error = 'Owner Hello ID or UID is required.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Agency name is required.');
      return;
    }
    if (widget.initial == null && !widget.isPlainAdmin && admin.isEmpty) {
      setState(() => _error = 'Bind this agency to an Admin UID or Hello ID.');
      return;
    }
    if (widget.initial == null && _logoFile == null && (_logoUrl == null || _logoUrl!.isEmpty)) {
      setState(() => _error = 'Agency logo or profile photo is required.');
      return;
    }

    setState(() => _uploading = true);
    String? finalLogoUrl = _logoUrl;
    if (_logoFile != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('agencies/logos/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(_logoFile!);
        finalLogoUrl = await storageRef.getDownloadURL();
      } catch (e) {
        setState(() {
          _uploading = false;
          _error = 'Failed to upload agency logo: $e';
        });
        return;
      }
    }

    final data = <String, dynamic>{
      'name': name,
      if (finalLogoUrl != null) 'logoUrl': finalLogoUrl,
      'country': _country.text.trim(),
      'contactPhone': _phone.text.trim(),
      'description': _description.text.trim(),
    };
    if (widget.initial == null) {
      data['ownerIdentifier'] = owner;
      if (!widget.isPlainAdmin) data['adminId'] = admin;
    }
    if (mounted) Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    final appointing = widget.initial == null;
    return AlertDialog(
      backgroundColor: const Color(0xFF131A29),
      title: Text(widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo / Profile Photo Picker
            GestureDetector(
              onTap: _uploading ? null : _pickLogo,
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _logoFile != null || (_logoUrl != null && _logoUrl!.isNotEmpty)
                            ? const Color(0xFF6366F1)
                            : Colors.white24,
                        width: 1.5,
                      ),
                      image: _logoFile != null
                          ? DecorationImage(
                              image: FileImage(_logoFile!),
                              fit: BoxFit.cover,
                            )
                          : (_logoUrl != null && _logoUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_logoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    ),
                    child: _logoFile == null && (_logoUrl == null || _logoUrl!.isEmpty)
                        ? const Icon(Icons.add_a_photo_rounded,
                            color: Colors.white54, size: 28)
                        : null,
                  ),
                  const Gap(6),
                  Text(
                    _logoFile != null
                        ? 'Change Logo'
                        : (_logoUrl != null && _logoUrl!.isNotEmpty
                            ? 'Change Logo'
                            : 'Upload Agency Logo *'),
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(14),
            if (appointing) ...[
              _field(_owner, 'Owner Hello ID or UID', 'e.g. 5621916410'),
              if (!widget.isPlainAdmin) ...[
                const Gap(10),
                _field(_admin, 'Admin Hello ID or UID',
                    'Admin who supervises this agency'),
              ],
              const Gap(10),
            ],
            _field(_name, 'Agency Name', 'e.g. Starlight Talent Group'),
            const Gap(10),
            _field(_country, 'Country', 'e.g. India'),
            const Gap(10),
            _field(_phone, 'Contact Phone', 'e.g. +91 9876543210'),
            const Gap(10),
            _field(_description, 'Description', 'Operational notes',
                maxLines: 2),
            if (_error != null) ...[
              const Gap(10),
              Text(_error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _uploading ? null : _submit,
          child: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF273244)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF273244)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6366F1)),
        ),
      ),
    );
  }
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.submitLabel,
  });

  final String title;
  final String label;
  final String hint;
  final String submitLabel;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'This field is required.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF131A29),
      title: Text(widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              hintText: widget.hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF273244)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF273244)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
            ),
          ),
          if (_error != null) ...[
            const Gap(8),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}


class _AgencyReportsSheet extends StatefulWidget {
  const _AgencyReportsSheet({
    required this.agencyId,
    required this.agencyName,
    required this.call,
  });

  final String agencyId;
  final String agencyName;
  final Future<dynamic> Function(String, [Map<String, dynamic>?]) call;

  @override
  State<_AgencyReportsSheet> createState() => _AgencyReportsSheetState();
}

class _AgencyReportsSheetState extends State<_AgencyReportsSheet> {
  int _tab = 0; // 0: Daily, 1: Time, 2: Total, 3: Host-Wise, 4: Beans, 5: Monthly
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  late String _selectedDay;
  late String _reportMonth;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().toIso8601String().substring(0, 10);
    _reportMonth = DateTime.now().toIso8601String().substring(0, 7);
    _load();
  }

  Future<void> _load([String? month]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final targetMonth = month ?? _reportMonth;
    try {
      final res = await widget.call('getAgencyRechargeStats', {
        'agencyId': widget.agencyId,
        'yearMonth': targetMonth,
      });
      if (mounted) {
        setState(() {
          _data = Map<String, dynamic>.from(res as Map);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      'Daily',
      'Time-Based',
      'Total Agency',
      'Host-Wise',
      'Total Beans',
      'Monthly'
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF273244))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.agencyName} - Reports',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                      const Text(
                        '6 Comprehensive Agency Reports',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (int i = 0; i < tabs.length; i++) ...[
                  ChoiceChip(
                    label: Text(tabs[i],
                        style: TextStyle(
                            color: _tab == i ? Colors.white : Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    selected: _tab == i,
                    selectedColor: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFF131A29),
                    side: const BorderSide(color: Color(0xFF273244)),
                    onSelected: (_) => setState(() => _tab = i),
                  ),
                  const Gap(6),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 12)),
                            const Gap(8),
                            ElevatedButton(
                              onPressed: () => _load(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final hosts = (_data?['hostBreakdown'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final records = (_data?['recentRecords'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final totalUSD = (_data?['combinedTotalRechargeUSD'] as num?)?.toDouble() ?? 0.0;
    final history = (_data?['monthlyHistory'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (_tab == 0) {
      // Daily Report
      final dailyRecs = records.where((r) => r['day'] == _selectedDay).toList();
      final dailyUSD = dailyRecs.fold<double>(
          0.0, (sum, r) => sum + ((r['usdAmount'] as num?)?.toDouble() ?? 0.0));
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Day: $_selectedDay',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() =>
                    _selectedDay = DateTime.now().toIso8601String().substring(0, 10)),
                child: const Text('Today'),
              ),
            ],
          ),
          const Gap(10),
          _statCard('Total Daily Recharge', '\$${dailyUSD.toStringAsFixed(2)}', const Color(0xFF10B981)),
          const Gap(8),
          _statCard('30% Agency Commission', '\$${(dailyUSD * 0.3).toStringAsFixed(2)}', const Color(0xFF6366F1)),
          const Gap(16),
          const Text('Transactions Today:',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
          const Gap(8),
          if (dailyRecs.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No recharges on this day', style: TextStyle(color: Colors.white38))))
          else
            for (final r in dailyRecs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r['hostName']?.toString() ?? 'Host', style: const TextStyle(color: Colors.white)),
                subtitle: Text('ID: ${r['hostHelloId']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                trailing: Text('\$${(r['usdAmount'] as num?)?.toDouble().toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ),
        ],
      );
    } else if (_tab == 1) {
      // Time-Based
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Time-Based Recharge Log (Recent 50 transactions)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Gap(12),
          for (final r in records)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r['hostName']?.toString() ?? 'Host', style: const TextStyle(color: Colors.white)),
              subtitle: Text('${r['day']}  •  ID: ${r['hostHelloId']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: Text('\$${(r['usdAmount'] as num?)?.toDouble().toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
        ],
      );
    } else if (_tab == 2) {
      // Total Agency
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard('Combined Total Recharge', '\$${totalUSD.toStringAsFixed(2)}', const Color(0xFF10B981)),
          const Gap(8),
          _statCard('Agency 30% Commission', '\$${(totalUSD * 0.3).toStringAsFixed(2)}', const Color(0xFF6366F1)),
          const Gap(8),
          _statCard('Total Hosts', '${hosts.length}', Colors.amber),
        ],
      );
    } else if (_tab == 3) {
      // Host-Wise
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final h in hosts)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131A29),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h['name']?.toString() ?? 'Host', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('ID: ${h['helloId']}  •  Mic: ${h['micHours']}h', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${(h['rechargeUSD'] as num?)?.toDouble().toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      Text('${h['beansEarned']} beans', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    } else if (_tab == 4) {
      // Total Beans
      final totalBeans = hosts.fold<int>(0, (sum, h) => sum + ((h['beansEarned'] as num?)?.toInt() ?? 0));
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard('Hosts Combined Beans', '$totalBeans', Colors.amber),
          const Gap(8),
          _statCard('Valuation (\$)', '\$${(totalBeans / 100).toStringAsFixed(2)}', const Color(0xFF10B981)),
        ],
      );
    } else {
      // Monthly
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final m in history)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131A29),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(m['yearMonth']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${(m['totalRechargeUSD'] as num?)?.toDouble().toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      Text('Commission: \$${((m['totalCommissionUSD'] ?? ((m['totalRechargeUSD'] as num?)?.toDouble() ?? 0) * 0.3) as num).toDouble().toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF273244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
          const Gap(4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
