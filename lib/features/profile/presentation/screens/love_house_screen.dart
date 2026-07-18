import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/relationship_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/relationship_model.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/relationship_service.dart';

class LoveHouseScreen extends ConsumerStatefulWidget {
  const LoveHouseScreen({super.key});

  @override
  ConsumerState<LoveHouseScreen> createState() => _LoveHouseScreenState();
}

class _LoveHouseScreenState extends ConsumerState<LoveHouseScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final result = await ref.read(relationshipServiceProvider).searchUsers(query.trim());
      setState(() => _searchResults = List<Map<String, dynamic>>.from(result['users'] as List? ?? []));
    } catch (_) {
      setState(() => _searchResults = []);
    }
    setState(() => _isSearching = false);
  }

  void _showInviteDialog() {
    _searchCtrl.clear();
    _searchResults = [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1F1D2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("INVITE PARTNER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) async {
                    if (v.trim().length < 2) {
                      setDialogState(() => _searchResults = []);
                      return;
                    }
                    try {
                      final result = await ref.read(relationshipServiceProvider).searchUsers(v.trim());
                      setDialogState(() => _searchResults = List<Map<String, dynamic>>.from(result['users'] as List? ?? []));
                    } catch (_) {
                      setDialogState(() => _searchResults = []);
                    }
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Search by username...",
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const Gap(12),
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, i) {
                        final u = _searchResults[i];
                        final isSelf = u['uid'] == ref.read(authStateProvider).value?.uid;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundImage: (u['profilePhotoUrl'] as String? ?? '').isNotEmpty
                                ? CachedNetworkImageProvider(u['profilePhotoUrl'] as String)
                                : null,
                            child: (u['profilePhotoUrl'] as String? ?? '').isEmpty
                                ? const Icon(Icons.person, color: Colors.white38, size: 16)
                                : null,
                          ),
                          title: Text(u['displayName'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('@${u['username'] as String? ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          trailing: isSelf
                              ? const Text("You", style: TextStyle(color: Colors.white24, fontSize: 10))
                              : SizedBox(
                                  height: 28,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await ref.read(relationshipServiceProvider).sendCPInvite(u['uid'] as String);
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("CP Invite sent!"), backgroundColor: Colors.green),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.pinkAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    child: const Text("Invite", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9)),
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final invitesAsync = ref.watch(cpInvitesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: profileAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          final bool isPaired = user.partnerUid != null && user.partnerUid!.isNotEmpty;
          final bool isFemale = user.gender?.toLowerCase() == 'female';

          return Stack(
            children: [
              // 💖 1. NEW HEART BOKEH BACKGROUND (Matching User's Request)
              _buildHeartBokehBackground(),

              // ✨ 2. SUBTLE FLOATING HEARTS (Enhanced Sparkle)
              ..._buildFloatingHearts(),

              // ☁️ 3. ELITE SCARLET OVERLAY
              _buildScarletScrim(),

              SafeArea(
                child: Column(
                  children: [
                    _buildEliteHeader(context),
                    invitesAsync.when(
                      data: (invs) => invs.isEmpty ? const SizedBox() : _buildInviteAlert(invs.first),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Column(
                          children: [
                            const Gap(20),
                            _buildSacredRing(user, isPaired, isFemale),
                            const Gap(40),
                            _buildGlassStats(user, isPaired),
                            const Gap(24),
                            _buildMiniMissionGrid(),
                            const Gap(24),
                            _buildPerkRow(),
                            if (isPaired) ...[
                              const Gap(20),
                              _buildDestructiveBtn("DISSOLVE PARTNERSHIP", () => _showDissolveDialog(user)),
                            ] else ...[
                               const Gap(30),
                               _buildGoldActionBtn("SEARCH PARTNER", _showInviteDialog),
                            ],
                            const Gap(40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
        error: (e, __) => const SizedBox(),
      ),
    );
  }

  Widget _buildHeartBokehBackground() {
    return Positioned.fill(
      child: CachedNetworkImage(
        // Matching the Pink/Magenta Sparkly Heart Vibe from the user's image
        imageUrl: "https://images.unsplash.com/photo-1516589174184-c68536573ca4?w=1000&q=80", 
        fit: BoxFit.cover,
        errorWidget: (c, e, s) => Container(color: const Color(0xFF3B0B1F)),
      ),
    );
  }

  Widget _buildScarletScrim() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              const Color(0xFFC2185B).withOpacity(0.1), // Warm Magenta Glow
              Colors.black.withOpacity(0.95),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingHearts() {
    return List.generate(8, (i) => Positioned(
      left: (i * 50).toDouble() + 5,
      bottom: -40,
      child: Icon(Icons.favorite, color: Colors.white.withOpacity(0.4), size: (8 + i % 6).toDouble())
        .animate(onPlay: (c) => c.repeat())
        .moveY(begin: 0, end: -600, duration: (4 + i).seconds)
        .fadeOut(delay: (2 + i).seconds),
    ));
  }

  Widget _buildEliteHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
          const Column(children: [Text("LOVE HOUSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 4)), Text("THE SACRED MUSEUM", style: TextStyle(color: Colors.pinkAccent, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1))]),
          const Icon(Icons.auto_awesome_rounded, color: Colors.pinkAccent, size: 20),
        ],
      ),
    );
  }

  Widget _buildInviteAlert(Map<String, dynamic> inv) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF2D161F), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.white10, backgroundImage: inv['senderAvatar'] != null ? CachedNetworkImageProvider(inv['senderAvatar']) : null, radius: 14, child: inv['senderAvatar'] == null ? const Icon(Icons.person, size: 14, color: Colors.white30) : null),
          const Gap(10),
          Expanded(child: Text("${inv['senderName'] ?? 'Someone'} is inviting you!", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
          GestureDetector(onTap: () => ref.read(relationshipServiceProvider).acceptCPInvite(inv['id']), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(8)), child: const Text("ACCEPT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9)))),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildSacredRing(UserModel user, bool isPaired, bool isFemale) {
    return Container(
      height: 160,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.favorite, color: Colors.pinkAccent, size: 120)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds)
              .fadeOut(duration: 2.seconds),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSacredAvatar(user.profilePhotoUrl, isFemale ? "QUEEN" : "KING"),
              const Gap(80),
              isPaired 
                ? _buildSacredAvatar(user.partnerAvatar ?? "", !isFemale ? "QUEEN" : "KING") 
                : _buildSacredAvatar("", "VACANT", isEmpty: true),
            ],
          ),
          
          const Icon(Icons.favorite_rounded, color: Colors.white, size: 36)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
        ],
      ),
    );
  }

  Widget _buildSacredAvatar(String url, String label, {bool isEmpty = false}) {
    return Column(
      children: [
        Container(
          width: 84, height: 84,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Colors.pinkAccent, Colors.amberAccent]),
            boxShadow: [BoxShadow(color: Colors.pinkAccent.withOpacity(0.4), blurRadius: 25)],
          ),
          child: Container(
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: (isEmpty || url.isEmpty)
              ? const Icon(Icons.favorite_border_rounded, color: Colors.white12, size: 28)
              : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (c, e, s) => const Icon(Icons.person, color: Colors.white12)),
          ),
        ),
        const Gap(12),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildGlassStats(UserModel user, bool isPaired) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat("CP RANK", "${user.cpLevel}"),
          _miniStat("HEARTS", "${user.cpPoints}"),
          _miniStat("BOND", "SOLO"), // Static for demo
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val) {
    return Column(children: [Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)), Text(label.toUpperCase(), style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1))]);
  }

  Widget _buildMiniMissionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("HEART MISSIONS", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2.5)),
        const Gap(16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.5,
          children: [
            _tinyMission(Icons.mic, "Voice", "+10"),
            _tinyMission(Icons.favorite, "Gift", "+100"),
            _tinyMission(Icons.camera, "Moment", "+25"),
            _tinyMission(Icons.stars, "Visit", "+15"),
          ],
        ),
      ],
    );
  }

  Widget _tinyMission(IconData icon, String title, String xp) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Row(children: [Icon(icon, color: Colors.pinkAccent, size: 12), const Gap(10), Expanded(child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 9))), Text(xp, style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.w900, fontSize: 9))]));
  }

  Widget _buildPerkRow() {
    return Row(children: [_miniPerk(Icons.shield_rounded, "CP SHEILD"), const Gap(10), _miniPerk(Icons.auto_awesome_rounded, "LOVE ENTRY")]);
  }

  Widget _miniPerk(IconData icon, String label) {
    return Expanded(child: Container(height: 48, decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.pinkAccent, size: 14), const Gap(10), Text(label, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, fontSize: 9))])));
  }

  void _showDissolveDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Dissolve Partnership?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        content: const Text("This will end your CP relationship. All shared progress and bonuses will be lost. This action cannot be undone.", style: TextStyle(color: Colors.white60, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final rels = await ref.read(relationshipServiceProvider).streamUserRelationships(user.uid, type: RelationshipType.cp).first;
                if (rels.isNotEmpty) {
                  await ref.read(relationshipServiceProvider).dissolveCP(rels.first.id);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Partnership dissolved."), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("DISSOLVE"),
          ),
        ],
      ),
    );
  }

  Widget _buildDestructiveBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildGoldActionBtn(String label, VoidCallback onTap) {
    return SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 0), child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2))));
  }
}
