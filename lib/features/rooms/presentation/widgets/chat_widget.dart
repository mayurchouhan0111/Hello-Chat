import 'package:flutter/material.dart';
import '../../../../core/models/message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/broadcast_service.dart';


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


        final broadcasts = ref.watch(activeBroadcastsProvider).value ?? [];
        final hasBroadcast = broadcasts.isNotEmpty;

        return ListView.builder(
          reverse: true,
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: visibleMessages.length + (hasBroadcast ? 1 : 0),
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
          itemBuilder: (context, index) {
            if (hasBroadcast && index == visibleMessages.length) {
              return _buildBroadcastTile(broadcasts.first.message);
            }
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
    final broadcasts = ref.watch(activeBroadcastsProvider).value ?? [];
    final hasBroadcast = broadcasts.isNotEmpty;

    return ListView.builder(
      reverse: true,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: msgs.length + (hasBroadcast ? 1 : 0),
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
      itemBuilder: (context, index) {
        if (hasBroadcast && index == msgs.length) {
          return _buildBroadcastTile(broadcasts.first.message);
        }
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
                color: Colors.black.withOpacity(0.5),
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

  Widget _buildBroadcastTile(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF673AB7).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
      ),
    );
  }
}
