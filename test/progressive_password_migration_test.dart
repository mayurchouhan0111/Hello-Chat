import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/user_model.dart';
import 'package:hello_chat/core/services/auth_service.dart';
import 'package:hello_chat/features/profile/presentation/widgets/password_migration_prompt_card.dart';

void main() {
  group('Progressive Password Migration - Unit & Model Tests', () {
    test('AuthService.normalizePhone and phoneToEmail map all phone formats to identical credentials', () {
      const expectedPhone = '+8801712345678';
      const expectedEmail = '+8801712345678@phone.hellochat.app';

      // 1. With international plus
      expect(AuthService.normalizePhone('+8801712345678'), expectedPhone);
      expect(AuthService.phoneToEmail('+8801712345678'), expectedEmail);

      // 2. Local format with leading zero (e.g. 01712345678)
      expect(AuthService.normalizePhone('01712345678', countryCode: '880'), expectedPhone);
      expect(AuthService.phoneToEmail('01712345678'), expectedEmail);

      // 3. Number without leading zero (e.g. 1712345678)
      expect(AuthService.normalizePhone('1712345678', countryCode: '880'), expectedPhone);
      expect(AuthService.phoneToEmail('1712345678'), expectedEmail);

      // 4. Number with 880 prefix but no plus (e.g. 8801712345678)
      expect(AuthService.normalizePhone('8801712345678', countryCode: '880'), expectedPhone);
      expect(AuthService.phoneToEmail('8801712345678'), expectedEmail);

      // 5. Number with spaces or dashes
      expect(AuthService.normalizePhone('+880 1712-345678'), expectedPhone);
      expect(AuthService.phoneToEmail('+880 1712-345678'), expectedEmail);
    });

    test('UserModel defaults hasPassword to false for legacy phone-only users', () {
      final user = UserModel(
        uid: 'user_123',
        createdAt: DateTime.now(),
        phoneNumber: '+8801712345678',
        username: 'legacy_user',
        displayName: 'Legacy User',
        lastActive: DateTime.now(),
      );

      expect(user.hasPassword, isFalse);
      expect(user.passwordPromptDismissedUntil, isNull);
    });

    test('UserModel parses hasPassword and passwordPromptDismissedUntil from Firestore data', () {
      final now = DateTime.now();
      final dismissDate = now.add(const Duration(days: 7));

      final data = {
        'uid': 'user_456',
        'createdAt': now.toIso8601String(),
        'phoneNumber': '+8801712345678',
        'username': 'migrated_user',
        'displayName': 'Migrated User',
        'lastActive': now.toIso8601String(),
        'hasPassword': true,
        'passwordPromptDismissedUntil': dismissDate.millisecondsSinceEpoch,
      };

      final user = UserModel.fromMap(data);
      expect(user.hasPassword, isTrue);
      expect(user.passwordPromptDismissedUntil, isNotNull);
      expect(user.passwordPromptDismissedUntil!.day, equals(dismissDate.day));
    });

    test('UserModel.copyWith preserves or updates hasPassword flag safely', () {
      final user = UserModel(
        uid: 'user_789',
        createdAt: DateTime.now(),
        phoneNumber: '+8801712345678',
        username: 'user_789',
        displayName: 'User 789',
        lastActive: DateTime.now(),
        hasPassword: false,
      );

      expect(user.hasPassword, isFalse);

      final updatedUser = user.copyWith(hasPassword: true);
      expect(updatedUser.hasPassword, isTrue);
      expect(updatedUser.uid, equals('user_789')); // UID preserved identically!
    });
  });

  group('PasswordMigrationPromptCard - Widget Tests', () {
    testWidgets('Displays prompt card when user has NO password', (tester) async {
      final legacyUser = UserModel(
        uid: 'legacy_1',
        createdAt: DateTime.now(),
        phoneNumber: '+8801712345678',
        username: 'legacy_1',
        displayName: 'Legacy User',
        lastActive: DateTime.now(),
        hasPassword: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PasswordMigrationPromptCard(userData: legacyUser),
            ),
          ),
        ),
      );

      expect(find.text("Quick Password Setup"), findsOneWidget);
      expect(find.text("NEW"), findsOneWidget);
      expect(find.text("Set Up Password"), findsOneWidget);
      expect(find.text("Remind Me Later"), findsOneWidget);
    });

    testWidgets('Does NOT display prompt card when user ALREADY has a password', (tester) async {
      final securedUser = UserModel(
        uid: 'secured_1',
        createdAt: DateTime.now(),
        phoneNumber: '+8801712345678',
        username: 'secured_1',
        displayName: 'Secured User',
        lastActive: DateTime.now(),
        hasPassword: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PasswordMigrationPromptCard(userData: securedUser),
            ),
          ),
        ),
      );

      expect(find.text("Quick Password Setup"), findsNothing);
      expect(find.text("Set Up Password"), findsNothing);
    });

    testWidgets('Does NOT display prompt card when dismissal cooldown is active', (tester) async {
      final cooldownUser = UserModel(
        uid: 'cooldown_1',
        createdAt: DateTime.now(),
        phoneNumber: '+8801712345678',
        username: 'cooldown_1',
        displayName: 'Cooldown User',
        lastActive: DateTime.now(),
        hasPassword: false,
        passwordPromptDismissedUntil: DateTime.now().add(const Duration(days: 5)),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PasswordMigrationPromptCard(userData: cooldownUser),
            ),
          ),
        ),
      );

      expect(find.text("Quick Password Setup"), findsNothing);
    });

    testWidgets('Tapping Remind Me Later immediately hides prompt card', (tester) async {
      final legacyUser = UserModel(
        uid: 'legacy_2',
        createdAt: DateTime.now(),
        phoneNumber: '+8801712345678',
        username: 'legacy_2',
        displayName: 'Legacy User 2',
        lastActive: DateTime.now(),
        hasPassword: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PasswordMigrationPromptCard(userData: legacyUser),
            ),
          ),
        ),
      );

      expect(find.text("Quick Password Setup"), findsOneWidget);

      // Tap "Remind Me Later"
      await tester.tap(find.text("Remind Me Later"));
      await tester.pumpAndSettle();

      // Card is immediately dismissed
      expect(find.text("Quick Password Setup"), findsNothing);
    });
  });
}

