import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dino_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DinoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<DinoModel?> getDinoStream(String uid) {
    return _db.collection('users').doc(uid).collection('pet').doc('dino')
      .snapshots()
      .map((doc) => doc.exists ? DinoModel.fromMap(doc.data()!, doc.id) : null);
  }

  Future<void> initializeDino(String uid) async {
    final petRef = _db.collection('users').doc(uid).collection('pet').doc('dino');
    final doc = await petRef.get();
    if (!doc.exists) {
      await petRef.set({
        'ownerUid': uid,
        'name': 'Little Dino',
        'type': 'T-Rex',
        'level': 1,
        'xp': 0,
        'health': 1.0,
        'energy': 1.0,
        'lastFed': FieldValue.serverTimestamp(),
        'lastPlayed': FieldValue.serverTimestamp(),
        'stage': 'Egg',
      });
    }
  }

  Future<void> feedDino(String uid) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('interactWithDino');
      await callable.call({'action': 'feed'});
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? "Failed to feed pet";
    }
  }

  Future<void> playWithDino(String uid) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('interactWithDino');
      await callable.call({'action': 'play'});
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? "Failed to play with pet";
    }
  }
}
