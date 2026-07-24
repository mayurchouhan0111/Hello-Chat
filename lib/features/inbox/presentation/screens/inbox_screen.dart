import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello_chat/core/constants/app_colors.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _getInboxMessagesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint("[INBOX_DEBUG] Firebase UID: ${uid ?? 'null'}");
    if (uid == null) {
      debugPrint("[INBOX_DEBUG] No authenticated user — returning empty stream");
      return const Stream.empty();
    }
    final path = 'users/$uid/inbox_messages';
    debugPrint("[INBOX_DEBUG] Listening to collection: $path");
    debugPrint("[INBOX_DEBUG] Query: orderBy('createdAt', descending: true), limit(50)");
    return _db
        .collection('users')
        .doc(uid)
        .collection('inbox_messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _markAsRead(String msgId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('inbox_messages')
          .doc(msgId)
          .update({'read': true});
    } catch (e) {
      debugPrint("Error marking inbox message as read: $e");
    }
  }

  void _showDetailDialog(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String title = data['title'] ?? 'Notification';
    final String body = data['body'] ?? '';
    final dynamic rawTime = data['createdAt'];
    final DateTime timestamp = rawTime is Timestamp ? rawTime.toDate() : DateTime.now();
    final String type = data['type'] ?? 'system';
    final Map<String, dynamic> extraData = data['data'] ?? {};
    final String? actionRoute = extraData['route'];

    // Mark as read immediately on open
    if (!(data['read'] as bool? ?? false)) {
      _markAsRead(doc.id);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Header
              Center(
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _getTypeColor(type).withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(_getTypeIcon(type), color: _getTypeColor(type), size: 28),
                ),
              ),
              const Gap(16),
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
              ),
              const Gap(6),
              // Time
              Text(
                timeago.format(timestamp, locale: 'en'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const Gap(20),
              // Body
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              const Gap(24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        foregroundColor: Colors.grey.shade700,
                      ),
                      child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                    ),
                  ),
                  if (actionRoute != null && actionRoute.isNotEmpty) ...[
                    const Gap(12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(actionRoute);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("VIEW DETAILS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'reward':
        return const Color(0xFFD97706); // Amber Gold
      case 'broadcast':
        return const Color(0xFF0284C7); // Light Cyan Blue
      case 'system':
      default:
        return AppColors.primary; // Primary Purple/Indigo
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'reward':
        return Icons.card_giftcard_rounded;
      case 'broadcast':
        return Icons.campaign_rounded;
      case 'system':
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.3),
        ),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _getInboxMessagesStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final unreadCount = snapshot.data!.docs
                  .where((d) => !(d.data()['read'] as bool? ?? false))
                  .length;
              if (unreadCount == 0) return const SizedBox.shrink();
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$unreadCount UNREAD",
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getInboxMessagesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError) {
            final err = snapshot.error.toString();
            debugPrint("[INBOX_DEBUG] Firestore error: $err");
            final bool isPermissionDenied = err.contains('permission-denied') || err.contains('PERMISSION_DENIED');
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: (isPermissionDenied ? Colors.orange : Colors.red).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: (isPermissionDenied ? Colors.orange : Colors.red).withOpacity(0.2)),
                      ),
                      child: Icon(
                        isPermissionDenied ? Icons.lock_outline_rounded : Icons.error_outline_rounded,
                        size: 40,
                        color: isPermissionDenied ? Colors.orange : Colors.red,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      isPermissionDenied ? "Access Denied" : "Something went wrong",
                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const Gap(8),
                    Text(
                      isPermissionDenied
                          ? "You don't have permission to view your inbox. Please try logging in again."
                          : "Could not load your inbox. Please try again later.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                    ),
                    const Gap(24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text("RETRY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.primary),
                  ),
                  const Gap(16),
                  const Text("No notifications yet", style: TextStyle(color: Colors.black45, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Gap(10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final String title = data['title'] ?? 'System Message';
              final String body = data['body'] ?? '';
              final dynamic rawTime = data['createdAt'];
              final DateTime timestamp = rawTime is Timestamp ? rawTime.toDate() : DateTime.now();
              final String type = data['type'] ?? 'system';
              final bool isRead = data['read'] as bool? ?? false;

              final Color color = _getTypeColor(type);

              return GestureDetector(
                onTap: () => _showDetailDialog(context, doc),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isRead ? Colors.black.withOpacity(0.04) : AppColors.primary.withOpacity(0.3),
                      width: isRead ? 1 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Circle Icon
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(isRead ? 0.08 : 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withOpacity(isRead ? 0.15 : 0.4), width: 1),
                        ),
                        child: Icon(_getTypeIcon(type), color: color, size: 18),
                      ),
                      const Gap(12),
                      // Text Contents
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isRead ? Colors.black87 : Colors.black,
                                      fontSize: 14,
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Gap(8),
                                Text(
                                  timeago.format(timestamp, locale: 'en_short'),
                                  style: TextStyle(
                                    color: isRead ? Colors.grey : Colors.black45,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(4),
                            Text(
                              body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isRead ? Colors.black45 : Colors.black87,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 300.ms, delay: Duration(milliseconds: 30 * index)).slideX(begin: 0.1, duration: 300.ms, delay: Duration(milliseconds: 30 * index));
            },
          );
        },
      ),
    );
  }
}
