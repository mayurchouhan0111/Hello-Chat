import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';

class CPLevelScreen extends ConsumerWidget {
  const CPLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Elite Dark Theme
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("CP LEVEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: profileAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // 🌟 CURRENT PROGRESS CARD
                _buildProgressHeader(user),
                
                const Gap(30),

                // 🏅 LEVEL MILESTONES (THE ROADMAP)
                _buildMilestonesList(),

                const Gap(40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
        error: (e, __) => const SizedBox(),
      ),
    );
  }

  Widget _buildProgressHeader(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2D0A15), Color(0xFF1A1A1A)]),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.pinkAccent.withOpacity(0.05), blurRadius: 30)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniProfileCircle(user.profilePhotoUrl),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 24),
              ),
              _miniProfileCircle(user.partnerAvatar ?? ""),
            ],
          ),
          const Gap(24),
          const Text("INTIMACY LEVEL", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Gap(4),
          Text("${user.cpLevel}", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
          const Gap(16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (user.cpPoints % 100) / 100, // Corrected logic for demo
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation(Colors.pinkAccent),
            ),
          ),
          const Gap(12),
          Text("${user.cpPoints}/1000 CP XP", style: const TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _miniProfileCircle(String url) {
    return Container(
      width: 54, height: 54,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
      child: Container(
        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: url, 
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white12),
        ),
      ),
    );
  }

  Widget _buildMilestonesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("LEVEL PRIVILEGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        const Gap(20),
        _milestoneTile("1", "PARTNER STATUS", "Unlock shared profile view and basic badge.", true),
        _milestoneTile("5", "WHISPER EFFECT", "Get a special magenta bubble for your private chats.", false),
        _milestoneTile("10", "HEART ENTRY", "Your entry into any room will be announced with hearts.", false),
        _milestoneTile("20", "GOLD FRAME", "Exclusive 'Eternal Love' golden profile frame.", false),
        _milestoneTile("50", "DEDICATED SERVER", "Unique room ID for your private Couple House.", false),
      ],
    );
  }

  Widget _milestoneTile(String lvl, String title, String desc, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: unlocked ? Colors.pinkAccent : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: unlocked ? Colors.pinkAccent : Colors.white12),
            ),
            child: Center(
              child: Text("LV$lvl", style: TextStyle(color: unlocked ? Colors.white : Colors.white38, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: unlocked ? Colors.white : Colors.white38, fontWeight: FontWeight.w900, fontSize: 13)),
                const Gap(4),
                Text(desc, style: TextStyle(color: unlocked ? Colors.white70 : Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0);
  }
}
