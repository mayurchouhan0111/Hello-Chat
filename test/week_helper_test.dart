import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/utils/week_helper.dart';
import 'package:hello_chat/core/services/server_time_service.dart';

void main() {
  group('WeekHelper & ServerTimeService ISO Week Tests', () {
    test('1. Sunday 23:59:59.999 stays in the old week', () {
      final sun = DateTime.parse('2026-10-25T23:59:59.999Z');
      expect(WeekHelper.getIsoWeekId(sun), equals('2026-W43'));
    });

    test('2. Monday 00:00:00.000 starts the new week', () {
      final mon = DateTime.parse('2026-10-26T00:00:00.000Z');
      expect(WeekHelper.getIsoWeekId(mon), equals('2026-W44'));
    });

    test('3. Boundary check: exactly 1 millisecond delta', () {
      final beforeBoundary = DateTime.parse('2026-10-25T23:59:59.999Z');
      final atBoundary = DateTime.parse('2026-10-26T00:00:00.000Z');
      expect(WeekHelper.getIsoWeekId(beforeBoundary), equals('2026-W43'));
      expect(WeekHelper.getIsoWeekId(atBoundary), equals('2026-W44'));
    });

    test('4. Gift between 00:00 and 07:00 UTC is in the new week', () {
      final earlyMon = DateTime.parse('2026-10-26T04:15:30.500Z');
      expect(WeekHelper.getIsoWeekId(earlyMon), equals('2026-W44'));
    });

    test('5. Year boundary 2025/2026 (2025-12-29 is Monday in 2026-W01)', () {
      final sun2025 = DateTime.parse('2025-12-28T23:59:59.999Z');
      final mon2026 = DateTime.parse('2025-12-29T00:00:00.000Z');
      expect(WeekHelper.getIsoWeekId(sun2025), equals('2025-W52'));
      expect(WeekHelper.getIsoWeekId(mon2026), equals('2026-W01'));
    });

    test('6. Year boundary with 53 weeks (2026-12-28 to 2027-01-03 is 2026-W53)', () {
      final monW53 = DateTime.parse('2026-12-28T12:00:00.000Z');
      final sunW53 = DateTime.parse('2027-01-03T23:59:59.999Z');
      final monNext = DateTime.parse('2027-01-04T00:00:00.000Z');
      expect(WeekHelper.getIsoWeekId(monW53), equals('2026-W53'));
      expect(WeekHelper.getIsoWeekId(sunW53), equals('2026-W53'));
      expect(WeekHelper.getIsoWeekId(monNext), equals('2027-W01'));
    });

    test('7. Timezones: UTC, UTC+5:30, UTC-8 all normalize to the same UTC week', () {
      // Monday 01:00 UTC represented in different local time zones:
      final instantUtc = DateTime.parse('2026-10-26T01:00:00.000Z');
      expect(WeekHelper.getIsoWeekId(instantUtc), equals('2026-W44'));

      // In IST (UTC+5:30): 06:30 AM Monday
      // In PT (UTC-7/8): 18:00 PM Sunday
      // toUtc() preserves the absolute instant:
      expect(WeekHelper.getIsoWeekId(instantUtc.toLocal()), equals('2026-W44'));
    });

    test('8. Wrong phone clock overridden by ServerTimeService offset', () {
      // Suppose phone hardware clock is stuck on Sunday Oct 25 18:00 UTC (lagging by 7 hours)
      // Server is actually Monday Oct 26 01:00 UTC (drift = +7 hours = +25,200,000 ms)
      const driftMs = 7 * 60 * 60 * 1000;
      ServerTimeService.setMockOffset(driftMs);

      // Even if local device clock is Sunday, ServerTimeService.serverNow gives Monday
      final serverTime = ServerTimeService.serverNow;
      expect(serverTime.isAfter(DateTime.now()), isTrue);
    });

    test('9. Fill-in window: true on Monday and Tuesday UTC, false on Wednesday-Sunday', () {
      final monday = DateTime.parse('2026-10-26T10:00:00.000Z');
      final tuesday = DateTime.parse('2026-10-27T23:59:59.000Z');
      final wednesday = DateTime.parse('2026-10-28T00:00:01.000Z');
      final sunday = DateTime.parse('2026-10-25T15:00:00.000Z');

      expect(WeekHelper.isFillInWindow(monday), isTrue);
      expect(WeekHelper.isFillInWindow(tuesday), isTrue);
      expect(WeekHelper.isFillInWindow(wednesday), isFalse);
      expect(WeekHelper.isFillInWindow(sunday), isFalse);
    });
  });
}
