import 'package:flutter/foundation.dart';
import '../services/server_time_service.dart';

/// Helper for standard ISO 8601 UTC week calculations (e.g. "2026-W44").
///
/// Guaranteed rules:
/// - Week starts Monday 00:00:00.000 UTC and ends Sunday 23:59:59.999 UTC.
/// - Sunday 23:59:59.999 UTC stays in the ending week.
/// - Monday 00:00:00.000 UTC starts the new week.
/// - Partner fill-in window is open on Monday and Tuesday (UTC).
class WeekHelper {
  /// Returns standard ISO 8601 week id: YYYY-Www (e.g. "2026-W44") in UTC.
  static String getIsoWeekId([DateTime? date]) {
    final utc = (date ?? DateTime.now()).toUtc();
    // Monday is 1, Sunday is 7 in Dart DateTime.weekday.
    // Thursday of the current week determines the ISO week-year:
    final thursday = utc.add(Duration(days: 4 - utc.weekday));
    final weekYear = thursday.year;

    // Jan 4th is always in week 1 of ISO-8601:
    final jan4 = DateTime.utc(weekYear, 1, 4);
    final jan4Thursday = jan4.add(Duration(days: 4 - jan4.weekday));
    final weekNumber = 1 + (thursday.difference(jan4Thursday).inDays ~/ 7);
    final weekPad = weekNumber < 10 ? '0$weekNumber' : '$weekNumber';
    return '$weekYear-W$weekPad';
  }

  /// Returns current UTC week id using authoritative [ServerTimeService].
  static String getCurrentServerWeekId() {
    return getIsoWeekId(ServerTimeService.serverNow);
  }

  /// Returns the start of the ISO week (Monday 00:00:00.000 UTC).
  static DateTime getWeekStart(DateTime date) {
    final utc = date.toUtc();
    final monday = utc.subtract(Duration(days: utc.weekday - 1));
    return DateTime.utc(monday.year, monday.month, monday.day, 0, 0, 0, 0);
  }

  /// Returns the end of the ISO week (Sunday 23:59:59.999 UTC).
  static DateTime getWeekEnd(DateTime date) {
    final start = getWeekStart(date);
    return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
  }

  /// Returns true if currently within the partner fill-in window (Monday 00:00 to Tuesday 23:59:59.999 UTC).
  static bool isFillInWindow([DateTime? date]) {
    final utc = (date ?? ServerTimeService.serverNow).toUtc();
    return utc.weekday == DateTime.monday || utc.weekday == DateTime.tuesday;
  }
}
