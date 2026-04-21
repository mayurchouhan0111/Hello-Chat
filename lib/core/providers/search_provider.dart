import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';

final searchQueryProvider = StateProvider<String>((ref) => "");

final searchUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  if (query.isEmpty) return Stream.value([]);

  // 1. Direct ID Search (UID or HelloID)
  final isNumeric = int.tryParse(query) != null;
  
  Stream<List<UserModel>> idStream;
  if (isNumeric) {
    idStream = FirebaseFirestore.instance
        .collection('users')
        .where('helloId', isEqualTo: int.parse(query))
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  } else {
    idStream = FirebaseFirestore.instance
        .collection('users')
        .doc(query)
        .snapshots()
        .map((doc) => doc.exists ? [UserModel.fromFirestore(doc)] : <UserModel>[]);
  }

  // 2. Name Search (Prefix)
  final nameStream = FirebaseFirestore.instance
      .collection('users')
      .where('displayName_lowercase', isGreaterThanOrEqualTo: query)
      .where('displayName_lowercase', isLessThanOrEqualTo: '$query\uf8ff')
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList());

  // Priority logic
  if (isNumeric && query.length >= 8) return idStream; // Numeric IDs are usually 8-10 digits
  if (query.length > 20) return idStream; // Long complex UID
  
  return nameStream;
});

final searchRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  if (query.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('rooms')
      .where('name_lowercase', isGreaterThanOrEqualTo: query)
      .where('name_lowercase', isLessThanOrEqualTo: '$query\uf8ff')
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => RoomModel.fromFirestore(doc)).toList());
});
