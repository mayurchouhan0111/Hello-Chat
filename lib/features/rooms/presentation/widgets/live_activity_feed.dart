import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import '../../../../core/models/message_model.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';

class LiveActivityFeed extends ConsumerWidget {
  final List<RoomMessage> messages;
  const LiveActivityFeed({super.key, required this.messages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter last 5 messages to keep it clean, focusing on gifts/actions
    final displayMessages = messages.reversed.toList();

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Double Points Banner (Keep this as a seasonal/event banner as requested)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C6FF).withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on, color: Colors.yellow, size: 16),
                const Gap(8),
                const Text(
                  "First Gift: Double PK Points",
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const Gap(8),
                const Text("| ACTIVE", style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ).animate().slideX(begin: -1, end: 0, duration: 400.ms),
          
          const Gap(12),
          
          // Real-time scrolling notifications
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: displayMessages.length,
              itemBuilder: (context, index) {
                final msg = displayMessages[index];
                return _buildDynamicNotification(ref, msg);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicNotification(WidgetRef ref, RoomMessage msg) {
    if (msg.type == 'system') {
      return _buildNotificationBody(msg.text, Colors.yellowAccent.withOpacity(0.7));
    }

    // For text or gift, we might want the user's name
    final userAsync = ref.watch(userProfileProvider(msg.uid));
    
    return userAsync.when(
      data: (user) {
        final userData = user as UserModel?;
        final name = userData?.displayName ?? "User";
        
        String displayText = "";
        Color color = Colors.white70;

        if (msg.type == 'gift') {
          displayText = "$name sent a gift 🎁";
          color = const Color(0xFF00E5FF);
        } else {
          displayText = "$name: ${msg.text}";
          color = Colors.white70;
        }

        return _buildNotificationBody(displayText, color);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildNotificationBody(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }
}
