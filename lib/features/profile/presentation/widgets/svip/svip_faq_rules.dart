import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

class SvipFaqRules extends StatelessWidget {
  const SvipFaqRules({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        "q": "How do I earn SVIP Points?",
        "a": "Every \$1.00 USD recharge into your Hello Chat account grants exactly 100 SVIP Points. Points are tracked separately from diamond and bean balances."
      },
      {
        "q": "When does Immediate Upgrade occur?",
        "a": "Whenever your accumulated points reach or exceed a higher tier's threshold, your account is immediately promoted, your 60-day validity cycle is refreshed, and your svipPoints are reset to 0."
      },
      {
        "q": "How does the 60-Day Renewal Evaluation work?",
        "a": "Every 60 days, the system checks points earned during that cycle: Upgrade if higher threshold reached, Maintain if current threshold reached, Downgrade by 1 tier if insufficient, or Expire to regular user if SVIP 1 fails to maintain. Points always reset to 0 after evaluation."
      },
      {
        "q": "How does Voice Room Protection work?",
        "a": "Members with SVIP 4, 5, or 6 (and users who have been granted assigned protection) cannot be kicked out or muted by any room owner, admin, or moderator."
      },
      {
        "q": "When can I claim my Daily Diamonds?",
        "a": "Daily diamonds are claimed once every 24 hours based on Server UTC timestamp. Client device clock changes are strictly ignored by the secure server engine."
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
            children: [
              const Icon(Icons.help_outline_rounded, color: Color(0xFFFFD700), size: 20),
              const Gap(8),
              Text(
                "FREQUENTLY ASKED QUESTIONS",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFFFE58F),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const Gap(12),
          ...faqs.map((faq) => _buildFaqItem(faq["q"]!, faq["a"]!)),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        iconColor: const Color(0xFFFFD700),
        collapsedIconColor: Colors.white54,
        title: Text(
          question,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Text(
            answer,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
