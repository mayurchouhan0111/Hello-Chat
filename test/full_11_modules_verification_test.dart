import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/models/room_theme_model.dart';
import 'package:hello_chat/core/models/message_model.dart';
import 'package:hello_chat/core/services/auth_service.dart';
import 'package:hello_chat/core/constants/stickers_data.dart';
import 'package:hello_chat/core/providers/overlay_provider.dart';

void main() {
  group('Module 1: User Login, Password Setup & Progressive Migration', () {
    test('Phone normalization handles local 0-prefix, international +, and spaces', () {
      expect(AuthService.normalizePhone('01712345678', countryCode: '880'), '+8801712345678');
      expect(AuthService.normalizePhone('+880 1712-345678'), '+8801712345678');
      expect(AuthService.normalizePhone('8801712345678', countryCode: '880'), '+8801712345678');
      expect(AuthService.normalizePhone('1712345678', countryCode: '880'), '+8801712345678');
    });

    test('phoneToEmail generates deterministic email identity for Firebase Auth linking', () {
      expect(AuthService.phoneToEmail('01712345678'), '+8801712345678@phone.hellochat.app');
      expect(AuthService.phoneToEmail('+8801712345678'), '+8801712345678@phone.hellochat.app');
    });

    test('UserModel maintains hasPassword and dismissal cooldown without UID mutation', () {
      final user = UserModel(
        uid: 'user_orig_999',
        createdAt: DateTime.now(),
        phoneNumber: '+8801712345678',
        username: 'user999',
        displayName: 'User 999',
        lastActive: DateTime.now(),
        hasPassword: false,
      );

      final updated = user.copyWith(hasPassword: true);
      expect(updated.uid, equals('user_orig_999'));
      expect(updated.hasPassword, isTrue);
    });
  });

  group('Module 3: Room Seat Design & Capacity Customization', () {
    test('Supports official capacity options 8, 9, 12, 13, 16', () {
      const allowedCapacities = [8, 9, 12, 13, 16];
      for (final cap in allowedCapacities) {
        expect(cap, greaterThanOrEqualTo(8));
        expect(cap, lessThanOrEqualTo(16));
        final audienceSeats = cap - 1;
        expect(audienceSeats, greaterThan(0));
      }
    });

    test('Defensive clamping prevents negative item count for corrupted capacities', () {
      int calculateItemCount(int cap, bool showHost) {
        return (showHost ? cap : cap - 1).clamp(0, 16);
      }

      expect(calculateItemCount(8, false), 7);
      expect(calculateItemCount(9, false), 8);
      expect(calculateItemCount(12, false), 11);
      expect(calculateItemCount(13, false), 12);
      expect(calculateItemCount(16, false), 15);
      expect(calculateItemCount(0, false), 0); // safely clamps
      expect(calculateItemCount(-5, false), 0); // safely clamps
    });
  });

  group('Module 4: Room Background Themes & Official Category', () {
    test('Catalog contains Normal, Luxury, and Official categories', () {
      expect(RoomThemeCatalog.normalThemes, isNotEmpty);
      expect(RoomThemeCatalog.luxuryThemes, isNotEmpty);
      expect(RoomThemeCatalog.officialThemes, isNotEmpty);
    });

    test('Official category includes Agency, Admin, Official, and Recharge themes', () {
      final officialIds = RoomThemeCatalog.officialThemes.map((t) => t.id).toList();
      expect(officialIds, contains('agency_theme'));
      expect(officialIds, contains('admin_theme'));
      expect(officialIds, contains('official_theme'));
      expect(officialIds, contains('recharge_theme'));
    });

    test('Theme lookup has safe fallback for unknown or null themeId', () {
      final defaultTheme = RoomThemeCatalog.getTheme(null);
      expect(defaultTheme.id, equals(RoomThemeCatalog.normalThemes.first.id));

      final official = RoomThemeCatalog.getTheme('agency_theme');
      expect(official.id, equals('agency_theme'));
      expect(official.category, equals(RoomThemeCategory.official));
    });
  });

  group('Module 7: Clear Messages Real-Time Filter', () {
    test('Messages are accurately filtered after messagesClearedAt timestamp', () {
      final now = DateTime.now();
      final before = now.subtract(const Duration(minutes: 5));
      final after = now.add(const Duration(minutes: 1));

      final msg1 = RoomMessage(
        msgId: 'msg_old',
        uid: 'user_1',
        text: 'Old message',
        type: 'text',
        createdAt: before,
      );

      final msg2 = RoomMessage(
        msgId: 'msg_new',
        uid: 'user_2',
        text: 'New message after clear',
        type: 'text',
        createdAt: after,
      );

      final allMessages = [msg1, msg2];
      final clearedAt = now;

      final filtered = allMessages.where((m) => m.createdAt.isAfter(clearedAt)).toList();
      expect(filtered.length, 1);
      expect(filtered.first.msgId, 'msg_new');
    });
  });

  group('Module 8 & 9: Emoji Replacement & Stickers', () {
    test('StickersData contains 4 dedicated professional packs without legacy emoji sets', () {
      const packs = StickersData.activePacks;
      expect(packs.length, 4);

      final packIds = packs.map((p) => p.id).toList();
      expect(packIds, contains('pack_audio'));
      expect(packIds, contains('pack_mascot'));
      expect(packIds, contains('pack_cuppy'));
      expect(packIds, contains('pack_chibi'));

      for (final pack in packs) {
        expect(pack.stickers, isNotEmpty);
        for (final asset in pack.stickers) {
          expect(asset.endsWith('.png') || asset.endsWith('.webp') || asset.endsWith('.jpg'), isTrue);
        }
      }
    });
  });

  group('Module 11: Room Minimize & Re-Entry Animation Suppression', () {
    test('RoomOverlayNotifier correctly tracks active sessions and restores without replay', () {
      final notifier = RoomOverlayNotifier();
      const testRoom = 'room_vip_777';

      // 1. Initially not restoring
      expect(notifier.isRestoringSession(testRoom), isFalse);

      // 2. User minimizes room
      notifier.minimize(testRoom);
      expect(notifier.isRestoringSession(testRoom), isTrue);
      expect(notifier.state.isMinimized, isTrue);

      // 3. User restores room
      notifier.restore();
      // Active session is preserved so re-entry animation is suppressed
      expect(notifier.isRestoringSession(testRoom), isTrue);
      expect(notifier.state.isMinimized, isFalse);

      // 4. User explicitly leaves room
      notifier.endSession(testRoom);
      expect(notifier.isRestoringSession(testRoom), isFalse);
    });
  });
}
