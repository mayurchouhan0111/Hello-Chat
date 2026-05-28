import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';

class PrivateChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUid;

  const PrivateChatScreen({
    super.key, 
    required this.chatId, 
    required this.otherUid,
  });

  @override
  ConsumerState<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends ConsumerState<PrivateChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      ref.read(chatServiceProvider).markAsRead(widget.chatId, currentUid);
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    // Reset typing state
    if (_isTyping) setState(() => _isTyping = false);

    await ref.read(chatServiceProvider).sendPrivateMessage(
      chatId: widget.chatId, 
      senderUid: currentUid, 
      receiverUid: widget.otherUid, 
      text: text,
    );

    _msgController.clear();
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    _markRead();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.otherUid));
    final messagesAsync = ref.watch(privateMessagesStreamProvider(widget.chatId));
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background, // Hello Chat primary background
      appBar: AppBar(
        backgroundColor: AppColors.primary, // Hello Chat Brand Purple
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: profileAsync.when(
          data: (user) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(user?.displayName ?? "Hello Chat User", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)), // Compacted
               const Text("online", style: TextStyle(color: Colors.white70, fontSize: 9)), // Compacted
            ],
          ),
          loading: () => const Text("Loading...", style: TextStyle(color: Colors.white, fontSize: 14)),
          error: (_, __) => const Text("User", style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
        actions: [
          profileAsync.maybeWhen(
            data: (user) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CircleAvatar(
                radius: 15,
                backgroundImage: (user?.profilePhotoUrl ?? '').isNotEmpty 
                  ? CachedNetworkImageProvider(user!.profilePhotoUrl) 
                  : null,
                child: (user?.profilePhotoUrl ?? '').isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 16) : null,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          // CUSTOM HELLO CHAT PATTERN BACKGROUND
          Positioned.fill(
            child: CustomPaint(
              painter: ChatBackgroundPainter(),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  data: (messages) => _buildMessageList(messages, currentUid),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, __) {
                    debugPrint("Chat Error: $e");
                    return _buildMessageList([], currentUid);
                  },
                ),
              ),
              SafeArea(child: _buildInputArea()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Map<String, dynamic>> messages, String? currentUid) {
    if (messages.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.yellow[200]!),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 14, color: Colors.black54),
              SizedBox(width: 8),
              Text("Messages are end-to-end encrypted", style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isMe = msg['senderUid'] == currentUid;
        
        // Date Grouping logic (simplified)
        bool showDate = false;
        if (index == messages.length - 1) {
          showDate = true;
        } else {
          final currentMsgDate = (msg['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          final nextMsgDate = (messages[index + 1]['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
          if (currentMsgDate.day != nextMsgDate.day) {
            showDate = true;
          }
        }

        return Column(
          children: [
            if (showDate) _buildDateHeader(msg['timestamp'] as Timestamp?),
            _buildMessageBubble(msg, isMe),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(Timestamp? timestamp) {
    final date = timestamp?.toDate() ?? DateTime.now();
    String dateStr = timeago.format(date);
    if (date.day == DateTime.now().day) dateStr = "TODAY";
    else if (date.day == DateTime.now().subtract(const Duration(days: 1)).day) dateStr = "YESTERDAY";
    else dateStr = "${date.day}/${date.month}/${date.year}";

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFD1E4F5).withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(dateStr, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black54)),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final timestamp = (msg['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeStr = "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}";
    
    if (msg['type'] == 'room_invite') {
      return _buildRoomInviteBubble(msg, isMe, timeStr);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 4,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20), // More rounded for "cute"
          boxShadow: const [], // Strictly NO shadow
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                msg['text'] ?? "",
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87, 
                  fontSize: 13, // Reduced from 15.5
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[500], fontSize: 9), // Compact
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg['isRead'] == true ? Icons.done_all : Icons.done,
                    size: 12,
                    color: msg['isRead'] == true ? AppColors.diamond : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomInviteBubble(Map<String, dynamic> msg, bool isMe, String timeStr) {
    final text = msg['text'] as String? ?? "";
    final lines = text.split('\n');
    final inviteText = lines.first;
    String? roomId;
    if (lines.length > 1) {
       final url = lines.last;
       if (url.contains('/live-room/')) {
         roomId = url.split('/live-room/').last;
       } else if (url.contains('/room/')) {
         roomId = url.split('/room/').last; // Backwards compatibility
       }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 4,
          left: isMe ? 40 : 0,
          right: isMe ? 0 : 40,
        ),
        width: 240,
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary.withOpacity(0.9) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? Colors.transparent : Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.white10 : Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white24 : AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.headset_mic_rounded, color: isMe ? Colors.white : AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      inviteText,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (roomId != null)
              GestureDetector(
                onTap: () => context.push('/live-room/$roomId'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "JOIN ROOM",
                    style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[500], fontSize: 9),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg['isRead'] == true ? Icons.done_all : Icons.done,
                      size: 12,
                      color: msg['isRead'] == true ? AppColors.diamond : Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 20),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      onChanged: (val) {
                        if (val.isNotEmpty && !_isTyping) setState(() => _isTyping = true);
                        if (val.isEmpty && _isTyping) setState(() => _isTyping = false);
                      },
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: "Message",
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey, size: 20),
                    onPressed: () {},
                  ),
                  if (!_isTyping)
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.grey, size: 20),
                      onPressed: () {},
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: CircleAvatar(
              radius: 20, // Reduced from 24
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 18, // Reduced
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 80;
    final List<IconData> icons = [
      Icons.favorite_outline_rounded,
      Icons.chat_bubble_outline_rounded,
      Icons.star_outline_rounded,
      Icons.diamond_outlined,
      Icons.emoji_emotions_outlined,
    ];

    int iconIndex = 0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icons[iconIndex % icons.length].codePoint),
            style: TextStyle(
              fontSize: 22,
              fontFamily: icons[iconIndex % icons.length].fontFamily,
              package: icons[iconIndex % icons.length].fontPackage,
              color: AppColors.primary.withOpacity(0.04), // Branded color
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        // Artistic rotation and placement
        canvas.save();
        canvas.translate(x + 20, y + 20);
        canvas.rotate(0.2); 
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
        
        iconIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
