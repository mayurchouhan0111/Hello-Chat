import 'package:cloud_functions/cloud_functions.dart';

class AdminWalletService {
  AdminWalletService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> getOverview({int limit = 100}) async {
    final result = await _functions
        .httpsCallable('getAdminWalletOverview')
        .call({'limit': limit});
    return Map<String, dynamic>.from(result.data as Map);
  }
}
