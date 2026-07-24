import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CommissionWalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Fetch active financial policies (Commission rates, USD-to-Diamond rate, Supported Gateways)
  Future<Map<String, dynamic>> getFinancialPolicies() async {
    try {
      final doc = await _firestore.collection('system_configs').doc('financial_policies').get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (e) {
      print('Error fetching financial policies: $e');
    }
    return {
      'agencyCommissionRate': 0.30,
      'adminCommissionRate': 0.10,
      'usdToDiamondRate': 1000000,
      'supportedGateways': ['bKash', 'Nagad', 'Rocket', 'Bank Transfer', 'PayPal', 'Wise', 'Binance Pay', 'USDT TRC20', 'USDT BEP20']
    };
  }

  /// Option 3: Convert USD Commission Balance -> Diamonds
  /// Rate: 1 USD = 1,000,000 Diamonds (default)
  Future<Map<String, dynamic>> convertCommissionToDiamonds(double usdAmount) async {
    final callable = _functions.httpsCallable('convertCommissionToDiamonds');
    final result = await callable.call({'usdAmount': usdAmount});
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Option 1: Transfer USD Commission Balance -> Reseller Wallet
  Future<Map<String, dynamic>> transferCommissionToReseller(String targetResellerHelloId, double usdAmount) async {
    final callable = _functions.httpsCallable('transferCommissionToReseller');
    final result = await callable.call({
      'targetResellerHelloId': targetResellerHelloId,
      'usdAmount': usdAmount,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Option 2: Submit Direct Financial Withdrawal Request
  Future<Map<String, dynamic>> submitCommissionWithdrawal({
    required double usdAmount,
    required String paymentMethod,
    required String paymentAccountDetails,
  }) async {
    final callable = _functions.httpsCallable('submitCommissionWithdrawal');
    final result = await callable.call({
      'usdAmount': usdAmount,
      'paymentMethod': paymentMethod,
      'paymentAccountDetails': paymentAccountDetails,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Stream USD-to-Diamond Conversion History for a User
  Stream<List<Map<String, dynamic>>> streamDiamondConversions(String uid) {
    return _firestore
        .collection('commission_diamond_conversions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Stream Direct Withdrawal Requests for a User
  Stream<List<Map<String, dynamic>>> streamWithdrawals(String uid) {
    return _firestore
        .collection('commission_withdrawals')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Stream Reseller Transfers History for a User
  Stream<List<Map<String, dynamic>>> streamResellerTransfers(String uid) {
    return _firestore
        .collection('commission_reseller_transfers')
        .where('senderUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Stream Commission Earnings Ledger for a User
  Stream<List<Map<String, dynamic>>> streamCommissionEarnings(String uid) {
    return _firestore
        .collection('commission_transactions')
        .where('recipientUid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }
}
