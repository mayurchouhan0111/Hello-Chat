import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fame_model.dart';
import '../services/fame_service.dart';

final fameServiceProvider = Provider<FameService>((ref) => FameService());

final fameLeaderboardProvider =
    StreamProvider.family<List<FameEntry>, FamePeriod>((ref, period) {
  return ref.watch(fameServiceProvider).streamTopFame(period);
});
