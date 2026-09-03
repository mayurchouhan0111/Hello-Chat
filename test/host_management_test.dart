import 'package:flutter_test/flutter_test.dart';

void main() {
  group('🏢 Task 8: Host Management Target & Recruitment Logic Tests', () {
    double calculateHostProgress(int beans, int target) {
      if (target <= 0) return 0.0;
      return (beans / target).clamp(0.0, 1.0);
    }

    test('Calculates 50% target progress accurately', () {
      final progress = calculateHostProgress(25000, 50000);
      expect(progress, equals(0.5));
    });

    test('Clamps target progress at 100% when earnings exceed target', () {
      final progress = calculateHostProgress(120000, 100000);
      expect(progress, equals(1.0));
    });

    test('Parses numeric user query for host addition', () {
      const query = '97702581';
      final numericId = int.tryParse(query.trim());
      expect(numericId, equals(97702581));
    });
  });
}
