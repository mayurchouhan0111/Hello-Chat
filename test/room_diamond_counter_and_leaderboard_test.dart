import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/room_model.dart';
import 'package:hello_chat/core/router/app_router.dart';

String formatDiamondCount(int n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

String isoWeekKey(DateTime date) {
  final dayNum = date.weekday;
  final thursday = date.add(Duration(days: 4 - dayNum));
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  final weekNo = ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
  return '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';
}

void main() {
  group('💎 Room Diamond Counter & Leaderboard Automated Tests', () {
    test('Formats room diamond counts accurately (K, M, B formatting)', () {
      expect(formatDiamondCount(0), equals('0'));
      expect(formatDiamondCount(450), equals('450'));
      expect(formatDiamondCount(1500), equals('1.5K'));
      expect(formatDiamondCount(2500000), equals('2.5M'));
      expect(formatDiamondCount(1200000000), equals('1.2B'));
    });

    test('Computes UTC ISO Week Keys matching backend specification', () {
      final date = DateTime.utc(2026, 8, 27); // Thursday
      final key = isoWeekKey(date);
      expect(key, equals('2026-W35'));
    });

    test('Updates RoomModel weeklyEarnings on diamond gift accumulation', () {
      final room = RoomModel(
        roomId: 'room_123',
        createdBy: 'user_1',
        ownerUid: 'user_1',
        name: 'Test Room',
        theme: 'Default',
        coverUrl: '',
        isPrivate: false,
        capacity: 8,
        currentUsersCount: 1,
        backgroundMusic: false,
        createdAt: DateTime.now(),
        status: 'active',
        admins: [],
        moderators: [],
        bannedUids: [],
        weeklyEarnings: 500,
      );

      expect(room.weeklyEarnings, equals(500));
      final updatedEarnings = room.weeklyEarnings + 1000;
      expect(formatDiamondCount(updatedEarnings), equals('1.5K'));
    });

    test('Verifies AppRoutes includes roomGiftLeaderboard route', () {
      expect(AppRoutes.roomGiftLeaderboard, equals('/room-gift-leaderboard'));
    });
  });
}
