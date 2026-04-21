import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dino_service.dart';
import '../models/dino_model.dart';
import 'auth_provider.dart';

final dinoServiceProvider = Provider<DinoService>((ref) {
  return DinoService();
});

final dinoStreamProvider = StreamProvider.family<DinoModel?, String>((ref, uid) {
  return ref.watch(dinoServiceProvider).getDinoStream(uid);
});

final currentDinoProvider = StreamProvider<DinoModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(dinoServiceProvider).getDinoStream(user.uid);
});
