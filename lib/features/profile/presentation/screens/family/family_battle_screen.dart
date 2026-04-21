import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hello_chat/core/models/family_model.dart';
import 'package:hello_chat/core/providers/family_provider.dart';
import 'package:hello_chat/core/constants/app_colors.dart';

class FamilyBattleScreen extends ConsumerStatefulWidget {
  final String myFamilyId;
  const FamilyBattleScreen({super.key, required this.myFamilyId});

  @override
  ConsumerState<FamilyBattleScreen> createState() => _FamilyBattleScreenState();
}

class _FamilyBattleScreenState extends ConsumerState<FamilyBattleScreen> {
  int myPoints = 4250;
  int enemyPoints = 3100;

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(familyStreamProvider(widget.myFamilyId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('FAMILY ARENA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded)),
      ),
      body: familyAsync.when(
        data: (family) {
          if (family == null) return const Center(child: Text("Error"));
          return _buildBattleUI(family);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Error")),
      ),
    );
  }

  Widget _buildBattleUI(FamilyModel myFamily) {
    double total = (myPoints + enemyPoints).toDouble();
    double myRatio = total == 0 ? 0.5 : myPoints / total;

    return Column(
      children: [
        _buildTimerBar(),
        const Gap(24),
        
        // Split Versus View
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildCombatant(myFamily, true, myPoints)),
                const Gap(8),
                _buildVersusDivider(),
                const Gap(8),
                Expanded(child: _buildCombatant(null, false, enemyPoints)),
              ],
            ),
          ),
        ),

        const Gap(24),
        _buildHardProgressBar(myRatio),
        const Gap(24),

        // Contribution Section
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: AppColors.divider, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOP RECRUITS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textPrimary)),
                const Gap(16),
                Expanded(
                  child: ListView.separated(
                    itemCount: 4,
                    separatorBuilder: (_, __) => const Gap(10),
                    itemBuilder: (context, i) => _ContributionItemLight(index: i),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_rounded, color: Colors.red, size: 20),
          Gap(8),
          Text('ENDS IN 03:45', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCombatant(FamilyModel? family, bool isLeft, int pts) {
    final color = isLeft ? AppColors.primary : Colors.red;
    final bgColor = isLeft ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2);
    final borderColor = isLeft ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70, height: 70,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(
                  child: family?.avatarUrl != null 
                    ? CachedNetworkImage(imageUrl: family!.avatarUrl!, fit: BoxFit.cover)
                    : Icon(isLeft ? Icons.shield : Icons.security, color: color, size: 30),
                ),
              ),
              if (isLeft)
                Positioned(bottom: -5, child: _buildTag('ALLY', color)),
            ],
          ),
          const Gap(16),
          Text(family?.name ?? 'SHADOW CLAN', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const Gap(4),
          Text('${(pts / 1000).toStringAsFixed(1)}k', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24)),
          const Text('PTS', style: TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildVersusDivider() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, fontStyle: FontStyle.italic, color: Colors.black12)),
        Container(width: 2, height: 40, color: Colors.black12),
      ],
    );
  }

  Widget _buildHardProgressBar(double ratio) {
    return Container(
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(
              flex: (ratio * 100).toInt(),
              child: Container(color: AppColors.primary),
            ),
            Expanded(
              flex: ((1 - ratio) * 100).toInt(),
              child: Container(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionItemLight extends StatelessWidget {
  final int index;
  const _ContributionItemLight({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.textTertiary))),
          ),
          const Gap(12),
          const CircleAvatar(radius: 16, backgroundColor: AppColors.background),
          const Gap(12),
          const Expanded(child: Text('Elite Warrior', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          Text('${1500 - (index * 300)} pts', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}
