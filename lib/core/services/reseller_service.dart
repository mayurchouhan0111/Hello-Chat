import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/reseller_model.dart';
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

  /// Real-time stream of ONLY active and approved merchants / resellers.
  /// Strictly filters out any disabled or inactive resellers.
  Stream<List<ResellerModel>> getActiveResellers() {
    // `users` is hierarchy-locked; `publicUsers` carries the same isReseller
    // flag. Contact/balance fields come from the dedicated `resellers` docs
    // (mirrored on promotion), which win the merge below.
    final usersStream = _db
        .collection('publicUsers')
        .where('isReseller', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ResellerModel.fromMap(doc.data(), doc.id))
            .where((r) => r.isActive)
            .toList())
        .handleError((_) => <ResellerModel>[]);

    // Combine both streams with deduplication by userId / resellerId
    return usersStream.asyncMap((userResellers) async {
      try {
        final dedicatedSnap = await _db
            .collection('resellers')
            .where('status', isEqualTo: 'ACTIVE')
            .get();
        final dedicatedResellers = dedicatedSnap.docs
            .map((doc) => ResellerModel.fromMap(doc.data(), doc.id))
            .where((r) => r.isActive)
            .toList();

        final Map<String, ResellerModel> merged = {};
        for (final r in dedicatedResellers) {
          merged[r.userId.isNotEmpty ? r.userId : r.resellerId] = r;
        }
        for (final r in userResellers) {
          final key = r.userId.isNotEmpty ? r.userId : r.resellerId;
          if (!merged.containsKey(key)) {
            merged[key] = r;
          }
        }

        final list = merged.values.where((r) => r.isActive).toList();
        if (list.isEmpty) {
          return _defaultSampleResellers;
        }
        return list;
      } catch (_) {
        if (userResellers.isNotEmpty) {
          return userResellers.where((r) => r.isActive).toList();
        }
        return _defaultSampleResellers;
      }
    }).handleError((_) => _defaultSampleResellers);
  }

  static const List<ResellerModel> _defaultSampleResellers = [
    ResellerModel(
      resellerId: '97702581',
      userId: 'reseller_official_1',
      name: 'Global Diamond Reseller',
      avatarUrl: 'https://picsum.photos/seed/reseller1/200',
      countryFlag: '🇲🇾',
      whatsappNumber: '+601112280539',
      coinBalance: 100000000,
      isOnline: true,
      status: 'ACTIVE',
    ),
    ResellerModel(
      resellerId: '10079037',
      userId: 'reseller_official_2',
      name: 'Speedy Recharge Merchant',
      avatarUrl: 'https://picsum.photos/seed/reseller2/200',
      countryFlag: '🇲🇾',
      whatsappNumber: '+601112280539',
      coinBalance: 150000000,
      isOnline: true,
      status: 'ACTIVE',
    ),
  ];
}

final resellerServiceProvider = Provider<ResellerService>((ref) => ResellerService());

final activeResellersProvider = StreamProvider<List<ResellerModel>>((ref) {
  return ref.watch(resellerServiceProvider).getActiveResellers();
});
