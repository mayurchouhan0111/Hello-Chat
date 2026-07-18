import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class GameRecoveryService {
  static final GameRecoveryService _instance = GameRecoveryService._();
  factory GameRecoveryService() => _instance;
  GameRecoveryService._();

  static const _fileName = 'spin_wheel_recovery.json';

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> saveBetState({
    required Map<String, int> bets,
    required Map<String, int> betClickCounts,
    required String roundId,
    required int timestamp,
  }) async {
    try {
      final data = {
        'bets': bets,
        'betClickCounts': betClickCounts,
        'roundId': roundId,
        'timestamp': timestamp,
      };
      final file = await _getFile();
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> loadBetState() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearBetState() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
