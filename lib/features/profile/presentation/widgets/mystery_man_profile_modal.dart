import 'package:flutter/material.dart';

class MysteryManProfileModal extends StatelessWidget {
  const MysteryManProfileModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const MysteryManProfileModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.visibility_off_rounded,
              size: 48,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mystery Man',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.black,
              fontSize: 22,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This user\'s profile is hidden.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personal details, badges, followers, gifts, and family details are concealed by SVIP Profile Hide privileges.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'CLOSE',
                style: TextStyle(fontWeight: FontWeight.black, letterSpacing: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
