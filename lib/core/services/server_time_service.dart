import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service providing authoritative server time by calculating client-server
/// clock drift with round-trip-time (RTT) correction.
///
/// Used by GiftAnimationOverlay to guarantee that old gift animations never
/// replay for new joiners, even if the device clock is skewed by +/- 10 minutes.
class ServerTimeService {
  static int _offsetMs = 0;
  static bool _hasSynced = false;

  /// Clock offset: serverTime = clientTime + offsetMs
  static int get offsetMs => _offsetMs;

  /// Current estimated server time as a [DateTime]
  static DateTime get serverNow =>
      DateTime.now().add(Duration(milliseconds: _offsetMs));

  /// Current estimated server timestamp in milliseconds
  static int get serverNowMs =>
      DateTime.now().millisecondsSinceEpoch + _offsetMs;

  /// Syncs time with backend callable [getServerTime], applying RTT adjustment.
  static Future<void> sync() async {
    try {
      final start = DateTime.now().millisecondsSinceEpoch;
      final callable = FirebaseFunctions.instance.httpsCallable('getServerTime');
      final res = await callable.call();
      final end = DateTime.now().millisecondsSinceEpoch;

      final serverTime = (res.data['serverTime'] as num?)?.toInt();
      if (serverTime != null) {
        final rtt = end - start;
        _offsetMs = serverTime - (start + (rtt ~/ 2));
        _hasSynced = true;
        debugPrint('[ServerTimeService] Synced server time offset: ${_offsetMs}ms (RTT: ${rtt}ms)');
      }
    } catch (e) {
      debugPrint('[ServerTimeService] Sync error: $e. Using local clock fallback.');
    }
  }

  /// Calibrates offset from an authoritative Firestore server timestamp
  /// (e.g. from room message or presence doc).
  static void calibrateWithServerTimestamp(DateTime serverTimestamp) {
    if (_hasSynced) return;
    final localNow = DateTime.now();
    final diff = serverTimestamp.difference(localNow).inMilliseconds;
    if (diff.abs() > 3000) {
      _offsetMs = diff;
      debugPrint('[ServerTimeService] Calibrated offset from document timestamp: ${_offsetMs}ms');
    }
  }

  /// For testing: allows resetting or mocking offset
  @visibleForTesting
  static void setMockOffset(int offsetMs) {
    _offsetMs = offsetMs;
    _hasSynced = true;
  }

  @visibleForTesting
  static void reset() {
    _offsetMs = 0;
    _hasSynced = false;
  }
}
