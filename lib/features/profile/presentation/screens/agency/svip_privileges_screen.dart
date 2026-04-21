import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/models/svip_level_model.dart';
import '../../../../../core/providers/profile_provider.dart';


class SVIPPrivilegesScreen extends ConsumerWidget {
  const SVIPPrivilegesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate/Black like screenshot
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "MSB - SVIP Point/Privileges",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
        error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.white))),
        data: (user) {
          final currentRecharge = user?.monthlyRecharge ?? 0;
          final currentLevel = user?.svipLevel ?? -1;
          
          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Image (Matching the Golden SVIP Logo)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 100),
                      const SizedBox(height: 10),
                      const Text(
                        "SVIP PRIVILEGES",
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Current Progress Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "This Month: $currentRecharge 💎",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Current Rank: ${currentLevel >= 0 ? 'SVIP$currentLevel' : 'None'}",
                                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: (currentRecharge / 500000000).clamp(0, 1),
                              backgroundColor: Colors.white10,

                              color: const Color(0xFFFFD700),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Privilege Table (Matching Screenshot)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.1),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(child: Center(child: Text("LEVEL", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text("Monthly Recharge", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text("SVIP Points", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)))),
                          ],
                        ),
                      ),
                      
                      // Table Body
                      ...SVIPLevelModel.levels.map((level) {
                        final isAchieved = currentRecharge >= level.monthlyRechargeRequirement;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                            color: isAchieved ? const Color(0xFFFFD700).withOpacity(0.05) : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Center(child: Text(level.name, style: TextStyle(color: isAchieved ? const Color(0xFFFFD700) : Colors.white, fontWeight: FontWeight.bold)))),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatNumber(level.monthlyRechargeRequirement),
                                      style: TextStyle(color: isAchieved ? const Color(0xFFFFD700) : Colors.white70, fontSize: 13),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700), size: 12),
                                  ],
                                ),
                              ),
                              Expanded(child: Center(child: Text("${level.svipPoints}", style: TextStyle(color: isAchieved ? const Color(0xFFFFD700) : Colors.white70, fontSize: 13)))),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "*SVIP status is calculated based on cumulative recharge within a single calendar month. Rank resets on the 1st of every month.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return "${(number / 1000000).toStringAsFixed(1)}M";
    if (number >= 1000) return "${(number / 1000).toStringAsFixed(0)}K";
    return number.toString();
  }
}
