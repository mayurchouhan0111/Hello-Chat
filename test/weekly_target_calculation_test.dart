import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/services/salary_service.dart';

void main() {
  group('📅 Task 12: Weekly Target Calculation & Reset Tests', () {
    test('Calculates UTC Week ID format YYYY-Www accurately', () {
      final date = DateTime.utc(2026, 8, 26);
      final weekId = SalaryService.getUtcWeekId(date);
      expect(weekId, matches(RegExp(r'^\d{4}-W\d{2}$')));
      expect(weekId, equals('2026-W35'));
    });

    test('Ensures Monday and Sunday of same week share identical week ID', () {
      final monday = DateTime.utc(2026, 8, 24);
      final sunday = DateTime.utc(2026, 8, 30);

      final mondayId = SalaryService.getUtcWeekId(monday);
      final sundayId = SalaryService.getUtcWeekId(sunday);

      expect(mondayId, equals(sundayId));
    });

    test('Triggers week ID rollover on next Monday 00:00 UTC', () {
      final sunday = DateTime.utc(2026, 8, 30);
      final nextMonday = DateTime.utc(2026, 8, 31);

      final sundayId = SalaryService.getUtcWeekId(sunday);
      final nextMondayId = SalaryService.getUtcWeekId(nextMonday);

      expect(sundayId, isNot(equals(nextMondayId)));
    });
  });
}
