import 'package:hello_chat/core/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/services/room_service.dart';
import 'package:hello_chat/services/voice_service.dart';
import 'package:hello_chat/services/agora_voice_service.dart';
import 'package:hello_chat/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/models/participant_model.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/core/models/room_banner_model.dart';

final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final voice = AgoraVoiceService();
  voice.initialize();
  ref.onDispose(() => voice.dispose());
  return voice;
});

final discoveryStreamProvider = StreamProvider<List<RoomModel>>((ref) {
  return ref.watch(roomServiceProvider).getRoomsDiscoveryStream();
});

final currentRoomStreamProvider = StreamProvider.family<RoomModel?, String>((ref, roomId) {
  return ref.watch(roomServiceProvider).getRoomStream(roomId);
});

final roomParticipantsProvider = StreamProvider.family<List<Participant>, String>((ref, roomId) {
  return ref.watch(roomServiceProvider).getParticipantsStream(roomId);
});

final isSpeakingProvider = StreamProvider<bool>((ref) {
  return ref.watch(voiceServiceProvider).isSpeakingStream;
});

final speakingUidsProvider = StreamProvider<List<int>>((ref) {
  return ref.watch(voiceServiceProvider).speakingUidsStream;
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final roomMessagesProvider = StreamProvider.family<List<RoomMessage>, String>((ref, roomId) {
  return ref.watch(chatServiceProvider).getMessagesStream(roomId);
});

final userActiveRoomStreamProvider = StreamProvider<RoomModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  
  return FirebaseFirestore.instance
      .collection('rooms')
      .where('ownerUid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'active')
      .limit(1)
      .snapshots()
      .map((snapshot) => snapshot.docs.isNotEmpty 
          ? RoomModel.fromFirestore(snapshot.docs.first) 
          : null);
});

final roomBannersProvider = StreamProvider<List<RoomBannerModel>>((ref) {
  return ref.watch(roomServiceProvider).getRoomBannersStream();
});

final roomMicRequestsProvider = StreamProvider.family<List<String>, String>((ref, roomId) {
  return FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('micRequests')
    .snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
});
