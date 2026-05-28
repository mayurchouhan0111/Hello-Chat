import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_firebase_service.dart';

class WalletService extends BaseFirebaseService {
  /// Requests a bean withdrawal.
  /// [amount] in Beans.
  /// [method] e.g. 'Bank Transfer', 'Bkash', etc.
  /// [isAgency] if true, withdraws from agency balance instead of user balance.
  Future<Map<String, dynamic>> requestWithdrawal({
    required int amount,
    required String method,
    required Map<String, String> accountDetails,
    bool isAgency = false,
    String? agencyId,
  }) async {
    final result = await callFunction('withdrawBeans', {
      'amount': amount,
      'method': method,
      'accountDetails': accountDetails,
      'isAgency': isAgency,
      'agencyId': agencyId,
    });
    return Map<String, dynamic>.from(result);
  }

  /// (Admin) Approves a withdrawal request.
  Future<void> approveWithdrawal(String requestId, {String? note}) async {
    await callFunction('adminApproveWithdrawal', {
      'id': requestId,
      'note': note,
    });
  }

  /// (Admin) Rejects a withdrawal request.
  Future<void> rejectWithdrawal(String requestId, {String? reason}) async {
    await callFunction('adminRejectWithdrawal', {
      'id': requestId,
      'reason': reason,
    });
  }
}

final walletServiceProvider = Provider<WalletService>((ref) => WalletService());
