import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hello_chat/core/providers/profile_provider.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:hello_chat/core/providers/room_provider.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/widgets/app_avatar.dart';
import 'package:hello_chat/services/chat_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ShareRoomSheet extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  const ShareRoomSheet({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  ConsumerState<ShareRoomSheet> createState() => _ShareRoomSheetState();
}

class _ShareRoomSheetState extends ConsumerState<ShareRoomSheet> {
  final List<String> _sentUids = [];

  void _shareExternally(String app) {
    final String shareMessage = "Join my voice room '${widget.roomName}' on Hello Chat! 🎙️\nhttps://hellochat-e8965.web.app/live-room/${widget.roomId}";
    Share.share(shareMessage);
  }

  void _sendToFollower(String followerUid) async {
    final currentUid = ref.read(authStateProvider).value?.uid;
    if (currentUid == null) return;

    setState(() => _sentUids.add(followerUid));

    try {
      final chatService = ref.read(chatServiceProvider);
      final chatId = await chatService.getOrCreateChat(currentUid, followerUid);
      
      await chatService.sendPrivateMessage(
        chatId: chatId,
        senderUid: currentUid,
        receiverUid: followerUid,
        text: "Join my voice room '${widget.roomName}'! 🎙️\nhttps://hellochat-e8965.web.app/live-room/${widget.roomId}",
        type: 'room_invite',
      );
    } catch (e) {
      debugPrint("Failed to send room invite: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Share Room",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // External Sharing Options
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildExternalShareIcon(Icons.share_rounded, "More", Colors.blueAccent, () => _shareExternally("more")),
                _buildExternalShareIcon(Icons.wechat, "WhatsApp", Colors.green, () => _shareExternally("whatsapp")),
                _buildExternalShareIcon(Icons.message_rounded, "Messenger", Colors.blue, () => _shareExternally("messenger")),
                _buildExternalShareIcon(Icons.camera_alt_rounded, "Instagram", Colors.purpleAccent, () => _shareExternally("instagram")),
                _buildExternalShareIcon(Icons.copy_rounded, "Copy Link", Colors.grey, () => _shareExternally("copy")),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10),
          ),
          
          const Text(
            "Share with Followers",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          
          // Followers List
          if (currentUid != null)
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final followersAsync = ref.watch(followersStreamProvider(currentUid));
                  
                  return followersAsync.when(
                    data: (followerUids) {
                      if (followerUids.isEmpty) {
                        return const Center(child: Text("No followers to share with.", style: TextStyle(color: Colors.white54)));
                      }
                      
                      return ListView.builder(
                        itemCount: followerUids.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final fUid = followerUids[index];
                          final userAsync = ref.watch(userProfileProvider(fUid));
                          final isSent = _sentUids.contains(fUid);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: userAsync.when(
                              data: (user) {
                                if (user == null) return const SizedBox.shrink();
                                final u = user as UserModel;
                                
                                return Row(
                                  children: [
                                    AppAvatar(imageUrl: u.profilePhotoUrl, radius: 22, showFrame: false),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        u.displayName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: isSent ? null : () => _sendToFollower(fUid),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSent ? Colors.white10 : const Color(0xFF00E5FF),
                                        foregroundColor: isSent ? Colors.white54 : Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                        minimumSize: const Size(60, 30),
                                      ),
                                      child: Text(isSent ? "Sent" : "Send", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ).animate().fadeIn(delay: (index * 50).ms);
                              },
                              loading: () => const SizedBox(height: 44),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Center(child: Text("Failed to load followers.", style: TextStyle(color: Colors.red))),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExternalShareIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
