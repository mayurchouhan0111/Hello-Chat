import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/widgets/user_badge.dart';

void main() {
  group('Luxury Visual Badge Engine Widget Verification', () {
    testWidgets('AgencyLevelBadge renders all 5 tiers with correct text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AgencyLevelBadge(level: 1),
                AgencyLevelBadge(level: 2),
                AgencyLevelBadge(level: 3),
                AgencyLevelBadge(level: 4),
                AgencyLevelBadge(level: 5),
              ],
            ),
          ),
        ),
      );

      // Verify text presence for all 5 tiers
      expect(find.text('1 AGENCY'), findsOneWidget);
      expect(find.text('2 AGENCY'), findsOneWidget);
      expect(find.text('3 AGENCY'), findsOneWidget);
      expect(find.text('4 AGENCY'), findsOneWidget);
      expect(find.text('5 AGENCY'), findsOneWidget);
    });

    testWidgets('HostLevelBadge renders all 5 tiers with correct text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HostLevelBadge(level: 1),
                HostLevelBadge(level: 2),
                HostLevelBadge(level: 3),
                HostLevelBadge(level: 4),
                HostLevelBadge(level: 5),
              ],
            ),
          ),
        ),
      );

      // Verify text presence for all 5 host tiers
      expect(find.text('1 HOST'), findsOneWidget);
      expect(find.text('2 HOST'), findsOneWidget);
      expect(find.text('3 HOST'), findsOneWidget);
      expect(find.text('4 HOST'), findsOneWidget);
      expect(find.text('5 HOST'), findsOneWidget);
    });

    testWidgets('SvipTierBadge renders SVIP 1 through 6', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SvipTierBadge(level: 1),
                SvipTierBadge(level: 2),
                SvipTierBadge(level: 3),
                SvipTierBadge(level: 4),
                SvipTierBadge(level: 5),
                SvipTierBadge(level: 6),
              ],
            ),
          ),
        ),
      );

      // Verify SVIP text badges
      expect(find.text('SVIP 1'), findsOneWidget);
      expect(find.text('SVIP 2'), findsOneWidget);
      expect(find.text('SVIP 3'), findsOneWidget);
      expect(find.text('SVIP 4'), findsOneWidget);
      expect(find.text('SVIP 5'), findsOneWidget);
      expect(find.text('SVIP 6'), findsOneWidget);
    });

    testWidgets('Badges composite row renders Agency, Host, and SVIP together without layout overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AgencyLevelBadge(level: 3),
                  SizedBox(width: 8),
                  HostLevelBadge(level: 4),
                  SizedBox(width: 8),
                  SvipTierBadge(level: 5),
                  SizedBox(width: 8),
                  UserBadge(label: 'LV.6', type: BadgeType.vip),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('3 AGENCY'), findsOneWidget);
      expect(find.text('4 HOST'), findsOneWidget);
      expect(find.text('SVIP 5'), findsOneWidget);
      expect(find.text('LV.6'), findsOneWidget);
      expect(tester.takeException(), isNull); // Ensures zero exceptions/overflow
    });
  });
}
