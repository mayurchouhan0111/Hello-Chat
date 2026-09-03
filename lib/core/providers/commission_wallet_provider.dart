import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/commission_wallet_service.dart';
import 'auth_provider.dart';

/// Service provider
final commissionWalletServiceProvider = Provider<CommissionWalletService>((ref) {
  return CommissionWalletService();
});

/// Active Financial Policies Provider (Commission rates, USD to Diamond rate, Gateways)
final financialPoliciesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(commissionWalletServiceProvider);
  return await service.getFinancialPolicies();
});

/// 1. Stream: Commission Earnings Ledger (from host recharges)
final commissionEarningsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  final service = ref.watch(commissionWalletServiceProvider);
  return service.streamCommissionEarnings(user.uid);
});

/// 2. Stream: Direct Cash Withdrawals History
final commissionWithdrawalsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  final service = ref.watch(commissionWalletServiceProvider);
  return service.streamWithdrawals(user.uid);
});

/// 3. Stream: Reseller Wallet Transfers History
final resellerTransfersStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  final service = ref.watch(commissionWalletServiceProvider);
  return service.streamResellerTransfers(user.uid);
});

/// 4. Stream: USD-to-Diamond Conversions History
final diamondConversionsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  final service = ref.watch(commissionWalletServiceProvider);
  return service.streamDiamondConversions(user.uid);
});

/// State for commission async actions
class CommissionActionState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const CommissionActionState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  CommissionActionState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return CommissionActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Action Notifier for Commission Wallet operations
class CommissionActionNotifier extends StateNotifier<CommissionActionState> {
  final CommissionWalletService _service;

  CommissionActionNotifier(this._service) : super(const CommissionActionState());

  /// Option 3: Convert USD -> Diamonds
  Future<bool> convertToDiamonds(double usdAmount) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      final res = await _service.convertCommissionToDiamonds(usdAmount);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully converted \$${usdAmount.toStringAsFixed(2)} USD to Diamonds!',
      );
      return res['success'] == true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Option 1: Transfer USD -> Reseller Wallet
  Future<bool> transferToReseller(String targetResellerHelloId, double usdAmount) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      final res = await _service.transferCommissionToReseller(targetResellerHelloId, usdAmount);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully transferred \$${usdAmount.toStringAsFixed(2)} USD to Reseller!',
      );
      return res['success'] == true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Option 2: Direct Withdrawal Request
  Future<bool> submitWithdrawal({
    required double usdAmount,
    required String paymentMethod,
    required String paymentAccountDetails,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      final res = await _service.submitCommissionWithdrawal(
        usdAmount: usdAmount,
        paymentMethod: paymentMethod,
        paymentAccountDetails: paymentAccountDetails,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Withdrawal request submitted successfully! Pending Owner review.',
      );
      return res['success'] == true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearMessages() {
    state = const CommissionActionState();
  }
}

final commissionActionProvider = StateNotifierProvider<CommissionActionNotifier, CommissionActionState>((ref) {
  final service = ref.watch(commissionWalletServiceProvider);
  return CommissionActionNotifier(service);
});
