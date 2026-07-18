import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockService {
  static final WakelockService _instance = WakelockService._();
  factory WakelockService() => _instance;
  WakelockService._();

  int _lockCount = 0;

  bool get isHeld => _lockCount > 0;

  Future<void> acquire() async {
    _lockCount++;
    if (_lockCount == 1) {
      await WakelockPlus.enable();
    }
  }

  Future<void> release() async {
    if (_lockCount <= 0) return;
    _lockCount--;
    if (_lockCount == 0) {
      await WakelockPlus.disable();
    }
  }

  Future<void> reset() async {
    _lockCount = 0;
    await WakelockPlus.disable();
  }
}
