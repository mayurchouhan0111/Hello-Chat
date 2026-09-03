import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/models/family_battle_model.dart';
import 'package:hello_chat/core/models/family_battle_request_model.dart';
import 'package:hello_chat/core/models/family_member_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/services/cloudinary_service.dart';
import 'package:hello_chat/core/constants/family_light_theme.dart';
import 'package:hello_chat/providers/wallet_provider.dart';

class FamilyBattleScreen extends ConsumerStatefulWidget {
  final String myFamilyId;
  const FamilyBattleScreen({super.key, required this.myFamilyId});

  @override
  ConsumerState<FamilyBattleScreen> createState() => _FamilyBattleScreenState();
}

class _FamilyBattleScreenState extends ConsumerState<FamilyBattleScreen>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  var _lastTap = DateTime(2000);
  int _comboCount = 0;
  Timer? _comboTimer;
  String? _resultShownForBattle;
  bool _isEnding = false;
  Timer? _autoPopTimer;
  bool _autoResultPending = false;
  Timer? _tickTimer;
  final _picker = ImagePicker();
  File? _battleImage;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _comboTimer?.cancel();
    _autoPopTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(familyStreamProvider(widget.myFamilyId));
    final activeBattleAsync = ref.watch(activeBattleProvider(widget.myFamilyId));

    return Scaffold(
      backgroundColor: FamilyLight.pageBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CLAN ARENA',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 3,
                color: FamilyLight.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: FamilyLight.card.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: FamilyLight.border),
            ),
            child: const Icon(Icons.close_rounded,
                color: FamilyLight.ink, size: 18),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildBackground(),
          familyAsync.when(
            data: (family) {
              if (family == null) {
                return const Center(
                    child: Text("Family not found",
                        style:
                            TextStyle(color: FamilyLight.muted)));
              }
              return activeBattleAsync.when(
                data: (battle) {
                  if (battle != null && battle.isActive) {
                    return _buildActiveBattle(battle, family);
                  }
                  return _buildTabs(family);
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: FamilyLight.gold)),
                error: (_, __) => _buildTabs(family),
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: FamilyLight.gold)),
            error: (_, __) => const Center(
                child: Text("Could not load family",
                    style:
                        TextStyle(color: FamilyLight.muted))),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(color: FamilyLight.pageBg),
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  FamilyLight.gold.withOpacity(0.08),
                  FamilyLight.gold.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  FamilyLight.red.withOpacity(0.06),
                  FamilyLight.red.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Tabs ──────────────────────────────────────────────────────
  Widget _buildTabs(FamilyModel family) {
    return SafeArea(
      child: Column(
        children: [
          const Gap(8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: FamilyLight.card.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FamilyLight.border),
            ),
            child: Row(
              children: [
                _buildTab('CHALLENGE', 0, Icons.sports_kabaddi_outlined),
                _buildTab('HISTORY', 1, Icons.history_rounded),
                _buildTab('RANKINGS', 2, Icons.leaderboard_rounded),
              ],
            ),
          ),
          const Gap(8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _tabIndex == 0
                  ? _buildLobby(family)
                  : _tabIndex == 1
                      ? _buildHistoryTab(family)
                      : _buildRankingsTab(family),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? FamilyLight.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: FamilyLight.gold.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.black : FamilyLight.muted,
              ),
              const Gap(6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color:
                      selected ? Colors.black : FamilyLight.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Lobby ─────────────────────────────────────────────────────
  Widget _buildLobby(FamilyModel myFamily) {
    final allFamiliesAsync = ref.watch(allFamiliesProvider);
    final sentRequestsAsync = ref.watch(sentBattleRequestsProvider(widget.myFamilyId));

    return allFamiliesAsync.when(
      data: (allFamilies) {
        final opponents =
            allFamilies.where((f) => f.id != widget.myFamilyId).toList();
        return sentRequestsAsync.when(
          data: (sent) {
            final active = sent.where((r) => r.isPending).toList();
            final recent = sent.where((r) => !r.isPending).take(5).toList();
            return _buildLobbyContent(myFamily, opponents, active, recent);
          },
          loading: () => _buildLobbyGrid(myFamily, opponents),
          error: (_, __) => _buildLobbyGrid(myFamily, opponents),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: FamilyLight.gold)),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            err.toString().length > 80
                ? 'Could not load clans.\nTry again later.'
                : err.toString(),
            style: const TextStyle(color: FamilyLight.muted),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyContent(FamilyModel myFamily, List<FamilyModel> opponents,
      List<FamilyBattleRequestModel> active,
      List<FamilyBattleRequestModel> recent) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        GestureDetector(
          onTap: _pickBattleImage,
          child: Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: FamilyLight.fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FamilyLight.gold.withOpacity(0.3)),
              image: _battleImage != null
                  ? DecorationImage(image: FileImage(_battleImage!), fit: BoxFit.cover)
                  : null,
            ),
            child: _battleImage == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: FamilyLight.gold, size: 36),
                      Gap(6),
                      Text('Tap to select battle image', style: TextStyle(color: FamilyLight.muted, fontSize: 12)),
                      Gap(2),
                      Text('', style: TextStyle(color: FamilyLight.gold, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _battleImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (active.isNotEmpty) ...[
          _buildSectionHeader('PENDING CHALLENGES', active.length),
          const Gap(8),
          ...active.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildSentRequestCard(r),
              )),
          const Gap(16),
        ],
        if (recent.isNotEmpty) ...[
          _buildSectionHeader('RECENT RESULTS', null),
          const Gap(8),
          ...recent.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildSentRequestCard(r),
              )),
          const Gap(16),
        ],
        _buildSectionHeader('SELECT OPPONENT', opponents.length),
        const Gap(12),
        ...opponents.map((enemy) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildEnemyCard(
                  enemy,
                  myFamily.totalCombatPoints ?? 0,
                  enemy.totalCombatPoints ?? 0),
            )),
      ],
    );
  }

  Widget _buildSectionHeader(String label, int? count) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: FamilyLight.gold,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: FamilyLight.gold.withOpacity(0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const Gap(8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: FamilyLight.muted,
            letterSpacing: 1,
          ),
        ),
        if (count != null) ...[
          const Gap(6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: FamilyLight.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 10,
                color: FamilyLight.gold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSentRequestCard(FamilyBattleRequestModel req) {
    final isPending = req.isPending;
    final isAccepted = req.status == 'accepted';
    final isRejected = req.status == 'rejected';
    final color = isPending
        ? FamilyLight.gold
        : isAccepted
            ? FamilyLight.green
            : FamilyLight.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FamilyLight.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: req.opponentAvatar != null
                  ? CachedNetworkImage(
                      imageUrl: req.opponentAvatar!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover)
                  : Container(
                      color: FamilyLight.fill,
                      child: Icon(Icons.shield,
                          color: color.withOpacity(0.5), size: 20)),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.opponentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: FamilyLight.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const Gap(3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    const Gap(5),
                    Text(
                      isPending
                          ? 'Awaiting response'
                          : isAccepted
                              ? 'Challenge accepted'
                              : 'Declined',
                      style: TextStyle(
                          fontSize: 11, color: color.withOpacity(0.9)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text(
              isPending
                  ? 'PENDING'
                  : isAccepted
                      ? 'ACCEPTED'
                      : 'REJECTED',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 9,
                letterSpacing: 0.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyGrid(FamilyModel myFamily, List<FamilyModel> opponents) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        GestureDetector(
          onTap: _pickBattleImage,
          child: Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: FamilyLight.fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FamilyLight.gold.withOpacity(0.3)),
              image: _battleImage != null
                  ? DecorationImage(image: FileImage(_battleImage!), fit: BoxFit.cover)
                  : null,
            ),
            child: _battleImage == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: FamilyLight.gold, size: 36),
                      Gap(6),
                      Text('Tap to select battle image', style: TextStyle(color: FamilyLight.muted, fontSize: 12)),
                      Gap(2),
                      Text('', style: TextStyle(color: FamilyLight.gold, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _battleImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        _buildSectionHeader('SELECT OPPONENT', opponents.length),
        const Gap(12),
        ...opponents.map((enemy) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildEnemyCard(
                  enemy,
                  myFamily.totalCombatPoints ?? 0,
                  enemy.totalCombatPoints ?? 0),
            )),
      ],
    );
  }

  Widget _buildEnemyCard(FamilyModel enemy, int myPts, int enemyPts) {
    final isStronger = enemyPts > myPts;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FamilyLight.border),
        boxShadow: [
          BoxShadow(
            color: FamilyLight.gold.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Container(
          color: FamilyLight.card.withOpacity(0.6),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: FamilyLight.gold.withOpacity(0.15)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: enemy.avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: enemy.avatarUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover)
                      : Container(
                          color: FamilyLight.fill,
                          child: const Icon(Icons.shield,
                              color: FamilyLight.gold, size: 24)),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(enemy.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: FamilyLight.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const Gap(3),
                    Row(
                      children: [
                        _buildStatChip(
                            Icons.people_rounded,
                            '${enemy.memberCount ?? 0}',
                            FamilyLight.muted),
                        const Gap(8),
                        _buildStatChip(Icons.shield_rounded,
                            enemy.rankName ?? 'Unranked', FamilyLight.faint),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(enemyPts / 1000).toStringAsFixed(1)}k',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isStronger
                          ? FamilyLight.red
                          : FamilyLight.muted,
                    ),
                  ),
                  const Text('CP',
                      style: TextStyle(
                          fontSize: 9,
                          color: FamilyLight.muted)),
                  const Gap(6),
                  GestureDetector(
                    onTap: () => _sendChallenge(enemy.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FamilyLight.gold,
                            FamilyLight.gold.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: FamilyLight.gold.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text('FIGHT',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              color: Colors.black,
                              letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const Gap(3),
        Text(label,
            style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }

  Future<void> _pickBattleImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      setState(() => _battleImage = File(picked.path));
    }
  }

  static const int _battleDiamondCost = 500000;
  Future<void> _sendChallenge(String opponentId) async {
    if (_battleImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a battle image first!'),
            backgroundColor: FamilyLight.red.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }


    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;
    if (user.diamondBalance < _battleDiamondCost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Insufficient diamonds to launch a battle.'),
            backgroundColor: FamilyLight.red.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    String? imageUrl;
    try {
      imageUrl = await ref.read(cloudinaryServiceProvider).uploadImage(_battleImage!.path, folder: 'battle_covers');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to upload image. Try again.'),
            backgroundColor: FamilyLight.red.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    try {
       await ref.read(familyServiceProvider).sendBattleRequest(
             challengerFamilyId: widget.myFamilyId,
             opponentFamilyId: opponentId,
             challengerImageUrl: imageUrl,
             challengerUid: user.uid,
             cost: _battleDiamondCost,
           );
      setState(() => _battleImage = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Challenge sent!'),
            backgroundColor: FamilyLight.gold.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().length > 100 ? 'Failed to send challenge.' : e.toString()),
            backgroundColor: FamilyLight.red.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
    }

    // Purchase battle access using diamonds
    Future<void> _buyAccess() async {
      final user = ref.read(currentUserProfileProvider).value;
      if (user == null) return;
      try {
        await ref.read(familyServiceProvider).purchaseBattleAccess(
          uid: user.uid,
          cost: _battleDiamondCost,
        );
        if (mounted) {
          setState(() => _hasAccess = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Battle access purchased!'),
              backgroundColor: FamilyLight.gold.withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: FamilyLight.red.withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    // ─── History Tab ──────────────────────────────────────────────
  Widget _buildHistoryTab(FamilyModel myFamily) {
    final historyAsync = ref.watch(battleHistoryProvider(widget.myFamilyId));

    return historyAsync.when(
      data: (battles) {
        if (battles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FamilyLight.card.withOpacity(0.5),
                      border: Border.all(color: FamilyLight.border),
                    ),
                    child: Icon(Icons.sports_kabaddi_rounded,
                        size: 40,
                        color: FamilyLight.muted
                            .withOpacity(0.4)),
                  ),
                  const Gap(16),
                  const Text('No battles yet',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: FamilyLight.muted)),
                  const Gap(6),
                  const Text('Challenge another clan to start your legacy',
                      style: TextStyle(
                          fontSize: 12,
                          color: FamilyLight.muted)),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: battles.length,
          itemBuilder: (_, i) => _buildHistoryCard(battles[i], myFamily),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: FamilyLight.gold)),
      error: (_, __) => const Center(
          child: Text('Could not load history',
              style: TextStyle(color: FamilyLight.muted))),
    );
  }

  // ─── Rankings Tab ──────────────────────────────────────────────
  Widget _buildRankingsTab(FamilyModel myFamily) {
    final familiesAsync = ref.watch(allFamiliesProvider);

    return familiesAsync.when(
      data: (families) {
        final sorted = List<FamilyModel>.from(families);
        sorted.sort((a, b) => b.totalCombatPoints.compareTo(a.totalCombatPoints));

        if (sorted.isEmpty) {
          return const Center(
            child: Text('No rankings yet',
                style: TextStyle(color: FamilyLight.muted)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: sorted.length,
          itemBuilder: (_, i) => _buildRankingRow(sorted[i], i, myFamily),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: FamilyLight.gold)),
      error: (_, __) => const Center(
          child: Text('Could not load rankings',
              style: TextStyle(color: FamilyLight.muted))),
    );
  }

  Widget _buildRankingRow(FamilyModel family, int index, FamilyModel myFamily) {
    final rank = index + 1;
    final isMe = family.id == myFamily.id;
    final badgeColor = FamilyModel.badgeColorForLevel(family.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? FamilyLight.gold.withOpacity(0.1)
            : FamilyLight.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? FamilyLight.gold.withOpacity(0.3) : FamilyLight.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: rank <= 3 ? FamilyLight.gold : FamilyLight.muted,
              ),
            ),
          ),
          const Gap(10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeColor.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: family.avatarUrl != null
                  ? CachedNetworkImage(imageUrl: family.avatarUrl!, fit: BoxFit.cover)
                  : Container(
                      color: FamilyLight.fill,
                      child: const Icon(Icons.shield, color: FamilyLight.gold, size: 18),
                    ),
            ),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: FamilyLight.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  'Lvl ${family.level}',
                  style: TextStyle(fontSize: 10, color: badgeColor),
                ),
              ],
            ),
          ),
          Text(
            '${family.totalCombatPoints}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: FamilyLight.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(FamilyBattleModel battle, FamilyModel myFamily) {
    final isA = battle.familyAId == widget.myFamilyId;
    final myPts = isA ? battle.familyAPoints : battle.familyBPoints;
    final enemyPts = isA ? battle.familyBPoints : battle.familyAPoints;
    final isWinner = battle.winnerId == widget.myFamilyId;
    final isDraw = battle.winnerId == null;
    final enemyName =
        isA ? (battle.familyBName ?? 'Unknown') : (battle.familyAName ?? 'Unknown');
    final enemyAvatar = isA ? battle.familyBAvatar : battle.familyAAvatar;
    final ago = _timeAgo(battle.startedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showBattleResult(battle, myFamily),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FamilyLight.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Container(
              color: FamilyLight.card.withOpacity(0.6),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isWinner
                              ? FamilyLight.gold.withOpacity(0.3)
                              : isDraw
                                  ? FamilyLight.border
                                  : FamilyLight.red.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: enemyAvatar != null
                          ? CachedNetworkImage(
                              imageUrl: enemyAvatar,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover)
                          : Container(
                              color: FamilyLight.fill,
                              child: Icon(Icons.shield,
                                  color: isWinner
                                      ? FamilyLight.gold
                                      : FamilyLight.red,
                                  size: 20)),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(enemyName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: FamilyLight.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const Gap(2),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 10,
                                color: FamilyLight.muted),
                            const Gap(4),
                            Text(ago,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: FamilyLight.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$myPts',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: FamilyLight.gold)),
                          Text('$enemyPts',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: FamilyLight.red)),
                        ],
                      ),
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWinner
                              ? FamilyLight.gold.withOpacity(0.15)
                              : isDraw
                                  ? FamilyLight.border
                                  : FamilyLight.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isWinner
                                ? FamilyLight.gold.withOpacity(0.3)
                                : isDraw
                                    ? FamilyLight.border
                                    : FamilyLight.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isWinner
                                  ? Icons.emoji_events_rounded
                                  : isDraw
                                      ? Icons.remove_rounded
                                      : Icons.close_rounded,
                              size: 10,
                              color: isWinner
                                  ? FamilyLight.gold
                                  : isDraw
                                      ? FamilyLight.muted
                                      : FamilyLight.red,
                            ),
                            const Gap(3),
                            Text(
                              isWinner
                                  ? 'WIN'
                                  : isDraw
                                      ? 'DRAW'
                                      : 'LOSS',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.5,
                                color: isWinner
                                    ? FamilyLight.gold
                                    : isDraw
                                        ? FamilyLight.muted
                                        : FamilyLight.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(4),
                      Icon(Icons.chevron_right_rounded,
                          color: FamilyLight.muted
                              .withOpacity(0.4),
                          size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBattleResult(FamilyBattleModel battle, FamilyModel myFamily) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BattleResultSheet(
          battle: battle,
          myFamilyId: widget.myFamilyId,
          myFamily: myFamily),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  // ─── Active Battle ────────────────────────────────────────────
  Widget _buildActiveBattle(FamilyBattleModel battle, FamilyModel myFamily) {
    if (!battle.isCompleted && _tickTimer == null) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    final isA = battle.familyAId == widget.myFamilyId;
    final myPts = isA ? battle.familyAPoints : battle.familyBPoints;
    final enemyPts = isA ? battle.familyBPoints : battle.familyAPoints;
    final total = (myPts + enemyPts).toDouble();
    final myRatio = total == 0 ? 0.5 : myPts / total;

    final battleMembersAsync =
        ref.watch(familyMembersProvider(widget.myFamilyId));

    return battleMembersAsync.when(
      data: (members) {
        final sorted = List<FamilyMemberModel>.from(members)
          ..sort((a, b) => b.combatPoints.compareTo(a.combatPoints));
        return _buildBattleContent(
            battle, myFamily, myPts, enemyPts, myRatio, sorted);
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: FamilyLight.gold)),
      error: (_, __) => _buildBattleContent(
          battle, myFamily, myPts, enemyPts, myRatio, []),
    );
  }

  Widget _buildBattleContent(
      FamilyBattleModel battle,
      FamilyModel myFamily,
      int myPts,
      int enemyPts,
      double myRatio,
      List<FamilyMemberModel> members) {
    final isCompleted = battle.isCompleted;
    final isWinner = battle.winnerId == widget.myFamilyId;
    final isDraw = battle.isCompleted && battle.winnerId == null;
    final isA = battle.familyAId == widget.myFamilyId;
    final enemyPtsTotal =
        isA ? battle.familyBPoints : battle.familyAPoints;
    final enemyName = isA
        ? (battle.familyBName ?? 'Unknown')
        : (battle.familyAName ?? 'Unknown');
    final showBackBtn = isCompleted || battle.isExpired;

    if (showBackBtn && _tickTimer != null) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }

    // Auto-end when timer expires
    if (battle.isExpired && !isCompleted && !_isEnding) {
      _isEnding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoEndBattle(battle);
      });
    }

    // Auto-show result sheet when completed
    if (isCompleted && _resultShownForBattle != battle.id) {
      _resultShownForBattle = battle.id;
      _autoResultPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _autoResultPending) {
          _autoResultPending = false;
          _showAutoResult(battle, myFamily);
        }
      });
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Roster Gatekeeper & Level Viewport
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: FamilyLight.card.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FamilyModel.badgeColorForLevel(myFamily.level).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: FamilyModel.themeGradientForLevel(myFamily.level)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LEVEL ${myFamily.level}',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                      ),
                      const Gap(8),
                      Text(
                        'Participants: ${myFamily.memberCount} / ${myFamily.memberLimit}',
                        style: const TextStyle(color: FamilyLight.ink, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                  Text(
                    'Remaining Slots: ${(myFamily.memberLimit - myFamily.memberCount).clamp(0, 1000)}',
                    style: TextStyle(color: FamilyModel.badgeColorForLevel(myFamily.level), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Timer or Result Banner
            _buildTimerBanner(
                battle, isCompleted, isWinner, isDraw),
            const Gap(16),

            // Score Cards
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                      child: _buildScoreCard(
                          myFamily.name,
                          myFamily.avatarUrl,
                          myPts,
                          FamilyModel.badgeColorForLevel(myFamily.level),
                          true)),
                  _buildVSColumn(myPts, enemyPtsTotal, showBackBtn),
                  Expanded(
                      child: _buildScoreCard(
                          enemyName,
                          isA ? battle.familyBAvatar : battle.familyAAvatar,
                          enemyPtsTotal,
                          FamilyLight.red,
                          false)),
                ],
              ),
            ),
            const Gap(16),

            // Progress Bar
            _buildGlowProgressBar(myRatio),
            const Gap(24),

            // Top Recruits / Contributor Leaderboard
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FamilyLight.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Container(
                    color: FamilyLight.card.withOpacity(0.5),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(
                                color: FamilyModel.badgeColorForLevel(myFamily.level),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const Gap(8),
                            const Text('MVP TOP CONTRIBUTORS',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: FamilyLight.ink,
                                    letterSpacing: 1)),
                          ],
                        ),
                        const Gap(12),
                        Expanded(
                          child: members.isEmpty
                              ? const Center(
                                  child: Text('No members',
                                      style: TextStyle(
                                          color: FamilyLight.muted)))
                              : ListView.separated(
                                  itemCount: members.length > 5
                                      ? 5
                                      : members.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (_, i) =>
                                      _buildMemberRow(
                                          members[i], i + 1),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Action
            if (!showBackBtn) ...[
              const Gap(12),
              _buildTapZone(battle),
            ],
            if (showBackBtn) ...[
              const Gap(12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FamilyLight.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    shadowColor: FamilyLight.gold.withOpacity(0.4),
                  ),
                  child: const Text('BACK TO ARENA',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 2)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _autoEndBattle(FamilyBattleModel battle) {
    final oppId = battle.familyAId == widget.myFamilyId
        ? battle.familyBId
        : battle.familyAId;
    ref.read(familyServiceProvider).endBattle(battle.id, widget.myFamilyId, oppId);
  }

  void _showAutoResult(FamilyBattleModel battle, FamilyModel myFamily) {
    _autoPopTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BattleResultSheet(
          battle: battle,
          myFamilyId: widget.myFamilyId,
          myFamily: myFamily),
    );
    _autoPopTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Widget _buildTimerBanner(
      FamilyBattleModel battle, bool isCompleted, bool isWinner, bool isDraw) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? (isWinner
                  ? FamilyLight.gold.withOpacity(0.4)
                  : isDraw
                      ? FamilyLight.border
                      : FamilyLight.red.withOpacity(0.4))
              : FamilyLight.gold.withOpacity(0.2),
        ),
        gradient: LinearGradient(
          colors: isCompleted
              ? (isWinner
                  ? [
                      FamilyLight.gold.withOpacity(0.1),
                      FamilyLight.card.withOpacity(0.5)
                    ]
                  : isDraw
                      ? [
                          FamilyLight.border,
                          FamilyLight.card.withOpacity(0.5)
                        ]
                      : [
                          FamilyLight.red.withOpacity(0.1),
                          FamilyLight.card.withOpacity(0.5)
                        ])
              : [
                  FamilyLight.gold.withOpacity(0.05),
                  FamilyLight.card.withOpacity(0.5)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCompleted
                ? (isWinner
                    ? Icons.emoji_events_rounded
                    : isDraw
                        ? Icons.remove_rounded
                        : Icons.sentiment_dissatisfied_rounded)
                : Icons.timer_rounded,
            size: 22,
            color: isCompleted
                ? (isWinner
                    ? FamilyLight.gold
                    : isDraw
                        ? FamilyLight.muted
                        : FamilyLight.red)
                : FamilyLight.gold,
          ),
          const Gap(10),
          Text(
            isCompleted
                ? (isWinner
                    ? 'VICTORY!'
                    : isDraw
                        ? 'DRAW'
                        : 'DEFEAT')
                : _formatTime(battle.remainingSeconds),
            style: TextStyle(
              color: isCompleted
                  ? (isWinner
                      ? FamilyLight.gold
                      : isDraw
                          ? FamilyLight.muted
                          : FamilyLight.red)
                  : FamilyLight.gold,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(
      String name, String? avatar, int pts, Color color, bool isLeft) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            FamilyLight.card.withOpacity(0.3),
          ],
          begin: isLeft ? Alignment.topLeft : Alignment.topRight,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: avatar != null
                  ? CachedNetworkImage(
                      imageUrl: avatar, fit: BoxFit.cover)
                  : Container(
                      color: FamilyLight.fill,
                      child: Icon(
                          isLeft
                              ? Icons.shield_rounded
                              : Icons.security_rounded,
                          color: color,
                          size: 22)),
            ),
          ),
          const Gap(6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: FamilyLight.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const Gap(2),
          Text(
            '${(pts / 1000).toStringAsFixed(1)}k',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              shadows: [
                Shadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVSColumn(int myPts, int enemyPts, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$myPts',
            style: TextStyle(
              color: FamilyLight.gold,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              shadows: [
                Shadow(
                  color: FamilyLight.gold.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FamilyLight.border,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('VS',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: FamilyLight.border)),
          ),
          Text(
            '$enemyPts',
            style: TextStyle(
              color: FamilyLight.red,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              shadows: [
                Shadow(
                  color: FamilyLight.red.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowProgressBar(double ratio) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FamilyLight.gold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: FamilyLight.gold.withOpacity(0.1),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Container(color: FamilyLight.card),
            LayoutBuilder(
              builder: (_, constraints) => Row(
                children: [
                  Expanded(
                    flex: (ratio * 100).toInt().clamp(1, 99),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FamilyLight.gold.withOpacity(0.8),
                            FamilyLight.gold,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - ratio) * 100).toInt().clamp(1, 99),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FamilyLight.red,
                            FamilyLight.red.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tap Zone ──────────────────────────────────────────────────
  Widget _buildTapZone(FamilyBattleModel battle) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _handleTap(battle),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: FamilyLight.gold.withOpacity(0.3)),
                gradient: LinearGradient(
                  colors: [
                    FamilyLight.gold.withOpacity(0.12),
                    FamilyLight.red.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: FamilyLight.gold.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded,
                        size: 30, color: FamilyLight.gold),
                    const Gap(10),
                    const Text('TAP TO ATTACK',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: FamilyLight.ink,
                            letterSpacing: 3)),
                    if (_comboCount > 1) ...[
                      const Gap(12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: FamilyLight.gold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('x$_comboCount',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: FamilyLight.gold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(FamilyBattleModel battle) {
    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds < 300) return;
    _lastTap = now;

    _comboCount++;
    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _comboCount = 0);
    });
    if (mounted) setState(() {});

    final oppId = battle.familyAId == widget.myFamilyId
        ? battle.familyBId
        : battle.familyAId;
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    if (uid.isEmpty) return;
    ref
        .read(familyServiceProvider)
        .scoreBattleTap(battle.id, widget.myFamilyId, oppId, uid);
  }

  Widget _buildMemberRow(FamilyMemberModel m, int rank) {
    final isTop3 = rank <= 3;
    final userAsync = ref.watch(cachedUserProfileProvider(m.userId));
    final displayName = userAsync.valueOrNull?.displayName ?? m.userId;
    final photoUrl = userAsync.valueOrNull?.profilePhotoUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isTop3
            ? FamilyLight.gold.withOpacity(0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isTop3
                  ? FamilyLight.gold.withOpacity(0.15)
                  : FamilyLight.border,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: isTop3
                          ? FamilyLight.gold
                          : FamilyLight.muted)),
            ),
          ),
          const Gap(10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isTop3
                      ? FamilyLight.gold.withOpacity(0.3)
                      : FamilyLight.border),
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildUserInitial(m.userId, isTop3),
                    )
                  : _buildUserInitial(m.userId, isTop3),
            ),
          ),
          const Gap(10),
          Expanded(
            child: Text(displayName,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: isTop3
                        ? FamilyLight.ink
                        : FamilyLight.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FamilyLight.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${m.combatPoints}',
                style: const TextStyle(
                    color: FamilyLight.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInitial(String userId, bool isTop3) {
    return Container(
      color: FamilyLight.fill,
      child: Center(
        child: Text(
          userId.isNotEmpty ? userId[0].toUpperCase() : '?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: isTop3
                ? FamilyLight.gold
                : FamilyLight.muted,
          ),
        ),
      ),
    );
  }

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Battle Result Bottom Sheet ──────────────────────────────────
class _BattleResultSheet extends ConsumerWidget {
  final FamilyBattleModel battle;
  final String myFamilyId;
  final FamilyModel myFamily;

  const _BattleResultSheet({
    required this.battle,
    required this.myFamilyId,
    required this.myFamily,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isA = battle.familyAId == myFamilyId;
    final myPts = isA ? battle.familyAPoints : battle.familyBPoints;
    final enemyPts = isA ? battle.familyBPoints : battle.familyAPoints;
    final isWinner = battle.winnerId == myFamilyId;
    final isDraw = battle.winnerId == null;
    final total = (myPts + enemyPts).toDouble();
    final myRatio = total == 0 ? 0.5 : myPts / total;
    final enemyName =
        isA ? (battle.familyBName ?? 'Unknown') : (battle.familyAName ?? 'Unknown');
    final enemyAvatar = isA ? battle.familyBAvatar : battle.familyAAvatar;

    return Container(
      decoration: BoxDecoration(
        color: FamilyLight.pageBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: FamilyLight.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Gap(24),

          // Result Icon + Title
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isWinner
                    ? FamilyLight.gold.withOpacity(0.3)
                    : isDraw
                        ? FamilyLight.border
                        : FamilyLight.red.withOpacity(0.3),
              ),
              gradient: LinearGradient(
                colors: [
                  isWinner
                      ? FamilyLight.gold.withOpacity(0.08)
                      : isDraw
                          ? FamilyLight.border
                          : FamilyLight.red.withOpacity(0.08),
                  FamilyLight.card.withOpacity(0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isWinner
                        ? FamilyLight.gold.withOpacity(0.15)
                        : isDraw
                            ? FamilyLight.border
                            : FamilyLight.red.withOpacity(0.15),
                    border: Border.all(
                      color: isWinner
                          ? FamilyLight.gold.withOpacity(0.3)
                          : isDraw
                              ? FamilyLight.border
                              : FamilyLight.red.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    isWinner
                        ? Icons.emoji_events_rounded
                        : isDraw
                            ? Icons.remove_rounded
                            : Icons.sentiment_dissatisfied_rounded,
                    color: isWinner
                        ? FamilyLight.gold
                        : isDraw
                            ? FamilyLight.muted
                            : FamilyLight.red,
                    size: 36,
                  ),
                ),
                const Gap(10),
                Text(
                  isWinner
                      ? 'VICTORY'
                      : isDraw
                          ? 'DRAW'
                          : 'DEFEAT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 6,
                    color: isWinner
                        ? FamilyLight.gold
                        : isDraw
                            ? FamilyLight.muted
                            : FamilyLight.red,
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),

          // Combatants
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 140,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: FamilyLight.gold.withOpacity(0.2)),
                        gradient: LinearGradient(
                          colors: [
                            FamilyLight.gold.withOpacity(0.06),
                            FamilyLight.card.withOpacity(0.5),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: FamilyLight.gold
                                      .withOpacity(0.4),
                                  width: 2),
                            ),
                            child: ClipOval(
                              child: myFamily.avatarUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: myFamily.avatarUrl!,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: FamilyLight.fill,
                                      child: const Icon(Icons.shield,
                                          color: FamilyLight.gold,
                                          size: 24)),
                            ),
                          ),
                          const Gap(6),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(myFamily.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    color: FamilyLight.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const Gap(2),
                          Text('$myPts pts',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: FamilyLight.gold)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isWinner
                                ? FamilyLight.gold.withOpacity(0.15)
                                : FamilyLight.border,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isWinner
                                  ? FamilyLight.gold.withOpacity(0.3)
                                  : FamilyLight.border,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                isWinner ? '+500' : '+0',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isWinner
                                      ? FamilyLight.gold
                                      : FamilyLight.faint,
                                ),
                              ),
                              Text(
                                'BP',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                  color: isWinner
                                      ? FamilyLight.gold
                                          .withOpacity(0.7)
                                      : FamilyLight.border,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: FamilyLight.red.withOpacity(0.2)),
                        gradient: LinearGradient(
                          colors: [
                            FamilyLight.red.withOpacity(0.06),
                            FamilyLight.card.withOpacity(0.5),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: FamilyLight.red
                                      .withOpacity(0.4),
                                  width: 2),
                            ),
                            child: ClipOval(
                              child: enemyAvatar != null
                                  ? CachedNetworkImage(
                                      imageUrl: enemyAvatar,
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: FamilyLight.fill,
                                      child: const Icon(
                                          Icons.security,
                                          color: FamilyLight.red,
                                          size: 24)),
                            ),
                          ),
                          const Gap(6),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(enemyName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    color: FamilyLight.ink),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const Gap(2),
                          Text('$enemyPts pts',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: FamilyLight.red)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(20),

          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: FamilyLight.gold.withOpacity(0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(
                      flex: (myRatio * 100).toInt().clamp(1, 99),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FamilyLight.gold.withOpacity(0.8),
                              FamilyLight.gold,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: ((1 - myRatio) * 100).toInt().clamp(1, 99),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FamilyLight.red,
                              FamilyLight.red.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Gap(8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$myPts',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: FamilyLight.gold)),
                Text('${(myRatio * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 11,
                        color: FamilyLight.muted)),
                Text('$enemyPts',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: FamilyLight.red)),
              ],
            ),
          ),
          const Gap(20),

          // Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(
                      color: FamilyLight.gold.withOpacity(0.3)),
                ),
                child: const Text('CLOSE',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: FamilyLight.gold,
                        letterSpacing: 2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
