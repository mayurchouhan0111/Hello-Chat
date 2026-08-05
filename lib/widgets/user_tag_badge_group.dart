import 'package:flutter/material.dart';
import 'uniform_tag_badge.dart';
import '../services/dynamic_tag_service.dart';

class UserTagBadgeGroup extends StatelessWidget {
  final Map<String, dynamic> userData;
  final double spacing;
  final MainAxisAlignment mainAxisAlignment;

  const UserTagBadgeGroup({
    super.key,
    required this.userData,
    this.spacing = UniformTagBadge.defaultSpacing,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> tags = [];
    final tagService = DynamicTagService.instance;

    // 1. Host Role Tag (Dynamic Color)
    final role = userData['role'] as String? ?? '';
    final hostDiamonds = (userData['hostDiamondsEarned'] as num?)?.toInt() ?? 0;
    if (role == 'host' || hostDiamonds > 0) {
      final hostInfo = tagService.getHostTagInfo(hostDiamonds);
      tags.add(UniformTagBadge.fromHex(
        label: hostInfo.label,
        icon: Icons.mic,
        hexColor: hostInfo.hexColor,
      ));
    }

    // 2. Agency Role Tag (Dynamic Color)
    final agencyDiamonds = (userData['agencyDiamondsEarned'] as num?)?.toInt() ?? 0;
    if (role == 'agency' || agencyDiamonds > 0) {
      final agencyInfo = tagService.getAgencyTagInfo(agencyDiamonds);
      tags.add(UniformTagBadge.fromHex(
        label: agencyInfo.label,
        icon: Icons.business,
        hexColor: agencyInfo.hexColor,
      ));
    }

    // 3. VIP / SVIP Tag
    final vipLevel = (userData['vipLevel'] as num?)?.toInt() ?? 0;
    if (vipLevel > 0) {
      tags.add(UniformTagBadge(
        label: 'VIP $vipLevel',
        icon: Icons.workspace_premium,
        gradientColors: const [Color(0xFFFFD700), Color(0xFFFFA500)],
      ));
    }

    // 4. Daily Receiver Rank Tag
    final dailyReceiverTag = userData['dailyReceiverRankTag'] as String?;
    if (dailyReceiverTag != null && dailyReceiverTag.isNotEmpty) {
      tags.add(UniformTagBadge(
        label: dailyReceiverTag,
        icon: Icons.star,
        backgroundColor: const Color(0xFFE91E63),
      ));
    }

    // 5. Weekly Receiver Rank Tag
    final weeklyReceiverTag = userData['weeklyReceiverRankTag'] as String?;
    if (weeklyReceiverTag != null && weeklyReceiverTag.isNotEmpty) {
      tags.add(UniformTagBadge(
        label: weeklyReceiverTag,
        icon: Icons.military_tech,
        backgroundColor: const Color(0xFF9C27B0),
      ));
    }

    // 6. Daily Sender Rank Tag
    final dailySenderTag = userData['dailySenderRankTag'] as String?;
    if (dailySenderTag != null && dailySenderTag.isNotEmpty) {
      tags.add(UniformTagBadge(
        label: dailySenderTag,
        icon: Icons.diamond,
        backgroundColor: const Color(0xFF00BCD4),
      ));
    }

    // 7. Weekly Sender Rank Tag
    final weeklySenderTag = userData['weeklySenderRankTag'] as String?;
    if (weeklySenderTag != null && weeklySenderTag.isNotEmpty) {
      tags.add(UniformTagBadge(
        label: weeklySenderTag,
        icon: Icons.diamond,
        backgroundColor: const Color(0xFF3F51B5),
      ));
    }

    // 8. Monthly Sender Rank Tag
    final monthlySenderTag = userData['monthlySenderRankTag'] as String?;
    if (monthlySenderTag != null && monthlySenderTag.isNotEmpty) {
      tags.add(UniformTagBadge(
        label: monthlySenderTag,
        icon: Icons.diamond,
        backgroundColor: const Color(0xFF4CAF50),
      ));
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return UniformTagGroup(
      tags: tags,
      spacing: spacing,
      mainAxisAlignment: mainAxisAlignment,
    );
  }
}
