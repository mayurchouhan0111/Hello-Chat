import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/message_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Room Messages (Existing) ---
  Stream<List<RoomMessage>> getMessagesStream(String roomId) {
    return _db.collection('rooms').doc(roomId).collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => RoomMessage.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> sendTextMessage(String roomId, String uid, String text) async {
    await _db.collection('rooms').doc(roomId).collection('messages').add({
      'uid': uid,
      'text': text,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendStickerMessage(String roomId, String uid, String stickerPath) async {
    await _db.collection('rooms').doc(roomId).collection('messages').add({
      'uid': uid,
      'text': stickerPath,
      'type': 'sticker',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendSystemMessage(String roomId, String text) async {
    await _db.collection('rooms').doc(roomId).collection('messages').add({
      'uid': 'system',
      'text': text,
      'type': 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Private Messaging (New) ---

  // Get or Create Chat between two users
  Future<String> getOrCreateChat(String uid1, String uid2) async {
    final chatId = uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
    final chatRef = _db.collection('chats').doc(chatId);
    
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      await chatRef.set({
        'chatId': chatId,
        'participants': [uid1, uid2],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': {uid1: 0, uid2: 0},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  Stream<List<Map<String, dynamic>>> getChatListStream(String uid) {
    return _db.collection('chats')
      .where('participants', arrayContains: uid)
      .orderBy('lastMessageTime', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Map<String, dynamic>>> getPrivateMessagesStream(String chatId) {
    return _db.collection('chats').doc(chatId).collection('messages')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> sendPrivateMessage({
    required String chatId,
    required String senderUid,
    required String receiverUid,
    required String text,
    String type = 'text',
  }) async {
    // 1. Enforcement Test: Check for mutual blocks
    final senderDoc = await _db.collection('users').doc(senderUid).get();
    final receiverDoc = await _db.collection('users').doc(receiverUid).get();

    final List senderBlocked = (senderDoc.data()?['blockedUids'] ?? []) as List;
    final List receiverBlocked = (receiverDoc.data()?['blockedUids'] ?? []) as List;

    if (senderBlocked.contains(receiverUid)) {
      throw Exception("You have blocked this user. Unblock them to send a message.");
    }
    if (receiverBlocked.contains(senderUid)) {
      throw Exception("You cannot send messages to this user.");
    }

    final batch = _db.batch();
    final chatRef = _db.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    // 2. Add Message
    batch.set(messageRef, {
      'messageId': messageRef.id,
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'text': text,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // 3. Update Chat Head
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCounts.$receiverUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> markAsRead(String chatId, String uid) async {
    await _db.collection('chats').doc(chatId).update({
      'unreadCounts.$uid': 0,
    });
  }
}
