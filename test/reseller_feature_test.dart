import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_chat/core/models/reseller_model.dart';
import 'package:hello_chat/core/services/reseller_service.dart';
import 'package:hello_chat/features/reseller/presentation/screens/reseller_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Merchant List Screen & Reseller Model Tests', () {
    test('ResellerModel serialization and active check', () {
      final model = ResellerModel.fromMap({
        'reseller_id': '97702581',
        'user_id': 'reseller_uid_1',
        'name': 'Test Merchant',
        'country_flag': '🇲🇾',
        'whatsapp_number': '+60 11-1228 0539',
        'coin_balance': 100000000,
        'is_online': true,
        'status': 'ACTIVE',
      }, 'reseller_uid_1');

      expect(model.resellerId, '97702581');
      expect(model.name, 'Test Merchant');
      expect(model.isActive, true);
      expect(model.sanitizedWhatsappNumber, '601112280539');
      expect(model.formattedCoinBalance, '100000000+');
    });

    testWidgets('ResellerListScreen renders Merchant List header, banner, and cards', (WidgetTester tester) async {
      const mockReseller = ResellerModel(
        resellerId: '97702581',
        userId: 'uid_merchant_1',
        name: 'Official Merchant Alpha',
        countryFlag: '🇲🇾',
        whatsappNumber: '+601112280539',
        coinBalance: 100000000,
        isOnline: true,
        status: 'ACTIVE',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeResellersProvider.overrideWith((ref) => Stream.value([mockReseller])),
          ],
          child: const MaterialApp(
            home: ResellerListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar & banner
      expect(find.text('Merchant List'), findsOneWidget);
      expect(find.text('Merchant Recharge more benefit'), findsOneWidget);

      // Card Header
      expect(find.text('Remaining gold coins'), findsOneWidget);
      expect(find.text('100000000+'), findsOneWidget);

      // Profile details
      expect(find.text('Official Merchant Alpha'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('ID:97702581'), findsOneWidget);
      expect(find.text('Whatsapp number: +601112280539'), findsOneWidget);

      // Action buttons
      expect(find.text('Private letter'), findsOneWidget);
      expect(find.text('Whatsapp'), findsOneWidget);
    });

    test('activeResellersProvider initializes stream', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final val = container.read(activeResellersProvider);
      expect(val, isNotNull);
    });
  });
}
