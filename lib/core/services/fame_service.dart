import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fame_model.dart';

class FameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ranks users by Beans received for the selected period.
  ///
  /// Reads the cosmetic `publicUsers` projection: `/users` is hierarchy-locked
  /// by Firestore rules, so querying it for other accounts fails.
  Stream<List<FameEntry>> streamTopFame(FamePeriod period, {int limit = 50}) {
    return _db
        .collection('publicUsers')
        .orderBy(period.field, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => FameEntry.fromMap(
                doc.id,
                doc.data(),
                pointsField: period.field,
              ))
          .where((entry) => entry.points > 0)
          .toList();
      FameEntry.sortByRank(entries);
      return entries;
    });
  }
}
