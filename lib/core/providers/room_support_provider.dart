import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/room_support_service.dart';

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
