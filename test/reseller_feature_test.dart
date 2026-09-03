import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/features/reseller/presentation/screens/reseller_list_screen.dart';
import 'package:hello_chat/core/services/reseller_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🛍️ Task 5: Reseller List Screen & Service Tests', () {
    testWidgets('ResellerListScreen renders header and reseller cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeResellersProvider.overrideWith((ref) => Stream.value([
              {
                'uid': 'reseller_1',
                'displayName': 'Global Reseller #1',
                'helloId': '97702581',
                'profilePhotoUrl': '',
                'whatsappNumber': '+601112280539',
                'status': 'Online 24/7',
                'discountRate': '5% Bonus Coins',
              }
            ])),
          ],
          child: const MaterialApp(
            home: ResellerListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Authorized Resellers'), findsOneWidget);
      expect(find.text('Global Reseller #1'), findsOneWidget);
      expect(find.text('Join WhatsApp'), findsOneWidget);
      expect(find.text('Send Message'), findsOneWidget);
    });

    test('activeResellersProvider initializes stream', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final val = container.read(activeResellersProvider);
      expect(val, isNotNull);
    });
  });
}
