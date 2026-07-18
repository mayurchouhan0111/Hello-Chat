import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/providers/recharge_event_provider.dart';

class RechargeEventDetailScreen extends ConsumerWidget {
  const RechargeEventDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(activeRechargeEventProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2B1308), // Rich dark brown
              Color(0xFF150803), // Deep black/brown
              Color(0xFF0C0401),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: eventAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            ),
            error: (err, stack) => Center(
              child: Text(
                "Error: $err",
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
            data: (event) {
              if (event == null) {
                return _buildEmptyState(context);
              }
              final eventId = event['id'] as String;
              final title = event['title'] ?? 'Recharge Bonus Event';
              final desc = event['description'] ?? '';
              final bannerUrl = event['bannerImage'] ?? '';

              return CustomScrollView(
                slivers: [
                  // App Bar with back button overlaid
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: const Color(0xFF2B1308),
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFFD700), size: 16),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (bannerUrl.isNotEmpty)
                            Image.network(
                              bannerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildDefaultBanner(),
                            )
                          else
                            _buildDefaultBanner(),
                          // Smooth bottom fade overlay
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Color(0xFF2B1308)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // Hero Content Overlay
                          Positioned(
                            bottom: 20,
                            left: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700), // Gold
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 10, offset: Offset(2, 2)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Detail Content Sections
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Under Discussion Warning Banner
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline_rounded, color: Color(0xFFFFB300), size: 20),
                              Gap(12),
                              Expanded(
                                child: Text(
                                  "UNDER DISCUSSION WITH CLIENT\nThis feature and the rebate amounts are not finalized.",
                                  style: TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.bold, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 1$ = 3M Coins offer badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFE52E2E), Color(0xFFA50C0C)]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 10),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "1 \$ = ",
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  " 3m coins",
                                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                                Icon(Icons.arrow_upward_rounded, color: Color(0xFFFFD700), size: 16),
                              ],
                            ),
                          ),
                        ),
                        const Gap(24),

                        // Go to recharge button
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF3333).withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  side: const BorderSide(color: Color(0xFFFFD700), width: 2),
                                ),
                              ),
                              onPressed: () => context.push(AppRoutes.wallet),
                              child: const Text(
                                "Go to recharge",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const Gap(32),

                        // Section 2: Event Details
                        _buildEventDetailsCard(desc),
                        const Gap(28),

                        // Section 3: Recharge Bonus Table
                        _buildTableSection(ref, eventId),
                        const Gap(40),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD700).withOpacity(0.05),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.15)),
            ),
            child: const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 64),
          ),
          const Gap(20),
          const Text(
            "UNDER DISCUSSION",
            style: TextStyle(color: Color(0xFFFFB300), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const Gap(8),
          const Text(
            "The Recharge Bonus Event screen is currently under discussion with the client and is incomplete.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const Gap(24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B1308),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      color: const Color(0xFF3E1F11),
      child: const Center(
        child: Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 80),
      ),
    );
  }

  Widget _buildEventDetailsCard(String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6B2A0E).withOpacity(0.9), // Classic royal brown card
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 14),
              Gap(8),
              Text(
                "Event Details:",
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Gap(12),
          Text(
            desc,
            style: const TextStyle(
              color: Color(0xFFFFE5D9),
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(16),
          const Text(
            "Note: Platform reserves the right to final interpretation of this event. Please consult customer service for specific rules.",
            style: TextStyle(
              color: Color(0xFFFFB399),
              fontSize: 10,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSection(WidgetRef ref, String eventId) {
    final packagesAsync = ref.watch(rechargeEventPackagesProvider(eventId));

    return packagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      error: (err, stack) => Center(child: Text("Error packages: $err", style: const TextStyle(color: Colors.red))),
      data: (packages) {
        if (packages.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6B2A0E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Styled Table Header
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.4), width: 1)),
                    ),
                    children: const [
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text("Recharge/\$", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text("basic coins", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text("bonus coins", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text("total", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  // Styled Table Rows
                  ...packages.map((pkg) {
                    final recharge = pkg['rechargeAmount'] ?? 0;
                    final base = pkg['baseCoins'] ?? 0;
                    final bonus = pkg['bonusCoins'] ?? 0;
                    final total = pkg['totalCoins'] ?? (base + bonus);

                    return TableRow(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.15), width: 0.5)),
                      ),
                      children: [
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "$recharge",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "$base",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFFE5D9), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "$bonus",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFF3333), fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "$total",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
