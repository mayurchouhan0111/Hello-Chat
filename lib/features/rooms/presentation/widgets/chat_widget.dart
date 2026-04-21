import 'package:flutter/material.dart';
import '../../../../core/models/message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';


class ChatWidget extends ConsumerWidget {
  final List<RoomMessage> messages;

  const ChatWidget({super.key, required this.messages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Get current user's blocked IDs
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final myProfileAsync = ref.watch(userProfileProvider(currentUid ?? ''));

    return myProfileAsync.when(
      data: (myProfile) {
        final blocked = (myProfile != null && myProfile is UserModel) 
            ? myProfile.blockedUids 
            : <String>[];
        
        // 2. Filter messages
        final visibleMessages = messages.where((m) => !blocked.contains(m.uid)).toList();


        return ListView.builder(
          reverse: true,
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: visibleMessages.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (context, index) {
            final msg = visibleMessages[index];
            return _buildMessageTile(ref, msg);
          },
        );
      },
      loading: () => _buildBasicList(ref, messages),
      error: (_, __) => _buildBasicList(ref, messages),
    );
  }

  Widget _buildBasicList(WidgetRef ref, List<RoomMessage> msgs) {
    return ListView.builder(
      reverse: true,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: msgs.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final msg = msgs[index];
        return _buildMessageTile(ref, msg);
      },
    );
  }


  Widget _buildMessageTile(WidgetRef ref, RoomMessage msg) {
    if (msg.type == 'system' || msg.type == 'gift') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
          child: Text(
            msg.text,
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final userAsync = ref.watch(userProfileProvider(msg.uid));
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: userAsync.when(
        data: (user) {
          final u = user as UserModel;
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                     margin: const EdgeInsets.only(top: 1),
                     padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                     decoration: BoxDecoration(
                       gradient: const LinearGradient(colors: [Color(0xFFFFF176), Color(0xFFFFD700)]),
                       borderRadius: BorderRadius.circular(6),
                     ),
                     child: Text("Lv.${u.level}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                   ),
                   const SizedBox(width: 8),
                   Flexible(
                     child: RichText(
                       text: TextSpan(
                         children: [
                           TextSpan(
                             text: "${u.displayName}: ",
                             style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 13, fontWeight: FontWeight.bold),
                           ),
                           TextSpan(
                             text: msg.text,
                             style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                           ),
                         ],
                       ),
                     ),
                   ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
      ),
    );
  }
}
