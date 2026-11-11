import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/models/user_model.dart';

/// In-memory session dismissal provider so user is never pestered repeatedly
final passwordReminderDismissedProvider = StateProvider<bool>((ref) => false);

class PasswordMigrationPromptCard extends ConsumerWidget {
  final UserModel userData;

  const PasswordMigrationPromptCard({
    super.key,
    required this.userData,
  });

  Future<void> _dismissPrompt(WidgetRef ref) async {
    // 1. Immediately dismiss in memory
    ref.read(passwordReminderDismissedProvider.notifier).state = true;

    // 2. Persist dismissal for 7 days in Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final dismissUntil = DateTime.now().add(const Duration(days: 7));
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'passwordPromptDismissedUntil': Timestamp.fromDate(dismissUntil),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error saving password prompt dismissal: $e");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Don't show if user already has a password
    if (userData.hasPassword) {
      return const SizedBox.shrink();
    }

    // 2. Don't show if user dismissed it in this session
    final isDismissedInSession = ref.watch(passwordReminderDismissedProvider);
    if (isDismissedInSession) {
      return const SizedBox.shrink();
    }

    // 3. Don't show if user dismissed it previously and the 7-day cooldown hasn't expired
    final dismissedUntil = userData.passwordPromptDismissedUntil;
    if (dismissedUntil != null && dismissedUntil.isAfter(DateTime.now())) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E2638),
            const Color(0xFF131826),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2638).withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFB300).withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8F00).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Quick Password Setup",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.5), width: 0.8),
                          ),
                          child: const Text(
                            "NEW",
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Log in faster with your phone & password without waiting for SMS OTPs.",
                      style: TextStyle(
                        color: Color(0xFFB0B7C3),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _dismissPrompt(ref),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    context.push(
                      AppRoutes.setPassword,
                      extra: {
                        'phone': userData.phoneNumber,
                        'isReset': false,
                        'canSkip': true,
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8F00).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open_rounded, color: Colors.black87, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "Set Up Password",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _dismissPrompt(ref),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    "Remind Me Later",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

