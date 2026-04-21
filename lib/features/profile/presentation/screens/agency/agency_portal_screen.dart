import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/agency_provider.dart';
import 'package:hello_chat/core/models/agency_model.dart';
import 'package:hello_chat/core/models/user_model.dart';


// ─────────────────────────────────────────────
//  Agency Theme Tokens
// ─────────────────────────────────────────────
class AgencyTheme {
  static const bg       = Color(0xFF080A0C);
  static const gold     = Color(0xFFF59E0B);
  static const goldDim  = Color(0x22F59E0B);
  static const surface  = Color(0xFF11141B);
  static const surface2 = Color(0xFF1A1F28);
  static const text     = Color(0xFFF1F5F9);
  static const textSub  = Color(0xFF94A3B8);
  static const textHint = Color(0xFF334155);
  static const divider  = Color(0xFF232936);

}

// ─────────────────────────────────────────────
//  Agency Portal Screen
// ─────────────────────────────────────────────
class AgencyPortalScreen extends ConsumerStatefulWidget {
  const AgencyPortalScreen({super.key});

  @override
  ConsumerState<AgencyPortalScreen> createState() => _AgencyPortalScreenState();
}

class _AgencyPortalScreenState extends ConsumerState<AgencyPortalScreen> {
  @override
  Widget build(BuildContext context) {
    final myAgencyAsync = ref.watch(myAgencyProvider);
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AgencyTheme.bg,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -150, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AgencyTheme.gold.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: myAgencyAsync.when(
                    data: (agency) {
                      if (agency == null) {
                        return _buildJoinOrCreateView(context);
                      }
                      return _buildAgencyDashboard(agency);
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AgencyTheme.gold)),
                    error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AgencyTheme.surface2,
                border: Border.all(color: AgencyTheme.divider),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AgencyTheme.text, size: 16),
            ),
          ),
          const Gap(20),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AGENCY PORTAL',
                style: TextStyle(
                  color: AgencyTheme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Economic Distribution Center',
                style: TextStyle(color: AgencyTheme.textSub, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Join or Create View ───────────────────────
  Widget _buildJoinOrCreateView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Gap(40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AgencyTheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AgencyTheme.gold.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.business_center_rounded, color: AgencyTheme.gold, size: 48),
                const Gap(20),
                const Text(
                  'Become an Agent',
                  style: TextStyle(color: AgencyTheme.text, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const Gap(8),
                const Text(
                  'Start your own agency, recruit hosts,\nand earn 10-20% commissions on all gifts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AgencyTheme.textSub, fontSize: 13),
                ),
                const Gap(32),
                _buildActionButton(
                  label: 'Register My Agency',
                  onTap: () => _showCreateAgencySheet(context),
                  isPrimary: true,
                ),
              ],
            ),
          ),
          const Gap(24),
          const Text('OR SEARCH AGENCIES TO JOIN', style: TextStyle(color: AgencyTheme.textSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Gap(24),
          ref.watch(allAgenciesProvider).when(
            data: (agencies) => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: agencies.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, i) => _AgencyListItem(agency: agencies[i]),
            ),
            loading: () => const Center(child: CircularProgressIndicator(color: AgencyTheme.gold)),
            error: (_, __) => const Text('Failed to load agencies'),
          ),
        ],
      ),
    );
  }

  // ── Agency Dashboard ─────────────────────────
  Widget _buildAgencyDashboard(AgencyModel agency) {
    final hostsAsync = ref.watch(agencyHostsProvider(agency.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agency Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [AgencyTheme.gold.withOpacity(0.15), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AgencyTheme.gold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AgencyTheme.surface2,
                  backgroundImage: agency.logoUrl.isNotEmpty ? CachedNetworkImageProvider(agency.logoUrl) : null,
                  child: agency.logoUrl.isEmpty ? const Icon(Icons.business_rounded, color: AgencyTheme.gold) : null,
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agency.name, style: const TextStyle(color: AgencyTheme.text, fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('Owner: ${agency.ownerName}', style: const TextStyle(color: AgencyTheme.textSub, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AgencyTheme.gold.withOpacity(0.1)),
                  child: Text('${(agency.commissionRate * 100).toInt()}% Comm', style: const TextStyle(color: AgencyTheme.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const Gap(32),
          const Text('AGENCY DISBURSEMENT', style: TextStyle(color: AgencyTheme.textSub, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Gap(16),
          Row(
            children: [
              _StatCard(title: 'Total Beans', value: agency.totalBeansEarned.toString(), icon: Icons.payments_rounded, color: AgencyTheme.gold),
              const Gap(12),
              _StatCard(title: 'Hosts', value: agency.hostUids.length.toString(), icon: Icons.people_rounded, color: Colors.blue),
            ],
          ),

          const Gap(32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('MY HOSTS', style: TextStyle(color: AgencyTheme.textSub, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
              Text('${agency.hostUids.length} Active', style: const TextStyle(color: AgencyTheme.textSub, fontSize: 11)),
            ],
          ),
          const Gap(16),
          hostsAsync.when(
            data: (hosts) => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: hosts.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, i) => _HostListItem(user: hosts[i]),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Text('Error loading hosts: $e'),
          ),
          const Gap(40),
          _buildActionButton(
            label: 'Withdraw Agency Earnings',
            onTap: () {}, // Month 6 Final gateway
            isPrimary: true,
          ),
          const Gap(16),
          _buildActionButton(
            label: 'Leave Agency',
            onTap: () => ref.read(agencyServiceProvider).leaveAgency(),
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required VoidCallback onTap, required bool isPrimary}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isPrimary ? AgencyTheme.gold : Colors.transparent,
          border: isPrimary ? null : Border.all(color: AgencyTheme.divider),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.black : AgencyTheme.textSub,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateAgencySheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 40),
        decoration: const BoxDecoration(
          color: AgencyTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Launch Agency', style: TextStyle(color: AgencyTheme.text, fontSize: 24, fontWeight: FontWeight.w900)),
            const Gap(8),
            const Text('Pick a unique name for your host group.', style: TextStyle(color: AgencyTheme.textSub, fontSize: 13)),
            const Gap(32),
            _buildTextField(label: 'Agency Name', hint: 'The Royal Syndicate', controller: nameCtrl),
            const Gap(20),
            _buildTextField(label: 'Description', hint: 'Best hosts in the game...', controller: descCtrl, maxLines: 3),
            const Gap(32),
            _buildActionButton(
              label: 'Create Agency Now',
              onTap: () async {
                await ref.read(agencyServiceProvider).createAgency(nameCtrl.text, descCtrl.text, '');
                Navigator.pop(context);
              },
              isPrimary: true,
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, required TextEditingController controller, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AgencyTheme.textSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const Gap(10),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AgencyTheme.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AgencyTheme.textSub.withOpacity(0.5)),
            filled: true,
            fillColor: AgencyTheme.surface2,
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

// ── Shared Widgets ─────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AgencyTheme.surface2, borderRadius: BorderRadius.circular(20), border: Border.all(color: AgencyTheme.divider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1)),
              child: Icon(icon, color: color, size: 16),
            ),
            const Gap(16),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(title, style: const TextStyle(color: AgencyTheme.textSub, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _AgencyListItem extends ConsumerWidget {
  final AgencyModel agency;
  const _AgencyListItem({required this.agency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AgencyTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AgencyTheme.divider)),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: AgencyTheme.surface2, child: const Icon(Icons.business_rounded, color: AgencyTheme.gold, size: 20)),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agency.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                Text('${agency.hostUids.length} Hosts', style: const TextStyle(color: AgencyTheme.textSub, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ref.read(agencyServiceProvider).joinAgency(agency.id),
            child: const Text('JOIN', style: TextStyle(color: AgencyTheme.gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _HostListItem extends StatelessWidget {
  final UserModel user;
  const _HostListItem({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AgencyTheme.surface2, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: user.profilePhotoUrl.isNotEmpty ? CachedNetworkImageProvider(user.profilePhotoUrl) : null,
            child: user.profilePhotoUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text('Beans: ${user.beansBalance}', style: const TextStyle(color: AgencyTheme.textSub, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AgencyTheme.textHint),
        ],
      ),
    );
  }
}
