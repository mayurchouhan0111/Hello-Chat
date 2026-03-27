import 'package:flutter/material.dart';
import '../../../../core/models/message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/user_model.dart';

class ChatWidget extends ConsumerWidget {
  final List<RoomMessage> messages;

  const ChatWidget({super.key, required this.messages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      reverse: true, // Newest at bottom
      shrinkWrap: true,
      itemCount: messages.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final msg = messages[index];
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
            style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
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
                       gradient: const LinearGradient(colors: [Color(0xFFFFB75E), Color(0xFFED8F03)]),
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
