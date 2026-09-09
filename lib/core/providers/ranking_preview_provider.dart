import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider to fetch top 3 images for a specific field and collection
final topRankedAvatarsProvider = StreamProvider.family<List<String>, ({String collection, String field})>((ref, arg) {
  return FirebaseFirestore.instance
      .collection(arg.collection)
      .orderBy(arg.field, descending: true)
      .limit(6)
      .snapshots()
      .map((snap) {
        final urls = snap.docs.map((doc) {
          final data = doc.data();
          if (arg.collection == 'rooms') {
            return data['coverUrl'] as String? ?? "";
          }
          return data['profilePhotoUrl'] as String? ?? "";
        }).where((url) => url.isNotEmpty).take(3).toList();
        return urls;
      });
});
