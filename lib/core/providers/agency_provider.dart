import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agency_model.dart';
import '../models/user_model.dart';
import '../services/agency_service.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

final agencyServiceProvider = Provider<AgencyService>((ref) {
  return AgencyService();
});

// Profile provider usually provides the currentUser
// final userProvider = StreamProvider<UserModel?>((ref) => ...);

final myAgencyProvider = StreamProvider<AgencyModel?>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null || user.agencyId == null) return Stream.value(null);
  return ref.watch(agencyServiceProvider).streamAgency(user.agencyId!);
});


final agencyHostsProvider = StreamProvider.family<List<UserModel>, String>((ref, agencyId) {
  return ref.watch(agencyServiceProvider).streamAgencyHosts(agencyId);
});

final allAgenciesProvider = StreamProvider<List<AgencyModel>>((ref) {
  return ref.watch(agencyServiceProvider).streamAllAgencies();
});
