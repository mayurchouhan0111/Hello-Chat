import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../constants/app_colors.dart';

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
      backgroundColor: AppColors.familySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.familyGold, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Member level',
              style: TextStyle(
                color: AppColors.familyText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Gap(20),
            _buildInfoSection(
              '1. Members get rich privileges and rewards by collecting their own combat points.',
            ),
            const Gap(12),
            _buildInfoSection(
              '2. Combat point source:\n'
              'Regular family gifts:\n'
              'For receiving family gifts: 1 bean = 1.0 combat point(s)\n'
              'For sending family gifts: 1 diamond = 1.0 combat point(s)\n'
              'Complete family task to get combat points\n'
              'Premium family gifts:\n'
              'Premium family gifts will have special bonus combat points.',
            ),
            const Gap(24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.familyGold, AppColors.familyGoldLight],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.familyTextSecondary,
        fontSize: 13,
        height: 1.5,
      ),
    );
  }
}
