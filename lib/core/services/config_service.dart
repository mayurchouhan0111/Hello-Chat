import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfigModel {
  final bool isMaintenance;
  final Map<String, dynamic> currency;
  final Map<String, dynamic> salary;

  AppConfigModel({
    required this.isMaintenance,
    required this.currency,
    required this.salary,
  });

  factory AppConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppConfigModel(
      isMaintenance: data['isMaintenance'] ?? false,
      currency: data['currency'] ?? {},
      salary: data['salary'] ?? {},
    );
  }
}

final configServiceProvider = Provider((ref) => ConfigService());

final globalConfigProvider = StreamProvider<AppConfigModel>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('global')
      .snapshots()
      .map((doc) => AppConfigModel.fromFirestore(doc));
});

class ConfigService {
  final _db = FirebaseFirestore.instance;

  Future<void> updateConfig(Map<String, dynamic> data) async {
    await _db.collection('app_config').doc('global').set(data, SetOptions(merge: true));
  }
}
