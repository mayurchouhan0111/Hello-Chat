import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../../../../../core/widgets/user_badge.dart';

class SvipBadgeShowcase extends StatefulWidget {
  const SvipBadgeShowcase({super.key});

  @override
  State<SvipBadgeShowcase> createState() => _SvipBadgeShowcaseState();
}

class _SvipBadgeShowcaseState extends State<SvipBadgeShowcase> {
  int _selectedTab = 0; // 0: Agency, 1: Host, 2: SVIP

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13100B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4A3A16), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 20),
                  const Gap(8),
                  Text(
                    "LEVEL BADGE PREVIEW",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFFE58F),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                "Live Pill Engine",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Gap(14),

          // Segmented Tab Selector
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                _buildTabButton("AGENCY", 0),
                _buildTabButton("HOST", 1),
                _buildTabButton("SVIP TIERS", 2),
              ],
            ),
          ),
          const Gap(16),

          // Badges List
          if (_selectedTab == 0) _buildAgencyBadgesList(),
          if (_selectedTab == 1) _buildHostBadgesList(),
          if (_selectedTab == 2) _buildSvipBadgesList(),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2A2000) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 1)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? const Color(0xFFFFE58F) : Colors.white54,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgencyBadgesList() {
    final agencyTiers = [
      {"level": 1, "target": "Target: 0 - 99", "tier": "Bronze Tier"},
      {"level": 2, "target": "Target: 100 - 499", "tier": "Silver Tier"},
      {"level": 3, "target": "Target: 500 - 1,499", "tier": "Gold Tier"},
      {"level": 4, "target": "Target: 1,500 - 4,999", "tier": "Diamond Tier"},
      {"level": 5, "target": "Target: 5,000+", "tier": "Imperial Crown Tier"},
    ];

    return Column(
      children: agencyTiers.map((item) {
        final level = item['level'] as int;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AgencyLevelBadge(level: level),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item['tier'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item['target'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHostBadgesList() {
    final hostTiers = [
      {"level": 1, "target": "Target: 0 - 49h", "tier": "Bronze Host"},
      {"level": 2, "target": "Target: 50 - 149h", "tier": "Silver Host"},
      {"level": 3, "target": "Target: 150 - 299h", "tier": "Gold Host"},
      {"level": 4, "target": "Target: 300 - 499h", "tier": "Diamond Host"},
      {"level": 5, "target": "Target: 500h+", "tier": "Imperial Star Host"},
    ];

    return Column(
      children: hostTiers.map((item) {
        final level = item['level'] as int;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              HostLevelBadge(level: level),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item['tier'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item['target'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSvipBadgesList() {
    final svipTiers = [
      {"level": 1, "req": "5,000 Pts (\$50)", "diamonds": "25K Diamonds / Day"},
      {"level": 2, "req": "10,000 Pts (\$100)", "diamonds": "50K Diamonds / Day"},
      {"level": 3, "req": "20,000 Pts (\$200)", "diamonds": "100K Diamonds / Day"},
      {"level": 4, "req": "50,000 Pts (\$500)", "diamonds": "250K Diamonds / Day"},
      {"level": 5, "req": "100,000 Pts (\$1,000)", "diamonds": "500K Diamonds / Day"},
      {"level": 6, "req": "250,000 Pts (\$2,500)", "diamonds": "1,000,000 Diamonds / Day"},
    ];

    return Column(
      children: svipTiers.map((item) {
        final level = item['level'] as int;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SvipTierBadge(level: level),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item['req'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFFE58F),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item['diamonds'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
