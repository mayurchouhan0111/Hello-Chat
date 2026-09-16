import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/room_support_service.dart';

/// First [limit] `coinsTarget` values from the room support config (ordered by level).
/// Fallback matches the 7-tier default seed. Rocket display uses the first 5.
List<int> roomSupportCoinsTargets(Map<String, dynamic>? config, {int limit = 5}) {
  const defaults = [10000000, 20000000, 30000000, 50000000, 100000000];
  final raw = (config?['levels'] as List<dynamic>?) ?? [];
  final sorted = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    ..sort((a, b) => ((a['level'] as num?)?.toInt() ?? 0).compareTo((b['level'] as num?)?.toInt() ?? 0));
  final out = <int>[];
  for (final e in sorted) {
    if (out.length >= limit) break;
    final v = (e['coinsTarget'] as num?)?.toInt() ?? 0;
    if (v > 0) out.add(v);
  }
  while (out.length < limit) {
    out.add(defaults[out.length]);
  }
  return out;
}

final roomSupportConfigProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(roomSupportServiceProvider).configStream();
});

final roomSupportCycleProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, roomId) {
  return ref.watch(roomSupportServiceProvider).cycleStream(roomId);
});

final roomSupportPartnersProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  return ref.watch(roomSupportServiceProvider).partnersStream(roomId);
});

final roomSupportHistoryProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  return ref.watch(roomSupportServiceProvider).historyStream(roomId);
});

final roomSupportRankingsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(roomSupportServiceProvider).rankingsStream();
});
