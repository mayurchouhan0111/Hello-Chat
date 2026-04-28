import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/providers/auth_provider.dart';
import 'room_provider.dart';

final chatListStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return Stream.value([]);
  
  return ref.watch(chatServiceProvider).getChatListStream(uid);
});

final privateMessagesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, chatId) {
  return ref.watch(chatServiceProvider).getPrivateMessagesStream(chatId);
});

final unreadTotalProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return Stream.value(0);

  return ref.watch(chatServiceProvider).getChatListStream(uid).map((chats) {
    int total = 0;
    for (var chat in chats) {
      final counts = chat['unreadCounts'] as Map<String, dynamic>?;
      total += (counts?[uid] as int? ?? 0);
    }
    return total;
  });
});
