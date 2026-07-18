import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final activeRechargeEventProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return FirebaseFirestore.instance
      .collection('recharge_bonus_events')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    
    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final start = (data['startDate'] as Timestamp?)?.toDate();
      final end = (data['endDate'] as Timestamp?)?.toDate();
      
      // Validation: Hide if expired or not started yet
      if (start != null && end != null) {
        if (now.isAfter(start) && now.isBefore(end)) {
          return {
            'id': doc.id,
            ...data,
          };
        }
      }
    }
    return null;
  });
});

final rechargeEventPackagesProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) {
  return FirebaseFirestore.instance
      .collection('recharge_bonus_packages')
      .where('eventId', isEqualTo: eventId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
    
    // Validation: Sort by sortOrder ascending, prevent negative values
    list.sort((a, b) {
      final sa = (a['sortOrder'] as num?)?.toInt() ?? 0;
      final sb = (b['sortOrder'] as num?)?.toInt() ?? 0;
      return sa.compareTo(sb);
    });
    
    return list;
  });
});
