import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class MemberLevelInfoDialog extends StatelessWidget {
  const MemberLevelInfoDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const MemberLevelInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.military_tech_rounded,
                  color: Color(0xFFD97706),
                  size: 28,
                ),
              ),
              const Gap(12),
              const Text(
                'Member Level Rules',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const Gap(16),
              _buildInfoCard(
                title: 'Combat Privileges',
                content: 'Members unlock rich privileges, clan combat bonuses, and elite rewards by raising their individual combat power.',
              ),
              const Gap(10),
              _buildInfoCard(
                title: 'How to Earn Combat Points (CP)',
                content: '• Receive Clan Gifts: 1 Bean = 1.0 CP\n'
                    '• Send Clan Gifts: 1 Diamond = 1.0 CP\n'
                    '• Complete Daily Clan Tasks for bonus CP\n'
                    '• Premium gifts grant special multiplier CP.',
              ),
              const Gap(20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Understood',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(4),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
