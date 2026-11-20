import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/fame_model.dart';
import '../../../../core/providers/fame_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/fame_badge.dart';

class FameScreen extends ConsumerStatefulWidget {
  const FameScreen({super.key});

  @override
  ConsumerState<FameScreen> createState() => _FameScreenState();
}

class _FameScreenState extends ConsumerState<FameScreen> {
  FamePeriod _period = FamePeriod.daily;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Fame Hall',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _buildFameHeader(),
          const SizedBox(height: 20),
          const Text(
            'Fame Ranking',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: FamePeriod.values.map((period) {
              return ChoiceChip(
                label: Text(period.label),
                selected: _period == period,
                onSelected: (_) => setState(() => _period = period),
                selectedColor: const Color(0xFF6C4AB6),
                labelStyle: TextStyle(
                  color: _period == period ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildLeaderboard(),
        ],
      ),
    );
  }

  Widget _buildFameHeader() {
    final profile = ref.watch(currentUserProfileProvider);
    final user = profile.valueOrNull;
    final hasError = profile.hasError && user == null;
    final isLoading = user == null && !hasError;
    final points = user?.totalBeansReceived ?? 0;
    final tier = FameCatalog.tierFor(points);
    final next = FameCatalog.nextTier(points);
    final tierColor = Color(tier.colorValue);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1B4A), Color(0xFF5B3A9B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B3A9B).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tierColor.withValues(alpha: 0.22),
                  border: Border.all(color: tierColor, width: 2),
                ),
                child: Icon(Icons.local_fire_department_rounded,
                    color: tierColor, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasError
                          ? 'Fame unavailable'
                          : isLoading
                              ? 'Loading Fame…'
                              : tier.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900),
                    ),
                    if (!hasError && !isLoading) ...[
                      const SizedBox(height: 4),
                      FameBadge(points: points, compact: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  hasError ? '—' : _formatCount(points),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900),
                ),
              ),
              const Text(
                'Lifetime Fame Points',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: hasError || isLoading ? 0 : FameCatalog.progress(points),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            ),
          ),
          const SizedBox(height: 8),
          if (hasError)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Could not load your Fame right now.',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(currentUserProfileProvider),
                  child: const Text('Retry',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            )
          else
            Text(
              isLoading
                  ? 'Fetching your Fame…'
                  : next == null
                      ? 'Maximum Fame level reached'
                      : '${_formatCount(FameCatalog.pointsToNext(points))} Beans to ${next.title}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 12),
          Text(
            'Fame rises with the Beans you receive from gifts.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    final leaderboard = ref.watch(fameLeaderboardProvider(_period));
    return leaderboard.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child:
            Center(child: CircularProgressIndicator(color: Color(0xFF6C4AB6))),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 44, color: Colors.black26),
            const SizedBox(height: 10),
            const Text('Could not load Fame ranking',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(fameLeaderboardProvider(_period)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(Icons.local_fire_department_outlined,
                    size: 52, color: Colors.black26),
                SizedBox(height: 10),
                Text('No Fame yet',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: Colors.black54)),
                SizedBox(height: 4),
                Text('Beans received in gifts appear here.',
                    style: TextStyle(fontSize: 12, color: Colors.black38)),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              _buildEntryRow(entries[i], i + 1),
          ],
        );
      },
    );
  }

  Widget _buildEntryRow(FameEntry entry, int rank) {
    final rankColor = rank == 1
        ? const Color(0xFFFFB300)
        : rank == 2
            ? const Color(0xFF90A4AE)
            : rank == 3
                ? const Color(0xFFBF7B3A)
                : Colors.black38;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.userProfile, extra: entry.uid),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: rank <= 3
                  ? Icon(Icons.workspace_premium_rounded,
                      color: rankColor, size: 22)
                  : Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13),
                    ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFEDE7F6),
              child: ClipOval(
                child: entry.photoUrl.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.black26)
                    : CachedNetworkImage(
                        imageUrl: entry.photoUrl,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: Colors.black26),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 3),
                  FameBadge(points: entry.points, compact: true),
                ],
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCompact(entry.points),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Color(0xFF6C4AB6)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompact(int value) {
    if (value >= 1000000000) {
      final v = value / 1000000000;
      return '${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1)}B';
    }
    if (value >= 1000000) {
      final v = value / 1000000;
      return '${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final v = value / 1000;
      return '${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1)}K';
    }
    return '$value';
  }

  String _formatCount(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}
