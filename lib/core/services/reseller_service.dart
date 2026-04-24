import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_firebase_service.dart';

class ResellerService extends BaseFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> buyDiamondPackage(String packageId) async {
    final result = await callFunction('buyDiamondPackage', {
      'packageId': packageId,
    });
    return castMap(result);
  }

  Future<Map<String, dynamic>> transferDiamonds({
    required String targetHelloId,
    required int amount,
  }) async {
    final result = await callFunction('resellerTransferDiamonds', {
      'targetHelloId': targetHelloId,
      'amount': amount,
    });
    return castMap(result);
  }

  Stream<List<Map<String, dynamic>>> getResellerPackages() {
    return Stream.fromFuture(callFunction('getDiamondPackages', {})).map((result) {
      final data = castMap(result);
      final List packages = data['packages'] ?? [];
      return packages.map((p) => castMap(p)).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getResellerHistory(String uid) {
    return Stream.fromFuture(callFunction('getResellerHistory', {
      'targetUid': uid,
    })).map((result) {
      final data = castMap(result);
      final List txs = data['transactions'] ?? [];
      return txs.map((t) => castMap(t)).toList();
    });
  }
}


final resellerServiceProvider = Provider<ResellerService>((ref) => ResellerService());
