import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

class SvipTierMatrixTable extends StatelessWidget {
  const SvipTierMatrixTable({super.key});

  static const Color darkBg = Color(0xFF070604);
  static const Color cardBg = Color(0xFF13100B);
  static const Color tableRowBgEven = Color(0xFF1B1710);
  static const Color tableRowBgOdd = Color(0xFF13100B);
  static const Color borderGold = Color(0xFF4A3A16);
  static const Color textGoldHeader = Color(0xFFF7E7B4);
  static const Color textGoldSub = Color(0xFFD8B65C);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGold, width: 1.2),
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
              const Icon(Icons.table_chart_rounded, color: Color(0xFFFFD700), size: 20),
              const Gap(8),
              Text(
                "SVIP TIER REQUIREMENTS & PRIVILEGES",
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFFFE58F),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const Gap(14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FixedColumnWidth(80),
                  1: FixedColumnWidth(100),
                  2: FixedColumnWidth(80),
                  3: FixedColumnWidth(130),
                  4: FixedColumnWidth(130),
                  5: FixedColumnWidth(120),
                  6: FixedColumnWidth(130),
                  7: FixedColumnWidth(120),
                },
                children: [
                  _buildHeaderRow(),
                  _buildDataRow("SVIP 1", "5,000", "\$50", "25,000", "No", "No", "24h (5 IDs)", false),
                  _buildDataRow("SVIP 2", "10,000", "\$100", "50,000", "No", "No", "72h (7 IDs)", true),
                  _buildDataRow("SVIP 3", "20,000", "\$200", "100,000", "No", "2 IDs", "7 Days", false),
                  _buildDataRow("SVIP 4", "50,000", "\$500", "250,000", "Kick & Mute", "Self Hidden", "30 Days", true),
                  _buildDataRow("SVIP 5", "100,000", "\$1,000", "500,000", "Kick & Mute + 5 Users", "+2 IDs", "Permanent", false),
                  _buildDataRow("SVIP 6", "250,000", "\$2,500", "1,000,000", "Global Kick + 10 Users", "+10 IDs", "Permanent", true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF382A0F), Color(0xFF261C0A)],
        ),
      ),
      children: [
        _buildHeaderCell("Level"),
        _buildHeaderCell("Points"),
        _buildHeaderCell("Recharge"),
        _buildHeaderCell("Daily Diamonds"),
        _buildHeaderCell("Room Protection"),
        _buildHeaderCell("Friend Hide"),
        _buildHeaderCell("Temp / CP Lock"),
        _buildHeaderCell("Validity"),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: textGoldHeader,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  TableRow _buildDataRow(
    String tier,
    String points,
    String recharge,
    String diamonds,
    String protection,
    String friendHide,
    String other,
    bool isEven,
  ) {
    final isTopTier = tier == "SVIP 6";
    final bg = isEven ? tableRowBgEven : tableRowBgOdd;

    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Text(
            tier,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              color: isTopTier ? const Color(0xFFFFD700) : textGoldSub,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildDataCell(points),
        _buildDataCell(recharge, color: const Color(0xFF10B981)),
        _buildDataCell(diamonds, color: const Color(0xFF00E5FF)),
        _buildDataCell(protection),
        _buildDataCell(friendHide),
        _buildDataCell(other),
        _buildDataCell("60 Days", color: Colors.amberAccent),
      ],
    );
  }

  Widget _buildDataCell(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: color ?? Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
