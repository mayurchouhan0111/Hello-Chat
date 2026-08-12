import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/models/svip_level_model.dart';
import '../../../../core/providers/profile_provider.dart';

class SVIPCenterScreen extends ConsumerStatefulWidget {
  const SVIPCenterScreen({super.key});

  @override
  ConsumerState<SVIPCenterScreen> createState() => _SVIPCenterScreenState();
}

class _SVIPCenterScreenState extends ConsumerState<SVIPCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isClaimingReward = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _claimDailyReward(int svipLevel) async {
    if (svipLevel <= 0) return;
    setState(() => _isClaimingReward = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('claimSvipDailyReward');
      final res = await callable.call();
      if (res.data != null && res.data['success'] == true) {
        final amount = res.data['rewardAmount'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Claimed $amount Daily Diamonds!'),
              backgroundColor: Colors.amber[700],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaimingReward = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'SVIP CENTER',
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Privileges'),
            Tab(text: 'Recharge Log'),
            Tab(text: 'Upgrade History'),
          ],
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
        data: (user) {
          final svipLevel = user?.svipLevel ?? 0;
          final svipPoints = user?.svipPoints ?? 0;
          final currentLevelModel = SVIPLevelModel.getLevelByTier(svipLevel);
          final nextLevelModel = SVIPLevelModel.getLevelByTier(svipLevel < 6 ? svipLevel + 1 : 6);

          final pointsTarget = nextLevelModel.requiredPoints;
          final progress = pointsTarget > 0 ? (svipPoints / pointsTarget).clamp(0.0, 1.0) : 1.0;

          final cycleEndDate = user?.vipExpiry;
          final remainingDays = cycleEndDate != null
              ? cycleEndDate.difference(DateTime.now()).inDays.clamp(0, 60)
              : 60;

          return TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Main Privileges & Daily Claim
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2C2411), Color(0xFF15130C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'SVIP $svipLevel',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              'Cycle Validity: $remainingDays Days',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$svipPoints PTS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            Text(
                              'Next: ${nextLevelModel.requiredPoints} PTS',
                              style: TextStyle(
                                color: Colors.amber[200],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.black45,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '1 USD Recharge = 100 SVIP Points. Points reset to 0 upon upgrade or 60-day cycle completion.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Daily Diamond Reward Claim Card
                  if (svipLevel > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1C16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daily SVIP Reward',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${currentLevelModel.dailyDiamondReward} Diamonds / 24 Hours',
                                style: TextStyle(color: Colors.amber[300], fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _isClaimingReward ? null : () => _claimDailyReward(svipLevel),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: _isClaimingReward
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Text('CLAIM', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  const Text(
                    'UNLOCKED PRIVILEGES',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Privileges Grid
                  _buildPrivilegeTile('Family Management', 'Battle Name, Logo & Leader Transfer', svipLevel >= 1),
                  _buildPrivilegeTile('Friend List Hide', 'Hide follower & friend lists for target IDs', svipLevel >= 3),
                  _buildPrivilegeTile('Profile Hide (Mystery Man)', 'Conceal real profile across rooms & feeds', svipLevel >= 4),
                  _buildPrivilegeTile('Voice Room Protection', 'Immunity against Kick Out and Mute actions', svipLevel >= 4),
                  _buildPrivilegeTile('CP Lock & SVIP 6 Remove', 'Lock CP relationship & send 5 removal requests', svipLevel >= 3),
                  _buildPrivilegeTile('Global Room Kick', 'SVIP 6 exclusive room kick permission', svipLevel == 6),
                  _buildPrivilegeTile('Banner Promotions', 'Level-based custom promotional banners', svipLevel >= 1),
                ],
              ),

              // Tab 2: Recharge Log
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('recharge_history')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No recharge records found.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final usd = data['usdAmount'] ?? 0.0;
                      final pts = (usd * 100).toInt();
                      final date = (data['timestamp'] as Timestamp?)?.toDate();
                      return Card(
                        color: const Color(0xFF1E1C16),
                        child: ListTile(
                          title: Text('\$$usd USD Recharge', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(date != null ? date.toString().split('.')[0] : 'Recent', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: Text('+$pts PTS', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                      );
                    },
                  );
                },
              ),

              // Tab 3: Upgrade History
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('svip_audit_logs')
                    .where('uid', isEqualTo: user?.uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No upgrade history recorded.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final type = data['type'] ?? 'upgrade';
                      final newLevel = data['newLevel'] ?? 0;
                      final date = (data['timestamp'] as Timestamp?)?.toDate();
                      return Card(
                        color: const Color(0xFF1E1C16),
                        child: ListTile(
                          title: Text('SVIP Level $newLevel ($type)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(date != null ? date.toString() : 'Recent', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: const Icon(Icons.verified, color: Colors.amber),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrivilegeTile(String title, String subtitle, bool unlocked) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: unlocked ? const Color(0xFF1E1C16) : Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: unlocked ? Colors.amber.withOpacity(0.3) : Colors.white10),
      ),
      child: ListTile(
        leading: Icon(
          unlocked ? Icons.check_circle : Icons.lock,
          color: unlocked ? Colors.amber : Colors.grey,
        ),
        title: Text(title, style: TextStyle(color: unlocked ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ),
    );
  }
}
