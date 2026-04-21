import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/agency_model.dart';
import '../models/user_model.dart';

class AgencyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // 1. Create an Agency
  Future<void> createAgency(String name, String description, String logoUrl) async {
    if (_uid == null) throw Exception("User not authenticated");

    final userDoc = await _db.collection('users').doc(_uid).get();
    final userData = UserModel.fromMap(userDoc.data()!);

    if (userData.agencyId != null) throw Exception("User already belongs to an agency");

    final agencyRef = _db.collection('agencies').doc();
    final agency = AgencyModel(
      id: agencyRef.id,
      name: name,
      ownerUid: _uid!,
      ownerName: userData.displayName,
      logoUrl: logoUrl,
      description: description,
      hostUids: [_uid!], // Owner is the first host
      createdAt: DateTime.now(),
      commissionRate: 0.1, // Default 10%
    );

    await _db.runTransaction((transaction) async {
      transaction.set(agencyRef, agency.toMap());
      transaction.update(_db.collection('users').doc(_uid), {
        'agencyId': agencyRef.id,
        'isAgencyOwner': true,
      });
    });
  }

  // 2. Join an Agency (Invite-only usually, but for now simple)
  Future<void> joinAgency(String agencyId) async {
    if (_uid == null) throw Exception("User not authenticated");

    await _db.runTransaction((transaction) async {
      final userRef = _db.collection('users').doc(_uid);
      final agencyRef = _db.collection('agencies').doc(agencyId);

      final userDoc = await transaction.get(userRef);
      if (userDoc.data()?['agencyId'] != null) throw Exception("User already in an agency");

      transaction.update(agencyRef, {
        'hostUids': FieldValue.arrayUnion([_uid]),
      });
      transaction.update(userRef, {
        'agencyId': agencyId,
        'isAgencyOwner': false,
      });
    });
  }

  // 3. Leave Agency
  Future<void> leaveAgency() async {
    if (_uid == null) throw Exception("User not authenticated");

    final userDoc = await _db.collection('users').doc(_uid).get();
    final agencyId = userDoc.data()?['agencyId'];
    if (agencyId == null) return;
    if (userDoc.data()?['isAgencyOwner'] == true) throw Exception("Owners cannot leave. Delete agency instead.");

    await _db.runTransaction((transaction) async {
      transaction.update(_db.collection('agencies').doc(agencyId), {
        'hostUids': FieldValue.arrayRemove([_uid]),
      });
      transaction.update(_db.collection('users').doc(_uid), {
        'agencyId': null,
        'isAgencyOwner': false,
      });
    });
  }

  // 4. Get Agency Details
  Stream<AgencyModel?> streamAgency(String agencyId) {
    return _db.collection('agencies').doc(agencyId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AgencyModel.fromMap(snap.data()!, snap.id);
    });
  }

  // 5. Get Hosts in Agency
  Stream<List<UserModel>> streamAgencyHosts(String agencyId) {
    return _db.collection('users')
        .where('agencyId', isEqualTo: agencyId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  // 6. Get All Agencies (for exploration)
  Stream<List<AgencyModel>> streamAllAgencies() {
    return _db.collection('agencies')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AgencyModel.fromMap(doc.data(), doc.id)).toList());
  }
}
